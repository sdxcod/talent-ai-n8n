#!/usr/bin/env node

import assert from 'node:assert/strict';
import { projectPhase3Handoff, validatePhase3Handoff } from './lib/phase3-handoff.mjs';

const dimensions = [
  ['JAVA_CORE', 25, true],
  ['SPRING_ECOSYSTEM', 20, true],
  ['DATABASE', 15, true],
  ['DISTRIBUTED_SYSTEMS', 15, false],
  ['TESTING', 10, true],
  ['SOFTWARE_ARCHITECTURE', 10, false],
  ['OBSERVABILITY_DEVOPS', 5, false],
];
const internal = {
  requestId: '00000000-0000-4000-8000-000000000001',
  assessmentId: '00000000-0000-4000-8000-000000000002',
  extractionId: '00000000-0000-4000-8000-000000000003',
  candidate: { fullName: 'Synthetic Candidate' },
  assessmentContext: { positionCode: 'JAVA_BACKEND', targetGradeCode: 'SENIOR', jobDescription: 'Synthetic Java backend role used only for contract validation.' },
  gradeGuide: { id: '00000000-0000-4000-8000-000000000004', version: '1.0.0' },
  score: { overall: 75, minimumRequired: 70, thresholdMet: true, mandatoryDimensionsMet: true },
  decision: 'MEETS_TARGET',
  dimensionAssessments: dimensions.map(([code, weight, mandatory]) => ({ code, title: code, weight, mandatory, modelScore: 3, effectiveScore: 3, confidence: 'HIGH', confidenceAccepted: true, weightedScore: Math.round((3 / 4) * weight * 100) / 100, minimumRequired: 2, minimumMet: true, evidence: [{ quote: 'Synthetic evidence', source: 'WORK_EXPERIENCE' }], rationale: 'Synthetic rationale' })),
  reviewReasons: [], modelWarnings: [], assessmentSummary: 'Synthetic assessment.',
  execution: { attemptCount: 1, status: 'COMPLETED', replayed: false, startedAt: '2026-09-01T00:00:00Z', completedAt: '2026-09-01T00:01:00Z' },
  metadata: { scoringModel: 'test-model', promptVersion: '1.0', engineVersion: '1.0', status: 'COMPLETED', createdAt: '2026-09-01T00:01:00Z' },
};

const payload = projectPhase3Handoff(internal);
assert.equal(validatePhase3Handoff(payload), payload);
assert.equal(payload.contractVersion, '1.0.0');
assert.equal(payload.metadata.assessmentStatus, 'COMPLETED');
assert.equal('schemaVersion' in payload, false);

for (const mutation of [
  (value) => { value.contractVersion = '2.0.0'; },
  (value) => { value.decision = 'REQUIRES_REVIEW'; },
  (value) => { value.dimensionAssessments.pop(); },
  (value) => { value.execution.status = 'FAILED'; },
]) {
  const invalid = structuredClone(payload);
  mutation(invalid);
  assert.throws(() => validatePhase3Handoff(invalid), /INVALID_PHASE3_HANDOFF/);
}

console.log('TalentAI Phase 3 handoff contract projection and validation passed.');
