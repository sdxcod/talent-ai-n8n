const persisted = $input.first().json;

if (
  persisted.complete !== true ||
  Number(persisted.persistedCount) !==
    Number(persisted.expectedCount)
) {
  throw new Error(
    'FIRST_ROUND_ANSWER_PERSISTENCE_FAILED'
  );
}

const normalized =
  $('Normalize Interview Answers').first().json;

return [
  {
    json: {
      ...normalized,
      persistence: {
        sessionId: persisted.sessionId,
        questionSetId: persisted.questionSetId,
        answerCount: Number(persisted.persistedCount),
      },
    },
  },
];
