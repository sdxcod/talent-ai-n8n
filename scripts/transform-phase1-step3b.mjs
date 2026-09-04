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

const formCss = readRepositoryFile(
  'workflows/shared/talentai-form-rtl.css'
).trim();

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

const failureCode = (source, definition) =>
  `const failureDefinition = ${JSON.stringify(definition, null, 2)};\n${code(source)}`;

const enableErrorOutput = (node) => {
  node.onError = 'continueErrorOutput';
};

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

const completionFormNode = (
  name,
  id,
  webhookId,
  position,
  completionTitle,
) => ({
  parameters: {
    operation: 'completion',
    completionTitle,
    completionMessage: '={{ $json.output }}',
    options: { customCss: formCss },
  },
  type: 'n8n-nodes-base.form',
  typeVersion: 2.5,
  position,
  id,
  name,
  webhookId,
});

const mainConnection = (node, index = 0) => ({
  node,
  type: 'main',
  index,
});

const transformTai01 = () => {
  workflow.settings = {
    ...(workflow.settings ?? {}),
    executionTimeout: 300,
  };

  const form = updateNode('On form submission', (node) => {
    node.parameters.authentication = 'n8nUserAuth';
    node.parameters.requireExecuteAccess = true;
    node.parameters.formTitle = 'ارزیابی داخلی رزومه TalentAI';
    node.parameters.formDescription =
      'این فرم فقط برای HR و کاربران مجاز است. نتیجه ارزیابی و امکان صدور دعوت امن پس از تکمیل پردازش نمایش داده می‌شود.';
    node.parameters.options = {
      ...(node.parameters.options ?? {}),
      path: 'talentai-hr-resume-assessment',
      buttonLabel: 'ارزیابی رزومه',
      ignoreBots: true,
      includeUserInOutput: false,
      showHeaders: false,
      customCss: formCss,
    };

    const fields = node.parameters.formFields.values;
    const requestIdField = fields.find(
      (field) => field.fieldName === 'requestId'
    );

    if (!requestIdField) {
      fields.unshift({
        fieldLabel: 'شناسه درخواست (اختیاری برای تکرار امن)',
        fieldType: 'text',
        fieldName: 'requestId',
        placeholder: 'UUID دریافتی از اجرای قبلی',
        requiredField: false,
      });
    } else {
      Object.assign(requestIdField, {
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
    enableErrorOutput(node);
  });

  updateNode('Extract from File', (node) => {
    node.position = [-960, 464];
    enableErrorOutput(node);
  });

  updateNode('Extract Structured Candidate Profile', (node) => {
    node.parameters.text =
      "={{ $('Extract from File').first().json.text }}";
    node.position = [32, 224];
    enableErrorOutput(node);
    node.retryOnFail = true;
    node.maxTries = 3;
    node.waitBetweenTries = 2000;
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
    enableErrorOutput(node);
    node.position = [256, 224];
  });

  updateNode('Save Resume Extraction', (node) => {
    node.position = [480, 224];
    enableErrorOutput(node);
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
    enableErrorOutput(node);
  });

  updateNode('Run Deterministic Grade Engine', (node) => {
    node.position = [1600, 224];
    enableErrorOutput(node);
  });

  updateNode('Build TalentAI Assessment Result', (node) => {
    node.parameters.jsCode = code('tai01-build-assessment-result');
    node.position = [1824, 224];
    enableErrorOutput(node);
  });

  removeNode('Alert message');

  upsertNode(codeNode(
    'Build Assessment Claim',
    'a018080b-0760-47b6-90f5-a14a28294011',
    [-736, 464],
    code('tai01-build-assessment-claim')
  ));

  const failureRoutes = [
    ['Profile Extraction Failure', '405fa194-2a30-44ce-89f4-b4ef79173901', [256, -144], {
      category: 'PROVIDER', code: 'PROFILE_EXTRACTION_PROVIDER_FAILED',
      message: 'Candidate profile extraction provider failed; private payload omitted.', retryable: true,
    }],
    ['Profile Validation Failure', '4160b2a5-3b41-45df-9a05-c5f08a284012', [480, -144], {
      category: 'VALIDATION', code: 'PROFILE_SCHEMA_VALIDATION_FAILED',
      message: 'Candidate profile did not satisfy the required schema.', retryable: false,
    }],
    ['Extraction Persistence Failure', '4271c3b6-4c52-46e0-ab16-d6019b395123', [704, -144], {
      category: 'PERSISTENCE', code: 'RESUME_EXTRACTION_PERSISTENCE_FAILED',
      message: 'Resume extraction could not be persisted.', retryable: true,
    }],
    ['Extraction Attachment Failure', '4382d4c7-5d63-47f1-bc27-e712ac4a6234', [928, -144], {
      category: 'PERSISTENCE', code: 'RESUME_EXTRACTION_ATTACHMENT_FAILED',
      message: 'Resume extraction could not be attached to the assessment execution.', retryable: true,
    }],
    ['Grade Guide Failure', '4493e5d8-6e74-4802-cd38-f823bd5b7345', [1376, -144], {
      category: 'CONFIGURATION', code: 'GRADE_GUIDE_RESOLUTION_FAILED',
      message: 'The active grade guide could not be resolved.', retryable: false,
    }],
    ['Grade Engine Failure', '45a4f6e9-7f85-4913-de49-a934ce6c8456', [1600, -144], {
      category: 'PROVIDER', code: 'EVIDENCE_SCORING_FAILED',
      message: 'Evidence scoring failed; provider payload omitted.', retryable: true,
    }],
    ['Result Assembly Failure', '46b507fa-8096-4a24-ef5a-ba45df7d9567', [1824, -144], {
      category: 'ORCHESTRATION', code: 'ASSESSMENT_RESULT_ASSEMBLY_FAILED',
      message: 'The final assessment result could not be assembled.', retryable: true,
    }],
  ];

  for (const [name, id, position, definition] of failureRoutes) {
    upsertNode(codeNode(
      name, id, position,
      failureCode('tai01-classify-assessment-failure', definition)
    ));
  }

  upsertNode(codeNode(
    'Intake Validation Failure',
    '47c6180b-91a7-4b35-f06b-cb56e08ea678',
    [-1184, 720],
    failureCode('tai01-classify-unclaimed-failure', {
      category: 'VALIDATION', code: 'ASSESSMENT_INTAKE_VALIDATION_FAILED',
      message: 'Assessment intake did not satisfy the required contract.', retryable: false,
    })
  ));

  upsertNode(codeNode(
    'Resume File Failure',
    '48d7291c-a2b8-4c46-817c-dc67f19fb789',
    [-960, 720],
    failureCode('tai01-classify-unclaimed-failure', {
      category: 'VALIDATION', code: 'RESUME_FILE_EXTRACTION_FAILED',
      message: 'The submitted resume file could not be read.', retryable: false,
    })
  ));

  upsertNode(postgresNode(
    'Record Assessment Failure',
    '49e83a2d-b3c9-4d57-928d-ed7802a0c890',
    [1152, -368],
    query('Q008__fail_assessment_execution'),
    '={{ [$json.requestId, $json.workflowExecutionId, $json.currentStage, $json.failureCategory, $json.failureCode, $json.failureMessage, $json.retryable] }}'
  ));

  upsertNode(postgresNode(
    'Expire Stale Assessment Executions',
    '4e3d8f72-081e-42ac-a7d2-32cd57f51d45',
    [-624, 464],
    query('Q011__expire_stale_assessment_executions'),
    '={{ [360] }}'
  ));
  enableErrorOutput(findNode('Expire Stale Assessment Executions'));

  upsertNode(codeNode(
    'Stale Recovery Failure',
    '4f4e9083-192f-43bd-b8e3-43de68062e56',
    [-624, 720],
    failureCode('tai01-classify-unclaimed-failure', {
      category: 'PERSISTENCE', code: 'STALE_EXECUTION_RECOVERY_FAILED',
      message: 'Stale assessment execution recovery could not be completed.', retryable: true,
    })
  ));
  enableErrorOutput(findNode('Record Assessment Failure'));

  upsertNode(codeNode(
    'Build Failed Assessment Result',
    '4af94b3e-c4da-4e68-a39e-fe8913b1d901',
    [1376, -368],
    code('tai01-build-failed-assessment-result')
  ));
  upsertNode(codeNode(
    'Build Failure Recording Fallback',
    '4b0a5c4f-d5eb-4f79-b4af-0f9a24c2ea12',
    [1376, -240],
    code('tai01-build-failure-recording-fallback')
  ));
  upsertNode(codeNode(
    'Build Unrecorded Failure Result',
    '4c1b6d50-e6fc-408a-85b0-10ab35d3fb23',
    [-736, 720],
    code('tai01-build-unrecorded-failure-result')
  ));
  upsertNode(codeNode(
    'Build Rejected Assessment Result',
    '4d2c7e61-f70d-419b-96c1-21bc46e40c34',
    [256, 816],
    code('tai01-build-rejected-assessment-result')
  ));

  upsertNode(completionFormNode(
    'Show Assessment Result',
    '57a1b2c3-d4e5-4f67-8a90-b1c2d3e4f501',
    '59c3d4e5-f607-4189-ab12-d3e4f5061723',
    [2048, 224],
    'نتیجه ارزیابی رزومه TalentAI'
  ));

  upsertNode(completionFormNode(
    'Show Assessment Failure',
    '58b2c3d4-e5f6-4078-9ab1-c2d3e4f50612',
    '5ad4e5f6-0718-429a-bc23-e4f506172834',
    [1600, -304],
    'ارزیابی رزومه TalentAI تکمیل نشد'
  ));

  upsertNode(postgresNode(
    'Claim Assessment Execution',
    'b07fc30d-1d75-4679-914c-a74e9b4104b0',
    [-512, 464],
    query('Q004__claim_assessment_execution'),
    "={{ [$('Build Assessment Claim').first().json.requestId, $('Build Assessment Claim').first().json.inputFingerprintSource, $('Build Assessment Claim').first().json.workflowExecutionId, $('Build Assessment Claim').first().json.positionCode, $('Build Assessment Claim').first().json.targetGradeCode] }}"
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
  enableErrorOutput(findNode('Attach Resume Extraction'));

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
    'Validate Assessment Intake': { main: [[mainConnection('Extract from File')], [mainConnection('Intake Validation Failure')]] },
    'Extract from File': { main: [[mainConnection('Build Assessment Claim')], [mainConnection('Resume File Failure')]] },
    'Build Assessment Claim': { main: [[mainConnection('Expire Stale Assessment Executions')]] },
    'Expire Stale Assessment Executions': { main: [[mainConnection('Claim Assessment Execution')], [mainConnection('Stale Recovery Failure')]] },
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
      main: [[mainConnection('Validate Candidate Profile')], [mainConnection('Profile Extraction Failure')]],
    },
    'OpenAI Chat Model': {
      ai_languageModel: [[{
        node: 'Extract Structured Candidate Profile',
        type: 'ai_languageModel',
        index: 0,
      }]],
    },
    'Validate Candidate Profile': {
      main: [[mainConnection('Save Resume Extraction')], [mainConnection('Profile Validation Failure')]],
    },
    'Save Resume Extraction': { main: [[mainConnection('Attach Resume Extraction')], [mainConnection('Extraction Persistence Failure')]] },
    'Attach Resume Extraction': { main: [[mainConnection('Prepare Grading Request')], [mainConnection('Extraction Attachment Failure')]] },
    'Prepare Grading Request': { main: [[mainConnection('Resolve Grade Engine Input')]] },
    'Resolve Grade Engine Input': { main: [[mainConnection('Run Deterministic Grade Engine')], [mainConnection('Grade Guide Failure')]] },
    'Run Deterministic Grade Engine': { main: [[mainConnection('Build TalentAI Assessment Result')], [mainConnection('Grade Engine Failure')]] },
    'Build TalentAI Assessment Result': {
      main: [
        [mainConnection('Show Assessment Result')],
        [mainConnection('Result Assembly Failure')],
      ],
    },
    'Completed Replay?': {
      main: [
        [mainConnection('Load Completed Assessment')],
        [mainConnection('Build Rejected Assessment Result')],
      ],
    },
    'Load Completed Assessment': {
      main: [[mainConnection('Build Replayed Assessment Result')]],
    },
    'Build Replayed Assessment Result': {
      main: [[mainConnection('Build TalentAI Assessment Result')]],
    },
    'Intake Validation Failure': { main: [[mainConnection('Build Unrecorded Failure Result')]] },
    'Resume File Failure': { main: [[mainConnection('Build Unrecorded Failure Result')]] },
    'Stale Recovery Failure': { main: [[mainConnection('Build Unrecorded Failure Result')]] },
    'Profile Extraction Failure': { main: [[mainConnection('Record Assessment Failure')]] },
    'Profile Validation Failure': { main: [[mainConnection('Record Assessment Failure')]] },
    'Extraction Persistence Failure': { main: [[mainConnection('Record Assessment Failure')]] },
    'Extraction Attachment Failure': { main: [[mainConnection('Record Assessment Failure')]] },
    'Grade Guide Failure': { main: [[mainConnection('Record Assessment Failure')]] },
    'Grade Engine Failure': { main: [[mainConnection('Record Assessment Failure')]] },
    'Result Assembly Failure': { main: [[mainConnection('Record Assessment Failure')]] },
    'Record Assessment Failure': { main: [[mainConnection('Build Failed Assessment Result')], [mainConnection('Build Failure Recording Fallback')]] },
    'Build Failed Assessment Result': {
      main: [[mainConnection('Show Assessment Failure')]],
    },
    'Build Failure Recording Fallback': {
      main: [[mainConnection('Show Assessment Failure')]],
    },
    'Build Unrecorded Failure Result': {
      main: [[mainConnection('Show Assessment Failure')]],
    },
    'Build Rejected Assessment Result': {
      main: [[mainConnection('Show Assessment Failure')]],
    },
  };
};

const transformTai02 = () => {
  workflow.settings = {
    ...(workflow.settings ?? {}),
    executionTimeout: 60,
  };

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
  workflow.settings = {
    ...(workflow.settings ?? {}),
    executionTimeout: 240,
  };

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
    node.retryOnFail = true;
    node.maxTries = 3;
    node.waitBetweenTries = 2000;
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
