#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_VERSION="${1:-3.1.1-rc.1}"
readonly TALENTAI_PRIVATE_DIR="$TALENTAI_ROOT/exports/private"
readonly TALENTAI_PHASE3_PACKAGE="$TALENTAI_PRIVATE_DIR/TalentAI-phase-1-step3.1B.n8np"
readonly TALENTAI_OUTPUT_PACKAGE="$TALENTAI_PRIVATE_DIR/TalentAI-mvp-v$TALENTAI_VERSION.n8np"
readonly TALENTAI_INTERVIEW_MANIFEST="$TALENTAI_ROOT/workflows/technical-interview/manifest.json"
readonly TALENTAI_TAI04_SOURCE="$TALENTAI_ROOT/workflows/technical-interview/TAI-04-candidate-interview-final-grade-v1.json"
readonly TALENTAI_TAI04_TARGET='workflows/tai-04-candidate-interview-final-grade-v1'
readonly TALENTAI_TAI04_VERSION_ID='571fe3e1-6706-40c5-a23e-0eac51bb283b'
readonly TALENTAI_TAI05_SOURCE="$TALENTAI_ROOT/workflows/technical-interview/TAI-05-secure-interview-invitation-v1.json"
readonly TALENTAI_TAI05_TARGET='workflows/tai-05-secure-interview-invitation-v1'
readonly TALENTAI_TAI05_VERSION_ID='b20ed102-5684-4cc9-8c89-398651a35120'

[[ "$TALENTAI_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || {
  echo 'Version must use SemVer, optionally with a prerelease suffix.' >&2
  exit 1
}

required_commands=(cmp find jq n8n-cli node rg shasum tar mktemp)

for required_command in "${required_commands[@]}"; do
  command -v "$required_command" >/dev/null 2>&1 || {
    echo "Required command is missing: $required_command" >&2
    exit 1
  }
done

cd "$TALENTAI_ROOT"

test -f "$TALENTAI_INTERVIEW_MANIFEST" || {
  echo "Technical interview manifest is missing: $TALENTAI_INTERVIEW_MANIFEST" >&2
  exit 1
}

test -f "$TALENTAI_TAI04_SOURCE" || {
  echo "TAI-04 source is missing: $TALENTAI_TAI04_SOURCE" >&2
  exit 1
}

test -f "$TALENTAI_TAI05_SOURCE" || {
  echo "TAI-05 source is missing: $TALENTAI_TAI05_SOURCE" >&2
  exit 1
}

if [ -e "$TALENTAI_OUTPUT_PACKAGE" ]; then
  echo "Release candidate already exists: $TALENTAI_OUTPUT_PACKAGE" >&2
  exit 1
fi

node scripts/test-phase3-calibration.mjs
node scripts/test-phase3-handoff.mjs
node scripts/test-phase45-workflow.mjs
node scripts/test-secure-invitation-workflows.mjs
node scripts/test-form-access-and-rtl.mjs
./scripts/build-step3b-upgrade-package.sh

test -s "$TALENTAI_PHASE3_PACKAGE" || {
  echo "Phase 3 package was not created: $TALENTAI_PHASE3_PACKAGE" >&2
  exit 1
}

readonly TALENTAI_TAI04_ID="$(
  jq -er '.workflows[0].id // error("TAI-04 ID is missing")' \
    "$TALENTAI_INTERVIEW_MANIFEST"
)"
readonly TALENTAI_TAI04_NAME="$(
  jq -er '.workflows[0].name // error("TAI-04 name is missing")' \
    "$TALENTAI_INTERVIEW_MANIFEST"
)"
readonly TALENTAI_TAI05_ID="$(
  jq -er '
    first(.workflows[] | select(.name == "TAI-05 Secure Interview Invitation v1") | .id)
    // error("TAI-05 ID is missing")
  ' "$TALENTAI_INTERVIEW_MANIFEST"
)"
readonly TALENTAI_TAI05_NAME="$(
  jq -er '
    first(.workflows[] | select(.id == "L8uQ5xN2pR7sV4wZ") | .name)
    // error("TAI-05 name is missing")
  ' "$TALENTAI_INTERVIEW_MANIFEST"
)"

