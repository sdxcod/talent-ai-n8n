BEGIN;

CREATE TEMPORARY TABLE phase45_end_to_end_correlation
ON COMMIT DROP
AS
WITH correlated AS
(
    SELECT
        execution.request_id,
        execution.extraction_id,
        assessment.id                              AS assessment_id,
        session.id                                 AS session_id,
        result.id                                  AS result_id,
        execution.status                           AS assessment_status,
        execution.current_stage                    AS assessment_stage,
        session.status                              AS interview_status,
        session.current_stage                       AS interview_stage,
        session.attempt_count                       AS interview_attempt_count,
        result.result_version,
        result.overall_score,
        result.assigned_grade_code,
        result.grade_checks,
        (
            SELECT COUNT(*)
            FROM talentai.technical_question_set AS question_set
            WHERE question_set.session_id = session.id
        )::INTEGER                                  AS question_set_count,
        (
            SELECT COUNT(*)
            FROM talentai.technical_interview_answer AS answer
            WHERE answer.session_id = session.id
        )::INTEGER                                  AS answer_count,
        (
            SELECT COUNT(*)
            FROM talentai.technical_interview_answer AS answer
            WHERE answer.session_id = session.id
              AND answer.status = 'EVALUATED'
        )::INTEGER                                  AS evaluated_answer_count,
        (
            SELECT COUNT(*)
            FROM talentai.technical_interview_result AS stored_result
            WHERE stored_result.session_id = session.id
        )::INTEGER                                  AS result_count
    FROM talentai.assessment_execution AS execution
    JOIN talentai.grade_assessment AS assessment
      ON assessment.id = execution.assessment_id
     AND assessment.request_id = execution.request_id
     AND assessment.extraction_id = execution.extraction_id
    JOIN talentai.technical_interview_session AS session
      ON session.contract_version = '1.0.0'
     AND session.request_id = execution.request_id
     AND session.assessment_id = assessment.id
     AND session.extraction_id = execution.extraction_id
    JOIN talentai.technical_interview_result AS result
      ON result.session_id = session.id
     AND result.result_version = 1
    WHERE execution.extraction_id = :'extraction_id'::UUID
),
resolved AS
(
    SELECT
        correlated.*,
        COALESCE(
            (
                SELECT grade_check ->> 'code'
                FROM jsonb_array_elements(
                    COALESCE(correlated.grade_checks, '[]'::JSONB)
                ) AS item(grade_check)
                WHERE COALESCE(
                    (grade_check ->> 'met')::BOOLEAN,
                    FALSE
                )
                ORDER BY
                    (grade_check ->> 'minimumOverallScore')::NUMERIC DESC
                LIMIT 1
            ),
            'NO_MATCH'
        )                                          AS expected_assigned_grade
    FROM correlated
)
SELECT
    resolved.request_id,
    resolved.assessment_id,
    resolved.extraction_id,
    resolved.session_id,
    resolved.result_id,
    resolved.assessment_status,
    resolved.assessment_stage,
    resolved.interview_status,
    resolved.interview_stage,
    resolved.interview_attempt_count,
    resolved.result_version,
    resolved.overall_score,
    resolved.assigned_grade_code,
    resolved.expected_assigned_grade,
    jsonb_array_length(resolved.grade_checks)       AS grade_check_count,
    resolved.question_set_count,
    resolved.answer_count,
    resolved.evaluated_answer_count,
    resolved.result_count,
    (
        resolved.assessment_status = 'COMPLETED'
        AND resolved.assessment_stage = 'COMPLETED'
        AND resolved.interview_status = 'COMPLETED'
        AND resolved.interview_stage = 'COMPLETED'
        AND resolved.result_version = 1
        AND resolved.assigned_grade_code = resolved.expected_assigned_grade
        AND jsonb_array_length(resolved.grade_checks) = 3
        AND resolved.question_set_count = 2
        AND resolved.answer_count = 30
        AND resolved.evaluated_answer_count = 30
        AND resolved.result_count = 1
    )                                              AS correlation_valid
FROM resolved;

TABLE phase45_end_to_end_correlation;

DO $phase45_correlation_assertion$
DECLARE
    correlation_count INTEGER;
    correlation_valid BOOLEAN;
BEGIN
    SELECT
        COUNT(*),
        COALESCE(BOOL_AND(check_result.correlation_valid), FALSE)
    INTO
        correlation_count,
        correlation_valid
    FROM phase45_end_to_end_correlation AS check_result;

    IF correlation_count <> 1 THEN
        RAISE EXCEPTION
            'Expected one correlated Phase 3 through Phase 5 result, found %',
            correlation_count;
    END IF;

    IF NOT correlation_valid THEN
        RAISE EXCEPTION
            'Phase 3 through Phase 5 correlation invariants failed';
    END IF;
END
$phase45_correlation_assertion$;

ROLLBACK;
