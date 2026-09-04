const input = $input.first().json;

const requestId = String(input.requestId ?? '').trim();
const extractionId = String(input.extractionId ?? '').trim();
const rootWorkflowExecutionId = String(
  input.rootWorkflowExecutionId ?? ''
).trim();
const attemptCount = Number(input.attemptCount);

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

if (!uuidPattern.test(requestId)) {
  throw new Error(
    'INVALID_REQUEST_ID: requestId must be a valid UUID.'
  );
}

if (!uuidPattern.test(extractionId)) {
  throw new Error(
    'INVALID_EXTRACTION_ID: extractionId must be a valid UUID.'
  );
}

if (!rootWorkflowExecutionId) {
  throw new Error(
    'INVALID_ROOT_EXECUTION_ID: rootWorkflowExecutionId is required.'
  );
}

if (!Number.isInteger(attemptCount) || attemptCount < 1) {
  throw new Error(
    'INVALID_ATTEMPT_COUNT: attemptCount must be a positive integer.'
  );
}

return [
  {
    json: {
      requestId,
      extractionId,
      rootWorkflowExecutionId,
      attemptCount,
    },
  },
];
