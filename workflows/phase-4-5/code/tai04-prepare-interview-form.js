const prepared = $input.first().json;

if (
  !prepared.questionPlan ||
  !Array.isArray(prepared.questionPlan.questions) ||
  !Array.isArray(prepared.formFields) ||
  prepared.questionPlan.questions.length !== prepared.formFields.length ||
  prepared.formFields.length < 1
) {
  throw new Error('INTERVIEW_FORM_CHECKPOINT_INVALID');
}

return [{ json: prepared }];
