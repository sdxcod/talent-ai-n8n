WITH requested AS
(
    SELECT $1::UUID AS extraction_id
)
SELECT
    CASE
        WHEN extraction.id IS NULL
            THEN 'EXTRACTION_NOT_FOUND'
        WHEN execution.request_id IS NULL
            THEN 'COMPLETED_EXECUTION_NOT_FOUND'
        WHEN assessment.id IS NULL
            THEN 'COMPLETED_ASSESSMENT_NOT_FOUND'
        WHEN grade_guide.id IS NULL
            THEN 'GRADE_GUIDE_NOT_FOUND'
        ELSE 'RESOLVED'
    END AS "resolutionStatus",
    CASE
        WHEN extraction.id IS NULL
            THEN 'Resume extraction was not found.'
        WHEN execution.request_id IS NULL
            THEN 'A completed assessment execution was not found.'
        WHEN assessment.id IS NULL
            THEN 'A completed grade assessment was not found.'
        WHEN grade_guide.id IS NULL
            THEN 'The versioned grade guide used by the assessment was not found.'
        ELSE 'Completed Phase 3 assessment resolved for the demo adapter.'
    END AS "resolutionMessage",
    requested.extraction_id                 AS "requestedExtractionId",
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
    assessment.overall_score::DOUBLE PRECISION
                                                AS "overallScore",
    assessment.minimum_overall_score::DOUBLE PRECISION
                                                AS "minimumOverallScore",
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
    extraction.profile -> 'candidate'        AS candidate,
    grade_guide.guide -> 'grades'            AS "gradeDefinitions"
FROM requested
LEFT JOIN talentai.resume_extraction AS extraction
       ON extraction.id = requested.extraction_id
LEFT JOIN talentai.assessment_execution AS execution
       ON execution.extraction_id = requested.extraction_id
      AND execution.status = 'COMPLETED'
      AND execution.current_stage = 'COMPLETED'
      AND execution.completed_at IS NOT NULL
LEFT JOIN talentai.grade_assessment AS assessment
       ON assessment.id = execution.assessment_id
      AND assessment.request_id = execution.request_id
      AND assessment.extraction_id = requested.extraction_id
      AND assessment.status = 'COMPLETED'
LEFT JOIN talentai.grade_guide AS grade_guide
       ON grade_guide.id = assessment.grade_guide_id
      AND grade_guide.guide_version = assessment.grade_guide_version;
