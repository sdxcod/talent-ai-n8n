#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_STATUS="${1:-}"
readonly TALENTAI_LIMIT="${2:-20}"

if [[ -n "$TALENTAI_STATUS" ]] \
  && [[ ! "$TALENTAI_STATUS" =~ ^(RUNNING|COMPLETED|FAILED)$ ]]; then
  echo 'Status must be RUNNING, COMPLETED, FAILED, or empty.' >&2
  exit 1
fi

if [[ ! "$TALENTAI_LIMIT" =~ ^[0-9]+$ ]] \
  || (( TALENTAI_LIMIT < 1 || TALENTAI_LIMIT > 200 )); then
  echo 'Limit must be an integer from 1 through 200.' >&2
  exit 1
fi

cd "$TALENTAI_REPOSITORY_ROOT"

docker compose exec -T postgres \
  psql \
    -v ON_ERROR_STOP=1 \
    -v status="$TALENTAI_STATUS" \
    -v row_limit="$TALENTAI_LIMIT" \
    -U admin \
    -d talentai <<'SQL'
SELECT
    request_id,
    status,
    current_stage,
    attempt_count,
    failure_category,
    failure_code,
    retryable,
    duration_seconds,
    stale,
    started_at,
    completed_at,
    failed_at
FROM talentai.assessment_execution_observability
WHERE :'status' = '' OR status = :'status'
ORDER BY started_at DESC
LIMIT :row_limit;
SQL
