const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DECISIONS = new Set(['MEETS_TARGET', 'BELOW_TARGET', 'REVIEW_REQUIRED']);
const DIMENSIONS = new Set(['JAVA_CORE', 'SPRING_ECOSYSTEM', 'DATABASE', 'DISTRIBUTED_SYSTEMS', 'TESTING', 'SOFTWARE_ARCHITECTURE', 'OBSERVABILITY_DEVOPS']);
const CONFIDENCE = new Set(['HIGH', 'MEDIUM', 'LOW']);

export function projectPhase3Handoff(assessment) {
  return {
    contract: 'talentai.phase3.assessment-handoff',
    contractVersion: '1.0.0',
    requestId: assessment.requestId,
    assessmentId: assessment.assessmentId,
    extractionId: assessment.extractionId,
    candidate: { fullName: assessment.candidate?.fullName },
    assessmentContext: assessment.assessmentContext,
    gradeGuide: assessment.gradeGuide,
    score: assessment.score,
    decision: assessment.decision,
    dimensionAssessments: assessment.dimensionAssessments,
    reviewReasons: assessment.reviewReasons,
    modelWarnings: assessment.modelWarnings,
    assessmentSummary: assessment.assessmentSummary,
    execution: {
      attemptCount: assessment.execution?.attemptCount,
      status: assessment.execution?.status,
      replayed: assessment.execution?.replayed,
      startedAt: assessment.execution?.startedAt,
      completedAt: assessment.execution?.completedAt,
    },
    metadata: {
      scoringModel: assessment.metadata?.scoringModel,
      promptVersion: assessment.metadata?.promptVersion,
      engineVersion: assessment.metadata?.engineVersion,
      assessmentStatus: assessment.metadata?.status,
      createdAt: assessment.metadata?.createdAt,
    },
  };
}

export function validatePhase3Handoff(payload) {
  const errors = [];
  const requireText = (value, name) => {
    if (typeof value !== 'string' || value.trim() === '') errors.push(`${name} is required`);
  };
  if (payload?.contract !== 'talentai.phase3.assessment-handoff') errors.push('unsupported contract');
  if (payload?.contractVersion !== '1.0.0') errors.push('unsupported contractVersion');
  for (const key of ['requestId', 'assessmentId', 'extractionId']) {
    if (!UUID.test(String(payload?.[key] ?? ''))) errors.push(`${key} must be UUID`);
  }
  requireText(payload?.candidate?.fullName, 'candidate.fullName');
  if (payload?.assessmentContext?.positionCode !== 'JAVA_BACKEND') errors.push('unsupported positionCode');
  if (!['JUNIOR', 'MID', 'SENIOR'].includes(payload?.assessmentContext?.targetGradeCode)) errors.push('unsupported targetGradeCode');
  requireText(payload?.assessmentContext?.jobDescription, 'assessmentContext.jobDescription');
  if (!DECISIONS.has(payload?.decision)) errors.push('unsupported decision');
  if (payload?.execution?.status !== 'COMPLETED') errors.push('execution.status must be COMPLETED');
  if (payload?.metadata?.assessmentStatus !== 'COMPLETED') errors.push('metadata.assessmentStatus must be COMPLETED');
  if (!Array.isArray(payload?.dimensionAssessments) || payload.dimensionAssessments.length !== 7) {
    errors.push('dimensionAssessments must contain exactly 7 entries');
  } else {
    const codes = new Set();
    for (const item of payload.dimensionAssessments) {
      if (!DIMENSIONS.has(item.code)) errors.push(`unsupported dimension ${item.code}`);
      if (codes.has(item.code)) errors.push(`duplicate dimension ${item.code}`);
      codes.add(item.code);
      if (!CONFIDENCE.has(item.confidence)) errors.push(`unsupported confidence ${item.confidence}`);
      if (item.modelScore > 0 && (!Array.isArray(item.evidence) || item.evidence.length === 0)) errors.push(`${item.code} positive score lacks evidence`);
    }
    if (codes.size !== DIMENSIONS.size) errors.push('dimension set is incomplete');
  }
  if (errors.length > 0) throw new Error(`INVALID_PHASE3_HANDOFF: ${errors.join('; ')}`);
  return payload;
}
