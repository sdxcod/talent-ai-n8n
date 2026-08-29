BEGIN;

CREATE TABLE IF NOT EXISTS talentai.grade_guide
(
    id                    UUID                     NOT NULL DEFAULT gen_random_uuid(),
    position_code         VARCHAR(100)             NOT NULL,
    guide_version         VARCHAR(50)              NOT NULL,
    guide_schema_version  VARCHAR(20)              NOT NULL DEFAULT '1.0',
    status                VARCHAR(30)              NOT NULL DEFAULT 'DRAFT',
    guide                 JSONB                    NOT NULL,
    created_at            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    activated_at          TIMESTAMP WITH TIME ZONE,

    CONSTRAINT grade_guide_pkey
        PRIMARY KEY (id),

    CONSTRAINT uq_grade_guide_position_version
        UNIQUE (position_code, guide_version),

    CONSTRAINT ck_grade_guide_status
        CHECK (status IN ('DRAFT', 'ACTIVE', 'ARCHIVED')),

    CONSTRAINT ck_grade_guide_active_timestamp
        CHECK (status <> 'ACTIVE' OR activated_at IS NOT NULL),

    CONSTRAINT ck_grade_guide_document_object
        CHECK (jsonb_typeof(guide) = 'object'),

    CONSTRAINT ck_grade_guide_position_matches_document
        CHECK (guide ->> 'positionCode' = position_code),

    CONSTRAINT ck_grade_guide_version_matches_document
        CHECK (guide ->> 'guideVersion' = guide_version),

    CONSTRAINT ck_grade_guide_has_grades
        CHECK (
            jsonb_typeof(guide -> 'grades') = 'array'
            AND jsonb_array_length(guide -> 'grades') > 0
        ),

    CONSTRAINT ck_grade_guide_has_dimensions
        CHECK (
            jsonb_typeof(guide -> 'dimensions') = 'array'
            AND jsonb_array_length(guide -> 'dimensions') > 0
        )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_grade_guide_one_active_per_position
    ON talentai.grade_guide (position_code)
    WHERE status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS ix_grade_guide_lookup
    ON talentai.grade_guide (position_code, status, guide_version);

GRANT USAGE ON SCHEMA talentai TO talentai_app;
GRANT SELECT ON talentai.grade_guide TO talentai_app;

COMMIT;
