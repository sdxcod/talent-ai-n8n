#!/usr/bin/env bash
set -Eeuo pipefail

readonly TALENTAI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TALENTAI_ROOT="$(cd "$TALENTAI_SCRIPT_DIR/.." && pwd)"
readonly TALENTAI_VERSION="${1:-2.0.0}"
readonly TALENTAI_PRIVATE_DIR="$TALENTAI_ROOT/exports/private"
readonly TALENTAI_SOURCE_PACKAGE="$TALENTAI_PRIVATE_DIR/TalentAI-phase-1-step3.1B.n8np"
readonly TALENTAI_RELEASE_PACKAGE="$TALENTAI_PRIVATE_DIR/TalentAI-phase3-release2-v$TALENTAI_VERSION.n8np"

[[ "$TALENTAI_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo 'Version must use MAJOR.MINOR.PATCH.' >&2
  exit 1
}

cd "$TALENTAI_ROOT"
node scripts/test-phase3-calibration.mjs
node scripts/test-phase3-handoff.mjs
./scripts/build-step3b-upgrade-package.sh
mv -- "$TALENTAI_SOURCE_PACKAGE" "$TALENTAI_RELEASE_PACKAGE"
shasum -a 256 "$TALENTAI_RELEASE_PACKAGE"
echo "Phase 3 Release 2 package created: $TALENTAI_RELEASE_PACKAGE"
