WITH requested AS
(
    SELECT
        'JAVA_BACKEND'::VARCHAR AS position_code,
        'MID'::VARCHAR          AS target_grade_code
)
SELECT
    gg.id                              AS grade_guide_id,
    gg.position_code,
    gg.guide_version,
    gg.guide_schema_version,
    requested.target_grade_code,
    grade_definition,
    gg.guide -> 'dimensions'           AS dimensions,
    gg.guide -> 'scoringScale'         AS scoring_scale,
    gg.guide -> 'evidencePolicy'        AS evidence_policy,
    gg.guide -> 'decisionPolicy'        AS decision_policy
FROM talentai.grade_guide AS gg
JOIN requested
  ON requested.position_code = gg.position_code
CROSS JOIN LATERAL jsonb_array_elements(gg.guide -> 'grades') AS grade_definition
WHERE gg.status = 'ACTIVE'
  AND grade_definition ->> 'code' = requested.target_grade_code;
