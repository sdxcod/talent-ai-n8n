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

const databaseQuery = (name) =>
  readRepositoryFile(`database/queries/${name}.sql`);

const workflow = JSON.parse(readFileSync(workflowPath, 'utf8'));

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

const ifNode = ({ name, id, position, leftValue }) => ({
  parameters: {
    conditions: {
      options: {
        caseSensitive: true,
        leftValue: '',
        typeValidation: 'strict',
        version: 3,
      },
      conditions: [
        {
          id: `${id}-condition`,
          leftValue,
          rightValue: '',
          operator: {
            type: 'boolean',
            operation: 'true',
            singleValue: true,
          },
        },
      ],
      combinator: 'and',
    },
    options: {},
  },
  type: 'n8n-nodes-base.if',
  typeVersion: 2.3,
  position,
  id,
  name,
});

const postgresQueryNode = ({
  name,
  id,
  position,
  queryName,
  queryReplacement,
}) => ({
  parameters: {
    operation: 'executeQuery',
    query: databaseQuery(queryName),
    options: {
      queryReplacement,
    },
  },
  type: 'n8n-nodes-base.postgres',
  typeVersion: 2.7,
  position,
  id,
  name,
});

const codeNode = ({ name, id, position, sourceName }) => ({
  parameters: {
    jsCode: code(sourceName),
  },
  type: 'n8n-nodes-base.code',
  typeVersion: 2,
  position,
  id,
  name,
});

const stopAndErrorNode = ({ name, id, position, errorMessage }) => ({
  parameters: {
    errorMessage,
  },
  type: 'n8n-nodes-base.stopAndError',
  typeVersion: 1,
  position,
  id,
  name,
});

const validateDemoRequest = renameNode(
  'Validate Interview Request',
  'Validate Demo Interview Request'
);
validateDemoRequest.parameters.jsCode = code(
  'tai04-validate-demo-interview-request'
);
validateDemoRequest.position = [-160, -256];

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
loadCompletedAssessment.position = [64, -256];

const resolved = requireNode('Interview Context Resolved?');
resolved.position = [288, -256];

const failSetup = requireNode('Fail Interview Setup');
failSetup.position = [512, -128];

const validateHandoff = renameNode(
  'Build Interview Context',
  'Validate Phase 3 Handoff'
);
validateHandoff.parameters.jsCode = code('tai04-validate-phase3-handoff');
validateHandoff.position = [736, -320];

upsertNode(codeNode({
  name: 'Build Demo Phase 3 Handoff',
  id: 'ad4e2705-1e38-4a71-9456-b9a5f9d4e201',
  position: [512, -320],
  sourceName: 'tai04-build-demo-phase3-handoff',
}));

const form = requireNode('On interview request');
form.parameters.formDescription =
  'Demo adapter: start an interview from a completed TalentAI Phase 3 extraction.';
form.position = [-384, -256];

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
trigger.position = [512, -512];

const configuration = requireNode('Interview Configuration');
configuration.position = [1408, -320];

upsertNode(postgresQueryNode({
  name: 'Claim Technical Interview Session',
  id: '22dc1a92-e189-47c5-91c4-498c11ec45d7',
  position: [960, -320],
  queryName: 'Q013__claim_technical_interview_session',
  queryReplacement:
    '={{ [$json.correlation.contractVersion, $json.correlation.requestId, $json.correlation.assessmentId, $json.correlation.extractionId, String($execution.id)] }}',
}));

upsertNode(ifNode({
  name: 'Interview Claim Can Continue?',
  id: '9773418d-f421-40bd-8920-7b9b4dd1c951',
  position: [1184, -320],
  leftValue: '={{ $json.canContinue === true }}',
}));

upsertNode(ifNode({
  name: 'Completed Interview Replay?',
  id: 'fe43b43a-19f2-4b4b-8d33-bda7b013a4f1',
  position: [1408, -128],
  leftValue:
    "={{ String($json.claimStatus ?? '') === 'COMPLETED_REPLAY' }}",
}));

upsertNode(postgresQueryNode({
  name: 'Load Completed Technical Interview',
  id: '273f6900-d01f-4408-b65e-ae9beb922f60',
  position: [1632, -384],
  queryName: 'Q018__load_completed_technical_interview',
  queryReplacement:
    "={{ [$('Validate Phase 3 Handoff').first().json.correlation.contractVersion, $('Validate Phase 3 Handoff').first().json.correlation.requestId, $('Validate Phase 3 Handoff').first().json.correlation.assessmentId] }}",
}));

upsertNode(stopAndErrorNode({
  name: 'Reject Technical Interview Claim',
  id: '26379c3d-96e2-41d2-a4ed-3595603cc5dc',
  position: [1632, -128],
  errorMessage:
    "={{ 'TECHNICAL_INTERVIEW_CLAIM_REJECTED: ' + String($json.claimStatus ?? 'UNKNOWN') + ' [requestId=' + String($json.requestId ?? '') + ', assessmentId=' + String($json.assessmentId ?? '') + ']' }}",
}));

