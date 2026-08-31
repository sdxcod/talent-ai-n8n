SELECT
    execution.request_id                    AS "requestId",
    execution.attempt_count                 AS "attemptCount",
    execution.status                        AS "executionStatus",
    execution.started_at                    AS "startedAt",
    execution.completed_at                  AS "completedAt",
    assessment.id                           AS "assessmentId",
    assessment.extraction_id                AS "extractionId",
    assessment.grade_guide_id               AS "gradeGuideId",
    assessment.grade_guide_version          AS "gradeGuideVersion",
    assessment.target_grade_code            AS "targetGradeCode",
    assessment.scoring_model                AS "scoringModel",
    assessment.prompt_version               AS "promptVersion",
    assessment.engine_version               AS "engineVersion",
    assessment.dimension_assessments        AS "dimensionAssessments",
    assessment.overall_score                AS "overallScore",
    assessment.minimum_overall_score        AS "minimumOverallScore",
    assessment.threshold_met                AS "thresholdMet",
    assessment.mandatory_dimensions_met     AS "mandatoryDimensionsMet",
    assessment.decision,
    assessment.review_reasons               AS "reviewReasons",
    assessment.model_warnings               AS "modelWarnings",
    assessment.assessment_summary           AS "assessmentSummary",
    assessment.status                       AS "assessmentStatus",
    assessment.created_at                   AS "assessmentCreatedAt",
    extraction.position_code                AS "positionCode",
    extraction.job_description              AS "jobDescription",
    extraction.profile -> 'candidate'        AS candidate
FROM talentai.assessment_execution AS execution
JOIN talentai.grade_assessment AS assessment
  ON assessment.id = execution.assessment_id
 AND assessment.request_id = execution.request_id
JOIN talentai.resume_extraction AS extraction
  ON extraction.id = execution.extraction_id
WHERE execution.request_id = $1::UUID
  AND execution.status = 'COMPLETED'
  AND execution.current_stage = 'COMPLETED'
  AND execution.completed_at IS NOT NULL;
