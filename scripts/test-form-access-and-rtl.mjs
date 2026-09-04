#!/usr/bin/env node

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, '..');
const read = (relativePath) =>
  readFileSync(resolve(repositoryRoot, relativePath), 'utf8');
const json = (relativePath) => JSON.parse(read(relativePath));

const formCss = read('workflows/shared/talentai-form-rtl.css').trim();
assert.match(formCss, /direction:\s*rtl/);
assert.match(formCss, /input\[name="invitationToken"\]/);
assert.match(formCss, /direction:\s*ltr/);

const tai01 = json(
  'workflows/resume-assessment/TAI-01-resume-intake-extraction-v2.json'
);
const tai04 = json(
  'workflows/technical-interview/TAI-04-candidate-interview-final-grade-v1.json'
);
const tai05 = json(
  'workflows/technical-interview/TAI-05-secure-interview-invitation-v1.json'
);

const node = (workflow, name) => {
  const found = workflow.nodes.find((candidate) => candidate.name === name);
  assert.ok(found, `${workflow.name}: missing node ${name}`);
  return found;
};

const assertRtlForms = (workflow) => {
  const forms = workflow.nodes.filter((candidate) =>
    ['n8n-nodes-base.formTrigger', 'n8n-nodes-base.form'].includes(
      candidate.type
    )
  );

  assert.ok(forms.length > 0, `${workflow.name}: no forms found`);
  for (const form of forms) {
    assert.equal(
      form.parameters.options?.customCss,
      formCss,
      `${workflow.name}: RTL CSS missing from ${form.name}`
    );
  }
};

assertRtlForms(tai01);
assertRtlForms(tai04);
assertRtlForms(tai05);

const hrIntake = node(tai01, 'On form submission');
assert.equal(hrIntake.parameters.authentication, 'n8nUserAuth');
assert.equal(hrIntake.parameters.requireExecuteAccess, true);
assert.equal(
  hrIntake.parameters.options.path,
  'talentai-hr-resume-assessment'
);
assert.equal(hrIntake.parameters.options.includeUserInOutput, false);

const candidateInterview = node(tai04, 'On interview request');
assert.equal(candidateInterview.parameters.authentication ?? 'none', 'none');
assert.equal(
  candidateInterview.parameters.options.path,
  'talentai-candidate-interview'
);

const invitationOperator = node(
  tai05,
  'On authorized invitation operation'
);
assert.equal(invitationOperator.parameters.authentication, 'n8nUserAuth');
assert.equal(invitationOperator.parameters.requireExecuteAccess, true);
assert.equal(invitationOperator.parameters.options.includeUserInOutput, false);

const resultSource = read(
  'workflows/resume-assessment/code/tai01-build-assessment-result.js'
);
const executeResultBuilder = new Function('$input', resultSource);
const assessment = {
  requestId: '10000000-0000-4000-8000-000000000001',
  assessmentId: '20000000-0000-4000-8000-000000000002',
  extractionId: '30000000-0000-4000-8000-000000000003',
  candidate: { fullName: 'Candidate <script>alert(1)</script>' },
  assessmentContext: {
    positionCode: 'JAVA_BACKEND',
    targetGradeCode: 'MID',
  },
  gradeGuide: { version: '1.0.0' },
  score: {
    overall: 75,
    minimumRequired: 70,
    thresholdMet: true,
    mandatoryDimensionsMet: true,
  },
  decision: 'MEETS_TARGET',
  execution: {
    requestId: '10000000-0000-4000-8000-000000000001',
    attemptCount: 1,
  },
  metadata: {
    scoringModel: 'gpt-5.6-sol',
    createdAt: '2026-09-04T00:00:00.000Z',
  },
};

const build = (overrides = {}) =>
  executeResultBuilder(
    {
      first: () => ({
        json: {
          ...assessment,
          ...overrides,
        },
      }),
    }
  )[0].json;

const positive = build();
assert.equal(positive.invitationEligible, true);
assert.equal(
  positive.invitationPath,
  '/form/talentai-secure-interview-invitation?action=ISSUE&extractionId=30000000-0000-4000-8000-000000000003&ttlMinutes=2880'
);
assert.match(positive.output, /صدور دعوت امن مصاحبه/);
assert.doesNotMatch(positive.output, /<script>/);
assert.match(positive.output, /&lt;script&gt;/);

const review = build({ decision: 'REVIEW_REQUIRED' });
assert.equal(review.invitationEligible, false);
assert.equal(review.invitationPath, null);
assert.doesNotMatch(review.output, /talentai-secure-interview-invitation/);
assert.match(review.output, /بررسی HR نیاز دارد/);

const belowTarget = build({ decision: 'BELOW_TARGET' });
assert.equal(belowTarget.invitationEligible, false);
assert.equal(belowTarget.invitationPath, null);
assert.doesNotMatch(belowTarget.output, /صدور دعوت امن مصاحبه/);

console.log(
  'TalentAI internal HR form access, conditional invitation CTA, and RTL contract passed.'
);
