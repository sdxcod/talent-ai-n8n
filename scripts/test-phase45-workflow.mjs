#!/usr/bin/env node

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, '..');
const workflowDirectory = path.join(repositoryRoot, 'workflows', 'phase-4-5');
const manifestPath = path.join(workflowDirectory, 'manifest.json');
const examplePath = path.join(
  repositoryRoot,
  'docs',
  'contracts',
  'phase3-assessment-handoff-v1.example.json',
);

const readJson = (filePath) => JSON.parse(fs.readFileSync(filePath, 'utf8'));

const manifest = readJson(manifestPath);

assert.equal(manifest.scope, 'PHASE_4_5_MVP');
assert.equal(manifest.schemaVersion, '1.0.0');
assert.deepEqual(manifest.upstreamContract, {
  name: 'talentai.phase3.assessment-handoff',
  version: '1.0.0',
});
assert.equal(manifest.workflows.length, 1);
assert.deepEqual(manifest.persistence, {
  schemaVersion: '1.0.0',
  migration: 'database/migrations/V009__create_technical_interview_persistence.sql',
  checkpointMigration: 'database/migrations/V010__add_technical_interview_checkpoint_recovery.sql',
  tables: [
    'talentai.technical_interview_session',
    'talentai.technical_question_set',
    'talentai.technical_interview_answer',
    'talentai.technical_interview_result',
  ],
  queryRange: 'Q013-Q020',
});
assert.deepEqual(
  [...manifest.requiredCredentialTypes].sort(),
  ['openAiApi', 'postgres'],
);

const descriptor = manifest.workflows[0];
const workflowPath = path.join(workflowDirectory, descriptor.file);
const workflow = readJson(workflowPath);
const exampleHandoff = readJson(examplePath);

assert.equal(workflow.id, descriptor.id);
assert.equal(workflow.name, descriptor.name);
assert.equal(workflow.active, false);
assert.equal(workflow.isArchived, false);
assert.equal(workflow.isPublished, false);

for (const forbiddenKey of [
  'meta',
  'nodeGroups',
  'pinData',
  'shared',
  'staticData',
  'tags',
  'versionId',
]) {
  assert.equal(
    Object.hasOwn(workflow, forbiddenKey),
    false,
    `Committed workflow contains runtime field: ${forbiddenKey}`,
  );
}

const nodeByName = new Map(workflow.nodes.map((node) => [node.name, node]));
assert.equal(nodeByName.size, workflow.nodes.length, 'Node names must be unique.');

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

for (const node of workflow.nodes) {
  assert.match(node.id, uuidPattern, `Node has an invalid UUID: ${node.name}`);

  if (node.webhookId !== undefined) {
    assert.match(
      node.webhookId,
      uuidPattern,
      `Node has an invalid webhook UUID: ${node.name}`,
    );
  }

  assert.equal(
    Object.hasOwn(node, 'credentials'),
    false,
    `Committed node contains credentials: ${node.name}`,
  );
}

