const failure = $input.first().json;

const requestId = String(failure.requestId ?? '');
const assessmentId = String(failure.assessmentId ?? '');
const sessionId = String(failure.sessionId ?? '');
const attemptCount = Number(failure.attemptCount ?? 1);
const retryable = failure.retryable === true;

const output = [
  'TalentAI technical interview failed.',
  '',
  `Request ID: ${requestId}`,
  `Assessment ID: ${assessmentId}`,
  `Interview Session ID: ${sessionId}`,
  `Attempt: ${attemptCount}`,
  `Stage: ${failure.currentStage ?? 'UNKNOWN'}`,
  `Failure Category: ${failure.failureCategory ?? 'ORCHESTRATION'}`,
  `Failure Code: ${failure.failureCode ?? 'TECHNICAL_INTERVIEW_FAILED'}`,
  `Retryable: ${retryable ? 'YES' : 'NO'}`,
  'Failure Recorded: YES',
].join('\n');

return [
  {
    json: {
      output,
      success: false,
      sessionId,
      requestId,
      assessmentId,
      extractionId: String(failure.extractionId ?? ''),
      workflowExecutionId: String($execution.id),
      executionStatus: failure.status ?? 'FAILED',
      currentStage: String(failure.currentStage ?? ''),
      attemptCount,
      failureCategory: String(
        failure.failureCategory ?? 'ORCHESTRATION'
      ),
      failureCode: String(
        failure.failureCode ?? 'TECHNICAL_INTERVIEW_FAILED'
      ),
      failureMessage: String(
        failure.failureMessage ??
          'Technical interview failed; private payload omitted.'
      ),
      retryable,
      failureRecorded: true,
      failedAt: failure.failedAt,
    },
  },
];
