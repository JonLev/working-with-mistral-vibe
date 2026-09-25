"""markdown helpers shared by the gates and generators (stdlib only).

Contains: fenced-code stripping, heading extraction with line numbers,
GitHub-style slugs, and relative-link extraction. All consumers rely on
deterministic behavior; no timestamps, no randomness.
"""

from __future__ import annotations

import re

FENCE_RE = re.compile(r"^(```+|~~~+)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*#*\s*$")
INLINE_CODE_RE = re.compile(r"`+[^`]*`+")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
SCHEME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.\-]*:")


def iter_prose_lines(text):
    """Yield (lineno, line) for every line outside fenced code blocks."""
    fence = None
    for lineno, line in enumerate(text.splitlines(), 1):
        stripped = line.lstrip()
        if fence is not None:
            if stripped.startswith(fence):
                fence = None
            continue
        m = FENCE_RE.match(stripped)
        if m:
            fence = m.group(1)
            continue
        yield lineno, line


def extract_link_targets(line):
    """Return raw link/image targets in a prose line.

    A match is skipped when it starts inside an inline code span (regex
    literals like `^...](?:...)` are not links). Links whose *text* is
    backticked — [`file`](path) — are kept: the match starts outside the span.
    """
    spans = [(m.start(), m.end()) for m in INLINE_CODE_RE.finditer(line)]
    targets = []
    for m in LINK_RE.finditer(line):
        if any(s < m.start() < e for s, e in spans):
            continue
        targets.append(m.group(1).strip())
    return targets


def extract_headings(text):
    """Return [(level, heading_text, line_no)] for ATX headings outside code fences."""
    headings = []
    for lineno, line in iter_prose_lines(text):
        m = HEADING_RE.match(line.strip())
        if m:
            headings.append((len(m.group(1)), m.group(2).strip(), lineno))
    return headings


def slugify(heading_text):
    """GitHub-style heading anchor."""
    s = heading_text.strip().lower()
    s = re.sub(r"[^\w\- ]", "", s)
    return s.replace(" ", "-")
