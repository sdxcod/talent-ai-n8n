WITH supplied AS
(
    SELECT
        COALESCE(
            NULLIF(BTRIM($1), '')::UUID,
            gen_random_uuid()
        ) AS request_id,
        encode(
            digest(COALESCE($2, ''), 'sha256'),
            'hex'
        ) AS input_fingerprint,
        NULLIF(BTRIM($3), '')          AS workflow_execution_id,
        UPPER(BTRIM($4))              AS position_code,
        UPPER(BTRIM($5))              AS target_grade_code
),
upserted AS
(
    INSERT INTO talentai.assessment_execution AS existing
    (
        request_id,
        input_fingerprint,
        initial_workflow_execution_id,
        last_workflow_execution_id,
        position_code,
        target_grade_code,
        status,
        current_stage
    )
    SELECT
        request_id,
        input_fingerprint,
        workflow_execution_id,
        workflow_execution_id,
        position_code,
        target_grade_code,
        'RUNNING',
        'PROFILE_EXTRACTION'
    FROM supplied
    ON CONFLICT ON CONSTRAINT assessment_execution_pkey
    DO UPDATE SET
        last_workflow_execution_id =
            CASE
                WHEN existing.input_fingerprint = EXCLUDED.input_fingerprint
                 AND existing.status = 'FAILED'
                 AND existing.retryable = TRUE
                    THEN EXCLUDED.last_workflow_execution_id
                ELSE existing.last_workflow_execution_id
            END,
        status =
            CASE
                WHEN existing.input_fingerprint = EXCLUDED.input_fingerprint
                 AND existing.status = 'FAILED'
                 AND existing.retryable = TRUE
                    THEN 'RUNNING'
                ELSE existing.status
            END,
        current_stage =
            CASE
                WHEN existing.input_fingerprint = EXCLUDED.input_fingerprint
                 AND existing.status = 'FAILED'
                 AND existing.retryable = TRUE
                    THEN CASE
                        WHEN existing.extraction_id IS NULL
                            THEN 'PROFILE_EXTRACTION'
                        ELSE 'GRADE_GUIDE_RESOLUTION'
                    END
                ELSE existing.current_stage
            END,
        attempt_count =
            CASE
                WHEN existing.input_fingerprint = EXCLUDED.input_fingerprint
                 AND existing.status = 'FAILED'
                 AND existing.retryable = TRUE
                    THEN existing.attempt_count + 1
                ELSE existing.attempt_count
            END,
        failure_category =
            CASE
                WHEN existing.input_fingerprint = EXCLUDED.input_fingerprint
                 AND existing.status = 'FAILED'
                 AND existing.retryable = TRUE
                    THEN NULL
                ELSE existing.failure_category
            END,
        failure_code =
            CASE
                WHEN existing.input_fingerprint = EXCLUDED.input_fingerprint
                 AND existing.status = 'FAILED'
                 AND existing.retryable = TRUE
                    THEN NULL
                ELSE existing.failure_code
            END,
        failure_message =
            CASE
                WHEN existing.input_fingerprint = EXCLUDED.input_fingerprint
                 AND existing.status = 'FAILED'
                 AND existing.retryable = TRUE
                    THEN NULL
                ELSE existing.failure_message
            END,
        retryable =
            CASE
                WHEN existing.input_fingerprint = EXCLUDED.input_fingerprint
                 AND existing.status = 'FAILED'
                 AND existing.retryable = TRUE
                    THEN NULL
                ELSE existing.retryable
            END,
        failed_at =
            CASE
                WHEN existing.input_fingerprint = EXCLUDED.input_fingerprint
                 AND existing.status = 'FAILED'
                 AND existing.retryable = TRUE
                    THEN NULL
                ELSE existing.failed_at
            END,
        updated_at =
            CASE
                WHEN existing.input_fingerprint = EXCLUDED.input_fingerprint
                 AND existing.status = 'FAILED'
                 AND existing.retryable = TRUE
                    THEN now()
                ELSE existing.updated_at
            END
    RETURNING existing.*
)
SELECT
    upserted.request_id                    AS "requestId",
    CASE
        WHEN upserted.input_fingerprint <> supplied.input_fingerprint
            THEN 'IDEMPOTENCY_CONFLICT'
        WHEN upserted.status = 'COMPLETED'
            THEN 'COMPLETED_REPLAY'
        WHEN upserted.status = 'FAILED'
         AND upserted.retryable = FALSE
            THEN 'FAILED_NOT_RETRYABLE'
        WHEN upserted.status = 'RUNNING'
         AND upserted.last_workflow_execution_id
             <> supplied.workflow_execution_id
            THEN 'ALREADY_RUNNING'
        WHEN upserted.status = 'RUNNING'
         AND upserted.attempt_count = 1
            THEN 'CLAIMED_NEW'
        WHEN upserted.status = 'RUNNING'
            THEN 'CLAIMED_RETRY'
        ELSE 'CLAIM_REJECTED'
    END                                      AS "claimStatus",
    (
        upserted.status = 'RUNNING'
        AND upserted.last_workflow_execution_id
            = supplied.workflow_execution_id
    )                                         AS "canContinue",
    upserted.status                            AS status,
    upserted.current_stage                     AS "currentStage",
    upserted.attempt_count                     AS "attemptCount",
    upserted.extraction_id                     AS "extractionId",
    upserted.assessment_id                     AS "assessmentId",
    upserted.failure_category                  AS "failureCategory",
    upserted.failure_code                      AS "failureCode",
    upserted.failure_message                   AS "failureMessage",
    upserted.retryable                         AS retryable,
    upserted.started_at                        AS "startedAt",
    upserted.updated_at                        AS "updatedAt",
    upserted.completed_at                      AS "completedAt",
    upserted.failed_at                         AS "failedAt"
FROM upserted
CROSS JOIN supplied;
