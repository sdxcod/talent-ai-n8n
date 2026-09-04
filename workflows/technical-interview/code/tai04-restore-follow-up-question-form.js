const persisted = $input.first().json;

if (
  !persisted.questionSetId ||
  persisted.round !== 'FOLLOW_UP' ||
  Number(persisted.questionCount) < 1
) {
  throw new Error(
    'FOLLOW_UP_QUESTION_SET_PERSISTENCE_FAILED'
  );
}

const validated =
  $('Validate Follow-up Questions').first().json;

return [
  {
    json: {
      ...validated,
      persistence: {
        sessionId: persisted.sessionId,
        questionSetId: persisted.questionSetId,
        questionSetVersion: Number(persisted.version),
        contentHash: persisted.contentHash,
      },
    },
  },
];
