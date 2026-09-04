WITH supplied AS
(
    SELECT
        $1::UUID                          AS invitation_id,
        NULLIF(BTRIM($2), '')             AS workflow_execution_id
),
revoked AS
(
    UPDATE talentai.technical_interview_invitation AS invitation
    SET
        status = 'REVOKED',
        revoked_by_workflow_execution_id = supplied.workflow_execution_id,
        revoked_at = now(),
        updated_at = now()
    FROM supplied
    WHERE invitation.id = supplied.invitation_id
      AND invitation.status = 'ISSUED'
      AND supplied.workflow_execution_id IS NOT NULL
    RETURNING invitation.*
),
current_invitation AS
(
    SELECT invitation.*
    FROM talentai.technical_interview_invitation AS invitation
    CROSS JOIN supplied
    WHERE invitation.id = supplied.invitation_id
      AND NOT EXISTS (SELECT 1 FROM revoked)
),
resolved AS
(
    SELECT revoked.*, TRUE AS revoked_now FROM revoked
    UNION ALL
    SELECT current_invitation.*, FALSE AS revoked_now FROM current_invitation
)
SELECT
    resolved.id                                      AS "invitationId",
    CASE
        WHEN resolved.id IS NULL
            THEN 'INVITATION_NOT_FOUND'
        WHEN resolved.revoked_now
            THEN 'REVOKED_NOW'
        WHEN resolved.status = 'REVOKED'
            THEN 'ALREADY_REVOKED'
        WHEN resolved.status = 'CLAIMED'
            THEN 'CLAIMED_INVITATION_NOT_REVOKED'
        WHEN resolved.status = 'EXPIRED'
            THEN 'EXPIRED_INVITATION_NOT_REVOKED'
        ELSE 'INVITATION_NOT_REVOKED'
    END                                              AS "revokeStatus",
    resolved.status,
    COALESCE(resolved.revoked_now, FALSE)             AS "revokedNow",
    resolved.revoked_at                              AS "revokedAt"
FROM supplied
LEFT JOIN resolved ON TRUE;
