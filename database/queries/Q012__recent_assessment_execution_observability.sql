SELECT
    request_id                    AS "requestId",
    status,
    current_stage                 AS "currentStage",
    attempt_count                 AS "attemptCount",
    position_code                 AS "positionCode",
    target_grade_code             AS "targetGradeCode",
    failure_category              AS "failureCategory",
    failure_code                  AS "failureCode",
    retryable,
    duration_seconds              AS "durationSeconds",
    stale,
    started_at                    AS "startedAt",
    updated_at                    AS "updatedAt",
    completed_at                  AS "completedAt",
    failed_at                     AS "failedAt"
FROM talentai.assessment_execution_observability
WHERE ($1 = '' OR status = UPPER(BTRIM($1)))
ORDER BY started_at DESC
LIMIT LEAST(GREATEST($2::INTEGER, 1), 200);
