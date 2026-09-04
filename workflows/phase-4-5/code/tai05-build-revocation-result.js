const revoked = $input.first().json;

if (
  !revoked.invitationId ||
  !['REVOKED_NOW', 'ALREADY_REVOKED'].includes(
    String(revoked.revokeStatus ?? '')
  )
) {
  throw new Error('SECURE_INVITATION_REVOCATION_NOT_CONFIRMED');
}

const output = [
  '<p>دعوت مصاحبه با موفقیت باطل شد.</p>',
  `<p><strong>شناسه دعوت:</strong> ${String(revoked.invitationId)}</p>`,
  `<p><strong>وضعیت:</strong> ${String(revoked.revokeStatus)}</p>`,
].join('');

return [
  {
    json: {
      success: true,
      operation: 'REVOKE',
      invitationId: String(revoked.invitationId),
      revokeStatus: String(revoked.revokeStatus),
      revokedAt: revoked.revokedAt ?? null,
      output,
    },
  },
];
