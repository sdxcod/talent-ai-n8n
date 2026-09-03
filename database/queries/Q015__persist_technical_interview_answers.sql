WITH supplied AS
(
    SELECT
        $1::UUID                              AS session_id,
        NULLIF(BTRIM($2), '')                 AS workflow_execution_id,
        $3::UUID                              AS question_set_id,
        $4::JSONB                             AS answer_records
),
eligible AS
(
    SELECT
        supplied.*,
        question_set.round,
        question_set.question_plan,
        question_set.question_count,
        session.current_stage,
        CASE question_set.round
            WHEN 'FIRST' THEN 'FIRST_ROUND'
            WHEN 'FOLLOW_UP' THEN 'FOLLOW_UP'
        END AS expected_stage,
        CASE question_set.round
            WHEN 'FIRST' THEN 'FOLLOW_UP_GENERATION'
            WHEN 'FOLLOW_UP' THEN 'ANSWER_EVALUATION'
        END AS next_stage
    FROM supplied
    JOIN talentai.technical_question_set AS question_set
      ON question_set.id = supplied.question_set_id
     AND question_set.session_id = supplied.session_id
    JOIN talentai.technical_interview_session AS session
      ON session.id = supplied.session_id
     AND session.status = 'RUNNING'
     AND session.claim_owner_workflow_execution_id
         = supplied.workflow_execution_id
    WHERE jsonb_typeof(supplied.answer_records) = 'array'
),
records AS
(
    SELECT
        eligible.*,
        answer_record,
        CASE answer_record ->> 'round'
            WHEN 'first' THEN 'FIRST'
            WHEN 'followUp' THEN 'FOLLOW_UP'
        END AS answer_round,
        NULLIF(BTRIM(answer_record ->> 'id'), '') AS question_id,
        NULLIF(BTRIM(answer_record ->> 'dimensionCode'), '') AS dimension_code,
        NULLIF(BTRIM(answer_record ->> 'type'), '') AS question_type
    FROM eligible
    CROSS JOIN LATERAL jsonb_array_elements(
        eligible.answer_records
    ) AS item(answer_record)
),
validated AS
(
    SELECT records.*
    FROM records
    WHERE records.answer_round = records.round
      AND EXISTS
      (
          SELECT 1
          FROM jsonb_array_elements(
              records.question_plan -> 'questions'
          ) AS planned(question)
          WHERE planned.question ->> 'id' = records.question_id
            AND planned.question ->> 'dimensionCode'
                = records.dimension_code
            AND planned.question ->> 'type' = records.question_type
      )
      AND records.answer_record ? 'answerLabels'
      AND records.answer_record ? 'answerText'
),
validation AS
(
    SELECT
        eligible.*,
        COUNT(validated.question_id)::INTEGER AS valid_count,
        COUNT(DISTINCT validated.question_id)::INTEGER AS unique_count
    FROM eligible
    LEFT JOIN validated
      ON validated.session_id = eligible.session_id
     AND validated.question_set_id = eligible.question_set_id
    GROUP BY
        eligible.session_id,
        eligible.workflow_execution_id,
        eligible.question_set_id,
        eligible.answer_records,
        eligible.round,
        eligible.question_plan,
        eligible.question_count,
        eligible.current_stage,
        eligible.expected_stage,
        eligible.next_stage
),
persisted AS
(
    INSERT INTO talentai.technical_interview_answer AS existing
    (
        session_id,
        question_set_id,
        round,
        question_id,
        dimension_code,
        question_type,
        answer_payload,
        deterministic_score,
        model_score,
        final_score,
        rationale,
        status,
        evaluated_at
    )
    SELECT
        validated.session_id,
        validated.question_set_id,
        validated.round,
        validated.question_id,
        validated.dimension_code,
        validated.question_type,
        jsonb_build_object(
            'questionText', validated.answer_record ->> 'questionText',
            'answerLabels', validated.answer_record -> 'answerLabels',
            'answerText', validated.answer_record ->> 'answerText'
        ),
        NULLIF(validated.answer_record ->> 'mcqScore', '')::NUMERIC,
        NULLIF(validated.answer_record ->> 'llmScore', '')::NUMERIC,
        NULLIF(validated.answer_record ->> 'finalScore', '')::NUMERIC,
        COALESCE(validated.answer_record ->> 'llmRationale', ''),
        CASE
            WHEN validated.answer_record ->> 'finalScore' IS NULL
                THEN 'SUBMITTED'
            ELSE 'EVALUATED'
        END,
        CASE
            WHEN validated.answer_record ->> 'finalScore' IS NULL
                THEN NULL
            ELSE now()
        END
    FROM validated
    JOIN validation
      ON validation.session_id = validated.session_id
     AND validation.question_set_id = validated.question_set_id
     AND validation.valid_count = validation.question_count
     AND validation.unique_count = validation.question_count
     AND validation.current_stage IN
         (validation.expected_stage, validation.next_stage)
    ON CONFLICT ON CONSTRAINT uq_technical_interview_answer_question
    DO UPDATE SET
        answer_payload = existing.answer_payload
    WHERE existing.question_set_id = EXCLUDED.question_set_id
      AND existing.dimension_code = EXCLUDED.dimension_code
      AND existing.question_type = EXCLUDED.question_type
      AND existing.answer_payload = EXCLUDED.answer_payload
      AND existing.deterministic_score IS NOT DISTINCT FROM
          EXCLUDED.deterministic_score
      AND existing.model_score IS NOT DISTINCT FROM EXCLUDED.model_score
      AND existing.final_score IS NOT DISTINCT FROM EXCLUDED.final_score
      AND existing.rationale = EXCLUDED.rationale
    RETURNING existing.*
),
persisted_count AS
(
    SELECT COUNT(*)::INTEGER AS value FROM persisted
),
advanced AS
(
    UPDATE talentai.technical_interview_session AS session
    SET
        current_stage = validation.next_stage,
        last_workflow_execution_id = validation.workflow_execution_id,
        updated_at = now()
    FROM validation, persisted_count
    WHERE session.id = validation.session_id
      AND session.current_stage = validation.expected_stage
      AND validation.valid_count = validation.question_count
      AND validation.unique_count = validation.question_count
      AND persisted_count.value = validation.question_count
    RETURNING session.id
)
SELECT
    validation.session_id                     AS "sessionId",
    validation.question_set_id                AS "questionSetId",
    validation.round                          AS round,
    persisted_count.value                     AS "persistedCount",
    validation.question_count                 AS "expectedCount",
    (
        persisted_count.value = validation.question_count
    )                                         AS "complete",
    CASE
        WHEN persisted_count.value = validation.question_count
            THEN validation.next_stage
        ELSE validation.current_stage
    END                                       AS "currentStage"
FROM validation
CROSS JOIN persisted_count;
