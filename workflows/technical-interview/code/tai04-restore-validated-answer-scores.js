const persisted = $input.first().json;

if (
  persisted.complete !== true ||
  Number(persisted.answerCount) !==
    Number(persisted.evaluatedCount)
) {
  throw new Error(
    'ANSWER_EVALUATION_PERSISTENCE_FAILED'
  );
}

const validated =
  $('Validate Answer Scores').first().json;

return [
  {
    json: {
      ...validated,
      persistence: {
        sessionId: persisted.sessionId,
        answerCount: Number(persisted.answerCount),
      },
    },
  },
];
