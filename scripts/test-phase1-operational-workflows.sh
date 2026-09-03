#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_WORKFLOW_DIR="$TALENTAI_REPOSITORY_ROOT/workflows/phase-1"
readonly TALENTAI_TAI01="$TALENTAI_WORKFLOW_DIR/TAI-01-resume-intake-extraction-v2.json"
readonly TALENTAI_TAI02="$TALENTAI_WORKFLOW_DIR/TAI-02-grade-guide-resolver-v1.json"
readonly TALENTAI_TAI03="$TALENTAI_WORKFLOW_DIR/TAI-03-evidence-scoring-grade-engine-v1.json"

cd "$TALENTAI_REPOSITORY_ROOT"

required_commands=(cmp jq mktemp node)

for required_command in "${required_commands[@]}"; do
  command -v "$required_command" >/dev/null 2>&1 || {
    echo "Required command is missing: $required_command" >&2
    exit 1
  }
done

jq empty "$TALENTAI_TAI01" "$TALENTAI_TAI02" "$TALENTAI_TAI03"

jq -e '
  ([.nodes[].id] | length) == ([.nodes[].id] | unique | length)
  and ([.nodes[].name] | length) == ([.nodes[].name] | unique | length)
  and any(
    .nodes[];
    .name == "On form submission"
    and any(.parameters.formFields.values[]; .fieldName == "requestId")
  )
  and any(.nodes[]; .name == "Claim Assessment Execution")
  and any(.nodes[]; .name == "Claim Can Continue?")
  and any(.nodes[]; .name == "Retry Has Extraction?")
  and any(.nodes[]; .name == "Completed Replay?")
  and any(.nodes[]; .name == "Attach Resume Extraction")
  and any(.nodes[]; .name == "Load Completed Assessment")
  and any(.nodes[]; .name == "Build Replayed Assessment Result")
  and any(.nodes[]; .name == "Reject Assessment Claim")
  and any(.nodes[]; .name == "Record Assessment Failure")
  and any(.nodes[]; .name == "Build Failed Assessment Result")
  and any(.nodes[]; .name == "Build Failure Recording Fallback")
  and any(.nodes[]; .name == "Build Unrecorded Failure Result")
  and any(.nodes[]; .name == "Build Rejected Assessment Result")
  and any(
    .nodes[];
    .name == "Show Assessment Result"
    and .type == "n8n-nodes-base.form"
    and .parameters.operation == "completion"
    and .parameters.completionMessage == "={{ $json.output }}"
  )
  and any(
    .nodes[];
    .name == "Show Assessment Failure"
    and .type == "n8n-nodes-base.form"
    and .parameters.operation == "completion"
    and .parameters.completionMessage == "={{ $json.output }}"
  )
  and any(.nodes[]; .name == "Expire Stale Assessment Executions")
  and any(.nodes[]; .name == "Stale Recovery Failure")
  and (.settings.executionTimeout == 300)
  and any(
    .nodes[];
    .name == "Extract Structured Candidate Profile"
    and .retryOnFail == true
    and .maxTries == 3
    and .waitBetweenTries == 2000
  )
  and any(
    .nodes[];
    .name == "Grade Engine Failure"
    and (.parameters.jsCode | contains("currentStage: ''"))
  )
  and (all(.nodes[]; .name != "Alert message"))
  and (
    .connections["Build Assessment Claim"].main[0][0].node
    == "Expire Stale Assessment Executions"
  )
  and (
    .connections["Expire Stale Assessment Executions"].main[0][0].node
    == "Claim Assessment Execution"
  )
  and (
    .connections["Claim Can Continue?"].main[0][0].node
    == "Retry Has Extraction?"
  )
  and (
    .connections["Claim Can Continue?"].main[1][0].node
    == "Completed Replay?"
  )
  and (
    .connections["Retry Has Extraction?"].main[0][0].node
    == "Prepare Grading Request"
  )
  and (
    .connections["Retry Has Extraction?"].main[1][0].node
    == "Extract Structured Candidate Profile"
  )
  and (
    .connections["Build Replayed Assessment Result"].main[0][0].node
    == "Build TalentAI Assessment Result"
  )
  and (
    .connections["Build TalentAI Assessment Result"].main[0][0].node
    == "Show Assessment Result"
  )
  and (
    .connections["Extract Structured Candidate Profile"].main[1][0].node
    == "Profile Extraction Failure"
  )
  and (
    .connections["Run Deterministic Grade Engine"].main[1][0].node
    == "Grade Engine Failure"
  )
  and (
    .connections["Record Assessment Failure"].main[0][0].node
    == "Build Failed Assessment Result"
  )
  and (
    .connections["Record Assessment Failure"].main[1][0].node
    == "Build Failure Recording Fallback"
  )
  and (
    .connections["Build Failed Assessment Result"].main[0][0].node
    == "Show Assessment Failure"
  )
  and (
    .connections["Build Failure Recording Fallback"].main[0][0].node
    == "Show Assessment Failure"
  )
  and (
    .connections["Build Unrecorded Failure Result"].main[0][0].node
    == "Show Assessment Failure"
  )
  and (
    .connections["Build Rejected Assessment Result"].main[0][0].node
    == "Show Assessment Failure"
  )
  and (
    [
      "Validate Assessment Intake",
      "Extract from File",
      "Extract Structured Candidate Profile",
      "Validate Candidate Profile",
      "Save Resume Extraction",
      "Attach Resume Extraction",
      "Resolve Grade Engine Input",
      "Run Deterministic Grade Engine",
      "Build TalentAI Assessment Result",
      "Expire Stale Assessment Executions",
      "Record Assessment Failure"
    ] as $error_nodes
    | (
        [
          .nodes[]
          | select(.name as $name | $error_nodes | index($name))
          | select(.onError == "continueErrorOutput")
        ]
        | length
      ) == ($error_nodes | length)
  )
  and (
    .connections["Expire Stale Assessment Executions"].main[1][0].node
    == "Stale Recovery Failure"
  )
