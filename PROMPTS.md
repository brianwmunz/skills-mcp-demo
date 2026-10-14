# Walk yourself through it

Want to see it done first? [Watch the webinar](https://youtu.be/9epduFkbZck), then follow along here.

These are the prompts and steps from the webinar, in order. Each prompt appears once.
When a step says to run a prompt "again," scroll back up and paste it.

Before you start, complete [Set up](README.md#set-up) in the README. Run every Claude Code
session from the repo root with `scripts/claude.sh`. After you change a skill or MCP
server, `/exit` and start a new session, because Claude Code loads both at startup.

**Stuck?** `scripts/jump.sh <checkpoint>` puts the repo at the finished state of any step,
using the checkpoint names below. It discards uncommitted changes. See the
[README](README.md#two-ways-to-use-this-repo).

---

## Part 1: Teach the agent what a good alert is (a skill)

**Start fresh:** `scripts/reset.sh b1`, then `scripts/claude.sh`.

### The baseline prompt

You'll use this prompt twice: once now, without a skill, and once after you write the skill.

```
Draft a Slack alert for the event in fixtures/acme-sync-failure.json.
```

**Look for:** the format the agent picks on its own, whether it decides on a severity, and
whether it copies raw details like the instance ID or error message straight from the event.

### Write the frontmatter by hand

Create `.claude/skills/alert-writer/SKILL.md` with:

```markdown
---
name: alert-writer
description: Writes integration-failure alerts for the team's alert channel. Decides whether an event deserves an alert, assigns severity (critical, warning, info), and formats a short, secret-free message. Use when an integration, instance, flow, or execution fails, degrades, retries, or recovers, or when asked to write, draft, or send an alert or incident notice about an integration.
---
```

The `description` is what the agent reads to decide whether to load the skill. Write it
to say both what the skill does and when to use it.

*Checkpoint: `b1-frontmatter`*

### Have Claude draft the body

```
Fill in the body of .claude/skills/alert-writer/SKILL.md below the frontmatter. Cover: when to alert vs. not; a severity rubric (critical = production plus data not syncing or an auth failure, warning = degraded or retrying, info = recovered or FYI); a fixed four-line message format (what broke, who's affected, impact, suggested next step); and rules: message 500 characters max, title 80 max, lead with the customer and integration, use only facts from the event. If an alert is warranted and a send_alert tool is available, call it. Keep the whole file under 100 lines.
```

### Make it yours

Read what Claude wrote and change anything that isn't how *your* team works. At minimum,
add this rule by hand:

```
- Never include secrets, tokens, API keys, or raw request/response payloads. Name the error code instead.
```

Optional: `skills-ref validate .claude/skills/alert-writer`

### Compare

`/exit`, start `scripts/claude.sh` again, and rerun **the baseline prompt**. Now the agent
should load `alert-writer`, call this `critical` (production plus a 401 auth failure), and
use your four-line format.

*Checkpoint: `b1-done`. Compare yours with the reference skill there.*

---

## Part 2: Give the agent a way to act (an MCP server)

**Start here if you skipped Part 1:** `scripts/reset.sh b2`, then `scripts/claude.sh`.

### Add the `send_alert` tool

[mcp-server/src/index.ts](mcp-server/src/index.ts) is a working MCP server with no tools.
Ask Claude to add one:

```
In mcp-server/src/index.ts, replace the TODO with a send_alert tool using registerTool. Input schema (zod, strict): severity enum info | warning | critical, title string max 80 chars, message string max 500 chars, integration optional string. The handler POSTs JSON { severity, title, message, integration, sentAt } to process.env.PRISMATIC_ALERT_WEBHOOK_URL and returns a short text result with the HTTP status and any executionId from the response. If ALERT_DRY_RUN=1, skip the POST and return the payload it would have sent. Fail clearly if the URL env var is missing, and never log or echo the URL. Make the tool description specific: it posts to the team's alert channel.
```

**Look for:** the schema enforces the limits the skill only *asks* for, the URL comes
from the environment so the agent never sees it, and dry run gives you a safe way to test.

### Build it

```sh
cd mcp-server && npm run build && cd ..
```

*Checkpoint: `b2-tool-done`*

### Register it for this project

Keep the **single quotes**. They stop your shell from expanding the variables, so
`.mcp.json` stores the literal `${...}` text instead of your URL.

```sh
claude mcp add --scope project alerts -e 'PRISMATIC_ALERT_WEBHOOK_URL=${PRISMATIC_ALERT_WEBHOOK_URL}' -e 'ALERT_DRY_RUN=${ALERT_DRY_RUN:-0}' -- node mcp-server/dist/index.js
cat .mcp.json
```

`/exit`, start `scripts/claude.sh`, approve the `alerts` server, and run `/mcp`. You should
see `alerts` with one tool, `send_alert`.

*Checkpoint: `b2-connected`*

---

## Part 3: The payoff

### The payoff prompt

```
Acme's Salesforce sync is failing. Check fixtures/acme-sync-failure.json and alert the team.
```

The skill decides what to say, and the MCP tool sends it. Read the tool call before you
approve it. That approval is your last check before anything leaves your machine.

- **In dry-run mode** (`ALERT_DRY_RUN=1`), the tool returns the exact JSON it would have sent.
- **For a real send,** set up a destination first:
  - **Recommended:** [docs/prismatic.md](docs/prismatic.md) (Prismatic flow → Slack)
  - **Alternative:** [docs/slack-direct.md](docs/slack-direct.md) (straight to Slack)

  Then put the URL in `.env`, set `ALERT_DRY_RUN=0`, restart `scripts/claude.sh`, and run
  **the payoff prompt** again. A 🔴 alert should appear in Slack.

### Change the event and see what the skill does

Edit `fixtures/acme-sync-failure.json` and run **the payoff prompt** again (dry run works fine):

- Set `instance.environment` to `"sandbox"`. The skill should skip the alert and say why.
- Remove `recordsPending`. The alert should say "unknown" instead of making up a number.

Run `git checkout fixtures/` to restore the original event.

---

## Bonus: same skill, same server, in Codex

```sh
mkdir -p .agents/skills
cp -r .claude/skills/alert-writer .agents/skills/
scripts/codex.sh
```

Paste **the payoff prompt** and approve the `send_alert` call. You don't need to change
the skill or the server. Setup details are in the [README](README.md#bonus-same-skill-and-server-in-codex).

*Checkpoint: `b2-codex`*
