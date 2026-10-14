#!/usr/bin/env bash
# Jump to any checkpoint tag. Discards live work, keeps .env, node_modules,
# comparison/ outputs, and .claude/settings.local.json (all gitignored).
set -euo pipefail
cd "$(dirname "$0")/.."

tags() { printf '  %s\n' b1-start b1-frontmatter b1-done b2-start b2-tool-done b2-connected b2-codex; }

tag="${1:-}"
if [[ -z "$tag" ]] || ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "usage: scripts/jump.sh <tag>"; echo "tags:"; tags; exit 1
fi

git reset -q --hard
git clean -fdq
git checkout -q -B live "$tag"
# Codex skills dir must exist (empty) so the live `cp -r ... .agents/skills/` lands right.
mkdir -p .agents/skills

cd mcp-server
[[ -d node_modules ]] || npm ci --silent
rm -rf dist && npm run -s build
cd ..

echo "At $tag on branch 'live'."
[[ -f .claude/skills/alert-writer/SKILL.md ]] && echo "  skill: alert-writer ($(wc -l < .claude/skills/alert-writer/SKILL.md | tr -d ' ') lines)" || echo "  skill: none"
grep -q "registerTool" mcp-server/src/index.ts && echo "  mcp:   send_alert implemented" || echo "  mcp:   scaffold only"
[[ -f .mcp.json ]] && echo "  .mcp.json: registered" || echo "  .mcp.json: none"
[[ -f .agents/skills/alert-writer/SKILL.md ]] && echo "  codex skill: alert-writer" || echo "  codex skill: none"
