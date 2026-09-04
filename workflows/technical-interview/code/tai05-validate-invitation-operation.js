const input = $input.first().json;
const action = String(input.action ?? '').trim().toUpperCase();
const extractionId = String(input.extractionId ?? '').trim();
const invitationId = String(input.invitationId ?? '').trim();
const ttlMinutes = Number(input.ttlMinutes ?? 2880);

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

if (!['ISSUE', 'REVOKE'].includes(action)) {
  throw new Error(
    'INVALID_INVITATION_ACTION: action must be ISSUE or REVOKE.'
  );
}

if (action === 'ISSUE' && !uuidPattern.test(extractionId)) {
  throw new Error(
    'INVALID_EXTRACTION_ID: extractionId is required for ISSUE.'
  );
}

if (action === 'REVOKE' && !uuidPattern.test(invitationId)) {
  throw new Error(
    'INVALID_INVITATION_ID: invitationId is required for REVOKE.'
  );
}

if (
  action === 'ISSUE' &&
  (!Number.isInteger(ttlMinutes) || ttlMinutes < 15 || ttlMinutes > 10080)
) {
  throw new Error(
    'INVALID_INVITATION_TTL: ttlMinutes must be from 15 to 10080.'
  );
}

return [
  {
    json: {
      action,
      extractionId: action === 'ISSUE' ? extractionId : null,
      invitationId: action === 'REVOKE' ? invitationId : null,
      ttlMinutes: action === 'ISSUE' ? ttlMinutes : null,
    },
  },
];
