import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

import { createServer } from '../src/server.js';
import { searchGuideTool, readPageTool, listPagesTool } from '../src/lib/tools.js';
import { loadReference } from '../src/lib/reference.js';

const here = dirname(fileURLToPath(import.meta.url));
const pkgRoot = join(here, '..');
const repoRoot = join(pkgRoot, '..');

// -- Tool handler contracts (direct calls, no transport) -----------------------

test('search_guide("hooks") returns the hooks events reference page', () => {
  const result = searchGuideTool({ query: 'hooks' });
  assert.equal(result.isError, undefined);
  const text = result.content[0].text;
  assert.ok(
    text.includes('guide/core/hooks-events-reference.md'),
    `expected hooks-events-reference.md in results, got:\n${text}`,
  );
});

test('search_guide matches case-insensitively across titles, descriptions, tags, and headings', () => {
  const upper = searchGuideTool({ query: 'HOOKS' });
  assert.ok(upper.content[0].text.includes('guide/core/hooks-events-reference.md'));
  // "diagrams" appears as a tag on the diagrams pages
  const tagged = searchGuideTool({ query: 'diagrams' });
  assert.ok(tagged.content[0].text.includes('guide/diagrams/01-foundations.md'));
});

test('search_guide reports which headings matched', () => {
  const result = searchGuideTool({ query: 'compaction' });
  const text = result.content[0].text;
  assert.ok(text.includes('guide/core/architecture.md'));
  assert.match(text, /matched heading/i);
});

test('search_guide returns a clean empty result, not an error, on no match', () => {
  const result = searchGuideTool({ query: 'zzz-no-such-topic-zzz' });
  assert.equal(result.isError, undefined);
  assert.match(result.content[0].text, /no results/i);
});

test('read_page("guide/core/architecture.md") returns the page with its title', async () => {
  const result = await readPageTool({ path: 'guide/core/architecture.md' });
  assert.equal(result.isError, undefined);
  const text = result.content[0].text;
  assert.ok(text.includes('How the Vibe CLI Works: Architecture and Internals'));
  assert.ok(text.includes('guide/core/architecture.md'));
});

test('read_page with a bogus path returns a clean error', async () => {
  const result = await readPageTool({ path: 'guide/nope/does-not-exist.md' });
  assert.equal(result.isError, true);
  assert.match(result.content[0].text, /not found/i);
  assert.ok(result.content[0].text.includes('guide/nope/does-not-exist.md'));
});

test('read_page rejects path traversal and absolute paths', async () => {
  for (const bad of ['../package.json', '/etc/passwd', 'guide/../../VERSION']) {
    const result = await readPageTool({ path: bad });
    assert.equal(result.isError, true, `expected error for ${bad}`);
  }
});

test('read_page with a section anchor returns heading to next same-or-higher heading', async () => {
  const result = await readPageTool({
    path: 'guide/core/architecture.md',
    section: '1. The master loop',
  });
  assert.equal(result.isError, undefined);
  const text = result.content[0].text;
  assert.ok(text.includes('## 1. The master loop'), 'starts at the named heading');
  assert.ok(text.includes('Verified surface audit'), 'includes nested deeper headings');
  assert.ok(!text.includes('## 2. The tool surface'), 'stops before the next same-level heading');
});

test('read_page with an unknown section anchor returns a clean error', async () => {
  const result = await readPageTool({
    path: 'guide/core/architecture.md',
    section: 'No Such Section Here',
  });
  assert.equal(result.isError, true);
  assert.match(result.content[0].text, /section/i);
});

test('list_pages includes the cheatsheet and diagrams pages', () => {
  const result = listPagesTool({});
  const text = result.content[0].text;
  assert.ok(text.includes('guide/cheatsheet.md'), 'cheatsheet page listed');
  assert.ok(text.includes('guide/diagrams/01-foundations.md'), 'diagrams page listed');
  const ref = loadReference();
  for (const page of ref.pages) {
    assert.ok(text.includes(page.path), `every page listed: ${page.path}`);
    assert.ok(text.includes(page.title), `title listed for ${page.path}`);
  }
});

