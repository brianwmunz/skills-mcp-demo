---
name: alert-writer
description: Writes integration-failure alerts for the team's alert channel. Decides whether an event deserves an alert, assigns severity (critical, warning, info), and formats a short, secret-free message. Use when an integration, instance, flow, or execution fails, degrades, retries, or recovers, or when asked to write, draft, or send an alert or incident notice about an integration.
---

# Alert Writer

Turn one integration event into one short alert that someone on the
integrations team can act on in under a minute.

## 1. Decide whether to alert

Alert when any of these is true:

- A production instance has failed 2+ times in a row, or for 15+ minutes.
- Authentication fails (401/403, expired or revoked credentials). These never fix themselves.
- Records are piling up and not syncing.
- A problem you already alerted on has recovered (send `info` so people stand down).

Do not alert when:

- A single failure was followed by a successful retry.
- The environment is not production (sandbox, staging, test), unless asked.
- The same instance and error were already alerted in the last hour.
- The event is missing the customer or integration. Ask instead of guessing.

If you decide not to alert, say why in one sentence and stop.

## 2. Pick a severity

| Severity   | Use when |
|------------|----------|
| `critical` | Production AND (data is not syncing OR auth is failing). Someone must act now. |
| `warning`  | Degraded: retrying, partial failures, rate limits, slowness, transient errors. |
| `info`     | Recovered, resolved, or FYI. No action needed. |

## 3. Write the alert

**Title** (max 80 chars): `<Customer> / <Integration>: <what broke>`

**Message** (max 500 chars): exactly four lines, in this order:

```
What broke: <failing step and error in plain words, with the error code>
Who's affected: <customer, integration, environment, instance ID>
Impact: <failures in window, records pending, time since last success>
Next step: <one concrete action>
```

## 4. Rules

- Lead with the customer and integration, in the title and the first thing a reader sees.
- Never include secrets, tokens, API keys, passwords, session values, webhook URLs,
  or raw request/response payloads. Name the error code, not the payload.
- Message stays at or under 500 characters. Cut adjectives first, never facts.
- Use only numbers and timestamps from the event. If something is unknown, write "unknown".
- Times in UTC, e.g. "last success 12:15 UTC (3h 27m before failure)".
- Plain, calm wording. No emoji, no @here/@channel, no "URGENT".

## 5. Send it

If an alert is warranted and a `send_alert` tool is available (it may appear as
`mcp__alerts__send_alert`), call it with `severity`, `title`, `message`, and
`integration` (the integration name). Do not ask for confirmation first.
Then report the severity, title, and the tool's result in two lines.

If no `send_alert` tool is available, show the alert in the format above and
say that it was not sent.

## Example

Event: Initech's NetSuite Orders instance (production) hit HTTP 429 twice in
10 minutes and is retrying; the next retry succeeded for some records.

```
severity: warning
title: Initech / NetSuite Orders: rate limited, retrying
message:
What broke: NetSuite returned 429 RATE_LIMIT_EXCEEDED on "Create Sales Orders".
Who's affected: Initech, NetSuite Orders, production, instance SW5zdGFuY2U6YjE5.
Impact: 2 failures in 10 min; retries partially succeeding; 40 orders queued.
Next step: Watch the next 2 runs; if 429s continue, lower batch size to 50.
```
