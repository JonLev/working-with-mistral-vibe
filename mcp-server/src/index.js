#!/usr/bin/env node
// index.js — stdio transport entry point for the working-with-mistral-vibe MCP server.

import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { createServer } from './server.js';

async function main() {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  process.stderr.write(`[working-with-mistral-vibe-mcp] fatal: ${err}\n`);
  process.exit(1);
});
