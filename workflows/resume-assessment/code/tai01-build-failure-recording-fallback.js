const claim = $('Claim Assessment Execution').first().json;
const requestId = String(claim.requestId ?? '');
const workflowExecutionId = String($execution.id);

const output = [
  'TalentAI assessment failed.',
  '',
  `Request ID: ${requestId}`,
  `Workflow Execution ID: ${workflowExecutionId}`,
  'Failure Category: PERSISTENCE',
  'Failure Code: FAILURE_RECORDING_FAILED',
  'Retryable: YES',
  'Failure Recorded: NO',
].join('\n');

return [
  {
    json: {
      output,
      success: false,
      requestId,
      workflowExecutionId,
      executionStatus: claim.status ?? 'RUNNING',
      currentStage: claim.currentStage ?? '',
      attemptCount: Number(claim.attemptCount ?? 1),
      failureCategory: 'PERSISTENCE',
      failureCode: 'FAILURE_RECORDING_FAILED',
      failureMessage:
        'The assessment failed and its failure record could not be confirmed.',
      retryable: true,
      failureRecorded: false,
    },
  },
];
