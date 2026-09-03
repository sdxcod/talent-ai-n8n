#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_DATABASE='talentai'
readonly TALENTAI_APPLICATION_USER='talentai_app'

required_variables=(
  POSTGRES_USER
  POSTGRES_PASSWORD
  POSTGRES_DB
  POSTGRES_NON_ROOT_USER
  POSTGRES_NON_ROOT_PASSWORD
  TALENTAI_DB_PASSWORD
)

for required_variable in "${required_variables[@]}"; do
  if [ -z "${!required_variable:-}" ]; then
    echo "Required environment variable is missing: $required_variable" >&2
    exit 1
  fi
done

psql \
  -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname postgres \
  --set=n8n_database="$POSTGRES_DB" \
  --set=n8n_user="$POSTGRES_NON_ROOT_USER" \
  --set=n8n_password="$POSTGRES_NON_ROOT_PASSWORD" \
  --set=talentai_database="$TALENTAI_DATABASE" \
  --set=talentai_user="$TALENTAI_APPLICATION_USER" \
  --set=talentai_password="$TALENTAI_DB_PASSWORD" \
  --set=postgres_admin="$POSTGRES_USER" <<'SQL'
SELECT format(
  'CREATE ROLE %I LOGIN PASSWORD %L',
  :'n8n_user',
  :'n8n_password'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_roles WHERE rolname = :'n8n_user'
)
\gexec

SELECT format(
  'CREATE ROLE %I LOGIN PASSWORD %L',
  :'talentai_user',
  :'talentai_password'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_roles WHERE rolname = :'talentai_user'
)
\gexec

SELECT format(
  'CREATE DATABASE %I OWNER %I',
  :'talentai_database',
  :'postgres_admin'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_database WHERE datname = :'talentai_database'
)
\gexec

SELECT format(
  'GRANT ALL PRIVILEGES ON DATABASE %I TO %I',
  :'n8n_database',
  :'n8n_user'
)
\gexec

SELECT format(
  'GRANT CONNECT ON DATABASE %I TO %I',
  :'talentai_database',
  :'talentai_user'
)
\gexec
SQL

psql \
  -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=n8n_user="$POSTGRES_NON_ROOT_USER" <<'SQL'
SELECT format(
  'GRANT USAGE, CREATE ON SCHEMA public TO %I',
  :'n8n_user'
)
\gexec
SQL

shopt -s nullglob

migration_files=(
  /docker-entrypoint-initdb.d/database/migrations/*.sql
)

if [ "${#migration_files[@]}" -eq 0 ]; then
  echo 'No TalentAI database migrations were found.' >&2
  exit 1
fi

for migration_file in "${migration_files[@]}"; do
  echo "Applying TalentAI migration: $(basename "$migration_file")"
  psql \
    -v ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" \
    --dbname "$TALENTAI_DATABASE" \
    --file "$migration_file"
done

seed_files=(
  /docker-entrypoint-initdb.d/database/seeds/*.sql
)

for seed_file in "${seed_files[@]}"; do
  echo "Applying TalentAI seed: $(basename "$seed_file")"
  psql \
    -v ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" \
    --dbname "$TALENTAI_DATABASE" \
    --file "$seed_file"
done

echo 'PostgreSQL initialization for n8n and TalentAI completed.'
