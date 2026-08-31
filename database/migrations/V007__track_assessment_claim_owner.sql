BEGIN;

ALTER TABLE talentai.assessment_execution
    ADD COLUMN IF NOT EXISTS claim_owner_workflow_execution_id VARCHAR(100);

UPDATE talentai.assessment_execution
SET claim_owner_workflow_execution_id = initial_workflow_execution_id
WHERE claim_owner_workflow_execution_id IS NULL;

ALTER TABLE talentai.assessment_execution
    ALTER COLUMN claim_owner_workflow_execution_id SET NOT NULL;

DO $migration$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'talentai.assessment_execution'::regclass
          AND conname = 'ck_assessment_execution_claim_owner'
    ) THEN
        ALTER TABLE talentai.assessment_execution
            ADD CONSTRAINT ck_assessment_execution_claim_owner
            CHECK (BTRIM(claim_owner_workflow_execution_id) <> '');
    END IF;
END
$migration$;

COMMIT;
