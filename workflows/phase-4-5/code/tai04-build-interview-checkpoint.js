const checkpoint = $input.first().json;
const interviewContext =
  $('Validate Phase 3 Handoff').first().json;

const parseJson = (value, fallback = null) => {
  if (value === null || value === undefined) return fallback;
  if (typeof value === 'string') return JSON.parse(value);
  return value;
};

const currentStage = String(checkpoint.currentStage ?? '');
const firstQuestionPlan = parseJson(checkpoint.firstQuestionPlan);
const followUpQuestionPlan = parseJson(checkpoint.followUpQuestionPlan);
const firstAnswerRecords = parseJson(
  checkpoint.firstAnswerRecords,
  []
);
const followUpAnswerRecords = parseJson(
  checkpoint.followUpAnswerRecords,
  []
);
const evaluationPayload = parseJson(
  checkpoint.evaluationPayload
);

const formFields = (plan) =>
  plan.questions.map((question, index) => {
    const field = {
      fieldLabel: `${index + 1}. ${question.questionText}`,
      fieldName: `q_${question.id}`,
      requiredField: true,
    };

    if (question.type === 'explanatory') {
      return {
        ...field,
        fieldType: 'textarea',
        placeholder: 'پاسخ خود را همین‌جا بنویسید…',
      };
    }

    return {
      ...field,
      fieldType:
        question.type === 'multi_choice' ? 'checkbox' : 'radio',
      fieldOptions: {
        values: question.options.map(
          (option) => ({ option: option.label })
        ),
      },
    };
  });

const requireQuestionPlan = (plan, expectedCount, label) => {
  if (
    !plan ||
    typeof plan !== 'object' ||
    !Array.isArray(plan.questions) ||
    plan.questions.length !== Number(expectedCount) ||
    plan.questions.length < 1
  ) {
    throw new Error(`INVALID_${label}_QUESTION_CHECKPOINT`);
  }
};

const requireAnswers = (records, expectedCount, label) => {
  if (
    !Array.isArray(records) ||
    records.length !== Number(expectedCount) ||
    records.length < 1
  ) {
    throw new Error(`INVALID_${label}_ANSWER_CHECKPOINT`);
  }
};

const requireQuestionSetId = (value, label) => {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`INVALID_${label}_QUESTION_SET_CHECKPOINT`);
  }
};

const base = {
  checkpointStage: currentStage,
  interviewContext,
  persistence: {
    sessionId: checkpoint.sessionId,
    attemptCount: Number(checkpoint.attemptCount),
    resumed: true,
  },
};

if (currentStage === 'FIRST_ROUND') {
  requireQuestionSetId(checkpoint.firstQuestionSetId, 'FIRST');
  requireQuestionPlan(
    firstQuestionPlan,
    checkpoint.firstQuestionCount,
    'FIRST'
  );

  return [{
    json: {
      ...base,
      persistence: {
        ...base.persistence,
        questionSetId: checkpoint.firstQuestionSetId,
      },
      questionPlan: firstQuestionPlan,
      formFields: formFields(firstQuestionPlan),
      interviewFormTitle: 'مصاحبه فنی TalentAI — مرحله اول',
      interviewFormDescription:
        `${interviewContext.candidate.fullName} عزیز، لطفاً به پرسش‌های مرحله اول بر پایه تجربه واقعی خود پاسخ دهید.`,
    },
  }];
}

if (currentStage === 'FOLLOW_UP_GENERATION') {
  requireAnswers(
    firstAnswerRecords,
    checkpoint.firstQuestionCount,
    'FIRST'
  );

  return [{
    json: {
      ...base,
      answerRecords: firstAnswerRecords,
    },
  }];
}

if (currentStage === 'FOLLOW_UP') {
  requireQuestionSetId(checkpoint.followUpQuestionSetId, 'FOLLOW_UP');
  requireAnswers(
    firstAnswerRecords,
    checkpoint.firstQuestionCount,
    'FIRST'
  );
  requireQuestionPlan(
    followUpQuestionPlan,
    checkpoint.followUpQuestionCount,
    'FOLLOW_UP'
  );

  return [{
    json: {
      ...base,
      persistence: {
        ...base.persistence,
        questionSetId: checkpoint.followUpQuestionSetId,
      },
      firstRoundAnswerRecords: firstAnswerRecords,
      questionPlan: followUpQuestionPlan,
      formFields: formFields(followUpQuestionPlan),
      followUpFormTitle: 'مصاحبه فنی TalentAI — مرحله تکمیلی',
      followUpFormDescription:
        `${interviewContext.candidate.fullName} عزیز، لطفاً به پرسش‌های تکمیلی بر پایه تجربه واقعی خود پاسخ دهید.`,
    },
  }];
}

if (currentStage === 'ANSWER_EVALUATION') {
  requireAnswers(
    firstAnswerRecords,
    checkpoint.firstQuestionCount,
    'FIRST'
  );
  requireAnswers(
    followUpAnswerRecords,
    checkpoint.followUpQuestionCount,
    'FOLLOW_UP'
  );

  return [{
    json: {
      ...base,
      firstRoundAnswerRecords: firstAnswerRecords,
      answerRecords: followUpAnswerRecords,
    },
  }];
}

if (currentStage === 'RESULT_PERSISTENCE') {
  const answerRecords = [
    ...firstAnswerRecords,
    ...followUpAnswerRecords,
  ];

  requireAnswers(
    answerRecords,
    Number(checkpoint.firstQuestionCount) +
      Number(checkpoint.followUpQuestionCount),
    'EVALUATED'
  );

  if (
    Number(checkpoint.evaluatedAnswerCount) !== answerRecords.length ||
    !evaluationPayload ||
    typeof evaluationPayload.interviewSummary !== 'string' ||
    !Array.isArray(evaluationPayload.warnings)
  ) {
    throw new Error('INVALID_ANSWER_EVALUATION_CHECKPOINT');
  }

  return [{
    json: {
      ...base,
      answerRecords,
      answerScoring: evaluationPayload,
    },
  }];
}

throw new Error(
  `UNSUPPORTED_INTERVIEW_CHECKPOINT_STAGE: ${currentStage || 'EMPTY'}`
);
