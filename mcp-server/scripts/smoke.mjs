#!/usr/bin/env node
// smoke.mjs — end-to-end smoke test and transcript for the MCP server.
//
// Spawns the server over stdio as a real client would, performs the
// initialize handshake, lists tools, and exercises the two representative
// calls: fetch a page (read_page) and fetch the reference index (the
// file://reference.yaml resource). Prints a readable transcript; exits 1
// on any failure.
//
// Usage: npm run smoke   (from mcp-server/)

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { spawnSync } from 'node:child_process';

const pkgRoot = new URL('..', import.meta.url).pathname;

function log(label, body) {
  const text = typeof body === 'string' ? body : JSON.stringify(body, null, 2);
  const clipped = text.length > 700 ? `${text.slice(0, 700)}\n  ... [${text.length - 700} more chars]` : text;
  console.log(`--- ${label} ---\n${clipped}\n`);
}

async function main() {
  const node = process.execPath;
  const serverEntry = `${pkgRoot}src/index.js`;

  console.log('=== smoke test: working-with-mistral-vibe-mcp over stdio ===\n');
  console.log(`$ node src/index.js   (spawned by the MCP client)\n`);

  const transport = new StdioClientTransport({
    command: node,
    args: [serverEntry],
  });
  const client = new Client({ name: 'smoke-client', version: '0.0.0' });

  await client.connect(transport);
  log('client connected (initialize handshake done)', { clientInfo: 'smoke-client', transport: 'stdio' });

  const tools = await client.listTools();
  log('tools/list', tools.tools.map((t) => ({ name: t.name, description: t.description.split('\n')[0] })));

  const search = await client.callTool({ name: 'search_guide', arguments: { query: 'hooks.toml' } });
  const searchLines = search.content[0].text.split('\n').slice(0, 6).join('\n');
  log('tools/call search_guide {"query": "hooks.toml"}', searchLines);

  const page = await client.callTool({
    name: 'read_page',
    arguments: { path: 'guide/core/architecture.md', section: 'How the Vibe CLI Works: Architecture and Internals' },
  });
  log('tools/call read_page {"path": "guide/core/architecture.md", "section": "How the Vibe CLI Works: Architecture and Internals"}', page.content[0].text.slice(0, 400));

  const resources = await client.listResources();
  log('resources/list', resources.resources);

  const ref = await client.readResource({ uri: 'file://reference.yaml' });
  const refText = ref.contents[0].text;
  const version = refText.match(/^version: "(.+)"$/m)?.[1];
  const pageCount = (refText.match(/^  - path:/gm) || []).length;
  log('resources/read file://reference.yaml', `version: "${version}"\n  - path: ... (${pageCount} page entries)`);

  await client.close();

  if (!tools.tools.some((t) => t.name === 'read_page')) throw new Error('read_page tool missing');
  if (!searchLines.includes('hooks')) throw new Error('search_guide returned no hooks result');
  if (!page.content[0].text.includes('# How the Vibe CLI Works: Architecture and Internals')) throw new Error('read_page returned wrong content');
  if (version !== '0.1.0') throw new Error(`reference index version mismatch: ${version}`);

  console.log('=== smoke test PASSED: start, connect, two tool calls, one resource read ===');
  process.exit(0);
}

try {
  await main();
} catch (err) {
  console.error(`smoke test FAILED: ${err && err.message ? err.message : err}`);
  if (process.env.SMOKE_DEBUG) {
    const diagnosed = spawnSync(process.execPath, ['--check', `${pkgRoot}src/index.js`]);
    console.error(`index.js syntax check exit: ${diagnosed.status}`);
  }
  process.exit(1);
}
