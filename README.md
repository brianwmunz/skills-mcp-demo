# Skills + MCP Servers: build an AI alerting agent

This is the companion repo for the webinar. You'll build two small pieces and then
connect them with one prompt:

1. **A skill** (`.claude/skills/alert-writer/`) that teaches the agent *what* to say:
   when an integration failure deserves an alert, how severe it is, and how to format it.
2. **An MCP server** (`mcp-server/`) that gives the agent a `send_alert` tool, so it can
   actually *do* something: POST the alert to a webhook.
3. **The payoff:** you ask the agent to "alert the team" about a failing Salesforce sync,
   and a formatted message lands in Slack.

```
 Claude Code / Codex
   │  reads the skill: decides severity, writes title + message
   │  calls the send_alert tool
   ▼
 alerts MCP server (mcp-server/)
   │  POST { severity, title, message, integration, sentAt }
   ▼
 Prismatic flow "Send Alert"          ← recommended (see docs/prismatic.md)
   │  adds a severity emoji, formats the message,
   │  holds the Slack credential, logs every execution
   ▼
 Slack #your-alerts-channel
```

The MCP server only knows "POST JSON to a URL." Where that URL points is up to you:

- **Recommended: Prismatic.** The webhook goes to a Prismatic flow that formats the
  message and posts it to Slack. The Slack credential stays in Prismatic, every alert gets
  an execution log, and you can change the format or destination without touching your
  agent's code. **Set-up guide: [docs/prismatic.md](docs/prismatic.md).**
- **Alternative: straight to Slack.** Point the server at a Slack incoming webhook and
  have it format the message itself. Fewer moving parts, fewer guardrails.
  **Guide: [docs/slack-direct.md](docs/slack-direct.md).**

The skill and MCP server work the same either way. Only the last hop changes.

---

## What you need

