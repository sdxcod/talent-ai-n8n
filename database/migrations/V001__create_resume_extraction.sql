BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS talentai;

CREATE TABLE IF NOT EXISTS talentai.resume_extraction
(
    id                      UUID                     NOT NULL DEFAULT gen_random_uuid(),
    workflow_execution_id   VARCHAR(100)             NOT NULL,
    position_code           VARCHAR(100)             NOT NULL,
    source_file_name        VARCHAR(500)             NOT NULL,
    extraction_model        VARCHAR(100)             NOT NULL,
    profile                 JSONB                    NOT NULL,
    status                  VARCHAR(30)              NOT NULL DEFAULT 'EXTRACTED',
    created_at              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    target_grade_code       VARCHAR(50)              NOT NULL DEFAULT 'UNSPECIFIED',
    job_description         TEXT                     NOT NULL DEFAULT '',
    profile_schema_version  VARCHAR(20)              NOT NULL DEFAULT '1.0',

    CONSTRAINT resume_extraction_pkey
        PRIMARY KEY (id),

    CONSTRAINT resume_extraction_workflow_execution_id_key
        UNIQUE (workflow_execution_id),

    CONSTRAINT ck_resume_extraction_status
        CHECK (status IN ('EXTRACTED', 'VALIDATION_FAILED'))
);

COMMIT;
