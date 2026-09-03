WITH supplied AS
(
    SELECT
        $1::UUID                              AS session_id,
        NULLIF(BTRIM($2), '')                 AS workflow_execution_id,
        $3::JSONB                             AS result_payload
),
eligible AS
(
    SELECT supplied.*, session.current_stage
    FROM supplied
    JOIN talentai.technical_interview_session AS session
      ON session.id = supplied.session_id
     AND session.status IN ('RUNNING', 'COMPLETED')
     AND session.current_stage IN ('RESULT_PERSISTENCE', 'COMPLETED')
     AND session.claim_owner_workflow_execution_id
         = supplied.workflow_execution_id
    WHERE jsonb_typeof(supplied.result_payload) = 'object'
      AND jsonb_typeof(supplied.result_payload #> '{score,dimensions}')
          = 'array'
      AND jsonb_typeof(supplied.result_payload -> 'gradeChecks') = 'array'
      AND jsonb_typeof(supplied.result_payload #> '{interview,warnings}')
          = 'array'
      AND NOT EXISTS
      (
          SELECT 1
          FROM talentai.technical_interview_answer AS answer
          WHERE answer.session_id = supplied.session_id
            AND answer.status <> 'EVALUATED'
      )
),
existing AS
(
    SELECT result.*
    FROM talentai.technical_interview_result AS result
    JOIN eligible
      ON result.session_id = eligible.session_id
     AND result.result_version = 1
     AND result.result_payload = eligible.result_payload
),
inserted AS
(
    INSERT INTO talentai.technical_interview_result
    (
        session_id,
        result_version,
        workflow_execution_id,
        assigned_grade_code,
        overall_score,
        dimension_scores,
        grade_checks,
        interview_summary,
        warnings,
        result_payload
    )
    SELECT
        eligible.session_id,
        1,
        eligible.workflow_execution_id,
        eligible.result_payload #>> '{assignedGrade,code}',
        (eligible.result_payload #>> '{score,overall}')::NUMERIC,
        eligible.result_payload #> '{score,dimensions}',
        eligible.result_payload -> 'gradeChecks',
        eligible.result_payload #>> '{interview,summary}',
        eligible.result_payload #> '{interview,warnings}',
        eligible.result_payload
    FROM eligible
    WHERE eligible.current_stage = 'RESULT_PERSISTENCE'
      AND NOT EXISTS (SELECT 1 FROM existing)
    ON CONFLICT ON CONSTRAINT uq_technical_interview_result_session_version
    DO NOTHING
    RETURNING *
),
resolved AS
(
    SELECT existing.*, FALSE AS was_inserted FROM existing
    UNION ALL
    SELECT inserted.*, TRUE AS was_inserted FROM inserted
),
completed AS
(
    UPDATE talentai.technical_interview_session AS session
    SET
        status = 'COMPLETED',
        current_stage = 'COMPLETED',
        last_workflow_execution_id = eligible.workflow_execution_id,
        failure_category = NULL,
        failure_code = NULL,
        failure_message = NULL,
        retryable = NULL,
        failed_at = NULL,
        updated_at = now(),
        completed_at = COALESCE(session.completed_at, now())
    FROM eligible
    WHERE session.id = eligible.session_id
      AND EXISTS (SELECT 1 FROM resolved)
    RETURNING session.*
)
SELECT
    resolved.id                              AS "resultId",
    resolved.session_id                      AS "sessionId",
    resolved.result_version                  AS "resultVersion",
    resolved.assigned_grade_code             AS "assignedGradeCode",
    resolved.overall_score                   AS "overallScore",
    resolved.result_payload                  AS "resultPayload",
    resolved.was_inserted                    AS "wasInserted",
    completed.status                         AS status,
    completed.current_stage                  AS "currentStage",
    completed.attempt_count                  AS "attemptCount",
    completed.completed_at                   AS "completedAt"
FROM resolved
JOIN completed ON completed.id = resolved.session_id;