' "$TALENTAI_TAI01" >/dev/null

jq -e '
  ([.nodes[].id] | length) == ([.nodes[].id] | unique | length)
  and ([.nodes[].name] | length) == ([.nodes[].name] | unique | length)
  and (
    first(
      .nodes[]
      | select(.name == "Grade Guide Resolution Requested")
      | [.parameters.workflowInputs.values[].name]
    )
    == ["extractionId", "requestId", "rootWorkflowExecutionId", "attemptCount"]
  )
  and any(.nodes[]; .name == "Validate Operational Input")
  and any(.nodes[]; .name == "Advance Grade Guide Resolution")
  and (.settings.executionTimeout == 60)
  and (
    .connections["Validate Operational Input"].main[0][0].node
    == "Advance Grade Guide Resolution"
  )
' "$TALENTAI_TAI02" >/dev/null

jq -e '
  ([.nodes[].id] | length) == ([.nodes[].id] | unique | length)
  and ([.nodes[].name] | length) == ([.nodes[].name] | unique | length)
  and any(.nodes[]; .name == "Advance Evidence Scoring")
  and any(.nodes[]; .name == "Advance Assessment Persistence")
  and any(.nodes[]; .name == "Complete Assessment Execution")
  and (.settings.executionTimeout == 240)
  and any(
    .nodes[];
    .name == "Score Resume Evidence"
    and .retryOnFail == true
    and .maxTries == 3
    and .waitBetweenTries == 2000
  )
  and (
    .connections["Validate Grade Engine Input"].main[0][0].node
    == "Advance Evidence Scoring"
  )
  and (
    .connections["Calculate Deterministic Grade"].main[0][0].node
    == "Advance Assessment Persistence"
  )
  and (
    .connections["Persist Grade Assessment"].main[0][0].node
    == "Complete Assessment Execution"
  )
