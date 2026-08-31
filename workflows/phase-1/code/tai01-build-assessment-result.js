const assessment = $input.first().json;

const score = Number(assessment.score?.overall ?? 0);
const minimumRequired = Number(
  assessment.score?.minimumRequired ?? 0
);
const mandatoryPassed =
  assessment.score?.mandatoryDimensionsMet === true;
const decision = assessment.decision ?? 'UNKNOWN';
const fullName =
  assessment.candidate?.fullName ?? 'Unknown candidate';
const positionCode =
  assessment.assessmentContext?.positionCode ?? '';
const targetGradeCode =
  assessment.assessmentContext?.targetGradeCode ?? '';
const requestId =
  assessment.execution?.requestId ?? assessment.requestId ?? '';
const attemptCount = Number(
  assessment.execution?.attemptCount ?? 1
);
const replayed =
  assessment.execution?.replayed === true ||
  assessment.metadata?.replayed === true;

const output = [
  'TalentAI assessment completed.',
  '',
  `Request ID: ${requestId}`,
  `Attempt: ${attemptCount}`,
  `Replayed: ${replayed ? 'YES' : 'NO'}`,
  `Candidate: ${fullName}`,
  `Position: ${positionCode}`,
  `Target Grade: ${targetGradeCode}`,
  `Overall Score: ${score} / 100`,
  `Required Score: ${minimumRequired} / 100`,
  `Mandatory Requirements: ${
    mandatoryPassed ? 'PASSED' : 'NOT PASSED'
  }`,
  `Decision: ${decision}`,
  '',
  `Assessment ID: ${assessment.assessmentId}`,
  `Extraction ID: ${assessment.extractionId}`,
  `Grade Guide: ${assessment.gradeGuide?.version}`,
  `Model: ${assessment.metadata?.scoringModel}`,
].join('\n');

return [
  {
    json: {
      output,
      requestId,
      attemptCount,
      replayed,
      assessmentId: assessment.assessmentId,
      extractionId: assessment.extractionId,
      candidateName: fullName,
      positionCode,
      targetGradeCode,
      overallScore: score,
      minimumRequiredScore: minimumRequired,
      thresholdMet: assessment.score?.thresholdMet,
      mandatoryDimensionsMet: mandatoryPassed,
      decision,
      gradeGuideVersion: assessment.gradeGuide?.version,
      scoringModel: assessment.metadata?.scoringModel,
      createdAt: assessment.metadata?.createdAt,
    },
  },
];
