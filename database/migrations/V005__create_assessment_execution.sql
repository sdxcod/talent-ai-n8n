BEGIN;

CREATE TABLE IF NOT EXISTS talentai.assessment_execution
(
    request_id                     UUID                     NOT NULL,
    input_fingerprint              VARCHAR(64)              NOT NULL,
    initial_workflow_execution_id  VARCHAR(100)             NOT NULL,
    last_workflow_execution_id     VARCHAR(100)             NOT NULL,
    position_code                  VARCHAR(100)             NOT NULL,
    target_grade_code              VARCHAR(50)              NOT NULL,
    status                         VARCHAR(30)              NOT NULL DEFAULT 'RUNNING',
    current_stage                  VARCHAR(50)              NOT NULL DEFAULT 'INTAKE',
    attempt_count                  INTEGER                  NOT NULL DEFAULT 1,
    extraction_id                  UUID,
    assessment_id                  UUID,
    failure_category               VARCHAR(30),
    failure_code                   VARCHAR(100),
    failure_message                VARCHAR(1000),
    retryable                      BOOLEAN,
    started_at                     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at                     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    completed_at                   TIMESTAMP WITH TIME ZONE,
    failed_at                      TIMESTAMP WITH TIME ZONE,

    CONSTRAINT assessment_execution_pkey
        PRIMARY KEY (request_id),

    CONSTRAINT fk_assessment_execution_extraction
        FOREIGN KEY (extraction_id)
        REFERENCES talentai.resume_extraction (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assessment_execution_assessment
        FOREIGN KEY (assessment_id)
        REFERENCES talentai.grade_assessment (id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_assessment_execution_fingerprint
        CHECK (input_fingerprint ~ '^[0-9a-f]{64}$'),

    CONSTRAINT ck_assessment_execution_status
        CHECK (status IN ('RUNNING', 'COMPLETED', 'FAILED')),

    CONSTRAINT ck_assessment_execution_stage
        CHECK (
            current_stage IN (
                'INTAKE',
                'PROFILE_EXTRACTION',
                'GRADE_GUIDE_RESOLUTION',
                'EVIDENCE_SCORING',
                'ASSESSMENT_PERSISTENCE',
                'COMPLETED'
            )
        ),

    CONSTRAINT ck_assessment_execution_attempt_count
        CHECK (attempt_count >= 1),

    CONSTRAINT ck_assessment_execution_failure_category
        CHECK (
            failure_category IS NULL
            OR failure_category IN (
                'VALIDATION',
                'PROVIDER',
                'PERSISTENCE',
                'CONFIGURATION',
                'ORCHESTRATION'
            )
        ),

    CONSTRAINT ck_assessment_execution_timestamps
        CHECK (
            updated_at >= started_at
            AND (completed_at IS NULL OR completed_at >= started_at)
            AND (failed_at IS NULL OR failed_at >= started_at)
        ),

    CONSTRAINT ck_assessment_execution_lifecycle
        CHECK (
            (
                status = 'RUNNING'
                AND current_stage <> 'COMPLETED'
                AND completed_at IS NULL
                AND failed_at IS NULL
                AND failure_category IS NULL
                AND failure_code IS NULL
                AND failure_message IS NULL
                AND retryable IS NULL
            )
            OR
            (
                status = 'COMPLETED'
                AND current_stage = 'COMPLETED'
                AND extraction_id IS NOT NULL
                AND assessment_id IS NOT NULL
                AND completed_at IS NOT NULL
                AND failed_at IS NULL
                AND failure_category IS NULL
                AND failure_code IS NULL
                AND failure_message IS NULL
                AND retryable IS NULL
            )
            OR
            (
                status = 'FAILED'
                AND current_stage <> 'COMPLETED'
                AND completed_at IS NULL
                AND failed_at IS NOT NULL
                AND failure_category IS NOT NULL
                AND failure_code IS NOT NULL
                AND failure_message IS NOT NULL
                AND retryable IS NOT NULL
            )
        )
);

CREATE INDEX IF NOT EXISTS ix_assessment_execution_status_updated
    ON talentai.assessment_execution (status, updated_at DESC);

CREATE INDEX IF NOT EXISTS ix_assessment_execution_last_workflow
    ON talentai.assessment_execution (last_workflow_execution_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_assessment_execution_extraction
    ON talentai.assessment_execution (extraction_id)
    WHERE extraction_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_assessment_execution_assessment
    ON talentai.assessment_execution (assessment_id)
    WHERE assessment_id IS NOT NULL;

GRANT SELECT, INSERT, UPDATE
ON TABLE talentai.assessment_execution
TO talentai_app;

COMMIT;
