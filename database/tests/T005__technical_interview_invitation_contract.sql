DO $contract$
DECLARE
    invitation_column_count INTEGER;
    phase3_foreign_key_count INTEGER;
    raw_token_column_count INTEGER;
BEGIN
    IF to_regclass('talentai.technical_interview_invitation') IS NULL THEN
        RAISE EXCEPTION 'Technical interview invitation table is missing';
    END IF;

    SELECT COUNT(*)
    INTO invitation_column_count
    FROM information_schema.columns
    WHERE table_schema = 'talentai'
      AND table_name = 'technical_interview_invitation'
      AND column_name IN
      (
          'id',
          'contract_version',
          'request_id',
          'assessment_id',
          'extraction_id',
          'token_hash',
          'status',
          'issue_count',
          'issued_by_workflow_execution_id',
          'claimed_by_workflow_execution_id',
          'revoked_by_workflow_execution_id',
          'issued_at',
          'expires_at',
          'claimed_at',
          'revoked_at',
          'updated_at'
      );

    IF invitation_column_count <> 16 THEN
        RAISE EXCEPTION
            'Technical interview invitation contract is incomplete: % columns',
            invitation_column_count;
    END IF;

    SELECT COUNT(*)
    INTO raw_token_column_count
    FROM information_schema.columns
    WHERE table_schema = 'talentai'
      AND table_name = 'technical_interview_invitation'
      AND column_name IN
          ('token', 'invitation_token', 'token_value', 'raw_token');

    IF raw_token_column_count <> 0 THEN
        RAISE EXCEPTION 'Invitation persistence must not contain a raw-token column';
    END IF;

    SELECT COUNT(*)
    INTO phase3_foreign_key_count
    FROM pg_constraint AS constraint_definition
    JOIN pg_class AS source_table
      ON source_table.oid = constraint_definition.conrelid
    JOIN pg_namespace AS source_schema
      ON source_schema.oid = source_table.relnamespace
    JOIN pg_class AS target_table
      ON target_table.oid = constraint_definition.confrelid
    JOIN pg_namespace AS target_schema
      ON target_schema.oid = target_table.relnamespace
    WHERE constraint_definition.contype = 'f'
      AND source_schema.nspname = 'talentai'
      AND source_table.relname = 'technical_interview_invitation'
      AND target_schema.nspname = 'talentai'
      AND target_table.relname IN
          ('assessment_execution', 'grade_assessment', 'resume_extraction');

    IF phase3_foreign_key_count <> 0 THEN
        RAISE EXCEPTION
            'Invitation persistence must not create foreign keys into frozen Phase 3 tables';
    END IF;

    IF NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_invitation',
        'SELECT'
    ) OR NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_invitation',
        'INSERT'
    ) OR NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_invitation',
        'UPDATE'
    ) OR has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_invitation',
        'DELETE'
    ) THEN
        RAISE EXCEPTION 'talentai_app invitation privileges are incorrect';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'talentai.technical_interview_invitation'::regclass
          AND conname = 'uq_technical_interview_invitation_handoff'
          AND contype = 'u'
    ) THEN
        RAISE EXCEPTION 'Invitation handoff uniqueness constraint is missing';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'talentai.technical_interview_invitation'::regclass
          AND conname = 'uq_technical_interview_invitation_token_hash'
          AND contype = 'u'
    ) THEN
        RAISE EXCEPTION 'Invitation token-hash uniqueness constraint is missing';
    END IF;

    RAISE NOTICE 'Technical interview invitation contract assertions passed.';
END
$contract$;
