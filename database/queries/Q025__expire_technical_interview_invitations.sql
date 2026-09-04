WITH expired AS
(
    UPDATE talentai.technical_interview_invitation AS invitation
    SET
        status = 'EXPIRED',
        updated_at = now()
    WHERE invitation.status = 'ISSUED'
      AND invitation.expires_at <= now()
    RETURNING invitation.id
)
SELECT COUNT(*)::INTEGER AS "expiredInvitationCount"
FROM expired;
