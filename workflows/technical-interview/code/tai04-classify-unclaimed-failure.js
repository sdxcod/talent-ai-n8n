return [
  {
    json: {
      sessionId: '',
      requestId: '',
      assessmentId: '',
      extractionId: '',
      workflowExecutionId: String($execution.id),
      currentStage: failureDefinition.stage ?? '',
      attemptCount: 0,
      failureCategory: failureDefinition.category,
      failureCode: failureDefinition.code,
      failureMessage: failureDefinition.message,
      retryable: failureDefinition.retryable,
    },
  },
];
