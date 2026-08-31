UPDATE talentai.assessment_execution AS execution
SET
    last_workflow_execution_id = NULLIF($2, ''),
    assessment_id = $3::UUID,
    status = 'COMPLETED',
    current_stage = 'COMPLETED',
    completed_at = now(),
    updated_at = now()
WHERE execution.request_id = $1::UUID
  AND execution.status = 'RUNNING'
  AND execution.extraction_id IS NOT NULL
  AND NULLIF($2, '') IS NOT NULL
  AND EXISTS
  (
      SELECT 1
      FROM talentai.grade_assessment AS assessment
      WHERE assessment.id = $3::UUID
        AND assessment.extraction_id = execution.extraction_id
        AND assessment.status = 'COMPLETED'
  )
RETURNING
    execution.request_id                 AS "requestId",
    execution.status,
    execution.current_stage              AS "currentStage",
    execution.attempt_count              AS "attemptCount",
    execution.extraction_id              AS "extractionId",
    execution.assessment_id              AS "assessmentId",
    execution.started_at                 AS "startedAt",
    execution.completed_at               AS "completedAt";
