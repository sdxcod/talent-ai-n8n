const failure = $input.first().json;

const requestId = String(failure.requestId ?? '');
const workflowExecutionId = String(
  failure.workflowExecutionId ?? $execution.id
);
const failureCategory = String(
  failure.failureCategory ?? 'ORCHESTRATION'
);
const failureCode = String(
  failure.failureCode ?? 'ASSESSMENT_REQUEST_FAILED'
);
const failureMessage = String(
  failure.failureMessage ??
    'Assessment request failed; private payload omitted.'
);
const retryable = failure.retryable === true;

const output = [
  'TalentAI assessment request failed.',
  '',
  `Request ID: ${requestId || 'NOT_ASSIGNED'}`,
  `Workflow Execution ID: ${workflowExecutionId}`,
  `Failure Category: ${failureCategory}`,
  `Failure Code: ${failureCode}`,
  `Retryable: ${retryable ? 'YES' : 'NO'}`,
  'Failure Recorded: NO',
].join('\n');

return [
  {
    json: {
      output,
      success: false,
      requestId,
      workflowExecutionId,
      executionStatus: 'REJECTED',
      failureCategory,
      failureCode,
      failureMessage,
      retryable,
      failureRecorded: false,
    },
  },
];
