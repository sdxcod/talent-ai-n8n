WITH eligible AS
(
    SELECT session.*
    FROM talentai.technical_interview_session AS session
    WHERE session.id = $1::UUID
      AND session.status = 'RUNNING'
      AND session.claim_owner_workflow_execution_id = NULLIF(BTRIM($2), '')
),
first_question_set AS
(
    SELECT question_set.*
    FROM talentai.technical_question_set AS question_set
    JOIN eligible ON eligible.id = question_set.session_id
    WHERE question_set.round = 'FIRST'
    ORDER BY question_set.version DESC
    LIMIT 1
),
follow_up_question_set AS
(
    SELECT question_set.*
    FROM talentai.technical_question_set AS question_set
    JOIN eligible ON eligible.id = question_set.session_id
    WHERE question_set.round = 'FOLLOW_UP'
    ORDER BY question_set.version DESC
    LIMIT 1
),
answers AS
(
    SELECT
        answer.session_id,
        answer.round,
        jsonb_agg(
            jsonb_build_object(
                'round', CASE answer.round
                    WHEN 'FIRST' THEN 'first'
                    WHEN 'FOLLOW_UP' THEN 'followUp'
                END,
                'id', answer.question_id,
                'dimensionCode', answer.dimension_code,
                'type', answer.question_type,
                'questionText', answer.answer_payload ->> 'questionText',
                'answerLabels', answer.answer_payload -> 'answerLabels',
                'answerText', answer.answer_payload ->> 'answerText',
                'mcqScore', answer.deterministic_score,
                'llmScore', answer.model_score,
                'llmRationale', answer.rationale,
                'finalScore', answer.final_score
            )
            ORDER BY answer.submitted_at, answer.question_id
        ) AS answer_records,
        COUNT(*)::INTEGER AS answer_count,
        COUNT(*) FILTER (
            WHERE answer.status = 'EVALUATED'
        )::INTEGER AS evaluated_count
    FROM talentai.technical_interview_answer AS answer
    JOIN eligible ON eligible.id = answer.session_id
    GROUP BY answer.session_id, answer.round
)
SELECT
    eligible.id                                      AS "sessionId",
    eligible.current_stage                           AS "currentStage",
    eligible.attempt_count                           AS "attemptCount",
    first_question_set.id                            AS "firstQuestionSetId",
    first_question_set.version                       AS "firstQuestionSetVersion",
    first_question_set.question_plan                 AS "firstQuestionPlan",
    first_question_set.question_count                AS "firstQuestionCount",
    COALESCE(first_answers.answer_records, '[]'::JSONB)
                                                       AS "firstAnswerRecords",
    COALESCE(first_answers.answer_count, 0)           AS "firstAnswerCount",
    follow_up_question_set.id                        AS "followUpQuestionSetId",
    follow_up_question_set.version                   AS "followUpQuestionSetVersion",
    follow_up_question_set.question_plan             AS "followUpQuestionPlan",
    follow_up_question_set.question_count            AS "followUpQuestionCount",
    COALESCE(follow_up_answers.answer_records, '[]'::JSONB)
                                                       AS "followUpAnswerRecords",
    COALESCE(follow_up_answers.answer_count, 0)       AS "followUpAnswerCount",
    COALESCE(first_answers.evaluated_count, 0)
      + COALESCE(follow_up_answers.evaluated_count, 0)
                                                       AS "evaluatedAnswerCount",
    eligible.evaluation_payload                      AS "evaluationPayload"
FROM eligible
LEFT JOIN first_question_set ON TRUE
LEFT JOIN follow_up_question_set ON TRUE
LEFT JOIN answers AS first_answers
  ON first_answers.session_id = eligible.id
 AND first_answers.round = 'FIRST'
LEFT JOIN answers AS follow_up_answers
  ON follow_up_answers.session_id = eligible.id
 AND follow_up_answers.round = 'FOLLOW_UP';
