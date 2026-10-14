#!/usr/bin/env bash
# Start Codex CLI in this repo with .env loaded and only the alerts MCP server.
# Uses `codex` from PATH, or the CLI bundled with the Codex desktop app.
# Extra args pass through, e.g. scripts/codex.sh exec "..."
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$(pwd)"
[[ -f .env ]] || { echo "Missing .env (cp .env.example .env)"; exit 1; }

codex_bin="$(command -v codex || true)"
[[ -n "$codex_bin" ]] || codex_bin="/Applications/ChatGPT.app/Contents/Resources/codex"
[[ -x "$codex_bin" ]] || { echo "Codex CLI not found (brew install --cask codex)"; exit 1; }

# Export only what the alerts server needs.
export PRISMATIC_ALERT_WEBHOOK_URL="$(set -a; source .env; echo "${PRISMATIC_ALERT_WEBHOOK_URL:-}")"
export ALERT_DRY_RUN="$(set -a; source .env; echo "${ALERT_DRY_RUN:-0}")"
unset SLACK_WEBHOOK_URL

# .codex/config.toml (loaded because this repo is trusted in ~/.codex/config.toml)
# turns off apps/connectors and plugins; node_repl comes from the user config.
exec "$codex_bin" -C "$repo" -c mcp_servers.node_repl.enabled=false "$@"
