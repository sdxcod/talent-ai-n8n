const extracted = $input.first().json;
const intake = $('Validate Assessment Intake').first().json;

const resumeText = String(extracted.text ?? '')
  .replace(/\r\n?/g, '\n')
  .trim();

if (resumeText.length < 20) {
  throw new Error(
    'RESUME_TEXT_EMPTY: the uploaded PDF did not yield usable text.'
  );
}

const inputFingerprintSource = JSON.stringify({
  schemaVersion: '1.0',
  positionCode: intake.positionCode,
  targetGradeCode: intake.targetGradeCode,
  jobDescription: intake.jobDescription,
  resumeText,
});

return [
  {
    json: {
      requestId: intake.requestId,
      inputFingerprintSource,
      workflowExecutionId: String($execution.id),
      positionCode: intake.positionCode,
      targetGradeCode: intake.targetGradeCode,
    },
  },
];
