#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"

cd "$TALENTAI_REPOSITORY_ROOT"

docker compose config --quiet

docker compose exec -T postgres sh -c '
  pg_isready -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB"
' >/dev/null

for migration_file in database/migrations/*.sql; do
  echo "Applying migration: $(basename "$migration_file")"
  docker compose exec -T postgres sh -c '
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d talentai
  ' < "$migration_file"
done

for seed_file in database/seeds/*.sql; do
  echo "Applying seed: $(basename "$seed_file")"
  docker compose exec -T postgres sh -c '
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d talentai
  ' < "$seed_file"
done

docker compose exec -T postgres sh -c '
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d talentai
' <<'SQL'
SELECT
  to_regclass('talentai.resume_extraction') AS resume_extraction,
  to_regclass('talentai.grade_guide') AS grade_guide,
  to_regclass('talentai.grade_assessment') AS grade_assessment;
SQL

echo 'TalentAI database migrations and reference seeds were applied.'