for (const requiredNode of [
  'On interview request',
  'When Executed by Another Workflow',
  'Validate Demo Interview Request',
  'Load Completed Phase 3 Assessment',
  'Build Demo Phase 3 Handoff',
  'Validate Phase 3 Handoff',
  'Claim Technical Interview Session',
  'Interview Claim Can Continue?',
  'Fresh Interview Attempt?',
  'Load Technical Interview Checkpoint',
  'Build Technical Interview Checkpoint',
  'Resume First Round?',
  'Resume Follow-up Generation?',
  'Resume Follow-up?',
  'Resume Answer Evaluation?',
  'Resume Result Persistence?',
  'Completed Interview Replay?',
  'Load Completed Technical Interview',
  'Build Rejected Technical Interview Result',
  'Generate Interview Questions',
  'Validate Interview Questions',
  'Persist First Question Set',
  'Restore First Question Form',
  'Prepare First Interview Form',
  'Persist First Round Answers',
  'Restore First Round Answers',
  'Generate Follow-up Questions',
  'Validate Follow-up Questions',
  'Persist Follow-up Question Set',
  'Restore Follow-up Question Form',
  'Prepare Follow-up Interview Form',
  'Persist Follow-up Answers',
  'Restore Follow-up Answers',
  'Score Interview Answers',
  'Validate Answer Scores',
  'Apply Answer Evaluations',
  'Restore Validated Answer Scores',
  'Calculate Final Grade',
  'Complete Technical Interview',
  'Build Persisted Interview Result',
  'Record Technical Interview Failure',
  'Build Failed Technical Interview Result',
  'Build Interview Failure Recording Fallback',
  'Build Unrecorded Technical Interview Result',
  'Demo Request Failure',
  'Phase 3 Lookup Failure',
  'Demo Handoff Assembly Failure',
  'Phase 3 Contract Failure',
  'Interview Claim Failure',
  'Interview Configuration Failure',
  'Question Prompt Failure',
  'Question Generation Failure',
  'Question Validation Failure',
  'First Question Persistence Failure',
  'First Answer Validation Failure',
  'First Answer Persistence Failure',
  'Follow-up Prompt Failure',
  'Follow-up Generation Failure',
  'Follow-up Validation Failure',
  'Follow-up Question Persistence Failure',
  'Follow-up Answer Validation Failure',
  'Follow-up Answer Persistence Failure',
  'Answer Scoring Prompt Failure',
  'Answer Scoring Failure',
  'Answer Score Validation Failure',
  'Answer Evaluation Persistence Failure',
  'Final Grade Failure',
  'Interview Completion Failure',
  'Checkpoint Load Failure',
  'Checkpoint Reconstruction Failure',
  'Checkpoint Route Failure',
  'First Question Checkpoint Failure',
  'First Answer Checkpoint Failure',
  'Follow-up Question Checkpoint Failure',
  'Follow-up Answer Checkpoint Failure',
  'Answer Evaluation Checkpoint Failure',
  'Show Final Grade',
]) {
  assert.ok(nodeByName.has(requiredNode), `Required node is missing: ${requiredNode}`);
}

assert.equal(
  nodeByName.has('Validate Interview Request'),
  false,
  'Legacy extraction-only entry point must not remain.',
);
assert.equal(
  nodeByName.has('Resolve Candidate and Resume Grade'),
  false,
  'Legacy cross-phase resolver must not remain.',
);

const connectionTargets = (name, outputIndex = 0) =>
  (workflow.connections[name]?.main?.[outputIndex] ?? []).map(
    (connection) => connection.node,
  );