// -- Bundled content contract -------------------------------------------------

test('the bundled reference resource loads and reports the guide version', async () => {
  const ref = loadReference();
  const version = (await readFile(join(repoRoot, 'VERSION'), 'utf8')).trim();
  assert.equal(ref.version, version, 'reference.yaml version matches VERSION');
  assert.ok(ref.pages.length >= 50, `expected the full index, got ${ref.pages.length} pages`);
  assert.ok(existsSync(join(pkgRoot, 'content', 'reference.yaml')));
  assert.ok(existsSync(join(pkgRoot, 'content', 'llms.txt')));
});

test('content/ is in sync with the repo sources (sync:content:check)', () => {
  const run = spawnSync(process.execPath, [join(pkgRoot, 'scripts', 'sync-content.mjs'), '--check'], {
    encoding: 'utf8',
  });
  assert.equal(run.status, 0, `sync-content --check failed:\n${run.stdout}${run.stderr}`);
});

test('no banned terms in authored mcp-server files', { concurrency: false }, async () => {
  // content/ here is a generated mirror of the guide sources. This test
  // polices what this package authors: src, scripts, test, and the manifests.
  // The pattern is assembled from fragments so this file does not contain the
  // literal terms of the product the guide migrated away from.
  const banned = new RegExp(
    ['cla' + 'ude', 'anthro' + 'pic', 'settings' + '.json', 'hooks' + '.json'].join('|'),
    'i',
  );
  const scanDirs = ['src', 'test', 'scripts'];
  const scanned = [];
  async function walk(dir) {
    for (const entry of await readdir(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) await walk(full);
      else if (/\.(js|mjs|json|yaml|yml|md|txt)$/.test(entry.name)) scanned.push(full);
    }
  }
  for (const dir of scanDirs) await walk(join(pkgRoot, dir));
  for (const f of ['package.json', 'server.json', 'README.md', 'LICENSE']) {
    scanned.push(join(pkgRoot, f));
  }
  const offenders = [];
  for (const file of scanned) {
    const text = await readFile(file, 'utf8').catch(() => '');
    if (banned.test(text)) offenders.push(relative(pkgRoot, file));
  }
  assert.deepEqual(offenders, [], `banned terms found in: ${offenders.join(', ')}`);
});

// -- SDK client over stdio -----------------------------------------------------

test('server speaks MCP over stdio: tools list, search call, reference resource', async () => {
  const { Client } = await import('@modelcontextprotocol/sdk/client/index.js');
  const { StdioClientTransport } = await import('@modelcontextprotocol/sdk/client/stdio.js');

  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [join(pkgRoot, 'src', 'index.js')],
  });
  const client = new Client({ name: 'test-client', version: '0.0.0' });
  await client.connect(transport);
  try {
    const tools = await client.listTools();
    const names = tools.tools.map((t) => t.name).sort();
    assert.deepEqual(names, ['list_pages', 'read_page', 'search_guide']);

    const search = await client.callTool({ name: 'search_guide', arguments: { query: 'hooks' } });
    const text = search.content[0].text;
    assert.ok(text.includes('guide/core/hooks-events-reference.md'));

    const read = await client.callTool({
      name: 'read_page',
      arguments: { path: 'guide/core/architecture.md' },
    });
    assert.ok(read.content[0].text.includes('How the Vibe CLI Works: Architecture and Internals'));

    const resource = await client.readResource({ uri: 'file://reference.yaml' });
    const resourceText = resource.contents[0].text;
    assert.match(resourceText, /^version: "0\.1\.0"$/m);
    assert.ok(resourceText.includes('guide/core/architecture.md'));
  } finally {
    await client.close();
  }
});

test('createServer wires the tools and resource onto a Server', async () => {
  const server = createServer();
  assert.ok(server, 'createServer returns a Server');
  await server.close();
});
