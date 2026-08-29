#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_WORKFLOW_DIR="$TALENTAI_REPOSITORY_ROOT/workflows/phase-1"

cd "$TALENTAI_REPOSITORY_ROOT"

required_workflow_files=(
  "$TALENTAI_WORKFLOW_DIR/TAI-01-resume-intake-extraction-v2.json"
  "$TALENTAI_WORKFLOW_DIR/TAI-02-grade-guide-resolver-v1.json"
  "$TALENTAI_WORKFLOW_DIR/TAI-03-evidence-scoring-grade-engine-v1.json"
  "$TALENTAI_WORKFLOW_DIR/manifest.json"
)

for required_workflow_file in "${required_workflow_files[@]}"; do
  if [ ! -f "$required_workflow_file" ]; then
    echo "Required workflow file is missing: $required_workflow_file" >&2
    exit 1
  fi
done

jq empty "${required_workflow_files[@]}"

jq -e '
  (.workflows | length == 3)
  and (.workflowDependencies | length == 2)
  and (
    (.requiredCredentialTypes | sort)
    == (["openAiApi", "postgres"] | sort)
  )
' "$TALENTAI_WORKFLOW_DIR/manifest.json" >/dev/null

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
' "$TALENTAI_WORKFLOW_DIR"/TAI-*.json >/dev/null; then
  echo 'A test or obsolete node remains in a committed workflow.' >&2
  exit 1
fi

if rg -q '"pinData"|"staticData"|"credentials"' "$TALENTAI_WORKFLOW_DIR"; then
  echo 'Committed workflow files contain private runtime data or credential references.' >&2
  exit 1
fi

docker compose config --quiet

readonly TALENTAI_N8N_ENDPOINT="$(docker compose port n8n 5678)"

curl -fsS "http://$TALENTAI_N8N_ENDPOINT/healthz"
echo

docker compose exec -T n8n n8n --version

docker compose exec -T postgres sh -c '
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d talentai
' <<'SQL'
DO $verification$
DECLARE
  active_guide_count INTEGER;
  dimension_count INTEGER;
  grade_count INTEGER;
  total_weight INTEGER;
BEGIN
  IF to_regclass('talentai.resume_extraction') IS NULL THEN
    RAISE EXCEPTION 'talentai.resume_extraction is missing';
  END IF;

  IF to_regclass('talentai.grade_guide') IS NULL THEN
    RAISE EXCEPTION 'talentai.grade_guide is missing';
  END IF;

  IF to_regclass('talentai.grade_assessment') IS NULL THEN
    RAISE EXCEPTION 'talentai.grade_assessment is missing';
  END IF;

  SELECT
    count(*),
    max(jsonb_array_length(guide -> 'dimensions')),
    max(jsonb_array_length(guide -> 'grades'))
  INTO
    active_guide_count,
    dimension_count,
    grade_count
  FROM talentai.grade_guide
  WHERE position_code = 'JAVA_BACKEND'
    AND status = 'ACTIVE';

  SELECT SUM((dimension ->> 'weight')::INTEGER)
  INTO total_weight
  FROM talentai.grade_guide AS grade_guide,
       LATERAL jsonb_array_elements(
         grade_guide.guide -> 'dimensions'
       ) AS dimension
  WHERE grade_guide.position_code = 'JAVA_BACKEND'
    AND grade_guide.status = 'ACTIVE';

  IF active_guide_count <> 1 THEN
    RAISE EXCEPTION 'Expected one active JAVA_BACKEND guide, found %', active_guide_count;
  END IF;

  IF dimension_count <> 7 OR grade_count <> 3 OR total_weight <> 100 THEN
    RAISE EXCEPTION
      'Invalid guide structure: dimensions %, grades %, total weight %',
      dimension_count,
      grade_count,
      total_weight;
  END IF;
END
$verification$;

SELECT
  position_code,
  guide_version,
  guide_schema_version,
  status,
  jsonb_array_length(guide -> 'dimensions') AS dimensions_count,
  jsonb_array_length(guide -> 'grades') AS grades_count
FROM talentai.grade_guide
WHERE position_code = 'JAVA_BACKEND'
  AND status = 'ACTIVE';
SQL

docker compose exec -T postgres \
  psql \
    -v ON_ERROR_STOP=1 \
    -U talentai_app \
    -d talentai <<'SQL'
SELECT count(*) AS active_guide_count
FROM talentai.grade_guide
WHERE status = 'ACTIVE';
SQL

echo 'TalentAI Phase 1 repository and runtime verification passed.'
