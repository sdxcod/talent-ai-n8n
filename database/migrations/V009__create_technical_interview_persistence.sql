BEGIN;

CREATE TABLE IF NOT EXISTS talentai.technical_interview_session
(
    id                                  UUID                     NOT NULL DEFAULT gen_random_uuid(),
    contract_version                    VARCHAR(20)              NOT NULL,
    request_id                          UUID                     NOT NULL,
    assessment_id                       UUID                     NOT NULL,
    extraction_id                       UUID                     NOT NULL,
    initial_workflow_execution_id       VARCHAR(100)             NOT NULL,
    claim_owner_workflow_execution_id   VARCHAR(100)             NOT NULL,
    last_workflow_execution_id          VARCHAR(100)             NOT NULL,
    status                              VARCHAR(30)              NOT NULL DEFAULT 'RUNNING',
    current_stage                       VARCHAR(50)              NOT NULL DEFAULT 'QUESTION_GENERATION',
    attempt_count                       INTEGER                  NOT NULL DEFAULT 1,
    failure_category                    VARCHAR(30),
    failure_code                        VARCHAR(100),
    failure_message                     VARCHAR(1000),
    retryable                           BOOLEAN,
    started_at                          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at                          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    completed_at                        TIMESTAMP WITH TIME ZONE,
    failed_at                           TIMESTAMP WITH TIME ZONE,

    CONSTRAINT technical_interview_session_pkey
        PRIMARY KEY (id),

    CONSTRAINT uq_technical_interview_session_handoff
        UNIQUE (contract_version, request_id, assessment_id),

    CONSTRAINT ck_technical_interview_session_contract
        CHECK (contract_version = '1.0.0'),

    CONSTRAINT ck_technical_interview_session_status
        CHECK (status IN ('RUNNING', 'COMPLETED', 'FAILED')),

    CONSTRAINT ck_technical_interview_session_stage
        CHECK (
            current_stage IN (
                'QUESTION_GENERATION',
                'FIRST_ROUND',
                'FOLLOW_UP_GENERATION',
                'FOLLOW_UP',
                'ANSWER_EVALUATION',
                'RESULT_PERSISTENCE',
                'COMPLETED'
            )
        ),

    CONSTRAINT ck_technical_interview_session_attempt
        CHECK (attempt_count >= 1),

    CONSTRAINT ck_technical_interview_session_failure_category
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

    CONSTRAINT ck_technical_interview_session_timestamps
        CHECK (
            updated_at >= started_at
            AND (completed_at IS NULL OR completed_at >= started_at)
            AND (failed_at IS NULL OR failed_at >= started_at)
        ),

    CONSTRAINT ck_technical_interview_session_lifecycle
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

CREATE INDEX IF NOT EXISTS ix_technical_interview_session_status_updated
    ON talentai.technical_interview_session (status, updated_at DESC);

CREATE INDEX IF NOT EXISTS ix_technical_interview_session_phase3_ids
    ON talentai.technical_interview_session (request_id, assessment_id, extraction_id);

CREATE TABLE IF NOT EXISTS talentai.technical_question_set
(
    id                          UUID                     NOT NULL DEFAULT gen_random_uuid(),
    session_id                  UUID                     NOT NULL,
    round                       VARCHAR(20)              NOT NULL,
    version                     INTEGER                  NOT NULL,
    content_hash                VARCHAR(64)              NOT NULL,
    question_plan               JSONB                    NOT NULL,
    question_count              INTEGER                  NOT NULL,
    generation_model            VARCHAR(100)             NOT NULL,
    prompt_version              VARCHAR(20)              NOT NULL,
    created_at                  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),

    CONSTRAINT technical_question_set_pkey
        PRIMARY KEY (id),

    CONSTRAINT fk_technical_question_set_session
        FOREIGN KEY (session_id)
        REFERENCES talentai.technical_interview_session (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_technical_question_set_version
        UNIQUE (session_id, round, version),

    CONSTRAINT uq_technical_question_set_content
        UNIQUE (session_id, round, content_hash),

    CONSTRAINT ck_technical_question_set_round
        CHECK (round IN ('FIRST', 'FOLLOW_UP')),

    CONSTRAINT ck_technical_question_set_version
        CHECK (version >= 1),

    CONSTRAINT ck_technical_question_set_hash
        CHECK (content_hash ~ '^[0-9a-f]{64}$'),

    CONSTRAINT ck_technical_question_set_plan
        CHECK (
            jsonb_typeof(question_plan) = 'object'
            AND jsonb_typeof(question_plan -> 'questions') = 'array'
            AND jsonb_array_length(question_plan -> 'questions') = question_count
            AND question_count > 0
        )
);

CREATE INDEX IF NOT EXISTS ix_technical_question_set_session_created
    ON talentai.technical_question_set (session_id, created_at DESC);

CREATE TABLE IF NOT EXISTS talentai.technical_interview_answer
(
    id                          UUID                     NOT NULL DEFAULT gen_random_uuid(),
    session_id                  UUID                     NOT NULL,
    question_set_id             UUID                     NOT NULL,
    round                       VARCHAR(20)              NOT NULL,
    question_id                 VARCHAR(40)              NOT NULL,
    dimension_code              VARCHAR(100)             NOT NULL,
    question_type               VARCHAR(30)              NOT NULL,
    answer_payload              JSONB                    NOT NULL,
    deterministic_score         NUMERIC(5, 2),
    model_score                 NUMERIC(5, 2),
    final_score                 NUMERIC(5, 2),
    rationale                   TEXT                     NOT NULL DEFAULT '',
    status                      VARCHAR(30)              NOT NULL DEFAULT 'SUBMITTED',
    submitted_at                TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    evaluated_at                TIMESTAMP WITH TIME ZONE,

    CONSTRAINT technical_interview_answer_pkey
        PRIMARY KEY (id),

    CONSTRAINT fk_technical_interview_answer_session
        FOREIGN KEY (session_id)
        REFERENCES talentai.technical_interview_session (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_technical_interview_answer_question_set
        FOREIGN KEY (question_set_id)
        REFERENCES talentai.technical_question_set (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_technical_interview_answer_question
        UNIQUE (session_id, round, question_id),

    CONSTRAINT ck_technical_interview_answer_round
        CHECK (round IN ('FIRST', 'FOLLOW_UP')),

    CONSTRAINT ck_technical_interview_answer_type
        CHECK (question_type IN ('single_choice', 'multi_choice', 'explanatory')),

    CONSTRAINT ck_technical_interview_answer_payload
        CHECK (jsonb_typeof(answer_payload) = 'object'),

    CONSTRAINT ck_technical_interview_answer_scores
        CHECK (
            (deterministic_score IS NULL OR deterministic_score BETWEEN 0 AND 4)
            AND (model_score IS NULL OR model_score BETWEEN 0 AND 4)
            AND (final_score IS NULL OR final_score BETWEEN 0 AND 4)
        ),

    CONSTRAINT ck_technical_interview_answer_status
        CHECK (status IN ('SUBMITTED', 'EVALUATED')),

    CONSTRAINT ck_technical_interview_answer_evaluation
        CHECK (
            (status = 'SUBMITTED' AND evaluated_at IS NULL)
            OR
            (status = 'EVALUATED' AND final_score IS NOT NULL AND evaluated_at IS NOT NULL)
        )
);

CREATE INDEX IF NOT EXISTS ix_technical_interview_answer_session_round
    ON talentai.technical_interview_answer (session_id, round, question_id);

CREATE TABLE IF NOT EXISTS talentai.technical_interview_result
(
    id                          UUID                     NOT NULL DEFAULT gen_random_uuid(),
    session_id                  UUID                     NOT NULL,
    result_version              INTEGER                  NOT NULL DEFAULT 1,
    workflow_execution_id       VARCHAR(100)             NOT NULL,
    assigned_grade_code         VARCHAR(50)              NOT NULL,
    overall_score               NUMERIC(5, 2)            NOT NULL,
    dimension_scores            JSONB                    NOT NULL,
    grade_checks                JSONB                    NOT NULL,
    interview_summary           TEXT                     NOT NULL,
    warnings                    JSONB                    NOT NULL DEFAULT '[]'::JSONB,
    result_payload              JSONB                    NOT NULL,
    status                      VARCHAR(30)              NOT NULL DEFAULT 'COMPLETED',
    created_at                  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),

    CONSTRAINT technical_interview_result_pkey
        PRIMARY KEY (id),

    CONSTRAINT fk_technical_interview_result_session
        FOREIGN KEY (session_id)
        REFERENCES talentai.technical_interview_session (id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_technical_interview_result_session_version
        UNIQUE (session_id, result_version),

    CONSTRAINT uq_technical_interview_result_workflow
        UNIQUE (workflow_execution_id),

    CONSTRAINT ck_technical_interview_result_version
        CHECK (result_version >= 1),

    CONSTRAINT ck_technical_interview_result_score
        CHECK (overall_score BETWEEN 0 AND 100),

    CONSTRAINT ck_technical_interview_result_json
        CHECK (
            jsonb_typeof(dimension_scores) = 'array'
            AND jsonb_typeof(grade_checks) = 'array'
            AND jsonb_typeof(warnings) = 'array'
            AND jsonb_typeof(result_payload) = 'object'
        ),

    CONSTRAINT ck_technical_interview_result_status
        CHECK (status = 'COMPLETED')
);

CREATE INDEX IF NOT EXISTS ix_technical_interview_result_session_created
    ON talentai.technical_interview_result (session_id, created_at DESC);

GRANT SELECT, INSERT, UPDATE
ON TABLE talentai.technical_interview_session
TO talentai_app;

GRANT SELECT, INSERT
ON TABLE talentai.technical_question_set
TO talentai_app;

GRANT SELECT, INSERT, UPDATE
ON TABLE talentai.technical_interview_answer
TO talentai_app;

GRANT SELECT, INSERT
ON TABLE talentai.technical_interview_result
TO talentai_app;

COMMIT;
