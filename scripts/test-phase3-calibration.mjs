#!/usr/bin/env node

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(scriptDir, '..');
const workflowPath = path.join(root, 'workflows/phase-1/TAI-03-evidence-scoring-grade-engine-v1.json');
const casesPath = path.join(root, 'demo/phase3/calibration-cases.json');

const workflow = JSON.parse(fs.readFileSync(workflowPath, 'utf8'));
const suite = JSON.parse(fs.readFileSync(casesPath, 'utf8'));
const engineNode = workflow.nodes.find((node) => node.name === 'Calculate Deterministic Grade');
assert.ok(engineNode?.parameters?.jsCode, 'Deterministic grade engine node is missing');

const dimensions = [
  ['JAVA_CORE', 'Core Java and JVM', 25, true],
  ['SPRING_ECOSYSTEM', 'Spring Ecosystem', 20, true],
  ['DATABASE', 'Database and Persistence', 15, true],
  ['DISTRIBUTED_SYSTEMS', 'Distributed Systems and Messaging', 15, false],
  ['TESTING', 'Testing and Quality', 10, true],
  ['SOFTWARE_ARCHITECTURE', 'Software Architecture', 10, false],
  ['OBSERVABILITY_DEVOPS', 'Observability and Delivery', 5, false],
].map(([code, title, weight, mandatory]) => ({ code, title, weight, mandatory }));

const grades = {
  JUNIOR: { code: 'JUNIOR', minimumOverallScore: 30, minimumDimensionLevels: { JAVA_CORE: 1, SPRING_ECOSYSTEM: 1 } },
  MID: { code: 'MID', minimumOverallScore: 50, minimumDimensionLevels: { JAVA_CORE: 2, SPRING_ECOSYSTEM: 2, DATABASE: 2, TESTING: 1 } },
  SENIOR: { code: 'SENIOR', minimumOverallScore: 70, minimumDimensionLevels: { JAVA_CORE: 3, SPRING_ECOSYSTEM: 3, DATABASE: 3, DISTRIBUTED_SYSTEMS: 2, TESTING: 2, SOFTWARE_ARCHITECTURE: 2 } },
};

function runCase(testCase) {
  const evidenceScoring = {
    schemaVersion: '1.0',
    assessmentSummary: `Synthetic calibration case ${testCase.id}`,
    warnings: testCase.warnings,
    dimensions: dimensions.map((dimension, index) => ({
      code: dimension.code,
      score: testCase.scores[index],
      confidence: testCase.confidence,
      evidence: testCase.scores[index] > 0 ? [{ quote: testCase.profile, source: 'WORK_EXPERIENCE' }] : [],
      rationale: `Synthetic rationale for ${dimension.code}`,
    })),
  };

  for (const assessment of evidenceScoring.dimensions) {
    if (assessment.score > 0) {
      assert.ok(assessment.evidence.length > 0, `${testCase.id}: positive score lacks evidence`);
      for (const evidence of assessment.evidence) {
        assert.ok(testCase.profile.includes(evidence.quote), `${testCase.id}: evidence is not traceable to profile`);
      }
    }
  }

  const input = {
    gradeEngineInput: {
      execution: { requestId: '00000000-0000-4000-8000-000000000001' },
      extraction: { id: '00000000-0000-4000-8000-000000000002' },
      assessmentContext: { targetGradeCode: testCase.targetGrade },
      gradeGuide: {
        id: '00000000-0000-4000-8000-000000000003',
        version: suite.guideVersion,
        dimensions,
        targetGrade: grades[testCase.targetGrade],
        evidencePolicy: { minimumConfidenceForScoring: 'MEDIUM', missingEvidenceScore: 0 },
      },
    },
    evidenceScoring,
    scoringMetadata: { model: 'calibration-fixture', promptVersion: '1.0' },
  };

  const sandbox = {
    $input: { first: () => ({ json: input }) },
    $execution: { id: 'calibration-execution' },
    console,
  };
  const wrapped = `(function () { ${engineNode.parameters.jsCode} })()`;
  return vm.runInNewContext(wrapped, sandbox, { timeout: 1000 })[0].json;
}

for (const testCase of suite.cases) {
  assert.equal(testCase.scores.length, dimensions.length, `${testCase.id}: score count`);
  const first = runCase(testCase);
  const result = first.deterministicResult;
  assert.equal(result.overallScore, testCase.expected.overallScore, `${testCase.id}: overall score`);
  assert.equal(result.decision, testCase.expected.decision, `${testCase.id}: decision`);
  assert.equal(result.mandatoryDimensionsMet, testCase.expected.mandatoryDimensionsMet, `${testCase.id}: mandatory dimensions`);
  assert.deepEqual(first.evidenceScoring.warnings, testCase.warnings, `${testCase.id}: warnings`);

  const stableProjection = JSON.stringify(result);
  for (let run = 0; run < 25; run += 1) {
    assert.equal(JSON.stringify(runCase(testCase).deterministicResult), stableProjection, `${testCase.id}: unstable repeat ${run + 1}`);
  }
}

console.log(`TalentAI Phase 3 calibration passed: ${suite.cases.length} cases, 25 repeat runs each.`);
