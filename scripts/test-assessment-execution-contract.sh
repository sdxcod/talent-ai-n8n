#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_CONTRACT_TEST="$TALENTAI_REPOSITORY_ROOT/database/tests/T001__assessment_execution_contract.sql"

cd "$TALENTAI_REPOSITORY_ROOT"

if [ ! -f "$TALENTAI_CONTRACT_TEST" ]; then
  echo "Assessment execution contract test is missing: $TALENTAI_CONTRACT_TEST" >&2
  exit 1
fi

docker compose config --quiet

docker compose exec -T postgres sh -c '
  pg_isready -h localhost -U "$POSTGRES_USER" -d talentai
' >/dev/null

docker compose exec -T postgres sh -c '
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d talentai
' < "$TALENTAI_CONTRACT_TEST"

echo 'TalentAI assessment execution contract test passed and was rolled back.'
