const persisted = $input.first().json;

if (
  !persisted.questionSetId ||
  persisted.round !== 'FIRST' ||
  Number(persisted.questionCount) < 1
) {
  throw new Error(
    'FIRST_QUESTION_SET_PERSISTENCE_FAILED'
  );
}

const validated =
  $('Validate Interview Questions').first().json;

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
