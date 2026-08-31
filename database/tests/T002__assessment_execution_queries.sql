DO $query_contract_test$
DECLARE
    v_completed_request_id UUID := '40000000-0000-4000-8000-000000000001';
    v_retry_request_id UUID := '40000000-0000-4000-8000-000000000002';
    v_extraction_id UUID := '50000000-0000-4000-8000-000000000001';
    v_assessment_id UUID;
    v_active_guide_id UUID;
    v_result RECORD;
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
        'query-contract-extraction-1',
        'JAVA_BACKEND',
        'query-contract.pdf',
        'query-contract-model',
        '{"candidate":{"fullName":"Query Contract"}}'::JSONB,
        'MID',
        'Synthetic rollback-only query contract job description.',
        'EXTRACTED',
        '1.0'
    );

    SET LOCAL ROLE talentai_app;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.claim_assessment_execution(
        v_completed_request_id::TEXT,
        'resume-one|JAVA_BACKEND|MID|job-description',
        'query-contract-root-1',
        'JAVA_BACKEND',
        'MID'
    );

    IF v_result."claimStatus" <> 'CLAIMED_NEW'
       OR v_result."canContinue" <> TRUE
       OR v_result."attemptCount" <> 1 THEN
        RAISE EXCEPTION
            'New claim assertion failed: status %, continue %, attempt %',
            v_result."claimStatus",
            v_result."canContinue",
            v_result."attemptCount";
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.claim_assessment_execution(
        v_completed_request_id::TEXT,
        'resume-one|JAVA_BACKEND|MID|job-description',
        'query-contract-root-2',
        'JAVA_BACKEND',
        'MID'
    );

    IF v_result."claimStatus" <> 'ALREADY_RUNNING'
       OR v_result."canContinue" <> FALSE THEN
        RAISE EXCEPTION
            'Running duplicate assertion failed: status %, continue %',
            v_result."claimStatus",
            v_result."canContinue";
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.claim_assessment_execution(
        v_completed_request_id::TEXT,
        'different-resume|JAVA_BACKEND|MID|job-description',
        'query-contract-root-3',
        'JAVA_BACKEND',
        'MID'
    );

    IF v_result."claimStatus" <> 'IDEMPOTENCY_CONFLICT'
       OR v_result."canContinue" <> FALSE THEN
        RAISE EXCEPTION
            'Idempotency conflict assertion failed: status %, continue %',
            v_result."claimStatus",
            v_result."canContinue";
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.attach_resume_extraction(
        v_completed_request_id,
        'query-contract-root-1',
        v_extraction_id
    );

    IF v_result."currentStage" <> 'GRADE_GUIDE_RESOLUTION'
       OR v_result."extractionId" <> v_extraction_id THEN
        RAISE EXCEPTION
            'Extraction attachment assertion failed: stage %, extraction %',
            v_result."currentStage",
            v_result."extractionId";
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.advance_assessment_execution(
        v_completed_request_id,
        'query-contract-grade-1',
        'EVIDENCE_SCORING'
    );

    IF v_result."currentStage" <> 'EVIDENCE_SCORING' THEN
        RAISE EXCEPTION
            'Forward stage assertion failed: stage %',
            v_result."currentStage";
    END IF;

    PERFORM *
    FROM pg_temp.advance_assessment_execution(
        v_completed_request_id,
        'query-contract-grade-1',
        'PROFILE_EXTRACTION'
    );

    IF FOUND THEN
        RAISE EXCEPTION 'Backward stage transition was unexpectedly accepted';
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.advance_assessment_execution(
        v_completed_request_id,
        'query-contract-grade-1',
        'ASSESSMENT_PERSISTENCE'
    );

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.persist_operational_grade_assessment(
        v_completed_request_id,
        'query-contract-assessment-1',
        v_extraction_id,
        v_active_guide_id,
        '1.0.0',
        'MID',
        'query-contract-model',
        '1.0',
        '1.0',
        '[{"code":"QUERY_CONTRACT"}]'::JSONB,
        70,
        60,
        TRUE,
        TRUE,
        'MEETS_TARGET',
        '[]'::JSONB,
        '[]'::JSONB,
        'Synthetic rollback-only query contract assessment.'
    );

    v_assessment_id := v_result."assessmentId";

    IF v_result."requestId" <> v_completed_request_id
       OR v_result."wasInserted" <> TRUE THEN
        RAISE EXCEPTION
            'Operational assessment insert assertion failed: request %, inserted %',
            v_result."requestId",
            v_result."wasInserted";
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.persist_operational_grade_assessment(
        v_completed_request_id,
        'query-contract-assessment-retry',
        v_extraction_id,
        v_active_guide_id,
        '1.0.0',
        'MID',
        'query-contract-model',
        '1.0',
        '1.0',
        '[{"code":"QUERY_CONTRACT"}]'::JSONB,
        70,
        60,
        TRUE,
        TRUE,
        'MEETS_TARGET',
        '[]'::JSONB,
        '[]'::JSONB,
        'Synthetic rollback-only query contract assessment.'
    );

    IF v_result."assessmentId" <> v_assessment_id
       OR v_result."wasInserted" <> FALSE THEN
        RAISE EXCEPTION
            'Operational assessment replay assertion failed: assessment %, inserted %',
            v_result."assessmentId",
            v_result."wasInserted";
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.complete_assessment_execution(
        v_completed_request_id,
        'query-contract-grade-1',
        v_assessment_id
    );

    IF v_result.status <> 'COMPLETED'
       OR v_result."currentStage" <> 'COMPLETED'
       OR v_result."assessmentId" <> v_assessment_id THEN
        RAISE EXCEPTION
            'Completion assertion failed: status %, stage %, assessment %',
            v_result.status,
            v_result."currentStage",
            v_result."assessmentId";
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.claim_assessment_execution(
        v_completed_request_id::TEXT,
        'resume-one|JAVA_BACKEND|MID|job-description',
        'query-contract-root-4',
        'JAVA_BACKEND',
        'MID'
    );

    IF v_result."claimStatus" <> 'COMPLETED_REPLAY'
       OR v_result."canContinue" <> FALSE THEN
        RAISE EXCEPTION
            'Completed replay assertion failed: status %, continue %',
            v_result."claimStatus",
            v_result."canContinue";
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.load_completed_assessment_execution(
        v_completed_request_id
    );

    IF v_result."assessmentId" <> v_assessment_id
       OR v_result."extractionId" <> v_extraction_id
       OR v_result."executionStatus" <> 'COMPLETED'
       OR v_result."decision" <> 'MEETS_TARGET'
       OR v_result."positionCode" <> 'JAVA_BACKEND' THEN
        RAISE EXCEPTION
            'Completed result load assertion failed: assessment %, execution %, decision %',
            v_result."assessmentId",
            v_result."executionStatus",
            v_result.decision;
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.claim_assessment_execution(
        v_retry_request_id::TEXT,
        'resume-two|JAVA_BACKEND|SENIOR|job-description',
        'query-contract-root-5',
        'JAVA_BACKEND',
        'SENIOR'
    );

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.advance_assessment_execution(
        v_retry_request_id,
        'query-contract-grade-engine-1',
        'EVIDENCE_SCORING'
    );

    PERFORM *
    FROM pg_temp.fail_assessment_execution(
        v_retry_request_id,
        'stale-workflow-execution',
        '',
        'ORCHESTRATION',
        'STALE_EXECUTION_FAILURE',
        'A stale workflow must not own the failure transition.',
        TRUE
    );

    IF FOUND THEN
        RAISE EXCEPTION 'Stale workflow failure transition was unexpectedly accepted';
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.fail_assessment_execution(
        v_retry_request_id,
        'query-contract-root-5',
        '',
        'PROVIDER',
        'PROVIDER_TEMPORARILY_UNAVAILABLE',
        E'Provider request failed.\nPrivate payload omitted.',
        TRUE
    );

    IF v_result.status <> 'FAILED'
       OR v_result."failureCategory" <> 'PROVIDER'
       OR v_result."failureCode" <> 'PROVIDER_TEMPORARILY_UNAVAILABLE'
       OR v_result."failureMessage" LIKE '%' || chr(10) || '%'
       OR v_result."currentStage" <> 'EVIDENCE_SCORING'
       OR v_result.retryable <> TRUE THEN
        RAISE EXCEPTION
            'Failure assertion failed: status %, stage %, category %, code %, retryable %',
            v_result.status,
            v_result."currentStage",
            v_result."failureCategory",
            v_result."failureCode",
            v_result.retryable;
    END IF;

    SELECT *
    INTO STRICT v_result
    FROM pg_temp.claim_assessment_execution(
        v_retry_request_id::TEXT,
        'resume-two|JAVA_BACKEND|SENIOR|job-description',
        'query-contract-root-6',
        'JAVA_BACKEND',
        'SENIOR'
    );

    IF v_result."claimStatus" <> 'CLAIMED_RETRY'
       OR v_result."canContinue" <> TRUE
       OR v_result."attemptCount" <> 2
       OR v_result."currentStage" <> 'PROFILE_EXTRACTION'
       OR v_result."failureCode" IS NOT NULL THEN
        RAISE EXCEPTION
            'Retry assertion failed: status %, continue %, attempt %, stage %, failure %',
            v_result."claimStatus",
            v_result."canContinue",
            v_result."attemptCount",
            v_result."currentStage",
            v_result."failureCode";
    END IF;

    IF (
        SELECT claim_owner_workflow_execution_id
        FROM talentai.assessment_execution
        WHERE request_id = v_retry_request_id
    ) <> 'query-contract-root-6' THEN
        RAISE EXCEPTION 'Retry did not transfer claim ownership to the new root execution';
    END IF;

    RAISE NOTICE 'Assessment execution query assertions passed.';
END
$query_contract_test$;

RESET ROLE;
