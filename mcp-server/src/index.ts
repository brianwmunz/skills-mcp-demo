import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "alerts", version: "1.0.0" });

// TODO: register send_alert tool here

const transport = new StdioServerTransport();
await server.connect(transport);