upsertNode(postgresQueryNode({
  name: 'Persist First Question Set',
  id: 'bb866eb9-7e7d-45be-b04b-e2ce483fc056',
  position: [2304, -320],
  queryName: 'Q014__persist_technical_question_set',
  queryReplacement:
    "={{ [$('Claim Technical Interview Session').first().json.sessionId, String($execution.id), 'FIRST', JSON.stringify($json.questionPlan), 'gpt-5.6-sol', '1.0'] }}",
}));

upsertNode(codeNode({
  name: 'Restore First Question Form',
  id: '5ff3bc18-ae39-49d2-8283-8158d73e2d50',
  position: [2528, -320],
  sourceName: 'tai04-restore-first-question-form',
}));

upsertNode(postgresQueryNode({
  name: 'Persist First Round Answers',
  id: '6f24d56e-9057-4824-8e6a-d51a316e0b64',
  position: [3200, -320],
  queryName: 'Q015__persist_technical_interview_answers',
  queryReplacement:
    "={{ [$('Claim Technical Interview Session').first().json.sessionId, String($execution.id), $('Persist First Question Set').first().json.questionSetId, JSON.stringify($json.answerRecords)] }}",
}));

upsertNode(codeNode({
  name: 'Restore First Round Answers',
  id: '55e8b39b-2735-4183-9e80-681768272581',
  position: [3424, -320],
  sourceName: 'tai04-restore-first-round-answers',
}));

upsertNode(postgresQueryNode({
  name: 'Persist Follow-up Question Set',
  id: '8d910cf1-c42e-47cb-8901-fe8c4d9d93c6',
  position: [4544, -320],
  queryName: 'Q014__persist_technical_question_set',
  queryReplacement:
    "={{ [$('Claim Technical Interview Session').first().json.sessionId, String($execution.id), 'FOLLOW_UP', JSON.stringify($json.questionPlan), 'gpt-5.6-sol', '1.0'] }}",
}));

upsertNode(codeNode({
  name: 'Restore Follow-up Question Form',
  id: '5f3d2a26-23bb-4633-93f3-6ee70a05bdee',
  position: [4768, -320],
  sourceName: 'tai04-restore-follow-up-question-form',
}));

upsertNode(postgresQueryNode({
  name: 'Persist Follow-up Answers',
  id: 'e9565333-830d-4c37-95ef-8c6674f70518',
  position: [5440, -320],
  queryName: 'Q015__persist_technical_interview_answers',
  queryReplacement:
    "={{ [$('Claim Technical Interview Session').first().json.sessionId, String($execution.id), $('Persist Follow-up Question Set').first().json.questionSetId, JSON.stringify($json.answerRecords)] }}",
}));

upsertNode(codeNode({
  name: 'Restore Follow-up Answers',
  id: 'e03e14b2-c86a-43c7-8fa2-f95a9dc55d99',
  position: [5664, -320],
  sourceName: 'tai04-restore-follow-up-answers',
}));

upsertNode(postgresQueryNode({
  name: 'Apply Answer Evaluations',
  id: '9db1ce3b-8d8d-479a-b0cf-5c136c720394',
  position: [6560, -320],
  queryName: 'Q016__apply_technical_answer_evaluations',
  queryReplacement:
    "={{ [$('Claim Technical Interview Session').first().json.sessionId, String($execution.id), JSON.stringify($json.answerRecords)] }}",
}));

upsertNode(codeNode({
  name: 'Restore Validated Answer Scores',
  id: 'bd156ad7-12c0-4af8-ac6a-18dd2a2e093d',
  position: [6784, -320],
  sourceName: 'tai04-restore-validated-answer-scores',
}));

upsertNode(postgresQueryNode({
  name: 'Complete Technical Interview',
  id: 'bf8e141b-bc52-4788-81ce-5f5235208ebf',
  position: [7232, -320],
  queryName: 'Q017__complete_technical_interview',
  queryReplacement:
    "={{ [$('Claim Technical Interview Session').first().json.sessionId, String($execution.id), JSON.stringify($json)] }}",
}));

upsertNode(codeNode({
  name: 'Build Persisted Interview Result',
  id: 'f22a89d9-c247-49ac-b557-b7d01c49d37a',
  position: [7456, -320],
  sourceName: 'tai04-build-persisted-interview-result',
}));

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

const positions = new Map([
  ['Build Interview Question Prompt', [1632, -320]],
  ['Generate Interview Questions', [1856, -320]],
  ['GapGPT Interview Question Model', [1856, -88]],
  ['Interview Question Output Parser', [1856, -552]],
  ['Validate Interview Questions', [2080, -320]],
  ['Candidate Interview Form', [2752, -320]],
  ['Normalize Interview Answers', [2976, -320]],
  ['Build Follow-up Question Prompt', [3648, -320]],
  ['Generate Follow-up Questions', [3872, -320]],
  ['GapGPT Follow-up Question Model', [3872, -88]],
  ['Follow-up Question Output Parser', [3872, -552]],
  ['Validate Follow-up Questions', [4320, -320]],
  ['Follow-up Interview Form', [4992, -320]],
  ['Normalize Follow-up Answers', [5216, -320]],
  ['Build Answer Scoring Prompt', [5888, -320]],
  ['Score Interview Answers', [6112, -320]],
  ['GapGPT Answer Scoring Model', [6112, -88]],
  ['Answer Score Output Parser', [6112, -552]],
  ['Validate Answer Scores', [6336, -320]],
  ['Calculate Final Grade', [7008, -320]],
  ['Build Final Grade Summary', [7680, -320]],
  ['Show Final Grade', [7904, -320]],
]);

