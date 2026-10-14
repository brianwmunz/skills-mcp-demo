#!/usr/bin/env bash
# Start Claude Code with .env loaded (Claude Code doesn't read .env itself;
# .mcp.json expands ${PRISMATIC_ALERT_WEBHOOK_URL} from this environment).
# Extra args pass through, e.g. scripts/claude.sh --model opus
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] || { echo "Missing .env (cp .env.example .env)"; exit 1; }
# Export only what the alerts server needs (not SLACK_WEBHOOK_URL).
export PRISMATIC_ALERT_WEBHOOK_URL="$(set -a; source .env; echo "${PRISMATIC_ALERT_WEBHOOK_URL:-}")"
export ALERT_DRY_RUN="$(set -a; source .env; echo "${ALERT_DRY_RUN:-0}")"
unset SLACK_WEBHOOK_URL
# Keep claude.ai connectors (Slack, Prismatic, ...) out of the demo session.
export ENABLE_CLAUDEAI_MCP_SERVERS=false
exec claude "$@"
