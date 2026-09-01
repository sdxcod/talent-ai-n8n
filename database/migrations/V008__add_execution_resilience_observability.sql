BEGIN;

CREATE OR REPLACE VIEW talentai.assessment_execution_observability AS
SELECT
    execution.request_id,
    execution.status,
    execution.current_stage,
    execution.attempt_count,
    execution.position_code,
    execution.target_grade_code,
    execution.initial_workflow_execution_id,
    execution.claim_owner_workflow_execution_id,
    execution.last_workflow_execution_id,
    execution.failure_category,
    execution.failure_code,
    execution.retryable,
    execution.started_at,
    execution.updated_at,
    execution.completed_at,
    execution.failed_at,
    ROUND(
        EXTRACT(
            EPOCH FROM (
                COALESCE(
                    execution.completed_at,
                    execution.failed_at,
                    now()
                ) - execution.started_at
            )
        )::NUMERIC,
        3
    ) AS duration_seconds,
    (
        execution.status = 'RUNNING'
        AND execution.updated_at < now() - INTERVAL '6 minutes'
    ) AS stale,
    execution.extraction_id,
    execution.assessment_id
FROM talentai.assessment_execution AS execution;

GRANT SELECT
ON talentai.assessment_execution_observability
TO talentai_app;

COMMIT;
