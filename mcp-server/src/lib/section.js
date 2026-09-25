// section.js — slice one section out of a markdown page.
//
// A section runs from its ATX heading to the next heading of the same or
// higher level (or end of file). Headings inside fenced code blocks do not
// count, matching the guide's generator.

/**
 * Extract ATX headings from markdown: [{ level, text, line }] with 1-based
 * file line numbers. Skips fenced code blocks.
 */
export function extractHeadings(text) {
  const headings = [];
  let inFence = false;
  const lines = text.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^\s*(```|~~~)/.test(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    const m = /^(#{1,6})\s+(.+?)\s*#*\s*$/.exec(line);
    if (m) {
      headings.push({ level: m[1].length, text: m[2].trim(), line: i + 1 });
    }
  }
  return headings;
}

function slugify(text) {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/[\s_-]+/g, '-');
}

/**
 * Slice the section named `section` out of `text`. Matching is
 * case-insensitive on the heading text or its slug. Returns
 * { text, startLine, endLine } or null when no heading matches.
 */
export function sliceSection(text, section) {
  const headings = extractHeadings(text);
  const wanted = section.trim().toLowerCase();
  const wantedSlug = slugify(section);
  const start = headings.find(
    (h) => h.text.toLowerCase() === wanted || slugify(h.text) === wantedSlug,
  );
  if (!start) return null;

  const end = headings.find((h) => h.line > start.line && h.level <= start.level);
  const lines = text.split('\n');
  const lastLine = end ? end.line - 1 : lines.length;
  return {
    text: lines.slice(start.line - 1, lastLine).join('\n').trimEnd(),
    startLine: start.line,
    endLine: lastLine,
  };
}

/** Heading texts for "closest matches" suggestions on a failed lookup. */
export function headingSuggestions(text, limit = 8) {
  return extractHeadings(text)
    .slice(0, limit)
    .map((h) => `  - ${h.text} (level ${h.level}, line ${h.line})`);
}
