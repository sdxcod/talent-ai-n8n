#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo 'Deprecated: use ./scripts/build-talentai-mvp-package.sh instead.' >&2
exec "$TALENTAI_SCRIPT_DIR/build-talentai-mvp-package.sh" "$@"
