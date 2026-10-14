import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "alerts", version: "1.0.0" });

server.registerTool(
  "send_alert",
  {
    title: "Send alert",
    description:
      "Posts an integration alert to the team's alert channel in Slack. " +
      "Triggers a Prismatic flow via webhook, and the flow posts the message. " +
      "Use for integration failures, degradations, and recoveries the team should see. " +
      "The alert is sent as written, so compose the title and message before calling.",
    inputSchema: z
      .object({
        severity: z
          .enum(["info", "warning", "critical"])
          .describe("critical = act now, warning = degraded, info = recovered/FYI"),
        title: z.string().min(1).max(80).describe("One-line headline, max 80 chars"),
        message: z.string().min(1).max(500).describe("Alert body, max 500 chars"),
        integration: z.string().optional().describe("Integration name, e.g. 'Salesforce Sync'"),
      })
      .strict(),
  },
  async ({ severity, title, message, integration }) => {
    const payload = { severity, title, message, integration, sentAt: new Date().toISOString() };

    if (process.env.ALERT_DRY_RUN === "1") {
      return text(`DRY RUN (not sent). Would POST:\n${JSON.stringify(payload, null, 2)}`);
    }

    const url = process.env.PRISMATIC_ALERT_WEBHOOK_URL;
    // An unset var in .mcp.json arrives as the literal "${VAR}" text.
    if (!url || url.startsWith("${")) {
      return text("send_alert is not configured: PRISMATIC_ALERT_WEBHOOK_URL is not set.", true);
    }

    let res: Response;
    try {
      res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(10_000),
      });
    } catch (err) {
      // Report the failure without the URL (it can appear in error causes).
      const reason = err instanceof Error && err.name === "TimeoutError" ? "timed out" : "network error";
      return text(`Alert not sent: webhook request failed (${reason}).`, true);
    }

    const body = await res.text();
    const executionId = parseExecutionId(body);
    const summary = `HTTP ${res.status}` + (executionId ? `, execution ID ${executionId}` : "");
    return res.ok ? text(`Alert sent (${summary}).`) : text(`Alert not sent (${summary}).`, true);
  },
);

function parseExecutionId(body: string): string | undefined {
  try {
    const id = JSON.parse(body)?.executionId;
    return typeof id === "string" ? id : undefined;
  } catch {
    return undefined;
  }
}

function text(t: string, isError = false) {
  return { content: [{ type: "text" as const, text: t }], isError };
}

const transport = new StdioServerTransport();
await server.connect(transport);
