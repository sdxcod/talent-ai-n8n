UPDATE talentai.assessment_execution AS execution
SET
    last_workflow_execution_id = NULLIF($2, ''),
    extraction_id = $3::UUID,
    current_stage = 'GRADE_GUIDE_RESOLUTION',
    updated_at = now()
WHERE execution.request_id = $1::UUID
  AND execution.status = 'RUNNING'
  AND NULLIF($2, '') IS NOT NULL
  AND (
      execution.extraction_id IS NULL
      OR execution.extraction_id = $3::UUID
  )
RETURNING
    execution.request_id                 AS "requestId",
    execution.status,
    execution.current_stage              AS "currentStage",
    execution.attempt_count              AS "attemptCount",
    execution.extraction_id              AS "extractionId",
    execution.updated_at                 AS "updatedAt";
