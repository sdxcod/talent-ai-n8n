const input = $input.first().json;
const handoff = input.phase3Handoff ?? input;
const errors = [];

const isObject = (value) =>
  value !== null &&
  typeof value === 'object' &&
  !Array.isArray(value);

const requireObject = (value, path) => {
  if (!isObject(value)) {
    errors.push(`${path} must be an object`);
    return {};
  }

  return value;
};

const requireExactKeys = (value, path, requiredKeys) => {
  if (!isObject(value)) return;

  const allowed = new Set(requiredKeys);

  for (const key of requiredKeys) {
    if (!Object.hasOwn(value, key)) {
      errors.push(`${path}.${key} is required`);
    }
  }

  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      errors.push(`${path}.${key} is not allowed`);
    }
  }
};

const requireText = (value, path, minimumLength = 1) => {
  if (
    typeof value !== 'string' ||
    value.trim().length < minimumLength
  ) {
    errors.push(`${path} must contain at least ${minimumLength} characters`);
    return '';
  }

  return value.trim();
};

const requireBoolean = (value, path) => {
  if (typeof value !== 'boolean') {
    errors.push(`${path} must be boolean`);
  }
};

const requireNumber = (value, path, minimum, maximum) => {
  if (
    typeof value !== 'number' ||
    !Number.isFinite(value) ||
    value < minimum ||
    value > maximum
  ) {
    errors.push(`${path} must be a number from ${minimum} to ${maximum}`);
  }
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const requireUuid = (value, path) => {
  if (!uuidPattern.test(String(value ?? ''))) {
    errors.push(`${path} must be UUID`);
  }
};

const requireDateTime = (value, path) => {
  if (
    typeof value !== 'string' ||
    value.trim() === '' ||
    Number.isNaN(Date.parse(value))
  ) {
    errors.push(`${path} must be a valid date-time string`);
  }
};

const root = requireObject(handoff, 'handoff');

const topLevelKeys = [
  'contract',
  'contractVersion',
  'requestId',
  'assessmentId',
  'extractionId',
  'candidate',
  'assessmentContext',
  'gradeGuide',
  'score',
  'decision',
  'dimensionAssessments',
  'reviewReasons',
  'modelWarnings',
  'assessmentSummary',
  'execution',
  'metadata',
];

requireExactKeys(root, 'handoff', topLevelKeys);

if (root.contract !== 'talentai.phase3.assessment-handoff') {
  errors.push('unsupported contract');
}

if (root.contractVersion !== '1.0.0') {
  errors.push('unsupported contractVersion');
}

requireUuid(root.requestId, 'requestId');
requireUuid(root.assessmentId, 'assessmentId');
requireUuid(root.extractionId, 'extractionId');

const candidate = requireObject(root.candidate, 'candidate');
requireExactKeys(candidate, 'candidate', ['fullName']);
requireText(candidate.fullName, 'candidate.fullName');

const assessmentContext = requireObject(
  root.assessmentContext,
  'assessmentContext'
);
requireExactKeys(assessmentContext, 'assessmentContext', [
  'positionCode',
  'targetGradeCode',
  'jobDescription',
]);

if (assessmentContext.positionCode !== 'JAVA_BACKEND') {
  errors.push('unsupported assessmentContext.positionCode');
}

if (
  !['JUNIOR', 'MID', 'SENIOR'].includes(
    assessmentContext.targetGradeCode
  )
) {
  errors.push('unsupported assessmentContext.targetGradeCode');
}

requireText(
  assessmentContext.jobDescription,
  'assessmentContext.jobDescription',
  30
);

const gradeGuide = requireObject(root.gradeGuide, 'gradeGuide');
requireExactKeys(gradeGuide, 'gradeGuide', ['id', 'version']);
requireUuid(gradeGuide.id, 'gradeGuide.id');
requireText(gradeGuide.version, 'gradeGuide.version');

const score = requireObject(root.score, 'score');
requireExactKeys(score, 'score', [
  'overall',
  'minimumRequired',
  'thresholdMet',
  'mandatoryDimensionsMet',
]);
requireNumber(score.overall, 'score.overall', 0, 100);
requireNumber(score.minimumRequired, 'score.minimumRequired', 0, 100);
requireBoolean(score.thresholdMet, 'score.thresholdMet');
requireBoolean(
  score.mandatoryDimensionsMet,
  'score.mandatoryDimensionsMet'
);

const decisions = new Set([
  'MEETS_TARGET',
  'BELOW_TARGET',
  'REVIEW_REQUIRED',
]);

if (!decisions.has(root.decision)) {
  errors.push('unsupported decision');
}

for (const [value, path] of [
  [root.reviewReasons, 'reviewReasons'],
  [root.modelWarnings, 'modelWarnings'],
]) {
  if (!Array.isArray(value)) {
    errors.push(`${path} must be an array`);
    continue;
  }

  for (const [index, item] of value.entries()) {
    requireText(item, `${path}[${index}]`);
  }
}

requireText(root.assessmentSummary, 'assessmentSummary');

const requiredDimensionCodes = new Set([
  'JAVA_CORE',
  'SPRING_ECOSYSTEM',
  'DATABASE',
  'DISTRIBUTED_SYSTEMS',
  'TESTING',
  'SOFTWARE_ARCHITECTURE',
  'OBSERVABILITY_DEVOPS',
]);
const confidenceValues = new Set(['HIGH', 'MEDIUM', 'LOW']);
const evidenceSources = new Set([
  'PROFILE_SKILL',
  'WORK_EXPERIENCE',
  'EDUCATION',
  'WARNING',
  'OTHER',
]);
const dimensionKeys = [
  'code',
  'title',
  'weight',
  'mandatory',
  'modelScore',
  'effectiveScore',
  'confidence',
  'confidenceAccepted',
  'weightedScore',
  'minimumRequired',
  'minimumMet',
  'evidence',
  'rationale',
];
const receivedDimensionCodes = new Set();

if (
  !Array.isArray(root.dimensionAssessments) ||
  root.dimensionAssessments.length !== requiredDimensionCodes.size
) {
  errors.push('dimensionAssessments must contain exactly 7 entries');
} else {
  for (const [index, rawDimension] of root.dimensionAssessments.entries()) {
    const path = `dimensionAssessments[${index}]`;
    const dimension = requireObject(rawDimension, path);

    requireExactKeys(dimension, path, dimensionKeys);

    if (!requiredDimensionCodes.has(dimension.code)) {
      errors.push(`${path}.code is unsupported`);
    } else if (receivedDimensionCodes.has(dimension.code)) {
      errors.push(`${path}.code is duplicated`);
    } else {
      receivedDimensionCodes.add(dimension.code);
    }

    requireText(dimension.title, `${path}.title`);

    if (
      !Number.isInteger(dimension.weight) ||
      dimension.weight < 0 ||
      dimension.weight > 100
    ) {
      errors.push(`${path}.weight must be an integer from 0 to 100`);
    }

    requireBoolean(dimension.mandatory, `${path}.mandatory`);

    for (const field of ['modelScore', 'effectiveScore']) {
      if (
        !Number.isInteger(dimension[field]) ||
        dimension[field] < 0 ||
        dimension[field] > 4
      ) {
        errors.push(`${path}.${field} must be an integer from 0 to 4`);
      }
    }

    if (!confidenceValues.has(dimension.confidence)) {
      errors.push(`${path}.confidence is unsupported`);
    }

    requireBoolean(
      dimension.confidenceAccepted,
      `${path}.confidenceAccepted`
    );
    requireNumber(
      dimension.weightedScore,
      `${path}.weightedScore`,
      0,
      100
    );

    if (
      dimension.minimumRequired !== null &&
      (
        !Number.isInteger(dimension.minimumRequired) ||
        dimension.minimumRequired < 0 ||
        dimension.minimumRequired > 4
      )
    ) {
      errors.push(
        `${path}.minimumRequired must be null or an integer from 0 to 4`
      );
    }

    requireBoolean(dimension.minimumMet, `${path}.minimumMet`);

    if (!Array.isArray(dimension.evidence)) {
      errors.push(`${path}.evidence must be an array`);
    } else {
      if (dimension.evidence.length > 5) {
        errors.push(`${path}.evidence must contain at most 5 entries`);
      }

      if (dimension.modelScore > 0 && dimension.evidence.length === 0) {
        errors.push(`${path} positive score lacks evidence`);
      }

      for (const [evidenceIndex, rawEvidence] of
        dimension.evidence.entries()) {
        const evidencePath = `${path}.evidence[${evidenceIndex}]`;
        const evidence = requireObject(rawEvidence, evidencePath);

        requireExactKeys(evidence, evidencePath, ['quote', 'source']);
        requireText(evidence.quote, `${evidencePath}.quote`);

        if (!evidenceSources.has(evidence.source)) {
          errors.push(`${evidencePath}.source is unsupported`);
        }
      }
    }

    requireText(dimension.rationale, `${path}.rationale`);
  }
}

if (receivedDimensionCodes.size !== requiredDimensionCodes.size) {
  errors.push('dimensionAssessments has an incomplete dimension set');
}

const execution = requireObject(root.execution, 'execution');
requireExactKeys(execution, 'execution', [
  'attemptCount',
  'status',
  'replayed',
  'startedAt',
  'completedAt',
]);

if (!Number.isInteger(execution.attemptCount) || execution.attemptCount < 1) {
  errors.push('execution.attemptCount must be a positive integer');
}

if (execution.status !== 'COMPLETED') {
  errors.push('execution.status must be COMPLETED');
}

requireBoolean(execution.replayed, 'execution.replayed');
requireDateTime(execution.startedAt, 'execution.startedAt');
requireDateTime(execution.completedAt, 'execution.completedAt');

const metadata = requireObject(root.metadata, 'metadata');
requireExactKeys(metadata, 'metadata', [
  'scoringModel',
  'promptVersion',
  'engineVersion',
  'assessmentStatus',
  'createdAt',
]);
requireText(metadata.scoringModel, 'metadata.scoringModel');
requireText(metadata.promptVersion, 'metadata.promptVersion');
requireText(metadata.engineVersion, 'metadata.engineVersion');

if (metadata.assessmentStatus !== 'COMPLETED') {
  errors.push('metadata.assessmentStatus must be COMPLETED');
}

requireDateTime(metadata.createdAt, 'metadata.createdAt');

if (
  root.decision === 'MEETS_TARGET' &&
  (
    score.thresholdMet !== true ||
    score.mandatoryDimensionsMet !== true ||
    root.reviewReasons?.length !== 0
  )
) {
  errors.push('MEETS_TARGET invariants are not satisfied');
}

if (
  root.decision === 'REVIEW_REQUIRED' &&
  root.reviewReasons?.length === 0
) {
  errors.push('REVIEW_REQUIRED requires at least one review reason');
}

if (errors.length > 0) {
  throw new Error(
    `INVALID_PHASE3_HANDOFF: ${errors.join('; ')}`
  );
}

const minimumDimensionLevels = Object.fromEntries(
  root.dimensionAssessments
    .filter((dimension) => dimension.minimumRequired !== null)
    .map((dimension) => [
      dimension.code,
      dimension.minimumRequired,
    ])
);

const targetGrade = {
  code: assessmentContext.targetGradeCode,
  label: assessmentContext.targetGradeCode,
  minimumOverallScore: score.minimumRequired,
  minimumDimensionLevels,
};

return [
  {
    json: {
      phase3Handoff: root,
      correlation: {
        contractVersion: root.contractVersion,
        requestId: root.requestId,
        assessmentId: root.assessmentId,
        extractionId: root.extractionId,
      },
      extraction: {
        id: root.extractionId,
        positionCode: assessmentContext.positionCode,
        targetGradeCode: assessmentContext.targetGradeCode,
        jobDescription: assessmentContext.jobDescription,
      },
      candidate: {
        fullName: candidate.fullName.trim(),
      },
      gradeGuide: {
        id: gradeGuide.id,
        version: gradeGuide.version,
        targetGrade,
        grades: [targetGrade],
        dimensions: root.dimensionAssessments.map((dimension) => ({
          code: dimension.code,
          title: dimension.title,
          weight: dimension.weight,
          mandatory: dimension.mandatory,
          minimumRequired: dimension.minimumRequired,
        })),
        scoringScale: [
          { score: 0, meaning: 'NO_USABLE_EVIDENCE' },
          { score: 1, meaning: 'LIMITED_OR_VAGUE' },
          { score: 2, meaning: 'PRACTICAL_AND_CONCRETE' },
          { score: 3, meaning: 'ADVANCED_WITH_TRADE_OFFS' },
          { score: 4, meaning: 'LEADERSHIP_OR_CROSS_CUTTING_OWNERSHIP' },
        ],
      },
      resumeGrade: {
        assessmentId: root.assessmentId,
        decision: root.decision,
        overallScore: score.overall,
        minimumOverallScore: score.minimumRequired,
        thresholdMet: score.thresholdMet,
        mandatoryDimensionsMet: score.mandatoryDimensionsMet,
        assessedAt: metadata.createdAt,
        summary: root.assessmentSummary,
        reviewReasons: root.reviewReasons,
        modelWarnings: root.modelWarnings,
        dimensions: root.dimensionAssessments,
      },
    },
  },
];
