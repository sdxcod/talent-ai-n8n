BEGIN;

CREATE TABLE IF NOT EXISTS talentai.grade_assessment
(
    id                         UUID                     NOT NULL DEFAULT gen_random_uuid(),
    workflow_execution_id      VARCHAR(100)             NOT NULL,
    extraction_id              UUID                     NOT NULL,
    grade_guide_id             UUID                     NOT NULL,
    grade_guide_version        VARCHAR(50)              NOT NULL,
    target_grade_code          VARCHAR(50)              NOT NULL,
    scoring_model              VARCHAR(100)             NOT NULL,
    prompt_version             VARCHAR(20)              NOT NULL,
    engine_version             VARCHAR(20)              NOT NULL,
    dimension_assessments      JSONB                    NOT NULL,
    overall_score              NUMERIC(5, 2)            NOT NULL,
    minimum_overall_score      NUMERIC(5, 2)            NOT NULL,
    threshold_met              BOOLEAN                  NOT NULL,
    mandatory_dimensions_met   BOOLEAN                  NOT NULL,
    decision                   VARCHAR(30)              NOT NULL,
    review_reasons             JSONB                    NOT NULL DEFAULT '[]'::JSONB,
    model_warnings             JSONB                    NOT NULL DEFAULT '[]'::JSONB,
    assessment_summary         TEXT                     NOT NULL,
    status                     VARCHAR(30)              NOT NULL DEFAULT 'COMPLETED',
    created_at                 TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),

    CONSTRAINT grade_assessment_pkey
        PRIMARY KEY (id),

    CONSTRAINT uq_grade_assessment_workflow_execution
        UNIQUE (workflow_execution_id),

    CONSTRAINT fk_grade_assessment_extraction
        FOREIGN KEY (extraction_id)
        REFERENCES talentai.resume_extraction (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_grade_assessment_grade_guide
        FOREIGN KEY (grade_guide_id)
        REFERENCES talentai.grade_guide (id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_grade_assessment_overall_score
        CHECK (overall_score >= 0 AND overall_score <= 100),

    CONSTRAINT ck_grade_assessment_minimum_score
        CHECK (minimum_overall_score >= 0 AND minimum_overall_score <= 100),

    CONSTRAINT ck_grade_assessment_decision
        CHECK (decision IN ('MEETS_TARGET', 'BELOW_TARGET', 'REVIEW_REQUIRED')),

    CONSTRAINT ck_grade_assessment_status
        CHECK (status = 'COMPLETED'),

    CONSTRAINT ck_grade_assessment_dimensions_array
        CHECK (
            jsonb_typeof(dimension_assessments) = 'array'
            AND jsonb_array_length(dimension_assessments) > 0
        ),

    CONSTRAINT ck_grade_assessment_review_reasons_array
        CHECK (jsonb_typeof(review_reasons) = 'array'),

    CONSTRAINT ck_grade_assessment_model_warnings_array
        CHECK (jsonb_typeof(model_warnings) = 'array')
);

CREATE INDEX IF NOT EXISTS ix_grade_assessment_extraction_created
    ON talentai.grade_assessment (extraction_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_grade_assessment_decision
    ON talentai.grade_assessment (decision, created_at DESC);

GRANT SELECT, INSERT ON talentai.grade_assessment TO talentai_app;

COMMIT;
