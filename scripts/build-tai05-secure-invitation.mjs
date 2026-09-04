#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, '..');
const outputPath = process.argv[2] ?? resolve(
  repositoryRoot,
  'workflows/phase-4-5/TAI-05-secure-interview-invitation-v1.json'
);

const read = (relativePath) =>
  readFileSync(resolve(repositoryRoot, relativePath), 'utf8');

const code = (name) =>
  read(`workflows/phase-4-5/code/${name}.js`).trimEnd();

const sql = (name) =>
  read(`workflows/phase-4-5/sql/${name}.sql`);

const query = (name) =>
  read(`database/queries/${name}.sql`);

const main = (node) => ({ node, type: 'main', index: 0 });

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

const codeNode = (name, id, position, sourceName) => ({
  parameters: { jsCode: code(sourceName) },
  type: 'n8n-nodes-base.code',
  typeVersion: 2,
  position,
  id,
  name,
  onError: 'continueErrorOutput',
});

const postgresNode = (
  name,
  id,
  position,
  statement,
  queryReplacement
) => ({
  parameters: {
    operation: 'executeQuery',
    query: statement,
    options: { queryReplacement },
  },
  type: 'n8n-nodes-base.postgres',
  typeVersion: 2.7,
  position,
  id,
  name,
  onError: 'continueErrorOutput',
});

const nodes = [
  {
    parameters: {
      authentication: 'n8nUserAuth',
      requireExecuteAccess: true,
      formTitle: 'مدیریت دعوت امن مصاحبه TalentAI',
      formDescription:
        'این فرم فقط برای HR و کاربران مجاز است. برای ISSUE، Extraction ID و مدت اعتبار را وارد کنید. برای REVOKE، Invitation ID را وارد کنید.',
      formFields: {
        values: [
          {
            fieldLabel: 'عملیات',
            fieldName: 'action',
            fieldType: 'dropdown',
            fieldOptions: {
              values: [
                { option: 'ISSUE' },
                { option: 'REVOKE' },
              ],
            },
            defaultValue: 'ISSUE',
            requiredField: true,
          },
          {
            fieldLabel: 'Extraction ID — فقط برای ISSUE',
            fieldName: 'extractionId',
            fieldType: 'text',
            placeholder: 'UUID ارزیابی تکمیل‌شده',
            requiredField: false,
          },
          {
            fieldLabel: 'Invitation ID — فقط برای REVOKE',
            fieldName: 'invitationId',
            fieldType: 'text',
            placeholder: 'UUID دعوت فعال',
            requiredField: false,
          },
          {
            fieldLabel: 'مدت اعتبار دعوت — دقیقه',
            fieldName: 'ttlMinutes',
            fieldType: 'dropdown',
            fieldOptions: {
              values: [
                { option: '1440' },
                { option: '2880' },
                { option: '4320' },
                { option: '10080' },
              ],
            },
            defaultValue: '2880',
            requiredField: true,
          },
        ],
      },
      responseMode: 'lastNode',
      options: {
        path: 'talentai-secure-interview-invitation',
        buttonLabel: 'اجرای عملیات امن',
        ignoreBots: true,
        showHeaders: false,
      },
    },
    type: 'n8n-nodes-base.formTrigger',
    typeVersion: 2.6,
    position: [-1120, -160],
    id: 'bc316b39-c02a-492f-8138-d47500115101',
    name: 'On authorized invitation operation',
    webhookId: '253ea553-f07c-4b3e-b519-a76f77015102',
  },
  codeNode(
    'Validate Invitation Operation',
    '9a916d36-d1af-49d4-9819-8d77fe4e5103',
    [-896, -160],
    'tai05-validate-invitation-operation'
  ),
  ifNode(
    'Issue Invitation?',
    'b7d66991-fae7-4b76-92e9-8f8da57f5104',
    [-672, -160],
    "={{ String($json.action ?? '') === 'ISSUE' }}"
  ),
  postgresNode(
    'Load Completed Phase 3 For Invitation',
    'a82044c6-e925-4b6a-a173-f2e407c85105',
    [-448, -320],
    sql('load-completed-phase3-handoff-by-extraction'),
    "={{ [$('Validate Invitation Operation').first().json.extractionId] }}"
  ),
  ifNode(
    'Invitation Context Resolved?',
    'c070b232-9b2a-46c5-b847-6b2a4e985106',
    [-224, -320],
    "={{ String($json.resolutionStatus ?? '') === 'RESOLVED' }}"
  ),
  codeNode(
    'Build Phase 3 Invitation Handoff',
    '2703902e-652a-48e6-b5d1-f3c2104d5107',
    [0, -320],
    'build-phase3-handoff-from-query'
  ),
  codeNode(
    'Validate Phase 3 Invitation Handoff',
    'b1b8dfb0-d023-4a49-87be-9cd7eec95108',
    [224, -320],
    'tai04-validate-phase3-handoff'
  ),
  postgresNode(
    'Issue Secure Interview Invitation',
    '0f0d84e4-dfc6-483b-85ba-334f1f6f5109',
    [448, -320],
    query('Q022__issue_technical_interview_invitation'),
    "={{ [$json.correlation.contractVersion, $json.correlation.requestId, $json.correlation.assessmentId, $json.correlation.extractionId, String($execution.id), $('Validate Invitation Operation').first().json.ttlMinutes] }}"
  ),
  ifNode(
    'Invitation Issued?',
    'cfbd0846-e13c-438a-a92b-2f8569995110',
    [672, -320],
    '={{ $json.canDeliver === true }}'
  ),
  codeNode(
    'Build Secure Invitation Result',
    'c254d111-f168-4c7c-81d9-caf2d1c75111',
    [896, -384],
    'tai05-build-invitation-result'
  ),
  postgresNode(
    'Revoke Secure Interview Invitation',
    'b18ee6d5-47cd-4d4a-b859-b44e1de95112',
    [-448, 0],
    query('Q024__revoke_technical_interview_invitation'),
    "={{ [$('Validate Invitation Operation').first().json.invitationId, String($execution.id)] }}"
  ),
  ifNode(
    'Invitation Revoked?',
    'c7d34cf6-a155-4578-ad57-a44099e55113',
    [-224, 0],
    "={{ ['REVOKED_NOW', 'ALREADY_REVOKED'].includes(String($json.revokeStatus ?? '')) }}"
  ),
  codeNode(
    'Build Secure Revocation Result',
    '43ab4b11-d35f-4d2c-bdc4-ea9353565114',
    [0, 0],
    'tai05-build-revocation-result'
  ),
  {
    parameters: {
      jsCode: code('tai05-build-operation-failure'),
    },
    type: 'n8n-nodes-base.code',
    typeVersion: 2,
    position: [896, 0],
    id: 'ed1c148b-f67c-4d1e-a174-6e6d8db85115',
    name: 'Build Secure Invitation Failure',
  },
  {
    parameters: {
      operation: 'completion',
      completionTitle: 'عملیات دعوت امن TalentAI تکمیل شد',
      completionMessage: '={{ $json.output }}',
      options: {},
    },
    type: 'n8n-nodes-base.form',
    typeVersion: 2.5,
    position: [1120, -384],
    id: '46e81c99-c1b9-468d-a2d3-aec5764d5116',
    name: 'Show Secure Invitation Result',
    webhookId: '42bfde76-b22a-4b80-a678-2c7b43225117',
  },
  {
    parameters: {
      operation: 'completion',
      completionTitle: 'عملیات دعوت امن TalentAI تکمیل نشد',
      completionMessage: '={{ $json.output }}',
      options: {},
    },
    type: 'n8n-nodes-base.form',
    typeVersion: 2.5,
    position: [1120, 0],
    id: '5a1dc1d7-1c68-4ed1-a027-35a8435f5118',
    name: 'Show Secure Invitation Failure',
    webhookId: '929a39e6-cf59-44d2-81a0-7817f0875119',
  },
];

