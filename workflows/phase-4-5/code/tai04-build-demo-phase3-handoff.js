const resolved = $input.first().json;

if (resolved.resolutionStatus !== 'RESOLVED') {
  throw new Error(
    `UNEXPECTED_RESOLUTION_STATUS: ${resolved.resolutionStatus}`
  );
}

const asIsoDate = (value, fieldName) => {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    throw new Error(
      `INVALID_PHASE3_HANDOFF_SOURCE: ${fieldName} must be a valid date-time.`
    );
  }

  return date.toISOString();
};

const candidate =
  resolved.candidate &&
  typeof resolved.candidate === 'object' &&
  !Array.isArray(resolved.candidate)
    ? resolved.candidate
    : {};

return [
  {
    json: {
      gradeCatalog: {
        id: resolved.gradeGuideId,
        version: resolved.gradeGuideVersion,
        grades: resolved.gradeDefinitions,
      },
      phase3Handoff: {
        contract: 'talentai.phase3.assessment-handoff',
        contractVersion: '1.0.0',
        requestId: resolved.requestId,
        assessmentId: resolved.assessmentId,
        extractionId: resolved.extractionId,
        candidate: {
          fullName: String(candidate.fullName ?? '').trim(),
        },
        assessmentContext: {
          positionCode: resolved.positionCode,
          targetGradeCode: resolved.targetGradeCode,
          jobDescription: resolved.jobDescription,
        },
        gradeGuide: {
          id: resolved.gradeGuideId,
          version: resolved.gradeGuideVersion,
        },
        score: {
          overall: Number(resolved.overallScore),
          minimumRequired: Number(resolved.minimumOverallScore),
          thresholdMet: resolved.thresholdMet === true,
          mandatoryDimensionsMet:
            resolved.mandatoryDimensionsMet === true,
        },
        decision: resolved.decision,
        dimensionAssessments: resolved.dimensionAssessments,
        reviewReasons: resolved.reviewReasons,
        modelWarnings: resolved.modelWarnings,
        assessmentSummary: resolved.assessmentSummary,
        execution: {
          attemptCount: Number(resolved.attemptCount),
          status: resolved.executionStatus,
          replayed: false,
          startedAt: asIsoDate(resolved.startedAt, 'startedAt'),
          completedAt: asIsoDate(resolved.completedAt, 'completedAt'),
        },
        metadata: {
          scoringModel: resolved.scoringModel,
          promptVersion: resolved.promptVersion,
          engineVersion: resolved.engineVersion,
          assessmentStatus: resolved.assessmentStatus,
          createdAt: asIsoDate(
            resolved.assessmentCreatedAt,
            'assessmentCreatedAt'
          ),
        },
      },
    },
  },
];
