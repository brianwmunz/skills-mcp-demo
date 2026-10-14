# Alternative: post straight to Slack

The recommended setup sends alerts through a Prismatic flow ([docs/prismatic.md](prismatic.md)).
To skip that hop, you can point `send_alert` straight at a Slack incoming webhook.
It's quicker to set up, but you take on the trade-offs listed below.

```
send_alert ──POST { text }──▶ Slack incoming webhook
```

## What you give up

| | Through Prismatic | Straight to Slack |
|---|---|---|
| Slack credential lives in | Prismatic | Your `.env` and the MCP server's environment |
| Message formatting lives in | The flow (edit without changing code) | The MCP server (edit code, rebuild, restart) |
| Did the alert actually post? | Execution log with step results | Only the HTTP status the tool returned |
| Change channel or add a destination | Edit the flow | Change code, add credentials |

For a personal experiment, going direct is fine. For anything a team relies on, the
Prismatic path is easier to run and maintain.

## Step 1: Create a Slack incoming webhook

1. Go to [api.slack.com/apps](https://api.slack.com/apps) and click **Create New App** → **From scratch**.
2. Open **Incoming Webhooks**, turn it **on**, and click **Add New Webhook to Workspace**.
3. Pick a channel and copy the URL (`https://hooks.slack.com/services/...`).

## Step 2: Make `send_alert` speak Slack

As built in the webinar, `send_alert` POSTs this JSON:

```json
{ "severity": "critical", "title": "...", "message": "...", "integration": "...", "sentAt": "..." }
```

Prismatic accepts any JSON, but a Slack incoming webhook requires a `text` field, so
sending this body straight to Slack fails with `400 no_text`. In the Prismatic setup, the
flow handles the formatting. Here the MCP server has to do it.

Ask Claude Code to make the change (from a `scripts/claude.sh` session at the repo root):

```
In mcp-server/src/index.ts, change send_alert so it posts directly to a Slack incoming webhook. Read the URL from process.env.SLACK_ALERT_WEBHOOK_URL instead of PRISMATIC_ALERT_WEBHOOK_URL. Send a Slack body of { text } where text is three lines: a severity emoji (critical 🔴, warning 🟠, info 🔵) followed by the title in bold (*title*), then the message, then _integration · severity_ in italics. Keep the zod schema, the ALERT_DRY_RUN behavior (return the Slack body it would have sent), the clear error when the URL is missing, and never echo the URL. Slack responds with plain text "ok", so return just the HTTP status. Update the tool description to say it posts to the team's Slack alert channel.
```

<details>
<summary>Reference version of the changed handler</summary>

```ts
const SEVERITY_EMOJI = { critical: "🔴", warning: "🟠", info: "🔵" } as const;

server.registerTool(
  "send_alert",
  {
    description:
      "Post an integration failure alert to the team's Slack alert channel. severity: critical|warning|info. title: max 80 chars. message: max 500 chars. integration: integration name.",
    inputSchema: {
      severity: z.enum(["critical", "warning", "info"]),
      title: z.string().min(1).max(80),
      message: z.string().min(1).max(500),
      integration: z.string().min(1),
    },
  },
  async ({ severity, title, message, integration }) => {
    const webhookUrl = process.env.SLACK_ALERT_WEBHOOK_URL;
    if (!webhookUrl) {
      return {
        content: [{ type: "text", text: "Error: SLACK_ALERT_WEBHOOK_URL is not set." }],
        isError: true,
      };
    }

    const body = {
      text: `${SEVERITY_EMOJI[severity]} *${title}*\n${message}\n_${integration} · ${severity}_`,
    };

    if (process.env.ALERT_DRY_RUN === "1") {
      return {
        content: [{ type: "text", text: `[DRY RUN] Alert not sent.\n${JSON.stringify(body, null, 2)}` }],
      };
    }

    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    return {
      content: [{ type: "text", text: `status: ${response.status}` }],
      isError: !response.ok,
    };
  }
);
```

</details>

Rebuild:

```sh
cd mcp-server && npm run build && cd ..
```

## Step 3: Pass the new variable through

Three places need to know about `SLACK_ALERT_WEBHOOK_URL`:

**`.env`**

```sh
SLACK_ALERT_WEBHOOK_URL=https://hooks.slack.com/services/...
ALERT_DRY_RUN=0
```

**`.mcp.json`.** Re-register the server so it forwards the new variable. Keep the single
quotes so the file stores the literal `${...}` text, not your URL:

```sh
claude mcp remove --scope project alerts
claude mcp add --scope project alerts -e 'SLACK_ALERT_WEBHOOK_URL=${SLACK_ALERT_WEBHOOK_URL}' -e 'ALERT_DRY_RUN=${ALERT_DRY_RUN:-0}' -- node mcp-server/dist/index.js
```

**`scripts/claude.sh`.** It only exports the variables the server needs. Add a line next
to the other `export` lines:

```sh
export SLACK_ALERT_WEBHOOK_URL="$(set -a; source .env; echo "${SLACK_ALERT_WEBHOOK_URL:-}")"
```

(For Codex, also change `env_vars` in [.codex/config.toml](../.codex/config.toml) and add
the same export to `scripts/codex.sh`.)

> Why a new name instead of reusing `SLACK_WEBHOOK_URL` from `.env.example`? The launch
> scripts deliberately `unset SLACK_WEBHOOK_URL`, so the raw Slack credential never reaches
> the agent session in the Prismatic setup. Using a separate name makes it clear that in
> this setup, you're choosing to give it to the server.

## Step 4: Test and run

Smoke test the Slack webhook by itself:

```sh
set -a; source .env; set +a
curl -s -X POST "$SLACK_ALERT_WEBHOOK_URL" -H 'Content-Type: application/json' \
  -d '{"text":"🔵 *Smoke test*\nWebhook to Slack works.\n_Demo · info_"}'
```

You should get `ok` back. Then `/exit`, restart with `scripts/claude.sh`, check `/mcp`, and
run [the payoff prompt](../PROMPTS.md#the-payoff-prompt).

## Switching back to Prismatic

`git checkout main -- mcp-server/src/index.ts .mcp.json scripts/claude.sh`, rebuild, and
follow [docs/prismatic.md](prismatic.md).
