const claim = $input.first().json;
const claimStatus = String(
  claim.claimStatus ?? 'INVITATION_NOT_CLAIMABLE'
);

const supportedStatuses = new Set([
  'INVALID_TOKEN_FORMAT',
  'INVITATION_NOT_FOUND',
  'INVITATION_ALREADY_CLAIMED',
  'INVITATION_REVOKED',
  'INVITATION_EXPIRED',
  'INVITATION_NOT_CLAIMABLE',
]);

return [
  {
    json: {
      success: false,
      workflowExecutionId: String($execution.id),
      executionStatus: 'REJECTED',
      failureCategory: 'VALIDATION',
      failureCode: supportedStatuses.has(claimStatus)
        ? claimStatus
        : 'INVITATION_NOT_CLAIMABLE',
      failureMessage:
        'The interview invitation is unavailable; private details omitted.',
      retryable: false,
      failureRecorded: false,
    },
  },
];