' "$TALENTAI_TAI03" >/dev/null

assert_embedded_query() {
  local workflow_file="$1"
  local node_name="$2"
  local query_file="$3"

  jq -e \
    --arg node_name "$node_name" \
    --rawfile expected_query "$query_file" \
    'first(.nodes[] | select(.name == $node_name) | .parameters.query) == $expected_query' \
    "$workflow_file" >/dev/null || {
      echo "Embedded query drift: $node_name" >&2
      exit 1
    }
}

assert_embedded_code() {
  local workflow_file="$1"
  local node_name="$2"
  local code_file="$3"

  jq -e \
    --arg node_name "$node_name" \
    --rawfile expected_code "$code_file" \
    'first(.nodes[] | select(.name == $node_name) | .parameters.jsCode) == ($expected_code | rtrimstr("\n"))' \
    "$workflow_file" >/dev/null || {
      echo "Embedded Code node drift: $node_name" >&2
      exit 1
    }
}

assert_embedded_query \
  "$TALENTAI_TAI01" \
  'Claim Assessment Execution' \
  'database/queries/Q004__claim_assessment_execution.sql'

assert_embedded_query \
  "$TALENTAI_TAI01" \
  'Attach Resume Extraction' \
  'database/queries/Q006__attach_resume_extraction.sql'

assert_embedded_query \
  "$TALENTAI_TAI01" \
  'Load Completed Assessment' \
  'database/queries/Q009__load_completed_assessment_execution.sql'

assert_embedded_query \
  "$TALENTAI_TAI01" \
  'Record Assessment Failure' \
  'database/queries/Q008__fail_assessment_execution.sql'

assert_embedded_query \
  "$TALENTAI_TAI01" \
  'Expire Stale Assessment Executions' \
  'database/queries/Q011__expire_stale_assessment_executions.sql'

assert_embedded_query \
  "$TALENTAI_TAI02" \
  'Advance Grade Guide Resolution' \
  'database/queries/Q005__advance_assessment_execution.sql'

assert_embedded_query \
  "$TALENTAI_TAI03" \
  'Advance Evidence Scoring' \
  'database/queries/Q005__advance_assessment_execution.sql'

assert_embedded_query \
  "$TALENTAI_TAI03" \
  'Advance Assessment Persistence' \
  'database/queries/Q005__advance_assessment_execution.sql'

assert_embedded_query \
  "$TALENTAI_TAI03" \
  'Persist Grade Assessment' \
  'database/queries/Q010__persist_operational_grade_assessment.sql'

assert_embedded_query \
  "$TALENTAI_TAI03" \
  'Complete Assessment Execution' \
  'database/queries/Q007__complete_assessment_execution.sql'

assert_embedded_code \
  "$TALENTAI_TAI01" \
  'Validate Assessment Intake' \
  'workflows/phase-1/code/tai01-validate-assessment-intake.js'

assert_embedded_code \
  "$TALENTAI_TAI01" \
  'Build Assessment Claim' \
  'workflows/phase-1/code/tai01-build-assessment-claim.js'

assert_embedded_code \
  "$TALENTAI_TAI01" \
  'Prepare Grading Request' \
  'workflows/phase-1/code/tai01-prepare-grading-request.js'

assert_embedded_code \
  "$TALENTAI_TAI01" \
  'Build Replayed Assessment Result' \
  'workflows/phase-1/code/tai01-build-replayed-assessment-result.js'

assert_embedded_code \
  "$TALENTAI_TAI01" \
  'Build TalentAI Assessment Result' \
  'workflows/phase-1/code/tai01-build-assessment-result.js'

assert_embedded_code \
  "$TALENTAI_TAI01" \
  'Build Failed Assessment Result' \
  'workflows/phase-1/code/tai01-build-failed-assessment-result.js'

