const claim = $('Claim Technical Interview Session').first().json;

return [
  {
    json: {
      sessionId: String(claim.sessionId ?? ''),
      requestId: String(claim.requestId ?? ''),
      assessmentId: String(claim.assessmentId ?? ''),
      extractionId: String(claim.extractionId ?? ''),
      workflowExecutionId: String($execution.id),
      currentStage: failureDefinition.stage,
      attemptCount: Number(claim.attemptCount ?? 1),
      failureCategory: failureDefinition.category,
      failureCode: failureDefinition.code,
      failureMessage: failureDefinition.message,
      retryable: failureDefinition.retryable,
    },
  },
];
