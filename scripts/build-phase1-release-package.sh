#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_EXPECTED_TAI01='TAI-01 Resume Intake & Extraction v2'
readonly TALENTAI_EXPECTED_TAI02='TAI-02 Grade Guide Resolver v1'
readonly TALENTAI_EXPECTED_TAI03='TAI-03 Evidence Scoring & Deterministic Grade Engine v1'

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_RELEASE_VERSION="${1:-1.0.0}"
readonly TALENTAI_WORKFLOW_SOURCE_DIR="$TALENTAI_REPOSITORY_ROOT/workflows/resume-assessment"
readonly TALENTAI_RAW_PACKAGE="${2:-$TALENTAI_REPOSITORY_ROOT/exports/private/TalentAI-phase-1-v${TALENTAI_RELEASE_VERSION}.flat.raw.n8np}"
readonly TALENTAI_DIST_DIR="$TALENTAI_REPOSITORY_ROOT/dist"
readonly TALENTAI_RELEASE_PACKAGE="$TALENTAI_DIST_DIR/TalentAI-phase-1-v${TALENTAI_RELEASE_VERSION}.n8np"

required_commands=(cmp jq rg tar shasum mktemp)

for required_command in "${required_commands[@]}"; do
  command -v "$required_command" >/dev/null 2>&1 || {
    echo "Required command is missing: $required_command" >&2
    exit 1
  }
done

if [ ! -f "$TALENTAI_RAW_PACKAGE" ]; then
  echo "Raw flat n8n package was not found: $TALENTAI_RAW_PACKAGE" >&2
  echo 'Run scripts/export-phase1-workflows.sh first.' >&2
  exit 1
fi

required_sources=(
  "$TALENTAI_WORKFLOW_SOURCE_DIR/TAI-01-resume-intake-extraction-v2.json"
  "$TALENTAI_WORKFLOW_SOURCE_DIR/TAI-02-grade-guide-resolver-v1.json"
  "$TALENTAI_WORKFLOW_SOURCE_DIR/TAI-03-evidence-scoring-grade-engine-v1.json"
)

for required_source in "${required_sources[@]}"; do
  if [ ! -f "$required_source" ]; then
    echo "Sanitized workflow source is missing: $required_source" >&2
    exit 1
  fi
done

TALENTAI_TEMP_DIR="$(mktemp -d)"
readonly TALENTAI_TEMP_DIR
trap 'rm -rf -- "$TALENTAI_TEMP_DIR"' EXIT

readonly TALENTAI_RAW_MANIFEST="$TALENTAI_TEMP_DIR/manifest.raw.json"
readonly TALENTAI_PACKAGE_ROOT="$TALENTAI_TEMP_DIR/package"
readonly TALENTAI_VERIFICATION_ROOT="$TALENTAI_TEMP_DIR/verification"
readonly TALENTAI_NORMALIZATION_ROOT="$TALENTAI_TEMP_DIR/normalization"

mkdir -p \
  "$TALENTAI_PACKAGE_ROOT" \
  "$TALENTAI_VERIFICATION_ROOT" \
  "$TALENTAI_NORMALIZATION_ROOT" \
  "$TALENTAI_DIST_DIR"

tar -xOzf "$TALENTAI_RAW_PACKAGE" manifest.json > "$TALENTAI_RAW_MANIFEST"