assert.deepEqual(
  connectionTargets('When Executed by Another Workflow'),
  ['Validate Phase 3 Handoff'],
  'Sub-workflow input must enter through the frozen Phase 3 contract.',
);
assert.deepEqual(
  connectionTargets('On interview request'),
  ['Validate Demo Interview Request'],
);
assert.deepEqual(
  connectionTargets('Build Demo Phase 3 Handoff'),
  ['Validate Phase 3 Handoff'],
);
assert.deepEqual(
  connectionTargets('Validate Phase 3 Handoff'),
  ['Claim Technical Interview Session'],
);
assert.deepEqual(
  connectionTargets('Claim Technical Interview Session'),
  ['Interview Claim Can Continue?'],
);
assert.deepEqual(
  connectionTargets('Interview Claim Can Continue?', 0),
  ['Interview Configuration'],
);
assert.deepEqual(
  connectionTargets('Interview Claim Can Continue?', 1),
  ['Completed Interview Replay?'],
);
assert.deepEqual(
  connectionTargets('Completed Interview Replay?', 0),
  ['Load Completed Technical Interview'],
);
assert.deepEqual(
  connectionTargets('Completed Interview Replay?', 1),
  ['Build Rejected Technical Interview Result'],
);
assert.deepEqual(
  connectionTargets('Load Completed Technical Interview'),
  ['Build Persisted Interview Result'],
);
assert.deepEqual(
  connectionTargets('Interview Configuration'),
  ['Fresh Interview Attempt?'],
);
assert.deepEqual(
  connectionTargets('Fresh Interview Attempt?', 0),
  ['Build Interview Question Prompt'],
);
assert.deepEqual(
  connectionTargets('Fresh Interview Attempt?', 1),
  ['Load Technical Interview Checkpoint'],
);
assert.deepEqual(
  connectionTargets('Load Technical Interview Checkpoint'),
  ['Build Technical Interview Checkpoint'],
);
assert.deepEqual(
  connectionTargets('Build Technical Interview Checkpoint'),
  ['Resume First Round?'],
);
assert.deepEqual(
  connectionTargets('Resume First Round?', 0),
  ['Prepare First Interview Form'],
);
assert.deepEqual(
  connectionTargets('Resume First Round?', 1),
  ['Resume Follow-up Generation?'],
);
assert.deepEqual(
  connectionTargets('Resume Follow-up Generation?', 0),
  ['Build Follow-up Question Prompt'],
);
assert.deepEqual(
  connectionTargets('Resume Follow-up Generation?', 1),
  ['Resume Follow-up?'],
);
assert.deepEqual(
  connectionTargets('Resume Follow-up?', 0),
  ['Prepare Follow-up Interview Form'],
);
assert.deepEqual(
  connectionTargets('Resume Follow-up?', 1),
  ['Resume Answer Evaluation?'],
);
assert.deepEqual(
  connectionTargets('Resume Answer Evaluation?', 0),
  ['Build Answer Scoring Prompt'],
);
assert.deepEqual(
  connectionTargets('Resume Answer Evaluation?', 1),
  ['Resume Result Persistence?'],
);
assert.deepEqual(
  connectionTargets('Resume Result Persistence?', 0),
  ['Calculate Final Grade'],
);
assert.deepEqual(
  connectionTargets('Resume Result Persistence?', 1),
  ['Checkpoint Route Failure'],
);
assert.deepEqual(
  connectionTargets('Validate Interview Questions'),
  ['Persist First Question Set'],
);
assert.deepEqual(
  connectionTargets('Persist First Question Set'),
  ['Restore First Question Form'],
);
assert.deepEqual(
  connectionTargets('Restore First Question Form'),
  ['Prepare First Interview Form'],
);
assert.deepEqual(
  connectionTargets('Prepare First Interview Form'),
  ['Candidate Interview Form'],
);
assert.deepEqual(
  connectionTargets('Normalize Interview Answers'),
  ['Persist First Round Answers'],
);
assert.deepEqual(
  connectionTargets('Persist First Round Answers'),
  ['Restore First Round Answers'],
);
assert.deepEqual(
  connectionTargets('Validate Follow-up Questions'),
  ['Persist Follow-up Question Set'],
);
assert.deepEqual(
  connectionTargets('Persist Follow-up Question Set'),
  ['Restore Follow-up Question Form'],
);
assert.deepEqual(
  connectionTargets('Restore Follow-up Question Form'),
  ['Prepare Follow-up Interview Form'],
);
assert.deepEqual(
  connectionTargets('Prepare Follow-up Interview Form'),
  ['Follow-up Interview Form'],
);
assert.deepEqual(
  connectionTargets('Normalize Follow-up Answers'),
  ['Persist Follow-up Answers'],
);
assert.deepEqual(
  connectionTargets('Persist Follow-up Answers'),
  ['Restore Follow-up Answers'],
);
assert.deepEqual(
  connectionTargets('Validate Answer Scores'),
  ['Apply Answer Evaluations'],
);
assert.deepEqual(
  connectionTargets('Apply Answer Evaluations'),
  ['Restore Validated Answer Scores'],
);
assert.deepEqual(
  connectionTargets('Calculate Final Grade'),
  ['Complete Technical Interview'],
);
assert.deepEqual(
  connectionTargets('Complete Technical Interview'),
  ['Build Persisted Interview Result'],
);
assert.deepEqual(
  connectionTargets('Build Persisted Interview Result'),
  ['Build Final Grade Summary'],
);

assert.deepEqual(
  nodeByName.get('When Executed by Another Workflow').parameters.workflowInputs,
  {
    values: [
      {
        name: 'phase3Handoff',
        type: 'object',
      },
    ],
  },
);
assert.equal(
  nodeByName.get('When Executed by Another Workflow').parameters.inputSource,
  'workflowInputs',
);

const codeDirectory = path.join(workflowDirectory, 'code');
const sourceCode = (name) =>
  fs.readFileSync(path.join(codeDirectory, `${name}.js`), 'utf8').trimEnd();

