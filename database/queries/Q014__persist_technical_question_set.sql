WITH supplied AS
(
    SELECT
        $1::UUID                                      AS session_id,
        NULLIF(BTRIM($2), '')                         AS workflow_execution_id,
        UPPER(BTRIM($3))                              AS round,
        $4::JSONB                                     AS question_plan,
        NULLIF(BTRIM($5), '')                         AS generation_model,
        NULLIF(BTRIM($6), '')                         AS prompt_version
),
normalized AS
(
    SELECT
        supplied.*,
        jsonb_array_length(question_plan -> 'questions') AS question_count,
        encode(digest(question_plan::TEXT, 'sha256'), 'hex') AS content_hash,
        CASE round
            WHEN 'FIRST' THEN 'QUESTION_GENERATION'
            WHEN 'FOLLOW_UP' THEN 'FOLLOW_UP_GENERATION'
        END AS expected_stage,
        CASE round
            WHEN 'FIRST' THEN 'FIRST_ROUND'
            WHEN 'FOLLOW_UP' THEN 'FOLLOW_UP'
        END AS next_stage
    FROM supplied
    WHERE round IN ('FIRST', 'FOLLOW_UP')
      AND jsonb_typeof(question_plan) = 'object'
      AND jsonb_typeof(question_plan -> 'questions') = 'array'
      AND jsonb_array_length(question_plan -> 'questions') > 0
),
eligible AS
(
    SELECT normalized.*, session.current_stage
    FROM normalized
    JOIN talentai.technical_interview_session AS session
      ON session.id = normalized.session_id
     AND session.status = 'RUNNING'
     AND session.claim_owner_workflow_execution_id
         = normalized.workflow_execution_id
     AND session.current_stage IN
         (normalized.expected_stage, normalized.next_stage)
),
existing AS
(
    SELECT question_set.*
    FROM talentai.technical_question_set AS question_set
    JOIN eligible
      ON question_set.session_id = eligible.session_id
     AND question_set.round = eligible.round
     AND question_set.content_hash = eligible.content_hash
),
inserted AS
(
    INSERT INTO talentai.technical_question_set
    (
        session_id,
        round,
        version,
        content_hash,
        question_plan,
        question_count,
        generation_model,
        prompt_version
    )
    SELECT
        eligible.session_id,
        eligible.round,
        COALESCE(
            (
                SELECT MAX(question_set.version) + 1
                FROM talentai.technical_question_set AS question_set
                WHERE question_set.session_id = eligible.session_id
                  AND question_set.round = eligible.round
            ),
            1
        ),
        eligible.content_hash,
        eligible.question_plan,
        eligible.question_count,
        eligible.generation_model,
        eligible.prompt_version
    FROM eligible
    WHERE eligible.current_stage = eligible.expected_stage
      AND NOT EXISTS (SELECT 1 FROM existing)
    ON CONFLICT ON CONSTRAINT uq_technical_question_set_content
    DO NOTHING
    RETURNING *
),
resolved AS
(
    SELECT existing.*, FALSE AS was_inserted FROM existing
    UNION ALL
    SELECT inserted.*, TRUE AS was_inserted FROM inserted
),
advanced AS
(
    UPDATE talentai.technical_interview_session AS session
    SET
        current_stage = eligible.next_stage,
        last_workflow_execution_id = eligible.workflow_execution_id,
        updated_at = now()
    FROM eligible
    WHERE session.id = eligible.session_id
      AND session.current_stage = eligible.expected_stage
      AND EXISTS (SELECT 1 FROM resolved)
    RETURNING session.id
)
SELECT
    resolved.id                              AS "questionSetId",
    resolved.session_id                      AS "sessionId",
    resolved.round                           AS round,
    resolved.version                         AS version,
    resolved.content_hash                    AS "contentHash",
    resolved.question_count                  AS "questionCount",
    resolved.generation_model                AS "generationModel",
    resolved.prompt_version                  AS "promptVersion",
    resolved.was_inserted                    AS "wasInserted",
    eligible.next_stage                      AS "currentStage"
FROM resolved
JOIN eligible
  ON eligible.session_id = resolved.session_id
 AND eligible.round = resolved.round;
