#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_ENV_FILE="$TALENTAI_REPOSITORY_ROOT/.env"

if [ -e "$TALENTAI_ENV_FILE" ]; then
  echo '.env already exists. It was not modified.' >&2
  echo 'Do not use this script when migrating an existing n8n instance.' >&2
  exit 1
fi

command -v openssl >/dev/null 2>&1 || {
  echo 'openssl is required.' >&2
  exit 1
}

readonly TALENTAI_POSTGRES_ADMIN_PASSWORD="$(openssl rand -hex 24)"
readonly TALENTAI_N8N_DATABASE_PASSWORD="$(openssl rand -hex 24)"
readonly TALENTAI_APPLICATION_PASSWORD="$(openssl rand -hex 24)"
readonly TALENTAI_RUNNERS_AUTH_TOKEN="$(openssl rand -hex 32)"
readonly TALENTAI_N8N_ENCRYPTION_KEY="$(openssl rand -hex 32)"

umask 077

{
  printf '%s\n' 'N8N_VERSION=2.36.8'
  printf '%s\n' 'POSTGRES_VERSION=18.6'
  printf '%s\n' 'POSTGRES_USER=admin'
  printf 'POSTGRES_PASSWORD=%s\n' "$TALENTAI_POSTGRES_ADMIN_PASSWORD"
  printf '%s\n' 'POSTGRES_DB=n8n'
  printf '%s\n' 'POSTGRES_NON_ROOT_USER=n8n_app'
  printf 'POSTGRES_NON_ROOT_PASSWORD=%s\n' "$TALENTAI_N8N_DATABASE_PASSWORD"
  printf 'TALENTAI_DB_PASSWORD=%s\n' "$TALENTAI_APPLICATION_PASSWORD"
  printf 'RUNNERS_AUTH_TOKEN=%s\n' "$TALENTAI_RUNNERS_AUTH_TOKEN"
  printf 'N8N_ENCRYPTION_KEY=%s\n' "$TALENTAI_N8N_ENCRYPTION_KEY"
  printf '%s\n' 'N8N_HOST_PORT=5678'
  printf '%s\n' 'POSTGRES_HOST_PORT=5434'
  printf '%s\n' 'GENERIC_TIMEZONE=Asia/Tehran'
} > "$TALENTAI_ENV_FILE"

chmod 600 "$TALENTAI_ENV_FILE"

echo "Created $TALENTAI_ENV_FILE with generated local secrets."
echo 'Secret values were not printed.'
