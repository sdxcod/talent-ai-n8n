#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_EXPECTED_TAI01='TAI-01 Resume Intake & Extraction v2'
readonly TALENTAI_EXPECTED_TAI02='TAI-02 Grade Guide Resolver v1'
readonly TALENTAI_EXPECTED_TAI03='TAI-03 Evidence Scoring & Deterministic Grade Engine v1'

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_RELEASE_VERSION="${1:-1.0.0}"
readonly TALENTAI_PRIVATE_EXPORT_DIR="$TALENTAI_REPOSITORY_ROOT/exports/private"
readonly TALENTAI_DESTINATION_DIR="$TALENTAI_REPOSITORY_ROOT/workflows/resume-assessment"
readonly TALENTAI_SOURCE_MANIFEST="$TALENTAI_DESTINATION_DIR/manifest.json"
readonly TALENTAI_FLAT_PACKAGE="$TALENTAI_PRIVATE_EXPORT_DIR/TalentAI-phase-1-v${TALENTAI_RELEASE_VERSION}.flat.raw.n8np"

required_commands=(jq n8n-cli rg tar)

for required_command in "${required_commands[@]}"; do
  command -v "$required_command" >/dev/null 2>&1 || {
    echo "Required command is missing: $required_command" >&2
    exit 1
  }
done

if [ ! -f "$TALENTAI_SOURCE_MANIFEST" ]; then
  echo "Committed Phase 1 manifest was not found: $TALENTAI_SOURCE_MANIFEST" >&2
  exit 1
fi

