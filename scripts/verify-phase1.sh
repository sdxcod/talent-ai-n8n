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

required_operational_files=(
  "$TALENTAI_REPOSITORY_ROOT/database/migrations/V005__create_assessment_execution.sql"
  "$TALENTAI_REPOSITORY_ROOT/database/queries/Q004__claim_assessment_execution.sql"
  "$TALENTAI_REPOSITORY_ROOT/database/queries/Q005__advance_assessment_execution.sql"
  "$TALENTAI_REPOSITORY_ROOT/database/queries/Q006__attach_resume_extraction.sql"
  "$TALENTAI_REPOSITORY_ROOT/database/queries/Q007__complete_assessment_execution.sql"
  "$TALENTAI_REPOSITORY_ROOT/database/queries/Q008__fail_assessment_execution.sql"
  "$TALENTAI_REPOSITORY_ROOT/database/queries/Q009__load_completed_assessment_execution.sql"
  "$TALENTAI_REPOSITORY_ROOT/database/queries/Q010__persist_operational_grade_assessment.sql"
  "$TALENTAI_REPOSITORY_ROOT/database/migrations/V006__link_grade_assessment_to_execution.sql"
  "$TALENTAI_REPOSITORY_ROOT/database/tests/T001__assessment_execution_contract.sql"
  "$TALENTAI_REPOSITORY_ROOT/database/tests/T002__assessment_execution_queries.sql"
  "$TALENTAI_SCRIPT_DIR/test-assessment-execution-contract.sh"
  "$TALENTAI_SCRIPT_DIR/test-assessment-execution-queries.sh"
  "$TALENTAI_SCRIPT_DIR/test-phase1-operational-workflows.sh"
)

for required_workflow_file in "${required_workflow_files[@]}"; do
  if [ ! -f "$required_workflow_file" ]; then
    echo "Required workflow file is missing: $required_workflow_file" >&2
    exit 1
  fi
done

for required_operational_file in "${required_operational_files[@]}"; do
  if [ ! -f "$required_operational_file" ]; then
    echo "Required operational file is missing: $required_operational_file" >&2
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
readonly TALENTAI_EXPECTED_PUBLIC_URL="http://$TALENTAI_N8N_ENDPOINT"

curl -fsS "$TALENTAI_EXPECTED_PUBLIC_URL/healthz"
echo

readonly TALENTAI_ACTUAL_EDITOR_BASE_URL="$(
  docker compose exec -T n8n printenv N8N_EDITOR_BASE_URL
)"
readonly TALENTAI_ACTUAL_WEBHOOK_URL="$(
  docker compose exec -T n8n printenv N8N_WEBHOOK_URL
)"

if [ "$TALENTAI_ACTUAL_EDITOR_BASE_URL" != "$TALENTAI_EXPECTED_PUBLIC_URL" ]; then
  echo 'N8N_EDITOR_BASE_URL does not match the published n8n endpoint.' >&2
  echo "Expected: $TALENTAI_EXPECTED_PUBLIC_URL" >&2
  echo "Actual:   $TALENTAI_ACTUAL_EDITOR_BASE_URL" >&2
  exit 1
fi

if [ "$TALENTAI_ACTUAL_WEBHOOK_URL" != "$TALENTAI_EXPECTED_PUBLIC_URL" ]; then
  echo 'N8N_WEBHOOK_URL does not match the published n8n endpoint.' >&2
  echo "Expected: $TALENTAI_EXPECTED_PUBLIC_URL" >&2
  echo "Actual:   $TALENTAI_ACTUAL_WEBHOOK_URL" >&2
  exit 1
fi

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
  missing_runtime_privileges TEXT[];
  execution_column_count INTEGER;
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

  IF to_regclass('talentai.assessment_execution') IS NULL THEN
    RAISE EXCEPTION 'talentai.assessment_execution is missing';
  END IF;

  SELECT count(*)
  INTO execution_column_count
  FROM information_schema.columns
  WHERE table_schema = 'talentai'
    AND table_name = 'assessment_execution'
    AND column_name IN (
      'request_id',
      'input_fingerprint',
      'initial_workflow_execution_id',
      'last_workflow_execution_id',
      'position_code',
      'target_grade_code',
      'status',
      'current_stage',
      'attempt_count',
      'extraction_id',
      'assessment_id',
      'failure_category',
      'failure_code',
      'failure_message',
      'retryable',
      'started_at',
      'updated_at',
      'completed_at',
      'failed_at'
    );

  IF execution_column_count <> 19 THEN
    RAISE EXCEPTION
      'assessment_execution contract is incomplete: expected 19 columns, found %',
      execution_column_count;
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

  SELECT ARRAY_AGG(privilege_name ORDER BY privilege_name)
  INTO missing_runtime_privileges
  FROM (
    VALUES
      (
        'USAGE on schema talentai',
        has_schema_privilege('talentai_app', 'talentai', 'USAGE')
      ),
      (
        'SELECT on talentai.resume_extraction',
        has_table_privilege(
          'talentai_app',
          'talentai.resume_extraction',
          'SELECT'
        )
      ),
      (
        'INSERT on talentai.resume_extraction',
        has_table_privilege(
          'talentai_app',
          'talentai.resume_extraction',
          'INSERT'
        )
      ),
      (
        'SELECT on talentai.grade_guide',
        has_table_privilege(
          'talentai_app',
          'talentai.grade_guide',
          'SELECT'
        )
      ),
      (
        'SELECT on talentai.grade_assessment',
        has_table_privilege(
          'talentai_app',
          'talentai.grade_assessment',
          'SELECT'
        )
      ),
      (
        'INSERT on talentai.grade_assessment',
        has_table_privilege(
          'talentai_app',
          'talentai.grade_assessment',
          'INSERT'
        )
      ),
      (
        'SELECT on talentai.assessment_execution',
        has_table_privilege(
          'talentai_app',
          'talentai.assessment_execution',
          'SELECT'
        )
      ),
      (
        'INSERT on talentai.assessment_execution',
        has_table_privilege(
          'talentai_app',
          'talentai.assessment_execution',
          'INSERT'
        )
      ),
      (
        'UPDATE on talentai.assessment_execution',
        has_table_privilege(
          'talentai_app',
          'talentai.assessment_execution',
          'UPDATE'
        )
      )
  ) AS runtime_privilege(privilege_name, is_granted)
  WHERE NOT COALESCE(is_granted, FALSE);

  IF missing_runtime_privileges IS NOT NULL THEN
    RAISE EXCEPTION
      'talentai_app is missing runtime privileges: %',
      array_to_string(missing_runtime_privileges, ', ');
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

"$TALENTAI_SCRIPT_DIR/test-assessment-execution-contract.sh"
"$TALENTAI_SCRIPT_DIR/test-assessment-execution-queries.sh"
"$TALENTAI_SCRIPT_DIR/test-phase1-operational-workflows.sh"

echo 'TalentAI Phase 1 repository and runtime verification passed.'
