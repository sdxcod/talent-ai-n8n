WITH expired AS
(
    UPDATE talentai.assessment_execution AS execution
    SET
        status = 'FAILED',
        failure_category = 'ORCHESTRATION',
        failure_code = 'EXECUTION_TIMEOUT',
        failure_message =
            'Assessment execution exceeded its workflow timeout.',
        retryable = TRUE,
        failed_at = now(),
        updated_at = now()
    WHERE execution.status = 'RUNNING'
      AND execution.updated_at < now() - make_interval(secs => $1::INTEGER)
    RETURNING execution.request_id
)
SELECT COUNT(*)::INTEGER AS "expiredExecutionCount"
FROM expired;
