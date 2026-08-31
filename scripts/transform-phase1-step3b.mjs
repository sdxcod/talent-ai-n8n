#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, '..');
const workflowPath = process.argv[2];

if (!workflowPath) {
  throw new Error(
    'Usage: node scripts/transform-phase1-step3b.mjs <workflow.json>'
  );
}

const readRepositoryFile = (relativePath) =>
  readFileSync(resolve(repositoryRoot, relativePath), 'utf8');

const code = (name) =>
  readRepositoryFile(`workflows/phase-1/code/${name}.js`).trimEnd();

const query = (name) =>
  readRepositoryFile(`database/queries/${name}.sql`);

const workflow = JSON.parse(readFileSync(workflowPath, 'utf8'));

const findNode = (name) =>
  workflow.nodes.find((node) => node.name === name);

const inferCredentials = (type) =>
  workflow.nodes.find(
    (node) => node.type === type && node.credentials
  )?.credentials;

const upsertNode = (node) => {
  const index = workflow.nodes.findIndex(
    (candidate) => candidate.name === node.name
  );
  const existing = index >= 0 ? workflow.nodes[index] : undefined;
  const credentials =
    existing?.credentials ?? inferCredentials(node.type);

  if (credentials) {
    node.credentials = credentials;
  }

  if (index >= 0) {
    workflow.nodes[index] = node;
  } else {
    workflow.nodes.push(node);
  }
};

const updateNode = (name, update) => {
  const node = findNode(name);

  if (!node) {
    throw new Error(`${workflow.name}: required node is missing: ${name}`);
  }

  update(node);
  return node;
};

const removeNode = (name) => {
  workflow.nodes = workflow.nodes.filter((node) => node.name !== name);
  delete workflow.connections[name];
};

