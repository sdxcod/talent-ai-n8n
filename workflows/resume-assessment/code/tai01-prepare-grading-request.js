const current = $input.first().json;
const claim = $('Claim Assessment Execution').first().json;

const extractionId = String(
  current.extractionId ?? current.id ?? claim.extractionId ?? ''
).trim();

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

if (!uuidPattern.test(extractionId)) {
  throw new Error(
    'EXTRACTION_NOT_ATTACHED: grading requires a valid extractionId.'
  );
}

return [
  {
    json: {
      requestId: claim.requestId,
      extractionId,
      rootWorkflowExecutionId: String($execution.id),
      attemptCount: Number(claim.attemptCount),
    },
  },
];
