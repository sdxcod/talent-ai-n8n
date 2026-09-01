#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_QUERY_DIR="$TALENTAI_REPOSITORY_ROOT/database/queries"
readonly TALENTAI_TEST_BODY="$TALENTAI_REPOSITORY_ROOT/database/tests/T002__assessment_execution_queries.sql"

cd "$TALENTAI_REPOSITORY_ROOT"

required_files=(
  "$TALENTAI_QUERY_DIR/Q004__claim_assessment_execution.sql"
  "$TALENTAI_QUERY_DIR/Q005__advance_assessment_execution.sql"
  "$TALENTAI_QUERY_DIR/Q006__attach_resume_extraction.sql"
  "$TALENTAI_QUERY_DIR/Q007__complete_assessment_execution.sql"
  "$TALENTAI_QUERY_DIR/Q008__fail_assessment_execution.sql"
  "$TALENTAI_QUERY_DIR/Q009__load_completed_assessment_execution.sql"
  "$TALENTAI_QUERY_DIR/Q010__persist_operational_grade_assessment.sql"
  "$TALENTAI_QUERY_DIR/Q011__expire_stale_assessment_executions.sql"
  "$TALENTAI_TEST_BODY"
)

for required_file in "${required_files[@]}"; do
  if [ ! -f "$required_file" ]; then
    echo "Assessment execution query test input is missing: $required_file" >&2
    exit 1
  fi
done

docker compose config --quiet

docker compose exec -T postgres sh -c '
  pg_isready -h localhost -U "$POSTGRES_USER" -d talentai
' >/dev/null

emit_sql_function() {
  local function_header="$1"
  local query_file="$2"

  printf '%s\n' "$function_header"
  printf '%s\n' 'LANGUAGE SQL AS $talentai_query$'
  sed -n '1,$p' "$query_file"
  printf '%s\n' '$talentai_query$;'
}

