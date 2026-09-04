#!/usr/bin/env node

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, '..');
const workflowDirectory = path.join(
  repositoryRoot,
  'workflows',
  'technical-interview'
);
const workflowPath = path.join(
  workflowDirectory,
  'TAI-05-secure-interview-invitation-v1.json'
);
const manifest = JSON.parse(
  fs.readFileSync(path.join(workflowDirectory, 'manifest.json'), 'utf8')
);
const workflow = JSON.parse(fs.readFileSync(workflowPath, 'utf8'));

const descriptor = manifest.workflows.find(
  ({ id }) => id === 'L8uQ5xN2pR7sV4wZ'
);

assert.deepEqual(descriptor, {
  id: 'L8uQ5xN2pR7sV4wZ',
  name: 'TAI-05 Secure Interview Invitation v1',
  file: 'TAI-05-secure-interview-invitation-v1.json',
});
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
    `Committed TAI-05 contains runtime field: ${forbiddenKey}`,
  );
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const nodeByName = new Map(workflow.nodes.map((node) => [node.name, node]));

assert.equal(nodeByName.size, workflow.nodes.length, 'TAI-05 node names must be unique.');

for (const node of workflow.nodes) {
  assert.match(node.id, uuidPattern, `TAI-05 node UUID is invalid: ${node.name}`);

  if (node.webhookId !== undefined) {
    assert.match(
      node.webhookId,
      uuidPattern,
      `TAI-05 webhook UUID is invalid: ${node.name}`,
    );
  }

  assert.equal(
    Object.hasOwn(node, 'credentials'),
    false,
    `Committed TAI-05 node contains credentials: ${node.name}`,
  );
}

for (const name of [
  'On authorized invitation operation',
  'Validate Invitation Operation',
  'Issue Invitation?',
  'Load Completed Phase 3 For Invitation',
  'Invitation Context Resolved?',
  'Build Phase 3 Invitation Handoff',
  'Validate Phase 3 Invitation Handoff',
  'Issue Secure Interview Invitation',
  'Invitation Issued?',
  'Build Secure Invitation Result',
  'Revoke Secure Interview Invitation',
  'Invitation Revoked?',
  'Build Secure Revocation Result',
  'Build Secure Invitation Failure',
  'Show Secure Invitation Result',
  'Show Secure Invitation Failure',
]) {
  assert.ok(nodeByName.has(name), `Required TAI-05 node is missing: ${name}`);
}

const trigger = nodeByName.get('On authorized invitation operation');
assert.equal(trigger.parameters.authentication, 'n8nUserAuth');
assert.equal(trigger.parameters.requireExecuteAccess, true);
assert.equal(
  trigger.parameters.options.path,
  manifest.invitation.operatorFormPath,
);
assert.equal(trigger.parameters.options.ignoreBots, true);
assert.equal(trigger.parameters.options.showHeaders, false);

const fields = trigger.parameters.formFields.values;
const fieldByName = new Map(fields.map((field) => [field.fieldName, field]));
assert.deepEqual([...fieldByName.keys()].sort(), [
  'action',
  'extractionId',
  'invitationId',
  'ttlMinutes',
]);
assert.equal(fieldByName.get('ttlMinutes').defaultValue, '2880');
assert.deepEqual(
  fieldByName.get('action').fieldOptions.values.map(({ option }) => option),
  ['ISSUE', 'REVOKE'],
);

assert.equal(workflow.settings.saveDataErrorExecution, 'none');
assert.equal(workflow.settings.saveDataSuccessExecution, 'none');
assert.equal(workflow.settings.saveManualExecutions, false);
assert.equal(workflow.settings.saveExecutionProgress, false);
assert.equal(workflow.settings.redactionPolicy, 'all');
assert.equal(workflow.settings.executionTimeout, 60);

const connectionTargets = (name, outputIndex = 0) =>
  (workflow.connections[name]?.main?.[outputIndex] ?? []).map(
    ({ node }) => node
  );

assert.deepEqual(
  connectionTargets('Issue Invitation?', 0),
  ['Load Completed Phase 3 For Invitation'],
);
assert.deepEqual(
  connectionTargets('Issue Invitation?', 1),
  ['Revoke Secure Interview Invitation'],
);
assert.deepEqual(
  connectionTargets('Invitation Issued?', 0),
  ['Build Secure Invitation Result'],
);
assert.deepEqual(
  connectionTargets('Invitation Issued?', 1),
  ['Build Secure Invitation Failure'],
);
assert.deepEqual(
  connectionTargets('Invitation Revoked?', 0),
  ['Build Secure Revocation Result'],
);
assert.deepEqual(
  connectionTargets('Invitation Revoked?', 1),
  ['Build Secure Invitation Failure'],
);
assert.deepEqual(
  connectionTargets('Build Secure Invitation Failure'),
  ['Show Secure Invitation Failure'],
);

