SELECT
    session.id                              AS "sessionId",
    session.contract_version                AS "contractVersion",
    session.request_id                      AS "requestId",
    session.assessment_id                   AS "assessmentId",
    session.extraction_id                   AS "extractionId",
    session.attempt_count                   AS "attemptCount",
    session.status                          AS status,
    session.current_stage                   AS "currentStage",
    session.started_at                      AS "startedAt",
    session.completed_at                    AS "completedAt",
    result.id                               AS "resultId",
    result.result_version                   AS "resultVersion",
    result.result_payload                   AS "resultPayload"
FROM talentai.technical_interview_session AS session
JOIN talentai.technical_interview_result AS result
  ON result.session_id = session.id
 AND result.status = 'COMPLETED'
WHERE session.contract_version = NULLIF(BTRIM($1), '')
  AND session.request_id = $2::UUID
  AND session.assessment_id = $3::UUID
  AND session.status = 'COMPLETED'
  AND session.current_stage = 'COMPLETED'
  AND session.completed_at IS NOT NULL
ORDER BY result.result_version DESC
LIMIT 1;
