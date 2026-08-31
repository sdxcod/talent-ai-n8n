BEGIN;

ALTER TABLE talentai.grade_assessment
    ADD COLUMN IF NOT EXISTS request_id UUID;

DO $migration$
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'talentai.grade_assessment'::regclass
          AND conname = 'fk_grade_assessment_execution'
    ) THEN
        ALTER TABLE talentai.grade_assessment
            ADD CONSTRAINT fk_grade_assessment_execution
            FOREIGN KEY (request_id)
            REFERENCES talentai.assessment_execution (request_id)
            ON DELETE RESTRICT;
    END IF;
END
$migration$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_grade_assessment_request
    ON talentai.grade_assessment (request_id)
    WHERE request_id IS NOT NULL;

COMMIT;