jq -e \
  --arg tai01 "$TALENTAI_EXPECTED_TAI01" \
  --arg tai02 "$TALENTAI_EXPECTED_TAI02" \
  --arg tai03 "$TALENTAI_EXPECTED_TAI03" \
  '
    (.packageFormatVersion == "1")
    and ((.workflows // []) | length == 3)
    and ((.folders // []) | length == 0)
    and (
      ([.workflows[].name] | sort)
      == ([$tai01, $tai02, $tai03] | sort)
    )
    and (((.variables // []) | length) == 0)
    and (((.dataTables // []) | length) == 0)
    and (((.tags // []) | length) == 0)
  ' "$TALENTAI_RAW_MANIFEST" >/dev/null || {
    echo 'Raw flat package validation failed.' >&2
    echo 'Export the three workflow IDs explicitly; do not use a folder package as the release input.' >&2
    exit 1
  }

jq \
  --arg tai01 "$TALENTAI_EXPECTED_TAI01" \
  --arg tai02 "$TALENTAI_EXPECTED_TAI02" \
  --arg tai03 "$TALENTAI_EXPECTED_TAI03" \
  '
    del(.folders, .credentials, .variables, .tags, .dataTables)
    | .workflows |= map(
        if .name == $tai01 then
          .target = "workflows/tai-01-resume-intake-extraction-v2"
        elif .name == $tai02 then
          .target = "workflows/tai-02-grade-guide-resolver-v1"
        elif .name == $tai03 then
          .target = "workflows/tai-03-evidence-scoring-deterministic-grade-engine-v1"
        else
          .
        end
      )
    | if .requirements then
        del(.requirements.credentials, .requirements.variables)
      else
        .
      end
  ' "$TALENTAI_RAW_MANIFEST" > "$TALENTAI_PACKAGE_ROOT/manifest.json"

manifest_workflow_target() {
  local manifest_path="$1"
  local workflow_name="$2"

  jq -er \
    --arg workflow_name "$workflow_name" \
    'first(.workflows[] | select(.name == $workflow_name) | .target) // error("Workflow not found")' \
    "$manifest_path"
}

validate_archive_target() {
  local archive_target="$1"

  if [ -z "$archive_target" ] \
    || [[ "$archive_target" == /* ]] \
    || [[ "$archive_target" == *'..'* ]]; then
    echo "Unsafe target in package manifest: $archive_target" >&2
    exit 1
  fi
}

normalize_workflow() {
  local source_path="$1"
  local destination_path="$2"

  jq -S '
    del(
      .active,
      .versionId,
      .parentFolderId,
      .pinData,
      .staticData,
      .createdAt,
      .updatedAt,
      .triggerCount,
      .meta,
      .shared,
      .tags
    )
    | .nodes |= map(del(.credentials))
  ' "$source_path" > "$destination_path"
}

materialize_release_workflow() {
  local workflow_name="$1"
  local source_name="$2"
  local raw_target
  local release_target
  local workflow_id
  local safe_name
  local raw_workflow
  local normalized_raw
  local normalized_committed

  raw_target="$(manifest_workflow_target "$TALENTAI_RAW_MANIFEST" "$workflow_name")"
  release_target="$(manifest_workflow_target "$TALENTAI_PACKAGE_ROOT/manifest.json" "$workflow_name")"

  validate_archive_target "$raw_target"
  validate_archive_target "$release_target"

  workflow_id="$(
    jq -er \
      --arg workflow_name "$workflow_name" \
      'first(.workflows[] | select(.name == $workflow_name) | .id) // error("Workflow ID not found")' \
      "$TALENTAI_RAW_MANIFEST"
  )"

  safe_name="$(printf '%s' "$source_name" | tr '/ ' '__')"
  raw_workflow="$TALENTAI_NORMALIZATION_ROOT/$safe_name.raw.json"
  normalized_raw="$TALENTAI_NORMALIZATION_ROOT/$safe_name.raw.normalized.json"
  normalized_committed="$TALENTAI_NORMALIZATION_ROOT/$safe_name.committed.normalized.json"

  tar -xOzf \
    "$TALENTAI_RAW_PACKAGE" \
    "$raw_target/workflow.json" \
    > "$raw_workflow"

  jq -e \
    --arg workflow_id "$workflow_id" \
    --arg workflow_name "$workflow_name" \
    '
      (.id == $workflow_id)
      and (.name == $workflow_name)
      and ((.versionId | type) == "string")
      and (has("active") | not)
      and (has("pinData") | not)
      and (has("staticData") | not)
    ' "$raw_workflow" >/dev/null || {
      echo "Raw package workflow schema check failed: $workflow_name" >&2
      exit 1
    }

  jq -e \
    --arg workflow_id "$workflow_id" \
    --arg workflow_name "$workflow_name" \
    '
      (.id == $workflow_id)
      and (.name == $workflow_name)
      and (.active == false)
      and (has("pinData") | not)
      and (has("staticData") | not)
      and ([.nodes[] | has("credentials")] | any | not)
    ' "$TALENTAI_WORKFLOW_SOURCE_DIR/$source_name" >/dev/null || {
      echo "Committed workflow validation failed: $source_name" >&2
      exit 1
    }

  normalize_workflow "$raw_workflow" "$normalized_raw"
  normalize_workflow \
    "$TALENTAI_WORKFLOW_SOURCE_DIR/$source_name" \
    "$normalized_committed"

  if ! cmp -s "$normalized_raw" "$normalized_committed"; then
    echo "Workflow source drift detected: $workflow_name" >&2
    echo 'Run scripts/export-phase1-workflows.sh and review the workflow source diff first.' >&2
    exit 1
  fi

  mkdir -p "$TALENTAI_PACKAGE_ROOT/$release_target"

  jq '
    del(.pinData, .staticData)
    | .nodes |= map(del(.credentials))
  ' "$raw_workflow" > "$TALENTAI_PACKAGE_ROOT/$release_target/workflow.json"

  jq -e '
    ((.versionId | type) == "string")
    and (has("active") | not)
    and (has("pinData") | not)
    and (has("staticData") | not)
    and ([.nodes[] | has("credentials")] | any | not)
  ' "$TALENTAI_PACKAGE_ROOT/$release_target/workflow.json" >/dev/null
}

materialize_release_workflow \
  "$TALENTAI_EXPECTED_TAI01" \
  'TAI-01-resume-intake-extraction-v2.json'

materialize_release_workflow \
  "$TALENTAI_EXPECTED_TAI02" \
  'TAI-02-grade-guide-resolver-v1.json'

materialize_release_workflow \
  "$TALENTAI_EXPECTED_TAI03" \
  'TAI-03-evidence-scoring-grade-engine-v1.json'

if rg -q -i \
  'sk-[A-Za-z0-9_-]{16,}|n8n_api_[A-Za-z0-9_-]{16,}|"(apiKey|password|accessToken|refreshToken|clientSecret|authorization)"[[:space:]]*:' \
  "$TALENTAI_PACKAGE_ROOT"; then
  echo 'A possible secret was detected in the release package source.' >&2
  exit 1
fi

archive_members=(manifest.json)

while IFS= read -r archive_member; do
  archive_member="${archive_member#./}"
  if [ "$archive_member" != 'manifest.json' ]; then
    archive_members+=("$archive_member")
  fi
done < <(
  cd "$TALENTAI_PACKAGE_ROOT"
  find . -type f -print | LC_ALL=C sort
)

(
  cd "$TALENTAI_PACKAGE_ROOT"
  tar -czf "$TALENTAI_RELEASE_PACKAGE" "${archive_members[@]}"
)

tar -xzf "$TALENTAI_RELEASE_PACKAGE" -C "$TALENTAI_VERIFICATION_ROOT"

jq -e '
  (.packageFormatVersion == "1")
  and ((.workflows // []) | length == 3)
  and ((.folders // []) | length == 0)
  and (((.credentials // []) | length) == 0)
  and (((.variables // []) | length) == 0)
  and (((.requirements.credentials // []) | length) == 0)
  and (((.requirements.variables // []) | length) == 0)
  and (((.requirements.workflows // []) | length) == 2)
' "$TALENTAI_VERIFICATION_ROOT/manifest.json" >/dev/null

if [ "$(find "$TALENTAI_VERIFICATION_ROOT" -name workflow.json -type f | wc -l | tr -d ' ')" -ne 3 ]; then
  echo 'Release package does not contain exactly three workflow entities.' >&2
  exit 1
fi

if [ "$(find "$TALENTAI_VERIFICATION_ROOT" -name folder.json -type f | wc -l | tr -d ' ')" -ne 0 ]; then
  echo 'Release package unexpectedly contains a folder entity.' >&2
  exit 1
fi

while IFS= read -r workflow_target_path; do
  validate_archive_target "$workflow_target_path"

  jq -e '
    ((.versionId | type) == "string")
    and (has("active") | not)
    and (has("pinData") | not)
    and (has("staticData") | not)
    and ([.nodes[] | has("credentials")] | any | not)
  ' "$TALENTAI_VERIFICATION_ROOT/$workflow_target_path/workflow.json" >/dev/null
done < <(
  jq -r '.workflows[].target' "$TALENTAI_VERIFICATION_ROOT/manifest.json"
)

echo "Safe TalentAI Phase 1 package created: $TALENTAI_RELEASE_PACKAGE"
echo 'Package SHA-256:'
shasum -a 256 "$TALENTAI_RELEASE_PACKAGE"

echo 'Release manifest summary:'
jq '{
  packageFormatVersion,
  sourceN8nVersion,
  workflowCount: ((.workflows // []) | length),
  folderCount: ((.folders // []) | length),
  credentialEntityCount: ((.credentials // []) | length),
  credentialRequirementCount: ((.requirements.credentials // []) | length),
  workflowDependencyCount: ((.requirements.workflows // []) | length),
  variableEntityCount: ((.variables // []) | length),
  variableRequirementCount: ((.requirements.variables // []) | length)
}' "$TALENTAI_VERIFICATION_ROOT/manifest.json"
