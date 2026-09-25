#!/bin/bash
# check-links.sh — link gate: every relative markdown link and image reference
# inside the repo must resolve to an existing file.
#
# Scope: all .md files in the working tree (untracked files included), except
# scripts/ (gate self-test fixtures live there).
# v1 checks file existence only for prose links — anchors are not verified for
# prose, and external URLs are ignored (no network in the gate).
#
# Mermaid diagram hrefs (click <id> href "target" inside fenced mermaid
# blocks) are held to a stricter zero-tolerance rule: the target
# file must exist AND, when an anchor is given, it must resolve to a heading
# of the target file. Diagram click hrefs must be repo-relative.
#
# Used by: .pre-commit-config.yaml and .github/workflows/ci.yml.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

python3 - "$REPO_ROOT" <<'PY'
import os
import re
import sys
from urllib.parse import unquote

sys.path.insert(0, os.path.join("scripts", "lib"))
import markdown  # noqa: E402

repo = sys.argv[1]
errors = []

CLICK_RE = re.compile(r'\bclick\s+\S+\s+href\s+"([^"]+)"')

_heading_cache = {}


def heading_anchors(path):
    if path not in _heading_cache:
        with open(path, encoding="utf-8") as f:
            _heading_cache[path] = {
                markdown.slugify(text) for _, text, _ in markdown.extract_headings(f.read())
            }
    return _heading_cache[path]


def check_mermaid_hrefs(full, rel, text):
    fence = None
    for lineno, line in enumerate(text.splitlines(), 1):
        stripped = line.lstrip()
        if fence is not None:
            if stripped.startswith(fence):
                fence = None
            else:
                for m in CLICK_RE.finditer(line):
                    target = m.group(1).strip()
                    if target.startswith(("#", "//")) or markdown.SCHEME_RE.match(target):
                        continue  # same-page fragment / external URL
                    path, _, anchor = target.partition("#")
                    if not path:
                        continue
                    resolved = os.path.normpath(os.path.join(os.path.dirname(full), unquote(path)))
                    if not os.path.exists(resolved):
                        errors.append(f"{rel}:{lineno}: broken mermaid href -> {target}")
                        continue
                    if anchor and anchor not in heading_anchors(resolved):
                        errors.append(f"{rel}:{lineno}: mermaid href anchor not found -> {target}")
            continue
        m = re.match(r"^(```+|~~~+)\s*mermaid", stripped)
        if m:
            fence = m.group(1)[:3]


for dirpath, dirnames, filenames in os.walk(repo):
    dirnames[:] = sorted(
        d for d in dirnames
        if d not in (".git", "node_modules", "__pycache__")
        and not (dirpath == repo and d == "scripts")
        # mcp-server/content/ is a generated mirror of guide/ + indexes;
        # its relative links are gated at their source, not in the copy.
        and not (os.path.basename(dirpath) == "mcp-server" and d == "content")
    )
    for fn in sorted(filenames):
        if not fn.endswith(".md"):
            continue
        full = os.path.join(dirpath, fn)
        rel = os.path.relpath(full, repo)
        with open(full, encoding="utf-8") as f:
            text = f.read()
        check_mermaid_hrefs(full, rel, text)
        for lineno, line in markdown.iter_prose_lines(text):
            for target in markdown.extract_link_targets(line):
                if target.startswith("#"):
                    continue  # same-page fragment
                if target.startswith("//") or markdown.SCHEME_RE.match(target):
                    continue  # external URL / protocol-relative
                path = unquote(target.split("#", 1)[0].strip())
                if not path:
                    continue
                resolved = os.path.normpath(os.path.join(os.path.dirname(full), path))
                if not os.path.exists(resolved):
                    errors.append(f"{rel}:{lineno}: broken link -> {target}")

for e in errors:
    print(f"FAIL {e}")
if errors:
    print(f"link gate: {len(errors)} broken link(s)")
    sys.exit(1)
print("link gate: clean")
PY
