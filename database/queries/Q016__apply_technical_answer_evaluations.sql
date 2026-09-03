WITH supplied AS
(
    SELECT
        $1::UUID                              AS session_id,
        NULLIF(BTRIM($2), '')                 AS workflow_execution_id,
        $3::JSONB                             AS answer_records
),
eligible AS
(
    SELECT supplied.*
    FROM supplied
    JOIN talentai.technical_interview_session AS session
      ON session.id = supplied.session_id
     AND session.status = 'RUNNING'
     AND session.current_stage IN
         ('ANSWER_EVALUATION', 'RESULT_PERSISTENCE')
     AND session.claim_owner_workflow_execution_id
         = supplied.workflow_execution_id
    WHERE jsonb_typeof(supplied.answer_records) = 'array'
),
records AS
(
    SELECT
        eligible.session_id,
        eligible.workflow_execution_id,
        answer_record,
        CASE answer_record ->> 'round'
            WHEN 'first' THEN 'FIRST'
            WHEN 'followUp' THEN 'FOLLOW_UP'
        END AS round,
        NULLIF(BTRIM(answer_record ->> 'id'), '') AS question_id
    FROM eligible
    CROSS JOIN LATERAL jsonb_array_elements(
        eligible.answer_records
    ) AS item(answer_record)
    WHERE NULLIF(answer_record ->> 'finalScore', '')::NUMERIC
          BETWEEN 0 AND 4
),
updated AS
(
    UPDATE talentai.technical_interview_answer AS answer
    SET
        model_score = NULLIF(records.answer_record ->> 'llmScore', '')::NUMERIC,
        final_score = NULLIF(records.answer_record ->> 'finalScore', '')::NUMERIC,
        rationale = COALESCE(records.answer_record ->> 'llmRationale', ''),
        status = 'EVALUATED',
        evaluated_at = COALESCE(answer.evaluated_at, now())
    FROM records
    WHERE answer.session_id = records.session_id
      AND answer.round = records.round
      AND answer.question_id = records.question_id
      AND answer.dimension_code = records.answer_record ->> 'dimensionCode'
      AND answer.question_type = records.answer_record ->> 'type'
    RETURNING answer.id
),
counts AS
(
    SELECT
        (SELECT COUNT(*) FROM records)::INTEGER AS supplied_count,
        (
            SELECT COUNT(*)
            FROM talentai.technical_interview_answer AS answer
            WHERE answer.session_id = eligible.session_id
        )::INTEGER AS answer_count,
        (SELECT COUNT(*) FROM updated)::INTEGER AS evaluated_count
    FROM eligible
),
advanced AS
(
    UPDATE talentai.technical_interview_session AS session
    SET
        current_stage = 'RESULT_PERSISTENCE',
        last_workflow_execution_id = eligible.workflow_execution_id,
        updated_at = now()
    FROM eligible, counts
    WHERE session.id = eligible.session_id
      AND session.current_stage = 'ANSWER_EVALUATION'
      AND counts.supplied_count = counts.answer_count
      AND counts.evaluated_count = counts.answer_count
      AND counts.answer_count > 0
    RETURNING session.id
)
SELECT
    eligible.session_id                      AS "sessionId",
    counts.supplied_count                    AS "suppliedCount",
    counts.answer_count                      AS "answerCount",
    counts.evaluated_count                   AS "evaluatedCount",
    (
        counts.answer_count > 0
        AND counts.supplied_count = counts.answer_count
        AND counts.evaluated_count = counts.answer_count
    )                                        AS "complete",
    CASE
        WHEN counts.answer_count > 0
         AND counts.supplied_count = counts.answer_count
         AND counts.evaluated_count = counts.answer_count
            THEN 'RESULT_PERSISTENCE'
        ELSE 'ANSWER_EVALUATION'
    END                                      AS "currentStage"
FROM eligible
CROSS JOIN counts;
