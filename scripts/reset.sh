#!/usr/bin/env bash
# Back to the start of a build: reset.sh b1 | reset.sh b2
set -euo pipefail
case "${1:-}" in
  b1) tag=b1-start ;;
  b2) tag=b2-start ;;
  *) echo "usage: scripts/reset.sh b1|b2"; exit 1 ;;
esac
# Every rehearsal starts with no Codex skill (jump.sh recreates the empty dir).
rm -rf "$(dirname "$0")/../.agents/skills"
exec "$(dirname "$0")/jump.sh" "$tag"
