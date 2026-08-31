WITH requested AS
(
    SELECT
        $1::UUID          AS request_id,
        NULLIF($2, '')    AS workflow_execution_id,
        UPPER(BTRIM($3))  AS next_stage
),
ranked AS
(
    SELECT
        requested.*,
        CASE requested.next_stage
            WHEN 'INTAKE'                  THEN 0
            WHEN 'PROFILE_EXTRACTION'      THEN 1
            WHEN 'GRADE_GUIDE_RESOLUTION'  THEN 2
            WHEN 'EVIDENCE_SCORING'        THEN 3
            WHEN 'ASSESSMENT_PERSISTENCE'  THEN 4
            ELSE -1
        END AS next_stage_rank
    FROM requested
)
UPDATE talentai.assessment_execution AS execution
SET
    last_workflow_execution_id = ranked.workflow_execution_id,
    current_stage = ranked.next_stage,
    updated_at = now()
FROM ranked
WHERE execution.request_id = ranked.request_id
  AND execution.status = 'RUNNING'
  AND ranked.workflow_execution_id IS NOT NULL
  AND ranked.next_stage_rank >= 0
  AND ranked.next_stage_rank >=
      CASE execution.current_stage
          WHEN 'INTAKE'                  THEN 0
          WHEN 'PROFILE_EXTRACTION'      THEN 1
          WHEN 'GRADE_GUIDE_RESOLUTION'  THEN 2
          WHEN 'EVIDENCE_SCORING'        THEN 3
          WHEN 'ASSESSMENT_PERSISTENCE'  THEN 4
          ELSE 99
      END
RETURNING
    execution.request_id                 AS "requestId",
    execution.status,
    execution.current_stage              AS "currentStage",
    execution.attempt_count              AS "attemptCount",
    execution.updated_at                 AS "updatedAt";
