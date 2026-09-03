#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_CORRELATION_QUERY="$TALENTAI_REPOSITORY_ROOT/database/queries/Q021__verify_phase45_end_to_end_correlation.sql"
readonly TALENTAI_EXTRACTION_ID="${1:-}"

if [[ ! "$TALENTAI_EXTRACTION_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]]; then
  echo 'Usage: ./scripts/verify-phase45-correlation.sh <phase3-extraction-uuid>' >&2
  exit 1
fi

test -f "$TALENTAI_CORRELATION_QUERY" || {
  echo "Correlation query is missing: $TALENTAI_CORRELATION_QUERY" >&2
  exit 1
}

cd "$TALENTAI_REPOSITORY_ROOT"

docker compose config --quiet

docker compose exec -T postgres sh -c '
  pg_isready -h localhost -U "$POSTGRES_USER" -d talentai
' >/dev/null

docker compose exec -T postgres \
  psql \
    -v ON_ERROR_STOP=1 \
    -v extraction_id="$TALENTAI_EXTRACTION_ID" \
    -U admin \
    -d talentai \
  < "$TALENTAI_CORRELATION_QUERY"

echo 'TalentAI Phase 3 through Phase 5 correlation verification passed.'
