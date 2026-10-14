# Send alerts through Prismatic

This guide connects the `send_alert` MCP tool to Slack through a Prismatic flow. When
you're done, `PRISMATIC_ALERT_WEBHOOK_URL` in your `.env` will point to a Prismatic
webhook, and every alert your agent sends will show up in Slack, formatted, with an
execution log you can check.

```
send_alert ──POST JSON──▶ Prismatic flow "Send Alert" ──▶ Slack
                          1. Webhook trigger
                          2. Severity Emoji  (critical → 🔴, warning → 🟠, info → 🔵)
                          3. Post to Slack   (uses the Slack Webhook connection)
```

It takes about 10 minutes by hand. Or you can have Prismatic's own skills do most of it
for you (see [Shortcut](#shortcut-let-prismatics-skills-do-the-setup)).

## Why put Prismatic in the middle?

The MCP server could post to Slack directly ([docs/slack-direct.md](slack-direct.md)
shows how). Putting a flow in between keeps the agent's tool simple and puts the
operational parts in a place built for them:

- **Credentials stay out of the agent's environment.** The Slack webhook is stored as a
  connection in Prismatic. Your laptop, `.env`, and the agent session only have the
  Prismatic trigger URL. If that URL leaks, you can rotate it without touching Slack.
- **Every alert is logged.** Each call creates an execution with step-by-step results, so
  when someone asks whether the alert went out, you can check.
- **Change formatting or destination without redeploying the agent.** Want blocks
  instead of text, a different channel per severity, or PagerDuty for `critical`? Edit
  the flow. The MCP server and skill stay the same.
- **One tool, many customers.** Deploy the same integration as separate instances with
  different Slack connections. The agent's tool doesn't change, only the URL.

## What you need

- A **Prismatic account**. No account yet? [Start a free trial](https://prismatic.io/free-trial/?utm_source=github&utm_medium=social&utm_campaign=2026-q4-skills-mcp-webinar&utm_content=prismatic-guide).
- A **Slack workspace** where you can create an app with an incoming webhook.
- **Optional:** the Prismatic CLI, `prism`, **v11 or later**, to work from the terminal
  (and for the skills shortcut below). The commands in this guide use v11:
  ```sh
  npm install -g @prismatic-io/prism@latest
  prism --version
  prism login
  ```

## Shortcut: let Prismatic's skills do the setup

You just built a skill that teaches an agent how *your team* writes alerts. Prismatic
publishes skills that teach an agent how to *use Prismatic*:
[prismatic-io/agent-skills](https://github.com/prismatic-io/agent-skills). They use the
same open Agent Skills format as `alert-writer`, so they work in Claude Code, Codex, and
other agents.

The skill for this job is **`orby`**. It operates your Prismatic organization through
the `prism` CLI, so it can import the YAML, publish it, create the customer, and deploy
the instance (Steps 2–3) from a single prompt. Before it changes anything on the
platform, it asks you to confirm.

**1. Prerequisites.** Orby needs the Prism CLI **v11 or later** (see
[What you need](#what-you-need)), logged in, and Node 22+.

**2. Install the skill** for your user account, not for this repo:

```sh
npx skills add prismatic-io/agent-skills --skill orby -g -a claude-code
```

Use `-a codex` for Codex, or leave off `--skill` and `-a` to choose from the full catalog.
Install it globally (`-g`) because `scripts/reset.sh` and `scripts/jump.sh` run
`git clean`, which would delete a skill installed inside the repo.

**3. Create the Slack webhook yourself** ([Step 1](#step-1-create-a-slack-incoming-webhook)).
That URL is a credential. Don't paste it into the chat. You'll enter it in Prismatic's UI.

**4. Open Claude Code at the repo root** (`claude` works here, since you aren't running the
alert demo yet) and ask:

```
Use the orby skill to set up the Prismatic side of this repo. Import prismatic/webinar-alert-relay.yml as a new integration, publish it, create a customer named "Webinar Demo", and deploy an instance of the integration for that customer. I'll enter the Slack Webhook connection value myself in the Prismatic UI, so tell me exactly where to put it. When the instance is deployed, give me the command that prints the Send Alert flow's webhook URL instead of showing the URL in this chat.
```

Read each `prism` command before you approve it. When Orby finishes, continue with
[Step 4](#step-4-copy-the-webhook-url-into-env) to put the URL in `.env`, then run the
[Step 5](#step-5-smoke-test) smoke test.

**5. Uninstall Orby before the payoff (recommended).** Orby's description covers
integration failures and executions, so on the payoff prompt Claude might use it to look
up "Acme" in your Prismatic organization instead of using `alert-writer` to write the
alert. Uninstall it until you're done with the demo:

```sh
npx skills remove -g orby
```

**Want to go further?** The `prismatic-integrations` skill builds **code-native**
integrations, written in TypeScript in your repo. Try having it rebuild this relay as
code instead of YAML. For example:
"Build a code-native Prismatic integration with a webhook-triggered flow that takes
{ severity, title, message, integration }, maps severity to an emoji, and posts to a Slack
incoming webhook connection."

Already using the older **Prismatic Skills plugin for Claude Code**
(`/plugin install prismatic-skills@prismatic-skills`)? `/prismatic-skills:orby` works the same way.

## Step 1: Create a Slack incoming webhook

1. Go to [api.slack.com/apps](https://api.slack.com/apps) and click **Create New App** → **From scratch**.
   Name it something like `Alert Relay` and pick your workspace.
2. In the app settings, open **Incoming Webhooks** and turn it **on**.
3. Click **Add New Webhook to Workspace**, pick the channel for alerts (for example
   `#integration-alerts`), and click **Allow**.
4. Copy the webhook URL (`https://hooks.slack.com/services/...`). You'll paste it into
   Prismatic in Step 3, not into this repo.

Treat this URL as a secret. Anyone who has it can post to that channel.

## Step 2: Import the integration

The integration is defined in [prismatic/webinar-alert-relay.yml](../prismatic/webinar-alert-relay.yml).
It's low-code YAML, so you can read it to see exactly what the flow does.

**With the CLI** (from the repo root):

```sh
prism integrations:import --path prismatic/webinar-alert-relay.yml --open
```

This creates an integration called **Webinar Alert Relay** and opens it in the designer.

**Or in the web app:** open **Integrations** from the left-hand menu, click
**+ Add Integration**, choose **Import from YAML**, and upload
`prismatic/webinar-alert-relay.yml`.

In the designer you'll see one flow, **Send Alert**, with three steps:

| Step | What it does |
|---|---|
| **Integration Trigger** | Webhook trigger. Receives `{ severity, title, message, integration, sentAt }` from `send_alert`. |
| **Severity Emoji** | Text Manipulation › Find & Replace Multiple Substrings. Turns `critical` into 🔴, `warning` into 🟠, and `info` into 🔵. |
| **Post to Slack** | Slack › **Post Slack Message From Webhook**, using the **Slack Webhook** connection (Slack's *Webhook URL* connection type, not OAuth). |

The Slack message template, simplified (the real one reads each field from `$integrationTrigger.results.body.data`):

```
{{$severityEmoji.results}} *{{title}}*
{{message}}
_{{integration}} · {{severity}}_
```

The trigger is asynchronous (`isSynchronous: false`). It responds as soon as the execution
is queued, so the agent doesn't wait on Slack.

### Optional: test it in the designer

Before you deploy, you can run the flow from the designer's **Test Runner** drawer at the
bottom of the screen:

1. On the **Test Configuration** tab, open **Test-instance configuration** and set
   **Slack Webhook** to your Slack URL from Step 1.
2. Click **Trigger payload** and enter a sample body:
   ```json
   { "severity": "info", "title": "Designer test", "message": "Hello from Prismatic.", "integration": "Demo" }
   ```
3. Click **Run**. The steps that ran are listed, and you can switch on **Logs** for details.

The **Trigger payload** dialog also shows the test instance's webhook URL. You could point
`.env` at that URL to try things out before deploying, but a deployed instance (Step 3)
is the real setup and the URL you should keep.

## Step 3: Publish and deploy an instance

An **integration** is the definition. An **instance** is that integration deployed for a
customer, with that customer's configuration. The instance is what gets the webhook URL
you'll use.

1. **Publish** the integration. In the designer, open the **Version history** tab, add a
   note, and click **Save & Publish**. (CLI: `prism integrations publish "$INTEGRATION_ID" --comment "Initial version"`,
   using the ID from `prism integrations list --filter 'name=^Webinar Alert Relay$' --columns id,name`.)
2. **Create a customer** to deploy to. For a demo, make one for yourself, such as
   `Webinar Demo`. (In **Customers**, or `prism customers create --name "Webinar Demo"`.)
3. **Add an instance** of *Webinar Alert Relay* for that customer, from the customer's
   **Instances** tab.
4. The configuration wizard asks for **Slack Webhook**. Paste the URL from Step 1.
5. Click **Save and deploy**.

## Step 4: Copy the webhook URL into `.env`

Open the instance and copy the **Send Alert** flow's webhook URL from its trigger details
(the instance's **Triggers** tab). It starts with `https://hooks.prismatic.io/trigger/`.

From the CLI, find the instance ID, then list its flows' webhook URLs:

```sh
prism instances list --filter 'name=^Webinar Alert Relay$' --columns id,name,customer
prism instances flow-configs list 'paste-instance-id-here' --columns name,webhookUrl --no-truncate
```

(Copy the ID by hand. Prism v11 prints list results in a structured format, so the old
`ID=$(prism ... --no-header)` trick captures extra lines along with the ID.)

Put it in `.env`:

```sh
PRISMATIC_ALERT_WEBHOOK_URL=https://hooks.prismatic.io/trigger/...
ALERT_DRY_RUN=0
```

`.env` is gitignored, so don't paste this URL anywhere you'd commit it. Anyone who has it
can trigger the flow.

## Step 5: Smoke test

Before involving the agent, check the webhook by itself. This sends a real Slack message:

```sh
set -a; source .env; set +a
curl -s -X POST "$PRISMATIC_ALERT_WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d '{"severity":"info","title":"Smoke test","message":"Webhook to Slack works.","integration":"Demo"}'
```

You should get back `{"executionId":"..."}`, and a 🔵 message should appear in your channel
a moment later.

## Step 6: Run the payoff

Restart `scripts/claude.sh` so it picks up the new `.env`, then run
[the payoff prompt](../PROMPTS.md#the-payoff-prompt) and approve the `send_alert` call. The tool result shows the HTTP status and Prismatic's
execution ID, and Slack should show something like:

> 🔴 **Acme Corp / Salesforce Sync: auth failing, 1,284 records pending**
> What broke: Salesforce returned 401 INVALID_SESSION_ID on "Fetch Updated Contacts".
> Who's affected: Acme Corp, Salesforce Sync v12, production, instance SW5zdGFu…
> Impact: 3 consecutive failures; last success 12:15 UTC; 1284 records pending.
> Next step: Re-authenticate the Salesforce connection for Acme Corp's instance.
> _Salesforce Sync · critical_

The model writes the text, so your wording will be a little different.

## Troubleshooting

**`status: 200` but nothing in Slack.** A 200 means Prismatic *accepted* the request, not
that Slack received it. Open the instance's **Executions** tab and find the execution ID
from the tool result. The step results show which step failed. Usually the Slack Webhook
connection is wrong or the Slack app was removed from the channel.

From the CLI:

```sh
prism executions get 'paste-execution-id-here'
prism executions logs 'paste-execution-id-here'
```

**404 or 4xx from the webhook.** The instance probably isn't deployed, or the URL came from
a different instance or flow. Copy it again (Step 4).

**The emoji shows as the word `critical`.** The severity text didn't match a replacement
exactly. The MCP server schema only allows `critical`, `warning`, and `info`, so check
for edits in the Severity Emoji step.

## Changing the flow

Edit in the designer and publish (**Version history** › **Save & Publish**). Then move the
instance to the new version: on the instance page, click **Reconfigure**, choose the new
version in **Integration Version**, and click **Save and deploy**.

Or keep the YAML in this repo as the source of truth:

```sh
prism integrations list --filter 'name=^Webinar Alert Relay$' --columns id,name
INTEGRATION_ID='paste-integration-id-here'
prism integrations import --path prismatic/webinar-alert-relay.yml --integration-id "$INTEGRATION_ID"
prism integrations publish "$INTEGRATION_ID" --comment "Describe the change"
# then Reconfigure the instance to the new version, as above
```

Some ideas to try:

- Route `critical` alerts to a different channel with a branch on severity.
- Replace the text message with Slack Block Kit for richer formatting.
- Add a step that opens a ticket for `critical` alerts.

The agent doesn't need to change for any of these.
