const input = $input.first().json;
const invitationToken =
  typeof input.invitationToken === 'string'
    ? input.invitationToken.trim().toLowerCase()
    : '';

if (!/^[0-9a-f]{64}$/.test(invitationToken)) {
  throw new Error(
    'INVALID_INVITATION_TOKEN: invitation token has an invalid format.'
  );
}

return [{ json: { invitationToken } }];
