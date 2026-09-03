WITH supplied AS
(
    SELECT
        NULLIF(BTRIM($1), '')                         AS contract_version,
        $2::UUID                                      AS request_id,
        $3::UUID                                      AS assessment_id,
        $4::UUID                                      AS extraction_id,
        NULLIF(BTRIM($5), '')                         AS workflow_execution_id
),
inserted AS
(
    INSERT INTO talentai.technical_interview_session
    (
        contract_version,
        request_id,
        assessment_id,
        extraction_id,
        initial_workflow_execution_id,
        claim_owner_workflow_execution_id,
        last_workflow_execution_id
    )
    SELECT
        contract_version,
        request_id,
        assessment_id,
        extraction_id,
        workflow_execution_id,
        workflow_execution_id,
        workflow_execution_id
    FROM supplied
    ON CONFLICT ON CONSTRAINT uq_technical_interview_session_handoff
    DO NOTHING
    RETURNING *
),
retried AS
(
    UPDATE talentai.technical_interview_session AS session
    SET
        claim_owner_workflow_execution_id = supplied.workflow_execution_id,
        last_workflow_execution_id = supplied.workflow_execution_id,
        status = 'RUNNING',
        attempt_count = session.attempt_count + 1,
        failure_category = NULL,
        failure_code = NULL,
        failure_message = NULL,
        retryable = NULL,
        failed_at = NULL,
        updated_at = now()
    FROM supplied
    WHERE session.contract_version = supplied.contract_version
      AND session.request_id = supplied.request_id
      AND session.assessment_id = supplied.assessment_id
      AND session.extraction_id = supplied.extraction_id
      AND session.status = 'FAILED'
      AND session.retryable = TRUE
      AND NOT EXISTS (SELECT 1 FROM inserted)
    RETURNING session.*
),
current_session AS
(
    SELECT * FROM inserted
    UNION ALL
    SELECT * FROM retried
    UNION ALL
    SELECT session.*
    FROM talentai.technical_interview_session AS session
    CROSS JOIN supplied
    WHERE session.contract_version = supplied.contract_version
      AND session.request_id = supplied.request_id
      AND session.assessment_id = supplied.assessment_id
      AND NOT EXISTS (SELECT 1 FROM inserted)
      AND NOT EXISTS (SELECT 1 FROM retried)
)
SELECT
    current_session.id                         AS "sessionId",
    CASE
        WHEN EXISTS (SELECT 1 FROM inserted)
            THEN 'CLAIMED_NEW'
        WHEN EXISTS (SELECT 1 FROM retried)
            THEN 'CLAIMED_RETRY'
        WHEN current_session.extraction_id <> supplied.extraction_id
            THEN 'HANDOFF_CONFLICT'
        WHEN current_session.status = 'COMPLETED'
            THEN 'COMPLETED_REPLAY'
        WHEN current_session.status = 'RUNNING'
         AND current_session.claim_owner_workflow_execution_id
             = supplied.workflow_execution_id
            THEN 'CLAIMED_CURRENT'
        WHEN current_session.status = 'RUNNING'
            THEN 'ALREADY_RUNNING'
        WHEN current_session.status = 'FAILED'
         AND current_session.retryable = FALSE
            THEN 'FAILED_NOT_RETRYABLE'
        ELSE 'CLAIM_REJECTED'
    END                                        AS "claimStatus",
    (
        current_session.extraction_id = supplied.extraction_id
        AND current_session.status = 'RUNNING'
        AND current_session.claim_owner_workflow_execution_id
            = supplied.workflow_execution_id
    )                                          AS "canContinue",
    current_session.status                     AS status,
    current_session.current_stage              AS "currentStage",
    current_session.attempt_count              AS "attemptCount",
    current_session.request_id                 AS "requestId",
    current_session.assessment_id              AS "assessmentId",
    current_session.extraction_id              AS "extractionId",
    current_session.failure_category           AS "failureCategory",
    current_session.failure_code               AS "failureCode",
    current_session.failure_message            AS "failureMessage",
    current_session.retryable                  AS retryable,
    current_session.started_at                 AS "startedAt",
    current_session.updated_at                 AS "updatedAt",
    current_session.completed_at               AS "completedAt",
    current_session.failed_at                  AS "failedAt"
FROM current_session
CROSS JOIN supplied;