for (const name of [
  'Validate Invitation Operation',
  'Load Completed Phase 3 For Invitation',
  'Build Phase 3 Invitation Handoff',
  'Validate Phase 3 Invitation Handoff',
  'Issue Secure Interview Invitation',
  'Build Secure Invitation Result',
  'Revoke Secure Interview Invitation',
  'Build Secure Revocation Result',
]) {
  assert.equal(
    nodeByName.get(name).onError,
    'continueErrorOutput',
    `${name} must expose a controlled failure output.`,
  );
  assert.deepEqual(
    connectionTargets(name, 1),
    ['Build Secure Invitation Failure'],
    `${name} must route errors to the sanitized failure builder.`,
  );
}

const sourceCode = (name) => fs.readFileSync(
  path.join(workflowDirectory, 'code', `${name}.js`),
  'utf8'
).trimEnd();

for (const [nodeName, sourceName] of [
  ['Validate Invitation Operation', 'tai05-validate-invitation-operation'],
  ['Build Phase 3 Invitation Handoff', 'build-phase3-handoff-from-query'],
  ['Validate Phase 3 Invitation Handoff', 'tai04-validate-phase3-handoff'],
  ['Build Secure Invitation Result', 'tai05-build-invitation-result'],
  ['Build Secure Revocation Result', 'tai05-build-revocation-result'],
  ['Build Secure Invitation Failure', 'tai05-build-operation-failure'],
]) {
  assert.equal(
    nodeByName.get(nodeName).parameters.jsCode,
    sourceCode(sourceName),
    `${nodeName} drifted from ${sourceName}.js`,
  );
}

const databaseQuery = (name) => fs.readFileSync(
  path.join(repositoryRoot, 'database', 'queries', `${name}.sql`),
  'utf8'
);

assert.equal(
  nodeByName.get('Issue Secure Interview Invitation').parameters.query,
  databaseQuery('Q022__issue_technical_interview_invitation'),
);
assert.equal(
  nodeByName.get('Revoke Secure Interview Invitation').parameters.query,
  databaseQuery('Q024__revoke_technical_interview_invitation'),
);
assert.equal(
  nodeByName.get('Load Completed Phase 3 For Invitation').parameters.query,
  fs.readFileSync(
    path.join(
      workflowDirectory,
      'sql',
      'load-completed-phase3-handoff-by-extraction.sql'
    ),
    'utf8'
  ),
);

const executeCode = (nodeName, input, executionId = 'secure-test-execution') => {
  const run = new Function(
    '$input',
    '$execution',
    nodeByName.get(nodeName).parameters.jsCode
  );

  return run(
    { first: () => ({ json: structuredClone(input) }) },
    { id: executionId },
  )[0].json;
};

const extractionId = '60000000-0000-4000-8000-000000000003';
const invitationId = '60000000-0000-4000-8000-000000000005';

assert.deepEqual(
  executeCode('Validate Invitation Operation', {
    action: 'issue',
    extractionId,
    ttlMinutes: '2880',
  }),
  {
    action: 'ISSUE',
    extractionId,
    invitationId: null,
    ttlMinutes: 2880,
  },
);
assert.deepEqual(
  executeCode('Validate Invitation Operation', {
    action: 'REVOKE',
    invitationId,
  }),
  {
    action: 'REVOKE',
    extractionId: null,
    invitationId,
    ttlMinutes: null,
  },
);
assert.throws(
  () => executeCode('Validate Invitation Operation', {
    action: 'ISSUE',
    extractionId: 'invalid',
    ttlMinutes: 2880,
  }),
  /INVALID_EXTRACTION_ID/,
);

const invitationResult = executeCode('Build Secure Invitation Result', {
  canDeliver: true,
  invitationToken: 'a'.repeat(64),
  invitationId,
  issueStatus: 'ISSUED_NEW',
  issueCount: 1,
  expiresAt: '2026-09-06T00:00:00.000Z',
});

assert.equal(invitationResult.success, true);
assert.match(
  invitationResult.invitationPath,
  /^\/form\/talentai-candidate-interview\?invitationToken=[0-9a-f]{64}$/,
);
assert.doesNotMatch(
  invitationResult.invitationPath,
  /requestId|assessmentId|extractionId/i,
);

const temporaryDirectory = fs.mkdtempSync(
  path.join(os.tmpdir(), 'talentai-tai05-build-')
);
const generatedPath = path.join(temporaryDirectory, 'workflow.json');

try {
  for (let iteration = 0; iteration < 2; iteration += 1) {
    const build = spawnSync(
      process.execPath,
      [
        path.join(repositoryRoot, 'scripts', 'build-tai05-secure-invitation.mjs'),
        generatedPath,
      ],
      { encoding: 'utf8' },
    );

    assert.equal(build.status, 0, build.stderr || build.stdout);
    assert.deepEqual(
      JSON.parse(fs.readFileSync(generatedPath, 'utf8')),
      workflow,
      `TAI-05 builder drifted on iteration ${iteration + 1}.`,
    );
  }
} finally {
  fs.rmSync(temporaryDirectory, { recursive: true, force: true });
}

console.log(
  'TalentAI secure invitation workflow and privacy contract passed.'
);