| | Required? | Notes |
|---|---|---|
| [Claude Code](https://docs.claude.com/en/docs/claude-code) | Yes | The `claude` CLI. Codex CLI works too (see [Bonus](#bonus-same-skill-and-server-in-codex)). |
| Node.js 20+ and git | Yes | To build the MCP server. |
| A Slack workspace | Yes | Somewhere you're allowed to add an incoming webhook. A test workspace is ideal. |
| A Prismatic account | Recommended | For the Prismatic path. See [docs/prismatic.md](docs/prismatic.md). |
| [`skills-ref`](https://github.com/agentskills/agentskills) | Optional | Validates your skill: `uv tool install "git+https://github.com/agentskills/agentskills.git#subdirectory=skills-ref"` |

You don't need Slack or Prismatic to start. Building the skill and server works offline, and dry-run mode
lets you see the exact payload without sending anything.

## Set up

```sh
git clone https://github.com/brianwmunz/skills-mcp-demo.git
cd skills-mcp-demo
cp .env.example .env
cd mcp-server && npm ci && npm run build && cd ..
```

For now, set `.env` to dry-run mode with a placeholder URL. The server won't start a call
without some URL, even in dry run. You'll replace it when you [connect to Slack](#connect-it-to-slack).

```sh
PRISMATIC_ALERT_WEBHOOK_URL=https://example.com/placeholder
ALERT_DRY_RUN=1
```

> **Always start Claude Code with `scripts/claude.sh`, not `claude`.** Claude Code doesn't
> read `.env`. The script exports only the two variables the MCP server needs, keeps your
> claude.ai connectors (Slack and others) out of the session so `send_alert` is the only
> way to send an alert, and passes any extra arguments through to `claude`.

## Two ways to use this repo

**Build it yourself, like in the webinar.** Follow [PROMPTS.md](PROMPTS.md). It walks
through every step and prompt in order, starting from an empty skill and an MCP server
that's just a `// TODO`.

**Just see it work.** `main` already has the finished skill, MCP server, and
`.mcp.json`. Set up a [destination](#connect-it-to-slack), then run the payoff prompt
from [PROMPTS.md](PROMPTS.md#the-payoff-prompt).

### Checkpoints

Each step of the build has a git tag. `scripts/reset.sh b1` (or `b2`) takes you to the
start of a part, and `scripts/jump.sh <checkpoint>` takes you to any point if you get stuck.

| Checkpoint | What's there |
|---|---|
| `b1-start` | No skill. MCP server scaffold with a `// TODO` |
| `b1-frontmatter` | `SKILL.md` with frontmatter only |
| `b1-done` / `b2-start` | Finished skill |
| `b2-tool-done` | Finished `send_alert` tool, built |
| `b2-connected` | Server registered in `.mcp.json` |
| `b2-codex` | Skill copied to `.agents/skills/` for Codex |

> `reset.sh` and `jump.sh` run `git reset --hard` and `git clean -fd`, then check out the
> tag on a branch called `live` and rebuild the server. They **throw away uncommitted
> work** (gitignored files like `.env` and `node_modules` are kept). To return to the
> finished version, run `git checkout main`.
>
> Checkpoints are snapshots from the webinar, so the docs in your working copy may look
> different after a jump. Keep this README and PROMPTS.md open on GitHub while you work.

After a jump, `/exit` and start a new `scripts/claude.sh` session. Claude Code loads
skills and MCP servers only at startup.

## Connect it to Slack

The MCP server POSTs JSON to whatever URL is in `PRISMATIC_ALERT_WEBHOOK_URL`. Choose
where that URL points:

### Recommended: through Prismatic → [docs/prismatic.md](docs/prismatic.md)

Import the included integration ([prismatic/webinar-alert-relay.yml](prismatic/webinar-alert-relay.yml)),
connect it to a Slack incoming webhook, deploy it, and copy its webhook URL into `.env`.
It takes about 10 minutes.
You can click through it yourself, or install Prismatic's own
[agent skills](https://github.com/prismatic-io/agent-skills) and let Claude do the
import and deploy from inside this repo. The guide covers both.

### Alternative: straight to Slack → [docs/slack-direct.md](docs/slack-direct.md)

Create a Slack incoming webhook and change `send_alert` to format the message itself.
The guide includes a prompt for that change and explains the trade-offs.

Either way, finish by setting `ALERT_DRY_RUN=0` in `.env`, restarting `scripts/claude.sh`,
and running the payoff prompt. Read the tool call before you approve it. That approval
prompt is your last check before something leaves your machine.

## Key ideas to notice

- **The skill is judgment, the tool is capability.** The skill decides *whether* to alert,
  how severe it is, and what to say. The MCP tool only knows how to send.
- **The schema enforces what the skill asks for.** The skill asks for short titles. The zod
  schema rejects long ones and anything outside `critical | warning | info`.
- **Secrets stay out of the model's context.** The webhook URL goes from `.env` to the
  server's environment through `${...}` expansion. It never appears in a prompt, a tool
  result, or a committed file.
- **The approval prompt is a feature.** Every `send_alert` call waits for you to approve it.

## Bonus: same skill and server in Codex

Skills and MCP are open standards, so the same skill and server run in OpenAI's Codex CLI.
The steps are at the end of [PROMPTS.md](PROMPTS.md#bonus-same-skill-same-server-in-codex).
Here's how this repo sets it up:

- **Skill:** Codex reads skills from `.agents/skills/`.
- **MCP server:** [.codex/config.toml](.codex/config.toml) registers `alerts` for this
  project and forwards `PRISMATIC_ALERT_WEBHOOK_URL` and `ALERT_DRY_RUN` by name, so the
  URL never appears in a config file. Each `send_alert` call asks for approval.
- **Lockdown:** the project config turns off ChatGPT apps/connectors, plugins, and browser
  tools, and runs shell commands in a sandbox with no network. `send_alert` is the only way
  out. Check with `scripts/codex.sh mcp list`.
- **Trust:** Codex only loads `.codex/config.toml` for projects you've trusted. On first
  launch, accept the trust prompt, then restart `scripts/codex.sh`.
- **CLI:** `scripts/codex.sh` uses `codex` from your PATH, or the CLI bundled with the
  ChatGPT desktop app on macOS. To install it: `brew install --cask codex`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/mcp` doesn't list `alerts` | Did you start with `scripts/claude.sh` from the repo root? Is `mcp-server/dist/index.js` built? Did you approve the server? (To get the approval prompt back: `claude mcp reset-project-choices`.) |
| `Error: PRISMATIC_ALERT_WEBHOOK_URL is not set` | Set it in `.env` and restart the session. Claude Code reads the environment only at startup. |
| The skill doesn't seem to load | Start a new session after changing `SKILL.md`. Make sure the `description` mentions alerts and integration failures. |
| Tool returns 200 but nothing shows in Slack | Prismatic accepted the request but the flow failed. Check the execution log ([docs/prismatic.md](docs/prismatic.md#troubleshooting)). |
| You want to test without sending anything | Set `ALERT_DRY_RUN=1` in `.env` and restart. |

## What's in here

| Path | What it is |
|---|---|
| [.claude/skills/alert-writer/SKILL.md](.claude/skills/alert-writer/SKILL.md) | The finished skill |
| [mcp-server/src/index.ts](mcp-server/src/index.ts) | The finished MCP server (`send_alert`) |
| [.mcp.json](.mcp.json) | Registers the server for Claude Code (project scope) |
| [.codex/config.toml](.codex/config.toml) | Registers the server for Codex, with lockdown settings |
| [fixtures/acme-sync-failure.json](fixtures/acme-sync-failure.json) | The failure event used in every demo |
| [prismatic/webinar-alert-relay.yml](prismatic/webinar-alert-relay.yml) | The Prismatic integration (webhook → format → Slack) |
| [docs/prismatic.md](docs/prismatic.md) | Set up the Prismatic flow |
| [docs/slack-direct.md](docs/slack-direct.md) | Skip Prismatic and post straight to Slack |
| [PROMPTS.md](PROMPTS.md) | Self-guided walkthrough with every prompt |
| `scripts/` | `claude.sh`, `codex.sh`, `reset.sh`, `jump.sh` |