for (const [name, position] of positions.entries()) {
  requireNode(name).position = position;
}

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
  main: [[mainConnection('Claim Technical Interview Session')]],
};
workflow.connections['Claim Technical Interview Session'] = {
  main: [[mainConnection('Interview Claim Can Continue?')]],
};
workflow.connections['Interview Claim Can Continue?'] = {
  main: [
    [mainConnection('Interview Configuration')],
    [mainConnection('Completed Interview Replay?')],
  ],
};
workflow.connections['Completed Interview Replay?'] = {
  main: [
    [mainConnection('Load Completed Technical Interview')],
    [mainConnection('Reject Technical Interview Claim')],
  ],
};
workflow.connections['Load Completed Technical Interview'] = {
  main: [[mainConnection('Build Persisted Interview Result')]],
};
workflow.connections['Interview Configuration'] = {
  main: [[mainConnection('Build Interview Question Prompt')]],
};
workflow.connections['Build Interview Question Prompt'] = {
  main: [[mainConnection('Generate Interview Questions')]],
};
workflow.connections['Generate Interview Questions'] = {
  main: [[mainConnection('Validate Interview Questions')]],
};
workflow.connections['Validate Interview Questions'] = {
  main: [[mainConnection('Persist First Question Set')]],
};
workflow.connections['Persist First Question Set'] = {
  main: [[mainConnection('Restore First Question Form')]],
};
workflow.connections['Restore First Question Form'] = {
  main: [[mainConnection('Candidate Interview Form')]],
};
workflow.connections['Candidate Interview Form'] = {
  main: [[mainConnection('Normalize Interview Answers')]],
};
workflow.connections['Normalize Interview Answers'] = {
  main: [[mainConnection('Persist First Round Answers')]],
};
workflow.connections['Persist First Round Answers'] = {
  main: [[mainConnection('Restore First Round Answers')]],
};
workflow.connections['Restore First Round Answers'] = {
  main: [[mainConnection('Build Follow-up Question Prompt')]],
};
workflow.connections['Build Follow-up Question Prompt'] = {
  main: [[mainConnection('Generate Follow-up Questions')]],
};
workflow.connections['Generate Follow-up Questions'] = {
  main: [[mainConnection('Validate Follow-up Questions')]],
};
workflow.connections['Validate Follow-up Questions'] = {
  main: [[mainConnection('Persist Follow-up Question Set')]],
};
workflow.connections['Persist Follow-up Question Set'] = {
  main: [[mainConnection('Restore Follow-up Question Form')]],
};
workflow.connections['Restore Follow-up Question Form'] = {
  main: [[mainConnection('Follow-up Interview Form')]],
};
workflow.connections['Follow-up Interview Form'] = {
  main: [[mainConnection('Normalize Follow-up Answers')]],
};
workflow.connections['Normalize Follow-up Answers'] = {
  main: [[mainConnection('Persist Follow-up Answers')]],
};
workflow.connections['Persist Follow-up Answers'] = {
  main: [[mainConnection('Restore Follow-up Answers')]],
};
workflow.connections['Restore Follow-up Answers'] = {
  main: [[mainConnection('Build Answer Scoring Prompt')]],
};
workflow.connections['Build Answer Scoring Prompt'] = {
  main: [[mainConnection('Score Interview Answers')]],
};
workflow.connections['Score Interview Answers'] = {
  main: [[mainConnection('Validate Answer Scores')]],
};
workflow.connections['Validate Answer Scores'] = {
  main: [[mainConnection('Apply Answer Evaluations')]],
};
workflow.connections['Apply Answer Evaluations'] = {
  main: [[mainConnection('Restore Validated Answer Scores')]],
};
workflow.connections['Restore Validated Answer Scores'] = {
  main: [[mainConnection('Calculate Final Grade')]],
};
workflow.connections['Calculate Final Grade'] = {
  main: [[mainConnection('Complete Technical Interview')]],
};
workflow.connections['Complete Technical Interview'] = {
  main: [[mainConnection('Build Persisted Interview Result')]],
};
workflow.connections['Build Persisted Interview Result'] = {
  main: [[mainConnection('Build Final Grade Summary')]],
};
workflow.connections['Build Final Grade Summary'] = {
  main: [[mainConnection('Show Final Grade')]],
};

writeFileSync(
  workflowPath,
  `${JSON.stringify(workflow, null, 2)}\n`,
  'utf8'
);
