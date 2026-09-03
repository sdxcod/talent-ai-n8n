#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, '..');
const workflowPath = process.argv[2];

if (!workflowPath) {
  throw new Error(
    'Usage: node scripts/transform-phase45-handoff.mjs <workflow.json>'
  );
}

const readRepositoryFile = (relativePath) =>
  readFileSync(resolve(repositoryRoot, relativePath), 'utf8');

const code = (name) =>
  readRepositoryFile(`workflows/phase-4-5/code/${name}.js`).trimEnd();

const sql = (name) =>
  readRepositoryFile(`workflows/phase-4-5/sql/${name}.sql`);

const workflow = JSON.parse(readFileSync(workflowPath, 'utf8'));
const handoffAlreadyTransformed = workflow.nodes.some(
  (node) => node.name === 'Validate Phase 3 Handoff'
);

const findNode = (name) =>
  workflow.nodes.find((node) => node.name === name);

const requireNode = (name) => {
  const node = findNode(name);

  if (!node) {
    throw new Error(`${workflow.name}: required node is missing: ${name}`);
  }

  return node;
};

const renameNode = (oldName, newName) => {
  const node = findNode(newName) ?? requireNode(oldName);

  if (node.name === oldName) {
    node.name = newName;
  }

  if (workflow.connections[oldName]) {
    workflow.connections[newName] = workflow.connections[oldName];
    delete workflow.connections[oldName];
  }

  for (const outputs of Object.values(workflow.connections)) {
    for (const outputGroup of outputs.main ?? []) {
      for (const connection of outputGroup ?? []) {
        if (connection.node === oldName) {
          connection.node = newName;
        }
      }
    }
  }

  for (const candidate of workflow.nodes) {
    if (candidate.type !== 'n8n-nodes-base.code') continue;

    const jsCode = candidate.parameters?.jsCode;

    if (typeof jsCode === 'string') {
      candidate.parameters.jsCode = jsCode.replaceAll(
        `'${oldName}'`,
        `'${newName}'`
      );
    }
  }

  return node;
};

const upsertNode = (node) => {
  const index = workflow.nodes.findIndex(
    (candidate) => candidate.name === node.name
  );

  if (index >= 0) {
    workflow.nodes[index] = node;
  } else {
    workflow.nodes.push(node);
  }
};

const mainConnection = (node, index = 0) => ({
  node,
  type: 'main',
  index,
});

const validateDemoRequest = renameNode(
  'Validate Interview Request',
  'Validate Demo Interview Request'
);
validateDemoRequest.parameters.jsCode = code(
  'tai04-validate-demo-interview-request'
);
validateDemoRequest.position = [-128, -256];

const loadCompletedAssessment = renameNode(
  'Resolve Candidate and Resume Grade',
  'Load Completed Phase 3 Assessment'
);
loadCompletedAssessment.parameters.query = sql(
  'load-completed-phase3-handoff-by-extraction'
);
loadCompletedAssessment.parameters.options = {
  queryReplacement: '={{ [$json.extractionId] }}',
};
loadCompletedAssessment.position = [96, -256];

const resolved = requireNode('Interview Context Resolved?');
resolved.position = [320, -256];

const failSetup = requireNode('Fail Interview Setup');
failSetup.position = [544, -128];

const validateHandoff = renameNode(
  'Build Interview Context',
  'Validate Phase 3 Handoff'
);
validateHandoff.parameters.jsCode = code('tai04-validate-phase3-handoff');
validateHandoff.position = [768, -320];

upsertNode({
  parameters: {
    jsCode: code('tai04-build-demo-phase3-handoff'),
  },
  type: 'n8n-nodes-base.code',
  typeVersion: 2,
  position: [544, -320],
  id: 'ad4e2705-1e38-4a71-9456-b9a5f9d4e201',
  name: 'Build Demo Phase 3 Handoff',
});

const form = requireNode('On interview request');
form.parameters.formDescription =
  'Demo adapter: start an interview from a completed TalentAI Phase 3 extraction.';
form.position = [-352, -256];

const trigger = requireNode('When Executed by Another Workflow');
trigger.parameters.inputSource = 'workflowInputs';
trigger.parameters.workflowInputs = {
  values: [
    {
      name: 'phase3Handoff',
      type: 'object',
    },
  ],
};
trigger.position = [544, -512];

const configuration = requireNode('Interview Configuration');
configuration.position = [992, -320];

if (!handoffAlreadyTransformed) {
  for (const node of workflow.nodes) {
    if (node.position?.[0] >= 992 && node.name !== 'Interview Configuration') {
      node.position[0] += 224;
    }
  }
}

const promptNode = requireNode('Build Interview Question Prompt');
promptNode.parameters.jsCode = promptNode.parameters.jsCode
  .replace(
    'probe the skills and claims in candidateProfile,',
    'probe the resume claims represented by evidence and rationale in resumeGrade.dimensions,'
  )
  .replace(
    'and ask explanatory questions about concrete projects from workExperiences.',
    'and ask explanatory questions that verify the specific evidence quotes without treating them as established truth.'
  );

workflow.connections['On interview request'] = {
  main: [[mainConnection('Validate Demo Interview Request')]],
};
workflow.connections['Validate Demo Interview Request'] = {
  main: [[mainConnection('Load Completed Phase 3 Assessment')]],
};
workflow.connections['Load Completed Phase 3 Assessment'] = {
  main: [[mainConnection('Interview Context Resolved?')]],
};
workflow.connections['Interview Context Resolved?'] = {
  main: [
    [mainConnection('Build Demo Phase 3 Handoff')],
    [mainConnection('Fail Interview Setup')],
  ],
};
workflow.connections['Build Demo Phase 3 Handoff'] = {
  main: [[mainConnection('Validate Phase 3 Handoff')]],
};
workflow.connections['When Executed by Another Workflow'] = {
  main: [[mainConnection('Validate Phase 3 Handoff')]],
};
workflow.connections['Validate Phase 3 Handoff'] = {
  main: [[mainConnection('Interview Configuration')]],
};

writeFileSync(
  workflowPath,
  `${JSON.stringify(workflow, null, 2)}\n`,
  'utf8'
);