for (const [nodeName, sourceName] of [
  ['Validate Demo Interview Request', 'tai04-validate-demo-interview-request'],
  ['Build Demo Phase 3 Handoff', 'tai04-build-demo-phase3-handoff'],
  ['Validate Phase 3 Handoff', 'tai04-validate-phase3-handoff'],
  ['Build Technical Interview Checkpoint', 'tai04-build-interview-checkpoint'],
  ['Restore First Question Form', 'tai04-restore-first-question-form'],
  ['Prepare First Interview Form', 'tai04-prepare-interview-form'],
  ['Restore First Round Answers', 'tai04-restore-first-round-answers'],
  ['Restore Follow-up Question Form', 'tai04-restore-follow-up-question-form'],
  ['Prepare Follow-up Interview Form', 'tai04-prepare-interview-form'],
  ['Restore Follow-up Answers', 'tai04-restore-follow-up-answers'],
  ['Restore Validated Answer Scores', 'tai04-restore-validated-answer-scores'],
  ['Build Persisted Interview Result', 'tai04-build-persisted-interview-result'],
  ['Build Rejected Technical Interview Result', 'tai04-build-rejected-interview-result'],
  ['Build Failed Technical Interview Result', 'tai04-build-failed-interview-result'],
  ['Build Interview Failure Recording Fallback', 'tai04-build-failure-recording-fallback'],
  ['Build Unrecorded Technical Interview Result', 'tai04-build-unrecorded-interview-result'],
]) {
  assert.equal(
    nodeByName.get(nodeName).parameters.jsCode,
    sourceCode(sourceName),
    `${nodeName} is not synchronized with ${sourceName}.js`,
  );
}

const unclaimedFailureNodes = [
  'Phase 3 Resolution Failure',
  'Demo Request Failure',
  'Phase 3 Lookup Failure',
  'Demo Handoff Assembly Failure',
  'Phase 3 Contract Failure',
  'Interview Claim Failure',
];

const recordedFailureNodes = [
  'Interview Configuration Failure',
  'Question Prompt Failure',
  'Question Generation Failure',
  'Question Validation Failure',
  'First Question Persistence Failure',
  'First Answer Validation Failure',
  'First Answer Persistence Failure',
  'Follow-up Prompt Failure',
  'Follow-up Generation Failure',
  'Follow-up Validation Failure',
  'Follow-up Question Persistence Failure',
  'Follow-up Answer Validation Failure',
  'Follow-up Answer Persistence Failure',
  'Answer Scoring Prompt Failure',
  'Answer Scoring Failure',
  'Answer Score Validation Failure',
  'Answer Evaluation Persistence Failure',
  'Final Grade Failure',
  'Interview Completion Failure',
  'Checkpoint Load Failure',
  'Checkpoint Reconstruction Failure',
  'Checkpoint Route Failure',
  'First Question Checkpoint Failure',
  'First Answer Checkpoint Failure',
  'Follow-up Question Checkpoint Failure',
  'Follow-up Answer Checkpoint Failure',
  'Answer Evaluation Checkpoint Failure',
];

for (const nodeName of unclaimedFailureNodes) {
  assert.ok(
    nodeByName.get(nodeName).parameters.jsCode.endsWith(
      sourceCode('tai04-classify-unclaimed-failure')
    ),
    `${nodeName} does not use the canonical unclaimed failure classifier.`,
  );
  assert.deepEqual(
    connectionTargets(nodeName),
    ['Build Unrecorded Technical Interview Result'],
  );
}

for (const nodeName of recordedFailureNodes) {
  assert.ok(
    nodeByName.get(nodeName).parameters.jsCode.endsWith(
      sourceCode('tai04-classify-interview-failure')
    ),
    `${nodeName} does not use the canonical recorded failure classifier.`,
  );
  assert.deepEqual(
    connectionTargets(nodeName),
    ['Record Technical Interview Failure'],
  );
}

