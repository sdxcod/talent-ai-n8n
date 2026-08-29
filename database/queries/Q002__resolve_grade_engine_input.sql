WITH requested AS
(
    SELECT $1::UUID AS extraction_id
)
SELECT
    CASE
        WHEN re.id IS NULL
            THEN 'EXTRACTION_NOT_FOUND'
        WHEN re.status <> 'EXTRACTED'
            THEN 'EXTRACTION_NOT_READY'
        WHEN re.profile_schema_version <> '1.0'
            THEN 'PROFILE_SCHEMA_UNSUPPORTED'
        WHEN jsonb_typeof(re.profile) <> 'object'
            THEN 'PROFILE_INVALID'
        WHEN NULLIF(BTRIM(re.target_grade_code), '') IS NULL
             OR re.target_grade_code = 'UNSPECIFIED'
            THEN 'TARGET_GRADE_UNSPECIFIED'
        WHEN gg.id IS NULL
            THEN 'ACTIVE_GRADE_GUIDE_NOT_FOUND'
        WHEN selected_grade.grade_definition IS NULL
            THEN 'TARGET_GRADE_NOT_FOUND'
        ELSE 'RESOLVED'
    END AS "resolutionStatus",

    CASE
        WHEN re.id IS NULL
            THEN 'Resume extraction was not found.'
        WHEN re.status <> 'EXTRACTED'
            THEN 'Resume extraction is not ready for grading.'
        WHEN re.profile_schema_version <> '1.0'
            THEN 'Resume profile schema version is not supported.'
        WHEN jsonb_typeof(re.profile) <> 'object'
            THEN 'Resume profile must be a JSON object.'
        WHEN NULLIF(BTRIM(re.target_grade_code), '') IS NULL
             OR re.target_grade_code = 'UNSPECIFIED'
            THEN 'Target grade code is not specified.'
        WHEN gg.id IS NULL
            THEN 'No active grade guide exists for the requested position.'
        WHEN selected_grade.grade_definition IS NULL
            THEN 'Target grade does not exist in the active grade guide.'
        ELSE 'Grade guide resolved successfully.'
    END AS "resolutionMessage",

    requested.extraction_id                 AS "requestedExtractionId",
    re.id                                   AS "extractionId",
    re.workflow_execution_id                AS "workflowExecutionId",
    re.position_code                        AS "positionCode",
    re.target_grade_code                    AS "targetGradeCode",
    re.source_file_name                     AS "sourceFileName",
    re.extraction_model                     AS "extractionModel",
    re.status                               AS "extractionStatus",
    re.profile_schema_version               AS "profileSchemaVersion",
    re.job_description                      AS "jobDescription",
    re.profile                              AS profile,
    re.created_at                           AS "extractedAt",
    gg.id                                   AS "gradeGuideId",
    gg.guide_version                        AS "gradeGuideVersion",
    gg.guide_schema_version                 AS "gradeGuideSchemaVersion",
    selected_grade.grade_definition         AS "gradeDefinition",
    gg.guide -> 'dimensions'                AS dimensions,
    gg.guide -> 'scoringScale'              AS "scoringScale",
    gg.guide -> 'evidencePolicy'             AS "evidencePolicy",
    gg.guide -> 'decisionPolicy'             AS "decisionPolicy"
FROM requested
LEFT JOIN talentai.resume_extraction AS re
       ON re.id = requested.extraction_id
LEFT JOIN talentai.grade_guide AS gg
       ON gg.position_code = re.position_code
      AND gg.status = 'ACTIVE'
LEFT JOIN LATERAL
(
    SELECT grade AS grade_definition
    FROM jsonb_array_elements(
        COALESCE(gg.guide -> 'grades', '[]'::JSONB)
    ) AS grade
    WHERE grade ->> 'code' = re.target_grade_code
    LIMIT 1
) AS selected_grade ON TRUE;
