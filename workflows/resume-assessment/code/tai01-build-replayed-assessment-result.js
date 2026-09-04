const replay = $input.first().json;

return [
  {
    json: {
      schemaVersion: '1.0',
      requestId: replay.requestId,
      assessmentId: replay.assessmentId,
      extractionId: replay.extractionId,
      candidate: {
        fullName: replay.candidate?.fullName ?? '',
      },
      assessmentContext: {
        positionCode: replay.positionCode,
        targetGradeCode: replay.targetGradeCode,
        jobDescription: replay.jobDescription,
      },
      gradeGuide: {
        id: replay.gradeGuideId,
        version: replay.gradeGuideVersion,
      },
      score: {
        overall: Number(replay.overallScore),
        minimumRequired: Number(replay.minimumOverallScore),
        thresholdMet: replay.thresholdMet,
        mandatoryDimensionsMet: replay.mandatoryDimensionsMet,
      },
      decision: replay.decision,
      dimensionAssessments: replay.dimensionAssessments,
      reviewReasons: replay.reviewReasons,
      modelWarnings: replay.modelWarnings,
      assessmentSummary: replay.assessmentSummary,
      execution: {
        requestId: replay.requestId,
        attemptCount: Number(replay.attemptCount),
        status: replay.executionStatus,
        replayed: true,
        startedAt: replay.startedAt,
        completedAt: replay.completedAt,
      },
      metadata: {
        scoringModel: replay.scoringModel,
        promptVersion: replay.promptVersion,
        engineVersion: replay.engineVersion,
        status: replay.assessmentStatus,
        createdAt: replay.assessmentCreatedAt,
        wasInserted: false,
        replayed: true,
      },
    },
  },
];
