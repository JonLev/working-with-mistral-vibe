#!/usr/bin/env node
// sync-content.mjs — copy the repo's generated guide artifacts into content/.
//
// content/ is generated, never hand-edited: it mirrors ../machine-readable/reference.yaml,
// ../llms.txt, and the whole ../guide/ tree. This replaces the source repo's
// pattern of manually copying content that then drifted: here the copy is a
// deterministic mirror with a --check drift gate for CI.
//
// Usage:
//   node scripts/sync-content.mjs           # copy; exits 1 on failure
//   node scripts/sync-content.mjs --check   # verify only; exit 1 on drift
//
// No dependencies beyond Node's standard library.

import { spawnSync } from 'node:child_process';
import {
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
} from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const pkgRoot = join(here, '..');
const repoRoot = join(pkgRoot, '..');
const contentDir = join(pkgRoot, 'content');

const SOURCES = [
  { src: join(repoRoot, 'machine-readable', 'reference.yaml'), dest: join(contentDir, 'reference.yaml') },
  { src: join(repoRoot, 'llms.txt'), dest: join(contentDir, 'llms.txt') },
  { src: join(repoRoot, 'guide'), dest: join(contentDir, 'guide') },
];

function fail(message) {
  process.stderr.write(`sync-content: FAIL ${message}\n`);
  process.exit(1);
}

function listFiles(root) {
  const out = [];
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const full = join(root, entry.name);
    if (entry.isDirectory()) out.push(...listFiles(full));
    else out.push(full);
  }
  return out.sort();
}

function bytesEqual(a, b) {
  const fa = readFileSync(a);
  const fb = readFileSync(b);
  return fa.equals(fb);
}

const check = process.argv.includes('--check');

// The sources must exist and be in sync with their own generator before we
// mirror them; otherwise content/ would bundle stale data.
for (const gen of ['generate-reference.py', 'generate-llms.py']) {
  const run = spawnSync('python3', [join(repoRoot, 'scripts', gen), '--check'], { encoding: 'utf8' });
  if (run.status !== 0) {
    fail(`repo source ${gen} has drifted; regenerate it before syncing content/`);
  }
}

for (const { src, dest } of SOURCES) {
  if (!existsSync(src)) fail(`source missing: ${relative(repoRoot, src)}`);

  if (check) {
    if (!existsSync(dest)) fail(`content/ is stale: ${relative(pkgRoot, dest)} is missing (run npm run sync:content)`);
    if (statSync(src).isFile()) {
      if (!bytesEqual(src, dest)) fail(`content/ is stale: ${relative(pkgRoot, dest)} differs from ${relative(repoRoot, src)}`);
    } else {
      const srcFiles = listFiles(src).map((f) => relative(src, f));
      const destFiles = existsSync(dest) ? listFiles(dest).map((f) => relative(dest, f)) : [];
      const srcSet = new Set(srcFiles);
      const destSet = new Set(destFiles);
      for (const f of srcFiles) {
        if (!destSet.has(f)) fail(`content/ is stale: guide/${f} is missing (run npm run sync:content)`);
        else if (!bytesEqual(join(src, f), join(dest, f))) {
          fail(`content/ is stale: guide/${f} differs from the repo source (run npm run sync:content)`);
        }
      }
      for (const f of destFiles) {
        if (!srcSet.has(f)) fail(`content/ is stale: guide/${f} has no repo source (run npm run sync:content)`);
      }
    }
    continue;
  }

  mkdirSync(dirname(dest), { recursive: true });
  if (statSync(src).isFile()) {
    cpSync(src, dest);
  } else {
    rmSync(dest, { recursive: true, force: true });
    cpSync(src, dest, { recursive: true });
  }
}

if (check) {
  console.log('content/ is in sync with the repo sources (check clean)');
} else {
  const guideCount = listFiles(join(contentDir, 'guide')).length;
  console.log(`synced content/: reference.yaml, llms.txt, ${guideCount} guide files`);
}
