WITH inserted AS
(
    INSERT INTO talentai.grade_assessment
    (
        workflow_execution_id,
        extraction_id,
        grade_guide_id,
        grade_guide_version,
        target_grade_code,
        scoring_model,
        prompt_version,
        engine_version,
        dimension_assessments,
        overall_score,
        minimum_overall_score,
        threshold_met,
        mandatory_dimensions_met,
        decision,
        review_reasons,
        model_warnings,
        assessment_summary,
        status
    )
    VALUES
    (
        $1,
        $2::UUID,
        $3::UUID,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9::JSONB,
        $10::NUMERIC(5, 2),
        $11::NUMERIC(5, 2),
        $12::BOOLEAN,
        $13::BOOLEAN,
        $14,
        $15::JSONB,
        $16::JSONB,
        $17,
        'COMPLETED'
    )
    ON CONFLICT (workflow_execution_id) DO NOTHING
    RETURNING *
),
selected AS
(
    SELECT inserted.*, TRUE AS was_inserted
    FROM inserted

    UNION ALL

    SELECT existing.*, FALSE AS was_inserted
    FROM talentai.grade_assessment AS existing
    WHERE existing.workflow_execution_id = $1
      AND NOT EXISTS (SELECT 1 FROM inserted)
)
SELECT
    id                              AS "assessmentId",
    workflow_execution_id           AS "workflowExecutionId",
    extraction_id                   AS "extractionId",
    grade_guide_id                  AS "gradeGuideId",
    grade_guide_version             AS "gradeGuideVersion",
    target_grade_code               AS "targetGradeCode",
    scoring_model                   AS "scoringModel",
    prompt_version                  AS "promptVersion",
    engine_version                  AS "engineVersion",
    dimension_assessments           AS "dimensionAssessments",
    overall_score                   AS "overallScore",
    minimum_overall_score           AS "minimumOverallScore",
    threshold_met                   AS "thresholdMet",
    mandatory_dimensions_met        AS "mandatoryDimensionsMet",
    decision,
    review_reasons                  AS "reviewReasons",
    model_warnings                  AS "modelWarnings",
    assessment_summary              AS "assessmentSummary",
    status,
    created_at                      AS "createdAt",
    was_inserted                    AS "wasInserted"
FROM selected
LIMIT 1;
