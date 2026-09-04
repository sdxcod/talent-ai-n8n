WITH supplied AS
(
    SELECT
        LOWER(NULLIF(BTRIM($1), ''))             AS invitation_token,
        NULLIF(BTRIM($2), '')                    AS workflow_execution_id
),
validated AS
(
    SELECT
        supplied.*,
        encode(digest(supplied.invitation_token, 'sha256'), 'hex')
                                                    AS token_hash
    FROM supplied
    WHERE supplied.invitation_token ~ '^[0-9a-f]{64}$'
      AND supplied.workflow_execution_id IS NOT NULL
),
matched AS
(
    SELECT invitation.*
    FROM talentai.technical_interview_invitation AS invitation
    JOIN validated
      ON invitation.token_hash = validated.token_hash
),
claimed AS
(
    UPDATE talentai.technical_interview_invitation AS invitation
    SET
        status = 'CLAIMED',
        claimed_by_workflow_execution_id = validated.workflow_execution_id,
        claimed_at = now(),
        updated_at = now()
    FROM validated
    WHERE invitation.token_hash = validated.token_hash
      AND invitation.status = 'ISSUED'
      AND invitation.expires_at > now()
    RETURNING invitation.*
),
expired AS
(
    UPDATE talentai.technical_interview_invitation AS invitation
    SET
        status = 'EXPIRED',
        updated_at = now()
    FROM validated
    WHERE invitation.token_hash = validated.token_hash
      AND invitation.status = 'ISSUED'
      AND invitation.expires_at <= now()
      AND NOT EXISTS (SELECT 1 FROM claimed)
    RETURNING invitation.*
),
resolved AS
(
    SELECT claimed.*, TRUE AS claimed_now FROM claimed
    UNION ALL
    SELECT expired.*, FALSE AS claimed_now FROM expired
    UNION ALL
    SELECT matched.*, FALSE AS claimed_now
    FROM matched
    WHERE NOT EXISTS (SELECT 1 FROM claimed)
      AND NOT EXISTS (SELECT 1 FROM expired)
)
SELECT
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM validated)
            THEN 'INVALID_TOKEN_FORMAT'
        WHEN resolved.id IS NULL
            THEN 'INVITATION_NOT_FOUND'
        WHEN resolved.claimed_now
            THEN 'CLAIMED_NEW'
        WHEN resolved.status = 'CLAIMED'
         AND resolved.claimed_by_workflow_execution_id
             = supplied.workflow_execution_id
            THEN 'CLAIMED_CURRENT'
        WHEN resolved.status = 'CLAIMED'
            THEN 'INVITATION_ALREADY_CLAIMED'
        WHEN resolved.status = 'REVOKED'
            THEN 'INVITATION_REVOKED'
        WHEN resolved.status = 'EXPIRED'
         OR resolved.expires_at <= now()
            THEN 'INVITATION_EXPIRED'
        ELSE 'INVITATION_NOT_CLAIMABLE'
    END                                              AS "claimStatus",
    COALESCE((
        resolved.claimed_now
        OR
        (
            resolved.status = 'CLAIMED'
            AND resolved.claimed_by_workflow_execution_id
                = supplied.workflow_execution_id
        )
    ), FALSE)                                        AS "canContinue",
    CASE
        WHEN resolved.claimed_now
          OR resolved.claimed_by_workflow_execution_id
             = supplied.workflow_execution_id
            THEN resolved.id
        ELSE NULL
    END                                              AS "invitationId",
    CASE
        WHEN resolved.claimed_now
          OR resolved.claimed_by_workflow_execution_id
             = supplied.workflow_execution_id
            THEN resolved.contract_version
        ELSE NULL
    END                                              AS "contractVersion",
    CASE
        WHEN resolved.claimed_now
          OR resolved.claimed_by_workflow_execution_id
             = supplied.workflow_execution_id
            THEN resolved.request_id
        ELSE NULL
    END                                              AS "requestId",
    CASE
        WHEN resolved.claimed_now
          OR resolved.claimed_by_workflow_execution_id
             = supplied.workflow_execution_id
            THEN resolved.assessment_id
        ELSE NULL
    END                                              AS "assessmentId",
    CASE
        WHEN resolved.claimed_now
          OR resolved.claimed_by_workflow_execution_id
             = supplied.workflow_execution_id
            THEN resolved.extraction_id
        ELSE NULL
    END                                              AS "extractionId",
    resolved.status,
    CASE
        WHEN resolved.claimed_now
          OR resolved.claimed_by_workflow_execution_id
             = supplied.workflow_execution_id
            THEN resolved.expires_at
        ELSE NULL
    END                                              AS "expiresAt",
    CASE
        WHEN resolved.claimed_now
          OR resolved.claimed_by_workflow_execution_id
             = supplied.workflow_execution_id
            THEN resolved.claimed_at
        ELSE NULL
    END                                              AS "claimedAt"
FROM supplied
LEFT JOIN resolved ON TRUE;