jq -e \
  --arg tai01 "$TALENTAI_EXPECTED_TAI01" \
  --arg tai02 "$TALENTAI_EXPECTED_TAI02" \
  --arg tai03 "$TALENTAI_EXPECTED_TAI03" \
  '
    (.phase == "1")
    and (.domain == "RESUME_ASSESSMENT")
    and ((.workflows // []) | length == 3)
    and (
      ([.workflows[].name] | sort)
      == ([$tai01, $tai02, $tai03] | sort)
    )
    and ([.workflows[].id | select(type != "string" or length == 0)] | length == 0)
  ' "$TALENTAI_SOURCE_MANIFEST" >/dev/null || {
    echo 'Committed Phase 1 manifest validation failed.' >&2
    exit 1
  }

manifest_workflow_field() {
  local manifest_path="$1"
  local workflow_name="$2"
  local field_name="$3"

  jq -er \
    --arg workflow_name "$workflow_name" \
    --arg field_name "$field_name" \
    'first(.workflows[] | select(.name == $workflow_name) | .[$field_name]) // error("Workflow field not found")' \
    "$manifest_path"
}

readonly TALENTAI_TAI01_ID="$(manifest_workflow_field "$TALENTAI_SOURCE_MANIFEST" "$TALENTAI_EXPECTED_TAI01" id)"
readonly TALENTAI_TAI02_ID="$(manifest_workflow_field "$TALENTAI_SOURCE_MANIFEST" "$TALENTAI_EXPECTED_TAI02" id)"
readonly TALENTAI_TAI03_ID="$(manifest_workflow_field "$TALENTAI_SOURCE_MANIFEST" "$TALENTAI_EXPECTED_TAI03" id)"

TALENTAI_TEMP_DIR="$(mktemp -d)"
readonly TALENTAI_TEMP_DIR
trap 'rm -rf -- "$TALENTAI_TEMP_DIR"' EXIT

readonly TALENTAI_FLAT_MANIFEST="$TALENTAI_TEMP_DIR/manifest.flat.json"
readonly TALENTAI_TEMP_OUTPUT_DIR="$TALENTAI_TEMP_DIR/phase-1"

mkdir -p "$TALENTAI_PRIVATE_EXPORT_DIR" "$TALENTAI_TEMP_OUTPUT_DIR"

n8n-cli package export \
  --workflow-id="$TALENTAI_TAI01_ID" \
  --workflow-id="$TALENTAI_TAI02_ID" \
  --workflow-id="$TALENTAI_TAI03_ID" \
  --include-variable-values=false \
  --include-tags=false \
  --missing-workflow-dependency-policy=fail \
  --output="$TALENTAI_FLAT_PACKAGE"

tar -xOzf "$TALENTAI_FLAT_PACKAGE" manifest.json > "$TALENTAI_FLAT_MANIFEST"

jq -e \
  --arg tai01 "$TALENTAI_EXPECTED_TAI01" \
  --arg tai02 "$TALENTAI_EXPECTED_TAI02" \
  --arg tai03 "$TALENTAI_EXPECTED_TAI03" \
  --arg tai01_id "$TALENTAI_TAI01_ID" \
  --arg tai02_id "$TALENTAI_TAI02_ID" \
  --arg tai03_id "$TALENTAI_TAI03_ID" \
  '
    (.packageFormatVersion == "1")
    and ((.workflows // []) | length == 3)
    and ((.folders // []) | length == 0)
    and (
      ([.workflows[] | {id, name}] | sort_by(.id))
      == (
        [
          {id: $tai01_id, name: $tai01},
          {id: $tai02_id, name: $tai02},
          {id: $tai03_id, name: $tai03}
        ]
        | sort_by(.id)
      )
    )
    and (((.variables // []) | length) == 0)
  ' "$TALENTAI_FLAT_MANIFEST" >/dev/null || {
    echo 'Flat package validation failed: expected the exact three allow-listed Phase 1 workflows and no folder or variable.' >&2
    exit 1
  }

materialize_workflow() {
  local workflow_name="$1"
  local destination_name="$2"
  local archive_target

  archive_target="$(manifest_workflow_field "$TALENTAI_FLAT_MANIFEST" "$workflow_name" target)"

  if [ -z "$archive_target" ] \
    || [[ "$archive_target" == /* ]] \
    || [[ "$archive_target" == *'..'* ]]; then
    echo "Unsafe workflow target in flat package: $archive_target" >&2
    exit 1
  fi

  tar -xOzf "$TALENTAI_FLAT_PACKAGE" "$archive_target/workflow.json" \
  | jq '
      del(
        .pinData,
        .staticData,
        .versionId,
        .parentFolderId,
        .createdAt,
        .updatedAt,
        .triggerCount,
        .meta,
        .shared,
        .tags
      )
      | .active = false
      | .nodes |= map(del(.credentials))
    ' > "$TALENTAI_TEMP_OUTPUT_DIR/$destination_name"
}

materialize_workflow \
  "$TALENTAI_EXPECTED_TAI01" \
  'TAI-01-resume-intake-extraction-v2.json'

materialize_workflow \
  "$TALENTAI_EXPECTED_TAI02" \
  'TAI-02-grade-guide-resolver-v1.json'

materialize_workflow \
  "$TALENTAI_EXPECTED_TAI03" \
  'TAI-03-evidence-scoring-grade-engine-v1.json'

jq \
  --arg release_version "$TALENTAI_RELEASE_VERSION" \
  --arg tai01 "$TALENTAI_EXPECTED_TAI01" \
  --arg tai02 "$TALENTAI_EXPECTED_TAI02" \
  --arg tai03 "$TALENTAI_EXPECTED_TAI03" \
  '{
    phase: "1",
    domain: "RESUME_ASSESSMENT",
    releaseVersion: $release_version,
    packageFormatVersion,
    sourceN8nVersion,
    folder: "TalentAI - Resume Assessment",
    workflows: (
      [
        .workflows[]
        | {
            id,
            name,
            file: (
              if .name == $tai01 then "TAI-01-resume-intake-extraction-v2.json"
              elif .name == $tai02 then "TAI-02-grade-guide-resolver-v1.json"
              elif .name == $tai03 then "TAI-03-evidence-scoring-grade-engine-v1.json"
              else error("Unexpected workflow")
              end
            )
          }
      ]
      | sort_by(.name)
    ),
    workflowDependencies: [
      (.requirements.workflows // [])[]
      | {id, name, usedByWorkflows}
    ],
    requiredCredentialTypes: (
      [(.requirements.credentials // [])[].type]
      | unique
    )
  }' "$TALENTAI_FLAT_MANIFEST" > "$TALENTAI_TEMP_OUTPUT_DIR/manifest.json"

jq empty "$TALENTAI_TEMP_OUTPUT_DIR"/*.json

if jq -s -e '
  [
    .[] | .nodes[].name
    | select(
        . == "Manual Trigger"
        or . == "Test Extraction Input"
        or . == "Resolve Test Grade Engine Input"
        or . == "Resume Extraction Result"
      )
  ]
  | length > 0
' "$TALENTAI_TEMP_OUTPUT_DIR"/TAI-*.json >/dev/null; then
  echo 'A test or obsolete node is still present in a Phase 1 workflow.' >&2
  exit 1
fi

if rg -q '"pinData"|"staticData"|"credentials"' "$TALENTAI_TEMP_OUTPUT_DIR"; then
  echo 'Pin data, static data, or credential references remain after sanitization.' >&2
  exit 1
fi

if rg -q -i \
  '"(apiKey|password|accessToken|refreshToken|clientSecret|authorization)"[[:space:]]*:|sk-[A-Za-z0-9_-]{16,}' \
  "$TALENTAI_TEMP_OUTPUT_DIR"; then
  echo 'A possible secret was detected. Inspect the private source package before committing.' >&2
  exit 1
fi

rg -q --fixed-strings \
  "$TALENTAI_TAI02_ID" \
  "$TALENTAI_TEMP_OUTPUT_DIR/TAI-01-resume-intake-extraction-v2.json" || {
    echo 'TAI-01 does not contain the TAI-02 workflow reference.' >&2
    exit 1
  }

rg -q --fixed-strings \
  "$TALENTAI_TAI03_ID" \
  "$TALENTAI_TEMP_OUTPUT_DIR/TAI-01-resume-intake-extraction-v2.json" || {
    echo 'TAI-01 does not contain the TAI-03 workflow reference.' >&2
    exit 1
  }

mkdir -p "$TALENTAI_DESTINATION_DIR"

cp "$TALENTAI_TEMP_OUTPUT_DIR/TAI-01-resume-intake-extraction-v2.json" "$TALENTAI_DESTINATION_DIR/"
cp "$TALENTAI_TEMP_OUTPUT_DIR/TAI-02-grade-guide-resolver-v1.json" "$TALENTAI_DESTINATION_DIR/"
cp "$TALENTAI_TEMP_OUTPUT_DIR/TAI-03-evidence-scoring-grade-engine-v1.json" "$TALENTAI_DESTINATION_DIR/"
cp "$TALENTAI_TEMP_OUTPUT_DIR/manifest.json" "$TALENTAI_DESTINATION_DIR/"

echo "Phase 1 workflows exported and validated: $TALENTAI_DESTINATION_DIR"
echo "Private flat release source package: $TALENTAI_FLAT_PACKAGE"
jq -r '.workflows[] | [.id, .name, .file] | @tsv' "$TALENTAI_DESTINATION_DIR/manifest.json"