const connections = {
  'On authorized invitation operation': {
    main: [[main('Validate Invitation Operation')]],
  },
  'Validate Invitation Operation': {
    main: [
      [main('Issue Invitation?')],
      [main('Build Secure Invitation Failure')],
    ],
  },
  'Issue Invitation?': {
    main: [
      [main('Load Completed Phase 3 For Invitation')],
      [main('Revoke Secure Interview Invitation')],
    ],
  },
  'Load Completed Phase 3 For Invitation': {
    main: [
      [main('Invitation Context Resolved?')],
      [main('Build Secure Invitation Failure')],
    ],
  },
  'Invitation Context Resolved?': {
    main: [
      [main('Build Phase 3 Invitation Handoff')],
      [main('Build Secure Invitation Failure')],
    ],
  },
  'Build Phase 3 Invitation Handoff': {
    main: [
      [main('Validate Phase 3 Invitation Handoff')],
      [main('Build Secure Invitation Failure')],
    ],
  },
  'Validate Phase 3 Invitation Handoff': {
    main: [
      [main('Issue Secure Interview Invitation')],
      [main('Build Secure Invitation Failure')],
    ],
  },
  'Issue Secure Interview Invitation': {
    main: [
      [main('Invitation Issued?')],
      [main('Build Secure Invitation Failure')],
    ],
  },
  'Invitation Issued?': {
    main: [
      [main('Build Secure Invitation Result')],
      [main('Build Secure Invitation Failure')],
    ],
  },
  'Build Secure Invitation Result': {
    main: [
      [main('Show Secure Invitation Result')],
      [main('Build Secure Invitation Failure')],
    ],
  },
  'Revoke Secure Interview Invitation': {
    main: [
      [main('Invitation Revoked?')],
      [main('Build Secure Invitation Failure')],
    ],
  },
  'Invitation Revoked?': {
    main: [
      [main('Build Secure Revocation Result')],
      [main('Build Secure Invitation Failure')],
    ],
  },
  'Build Secure Revocation Result': {
    main: [
      [main('Show Secure Invitation Result')],
      [main('Build Secure Invitation Failure')],
    ],
  },
  'Build Secure Invitation Failure': {
    main: [[main('Show Secure Invitation Failure')]],
  },
};

const workflow = {
  id: 'L8uQ5xN2pR7sV4wZ',
  name: 'TAI-05 Secure Interview Invitation v1',
  active: false,
  isArchived: false,
  isPublished: false,
  nodes,
  connections,
  settings: {
    executionOrder: 'v1',
    binaryMode: 'separate',
    saveDataErrorExecution: 'none',
    saveDataSuccessExecution: 'none',
    saveManualExecutions: false,
    saveExecutionProgress: false,
    executionTimeout: 60,
    redactionPolicy: 'all',
  },
};

writeFileSync(outputPath, `${JSON.stringify(workflow, null, 2)}\n`, 'utf8');
