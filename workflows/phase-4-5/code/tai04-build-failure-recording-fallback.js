const claim = $('Claim Technical Interview Session').first().json;
const requestId = String(claim.requestId ?? '');
const assessmentId = String(claim.assessmentId ?? '');
const sessionId = String(claim.sessionId ?? '');
const workflowExecutionId = String($execution.id);

const output = [
  'TalentAI technical interview failed.',
  '',
  `Request ID: ${requestId}`,
  `Assessment ID: ${assessmentId}`,
  `Interview Session ID: ${sessionId}`,
  `Workflow Execution ID: ${workflowExecutionId}`,
  'Failure Category: PERSISTENCE',
  'Failure Code: INTERVIEW_FAILURE_RECORDING_FAILED',
  'Retryable: YES',
  'Failure Recorded: NO',
].join('\n');

return [
  {
    json: {
      output,
      success: false,
      sessionId,
      requestId,
      assessmentId,
      extractionId: String(claim.extractionId ?? ''),
      workflowExecutionId,
      executionStatus: claim.status ?? 'RUNNING',
      currentStage: claim.currentStage ?? '',
      attemptCount: Number(claim.attemptCount ?? 1),
      failureCategory: 'PERSISTENCE',
      failureCode: 'INTERVIEW_FAILURE_RECORDING_FAILED',
      failureMessage:
        'The technical interview failed and its failure record could not be confirmed.',
      retryable: true,
      failureRecorded: false,
    },
  },
];
