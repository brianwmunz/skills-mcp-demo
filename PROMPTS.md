# Live prompts

From the run sheet, in order. Start every Claude Code session with
`scripts/claude.sh` from the repo root so `.env` is loaded.

---

## Build #1: the skill (target 7 min, hard stop 14:00)

Start: `scripts/reset.sh b1`, then `scripts/claude.sh`.

### 1. No-skill baseline (0:00)

```
Draft a Slack alert for the event in fixtures/acme-sync-failure.json.
```

### Type the frontmatter by hand (1:00)

Create `.claude/skills/alert-writer/SKILL.md` and type:

```
---
name: alert-writer
description: Writes integration-failure alerts for the team's alert channel. Decides whether an event deserves an alert, assigns severity (critical, warning, info), and formats a short, secret-free message. Use when an integration, instance, flow, or execution fails, degrades, retries, or recovers, or when asked to write, draft, or send an alert or incident notice about an integration.
---
```

Fallback: `scripts/jump.sh b1-frontmatter`

### 2. Draft the body (2:30)

```
Fill in the body of .claude/skills/alert-writer/SKILL.md below the frontmatter. Cover: when to alert vs. not; a severity rubric (critical = production plus data not syncing or an auth failure, warning = degraded or retrying, info = recovered or FYI); a fixed four-line message format (what broke, who's affected, impact, suggested next step); and rules: message 500 characters max, title 80 max, lead with the customer and integration, use only facts from the event. If an alert is warranted and a send_alert tool is available, call it. Keep the whole file under 100 lines.
```

### Edit one rule by hand (4:00)

Add under the rules:

```
- Never include secrets, tokens, API keys, or raw request/response payloads. Name the error code instead.
```

### Validate (4:30)

```
skills-ref validate .claude/skills/alert-writer
```

### Prompt 1 again, new session (5:00)

`/exit`, then `scripts/claude.sh`:

```
Draft a Slack alert for the event in fixtures/acme-sync-failure.json.
```

**If it goes sideways:** `scripts/jump.sh b1-done`, then validate and rerun prompt 1.

---

## Build #2: the MCP server (target 8 min, hard stop 25:00)

Start: `scripts/reset.sh b2`, then `scripts/claude.sh`.

### 3. Implement `send_alert` (1:00)

```
In mcp-server/src/index.ts, replace the TODO with a send_alert tool using registerTool. Input schema (zod, strict): severity enum info | warning | critical, title string max 80 chars, message string max 500 chars, integration optional string. The handler POSTs JSON { severity, title, message, integration, sentAt } to process.env.PRISMATIC_ALERT_WEBHOOK_URL and returns a short text result with the HTTP status and any executionId from the response. If ALERT_DRY_RUN=1, skip the POST and return the payload it would have sent. Fail clearly if the URL env var is missing, and never log or echo the URL. Make the tool description specific: it posts to the team's alert channel.
```

### Build (4:00)

```
cd mcp-server && npm run build && cd ..
```

### Register project-scoped (4:30)

Keep the **single quotes**. They stop your shell from expanding the variables, so
`.mcp.json` gets the literal `${...}` text and not the URL.

```
claude mcp add --scope project alerts -e 'PRISMATIC_ALERT_WEBHOOK_URL=${PRISMATIC_ALERT_WEBHOOK_URL}' -e 'ALERT_DRY_RUN=${ALERT_DRY_RUN:-0}' -- node mcp-server/dist/index.js
```

```
cat .mcp.json
```

**If it goes sideways:** `scripts/jump.sh b2-tool-done` or `scripts/jump.sh b2-connected`.

### New session (5:30)

`/exit`, then `scripts/claude.sh`. Approve the `alerts` server, then:

```
/mcp
```

### 4. Payoff (6:00)

```
Acme's Salesforce sync is failing. Check fixtures/acme-sync-failure.json and alert the team.
```

Read the tool call aloud before approving it. If the network dies, set
`ALERT_DRY_RUN=1` in `.env`, restart the session, and show the payload.

---

## Codex: same skill, same MCP server (after the payoff)

In a terminal at the repo root (exit Claude Code or use another pane):

```
cp -r .claude/skills/alert-writer .agents/skills/
```

```
scripts/codex.sh
```

Paste the payoff prompt:

```
Acme's Salesforce sync is failing. Check fixtures/acme-sync-failure.json and alert the team.
```

Approve the `send_alert` call. The second Slack message should arrive.

**If it goes sideways:** `scripts/jump.sh b2-codex` (skill already copied), then `scripts/codex.sh`.
