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

if (
  !Array.isArray(normalized.firstRoundAnswerRecords) ||
  normalized.firstRoundAnswerRecords.length < 1
) {
  throw new Error(
    'FIRST_ROUND_ANSWER_CHECKPOINT_NOT_AVAILABLE'
  );
}

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
