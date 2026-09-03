DO $queries$
DECLARE
    v_request_id UUID := '50000000-0000-4000-8000-000000000001';
    v_assessment_id UUID := '50000000-0000-4000-8000-000000000002';
    v_extraction_id UUID := '50000000-0000-4000-8000-000000000003';
    v_retry_request_id UUID := '50000000-0000-4000-8000-000000000004';
    v_retry_assessment_id UUID := '50000000-0000-4000-8000-000000000005';
    v_retry_extraction_id UUID := '50000000-0000-4000-8000-000000000006';
    v_session_id UUID;
    v_first_question_set_id UUID;
    v_follow_up_question_set_id UUID;
    v_result_id UUID;
    v_retry_session_id UUID;
    v_row RECORD;
    v_count INTEGER;
BEGIN
    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_session(
        '1.0.0',
        v_request_id::TEXT,
        v_assessment_id::TEXT,
        v_extraction_id::TEXT,
        'interview-query-test-1'
    );

    IF v_row."claimStatus" <> 'CLAIMED_NEW'
       OR v_row."canContinue" IS NOT TRUE
       OR v_row."attemptCount" <> 1
       OR v_row."currentStage" <> 'QUESTION_GENERATION' THEN
        RAISE EXCEPTION 'New technical interview claim failed: %', v_row;
    END IF;

    v_session_id := v_row."sessionId";

    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_session(
        '1.0.0',
        v_request_id::TEXT,
        v_assessment_id::TEXT,
        '50000000-0000-4000-8000-000000000099',
        'interview-query-test-2'
    );

    IF v_row."claimStatus" <> 'HANDOFF_CONFLICT'
       OR v_row."canContinue" IS NOT FALSE THEN
        RAISE EXCEPTION 'Handoff conflict was not rejected: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_session(
        '1.0.0',
        v_request_id::TEXT,
        v_assessment_id::TEXT,
        v_extraction_id::TEXT,
        'interview-query-test-2'
    );

    IF v_row."claimStatus" <> 'ALREADY_RUNNING'
       OR v_row."canContinue" IS NOT FALSE THEN
        RAISE EXCEPTION 'Concurrent claim was not rejected: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.persist_technical_question_set(
        v_session_id,
        'interview-query-test-1',
        'FIRST',
        '{
          "schemaVersion": "1.0",
          "round": "first",
          "questions": [{
            "id": "Q1",
            "dimensionCode": "JAVA_CORE",
            "type": "single_choice",
            "questionText": "Which Java behavior is correct?",
            "options": [
              {"label": "A", "score": 1},
              {"label": "B", "score": 3},
              {"label": "C", "score": 0}
            ]
          }]
        }'::JSONB,
        'gpt-test',
        '1.0'
    );

    IF v_row."wasInserted" IS NOT TRUE
       OR v_row."version" <> 1
       OR v_row."currentStage" <> 'FIRST_ROUND' THEN
        RAISE EXCEPTION 'First question set persistence failed: %', v_row;
    END IF;

    v_first_question_set_id := v_row."questionSetId";

    SELECT * INTO STRICT v_row
    FROM pg_temp.persist_technical_question_set(
        v_session_id,
        'interview-query-test-1',
        'FIRST',
        '{
          "schemaVersion": "1.0",
          "round": "first",
          "questions": [{
            "id": "Q1",
            "dimensionCode": "JAVA_CORE",
            "type": "single_choice",
            "questionText": "Which Java behavior is correct?",
            "options": [
              {"label": "A", "score": 1},
              {"label": "B", "score": 3},
              {"label": "C", "score": 0}
            ]
          }]
        }'::JSONB,
        'gpt-test',
        '1.0'
    );

    IF v_row."wasInserted" IS NOT FALSE
       OR v_row."questionSetId" <> v_first_question_set_id THEN
        RAISE EXCEPTION 'Question set replay was not idempotent: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.persist_technical_interview_answers(
        v_session_id,
        'interview-query-test-1',
        v_first_question_set_id,
        '[{
          "round": "first",
          "id": "Q1",
          "dimensionCode": "JAVA_CORE",
          "type": "single_choice",
          "questionText": "Which Java behavior is correct?",
          "answerLabels": ["B"],
          "answerText": "",
          "mcqScore": 3,
          "llmScore": null,
          "llmRationale": "",
          "finalScore": 3
        }]'::JSONB
    );

    IF v_row."complete" IS NOT TRUE
       OR v_row."persistedCount" <> 1
       OR v_row."currentStage" <> 'FOLLOW_UP_GENERATION' THEN
        RAISE EXCEPTION 'First-round answer persistence failed: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.persist_technical_question_set(
        v_session_id,
        'interview-query-test-1',
        'FOLLOW_UP',
        '{
          "schemaVersion": "1.0",
          "round": "followUp",
          "questions": [{
            "id": "F1",
            "dimensionCode": "JAVA_CORE",
            "type": "explanatory",
            "questionText": "Explain the trade-off you would make.",
            "options": []
          }]
        }'::JSONB,
        'gpt-test',
        '1.0'
    );

    IF v_row."wasInserted" IS NOT TRUE
       OR v_row."currentStage" <> 'FOLLOW_UP' THEN
        RAISE EXCEPTION 'Follow-up question set persistence failed: %', v_row;
    END IF;

    v_follow_up_question_set_id := v_row."questionSetId";

    SELECT * INTO STRICT v_row
    FROM pg_temp.persist_technical_interview_answers(
        v_session_id,
        'interview-query-test-1',
        v_follow_up_question_set_id,
        '[{
          "round": "followUp",
          "id": "F1",
          "dimensionCode": "JAVA_CORE",
          "type": "explanatory",
          "questionText": "Explain the trade-off you would make.",
          "answerLabels": [],
          "answerText": "A concrete technical explanation.",
          "mcqScore": null,
          "llmScore": null,
          "llmRationale": "",
          "finalScore": null
        }]'::JSONB
    );

    IF v_row."complete" IS NOT TRUE
       OR v_row."currentStage" <> 'ANSWER_EVALUATION' THEN
        RAISE EXCEPTION 'Follow-up answer persistence failed: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.apply_technical_answer_evaluations(
        v_session_id,
        'interview-query-test-1',
        '[
          {
            "round": "first",
            "id": "Q1",
            "dimensionCode": "JAVA_CORE",
            "type": "single_choice",
            "mcqScore": 3,
            "llmScore": null,
            "llmRationale": "",
            "finalScore": 3
          },
          {
            "round": "followUp",
            "id": "F1",
            "dimensionCode": "JAVA_CORE",
            "type": "explanatory",
            "mcqScore": null,
            "llmScore": 2,
            "llmRationale": "Concrete but limited trade-off analysis.",
            "finalScore": 2
          }
        ]'::JSONB,
        '{
          "schemaVersion": "1.0",
          "interviewSummary": "Synthetic evaluation summary.",
          "warnings": []
        }'::JSONB
    );

    IF v_row."complete" IS NOT TRUE
       OR v_row."answerCount" <> 2
       OR v_row."evaluatedCount" <> 2
       OR v_row."currentStage" <> 'RESULT_PERSISTENCE' THEN
        RAISE EXCEPTION 'Answer evaluation persistence failed: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.load_technical_interview_checkpoint(
        v_session_id,
        'interview-query-test-1'
    );

    IF v_row."currentStage" <> 'RESULT_PERSISTENCE'
       OR v_row."firstQuestionSetId" <> v_first_question_set_id
       OR v_row."firstAnswerCount" <> 1
       OR v_row."followUpQuestionSetId" <> v_follow_up_question_set_id
       OR v_row."followUpAnswerCount" <> 1
       OR v_row."evaluatedAnswerCount" <> 2
       OR v_row."evaluationPayload" ->> 'interviewSummary'
          <> 'Synthetic evaluation summary.' THEN
        RAISE EXCEPTION 'Interview checkpoint could not be reconstructed: %', v_row;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM pg_temp.load_technical_interview_checkpoint(
        v_session_id,
        'interview-query-wrong-owner'
    );

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Non-owner workflow loaded interview checkpoint';
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.complete_technical_interview(
        v_session_id,
        'interview-query-test-1',
        '{
          "schemaVersion": "1.0",
          "interviewExecutionId": "interview-query-test-1",
          "assignedGrade": {"code": "MID", "label": "Mid"},
          "score": {
            "overall": 75,
            "scale": "0-100",
            "dimensions": []
          },
          "gradeChecks": [],
          "interview": {
            "summary": "A defensible synthetic result.",
            "warnings": []
          }
        }'::JSONB
    );

    IF v_row.status <> 'COMPLETED'
       OR v_row."currentStage" <> 'COMPLETED'
       OR v_row."wasInserted" IS NOT TRUE THEN
        RAISE EXCEPTION 'Interview completion failed: %', v_row;
    END IF;

    v_result_id := v_row."resultId";

    SELECT * INTO STRICT v_row
    FROM pg_temp.load_completed_technical_interview(
        '1.0.0',
        v_request_id,
        v_assessment_id
    );

    IF v_row."sessionId" <> v_session_id
       OR v_row."resultId" <> v_result_id
       OR v_row."attemptCount" <> 1 THEN
        RAISE EXCEPTION 'Completed interview replay load failed: %', v_row;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_session(
        '1.0.0',
        v_request_id::TEXT,
        v_assessment_id::TEXT,
        v_extraction_id::TEXT,
        'interview-query-test-2'
    );

    IF v_row."claimStatus" <> 'COMPLETED_REPLAY'
       OR v_row."canContinue" IS NOT FALSE
       OR v_row."attemptCount" <> 1 THEN
        RAISE EXCEPTION 'Completed claim was not replay-safe: %', v_row;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM talentai.technical_question_set
    WHERE session_id = v_session_id;

    IF v_count <> 2 THEN
        RAISE EXCEPTION 'Expected two immutable question sets, found %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM talentai.technical_interview_answer
    WHERE session_id = v_session_id;

    IF v_count <> 2 THEN
        RAISE EXCEPTION 'Expected two idempotent answer rows, found %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM talentai.technical_interview_result
    WHERE session_id = v_session_id;

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Expected one immutable result, found %', v_count;
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_session(
        '1.0.0',
        v_retry_request_id::TEXT,
        v_retry_assessment_id::TEXT,
        v_retry_extraction_id::TEXT,
        'interview-query-retry-1'
    );

    v_retry_session_id := v_row."sessionId";

    SELECT * INTO STRICT v_row
    FROM pg_temp.fail_technical_interview_session(
        v_retry_session_id,
        'interview-query-retry-1',
        'QUESTION_GENERATION',
        'PROVIDER',
        'QUESTION_GENERATION_FAILED',
        E'Synthetic retryable\tfailure.\nPrivate payload omitted.',
        TRUE
    );

    IF v_row.status <> 'FAILED'
       OR v_row."currentStage" <> 'QUESTION_GENERATION'
       OR v_row."failureCategory" <> 'PROVIDER'
       OR v_row."failureCode" <> 'QUESTION_GENERATION_FAILED'
       OR v_row."failureMessage" ~ E'[\r\n\t]'
       OR v_row.retryable IS NOT TRUE
       OR v_row."failedAt" IS NULL THEN
        RAISE EXCEPTION 'Controlled interview failure was not recorded: %', v_row;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM pg_temp.fail_technical_interview_session(
        v_retry_session_id,
        'interview-query-retry-wrong-owner',
        'QUESTION_GENERATION',
        'PROVIDER',
        'SHOULD_NOT_BE_RECORDED',
        'Wrong owner must not overwrite the failure.',
        TRUE
    );

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Non-owner workflow overwrote interview failure state';
    END IF;

    SELECT * INTO STRICT v_row
    FROM pg_temp.claim_technical_interview_session(
        '1.0.0',
        v_retry_request_id::TEXT,
        v_retry_assessment_id::TEXT,
        v_retry_extraction_id::TEXT,
        'interview-query-retry-2'
    );

    IF v_row."claimStatus" <> 'CLAIMED_RETRY'
       OR v_row."canContinue" IS NOT TRUE
       OR v_row."attemptCount" <> 2
       OR v_row."currentStage" <> 'QUESTION_GENERATION'
       OR v_row."failureCode" IS NOT NULL THEN
        RAISE EXCEPTION 'Retryable interview claim failed: %', v_row;
    END IF;

    RAISE NOTICE 'Technical interview query assertions passed.';
END
$queries$;