const errorRoutes = new Map([
  ['Validate Demo Interview Request', 'Demo Request Failure'],
  ['Load Completed Phase 3 Assessment', 'Phase 3 Lookup Failure'],
  ['Build Demo Phase 3 Handoff', 'Demo Handoff Assembly Failure'],
  ['Validate Phase 3 Handoff', 'Phase 3 Contract Failure'],
  ['Claim Technical Interview Session', 'Interview Claim Failure'],
  ['Interview Configuration', 'Interview Configuration Failure'],
  ['Load Technical Interview Checkpoint', 'Checkpoint Load Failure'],
  ['Build Technical Interview Checkpoint', 'Checkpoint Reconstruction Failure'],
  ['Build Interview Question Prompt', 'Question Prompt Failure'],
  ['Generate Interview Questions', 'Question Generation Failure'],
  ['Validate Interview Questions', 'Question Validation Failure'],
  ['Persist First Question Set', 'First Question Persistence Failure'],
  ['Restore First Question Form', 'First Question Checkpoint Failure'],
  ['Prepare First Interview Form', 'First Question Checkpoint Failure'],
  ['Normalize Interview Answers', 'First Answer Validation Failure'],
  ['Persist First Round Answers', 'First Answer Persistence Failure'],
  ['Restore First Round Answers', 'First Answer Checkpoint Failure'],
  ['Build Follow-up Question Prompt', 'Follow-up Prompt Failure'],
  ['Generate Follow-up Questions', 'Follow-up Generation Failure'],
  ['Validate Follow-up Questions', 'Follow-up Validation Failure'],
  ['Persist Follow-up Question Set', 'Follow-up Question Persistence Failure'],
  ['Restore Follow-up Question Form', 'Follow-up Question Checkpoint Failure'],
  ['Prepare Follow-up Interview Form', 'Follow-up Question Checkpoint Failure'],
  ['Normalize Follow-up Answers', 'Follow-up Answer Validation Failure'],
  ['Persist Follow-up Answers', 'Follow-up Answer Persistence Failure'],
  ['Restore Follow-up Answers', 'Follow-up Answer Checkpoint Failure'],
  ['Build Answer Scoring Prompt', 'Answer Scoring Prompt Failure'],
  ['Score Interview Answers', 'Answer Scoring Failure'],
  ['Validate Answer Scores', 'Answer Score Validation Failure'],
  ['Apply Answer Evaluations', 'Answer Evaluation Persistence Failure'],
  ['Restore Validated Answer Scores', 'Answer Evaluation Checkpoint Failure'],
  ['Calculate Final Grade', 'Final Grade Failure'],
  ['Complete Technical Interview', 'Interview Completion Failure'],
]);

for (const [source, target] of errorRoutes) {
  assert.equal(
    nodeByName.get(source).onError,
    'continueErrorOutput',
    `${source} must expose a controlled error output.`,
  );
  assert.deepEqual(connectionTargets(source, 1), [target]);
}

for (const providerNode of [
  'Generate Interview Questions',
  'Generate Follow-up Questions',
  'Score Interview Answers',
]) {
  const node = nodeByName.get(providerNode);
  assert.equal(node.retryOnFail, true);
  assert.equal(node.maxTries, 3);
  assert.equal(node.waitBetweenTries, 2000);
}

assert.deepEqual(
  connectionTargets('Record Technical Interview Failure'),
  ['Build Failed Technical Interview Result'],
);
assert.deepEqual(
  connectionTargets('Record Technical Interview Failure', 1),
  ['Build Interview Failure Recording Fallback'],
);
assert.equal(
  nodeByName.get('Record Technical Interview Failure').onError,
  'continueErrorOutput',
);

const databaseQueryDirectory = path.join(repositoryRoot, 'database', 'queries');
const databaseQuery = (name) =>
  fs.readFileSync(path.join(databaseQueryDirectory, `${name}.sql`), 'utf8');

for (const [nodeName, queryName] of [
  ['Claim Technical Interview Session', 'Q013__claim_technical_interview_session'],
  ['Load Completed Technical Interview', 'Q018__load_completed_technical_interview'],
  ['Load Technical Interview Checkpoint', 'Q020__load_technical_interview_checkpoint'],
  ['Persist First Question Set', 'Q014__persist_technical_question_set'],
  ['Persist First Round Answers', 'Q015__persist_technical_interview_answers'],
  ['Persist Follow-up Question Set', 'Q014__persist_technical_question_set'],
  ['Persist Follow-up Answers', 'Q015__persist_technical_interview_answers'],
  ['Apply Answer Evaluations', 'Q016__apply_technical_answer_evaluations'],
  ['Complete Technical Interview', 'Q017__complete_technical_interview'],
  ['Record Technical Interview Failure', 'Q019__fail_technical_interview_session'],
]) {
  assert.equal(
    nodeByName.get(nodeName).parameters.query,
    databaseQuery(queryName),
    `${nodeName} is not synchronized with ${queryName}.sql`,
  );
}

assert.match(
  nodeByName.get('Apply Answer Evaluations').parameters.options.queryReplacement,
  /JSON\.stringify\(\$json\.answerScoring\)/,
  'Answer-scoring metadata must be persisted with the evaluation checkpoint.',
);
assert.match(
  nodeByName.get('Normalize Interview Answers').parameters.jsCode,
  /Prepare First Interview Form/,
);
assert.match(
  nodeByName.get('Normalize Follow-up Answers').parameters.jsCode,
  /Prepare Follow-up Interview Form/,
);
assert.match(
  nodeByName.get('Build Answer Scoring Prompt').parameters.jsCode,
  /firstRoundAnswerRecords/,
);

