#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_REPOSITORY_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_ENV_FILE="$TALENTAI_REPOSITORY_ROOT/.env"

cd "$TALENTAI_REPOSITORY_ROOT"

required_commands=(curl docker jq rg)

for required_command in "${required_commands[@]}"; do
  command -v "$required_command" >/dev/null 2>&1 || {
    echo "Required command is missing: $required_command" >&2
    exit 1
  }
done

if [ ! -f "$TALENTAI_ENV_FILE" ]; then
  "$TALENTAI_SCRIPT_DIR/create-local-env.sh"
else
  echo 'Existing .env detected; preserving its ports, passwords, and encryption key.'
fi

docker compose config --quiet
docker compose pull
docker compose up -d

readonly TALENTAI_N8N_ENDPOINT="$(docker compose port n8n 5678)"
TALENTAI_N8N_HEALTHY=false

for attempt in {1..60}; do
  if curl -fsS "http://$TALENTAI_N8N_ENDPOINT/healthz" >/dev/null 2>&1; then
    TALENTAI_N8N_HEALTHY=true
    break
  fi

  sleep 2
done

if [ "$TALENTAI_N8N_HEALTHY" != true ]; then
  echo "n8n did not become healthy at http://$TALENTAI_N8N_ENDPOINT within 120 seconds." >&2
  echo 'Inspect the services with: docker compose ps' >&2
  echo 'Inspect the logs with: docker compose logs --tail=150 n8n n8n-runner postgres' >&2
  exit 1
fi

unset TALENTAI_N8N_HEALTHY

"$TALENTAI_SCRIPT_DIR/apply-database.sh"
"$TALENTAI_SCRIPT_DIR/verify-phase1.sh"

echo
echo 'TalentAI local stack is ready.'
echo "Open the n8n editor at: http://$TALENTAI_N8N_ENDPOINT"
echo 'Continue with owner setup, workflow import, and credential assignment in README.md.'
