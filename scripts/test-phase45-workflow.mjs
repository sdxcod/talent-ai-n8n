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

for (const node of workflow.nodes) {
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
  'Generate Interview Questions',
  'Validate Interview Questions',
  'Generate Follow-up Questions',
  'Validate Follow-up Questions',
  'Score Interview Answers',
  'Validate Answer Scores',
  'Calculate Final Grade',
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
]) {
  assert.equal(
    nodeByName.get(nodeName).parameters.jsCode,
    sourceCode(sourceName),
    `${nodeName} is not synchronized with ${sourceName}.js`,
  );
}

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
