#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_QUERY_DIR="$TALENTAI_REPOSITORY_ROOT/database/queries"
readonly TALENTAI_CONTRACT_TEST="$TALENTAI_REPOSITORY_ROOT/database/tests/T005__technical_interview_invitation_contract.sql"
readonly TALENTAI_QUERY_TEST="$TALENTAI_REPOSITORY_ROOT/database/tests/T006__technical_interview_invitation_queries.sql"

cd "$TALENTAI_REPOSITORY_ROOT"

required_files=(
  "$TALENTAI_REPOSITORY_ROOT/database/migrations/V011__create_secure_interview_invitation.sql"
  "$TALENTAI_QUERY_DIR/Q022__issue_technical_interview_invitation.sql"
  "$TALENTAI_QUERY_DIR/Q023__claim_technical_interview_invitation.sql"
  "$TALENTAI_QUERY_DIR/Q024__revoke_technical_interview_invitation.sql"
  "$TALENTAI_QUERY_DIR/Q025__expire_technical_interview_invitations.sql"
  "$TALENTAI_CONTRACT_TEST"
  "$TALENTAI_QUERY_TEST"
)

for required_file in "${required_files[@]}"; do
  if [ ! -f "$required_file" ]; then
    echo "Technical interview invitation test input is missing: $required_file" >&2
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
CREATE FUNCTION pg_temp.issue_technical_interview_invitation(
  TEXT, UUID, UUID, UUID, TEXT, INTEGER
)
RETURNS TABLE (
  "invitationId" UUID,
  "issueStatus" TEXT,
  "canDeliver" BOOLEAN,
  "invitationToken" TEXT,
  "contractVersion" VARCHAR,
  "requestId" UUID,
  "assessmentId" UUID,
  "extractionId" UUID,
  status VARCHAR,
  "issueCount" INTEGER,
  "issuedAt" TIMESTAMP WITH TIME ZONE,
  "expiresAt" TIMESTAMP WITH TIME ZONE
)' "$TALENTAI_QUERY_DIR/Q022__issue_technical_interview_invitation.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.claim_technical_interview_invitation(
  TEXT, TEXT
)
RETURNS TABLE (
  "claimStatus" TEXT,
  "canContinue" BOOLEAN,
  "invitationId" UUID,
  "contractVersion" VARCHAR,
  "requestId" UUID,
  "assessmentId" UUID,
  "extractionId" UUID,
  status VARCHAR,
  "expiresAt" TIMESTAMP WITH TIME ZONE,
  "claimedAt" TIMESTAMP WITH TIME ZONE
)' "$TALENTAI_QUERY_DIR/Q023__claim_technical_interview_invitation.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.revoke_technical_interview_invitation(
  UUID, TEXT
)
RETURNS TABLE (
  "invitationId" UUID,
  "revokeStatus" TEXT,
  status VARCHAR,
  "revokedNow" BOOLEAN,
  "revokedAt" TIMESTAMP WITH TIME ZONE
)' "$TALENTAI_QUERY_DIR/Q024__revoke_technical_interview_invitation.sql"

  emit_sql_function '
CREATE FUNCTION pg_temp.expire_technical_interview_invitations()
RETURNS TABLE (
  "expiredInvitationCount" INTEGER
)' "$TALENTAI_QUERY_DIR/Q025__expire_technical_interview_invitations.sql"

  sed -n '1,$p' "$TALENTAI_QUERY_TEST"
  printf '%s\n' 'ROLLBACK;'
} | docker compose exec -T postgres sh -c '
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d talentai
'

echo 'TalentAI technical interview invitation tests passed and were rolled back.'