TALENTAI_TEMP_DIR="$(mktemp -d)"
readonly TALENTAI_TEMP_DIR
trap 'rm -rf -- "$TALENTAI_TEMP_DIR"' EXIT

readonly TALENTAI_PACKAGE_ROOT="$TALENTAI_TEMP_DIR/package"
readonly TALENTAI_COMPARE_ROOT="$TALENTAI_TEMP_DIR/compare"
readonly TALENTAI_PACKAGE_MANIFEST="$TALENTAI_PACKAGE_ROOT/manifest.json"
readonly TALENTAI_TAI04_PACKAGE="$TALENTAI_PACKAGE_ROOT/$TALENTAI_TAI04_TARGET/workflow.json"
readonly TALENTAI_TAI05_PACKAGE="$TALENTAI_PACKAGE_ROOT/$TALENTAI_TAI05_TARGET/workflow.json"

mkdir -p \
  "$TALENTAI_PACKAGE_ROOT" \
  "$TALENTAI_COMPARE_ROOT" \
  "$(dirname "$TALENTAI_TAI04_PACKAGE")" \
  "$(dirname "$TALENTAI_TAI05_PACKAGE")"

tar -xzf "$TALENTAI_PHASE3_PACKAGE" -C "$TALENTAI_PACKAGE_ROOT"