const sqlPath = path.join(
  workflowDirectory,
  'sql',
  'load-completed-phase3-handoff-by-extraction.sql',
);
assert.equal(
  nodeByName.get('Load Completed Phase 3 Assessment').parameters.query,
  fs.readFileSync(sqlPath, 'utf8'),
);

const executeCodeNode = (nodeName, input) => {
  const source = nodeByName.get(nodeName).parameters.jsCode;
  const run = new Function('$input', source);

  return run({
    first: () => ({ json: structuredClone(input) }),
  });
};

const validated = executeCodeNode(
  'Validate Phase 3 Handoff',
  { phase3Handoff: exampleHandoff },
)[0].json;

const executeCheckpointNode = (input) => {
  const source = nodeByName.get(
    'Build Technical Interview Checkpoint'
  ).parameters.jsCode;
  const run = new Function('$input', '$', source);

  return run(
    {
      first: () => ({ json: structuredClone(input) }),
    },
    (name) => {
      assert.equal(name, 'Validate Phase 3 Handoff');
      return {
        first: () => ({ json: structuredClone(validated) }),
      };
    },
  )[0].json;
};

const checkpointQuestion = {
  id: 'Q1',
  dimensionCode: 'JAVA_CORE',
  type: 'single_choice',
  questionText: 'Which Java behavior is correct?',
  options: [
    { label: 'A', score: 0 },
    { label: 'B', score: 4 },
    { label: 'C', score: 1 },
  ],
};
const checkpointAnswer = {
  round: 'first',
  id: 'Q1',
  dimensionCode: 'JAVA_CORE',
  type: 'single_choice',
  questionText: checkpointQuestion.questionText,
  answerLabels: ['B'],
  answerText: '',
  mcqScore: 4,
  llmScore: null,
  llmRationale: '',
  finalScore: 4,
};
const checkpointFollowUpAnswer = {
  ...checkpointAnswer,
  round: 'followUp',
  id: 'F1',
  type: 'explanatory',
  answerLabels: [],
  answerText: 'A concrete synthetic answer.',
  mcqScore: null,
  llmScore: 3,
  llmRationale: 'Concrete evidence.',
  finalScore: 3,
};

const firstRoundCheckpoint = executeCheckpointNode({
  sessionId: '60000000-0000-4000-8000-000000000001',
  currentStage: 'FIRST_ROUND',
  attemptCount: 2,
  firstQuestionPlan: {
    schemaVersion: '1.0',
    round: 'first',
    questions: [checkpointQuestion],
  },
  firstQuestionCount: 1,
  firstAnswerRecords: [],
  firstAnswerCount: 0,
  followUpQuestionPlan: null,
  followUpQuestionCount: null,
  followUpAnswerRecords: [],
  followUpAnswerCount: 0,
  evaluatedAnswerCount: 0,
  evaluationPayload: null,
});

assert.equal(firstRoundCheckpoint.checkpointStage, 'FIRST_ROUND');
assert.equal(firstRoundCheckpoint.formFields.length, 1);
assert.equal(firstRoundCheckpoint.persistence.resumed, true);

const resultCheckpoint = executeCheckpointNode({
  sessionId: '60000000-0000-4000-8000-000000000001',
  currentStage: 'RESULT_PERSISTENCE',
  attemptCount: 2,
  firstQuestionCount: 1,
  firstAnswerRecords: [checkpointAnswer],
  firstAnswerCount: 1,
  followUpQuestionCount: 1,
  followUpAnswerRecords: [checkpointFollowUpAnswer],
  followUpAnswerCount: 1,
  evaluatedAnswerCount: 2,
  evaluationPayload: {
    schemaVersion: '1.0',
    interviewSummary: 'Synthetic checkpoint summary.',
    warnings: [],
  },
});

assert.equal(resultCheckpoint.checkpointStage, 'RESULT_PERSISTENCE');
assert.equal(resultCheckpoint.answerRecords.length, 2);
assert.equal(
  resultCheckpoint.answerScoring.interviewSummary,
  'Synthetic checkpoint summary.',
);

