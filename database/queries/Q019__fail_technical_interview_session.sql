UPDATE talentai.technical_interview_session AS session
SET
    last_workflow_execution_id = NULLIF(BTRIM($2), ''),
    current_stage = COALESCE(
        NULLIF(UPPER(BTRIM($3)), ''),
        session.current_stage
    ),
    status = 'FAILED',
    failure_category = UPPER(BTRIM($4)),
    failure_code = UPPER(BTRIM($5)),
    failure_message = LEFT(
        REGEXP_REPLACE(
            BTRIM($6),
            '[\r\n\t]+',
            ' ',
            'g'
        ),
        1000
    ),
    retryable = $7::BOOLEAN,
    completed_at = NULL,
    failed_at = now(),
    updated_at = now()
WHERE session.id = $1::UUID
  AND session.status = 'RUNNING'
  AND NULLIF(BTRIM($2), '') IS NOT NULL
  AND session.claim_owner_workflow_execution_id = NULLIF(BTRIM($2), '')
  AND NULLIF(BTRIM($4), '') IS NOT NULL
  AND NULLIF(BTRIM($5), '') IS NOT NULL
  AND NULLIF(BTRIM($6), '') IS NOT NULL
RETURNING
    session.id                         AS "sessionId",
    session.request_id                 AS "requestId",
    session.assessment_id              AS "assessmentId",
    session.extraction_id              AS "extractionId",
    session.status,
    session.current_stage              AS "currentStage",
    session.attempt_count              AS "attemptCount",
    session.failure_category           AS "failureCategory",
    session.failure_code               AS "failureCode",
    session.failure_message            AS "failureMessage",
    session.retryable,
    session.started_at                 AS "startedAt",
    session.failed_at                  AS "failedAt";
