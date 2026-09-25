// tools.js — the three tool handlers, MCP CallToolResult-shaped so the tests
// (and any future transport) can call them directly without a server.

import { loadReference } from './reference.js';
import { resolveContentPath, readContentFile } from './content.js';
import { sliceSection, headingSuggestions } from './section.js';

function textResult(text, isError = false) {
  const result = { content: [{ type: 'text', text }] };
  if (isError) result.isError = true;
  return result;
}

/**
 * search_guide(query): case-insensitive substring search over page titles,
 * descriptions, tags, and heading texts from content/reference.yaml.
 */
export function searchGuideTool({ query }) {
  if (typeof query !== 'string' || query.trim().length === 0) {
    return textResult('Error: query must be a non-empty string.', true);
  }
  const reference = loadReference();
  const q = query.trim().toLowerCase();

  const results = [];
  for (const page of reference.pages) {
    const matchedHeadings = page.headings.filter((h) => h.text.toLowerCase().includes(q));
    const matchedTags = page.tags.filter((t) => t.toLowerCase().includes(q));
    const titleMatch = page.title.toLowerCase().includes(q);
    const descriptionMatch = page.description.toLowerCase().includes(q);
    if (matchedHeadings.length === 0 && matchedTags.length === 0 && !titleMatch && !descriptionMatch) {
      continue;
    }
    results.push({ page, matchedHeadings, matchedTags, titleMatch, descriptionMatch });
  }

  if (results.length === 0) {
    return textResult(
      [
        `No results found for: "${query}"`,
        '',
        'Tips:',
        '  - Try a shorter keyword: "hooks" instead of "how do hooks work".',
        '  - Try related terms: "agents", "skills", "mcp", "context", "security".',
        '  - Read the file://reference.yaml resource for the full page index,',
        '    or list_pages() for every page with its description.',
      ].join('\n'),
    );
  }

  const lines = [`Found ${results.length} result(s) for: "${query}"`, ''];
  for (const { page, matchedHeadings, matchedTags, titleMatch, descriptionMatch } of results) {
    lines.push(`${page.path} — ${page.title}`);
    if (titleMatch) lines.push('  matched title');
    if (descriptionMatch) lines.push('  matched description');
    for (const tag of matchedTags) lines.push(`  matched tag: ${tag}`);
    for (const h of matchedHeadings) {
      lines.push(`  matched heading: "${h.text}" (line ${h.line})`);
    }
    lines.push(`  → read_page(path="${page.path}")`);
    lines.push('');
  }
  lines.push('Use read_page(path, section) to read a result; cite the guide path when quoting.');
  return textResult(lines.join('\n'));
}

/**
 * read_page(path, section?): return a bundled page's markdown — the whole
 * page, or one section from its heading to the next same-or-higher heading.
 */
export function readPageTool({ path, section }) {
  if (typeof path !== 'string' || path.trim().length === 0) {
    return textResult('Error: path must be a non-empty string.', true);
  }
  const cleaned = path.trim();
  if (resolveContentPath(cleaned) === null) {
    return textResult(
      `Error: invalid path "${cleaned}". Only repo-relative paths inside the bundled guide (e.g. "guide/core/architecture.md") are permitted.`,
      true,
    );
  }

  const raw = readContentFile(cleaned);
  if (raw === null) {
    return textResult(
      [
        `Error: page not found: "${cleaned}".`,
        '',
        'The path must exist in the bundled guide. Use list_pages() for every',
        'available path, or search_guide(query) to find pages by topic.',
      ].join('\n'),
      true,
    );
  }

  if (typeof section === 'string' && section.trim().length > 0) {
    const sliced = sliceSection(raw, section);
    if (sliced === null) {
      const suggestions = headingSuggestions(raw);
      return textResult(
        [
          `Error: section "${section.trim()}" not found in ${cleaned}.`,
          '',
          suggestions.length > 0
            ? ['Headings in this page:', ...suggestions].join('\n')
            : 'This page has no headings.',
        ].join('\n'),
        true,
      );
    }
    return textResult(
      [
        `Page: ${cleaned} (lines ${sliced.startLine}-${sliced.endLine})`,
        `Section: ${section.trim()}`,
        '',
        sliced.text,
        '',
        `Cite the guide path ${cleaned} when quoting.`,
      ].join('\n'),
    );
  }

  const totalLines = raw.split('\n').length;
  return textResult(
    [`Page: ${cleaned} (lines 1-${totalLines})`, '', raw, '', `Cite the guide path ${cleaned} when quoting.`].join('\n'),
  );
}

/**
 * list_pages(): every indexed page path with its title and description.
 */
export function listPagesTool() {
  const reference = loadReference();
  const lines = [
    `The working-with-mistral-vibe guide — ${reference.pages.length} pages (index version ${reference.version})`,
    '',
  ];
  for (const page of reference.pages) {
    lines.push(`${page.path} — ${page.title}`);
    lines.push(`  ${page.description}`);
  }
  lines.push('');
  lines.push('Use search_guide(query) to find pages by topic, read_page(path) to read one.');
  return textResult(lines.join('\n'));
}
