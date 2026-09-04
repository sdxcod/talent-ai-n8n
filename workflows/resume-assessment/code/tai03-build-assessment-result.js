const persisted = $('Persist Grade Assessment').first().json;
const completed = $input.first().json;
const calculated = $('Calculate Deterministic Grade').first().json;
const engineInput = calculated.gradeEngineInput;
const candidate = engineInput.candidateProfile?.candidate ?? {};

return [
  {
    json: {
      schemaVersion: '1.0',
      requestId: completed.requestId,
      assessmentId: persisted.assessmentId,
      extractionId: persisted.extractionId,
      candidate: {
        fullName: candidate.fullName ?? '',
      },
      assessmentContext: {
        positionCode: engineInput.assessmentContext.positionCode,
        targetGradeCode: persisted.targetGradeCode,
        jobDescription: engineInput.assessmentContext.jobDescription,
      },
      gradeGuide: {
        id: persisted.gradeGuideId,
        version: persisted.gradeGuideVersion,
      },
      score: {
        overall: Number(persisted.overallScore),
        minimumRequired: Number(persisted.minimumOverallScore),
        thresholdMet: persisted.thresholdMet,
        mandatoryDimensionsMet: persisted.mandatoryDimensionsMet,
      },
      decision: persisted.decision,
      dimensionAssessments: persisted.dimensionAssessments,
      reviewReasons: persisted.reviewReasons,
      modelWarnings: persisted.modelWarnings,
      assessmentSummary: persisted.assessmentSummary,
      execution: {
        requestId: completed.requestId,
        attemptCount: Number(completed.attemptCount),
        status: completed.status,
        replayed: false,
        startedAt: completed.startedAt,
        completedAt: completed.completedAt,
      },
      metadata: {
        scoringModel: persisted.scoringModel,
        promptVersion: persisted.promptVersion,
        engineVersion: persisted.engineVersion,
        status: persisted.status,
        createdAt: persisted.createdAt,
        wasInserted: persisted.wasInserted,
        replayed: false,
      },
    },
  },
];
