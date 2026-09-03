BEGIN;

ALTER TABLE talentai.technical_interview_session
    ADD COLUMN IF NOT EXISTS evaluation_payload JSONB;

ALTER TABLE talentai.technical_interview_session
    DROP CONSTRAINT IF EXISTS ck_technical_interview_session_evaluation_payload;

ALTER TABLE talentai.technical_interview_session
    ADD CONSTRAINT ck_technical_interview_session_evaluation_payload
    CHECK (
        evaluation_payload IS NULL
        OR (
            jsonb_typeof(evaluation_payload) = 'object'
            AND jsonb_typeof(evaluation_payload -> 'warnings') = 'array'
            AND jsonb_typeof(evaluation_payload -> 'interviewSummary') = 'string'
            AND LENGTH(BTRIM(evaluation_payload ->> 'interviewSummary')) > 0
        )
    );

COMMIT;
