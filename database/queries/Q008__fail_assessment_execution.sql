UPDATE talentai.assessment_execution AS execution
SET
    last_workflow_execution_id = NULLIF($2, ''),
    current_stage = UPPER(BTRIM($3)),
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
    failed_at = now(),
    updated_at = now()
WHERE execution.request_id = $1::UUID
  AND execution.status = 'RUNNING'
  AND NULLIF($2, '') IS NOT NULL
  AND NULLIF(BTRIM($3), '') IS NOT NULL
  AND NULLIF(BTRIM($4), '') IS NOT NULL
  AND NULLIF(BTRIM($5), '') IS NOT NULL
  AND NULLIF(BTRIM($6), '') IS NOT NULL
RETURNING
    execution.request_id                 AS "requestId",
    execution.status,
    execution.current_stage              AS "currentStage",
    execution.attempt_count              AS "attemptCount",
    execution.extraction_id              AS "extractionId",
    execution.failure_category           AS "failureCategory",
    execution.failure_code               AS "failureCode",
    execution.failure_message            AS "failureMessage",
    execution.retryable,
    execution.started_at                 AS "startedAt",
    execution.failed_at                  AS "failedAt";
