const claim = $('Claim Assessment Execution').first().json;

return [
  {
    json: {
      requestId: String(claim.requestId ?? ''),
      workflowExecutionId: String($execution.id),
      // Preserve the latest database stage advanced by child workflows.
      currentStage: '',
      attemptCount: Number(claim.attemptCount ?? 1),
      failureCategory: failureDefinition.category,
      failureCode: failureDefinition.code,
      failureMessage: failureDefinition.message,
      retryable: failureDefinition.retryable,
    },
  },
];