{
  printf '%s\n' 'BEGIN;'
  printf '%s\n' 'CREATE TEMP TABLE _talentai_query_contract_bootstrap (id INTEGER);'

  emit_sql_function '
CREATE FUNCTION pg_temp.claim_assessment_execution(
  TEXT, TEXT, TEXT, TEXT, TEXT
)
RETURNS TABLE (
  "requestId" UUID,
  "claimStatus" TEXT,
  "canContinue" BOOLEAN,
  status VARCHAR,
  "currentStage" VARCHAR,
  "attemptCount" INTEGER,
  "extractionId" UUID,
  "assessmentId" UUID,
  "failureCategory" VARCHAR,
  "failureCode" VARCHAR,
  "failureMessage" VARCHAR,
  retryable BOOLEAN,
  "startedAt" TIMESTAMP WITH TIME ZONE,
  "updatedAt" TIMESTAMP WITH TIME ZONE,
  "completedAt" TIMESTAMP WITH TIME ZONE,
  "failedAt" TIMESTAMP WITH TIME ZONE
)' "$TALENTAI_QUERY_DIR/Q004__claim_assessment_execution.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.advance_assessment_execution(
  UUID, TEXT, TEXT
)
RETURNS TABLE (
  "requestId" UUID,
  status VARCHAR,
  "currentStage" VARCHAR,
  "attemptCount" INTEGER,
  "updatedAt" TIMESTAMP WITH TIME ZONE
)' "$TALENTAI_QUERY_DIR/Q005__advance_assessment_execution.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.attach_resume_extraction(
  UUID, TEXT, UUID
)
RETURNS TABLE (
  "requestId" UUID,
  status VARCHAR,
  "currentStage" VARCHAR,
  "attemptCount" INTEGER,
  "extractionId" UUID,
  "updatedAt" TIMESTAMP WITH TIME ZONE
)' "$TALENTAI_QUERY_DIR/Q006__attach_resume_extraction.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.complete_assessment_execution(
  UUID, TEXT, UUID
)
RETURNS TABLE (
  "requestId" UUID,
  status VARCHAR,
  "currentStage" VARCHAR,
  "attemptCount" INTEGER,
  "extractionId" UUID,
  "assessmentId" UUID,
  "startedAt" TIMESTAMP WITH TIME ZONE,
  "completedAt" TIMESTAMP WITH TIME ZONE
)' "$TALENTAI_QUERY_DIR/Q007__complete_assessment_execution.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.fail_assessment_execution(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN
)
RETURNS TABLE (
  "requestId" UUID,
  status VARCHAR,
  "currentStage" VARCHAR,
  "attemptCount" INTEGER,
  "extractionId" UUID,
  "failureCategory" VARCHAR,
  "failureCode" VARCHAR,
  "failureMessage" VARCHAR,
  retryable BOOLEAN,
  "startedAt" TIMESTAMP WITH TIME ZONE,
  "failedAt" TIMESTAMP WITH TIME ZONE
)' "$TALENTAI_QUERY_DIR/Q008__fail_assessment_execution.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.load_completed_assessment_execution(
  UUID
)
RETURNS TABLE (
  "requestId" UUID,
  "attemptCount" INTEGER,
  "executionStatus" VARCHAR,
  "startedAt" TIMESTAMP WITH TIME ZONE,
  "completedAt" TIMESTAMP WITH TIME ZONE,
  "assessmentId" UUID,
  "extractionId" UUID,
  "gradeGuideId" UUID,
  "gradeGuideVersion" VARCHAR,
  "targetGradeCode" VARCHAR,
  "scoringModel" VARCHAR,
  "promptVersion" VARCHAR,
  "engineVersion" VARCHAR,
  "dimensionAssessments" JSONB,
  "overallScore" NUMERIC,
  "minimumOverallScore" NUMERIC,
  "thresholdMet" BOOLEAN,
  "mandatoryDimensionsMet" BOOLEAN,
  decision VARCHAR,
  "reviewReasons" JSONB,
  "modelWarnings" JSONB,
  "assessmentSummary" TEXT,
  "assessmentStatus" VARCHAR,
  "assessmentCreatedAt" TIMESTAMP WITH TIME ZONE,
  "positionCode" VARCHAR,
  "jobDescription" TEXT,
  candidate JSONB
)' "$TALENTAI_QUERY_DIR/Q009__load_completed_assessment_execution.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.persist_operational_grade_assessment(
  UUID, TEXT, UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT,
  JSONB, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN, TEXT, JSONB, JSONB, TEXT
)
RETURNS TABLE (
  "requestId" UUID,
  "assessmentId" UUID,
  "workflowExecutionId" VARCHAR,
  "extractionId" UUID,
  "gradeGuideId" UUID,
  "gradeGuideVersion" VARCHAR,
  "targetGradeCode" VARCHAR,
  "scoringModel" VARCHAR,
  "promptVersion" VARCHAR,
  "engineVersion" VARCHAR,
  "dimensionAssessments" JSONB,
  "overallScore" NUMERIC,
  "minimumOverallScore" NUMERIC,
  "thresholdMet" BOOLEAN,
  "mandatoryDimensionsMet" BOOLEAN,
  decision VARCHAR,
  "reviewReasons" JSONB,
  "modelWarnings" JSONB,
  "assessmentSummary" TEXT,
  status VARCHAR,
  "createdAt" TIMESTAMP WITH TIME ZONE,
  "wasInserted" BOOLEAN
)' "$TALENTAI_QUERY_DIR/Q010__persist_operational_grade_assessment.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.expire_stale_assessment_executions(
  INTEGER
)
RETURNS TABLE (
  "expiredExecutionCount" INTEGER
)' "$TALENTAI_QUERY_DIR/Q011__expire_stale_assessment_executions.sql"

  sed -n '1,$p' "$TALENTAI_TEST_BODY"
  printf '%s\n' 'ROLLBACK;'
} | docker compose exec -T postgres sh -c '
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d talentai
'

echo 'TalentAI assessment execution query tests passed and were rolled back.'