const postgresNode = (name, id, position, sql, queryReplacement) => ({
  parameters: {
    operation: 'executeQuery',
    query: sql,
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

const codeNode = (name, id, position, jsCode) => ({
  parameters: { jsCode },
  type: 'n8n-nodes-base.code',
  typeVersion: 2,
  position,
  id,
  name,
});

const ifNode = (name, id, position, expression) => ({
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
          leftValue: expression,
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

const stopNode = (name, id, position, errorMessage) => ({
  parameters: { errorMessage },
  type: 'n8n-nodes-base.stopAndError',
  typeVersion: 1,
  position,
  id,
  name,
});

const mainConnection = (node, index = 0) => ({
  node,
  type: 'main',
  index,
});

const transformTai01 = () => {
  const form = updateNode('On form submission', (node) => {
    const fields = node.parameters.formFields.values;

    if (!fields.some((field) => field.fieldName === 'requestId')) {
      fields.unshift({
        fieldLabel: 'شناسه درخواست (اختیاری برای تکرار امن)',
        fieldType: 'text',
        fieldName: 'requestId',
        placeholder: 'UUID دریافتی از اجرای قبلی',
        requiredField: false,
      });
    }

    node.position = [-1408, 464];
  });

  updateNode('Validate Assessment Intake', (node) => {
    node.parameters.jsCode = code('tai01-validate-assessment-intake');
    node.position = [-1184, 464];
  });

  updateNode('Extract from File', (node) => {
    node.position = [-960, 464];
  });

  updateNode('Extract Structured Candidate Profile', (node) => {
    node.parameters.text =
      "={{ $('Extract from File').first().json.text }}";
    node.position = [32, 224];
  });

  updateNode('OpenAI Chat Model', (node) => {
    node.position = [48, 448];
  });

  updateNode('Validate Candidate Profile', (node) => {
    if (!node.parameters.jsCode.includes('const claim =')) {
      node.parameters.jsCode = node.parameters.jsCode.replace(
          "const intake = $('Validate Assessment Intake').first().json;",
          "const intake = $('Validate Assessment Intake').first().json;\nconst claim = $('Claim Assessment Execution').first().json;"
        );
    }

    if (!node.parameters.jsCode.includes('requestId: claim.requestId')) {
      node.parameters.jsCode = node.parameters.jsCode.replace(
          "workflowExecutionId: String($execution.id),\n        sourceFileName:",
          "workflowExecutionId: String($execution.id),\n        requestId: claim.requestId,\n        attemptCount: Number(claim.attemptCount),\n        sourceFileName:"
        );
    }
    delete node.onError;
    node.position = [256, 224];
  });

  updateNode('Save Resume Extraction', (node) => {
    node.position = [480, 224];
  });

  updateNode('Resolve Grade Engine Input', (node) => {
    node.position = [1376, 224];
    node.parameters.workflowInputs = {
      mappingMode: 'defineBelow',
      value: {
        extractionId: '={{ $json.extractionId }}',
        requestId: '={{ $json.requestId }}',
        rootWorkflowExecutionId: '={{ $json.rootWorkflowExecutionId }}',
        attemptCount: '={{ $json.attemptCount }}',
      },
      matchingColumns: [],
      schema: [
        'extractionId',
        'requestId',
        'rootWorkflowExecutionId',
        'attemptCount',
      ].map((name) => ({
        id: name,
        displayName: name,
        required: false,
        defaultMatch: false,
        display: true,
        canBeUsedToMatch: true,
        type: name === 'attemptCount' ? 'number' : 'string',
        removed: false,
      })),
      attemptToConvertTypes: false,
      convertFieldsToString: false,
    };
  });

  updateNode('Run Deterministic Grade Engine', (node) => {
    node.position = [1600, 224];
  });

  updateNode('Build TalentAI Assessment Result', (node) => {
    node.parameters.jsCode = code('tai01-build-assessment-result');
    node.position = [1824, 224];
  });

  removeNode('Alert message');

  upsertNode(codeNode(
    'Build Assessment Claim',
    'a018080b-0760-47b6-90f5-a14a28294011',
    [-736, 464],
    code('tai01-build-assessment-claim')
  ));

  upsertNode(postgresNode(
    'Claim Assessment Execution',
    'b07fc30d-1d75-4679-914c-a74e9b4104b0',
    [-512, 464],
    query('Q004__claim_assessment_execution'),
    '={{ [$json.requestId, $json.inputFingerprintSource, $json.workflowExecutionId, $json.positionCode, $json.targetGradeCode] }}'
  ));

  upsertNode(ifNode(
    'Claim Can Continue?',
    'c7fba835-11bd-4ba4-b0e3-e0184d75b422',
    [-288, 464],
    '={{ $json.canContinue === true }}'
  ));

  upsertNode(ifNode(
    'Retry Has Extraction?',
    'dd9ff0fd-9081-42dd-8eac-3309843a90ac',
    [-64, 320],
    "={{ String($json.extractionId ?? '').trim().length > 0 }}"
  ));

  upsertNode(ifNode(
    'Completed Replay?',
    'ee607d31-dfa5-4cea-90df-33353b57b01f',
    [-64, 672],
    "={{ String($json.claimStatus ?? '') === 'COMPLETED_REPLAY' }}"
  ));

  upsertNode(postgresNode(
    'Attach Resume Extraction',
    'f5083537-ae31-4c1b-b0ed-d8bc453cb2f0',
    [704, 224],
    query('Q006__attach_resume_extraction'),
    "={{ [$('Claim Assessment Execution').first().json.requestId, String($execution.id), $json.id] }}"
  ));

  upsertNode(codeNode(
    'Prepare Grading Request',
    '065d2130-56bd-4887-9be7-88bb3f70700b',
    [1152, 224],
    code('tai01-prepare-grading-request')
  ));

  upsertNode(postgresNode(
    'Load Completed Assessment',
    '17671c80-b752-4c05-91f7-da2cbf2e012e',
    [256, 672],
    query('Q009__load_completed_assessment_execution'),
    '={{ [$json.requestId] }}'
  ));

  upsertNode(codeNode(
    'Build Replayed Assessment Result',
    '2865a4ad-c5c2-4df4-a095-0c949cb864b1',
    [480, 672],
    code('tai01-build-replayed-assessment-result')
  ));

  upsertNode(stopNode(
    'Reject Assessment Claim',
    '394ee083-d23e-417c-99d6-25cb034e9153',
    [256, 816],
    "={{ 'ASSESSMENT_CLAIM_REJECTED: ' + String($json.claimStatus ?? 'UNKNOWN') + ' [requestId=' + String($json.requestId ?? '') + ']' }}"
  ));

  workflow.connections = {
    'On form submission': { main: [[mainConnection('Validate Assessment Intake')]] },
    'Validate Assessment Intake': { main: [[mainConnection('Extract from File')]] },
    'Extract from File': { main: [[mainConnection('Build Assessment Claim')]] },
    'Build Assessment Claim': { main: [[mainConnection('Claim Assessment Execution')]] },
    'Claim Assessment Execution': { main: [[mainConnection('Claim Can Continue?')]] },
    'Claim Can Continue?': {
      main: [
        [mainConnection('Retry Has Extraction?')],
        [mainConnection('Completed Replay?')],
      ],
    },
    'Retry Has Extraction?': {
      main: [
        [mainConnection('Prepare Grading Request')],
        [mainConnection('Extract Structured Candidate Profile')],
      ],
    },
    'Extract Structured Candidate Profile': {
      main: [[mainConnection('Validate Candidate Profile')]],
    },
    'OpenAI Chat Model': {
      ai_languageModel: [[{
        node: 'Extract Structured Candidate Profile',
        type: 'ai_languageModel',
        index: 0,
      }]],
    },
    'Validate Candidate Profile': {
      main: [[mainConnection('Save Resume Extraction')]],
    },
    'Save Resume Extraction': { main: [[mainConnection('Attach Resume Extraction')]] },
    'Attach Resume Extraction': { main: [[mainConnection('Prepare Grading Request')]] },
    'Prepare Grading Request': { main: [[mainConnection('Resolve Grade Engine Input')]] },
    'Resolve Grade Engine Input': { main: [[mainConnection('Run Deterministic Grade Engine')]] },
    'Run Deterministic Grade Engine': { main: [[mainConnection('Build TalentAI Assessment Result')]] },
    'Completed Replay?': {
      main: [
        [mainConnection('Load Completed Assessment')],
        [mainConnection('Reject Assessment Claim')],
      ],
    },
    'Load Completed Assessment': {
      main: [[mainConnection('Build Replayed Assessment Result')]],
    },
    'Build Replayed Assessment Result': {
      main: [[mainConnection('Build TalentAI Assessment Result')]],
    },
  };
};

const transformTai02 = () => {
  updateNode('Grade Guide Resolution Requested', (node) => {
    node.parameters = {
      workflowInputs: {
        values: [
          { name: 'extractionId' },
          { name: 'requestId' },
          { name: 'rootWorkflowExecutionId' },
          { name: 'attemptCount', type: 'number' },
        ],
      },
    };
    node.position = [-688, 64];
  });

  const validationNodeName = findNode('Validate Operational Input')
    ? 'Validate Operational Input'
    : 'Validate Extraction ID';

  updateNode(validationNodeName, (node) => {
    node.name = 'Validate Operational Input';
    node.parameters.jsCode = code('tai02-validate-operational-input');
    node.position = [-464, 64];
  });

  updateNode('Resolve Extraction and Grade Guide', (node) => {
    node.parameters.options.queryReplacement =
      "={{ [$('Validate Operational Input').first().json.extractionId] }}";
    node.position = [-16, 64];
  });

  updateNode('Grade Guide Resolved?', (node) => {
    node.position = [208, 64];
  });

  updateNode('Fail Grade Guide Resolution', (node) => {
    node.position = [432, 160];
    node.parameters.errorMessage =
      "={{ $json.resolutionStatus + ': ' + $json.resolutionMessage + ' [requestId=' + $('Validate Operational Input').first().json.requestId + ', extractionId=' + $json.requestedExtractionId + ']' }}";
  });

  updateNode('Build Grade Engine Input', (node) => {
    if (!node.parameters.jsCode.includes('const operational =')) {
      node.parameters.jsCode = node.parameters.jsCode.replace(
        'const resolved = $input.first().json;',
        "const resolved = $input.first().json;\nconst operational = $('Validate Operational Input').first().json;"
      );
    }

    if (!node.parameters.jsCode.includes('requestId: operational.requestId')) {
      node.parameters.jsCode = node.parameters.jsCode.replace(
        "schemaVersion: '1.0',\n\n      resolution:",
        "schemaVersion: '1.0',\n\n      execution: {\n        requestId: operational.requestId,\n        rootWorkflowExecutionId: operational.rootWorkflowExecutionId,\n        attemptCount: Number(operational.attemptCount),\n      },\n\n      resolution:"
      );
    }
    node.position = [432, -32];
  });

  upsertNode(postgresNode(
    'Advance Grade Guide Resolution',
    '4a8f2a1b-45da-4274-8fb8-769877e3ae80',
    [-240, 64],
    query('Q005__advance_assessment_execution'),
    "={{ [$json.requestId, String($execution.id), 'GRADE_GUIDE_RESOLUTION'] }}"
  ));

  workflow.connections = {
    'Grade Guide Resolution Requested': {
      main: [[mainConnection('Validate Operational Input')]],
    },
    'Validate Operational Input': {
      main: [[mainConnection('Advance Grade Guide Resolution')]],
    },
    'Advance Grade Guide Resolution': {
      main: [[mainConnection('Resolve Extraction and Grade Guide')]],
    },
    'Resolve Extraction and Grade Guide': {
      main: [[mainConnection('Grade Guide Resolved?')]],
    },
    'Grade Guide Resolved?': {
      main: [
        [mainConnection('Build Grade Engine Input')],
        [mainConnection('Fail Grade Guide Resolution')],
      ],
    },
  };
};

const transformTai03 = () => {
  updateNode('Grade Engine Requested', (node) => {
    node.position = [-16, -32];
  });

  updateNode('Validate Grade Engine Input', (node) => {
    node.parameters.jsCode = code('tai03-validate-operational-input');
    node.position = [208, -32];
  });

  updateNode('Build Evidence Scoring Prompt', (node) => {
    node.parameters.jsCode = node.parameters.jsCode.replace(
      'const gradeEngineInput = $input.first().json;',
      "const gradeEngineInput = $('Validate Grade Engine Input').first().json;"
    );
    node.position = [656, -32];
  });

  updateNode('Score Resume Evidence', (node) => {
    node.position = [880, -32];
  });

  updateNode('GapGPT Evidence Scoring Model', (node) => {
    node.position = [896, 208];
  });

  updateNode('Grade Evidence Output Parser', (node) => {
    node.position = [1024, 208];
  });

  updateNode('Validate Dimension Assessments', (node) => {
    node.position = [1104, -32];
  });

  updateNode('Calculate Deterministic Grade', (node) => {
    node.parameters.jsCode = node.parameters.jsCode.replace(
      'const persistenceParameters = [\n  workflowExecutionId,',
      'const persistenceParameters = [\n  gradeEngineInput.execution.requestId,\n  workflowExecutionId,'
    );
    node.position = [1328, -32];
  });

  updateNode('Persist Grade Assessment', (node) => {
    node.parameters.query = query('Q010__persist_operational_grade_assessment');
    node.parameters.options.queryReplacement =
      "={{ $('Calculate Deterministic Grade').first().json.persistenceParameters }}";
    node.position = [1776, -32];
  });

  updateNode('Build Grade Assessment Result', (node) => {
    node.parameters.jsCode = code('tai03-build-assessment-result');
    node.position = [2224, -32];
  });

  upsertNode(postgresNode(
    'Advance Evidence Scoring',
    '5ea80c9d-c375-4a42-9739-42d561874095',
    [432, -32],
    query('Q005__advance_assessment_execution'),
    "={{ [$json.execution.requestId, String($execution.id), 'EVIDENCE_SCORING'] }}"
  ));

  upsertNode(postgresNode(
    'Advance Assessment Persistence',
    '6fa768df-a232-4656-b872-4017c59d7ba9',
    [1552, -32],
    query('Q005__advance_assessment_execution'),
    "={{ [$json.gradeEngineInput.execution.requestId, String($execution.id), 'ASSESSMENT_PERSISTENCE'] }}"
  ));

  upsertNode(postgresNode(
    'Complete Assessment Execution',
    '70edbca8-010d-4f62-bb58-5135c96e9354',
    [2000, -32],
    query('Q007__complete_assessment_execution'),
    "={{ [$json.requestId, String($execution.id), $json.assessmentId] }}"
  ));

  workflow.connections = {
    'Grade Engine Requested': {
      main: [[mainConnection('Validate Grade Engine Input')]],
    },
    'Validate Grade Engine Input': {
      main: [[mainConnection('Advance Evidence Scoring')]],
    },
    'Advance Evidence Scoring': {
      main: [[mainConnection('Build Evidence Scoring Prompt')]],
    },
    'Build Evidence Scoring Prompt': {
      main: [[mainConnection('Score Resume Evidence')]],
    },
    'GapGPT Evidence Scoring Model': {
      ai_languageModel: [[{
        node: 'Score Resume Evidence',
        type: 'ai_languageModel',
        index: 0,
      }]],
    },
    'Grade Evidence Output Parser': {
      ai_outputParser: [[{
        node: 'Score Resume Evidence',
        type: 'ai_outputParser',
        index: 0,
      }]],
    },
    'Score Resume Evidence': {
      main: [[mainConnection('Validate Dimension Assessments')]],
    },
    'Validate Dimension Assessments': {
      main: [[mainConnection('Calculate Deterministic Grade')]],
    },
    'Calculate Deterministic Grade': {
      main: [[mainConnection('Advance Assessment Persistence')]],
    },
    'Advance Assessment Persistence': {
      main: [[mainConnection('Persist Grade Assessment')]],
    },
    'Persist Grade Assessment': {
      main: [[mainConnection('Complete Assessment Execution')]],
    },
    'Complete Assessment Execution': {
      main: [[mainConnection('Build Grade Assessment Result')]],
    },
  };
};

switch (workflow.name) {
  case 'TAI-01 Resume Intake & Extraction v2':
    transformTai01();
    break;
  case 'TAI-02 Grade Guide Resolver v1':
    transformTai02();
    break;
  case 'TAI-03 Evidence Scoring & Deterministic Grade Engine v1':
    transformTai03();
    break;
  default:
    throw new Error(`Unexpected Phase 1 workflow: ${workflow.name}`);
}

writeFileSync(workflowPath, `${JSON.stringify(workflow, null, 2)}\n`);
