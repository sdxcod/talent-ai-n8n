BEGIN;

DO $contract_test$
DECLARE
    v_completed_request_id UUID := '10000000-0000-4000-8000-000000000001';
    v_failed_request_id UUID := '10000000-0000-4000-8000-000000000002';
    v_invalid_request_id UUID := '10000000-0000-4000-8000-000000000003';
    v_extraction_id UUID := '20000000-0000-4000-8000-000000000001';
    v_assessment_id UUID := '30000000-0000-4000-8000-000000000001';
    v_active_guide_id UUID;
    actual_status VARCHAR(30);
    actual_stage VARCHAR(50);
    actual_failure_code VARCHAR(100);
BEGIN
    SELECT id
    INTO STRICT v_active_guide_id
    FROM talentai.grade_guide
    WHERE position_code = 'JAVA_BACKEND'
      AND status = 'ACTIVE';

    INSERT INTO talentai.resume_extraction
    (
        id,
        workflow_execution_id,
        position_code,
        source_file_name,
        extraction_model,
        profile,
        target_grade_code,
        job_description,
        status,
        profile_schema_version
    )
    VALUES
    (
        v_extraction_id,
        'contract-test-extraction-1',
        'JAVA_BACKEND',
        'contract-test.pdf',
        'contract-test-model',
        '{"candidate":{"fullName":"Contract Test"}}'::JSONB,
        'MID',
        'Synthetic rollback-only contract test job description.',
        'EXTRACTED',
        '1.0'
    );

    INSERT INTO talentai.grade_assessment
    (
        id,
        workflow_execution_id,
        extraction_id,
        grade_guide_id,
        grade_guide_version,
        target_grade_code,
        scoring_model,
        prompt_version,
        engine_version,
        dimension_assessments,
        overall_score,
        minimum_overall_score,
        threshold_met,
        mandatory_dimensions_met,
        decision,
        review_reasons,
        model_warnings,
        assessment_summary,
        status
    )
    VALUES
    (
        v_assessment_id,
        'contract-test-assessment-1',
        v_extraction_id,
        v_active_guide_id,
        '1.0.0',
        'MID',
        'contract-test-model',
        '1.0',
        '1.0',
        '[{"code":"CONTRACT_TEST"}]'::JSONB,
        50,
        60,
        FALSE,
        FALSE,
        'BELOW_TARGET',
        '[]'::JSONB,
        '[]'::JSONB,
        'Synthetic rollback-only contract test assessment.',
        'COMPLETED'
    );

    INSERT INTO talentai.assessment_execution
    (
        request_id,
        input_fingerprint,
        initial_workflow_execution_id,
        last_workflow_execution_id,
        position_code,
        target_grade_code,
        status,
        current_stage,
        extraction_id
    )
    VALUES
    (
        v_completed_request_id,
        repeat('a', 64),
        'contract-test-root-1',
        'contract-test-grade-1',
        'JAVA_BACKEND',
        'MID',
        'RUNNING',
        'ASSESSMENT_PERSISTENCE',
        v_extraction_id
    );

    UPDATE talentai.assessment_execution
    SET
        last_workflow_execution_id = 'contract-test-grade-1',
        assessment_id = v_assessment_id,
        status = 'COMPLETED',
        current_stage = 'COMPLETED',
        completed_at = now(),
        updated_at = now()
    WHERE request_id = v_completed_request_id;

    SELECT status, current_stage
    INTO actual_status, actual_stage
    FROM talentai.assessment_execution
    WHERE request_id = v_completed_request_id;

    IF actual_status <> 'COMPLETED'
       OR actual_stage <> 'COMPLETED' THEN
        RAISE EXCEPTION
            'Completed lifecycle assertion failed: status %, stage %',
            actual_status,
            actual_stage;
    END IF;

    BEGIN
        INSERT INTO talentai.assessment_execution
        (
            request_id,
            input_fingerprint,
            initial_workflow_execution_id,
            last_workflow_execution_id,
            position_code,
            target_grade_code,
            status,
            current_stage
        )
        VALUES
        (
            v_completed_request_id,
            repeat('b', 64),
            'contract-test-duplicate',
            'contract-test-duplicate',
            'JAVA_BACKEND',
            'MID',
            'RUNNING',
            'INTAKE'
        );

        RAISE EXCEPTION 'Duplicate request_id was unexpectedly accepted';
    EXCEPTION
        WHEN unique_violation THEN
            NULL;
    END;

    INSERT INTO talentai.assessment_execution
    (
        request_id,
        input_fingerprint,
        initial_workflow_execution_id,
        last_workflow_execution_id,
        position_code,
        target_grade_code,
        status,
        current_stage
    )
    VALUES
    (
        v_failed_request_id,
        repeat('c', 64),
        'contract-test-root-2',
        'contract-test-root-2',
        'JAVA_BACKEND',
        'SENIOR',
        'RUNNING',
        'PROFILE_EXTRACTION'
    );

    UPDATE talentai.assessment_execution
    SET
        status = 'FAILED',
        failure_category = 'PROVIDER',
        failure_code = 'PROVIDER_TEMPORARILY_UNAVAILABLE',
        failure_message = 'Provider request failed; private payload omitted.',
        retryable = TRUE,
        failed_at = now(),
        updated_at = now()
    WHERE request_id = v_failed_request_id;

    SELECT status, current_stage, failure_code
    INTO actual_status, actual_stage, actual_failure_code
    FROM talentai.assessment_execution
    WHERE request_id = v_failed_request_id;

    IF actual_status <> 'FAILED'
       OR actual_stage <> 'PROFILE_EXTRACTION'
       OR actual_failure_code <> 'PROVIDER_TEMPORARILY_UNAVAILABLE' THEN
        RAISE EXCEPTION
            'Failed lifecycle assertion failed: status %, stage %, code %',
            actual_status,
            actual_stage,
            actual_failure_code;
    END IF;

    BEGIN
        INSERT INTO talentai.assessment_execution
        (
            request_id,
            input_fingerprint,
            initial_workflow_execution_id,
            last_workflow_execution_id,
            position_code,
            target_grade_code,
            status,
            current_stage,
            completed_at
        )
        VALUES
        (
            v_invalid_request_id,
            repeat('d', 64),
            'contract-test-invalid',
            'contract-test-invalid',
            'JAVA_BACKEND',
            'MID',
            'COMPLETED',
            'COMPLETED',
            now()
        );

        RAISE EXCEPTION 'Invalid completed lifecycle was unexpectedly accepted';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    IF NOT has_table_privilege(
        'talentai_app',
        'talentai.assessment_execution',
        'SELECT,INSERT,UPDATE'
    ) THEN
        RAISE EXCEPTION
            'talentai_app is missing assessment_execution runtime privileges';
    END IF;

    RAISE NOTICE 'Assessment execution contract assertions passed.';
END
$contract_test$;

ROLLBACK;
