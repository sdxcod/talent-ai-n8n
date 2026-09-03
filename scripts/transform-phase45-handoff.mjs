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

const failureCode = (sourceName, definition) =>
  `const failureDefinition = ${JSON.stringify(definition, null, 2)};\n${code(sourceName)}`;

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

const enableErrorOutput = (node) => {
  node.onError = 'continueErrorOutput';
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

const failureNode = ({
  name,
  id,
  position,
  sourceName = 'tai04-classify-interview-failure',
  definition,
}) => ({
  parameters: {
    jsCode: failureCode(sourceName, definition),
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

const phase3ResolutionFailure = renameNode(
  'Fail Interview Setup',
  'Phase 3 Resolution Failure'
);
Object.assign(
  phase3ResolutionFailure,
  failureNode({
    name: 'Phase 3 Resolution Failure',
    id: phase3ResolutionFailure.id,
    position: [512, -128],
    sourceName: 'tai04-classify-unclaimed-failure',
    definition: {
      stage: '',
      category: 'VALIDATION',
      code: 'COMPLETED_PHASE3_ASSESSMENT_NOT_FOUND',
      message: 'A completed Phase 3 assessment could not be resolved for the supplied extraction.',
      retryable: false,
    },
  })
);

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

const rejectedClaim = findNode('Build Rejected Technical Interview Result') ??
  renameNode(
    'Reject Technical Interview Claim',
    'Build Rejected Technical Interview Result'
  );
Object.assign(rejectedClaim, codeNode({
  name: 'Build Rejected Technical Interview Result',
  id: rejectedClaim.id,
  position: [1632, -128],
  sourceName: 'tai04-build-rejected-interview-result',
}));

upsertNode(ifNode({
  name: 'Fresh Interview Attempt?',
  id: '44fe4682-b86c-4a2b-a3a8-7baefafc1201',
  position: [1632, -320],
  leftValue:
    "={{ String($('Claim Technical Interview Session').first().json.currentStage ?? '') === 'QUESTION_GENERATION' }}",
}));

upsertNode(postgresQueryNode({
  name: 'Load Technical Interview Checkpoint',
  id: '655ca7f4-2036-4d04-9e13-472eb5101202',
  position: [1856, -704],
  queryName: 'Q020__load_technical_interview_checkpoint',
  queryReplacement:
    "={{ [$('Claim Technical Interview Session').first().json.sessionId, String($execution.id)] }}",
}));

upsertNode(codeNode({
  name: 'Build Technical Interview Checkpoint',
  id: '4a2d9af7-0f79-45e2-8911-ec81e39d1203',
  position: [2080, -704],
  sourceName: 'tai04-build-interview-checkpoint',
}));

for (const [name, id, position, stage] of [
  ['Resume First Round?', 'ab64e3bb-35db-4f19-b48f-405ec8ac1204', [2304, -704], 'FIRST_ROUND'],
  ['Resume Follow-up Generation?', '00f1ee70-9ebc-4492-847a-2167163d1205', [2528, -704], 'FOLLOW_UP_GENERATION'],
  ['Resume Follow-up?', '70b8cf31-4301-4090-9720-3d91607a1206', [2752, -704], 'FOLLOW_UP'],
  ['Resume Answer Evaluation?', '21474bd0-a6ed-4770-9262-f5c3345c1207', [2976, -704], 'ANSWER_EVALUATION'],
  ['Resume Result Persistence?', 'cbed4e20-5026-4276-888e-5565f9a41208', [3200, -704], 'RESULT_PERSISTENCE'],
]) {
  upsertNode(ifNode({
    name,
    id,
    position,
    leftValue: `={{ String($json.checkpointStage ?? '') === '${stage}' }}`,
  }));
}

upsertNode(codeNode({
  name: 'Prepare First Interview Form',
  id: '7062b417-03a5-4e97-898f-ce5f41891209',
  position: [2640, -320],
  sourceName: 'tai04-prepare-interview-form',
}));

upsertNode(codeNode({
  name: 'Prepare Follow-up Interview Form',
  id: '5be1c8e5-6cb1-408c-9f3a-6e82e2771210',
  position: [4880, -320],
  sourceName: 'tai04-prepare-interview-form',
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
    "={{ [$('Claim Technical Interview Session').first().json.sessionId, String($execution.id), JSON.stringify($json.answerRecords), JSON.stringify($json.answerScoring)] }}",
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

upsertNode(postgresQueryNode({
  name: 'Record Technical Interview Failure',
  id: 'fc546a2e-f315-4e09-838f-cf11df3adc01',
  position: [7008, 416],
  queryName: 'Q019__fail_technical_interview_session',
  queryReplacement:
    '={{ [$json.sessionId, $json.workflowExecutionId, $json.currentStage, $json.failureCategory, $json.failureCode, $json.failureMessage, $json.retryable] }}',
}));
enableErrorOutput(requireNode('Record Technical Interview Failure'));

upsertNode(codeNode({
  name: 'Build Failed Technical Interview Result',
  id: '2aae260f-1cf2-48f7-9bed-9586bf613202',
  position: [7232, 352],
  sourceName: 'tai04-build-failed-interview-result',
}));

upsertNode(codeNode({
  name: 'Build Interview Failure Recording Fallback',
  id: 'fe55a7c4-40e4-4d57-a6ea-b829f141d303',
  position: [7232, 480],
  sourceName: 'tai04-build-failure-recording-fallback',
}));

upsertNode(codeNode({
  name: 'Build Unrecorded Technical Interview Result',
  id: '9e21b709-a1c7-489c-8a12-280df89d8404',
  position: [960, 416],
  sourceName: 'tai04-build-unrecorded-interview-result',
}));

const unclaimedFailures = [
  {
    name: 'Demo Request Failure',
    id: '63e0d476-4644-4a94-aa0b-3b6a9abdf105',
    position: [-160, 64],
    definition: {
      stage: '',
      category: 'VALIDATION',
      code: 'TECHNICAL_INTERVIEW_REQUEST_VALIDATION_FAILED',
      message: 'The demo interview request did not satisfy the required contract.',
      retryable: false,
    },
  },
  {
    name: 'Phase 3 Lookup Failure',
    id: '96469124-e34d-4d96-a442-9a4c6e13b106',
    position: [64, 64],
    definition: {
      stage: '',
      category: 'PERSISTENCE',
      code: 'PHASE3_HANDOFF_LOOKUP_FAILED',
      message: 'The completed Phase 3 assessment could not be loaded.',
      retryable: true,
    },
  },
  {
    name: 'Demo Handoff Assembly Failure',
    id: '1f7d7540-6973-4812-8d17-86f18ebf9107',
    position: [512, 64],
    definition: {
      stage: '',
      category: 'ORCHESTRATION',
      code: 'PHASE3_HANDOFF_ASSEMBLY_FAILED',
      message: 'The demo Phase 3 handoff could not be assembled.',
      retryable: true,
    },
  },
  {
    name: 'Phase 3 Contract Failure',
    id: '7b67d3a1-8b5b-43c9-bda6-2d7468e1d108',
    position: [736, 64],
    definition: {
      stage: '',
      category: 'VALIDATION',
      code: 'PHASE3_HANDOFF_VALIDATION_FAILED',
      message: 'The Phase 3 handoff did not satisfy contract version 1.0.0.',
      retryable: false,
    },
  },
  {
    name: 'Interview Claim Failure',
    id: '36134c02-a145-48ac-aad1-bbce7770b109',
    position: [960, 64],
    definition: {
      stage: 'QUESTION_GENERATION',
      category: 'PERSISTENCE',
      code: 'TECHNICAL_INTERVIEW_CLAIM_FAILED',
      message: 'The technical interview session could not be claimed.',
      retryable: true,
    },
  },
];

for (const failure of unclaimedFailures) {
  upsertNode(failureNode({
    ...failure,
    sourceName: 'tai04-classify-unclaimed-failure',
  }));
}

const interviewFailures = [
  {
    name: 'Interview Configuration Failure',
    id: '559d335e-d37e-4fd0-b4d5-af314d4e1110',
    position: [1408, 64],
    definition: {
      stage: 'QUESTION_GENERATION',
      category: 'CONFIGURATION',
      code: 'TECHNICAL_INTERVIEW_CONFIGURATION_FAILED',
      message: 'The technical interview configuration is invalid.',
      retryable: false,
    },
  },
  {
    name: 'Question Prompt Failure',
    id: 'e31f8d53-61f4-4aa1-8510-e5b967de7111',
    position: [1632, 64],
    definition: {
      stage: 'QUESTION_GENERATION',
      category: 'ORCHESTRATION',
      code: 'INTERVIEW_QUESTION_PROMPT_FAILED',
      message: 'The interview question prompt could not be assembled.',
      retryable: true,
    },
  },
  {
    name: 'Question Generation Failure',
    id: '24f2bc43-8e18-4823-afb5-dba62d3d7112',
    position: [1856, 64],
    definition: {
      stage: 'QUESTION_GENERATION',
      category: 'PROVIDER',
      code: 'INTERVIEW_QUESTION_GENERATION_FAILED',
      message: 'Interview question generation failed; provider payload omitted.',
      retryable: true,
    },
  },
  {
    name: 'Question Validation Failure',
    id: '99aaf2cd-a394-41f8-a34d-4a6d01ba7113',
    position: [2080, 64],
    definition: {
      stage: 'QUESTION_GENERATION',
      category: 'PROVIDER',
      code: 'INTERVIEW_QUESTION_RESPONSE_INVALID',
      message: 'Generated interview questions did not satisfy the required schema.',
      retryable: true,
    },
  },
  {
    name: 'First Question Persistence Failure',
    id: '2b4253d2-78ec-4e66-93f8-789fb3fb7114',
    position: [2416, 64],
    definition: {
      stage: '',
      category: 'PERSISTENCE',
      code: 'FIRST_QUESTION_SET_PERSISTENCE_FAILED',
      message: 'The first-round question set could not be persisted.',
      retryable: true,
    },
  },
  {
    name: 'First Answer Validation Failure',
    id: '08b9b125-3121-4a63-a11d-e4d3cfc47115',
    position: [2976, 64],
    definition: {
      stage: 'FIRST_ROUND',
      category: 'VALIDATION',
      code: 'FIRST_ROUND_ANSWER_VALIDATION_FAILED',
      message: 'The first-round interview answers are invalid.',
      retryable: true,
    },
  },
  {
    name: 'First Answer Persistence Failure',
    id: 'f626697f-4c64-424e-a1c6-10d638737116',
    position: [3312, 64],
    definition: {
      stage: '',
      category: 'PERSISTENCE',
      code: 'FIRST_ROUND_ANSWER_PERSISTENCE_FAILED',
      message: 'The first-round interview answers could not be persisted.',
      retryable: true,
    },
  },
  {
    name: 'Follow-up Prompt Failure',
    id: 'a1a0473f-33cc-469d-9803-032c6bea7117',
    position: [3648, 64],
    definition: {
      stage: 'FOLLOW_UP_GENERATION',
      category: 'ORCHESTRATION',
      code: 'FOLLOW_UP_PROMPT_FAILED',
      message: 'The follow-up question prompt could not be assembled.',
      retryable: true,
    },
  },
  {
    name: 'Follow-up Generation Failure',
    id: 'ec64f6ce-02b9-45a4-974e-19f3e9cd7118',
    position: [3872, 64],
    definition: {
      stage: 'FOLLOW_UP_GENERATION',
      category: 'PROVIDER',
      code: 'FOLLOW_UP_QUESTION_GENERATION_FAILED',
      message: 'Follow-up question generation failed; provider payload omitted.',
      retryable: true,
    },
  },
  {
    name: 'Follow-up Validation Failure',
    id: '64cb60a0-911d-4e1c-86ca-314a05a37119',
    position: [4320, 64],
    definition: {
      stage: 'FOLLOW_UP_GENERATION',
      category: 'PROVIDER',
      code: 'FOLLOW_UP_QUESTION_RESPONSE_INVALID',
      message: 'Generated follow-up questions did not satisfy the required schema.',
      retryable: true,
    },
  },
  {
    name: 'Follow-up Question Persistence Failure',
    id: 'a48bdbca-a3f7-46ce-ab29-5b15d3927120',
    position: [4656, 64],
    definition: {
      stage: '',
      category: 'PERSISTENCE',
      code: 'FOLLOW_UP_QUESTION_SET_PERSISTENCE_FAILED',
      message: 'The follow-up question set could not be persisted.',
      retryable: true,
    },
  },
  {
    name: 'Follow-up Answer Validation Failure',
    id: '4f38c9bc-4208-4696-8a30-741691f47121',
    position: [5216, 64],
    definition: {
      stage: 'FOLLOW_UP',
      category: 'VALIDATION',
      code: 'FOLLOW_UP_ANSWER_VALIDATION_FAILED',
      message: 'The follow-up interview answers are invalid.',
      retryable: true,
    },
  },
  {
    name: 'Follow-up Answer Persistence Failure',
    id: '9ae6df5b-886e-49c1-b0dd-273fac207122',
    position: [5552, 64],
    definition: {
      stage: '',
      category: 'PERSISTENCE',
      code: 'FOLLOW_UP_ANSWER_PERSISTENCE_FAILED',
      message: 'The follow-up interview answers could not be persisted.',
      retryable: true,
    },
  },
  {
    name: 'Answer Scoring Prompt Failure',
    id: '6d168f26-c595-4c76-9b57-1976a8b17123',
    position: [5888, 64],
    definition: {
      stage: 'ANSWER_EVALUATION',
      category: 'ORCHESTRATION',
      code: 'ANSWER_SCORING_PROMPT_FAILED',
      message: 'The answer-scoring prompt could not be assembled.',
      retryable: true,
    },
  },
  {
    name: 'Answer Scoring Failure',
    id: '6589c86b-0350-44a4-a03c-4c60bec87124',
    position: [6112, 64],
    definition: {
      stage: 'ANSWER_EVALUATION',
      category: 'PROVIDER',
      code: 'INTERVIEW_ANSWER_SCORING_FAILED',
      message: 'Interview answer scoring failed; provider payload omitted.',
      retryable: true,
    },
  },
  {
    name: 'Answer Score Validation Failure',
    id: '3fb0f7c0-a247-4b97-b12e-61c071367125',
    position: [6336, 64],
    definition: {
      stage: 'ANSWER_EVALUATION',
      category: 'PROVIDER',
      code: 'INTERVIEW_ANSWER_SCORING_RESPONSE_INVALID',
      message: 'Answer scoring did not satisfy the required schema.',
      retryable: true,
    },
  },
  {
    name: 'Answer Evaluation Persistence Failure',
    id: '776fb70f-ab1c-4f83-8b41-ffea7d067126',
    position: [6672, 64],
    definition: {
      stage: '',
      category: 'PERSISTENCE',
      code: 'ANSWER_EVALUATION_PERSISTENCE_FAILED',
      message: 'Interview answer evaluations could not be persisted.',
      retryable: true,
    },
  },
  {
    name: 'Final Grade Failure',
    id: '9ea8132d-a93a-4414-b293-d99cb4997127',
    position: [7008, 64],
    definition: {
      stage: 'RESULT_PERSISTENCE',
      category: 'ORCHESTRATION',
      code: 'FINAL_GRADE_CALCULATION_FAILED',
      message: 'The final technical grade could not be calculated.',
      retryable: true,
    },
  },
  {
    name: 'Interview Completion Failure',
    id: 'b0126c3f-332a-4437-ad5b-e50bbc507128',
    position: [7344, 64],
    definition: {
      stage: '',
      category: 'PERSISTENCE',
      code: 'TECHNICAL_INTERVIEW_COMPLETION_FAILED',
      message: 'The final technical interview result could not be persisted.',
      retryable: true,
    },
  },
  {
    name: 'Checkpoint Load Failure',
    id: '1831c7b7-204a-4e67-83bd-62abb5ea1211',
    position: [1856, -928],
    definition: {
      stage: '',
      category: 'PERSISTENCE',
      code: 'INTERVIEW_CHECKPOINT_LOAD_FAILED',
      message: 'The technical interview checkpoint could not be loaded.',
      retryable: true,
    },
  },
  {
    name: 'Checkpoint Reconstruction Failure',
    id: '1f3d6ca2-33e9-4b04-91af-371a343d1212',
    position: [2080, -928],
    definition: {
      stage: '',
      category: 'PERSISTENCE',
      code: 'INTERVIEW_CHECKPOINT_INVALID',
      message: 'The persisted technical interview checkpoint is incomplete.',
      retryable: false,
    },
  },
  {
    name: 'Checkpoint Route Failure',
    id: 'ee868f22-fdf7-4a02-8c8d-43c2a7ce1213',
    position: [3424, -704],
    definition: {
      stage: '',
      category: 'ORCHESTRATION',
      code: 'INTERVIEW_CHECKPOINT_STAGE_UNSUPPORTED',
      message: 'The persisted interview stage cannot be resumed.',
      retryable: false,
    },
  },
  {
    name: 'First Question Checkpoint Failure',
    id: '5b083dd3-e481-4b4d-9d0f-572ca5a61214',
    position: [2640, 176],
    definition: {
      stage: 'FIRST_ROUND',
      category: 'PERSISTENCE',
      code: 'FIRST_QUESTION_CHECKPOINT_INVALID',
      message: 'The persisted first-round question checkpoint is incomplete.',
      retryable: false,
    },
  },
  {
    name: 'First Answer Checkpoint Failure',
    id: 'e3dcf62e-c93f-4ad2-b52b-75acfd201215',
    position: [3424, 176],
    definition: {
      stage: 'FOLLOW_UP_GENERATION',
      category: 'PERSISTENCE',
      code: 'FIRST_ANSWER_CHECKPOINT_INVALID',
      message: 'The persisted first-round answer checkpoint is incomplete.',
      retryable: false,
    },
  },
  {
    name: 'Follow-up Question Checkpoint Failure',
    id: '978e81cb-e17d-4108-9b84-a2a34be11216',
    position: [4880, 176],
    definition: {
      stage: 'FOLLOW_UP',
      category: 'PERSISTENCE',
      code: 'FOLLOW_UP_QUESTION_CHECKPOINT_INVALID',
      message: 'The persisted follow-up question checkpoint is incomplete.',
      retryable: false,
    },
  },
  {
    name: 'Follow-up Answer Checkpoint Failure',
    id: 'c92ee639-ac13-4e7b-b33c-789d67f71217',
    position: [5664, 176],
    definition: {
      stage: 'ANSWER_EVALUATION',
      category: 'PERSISTENCE',
      code: 'FOLLOW_UP_ANSWER_CHECKPOINT_INVALID',
      message: 'The persisted follow-up answer checkpoint is incomplete.',
      retryable: false,
    },
  },
  {
    name: 'Answer Evaluation Checkpoint Failure',
    id: '393854c7-60a9-43d4-8270-8396fd321218',
    position: [6784, 176],
    definition: {
      stage: 'RESULT_PERSISTENCE',
      category: 'PERSISTENCE',
      code: 'ANSWER_EVALUATION_CHECKPOINT_INVALID',
      message: 'The persisted answer-evaluation checkpoint is incomplete.',
      retryable: false,
    },
  },
];

for (const failure of interviewFailures) {
  upsertNode(failureNode(failure));
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

const normalizeFirstAnswers = requireNode('Normalize Interview Answers');
normalizeFirstAnswers.parameters.jsCode =
  normalizeFirstAnswers.parameters.jsCode.replace(
    "$('Validate Interview Questions').first().json",
    "$('Prepare First Interview Form').first().json"
  );

const normalizeFollowUpAnswers = requireNode('Normalize Follow-up Answers');
normalizeFollowUpAnswers.parameters.jsCode =
  normalizeFollowUpAnswers.parameters.jsCode.replace(
    "$('Validate Follow-up Questions').first().json",
    "$('Prepare Follow-up Interview Form').first().json"
  );

const answerScoringPrompt = requireNode('Build Answer Scoring Prompt');
answerScoringPrompt.parameters.jsCode =
  answerScoringPrompt.parameters.jsCode.replace(
    "const roundOneRecords =\n  $('Normalize Interview Answers').first().json.answerRecords;",
    "const roundOneRecords = Array.isArray(\n  roundTwoContext.firstRoundAnswerRecords\n)\n  ? roundTwoContext.firstRoundAnswerRecords\n  : $('Restore First Round Answers').first().json.answerRecords;"
  );

const positions = new Map([
  ['Build Interview Question Prompt', [1856, -320]],
  ['Generate Interview Questions', [2080, -320]],
  ['GapGPT Interview Question Model', [2080, -88]],
  ['Interview Question Output Parser', [2080, -552]],
  ['Validate Interview Questions', [2304, -320]],
  ['Persist First Question Set', [2528, -320]],
  ['Restore First Question Form', [2752, -320]],
  ['Prepare First Interview Form', [2976, -320]],
  ['Candidate Interview Form', [3200, -320]],
  ['Normalize Interview Answers', [3424, -320]],
  ['Persist First Round Answers', [3648, -320]],
  ['Restore First Round Answers', [3872, -320]],
  ['Build Follow-up Question Prompt', [4096, -320]],
  ['Generate Follow-up Questions', [4320, -320]],
  ['GapGPT Follow-up Question Model', [4320, -88]],
  ['Follow-up Question Output Parser', [4320, -552]],
  ['Validate Follow-up Questions', [4544, -320]],
  ['Persist Follow-up Question Set', [4768, -320]],
  ['Restore Follow-up Question Form', [4992, -320]],
  ['Prepare Follow-up Interview Form', [5216, -320]],
  ['Follow-up Interview Form', [5440, -320]],
  ['Normalize Follow-up Answers', [5664, -320]],
  ['Persist Follow-up Answers', [5888, -320]],
  ['Restore Follow-up Answers', [6112, -320]],
  ['Build Answer Scoring Prompt', [6336, -320]],
  ['Score Interview Answers', [6560, -320]],
  ['GapGPT Answer Scoring Model', [6560, -88]],
  ['Answer Score Output Parser', [6560, -552]],
  ['Validate Answer Scores', [6784, -320]],
  ['Apply Answer Evaluations', [7008, -320]],
  ['Restore Validated Answer Scores', [7232, -320]],
  ['Calculate Final Grade', [7456, -320]],
  ['Complete Technical Interview', [7680, -320]],
  ['Build Persisted Interview Result', [7904, -320]],
  ['Build Final Grade Summary', [8128, -320]],
  ['Show Final Grade', [8352, -320]],
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
    [mainConnection('Phase 3 Resolution Failure')],
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
    [mainConnection('Build Rejected Technical Interview Result')],
  ],
};
workflow.connections['Load Completed Technical Interview'] = {
  main: [[mainConnection('Build Persisted Interview Result')]],
};
workflow.connections['Interview Configuration'] = {
  main: [[mainConnection('Fresh Interview Attempt?')]],
};
workflow.connections['Fresh Interview Attempt?'] = {
  main: [
    [mainConnection('Build Interview Question Prompt')],
    [mainConnection('Load Technical Interview Checkpoint')],
  ],
};
workflow.connections['Load Technical Interview Checkpoint'] = {
  main: [[mainConnection('Build Technical Interview Checkpoint')]],
};
workflow.connections['Build Technical Interview Checkpoint'] = {
  main: [[mainConnection('Resume First Round?')]],
};
workflow.connections['Resume First Round?'] = {
  main: [
    [mainConnection('Prepare First Interview Form')],
    [mainConnection('Resume Follow-up Generation?')],
  ],
};
workflow.connections['Resume Follow-up Generation?'] = {
  main: [
    [mainConnection('Build Follow-up Question Prompt')],
    [mainConnection('Resume Follow-up?')],
  ],
};
workflow.connections['Resume Follow-up?'] = {
  main: [
    [mainConnection('Prepare Follow-up Interview Form')],
    [mainConnection('Resume Answer Evaluation?')],
  ],
};
workflow.connections['Resume Answer Evaluation?'] = {
  main: [
    [mainConnection('Build Answer Scoring Prompt')],
    [mainConnection('Resume Result Persistence?')],
  ],
};
workflow.connections['Resume Result Persistence?'] = {
  main: [
    [mainConnection('Calculate Final Grade')],
    [mainConnection('Checkpoint Route Failure')],
  ],
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
  main: [[mainConnection('Prepare First Interview Form')]],
};
workflow.connections['Prepare First Interview Form'] = {
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
  main: [[mainConnection('Prepare Follow-up Interview Form')]],
};
workflow.connections['Prepare Follow-up Interview Form'] = {
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

const connectWithFailure = (source, success, failure) => {
  enableErrorOutput(requireNode(source));
  workflow.connections[source] = {
    main: [
      [mainConnection(success)],
      [mainConnection(failure)],
    ],
  };
};

connectWithFailure(
  'Validate Demo Interview Request',
  'Load Completed Phase 3 Assessment',
  'Demo Request Failure'
);
connectWithFailure(
  'Load Completed Phase 3 Assessment',
  'Interview Context Resolved?',
  'Phase 3 Lookup Failure'
);
connectWithFailure(
  'Build Demo Phase 3 Handoff',
  'Validate Phase 3 Handoff',
  'Demo Handoff Assembly Failure'
);
connectWithFailure(
  'Validate Phase 3 Handoff',
  'Claim Technical Interview Session',
  'Phase 3 Contract Failure'
);
connectWithFailure(
  'Claim Technical Interview Session',
  'Interview Claim Can Continue?',
  'Interview Claim Failure'
);
connectWithFailure(
  'Interview Configuration',
  'Fresh Interview Attempt?',
  'Interview Configuration Failure'
);
connectWithFailure(
  'Load Technical Interview Checkpoint',
  'Build Technical Interview Checkpoint',
  'Checkpoint Load Failure'
);
connectWithFailure(
  'Build Technical Interview Checkpoint',
  'Resume First Round?',
  'Checkpoint Reconstruction Failure'
);
connectWithFailure(
  'Build Interview Question Prompt',
  'Generate Interview Questions',
  'Question Prompt Failure'
);
connectWithFailure(
  'Generate Interview Questions',
  'Validate Interview Questions',
  'Question Generation Failure'
);
connectWithFailure(
  'Validate Interview Questions',
  'Persist First Question Set',
  'Question Validation Failure'
);
connectWithFailure(
  'Persist First Question Set',
  'Restore First Question Form',
  'First Question Persistence Failure'
);
connectWithFailure(
  'Restore First Question Form',
  'Prepare First Interview Form',
  'First Question Checkpoint Failure'
);
connectWithFailure(
  'Prepare First Interview Form',
  'Candidate Interview Form',
  'First Question Checkpoint Failure'
);
connectWithFailure(
  'Normalize Interview Answers',
  'Persist First Round Answers',
  'First Answer Validation Failure'
);
connectWithFailure(
  'Persist First Round Answers',
  'Restore First Round Answers',
  'First Answer Persistence Failure'
);
connectWithFailure(
  'Restore First Round Answers',
  'Build Follow-up Question Prompt',
  'First Answer Checkpoint Failure'
);
connectWithFailure(
  'Build Follow-up Question Prompt',
  'Generate Follow-up Questions',
  'Follow-up Prompt Failure'
);
connectWithFailure(
  'Generate Follow-up Questions',
  'Validate Follow-up Questions',
  'Follow-up Generation Failure'
);
connectWithFailure(
  'Validate Follow-up Questions',
  'Persist Follow-up Question Set',
  'Follow-up Validation Failure'
);
connectWithFailure(
  'Persist Follow-up Question Set',
  'Restore Follow-up Question Form',
  'Follow-up Question Persistence Failure'
);
connectWithFailure(
  'Restore Follow-up Question Form',
  'Prepare Follow-up Interview Form',
  'Follow-up Question Checkpoint Failure'
);
connectWithFailure(
  'Prepare Follow-up Interview Form',
  'Follow-up Interview Form',
  'Follow-up Question Checkpoint Failure'
);
connectWithFailure(
  'Normalize Follow-up Answers',
  'Persist Follow-up Answers',
  'Follow-up Answer Validation Failure'
);
connectWithFailure(
  'Persist Follow-up Answers',
  'Restore Follow-up Answers',
  'Follow-up Answer Persistence Failure'
);
connectWithFailure(
  'Restore Follow-up Answers',
  'Build Answer Scoring Prompt',
  'Follow-up Answer Checkpoint Failure'
);
connectWithFailure(
  'Build Answer Scoring Prompt',
  'Score Interview Answers',
  'Answer Scoring Prompt Failure'
);
connectWithFailure(
  'Score Interview Answers',
  'Validate Answer Scores',
  'Answer Scoring Failure'
);
connectWithFailure(
  'Validate Answer Scores',
  'Apply Answer Evaluations',
  'Answer Score Validation Failure'
);
connectWithFailure(
  'Apply Answer Evaluations',
  'Restore Validated Answer Scores',
  'Answer Evaluation Persistence Failure'
);
connectWithFailure(
  'Restore Validated Answer Scores',
  'Calculate Final Grade',
  'Answer Evaluation Checkpoint Failure'
);
connectWithFailure(
  'Calculate Final Grade',
  'Complete Technical Interview',
  'Final Grade Failure'
);
connectWithFailure(
  'Complete Technical Interview',
  'Build Persisted Interview Result',
  'Interview Completion Failure'
);

for (const providerNode of [
  'Generate Interview Questions',
  'Generate Follow-up Questions',
  'Score Interview Answers',
]) {
  const node = requireNode(providerNode);
  node.retryOnFail = true;
  node.maxTries = 3;
  node.waitBetweenTries = 2000;
}

for (const failure of unclaimedFailures) {
  workflow.connections[failure.name] = {
    main: [[mainConnection('Build Unrecorded Technical Interview Result')]],
  };
}
workflow.connections['Phase 3 Resolution Failure'] = {
  main: [[mainConnection('Build Unrecorded Technical Interview Result')]],
};

for (const failure of interviewFailures) {
  workflow.connections[failure.name] = {
    main: [[mainConnection('Record Technical Interview Failure')]],
  };
}
workflow.connections['Record Technical Interview Failure'] = {
  main: [
    [mainConnection('Build Failed Technical Interview Result')],
    [mainConnection('Build Interview Failure Recording Fallback')],
  ],
};

writeFileSync(
  workflowPath,
  `${JSON.stringify(workflow, null, 2)}\n`,
  'utf8'
);
