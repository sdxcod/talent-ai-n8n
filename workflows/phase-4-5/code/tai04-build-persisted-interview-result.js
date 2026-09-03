const persisted = $input.first().json;

let result = persisted.resultPayload;

if (typeof result === 'string') {
  result = JSON.parse(result);
}

if (
  !result ||
  typeof result !== 'object' ||
  Array.isArray(result) ||
  !persisted.sessionId ||
  !persisted.resultId
) {
  throw new Error(
    'COMPLETED_INTERVIEW_RESULT_NOT_AVAILABLE'
  );
}

const replayed =
  persisted.wasInserted === undefined
    ? true
    : persisted.wasInserted !== true;

return [
  {
    json: {
      ...result,
      persistence: {
        sessionId: persisted.sessionId,
        resultId: persisted.resultId,
        resultVersion: Number(persisted.resultVersion),
        attemptCount: Number(persisted.attemptCount),
        replayed,
      },
    },
  },
];
