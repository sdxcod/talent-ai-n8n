WITH supplied AS
(
    SELECT
        NULLIF(BTRIM($1), '')                 AS contract_version,
        $2::UUID                              AS request_id,
        $3::UUID                              AS assessment_id,
        $4::UUID                              AS extraction_id,
        NULLIF(BTRIM($5), '')                 AS workflow_execution_id,
        $6::INTEGER                           AS ttl_minutes,
        encode(gen_random_bytes(32), 'hex')   AS invitation_token
),
validated AS
(
    SELECT supplied.*
    FROM supplied
    WHERE supplied.contract_version = '1.0.0'
      AND supplied.workflow_execution_id IS NOT NULL
      AND supplied.ttl_minutes BETWEEN 15 AND 10080
),
eligible AS
(
    SELECT validated.*
    FROM validated
    JOIN talentai.assessment_execution AS execution
      ON execution.request_id = validated.request_id
     AND execution.assessment_id = validated.assessment_id
     AND execution.extraction_id = validated.extraction_id
     AND execution.status = 'COMPLETED'
     AND execution.current_stage = 'COMPLETED'
     AND execution.completed_at IS NOT NULL
    JOIN talentai.grade_assessment AS assessment
      ON assessment.id = validated.assessment_id
     AND assessment.request_id = validated.request_id
     AND assessment.extraction_id = validated.extraction_id
     AND assessment.status = 'COMPLETED'
),
issued AS
(
    INSERT INTO talentai.technical_interview_invitation
    (
        contract_version,
        request_id,
        assessment_id,
        extraction_id,
        token_hash,
        status,
        issue_count,
        issued_by_workflow_execution_id,
        issued_at,
        expires_at,
        updated_at
    )
    SELECT
        eligible.contract_version,
        eligible.request_id,
        eligible.assessment_id,
        eligible.extraction_id,
        encode(digest(eligible.invitation_token, 'sha256'), 'hex'),
        'ISSUED',
        1,
        eligible.workflow_execution_id,
        now(),
        now() + make_interval(mins => eligible.ttl_minutes),
        now()
    FROM eligible
    ON CONFLICT ON CONSTRAINT uq_technical_interview_invitation_handoff
    DO UPDATE
    SET
        extraction_id = EXCLUDED.extraction_id,
        token_hash = EXCLUDED.token_hash,
        status = 'ISSUED',
        issue_count = technical_interview_invitation.issue_count + 1,
        issued_by_workflow_execution_id = EXCLUDED.issued_by_workflow_execution_id,
        claimed_by_workflow_execution_id = NULL,
        revoked_by_workflow_execution_id = NULL,
        issued_at = EXCLUDED.issued_at,
        expires_at = EXCLUDED.expires_at,
        claimed_at = NULL,
        revoked_at = NULL,
        updated_at = EXCLUDED.updated_at
    WHERE
        technical_interview_invitation.status IN ('REVOKED', 'EXPIRED')
        OR
        (
            technical_interview_invitation.status = 'ISSUED'
            AND technical_interview_invitation.expires_at <= now()
        )
    RETURNING *
),
current_invitation AS
(
    SELECT invitation.*
    FROM talentai.technical_interview_invitation AS invitation
    CROSS JOIN supplied
    WHERE invitation.contract_version = supplied.contract_version
      AND invitation.request_id = supplied.request_id
      AND invitation.assessment_id = supplied.assessment_id
      AND NOT EXISTS (SELECT 1 FROM issued)
),
resolved AS
(
    SELECT issued.* FROM issued
    UNION ALL
    SELECT current_invitation.* FROM current_invitation
)
SELECT
    resolved.id                                      AS "invitationId",
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM validated)
            THEN 'INVALID_ISSUE_REQUEST'
        WHEN NOT EXISTS (SELECT 1 FROM eligible)
            THEN 'PHASE3_HANDOFF_NOT_ELIGIBLE'
        WHEN EXISTS (SELECT 1 FROM issued)
         AND resolved.issue_count = 1
            THEN 'ISSUED_NEW'
        WHEN EXISTS (SELECT 1 FROM issued)
            THEN 'ISSUED_REPLACEMENT'
        WHEN resolved.status = 'ISSUED'
         AND resolved.expires_at > now()
            THEN 'ACTIVE_INVITATION_EXISTS'
        WHEN resolved.status = 'CLAIMED'
            THEN 'INVITATION_ALREADY_CLAIMED'
        ELSE 'INVITATION_NOT_ISSUED'
    END                                              AS "issueStatus",
    EXISTS (SELECT 1 FROM issued)                    AS "canDeliver",
    CASE
        WHEN EXISTS (SELECT 1 FROM issued)
            THEN supplied.invitation_token
        ELSE NULL
    END                                              AS "invitationToken",
    CASE
        WHEN EXISTS (SELECT 1 FROM issued)
            THEN resolved.contract_version
        ELSE NULL
    END                                              AS "contractVersion",
    CASE
        WHEN EXISTS (SELECT 1 FROM issued)
            THEN resolved.request_id
        ELSE NULL
    END                                              AS "requestId",
    CASE
        WHEN EXISTS (SELECT 1 FROM issued)
            THEN resolved.assessment_id
        ELSE NULL
    END                                              AS "assessmentId",
    CASE
        WHEN EXISTS (SELECT 1 FROM issued)
            THEN resolved.extraction_id
        ELSE NULL
    END                                              AS "extractionId",
    resolved.status,
    resolved.issue_count                             AS "issueCount",
    resolved.issued_at                               AS "issuedAt",
    resolved.expires_at                              AS "expiresAt"
FROM supplied
LEFT JOIN resolved ON TRUE;
