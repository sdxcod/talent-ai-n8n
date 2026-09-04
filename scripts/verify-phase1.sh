#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo 'Deprecated: use ./scripts/verify-talentai.sh instead.' >&2
exec "$TALENTAI_SCRIPT_DIR/verify-talentai.sh" "$@"