assert_embedded_code \
  "$TALENTAI_TAI01" \
  'Build Failure Recording Fallback' \
  'workflows/phase-1/code/tai01-build-failure-recording-fallback.js'

assert_embedded_code \
  "$TALENTAI_TAI01" \
  'Build Unrecorded Failure Result' \
  'workflows/phase-1/code/tai01-build-unrecorded-failure-result.js'

assert_embedded_code \
  "$TALENTAI_TAI01" \
  'Build Rejected Assessment Result' \
  'workflows/phase-1/code/tai01-build-rejected-assessment-result.js'

assert_embedded_code \
  "$TALENTAI_TAI02" \
  'Validate Operational Input' \
  'workflows/phase-1/code/tai02-validate-operational-input.js'

assert_embedded_code \
  "$TALENTAI_TAI03" \
  'Validate Grade Engine Input' \
  'workflows/phase-1/code/tai03-validate-operational-input.js'

assert_embedded_code \
  "$TALENTAI_TAI03" \
  'Build Grade Assessment Result' \
  'workflows/phase-1/code/tai03-build-assessment-result.js'

for code_file in workflows/phase-1/code/*.js; do
  node -e '
    const fs = require("node:fs");
    new Function(fs.readFileSync(process.argv[1], "utf8"));
  ' "$code_file"
done

TALENTAI_TEMP_DIR="$(mktemp -d)"
readonly TALENTAI_TEMP_DIR
trap 'rm -rf -- "$TALENTAI_TEMP_DIR"' EXIT

for workflow_file in "$TALENTAI_TAI01" "$TALENTAI_TAI02" "$TALENTAI_TAI03"; do
  temporary_workflow="$TALENTAI_TEMP_DIR/$(basename "$workflow_file")"
  normalized_source="$temporary_workflow.source.normalized.json"
  normalized_transformed="$temporary_workflow.transformed.normalized.json"

  cp "$workflow_file" "$temporary_workflow"
  node "$TALENTAI_SCRIPT_DIR/transform-phase1-step3b.mjs" "$temporary_workflow"

  jq -S . "$workflow_file" > "$normalized_source"
  jq -S . "$temporary_workflow" > "$normalized_transformed"

  cmp -s "$normalized_source" "$normalized_transformed" || {
    echo "Workflow transformer is not idempotent: $(basename "$workflow_file")" >&2
    exit 1
  }
done

assert_postgres_credential_inference() {
  local workflow_file="$1"
  local donor_node="$2"
  local temporary_workflow="$TALENTAI_TEMP_DIR/credential-$(basename "$workflow_file")"

  jq \
    --arg donor_node "$donor_node" \
    '
      .nodes |= map(
        if .type == "n8n-nodes-base.postgres" then
          if .name == $donor_node then
            .credentials = {
              postgres: {
                id: "contract-postgres-credential",
                name: "Contract PostgreSQL"
              }
            }
          else
            del(.credentials)
          end
        else
          .
        end
      )
    ' "$workflow_file" > "$temporary_workflow"

  node "$TALENTAI_SCRIPT_DIR/transform-phase1-step3b.mjs" "$temporary_workflow"

  jq -e '
    [
      .nodes[]
      | select(.type == "n8n-nodes-base.postgres")
      | .credentials.postgres.id
    ]
    | length > 0
      and all(. == "contract-postgres-credential")
  ' "$temporary_workflow" >/dev/null || {
    echo "PostgreSQL credential inference failed: $(basename "$workflow_file")" >&2
    exit 1
  }
}

assert_postgres_credential_inference \
  "$TALENTAI_TAI01" \
  'Save Resume Extraction'

assert_postgres_credential_inference \
  "$TALENTAI_TAI02" \
  'Resolve Extraction and Grade Guide'

assert_postgres_credential_inference \
  "$TALENTAI_TAI03" \
  'Persist Grade Assessment'

echo 'TalentAI Phase 1 operational workflow contract passed.'
