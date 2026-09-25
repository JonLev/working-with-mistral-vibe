// reference.js — load and parse the generated reference index.
//
// The parser targets the exact output format of scripts/generate-reference.py
// (documented in ../machine-readable/schema.md): every scalar is a JSON
// string, pages and headings are fixed-shape lists. That keeps the server to
// one dependency (@modelcontextprotocol/sdk) — no YAML library.

import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const pkg = require('../../package.json');

export const SERVER_NAME = pkg.name;
export const SERVER_VERSION = pkg.version;

export const CONTENT_DIR = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', 'content');
export const REFERENCE_PATH = resolve(CONTENT_DIR, 'reference.yaml');

function jsonValue(raw) {
  return JSON.parse(raw);
}

/**
 * Parse the generated reference.yaml subset into
 * { version, pages: [{ path, title, description, tags, headings }] }.
 */
export function parseReference(text) {
  const version = { current: null };
  const pages = [];
  let page = null;
  let heading = null;
  let inHeadings = false;

  for (const line of text.split('\n')) {
    if (line.startsWith('#')) continue;

    let m = /^version:\s*(.+)$/.exec(line);
    if (m) {
      version.current = jsonValue(m[1]);
      continue;
    }
    m = /^  - path:\s*(.+)$/.exec(line);
    if (m) {
      page = { path: jsonValue(m[1]), title: '', description: '', tags: [], headings: [] };
      pages.push(page);
      inHeadings = false;
      continue;
    }
    if (!page) continue;

    m = /^    title:\s*(.+)$/.exec(line);
    if (m) {
      page.title = jsonValue(m[1]);
      continue;
    }
    m = /^    description:\s*(.+)$/.exec(line);
    if (m) {
      page.description = jsonValue(m[1]);
      continue;
    }
    m = /^    tags:\s*\[(.*)\]$/.exec(line);
    if (m) {
      page.tags = m[1].trim() ? JSON.parse(`[${m[1]}]`) : [];
      continue;
    }
    if (/^    headings:\s*$/.test(line)) {
      inHeadings = true;
      heading = null;
      continue;
    }
    if (/^      \[\]$/.test(line)) {
      inHeadings = false;
      continue;
    }
    m = /^      - level:\s*(\d+)$/.exec(line);
    if (m) {
      heading = { level: Number(m[1]), text: '', line: 0 };
      page.headings.push(heading);
      continue;
    }
    if (!heading) continue;
    m = /^        text:\s*(.+)$/.exec(line);
    if (m) {
      heading.text = jsonValue(m[1]);
      continue;
    }
    m = /^        line:\s*(\d+)$/.exec(line);
    if (m) {
      heading.line = Number(m[1]);
    }
  }

  return { version: version.current, pages };
}

let cache = null;

/** Load and cache the bundled content/reference.yaml index. */
export function loadReference() {
  if (cache) return cache;
  const text = readFileSync(REFERENCE_PATH, 'utf8');
  const parsed = parseReference(text);
  cache = { ...parsed, raw: text };
  return cache;
}

/** Raw text of the bundled reference.yaml (for the file://resource). */
export function getReferenceRaw() {
  return readFileSync(REFERENCE_PATH, 'utf8');
}

/** Find one page entry by repo-relative path, or null. */
export function findPage(reference, path) {
  return reference.pages.find((p) => p.path === path) ?? null;
}