assert.deepEqual(validated.correlation, {
  contractVersion: '1.0.0',
  requestId: exampleHandoff.requestId,
  assessmentId: exampleHandoff.assessmentId,
  extractionId: exampleHandoff.extractionId,
});
assert.deepEqual(validated.phase3Handoff, exampleHandoff);
assert.equal(validated.gradeGuide.grades.length, 1);
assert.equal(
  validated.gradeGuide.grades[0].code,
  exampleHandoff.assessmentContext.targetGradeCode,
);
assert.equal(validated.resumeGrade.dimensions.length, 7);

for (const mutation of [
  (value) => { value.contractVersion = '2.0.0'; },
  (value) => { value.execution.status = 'FAILED'; },
  (value) => { value.privateProviderPayload = 'must-not-cross-boundary'; },
  (value) => { value.dimensionAssessments[0].evidence = []; },
  (value) => { value.assessmentContext.jobDescription = 'too short'; },
]) {
  const invalid = structuredClone(exampleHandoff);
  mutation(invalid);

  assert.throws(
    () => executeCodeNode(
      'Validate Phase 3 Handoff',
      { phase3Handoff: invalid },
    ),
    /INVALID_PHASE3_HANDOFF/,
  );
}

const demoSource = {
  resolutionStatus: 'RESOLVED',
  requestId: exampleHandoff.requestId,
  assessmentId: exampleHandoff.assessmentId,
  extractionId: exampleHandoff.extractionId,
  candidate: exampleHandoff.candidate,
  positionCode: exampleHandoff.assessmentContext.positionCode,
  targetGradeCode: exampleHandoff.assessmentContext.targetGradeCode,
  jobDescription: exampleHandoff.assessmentContext.jobDescription,
  gradeGuideId: exampleHandoff.gradeGuide.id,
  gradeGuideVersion: exampleHandoff.gradeGuide.version,
  overallScore: exampleHandoff.score.overall,
  minimumOverallScore: exampleHandoff.score.minimumRequired,
  thresholdMet: exampleHandoff.score.thresholdMet,
  mandatoryDimensionsMet: exampleHandoff.score.mandatoryDimensionsMet,
  decision: exampleHandoff.decision,
  dimensionAssessments: exampleHandoff.dimensionAssessments,
  reviewReasons: exampleHandoff.reviewReasons,
  modelWarnings: exampleHandoff.modelWarnings,
  assessmentSummary: exampleHandoff.assessmentSummary,
  attemptCount: exampleHandoff.execution.attemptCount,
  executionStatus: exampleHandoff.execution.status,
  startedAt: exampleHandoff.execution.startedAt,
  completedAt: exampleHandoff.execution.completedAt,
  scoringModel: exampleHandoff.metadata.scoringModel,
  promptVersion: exampleHandoff.metadata.promptVersion,
  engineVersion: exampleHandoff.metadata.engineVersion,
  assessmentStatus: exampleHandoff.metadata.assessmentStatus,
  assessmentCreatedAt: exampleHandoff.metadata.createdAt,
};

const demoHandoff = executeCodeNode(
  'Build Demo Phase 3 Handoff',
  demoSource,
)[0].json.phase3Handoff;

assert.deepEqual(demoHandoff, exampleHandoff);
assert.doesNotThrow(() =>
  executeCodeNode(
    'Validate Phase 3 Handoff',
    { phase3Handoff: demoHandoff },
  )
);

const temporaryDirectory = fs.mkdtempSync(
  path.join(os.tmpdir(), 'talentai-phase45-transform-'),
);
const transformedPath = path.join(temporaryDirectory, 'workflow.json');

try {
  fs.copyFileSync(workflowPath, transformedPath);

  for (let iteration = 0; iteration < 2; iteration += 1) {
    const transform = spawnSync(
      process.execPath,
      [
        path.join(repositoryRoot, 'scripts', 'transform-phase45-handoff.mjs'),
        transformedPath,
      ],
      { encoding: 'utf8' },
    );

    assert.equal(
      transform.status,
      0,
      transform.stderr || transform.stdout,
    );
    assert.deepEqual(
      readJson(transformedPath),
      workflow,
      `Phase 4/5 transformer drifted on iteration ${iteration + 1}.`,
    );
  }
} finally {
  fs.rmSync(temporaryDirectory, { recursive: true, force: true });
}

console.log(
  'TalentAI Phase 4/5 handoff boundary and workflow source contract passed.'
);
