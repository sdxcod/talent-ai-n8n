#!/usr/bin/env node

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, '..');
const workflowDirectory = path.join(repositoryRoot, 'workflows', 'phase-4-5');
const manifestPath = path.join(workflowDirectory, 'manifest.json');

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
  'Validate Interview Request',
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

console.log('TalentAI Phase 4/5 workflow source contract passed.');
