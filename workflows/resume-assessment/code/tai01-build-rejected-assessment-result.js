const claim = $input.first().json;

const claimStatus = String(
  claim.claimStatus ?? 'CLAIM_REJECTED'
);

const definitions = {
  IDEMPOTENCY_CONFLICT: {
    category: 'VALIDATION',
    code: 'IDEMPOTENCY_CONFLICT',
    message: 'The request identifier is already bound to different input.',
    retryable: false,
  },
  ALREADY_RUNNING: {
    category: 'ORCHESTRATION',
    code: 'ASSESSMENT_ALREADY_RUNNING',
    message: 'The assessment request is already running.',
    retryable: true,
  },
  FAILED_NOT_RETRYABLE: {
    category: String(claim.failureCategory ?? 'ORCHESTRATION'),
    code: String(claim.failureCode ?? 'ASSESSMENT_NOT_RETRYABLE'),
    message: 'The previous assessment attempt failed and is not retryable.',
    retryable: false,
  },
  CLAIM_REJECTED: {
    category: 'ORCHESTRATION',
    code: 'ASSESSMENT_CLAIM_REJECTED',
    message: 'The assessment request could not be claimed.',
    retryable: false,
  },
};

const failure = definitions[claimStatus] ?? definitions.CLAIM_REJECTED;
const requestId = String(claim.requestId ?? '');

const output = [
  'TalentAI assessment request rejected.',
  '',
  `Request ID: ${requestId}`,
  `Claim Status: ${claimStatus}`,
  `Failure Category: ${failure.category}`,
  `Failure Code: ${failure.code}`,
  `Retryable: ${failure.retryable ? 'YES' : 'NO'}`,
].join('\n');

return [
  {
    json: {
      output,
      success: false,
      requestId,
      workflowExecutionId: String($execution.id),
      executionStatus: claim.status ?? 'REJECTED',
      claimStatus,
      currentStage: claim.currentStage ?? '',
      attemptCount: Number(claim.attemptCount ?? 1),
      failureCategory: failure.category,
      failureCode: failure.code,
      failureMessage: failure.message,
      retryable: failure.retryable,
      failureRecorded: claimStatus === 'FAILED_NOT_RETRYABLE',
    },
  },
];
