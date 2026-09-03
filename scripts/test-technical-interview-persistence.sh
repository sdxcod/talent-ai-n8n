#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_QUERY_DIR="$TALENTAI_REPOSITORY_ROOT/database/queries"
readonly TALENTAI_CONTRACT_TEST="$TALENTAI_REPOSITORY_ROOT/database/tests/T003__technical_interview_persistence_contract.sql"
readonly TALENTAI_QUERY_TEST="$TALENTAI_REPOSITORY_ROOT/database/tests/T004__technical_interview_queries.sql"

cd "$TALENTAI_REPOSITORY_ROOT"

required_files=(
  "$TALENTAI_REPOSITORY_ROOT/database/migrations/V009__create_technical_interview_persistence.sql"
  "$TALENTAI_QUERY_DIR/Q013__claim_technical_interview_session.sql"
  "$TALENTAI_QUERY_DIR/Q014__persist_technical_question_set.sql"
  "$TALENTAI_QUERY_DIR/Q015__persist_technical_interview_answers.sql"
  "$TALENTAI_QUERY_DIR/Q016__apply_technical_answer_evaluations.sql"
  "$TALENTAI_QUERY_DIR/Q017__complete_technical_interview.sql"
  "$TALENTAI_QUERY_DIR/Q018__load_completed_technical_interview.sql"
  "$TALENTAI_CONTRACT_TEST"
  "$TALENTAI_QUERY_TEST"
)

for required_file in "${required_files[@]}"; do
  if [ ! -f "$required_file" ]; then
    echo "Technical interview persistence test input is missing: $required_file" >&2
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
  sed -n '1,$p' "$TALENTAI_CONTRACT_TEST"

  emit_sql_function '
CREATE FUNCTION pg_temp.claim_technical_interview_session(
  TEXT, TEXT, TEXT, TEXT, TEXT
)
RETURNS TABLE (
  "sessionId" UUID,
  "claimStatus" TEXT,
  "canContinue" BOOLEAN,
  status VARCHAR,
  "currentStage" VARCHAR,
  "attemptCount" INTEGER,
  "requestId" UUID,
  "assessmentId" UUID,
  "extractionId" UUID,
  "failureCategory" VARCHAR,
  "failureCode" VARCHAR,
  "failureMessage" VARCHAR,
  retryable BOOLEAN,
  "startedAt" TIMESTAMP WITH TIME ZONE,
  "updatedAt" TIMESTAMP WITH TIME ZONE,
  "completedAt" TIMESTAMP WITH TIME ZONE,
  "failedAt" TIMESTAMP WITH TIME ZONE
)' "$TALENTAI_QUERY_DIR/Q013__claim_technical_interview_session.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.persist_technical_question_set(
  UUID, TEXT, TEXT, JSONB, TEXT, TEXT
)
RETURNS TABLE (
  "questionSetId" UUID,
  "sessionId" UUID,
  round VARCHAR,
  version INTEGER,
  "contentHash" VARCHAR,
  "questionCount" INTEGER,
  "generationModel" VARCHAR,
  "promptVersion" VARCHAR,
  "wasInserted" BOOLEAN,
  "currentStage" TEXT
)' "$TALENTAI_QUERY_DIR/Q014__persist_technical_question_set.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.persist_technical_interview_answers(
  UUID, TEXT, UUID, JSONB
)
RETURNS TABLE (
  "sessionId" UUID,
  "questionSetId" UUID,
  round VARCHAR,
  "persistedCount" INTEGER,
  "expectedCount" INTEGER,
  complete BOOLEAN,
  "currentStage" TEXT
)' "$TALENTAI_QUERY_DIR/Q015__persist_technical_interview_answers.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.apply_technical_answer_evaluations(
  UUID, TEXT, JSONB
)
RETURNS TABLE (
  "sessionId" UUID,
  "suppliedCount" INTEGER,
  "answerCount" INTEGER,
  "evaluatedCount" INTEGER,
  complete BOOLEAN,
  "currentStage" TEXT
)' "$TALENTAI_QUERY_DIR/Q016__apply_technical_answer_evaluations.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.complete_technical_interview(
  UUID, TEXT, JSONB
)
RETURNS TABLE (
  "resultId" UUID,
  "sessionId" UUID,
  "resultVersion" INTEGER,
  "assignedGradeCode" VARCHAR,
  "overallScore" NUMERIC,
  "resultPayload" JSONB,
  "wasInserted" BOOLEAN,
  status VARCHAR,
  "currentStage" VARCHAR,
  "attemptCount" INTEGER,
  "completedAt" TIMESTAMP WITH TIME ZONE
)' "$TALENTAI_QUERY_DIR/Q017__complete_technical_interview.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.load_completed_technical_interview(
  TEXT, UUID, UUID
)
RETURNS TABLE (
  "sessionId" UUID,
  "contractVersion" VARCHAR,
  "requestId" UUID,
  "assessmentId" UUID,
  "extractionId" UUID,
  "attemptCount" INTEGER,
  status VARCHAR,
  "currentStage" VARCHAR,
  "startedAt" TIMESTAMP WITH TIME ZONE,
  "completedAt" TIMESTAMP WITH TIME ZONE,
  "resultId" UUID,
  "resultVersion" INTEGER,
  "resultPayload" JSONB
)' "$TALENTAI_QUERY_DIR/Q018__load_completed_technical_interview.sql"

  sed -n '1,$p' "$TALENTAI_QUERY_TEST"
  printf '%s\n' 'ROLLBACK;'
} | docker compose exec -T postgres sh -c '
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d talentai
'

echo 'TalentAI technical interview persistence tests passed and were rolled back.'
