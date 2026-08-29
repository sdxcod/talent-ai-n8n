#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_EXPECTED_TAI01='TAI-01 Resume Intake & Extraction v2'
readonly TALENTAI_EXPECTED_TAI02='TAI-02 Grade Guide Resolver v1'
readonly TALENTAI_EXPECTED_TAI03='TAI-03 Evidence Scoring & Deterministic Grade Engine v1'

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_FOLDER_ID="${TALENTAI_PHASE1_FOLDER_ID:?Set TALENTAI_PHASE1_FOLDER_ID to the n8n Phase 1 folder ID.}"
readonly TALENTAI_RELEASE_VERSION="${1:-1.0.0}"
readonly TALENTAI_PRIVATE_EXPORT_DIR="$TALENTAI_REPOSITORY_ROOT/exports/private"
readonly TALENTAI_DESTINATION_DIR="$TALENTAI_REPOSITORY_ROOT/workflows/phase-1"
readonly TALENTAI_PACKAGE="$TALENTAI_PRIVATE_EXPORT_DIR/TalentAI-phase-1-v${TALENTAI_RELEASE_VERSION}.raw.n8np"

command -v n8n-cli >/dev/null 2>&1 || {
  echo 'n8n-cli is required. Install it with: npm install -g @n8n/cli' >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  echo 'jq is required.' >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || {
  echo 'ripgrep (rg) is required.' >&2
  exit 1
}

TALENTAI_TEMP_DIR="$(mktemp -d)"
readonly TALENTAI_TEMP_DIR
trap 'rm -rf -- "$TALENTAI_TEMP_DIR"' EXIT

readonly TALENTAI_TEMP_MANIFEST="$TALENTAI_TEMP_DIR/manifest.json"
readonly TALENTAI_TEMP_OUTPUT_DIR="$TALENTAI_TEMP_DIR/phase-1"

mkdir -p "$TALENTAI_PRIVATE_EXPORT_DIR" "$TALENTAI_TEMP_OUTPUT_DIR"

n8n-cli package export \
  --folder-id="$TALENTAI_FOLDER_ID" \
  --include-variable-values=false \
  --include-tags=false \
  --missing-workflow-dependency-policy=fail \
  --output="$TALENTAI_PACKAGE"

tar -xOzf "$TALENTAI_PACKAGE" manifest.json > "$TALENTAI_TEMP_MANIFEST"

jq -e \
  --arg tai01 "$TALENTAI_EXPECTED_TAI01" \
  --arg tai02 "$TALENTAI_EXPECTED_TAI02" \
  --arg tai03 "$TALENTAI_EXPECTED_TAI03" \
  '
    (.packageFormatVersion == "1")
    and ((.workflows // []) | length == 3)
    and (
      ([.workflows[].name] | sort)
      == ([$tai01, $tai02, $tai03] | sort)
    )
    and (((.variables // []) | length) == 0)
  ' "$TALENTAI_TEMP_MANIFEST" >/dev/null || {
    echo 'Package validation failed: expected exactly the three Phase 1 workflows and no bundled variables.' >&2
    exit 1
  }

workflow_target() {
  local workflow_name="$1"

  jq -er \
    --arg workflow_name "$workflow_name" \
    'first(.workflows[] | select(.name == $workflow_name) | .target) // error("Workflow not found")' \
    "$TALENTAI_TEMP_MANIFEST"
}

materialize_workflow() {
  local workflow_name="$1"
  local destination_name="$2"
  local archive_target

  archive_target="$(workflow_target "$workflow_name")"

  tar -xOzf "$TALENTAI_PACKAGE" "$archive_target/workflow.json" \
  | jq '
      del(
        .pinData,
        .staticData,
        .versionId,
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
    releaseVersion: $release_version,
    packageFormatVersion,
    sourceN8nVersion,
    folder: (((.folders // [])[0].name) // "TalentAI - Phase 1"),
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
  }' "$TALENTAI_TEMP_MANIFEST" > "$TALENTAI_TEMP_OUTPUT_DIR/manifest.json"

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
  echo 'A possible secret was detected. Inspect the temporary source package before committing.' >&2
  exit 1
fi

readonly TAI02_WORKFLOW_ID="$(jq -r '.id' "$TALENTAI_TEMP_OUTPUT_DIR/TAI-02-grade-guide-resolver-v1.json")"
readonly TAI03_WORKFLOW_ID="$(jq -r '.id' "$TALENTAI_TEMP_OUTPUT_DIR/TAI-03-evidence-scoring-grade-engine-v1.json")"

rg -q --fixed-strings \
  "$TAI02_WORKFLOW_ID" \
  "$TALENTAI_TEMP_OUTPUT_DIR/TAI-01-resume-intake-extraction-v2.json" || {
    echo 'TAI-01 does not contain the TAI-02 workflow reference.' >&2
    exit 1
  }

rg -q --fixed-strings \
  "$TAI03_WORKFLOW_ID" \
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
jq -r '.workflows[] | [.id, .name, .file] | @tsv' "$TALENTAI_DESTINATION_DIR/manifest.json"
