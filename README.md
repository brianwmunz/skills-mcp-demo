# Skills + MCP Servers: webinar demo

Two live builds that meet in one prompt:

1. **Build #1 (skill):** `.claude/skills/alert-writer` decides *what* to say.
2. **Build #2 (MCP server):** `mcp-server/` exposes `send_alert`, which triggers a Prismatic flow by webhook. The flow posts to Slack.
3. **Payoff:** one prompt, and a Slack message appears.

Prompts to paste are in [PROMPTS.md](PROMPTS.md). The failure event both demos use is [fixtures/acme-sync-failure.json](fixtures/acme-sync-failure.json).

## Quick reference

| Command | What it does |
|---|---|
| `scripts/reset.sh b1` | Start of Build #1: no skill, MCP scaffold only |
| `scripts/reset.sh b2` | Start of Build #2: skill done, MCP scaffold only |
| `scripts/jump.sh <tag>` | Jump to any checkpoint (below) |
| `scripts/claude.sh` | Start Claude Code with `.env` loaded (always use this) |
| `scripts/codex.sh` | Start Codex CLI with `.env` loaded and only the `alerts` server |

Checkpoints, in order:

| Tag | State |
|---|---|
| `b1-start` | No skill. MCP scaffold with `// TODO: register send_alert tool here` |
| `b1-frontmatter` | `SKILL.md` with frontmatter only |
| `b1-done` | Reference skill complete |
| `b2-start` | Same as `b1-done` |
| `b2-tool-done` | Reference `send_alert` implemented and built |
| `b2-connected` | `.mcp.json` registered |
| `b2-codex` | `b2-connected` plus `.agents/skills/alert-writer` (the live `cp` already done) |

`reset.sh` and `jump.sh` discard any live changes, check out the tag on a scratch
branch called `live`, and rebuild `mcp-server/dist`. `main` and the tags are never
modified. `reset.sh` also deletes `.agents/skills/` so every rehearsal starts without the Codex
copy of the skill. Both scripts leave an empty `.agents/skills/` behind so the live `cp` lands in the right place. Kept across resets (all gitignored): `.env`, `node_modules`, anything in
`comparison/`, and `.claude/settings.local.json`.

Run `/exit` and start a new `scripts/claude.sh` session after a jump. Claude Code
loads skills and MCP servers at startup.

## Why `scripts/claude.sh`

Claude Code does not read `.env`. `.mcp.json` uses `${PRISMATIC_ALERT_WEBHOOK_URL}` and
`${ALERT_DRY_RUN:-0}`, which expand from the environment Claude Code was started in.
`scripts/claude.sh` exports only `PRISMATIC_ALERT_WEBHOOK_URL` and `ALERT_DRY_RUN` from `.env`
(not `SLACK_WEBHOOK_URL`, so nothing in the session can post to Slack directly) and then runs
`claude`, so the URL never shows on screen. Any arguments are passed through to `claude`.

## Safety net: dry run

Set `ALERT_DRY_RUN=1` in `.env` and restart the session. `send_alert` then skips the
POST and returns the exact payload it would have sent.

## No claude.ai connectors in the demo

`scripts/claude.sh` also sets `ENABLE_CLAUDEAI_MCP_SERVERS=false`. Your claude.ai
connectors (Slack, Prismatic, and others) stay out of the session, so the only way
to alert is `send_alert` and `/mcp` shows only `alerts`.

## Prismatic side (built and deployed)

Org: **FactoryIQ Demo Org**. Integration **Webinar Alert Relay** ([prismatic/webinar-alert-relay.yml](prismatic/webinar-alert-relay.yml)),
deployed as an instance for the test customer **Webinar Demo**.

Flow **Send Alert**: Webhook trigger → **Severity Emoji** (Text Manipulation › Find & Replace
Multiple Substrings: critical → 🔴, warning → 🟠, info → 🔵) → **Post to Slack**
(Slack › Post Slack Message From Webhook, connection type *Webhook URL*). Slack message:

```
🔴 *{title}*
{message}
_{integration} · {severity}_
```

`.env` holds `PRISMATIC_ALERT_WEBHOOK_URL` (the instance's flow webhook) and
`SLACK_WEBHOOK_URL` (the Slack incoming webhook for `#webinar-alerts`, used only to
configure the instance's connection).

To change the flow, edit the YAML, then re-import, publish, and redeploy:

```sh
ID=$(prism integrations:list --columns id --no-header --filter 'name=Webinar Alert Relay')
prism integrations:import --path prismatic/webinar-alert-relay.yml --integrationId "$ID"
prism integrations:publish "$ID" --comment "..."
# then update the instance to the new version in the Prismatic UI (Instances › Webinar Alert Relay)
```

### What Prismatic returns

The webhook is asynchronous. It returns as soon as the execution is queued, before Slack is called:

```
HTTP/2 200
content-type: application/json
prismatic-executionid: SW5zdGFuY2VFeGVjdXRpb25SZXN1bHQ6...

{"executionId":"SW5zdGFuY2VFeGVjdXRpb25SZXN1bHQ6..."}
```

`send_alert` reports this as `Alert sent (HTTP 200, execution ID ...)`. A 200 means
*accepted*, not *posted*. If Slack is quiet, look up the execution in Prismatic
(Instances › Webinar Alert Relay › Executions) or:

```sh
prism graphql:query 'query { executionResult(id: "<executionId>") { error stepResults { nodes { stepName } } } }'
```

## Smoke test (sends a real Slack message)

```sh
set -a; source .env; set +a
curl -s -X POST "$PRISMATIC_ALERT_WEBHOOK_URL" -H 'Content-Type: application/json' \
  -d '{"severity":"info","title":"Smoke test","message":"Webhook to Slack works.","integration":"Demo"}'
```

Expect `{"executionId":"..."}` and a 🔵 message in `#webinar-alerts`.

## MCP approval

The first session at `b2-connected` asks you to approve the `alerts` server from
`.mcp.json`. To show that prompt live after rehearsing, run
`claude mcp reset-project-choices`.

## Codex

After the payoff, the same skill and MCP server run in Codex CLI (see the end of [PROMPTS.md](PROMPTS.md)).

- **Skill:** Codex reads skills from `.agents/skills/`. The live step is
  `cp -r .claude/skills/alert-writer .agents/skills/`.
- **MCP server:** [.codex/config.toml](.codex/config.toml) registers `alerts` (project-scoped)
  with `env_vars = ["PRISMATIC_ALERT_WEBHOOK_URL", "ALERT_DRY_RUN"]`. Those are forwarded by name from
  the shell `scripts/codex.sh` starts, so the URL never appears in a config file.
  `send_alert` asks for approval on each call.
- **Nothing else can post to Slack:** the project config turns off ChatGPT apps/connectors,
  plugins, browser, and computer use, and keeps shell commands sandboxed with no network
  and without the webhook variables. `scripts/codex.sh` exports only the two variables `alerts`
  needs (not `SLACK_WEBHOOK_URL`) and turns off the `node_repl` server from your user config.
  Check with `scripts/codex.sh mcp list`: only `alerts` should be enabled.
- **Trust:** Codex loads `.codex/config.toml` only for trusted projects, and only trust saved in
  `~/.codex/config.toml` counts (a `-c` override doesn't). This repo is trusted there. On another
  machine, accept Codex's trust prompt on first launch, then restart.
- **CLI:** `scripts/codex.sh` uses `codex` from your PATH, or the CLI bundled with the Codex
  desktop app (`/Applications/ChatGPT.app/Contents/Resources/codex`). If a desktop update
  breaks it, `brew install --cask codex`.

## Prerequisites

- Node 20+ (built with Node 25). Dependencies are already installed in `mcp-server/node_modules`.
- `skills-ref` (installed with `uv tool install "git+https://github.com/agentskills/agentskills.git#subdirectory=skills-ref"`).
