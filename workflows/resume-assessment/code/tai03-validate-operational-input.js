const input = $input.first().json;
const errors = [];

const isObject = (value) =>
  value !== null &&
  typeof value === 'object' &&
  !Array.isArray(value);

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

if (input.schemaVersion !== '1.0') {
  errors.push('schemaVersion must be 1.0');
}

if (input.resolution?.status !== 'RESOLVED') {
  errors.push('resolution.status must be RESOLVED');
}

if (!uuidPattern.test(String(input.extraction?.id ?? ''))) {
  errors.push('extraction.id must be a valid UUID');
}

if (!isObject(input.execution)) {
  errors.push('execution context must be an object');
} else {
  if (!uuidPattern.test(String(input.execution.requestId ?? ''))) {
    errors.push('execution.requestId must be a valid UUID');
  }

  if (!String(input.execution.rootWorkflowExecutionId ?? '').trim()) {
    errors.push('execution.rootWorkflowExecutionId is required');
  }

  if (
    !Number.isInteger(Number(input.execution.attemptCount)) ||
    Number(input.execution.attemptCount) < 1
  ) {
    errors.push('execution.attemptCount must be a positive integer');
  }
}

if (!isObject(input.candidateProfile)) {
  errors.push('candidateProfile must be an object');
}

if (!isObject(input.assessmentContext)) {
  errors.push('assessmentContext must be an object');
}

if (!isObject(input.gradeGuide)) {
  errors.push('gradeGuide must be an object');
}

const dimensions = input.gradeGuide?.dimensions;

if (!Array.isArray(dimensions) || dimensions.length !== 7) {
  errors.push('gradeGuide.dimensions must contain exactly 7 dimensions');
}

const dimensionCodes = Array.isArray(dimensions)
  ? dimensions.map((dimension) => dimension.code)
  : [];

if (new Set(dimensionCodes).size !== dimensionCodes.length) {
  errors.push('gradeGuide dimension codes must be unique');
}

const totalWeight = Array.isArray(dimensions)
  ? dimensions.reduce(
      (total, dimension) =>
        total + Number(dimension.weight ?? 0),
      0
    )
  : 0;

if (totalWeight !== 100) {
  errors.push(
    `gradeGuide dimension weights must total 100, found ${totalWeight}`
  );
}

const targetGradeCode = input.assessmentContext?.targetGradeCode;
const guideTargetGradeCode = input.gradeGuide?.targetGrade?.code;

if (!targetGradeCode || targetGradeCode !== guideTargetGradeCode) {
  errors.push(
    'assessment target grade must match gradeGuide.targetGrade.code'
  );
}

if (
  input.gradeGuide?.decisionPolicy?.finalGradeAssignedBy !==
  'DETERMINISTIC_ENGINE'
) {
  errors.push(
    'final grade must be assigned by DETERMINISTIC_ENGINE'
  );
}

if (errors.length > 0) {
  throw new Error(
    `INVALID_GRADE_ENGINE_INPUT: ${errors.join('; ')}`
  );
}

return [
  {
    json: input,
  },
];