jq -e '
  (.packageFormatVersion == "1")
  and ((.workflows // []) | length == 3)
  and ((.folders // []) | length == 0)
  and (((.tags // []) | length) == 0)
  and (((.variables // []) | length) == 0)
' "$TALENTAI_PACKAGE_MANIFEST" >/dev/null || {
  echo 'Phase 3 package does not satisfy the expected release baseline.' >&2
  exit 1
}

if jq -e \
  --arg id "$TALENTAI_TAI04_ID" \
  --arg name "$TALENTAI_TAI04_NAME" \
  --arg tai05_id "$TALENTAI_TAI05_ID" \
  --arg tai05_name "$TALENTAI_TAI05_NAME" \
  'any(
    .workflows[];
    .id == $id or .name == $name
    or .id == $tai05_id or .name == $tai05_name
  )' \
  "$TALENTAI_PACKAGE_MANIFEST" >/dev/null; then
  echo 'A technical interview workflow collides with the assessment package.' >&2
  exit 1
fi

TALENTAI_PACKAGE_WORKFLOWS=()

for workflow_file in \
  "$TALENTAI_PACKAGE_ROOT"/workflows/*/workflow.json; do
  if [ -f "$workflow_file" ]; then
    TALENTAI_PACKAGE_WORKFLOWS+=("$workflow_file")
  fi
done

if [ "${#TALENTAI_PACKAGE_WORKFLOWS[@]}" -ne 3 ]; then
  echo 'Expected exactly three workflow payloads in the Phase 3 package.' >&2
  exit 1
fi

for workflow_file in "${TALENTAI_PACKAGE_WORKFLOWS[@]}"; do
  jq '.active = false' "$workflow_file" \
    > "$TALENTAI_TEMP_DIR/workflow.inactive.json"
  mv "$TALENTAI_TEMP_DIR/workflow.inactive.json" "$workflow_file"
done

readonly TALENTAI_POSTGRES_BINDING="$(
  jq -sc '
    first(
      .[]
      | .nodes[]
      | .credentials.postgres?
      | select(. != null)
    ) // error("PostgreSQL credential binding not found")
  ' "${TALENTAI_PACKAGE_WORKFLOWS[@]}"
)"

readonly TALENTAI_OPENAI_BINDING="$(
  jq -sc '
    first(
      .[]
      | .nodes[]
      | .credentials.openAiApi?
      | select(. != null)
    ) // error("OpenAI credential binding not found")
  ' "${TALENTAI_PACKAGE_WORKFLOWS[@]}"
)"

jq \
  --argjson postgres_binding "$TALENTAI_POSTGRES_BINDING" \
  --argjson openai_binding "$TALENTAI_OPENAI_BINDING" \
  '
    .active = false
    | .versionId = $version_id
    | .parentFolderId = null
    | .nodes |= map(
        if .type == "n8n-nodes-base.postgres" then
          .credentials = {
            postgres: $postgres_binding
          }
        elif .type == "@n8n/n8n-nodes-langchain.lmChatOpenAi" then
          .credentials = {
            openAiApi: $openai_binding
          }
        else
          del(.credentials)
        end
      )
  ' \
  --arg version_id "$TALENTAI_TAI04_VERSION_ID" \
  "$TALENTAI_TAI04_SOURCE" > "$TALENTAI_TAI04_PACKAGE"

jq \
  --argjson postgres_binding "$TALENTAI_POSTGRES_BINDING" \
  '
    .active = false
    | .versionId = $version_id
    | .parentFolderId = null
    | .nodes |= map(
        if .type == "n8n-nodes-base.postgres" then
          .credentials = {
            postgres: $postgres_binding
          }
        else
          del(.credentials)
        end
      )
  ' \
  --arg version_id "$TALENTAI_TAI05_VERSION_ID" \
  "$TALENTAI_TAI05_SOURCE" > "$TALENTAI_TAI05_PACKAGE"

jq \
  --arg id "$TALENTAI_TAI04_ID" \
  --arg name "$TALENTAI_TAI04_NAME" \
  --arg target "$TALENTAI_TAI04_TARGET" \
  --arg tai05_id "$TALENTAI_TAI05_ID" \
  --arg tai05_name "$TALENTAI_TAI05_NAME" \
  --arg tai05_target "$TALENTAI_TAI05_TARGET" \
  '
    .workflows += [
      {
        id: $id,
        name: $name,
        target: $target
      },
      {
        id: $tai05_id,
        name: $tai05_name,
        target: $tai05_target
      }
    ]
    | .workflows |= sort_by(.name)
    | .requirements.credentials |= map(
        .usedByWorkflows = (
          (
            (.usedByWorkflows // [])
            + [$id]
            + (if .type == "postgres" then [$tai05_id] else [] end)
          )
          | unique
        )
      )
  ' "$TALENTAI_PACKAGE_MANIFEST" \
  > "$TALENTAI_TEMP_DIR/manifest.updated.json"

mv \
  "$TALENTAI_TEMP_DIR/manifest.updated.json" \
  "$TALENTAI_PACKAGE_MANIFEST"

jq -e \
  --arg id "$TALENTAI_TAI04_ID" \
  --arg name "$TALENTAI_TAI04_NAME" \
  --arg target "$TALENTAI_TAI04_TARGET" \
  --arg tai05_id "$TALENTAI_TAI05_ID" \
  --arg tai05_name "$TALENTAI_TAI05_NAME" \
  --arg tai05_target "$TALENTAI_TAI05_TARGET" \
  '
    (.packageFormatVersion == "1")
    and ((.workflows // []) | length == 5)
    and ([.workflows[].id] | unique | length == 5)
    and ([.workflows[].name] | unique | length == 5)
    and any(
      .workflows[];
      .id == $id and .name == $name and .target == $target
    )
    and any(
      .workflows[];
      .id == $tai05_id
      and .name == $tai05_name
      and .target == $tai05_target
    )
    and ((.folders // []) | length == 0)
    and (((.variables // []) | length) == 0)
    and (((.tags // []) | length) == 0)
    and (
      [(.requirements.credentials // [])[].type] | sort
      == (["openAiApi", "postgres"] | sort)
    )
    and all(
      (.requirements.credentials // [])[];
      (.usedByWorkflows // []) | index($id) != null
    )
    and all(
      (.requirements.credentials // [])[]
      | select(.type == "postgres");
      (.usedByWorkflows // []) | index($tai05_id) != null
    )
    and all(
      (.requirements.credentials // [])[]
      | select(.type == "openAiApi");
      (.usedByWorkflows // []) | index($tai05_id) == null
    )
  ' "$TALENTAI_PACKAGE_MANIFEST" >/dev/null || {
  echo 'Final TalentAI package manifest validation failed.' >&2
  exit 1
}

jq -e '
  (.versionId | type == "string" and length > 0)
  and (has("parentFolderId") and .parentFolderId == null)
  and (.isPublished | type == "boolean")
  and (.isArchived | type == "boolean")
  and
  all(
    .nodes[]
    | select(.type == "n8n-nodes-base.postgres");
    (.credentials.postgres.id // "") != ""
  )
  and all(
    .nodes[]
    | select(.type == "@n8n/n8n-nodes-langchain.lmChatOpenAi");
    (.credentials.openAiApi.id // "") != ""
  )
' "$TALENTAI_TAI04_PACKAGE" >/dev/null || {
  echo 'TAI-04 contains an unresolved credential binding.' >&2
  exit 1
}

jq -e '
  (.versionId | type == "string" and length > 0)
  and (has("parentFolderId") and .parentFolderId == null)
  and (.isPublished | type == "boolean")
  and (.isArchived | type == "boolean")
  and all(
    .nodes[]
    | select(.type == "n8n-nodes-base.postgres");
    (.credentials.postgres.id // "") != ""
  )
  and all(
    .nodes[];
    .type != "@n8n/n8n-nodes-langchain.lmChatOpenAi"
  )
' "$TALENTAI_TAI05_PACKAGE" >/dev/null || {
  echo 'TAI-05 contains an unresolved or unexpected credential binding.' >&2
  exit 1
}

jq -s -e '
  length == 5
  and all(.[]; .active == false)
' \
  "${TALENTAI_PACKAGE_WORKFLOWS[@]}" \
  "$TALENTAI_TAI04_PACKAGE" \
  "$TALENTAI_TAI05_PACKAGE" >/dev/null || {
  echo 'All release-candidate workflows must be inactive.' >&2
  exit 1
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

normalize_workflow \
  "$TALENTAI_TAI04_SOURCE" \
  "$TALENTAI_COMPARE_ROOT/tai04.committed.json"

normalize_workflow \
  "$TALENTAI_TAI04_PACKAGE" \
  "$TALENTAI_COMPARE_ROOT/tai04.package.json"

if ! cmp -s \
  "$TALENTAI_COMPARE_ROOT/tai04.committed.json" \
  "$TALENTAI_COMPARE_ROOT/tai04.package.json"; then
  echo 'Packaged TAI-04 drifted from committed source.' >&2
  exit 1
fi

normalize_workflow \
  "$TALENTAI_TAI05_SOURCE" \
  "$TALENTAI_COMPARE_ROOT/tai05.committed.json"

normalize_workflow \
  "$TALENTAI_TAI05_PACKAGE" \
  "$TALENTAI_COMPARE_ROOT/tai05.package.json"

if ! cmp -s \
  "$TALENTAI_COMPARE_ROOT/tai05.committed.json" \
  "$TALENTAI_COMPARE_ROOT/tai05.package.json"; then
  echo 'Packaged TAI-05 drifted from committed source.' >&2
  exit 1
fi

if rg -q -i \
  'sk-[A-Za-z0-9_-]{16,}|"(apiKey|password|accessToken|refreshToken|clientSecret|authorization)"[[:space:]]*:' \
  "$TALENTAI_PACKAGE_ROOT"; then
  echo 'A possible secret was detected in the TalentAI package.' >&2
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

mkdir -p "$TALENTAI_PRIVATE_DIR"

(
  cd "$TALENTAI_PACKAGE_ROOT"
  tar -czf "$TALENTAI_OUTPUT_PACKAGE" "${archive_members[@]}"
)

test -s "$TALENTAI_OUTPUT_PACKAGE"

echo "TalentAI MVP package created: $TALENTAI_OUTPUT_PACKAGE"
shasum -a 256 "$TALENTAI_OUTPUT_PACKAGE"
jq -r '.workflows[] | [.id, .name, .target] | @tsv' \
  "$TALENTAI_PACKAGE_MANIFEST"
