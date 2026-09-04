#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_WORKFLOW_DIR="$TALENTAI_REPOSITORY_ROOT/workflows/resume-assessment"
readonly TALENTAI_MANIFEST="$TALENTAI_WORKFLOW_DIR/manifest.json"
readonly TALENTAI_PRIVATE_DIR="$TALENTAI_REPOSITORY_ROOT/exports/private"
readonly TALENTAI_BASE_PACKAGE="$TALENTAI_PRIVATE_DIR/TalentAI-phase-1-step3.1B.base.raw.n8np"
readonly TALENTAI_UPGRADE_PACKAGE="$TALENTAI_PRIVATE_DIR/TalentAI-phase-1-step3.1B.n8np"

cd "$TALENTAI_REPOSITORY_ROOT"

required_commands=(cmp jq n8n-cli node rg tar mktemp)

for required_command in "${required_commands[@]}"; do
  command -v "$required_command" >/dev/null 2>&1 || {
    echo "Required command is missing: $required_command" >&2
    exit 1
  }
done

mkdir -p "$TALENTAI_PRIVATE_DIR"

workflow_id_by_name() {
  local workflow_name="$1"

  jq -er \
    --arg workflow_name "$workflow_name" \
    'first(.workflows[] | select(.name == $workflow_name) | .id) // error("Workflow ID not found")' \
    "$TALENTAI_MANIFEST"
}

readonly TALENTAI_TAI01_ID="$(
  workflow_id_by_name 'TAI-01 Resume Intake & Extraction v2'
)"
readonly TALENTAI_TAI02_ID="$(
  workflow_id_by_name 'TAI-02 Grade Guide Resolver v1'
)"
readonly TALENTAI_TAI03_ID="$(
  workflow_id_by_name 'TAI-03 Evidence Scoring & Deterministic Grade Engine v1'
)"

n8n-cli package export \
  --workflow-id="$TALENTAI_TAI01_ID" \
  --workflow-id="$TALENTAI_TAI02_ID" \
  --workflow-id="$TALENTAI_TAI03_ID" \
  --include-variable-values=false \
  --include-tags=false \
  --missing-workflow-dependency-policy=fail \
  --output="$TALENTAI_BASE_PACKAGE"

TALENTAI_TEMP_DIR="$(mktemp -d)"
readonly TALENTAI_TEMP_DIR
trap 'rm -rf -- "$TALENTAI_TEMP_DIR"' EXIT

readonly TALENTAI_PACKAGE_ROOT="$TALENTAI_TEMP_DIR/package"
readonly TALENTAI_COMPARE_ROOT="$TALENTAI_TEMP_DIR/compare"

mkdir -p "$TALENTAI_PACKAGE_ROOT" "$TALENTAI_COMPARE_ROOT"
tar -xzf "$TALENTAI_BASE_PACKAGE" -C "$TALENTAI_PACKAGE_ROOT"

jq -e '
  (.packageFormatVersion == "1")
  and ((.workflows // []) | length == 3)
  and ((.folders // []) | length == 0)
  and (((.tags // []) | length) == 0)
' "$TALENTAI_PACKAGE_ROOT/manifest.json" >/dev/null

manifest_workflow_field() {
  local workflow_name="$1"
  local field_name="$2"

  jq -er \
    --arg workflow_name "$workflow_name" \
    --arg field_name "$field_name" \
    'first(.workflows[] | select(.name == $workflow_name) | .[$field_name]) // error("Workflow field not found")' \
    "$TALENTAI_PACKAGE_ROOT/manifest.json"
}

normalize_workflow() {
  local source_path="$1"
  local destination_path="$2"

  jq -S '
    del(
      .active,
      .isPublished,
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

transform_workflow() {
  local workflow_name="$1"
  local committed_name="$2"
  local package_target
  local package_workflow
  local safe_name

  package_target="$(manifest_workflow_field "$workflow_name" target)"

  if [ -z "$package_target" ] \
    || [[ "$package_target" == /* ]] \
    || [[ "$package_target" == *'..'* ]]; then
    echo "Unsafe workflow target: $package_target" >&2
    exit 1
  fi

  package_workflow="$TALENTAI_PACKAGE_ROOT/$package_target/workflow.json"
  safe_name="$(printf '%s' "$committed_name" | tr '/ ' '__')"

  node "$TALENTAI_SCRIPT_DIR/transform-phase1-step3b.mjs" "$package_workflow"

  normalize_workflow \
    "$package_workflow" \
    "$TALENTAI_COMPARE_ROOT/$safe_name.package.json"

  normalize_workflow \
    "$TALENTAI_WORKFLOW_DIR/$committed_name" \
    "$TALENTAI_COMPARE_ROOT/$safe_name.committed.json"

  if ! cmp -s \
    "$TALENTAI_COMPARE_ROOT/$safe_name.package.json" \
    "$TALENTAI_COMPARE_ROOT/$safe_name.committed.json"; then
    echo "Transformed package drifted from committed source: $workflow_name" >&2
    exit 1
  fi
}

transform_workflow \
  'TAI-01 Resume Intake & Extraction v2' \
  'TAI-01-resume-intake-extraction-v2.json'

transform_workflow \
  'TAI-02 Grade Guide Resolver v1' \
  'TAI-02-grade-guide-resolver-v1.json'

transform_workflow \
  'TAI-03 Evidence Scoring & Deterministic Grade Engine v1' \
  'TAI-03-evidence-scoring-grade-engine-v1.json'

if jq -s -e '
  [
    .[]
    | .nodes[]
    | select(.type == "n8n-nodes-base.postgres")
    | select((.credentials.postgres.id // "") == "")
  ]
  | length > 0
' "$TALENTAI_PACKAGE_ROOT"/workflows/*/workflow.json >/dev/null; then
  echo 'A PostgreSQL node has no credential reference in the upgrade package.' >&2
  exit 1
fi

if rg -q -i \
  'sk-[A-Za-z0-9_-]{16,}|"(apiKey|password|accessToken|refreshToken|clientSecret|authorization)"[[:space:]]*:' \
  "$TALENTAI_PACKAGE_ROOT"; then
  echo 'A possible secret was detected in the upgrade package.' >&2
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
  tar -czf "$TALENTAI_UPGRADE_PACKAGE" "${archive_members[@]}"
)

echo "Step 3.1B upgrade package created: $TALENTAI_UPGRADE_PACKAGE"
echo 'Import it into the project that already owns the three Phase 1 workflows.'
echo 'Use workflow-conflict-policy=new-version and credential-missing-mode=must-preexist.'
