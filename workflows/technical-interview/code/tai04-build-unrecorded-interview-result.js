const failure = $input.first().json;

const requestId = String(failure.requestId ?? '');
const assessmentId = String(failure.assessmentId ?? '');
const workflowExecutionId = String(
  failure.workflowExecutionId ?? $execution.id
);
const retryable = failure.retryable === true;

const output = [
  'TalentAI technical interview request failed.',
  '',
  `Request ID: ${requestId || 'NOT_ASSIGNED'}`,
  `Assessment ID: ${assessmentId || 'NOT_ASSIGNED'}`,
  `Workflow Execution ID: ${workflowExecutionId}`,
  `Failure Category: ${failure.failureCategory ?? 'ORCHESTRATION'}`,
  `Failure Code: ${failure.failureCode ?? 'TECHNICAL_INTERVIEW_REQUEST_FAILED'}`,
  `Retryable: ${retryable ? 'YES' : 'NO'}`,
  'Failure Recorded: NO',
].join('\n');

return [
  {
    json: {
      output,
      success: false,
      sessionId: String(failure.sessionId ?? ''),
      requestId,
      assessmentId,
      extractionId: String(failure.extractionId ?? ''),
      workflowExecutionId,
      executionStatus: 'REJECTED',
      currentStage: String(failure.currentStage ?? ''),
      attemptCount: Number(failure.attemptCount ?? 0),
      failureCategory: String(
        failure.failureCategory ?? 'ORCHESTRATION'
      ),
      failureCode: String(
        failure.failureCode ?? 'TECHNICAL_INTERVIEW_REQUEST_FAILED'
      ),
      failureMessage: String(
        failure.failureMessage ??
          'Technical interview request failed; private payload omitted.'
      ),
      retryable,
      failureRecorded: false,
    },
  },
];
