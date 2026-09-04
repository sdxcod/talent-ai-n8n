DO $queries$
DECLARE
    v_request_id UUID := '60000000-0000-4000-8000-000000000001';
    v_assessment_id UUID := '60000000-0000-4000-8000-000000000002';
    v_extraction_id UUID := '60000000-0000-4000-8000-000000000003';
    v_grade_guide_id UUID := '60000000-0000-4000-8000-000000000004';
    v_expired_invitation_id UUID := '60000000-0000-4000-8000-000000000005';
    v_token TEXT;
    v_replacement_token TEXT;
    v_expired_token TEXT := repeat('a', 64);
    v_invitation_id UUID;
    v_row RECORD;
    v_count INTEGER;
BEGIN
    INSERT INTO talentai.resume_extraction
    (
        id,
        workflow_execution_id,
        position_code,
        source_file_name,
        extraction_model,
        profile,
        status,
        target_grade_code,
        job_description,
        profile_schema_version
    )
    VALUES
    (
        v_extraction_id,
        'invitation-query-extraction',
        'JAVA_BACKEND',
        'synthetic-resume.pdf',
        'gpt-test',
        '{"candidate":{"fullName":"Invitation Test Candidate"}}'::JSONB,
        'EXTRACTED',
        'MID',
        'Synthetic job description for secure invitation query testing.',
        '1.0'
    );

    INSERT INTO talentai.grade_guide
    (
        id,
        position_code,
        guide_version,
        guide_schema_version,
        status,
        guide,
        activated_at
    )
    VALUES
    (
        v_grade_guide_id,
        'JAVA_BACKEND_INVITATION_TEST',
        'invitation-test-v1',
        '1.0',
        'ACTIVE',
        '{
          "positionCode": "JAVA_BACKEND_INVITATION_TEST",
          "guideVersion": "invitation-test-v1",
          "grades": [{"code": "MID"}],
          "dimensions": [{"code": "JAVA_CORE"}]
        }'::JSONB,
        now()
    );

    INSERT INTO talentai.assessment_execution
    (
        request_id,
        input_fingerprint,
        initial_workflow_execution_id,
        claim_owner_workflow_execution_id,
        last_workflow_execution_id,
        position_code,
        target_grade_code,
        status,
        current_stage
    )
    VALUES
    (
        v_request_id,
        repeat('b', 64),
        'invitation-query-assessment',
        'invitation-query-assessment',
        'invitation-query-assessment',
        'JAVA_BACKEND',
        'MID',
        'RUNNING',
        'ASSESSMENT_PERSISTENCE'
    );

    INSERT INTO talentai.grade_assessment
    (
        id,
        workflow_execution_id,
        request_id,
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
        'invitation-query-grade',
        v_request_id,
        v_extraction_id,
        v_grade_guide_id,
        'invitation-test-v1',
        'MID',
        'gpt-test',
        '1.0',
        '1.0',
        '[{"code":"JAVA_CORE","effectiveScore":3}]'::JSONB,
        75,
        60,
        TRUE,
        TRUE,
        'MEETS_TARGET',
        '[]'::JSONB,
        '[]'::JSONB,
        'Synthetic completed assessment for invitation testing.',
        'COMPLETED'
    );

    UPDATE talentai.assessment_execution
    SET
        extraction_id = v_extraction_id,
        assessment_id = v_assessment_id,
        status = 'COMPLETED',
        current_stage = 'COMPLETED',
        updated_at = now(),
        completed_at = now()
    WHERE request_id = v_request_id;

    SELECT * INTO STRICT v_row
    FROM pg_temp.issue_technical_interview_invitation(
        '1.0.0',
        v_request_id,
        v_assessment_id,
        v_extraction_id,
        'invitation-issue-test-1',
        120
    );

    IF v_row."issueStatus" <> 'ISSUED_NEW'
       OR v_row."canDeliver" IS NOT TRUE
       OR v_row."invitationToken" !~ '^[0-9a-f]{64}$'
       OR v_row."issueCount" <> 1 THEN
        RAISE EXCEPTION 'New invitation issuance failed: %', v_row;
    END IF;

    v_invitation_id := v_row."invitationId";
    v_token := v_row."invitationToken";

    SELECT COUNT(*) INTO v_count
    FROM talentai.technical_interview_invitation
    WHERE id = v_invitation_id
      AND token_hash = encode(digest(v_token, 'sha256'), 'hex')
      AND token_hash <> v_token;

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Invitation token was not stored as a SHA-256 digest';
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.issue_technical_interview_invitation(
        '1.0.0',
        v_request_id,
        v_assessment_id,
        v_extraction_id,
        'invitation-issue-test-2',
        120
    );

    IF v_row."issueStatus" <> 'ACTIVE_INVITATION_EXISTS'
       OR v_row."canDeliver" IS NOT FALSE
       OR v_row."invitationToken" IS NOT NULL
       OR v_row."issueCount" <> 1 THEN
        RAISE EXCEPTION 'Active invitation was not protected from duplicate issue: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_invitation(
        'not-a-token',
        'invitation-claim-test-1'
    );

    IF v_row."claimStatus" <> 'INVALID_TOKEN_FORMAT'
       OR v_row."canContinue" IS NOT FALSE THEN
        RAISE EXCEPTION 'Malformed invitation token was not rejected: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_invitation(
        v_token,
        'invitation-claim-test-1'
    );

    IF v_row."claimStatus" <> 'CLAIMED_NEW'
       OR v_row."canContinue" IS NOT TRUE
       OR v_row."requestId" <> v_request_id
       OR v_row."assessmentId" <> v_assessment_id
       OR v_row."extractionId" <> v_extraction_id THEN
        RAISE EXCEPTION 'Valid invitation claim failed: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_invitation(
        v_token,
        'invitation-claim-test-1'
    );

    IF v_row."claimStatus" <> 'CLAIMED_CURRENT'
       OR v_row."canContinue" IS NOT TRUE THEN
        RAISE EXCEPTION 'Invitation claim was not idempotent for its owner: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_invitation(
        v_token,
        'invitation-claim-test-2'
    );

    IF v_row."claimStatus" <> 'INVITATION_ALREADY_CLAIMED'
       OR v_row."canContinue" IS NOT FALSE
       OR v_row."requestId" IS NOT NULL
       OR v_row."assessmentId" IS NOT NULL
       OR v_row."extractionId" IS NOT NULL THEN
        RAISE EXCEPTION 'Claimed invitation leaked handoff data: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.revoke_technical_interview_invitation(
        v_invitation_id,
        'invitation-revoke-test-1'
    );

    IF v_row."revokeStatus" <> 'CLAIMED_INVITATION_NOT_REVOKED'
       OR v_row."revokedNow" IS NOT FALSE THEN
        RAISE EXCEPTION 'Claimed invitation was unexpectedly revoked: %', v_row;
    END IF;

    UPDATE talentai.technical_interview_invitation
    SET
        status = 'EXPIRED',
        claimed_by_workflow_execution_id = NULL,
        claimed_at = NULL,
        updated_at = now()
    WHERE id = v_invitation_id;

    SELECT * INTO STRICT v_row
    FROM pg_temp.issue_technical_interview_invitation(
        '1.0.0',
        v_request_id,
        v_assessment_id,
        v_extraction_id,
        'invitation-issue-test-3',
        120
    );

    IF v_row."issueStatus" <> 'ISSUED_REPLACEMENT'
       OR v_row."canDeliver" IS NOT TRUE
       OR v_row."issueCount" <> 2
       OR v_row."invitationToken" = v_token THEN
        RAISE EXCEPTION 'Expired invitation was not securely replaced: %', v_row;
    END IF;

    v_replacement_token := v_row."invitationToken";

    SELECT * INTO STRICT v_row
    FROM pg_temp.revoke_technical_interview_invitation(
        v_invitation_id,
        'invitation-revoke-test-2'
    );

    IF v_row."revokeStatus" <> 'REVOKED_NOW'
       OR v_row."revokedNow" IS NOT TRUE
       OR v_row.status <> 'REVOKED' THEN
        RAISE EXCEPTION 'Issued invitation revocation failed: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_invitation(
        v_replacement_token,
        'invitation-claim-test-3'
    );

    IF v_row."claimStatus" <> 'INVITATION_REVOKED'
       OR v_row."canContinue" IS NOT FALSE THEN
        RAISE EXCEPTION 'Revoked invitation remained claimable: %', v_row;
    END IF;

    INSERT INTO talentai.technical_interview_invitation
    (
        id,
        contract_version,
        request_id,
        assessment_id,
        extraction_id,
        token_hash,
        status,
        issued_by_workflow_execution_id,
        issued_at,
        expires_at,
        updated_at
    )
    VALUES
    (
        v_expired_invitation_id,
        '1.0.0',
        '60000000-0000-4000-8000-000000000011',
        '60000000-0000-4000-8000-000000000012',
        '60000000-0000-4000-8000-000000000013',
        encode(digest(v_expired_token, 'sha256'), 'hex'),
        'ISSUED',
        'invitation-expiry-test',
        now() - INTERVAL '2 hours',
        now() - INTERVAL '1 hour',
        now() - INTERVAL '2 hours'
    );

    SELECT * INTO STRICT v_row
    FROM pg_temp.expire_technical_interview_invitations();

    IF v_row."expiredInvitationCount" <> 1 THEN
        RAISE EXCEPTION 'Expected one stale invitation to expire: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_invitation(
        v_expired_token,
        'invitation-claim-expired'
    );

    IF v_row."claimStatus" <> 'INVITATION_EXPIRED'
       OR v_row."canContinue" IS NOT FALSE THEN
        RAISE EXCEPTION 'Expired invitation remained claimable: %', v_row;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM talentai.technical_interview_invitation
    WHERE request_id = v_request_id
      AND assessment_id = v_assessment_id;

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Invitation handoff idempotency produced % rows', v_count;
    END IF;

    RAISE NOTICE 'Technical interview invitation query assertions passed.';
END
$queries$;
