DO $contract$
DECLARE
    missing_tables TEXT[];
    phase3_foreign_key_count INTEGER;
    session_column_count INTEGER;
BEGIN
    SELECT ARRAY_AGG(table_name ORDER BY table_name)
    INTO missing_tables
    FROM
    (
        VALUES
            ('technical_interview_session'),
            ('technical_question_set'),
            ('technical_interview_answer'),
            ('technical_interview_result')
    ) AS required(table_name)
    WHERE to_regclass('talentai.' || table_name) IS NULL;

    IF missing_tables IS NOT NULL THEN
        RAISE EXCEPTION
            'Technical interview persistence tables are missing: %',
            missing_tables;
    END IF;

    SELECT COUNT(*)
    INTO session_column_count
    FROM information_schema.columns
    WHERE table_schema = 'talentai'
      AND table_name = 'technical_interview_session'
      AND column_name IN
      (
          'id',
          'contract_version',
          'request_id',
          'assessment_id',
          'extraction_id',
          'initial_workflow_execution_id',
          'claim_owner_workflow_execution_id',
          'last_workflow_execution_id',
          'status',
          'current_stage',
          'attempt_count',
          'failure_category',
          'failure_code',
          'failure_message',
          'retryable',
          'evaluation_payload',
          'started_at',
          'updated_at',
          'completed_at',
          'failed_at'
      );

    IF session_column_count <> 20 THEN
        RAISE EXCEPTION
            'Technical interview session contract is incomplete: % columns',
            session_column_count;
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
      AND source_table.relname LIKE 'technical_%'
      AND target_schema.nspname = 'talentai'
      AND target_table.relname IN
          ('assessment_execution', 'grade_assessment', 'resume_extraction');

    IF phase3_foreign_key_count <> 0 THEN
        RAISE EXCEPTION
            'Phase 4/5 persistence must not create foreign keys into frozen Phase 3 tables';
    END IF;

    IF NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_session',
        'SELECT'
    ) OR NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_session',
        'INSERT'
    ) OR NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_session',
        'UPDATE'
    ) THEN
        RAISE EXCEPTION 'talentai_app session privileges are incomplete';
    END IF;

    IF NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_question_set',
        'SELECT'
    ) OR NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_question_set',
        'INSERT'
    ) OR has_table_privilege(
        'talentai_app',
        'talentai.technical_question_set',
        'UPDATE'
    ) THEN
        RAISE EXCEPTION 'Question sets must be append-only for talentai_app';
    END IF;

    IF NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_answer',
        'SELECT'
    ) OR NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_answer',
        'INSERT'
    ) OR NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_answer',
        'UPDATE'
    ) THEN
        RAISE EXCEPTION 'talentai_app answer privileges are incomplete';
    END IF;

    IF NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_result',
        'SELECT'
    ) OR NOT has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_result',
        'INSERT'
    ) OR has_table_privilege(
        'talentai_app',
        'talentai.technical_interview_result',
        'UPDATE'
    ) THEN
        RAISE EXCEPTION 'Interview results must be append-only for talentai_app';
    END IF;

    RAISE NOTICE 'Technical interview persistence contract assertions passed.';
END
$contract$;
