return [
  {
    json: {
      requestId: '',
      workflowExecutionId: String($execution.id),
      failureCategory: failureDefinition.category,
      failureCode: failureDefinition.code,
      failureMessage: failureDefinition.message,
      retryable: failureDefinition.retryable,
    },
  },
];
