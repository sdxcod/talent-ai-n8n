const claim = $input.first().json;
const claimStatus = String(claim.claimStatus ?? 'CLAIM_REJECTED');

const definitions = {
  HANDOFF_CONFLICT: {
    category: 'VALIDATION',
    code: 'TECHNICAL_INTERVIEW_HANDOFF_CONFLICT',
    message: 'The interview session is bound to a different Phase 3 handoff.',
    retryable: false,
  },
  ALREADY_RUNNING: {
    category: 'ORCHESTRATION',
    code: 'TECHNICAL_INTERVIEW_ALREADY_RUNNING',
    message: 'The technical interview session is already running.',
    retryable: true,
  },
  FAILED_NOT_RETRYABLE: {
    category: String(claim.failureCategory ?? 'ORCHESTRATION'),
    code: String(
      claim.failureCode ?? 'TECHNICAL_INTERVIEW_NOT_RETRYABLE'
    ),
    message: 'The previous technical interview attempt is not retryable.',
    retryable: false,
  },
  CLAIM_REJECTED: {
    category: 'ORCHESTRATION',
    code: 'TECHNICAL_INTERVIEW_CLAIM_REJECTED',
    message: 'The technical interview session could not be claimed.',
    retryable: false,
  },
};

const failure = definitions[claimStatus] ?? definitions.CLAIM_REJECTED;
const requestId = String(claim.requestId ?? '');
const assessmentId = String(claim.assessmentId ?? '');

const output = [
  'TalentAI technical interview request rejected.',
  '',
  `Request ID: ${requestId}`,
  `Assessment ID: ${assessmentId}`,
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
      sessionId: String(claim.sessionId ?? ''),
      requestId,
      assessmentId,
      extractionId: String(claim.extractionId ?? ''),
      workflowExecutionId: String($execution.id),
      executionStatus: claim.status ?? 'REJECTED',
      claimStatus,
      currentStage: claim.currentStage ?? '',
      attemptCount: Number(claim.attemptCount ?? 0),
      failureCategory: failure.category,
      failureCode: failure.code,
      failureMessage: failure.message,
      retryable: failure.retryable,
      failureRecorded: claimStatus === 'FAILED_NOT_RETRYABLE',
    },
  },
];
