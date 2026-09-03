const persisted = $input.first().json;

if (
  persisted.complete !== true ||
  Number(persisted.persistedCount) !==
    Number(persisted.expectedCount)
) {
  throw new Error(
    'FOLLOW_UP_ANSWER_PERSISTENCE_FAILED'
  );
}

const normalized =
  $('Normalize Follow-up Answers').first().json;
const firstRound =
  $('Restore First Round Answers').first().json;

return [
  {
    json: {
      ...normalized,
      firstRoundAnswerRecords: firstRound.answerRecords,
      persistence: {
        sessionId: persisted.sessionId,
        questionSetId: persisted.questionSetId,
        answerCount: Number(persisted.persistedCount),
      },
    },
  },
];
