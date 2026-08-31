const failure = $input.first().json;

const requestId = String(failure.requestId ?? '');
const attemptCount = Number(failure.attemptCount ?? 1);
const failureCategory = String(
  failure.failureCategory ?? 'ORCHESTRATION'
);
const failureCode = String(
  failure.failureCode ?? 'ASSESSMENT_EXECUTION_FAILED'
);
const failureMessage = String(
  failure.failureMessage ??
    'Assessment execution failed; private payload omitted.'
);
const retryable = failure.retryable === true;

const output = [
  'TalentAI assessment failed.',
  '',
  `Request ID: ${requestId}`,
  `Attempt: ${attemptCount}`,
  `Stage: ${failure.currentStage ?? 'UNKNOWN'}`,
  `Failure Category: ${failureCategory}`,
  `Failure Code: ${failureCode}`,
  `Retryable: ${retryable ? 'YES' : 'NO'}`,
  'Failure Recorded: YES',
].join('\n');

return [
  {
    json: {
      output,
      success: false,
      requestId,
      workflowExecutionId: String($execution.id),
      executionStatus: failure.status ?? 'FAILED',
      currentStage: failure.currentStage ?? '',
      attemptCount,
      failureCategory,
      failureCode,
      failureMessage,
      retryable,
      failureRecorded: true,
      failedAt: failure.failedAt,
    },
  },
];
