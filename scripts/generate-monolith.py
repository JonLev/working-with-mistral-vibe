#!/usr/bin/env python3
"""generate-monolith.py — generate guide/vibe-guide.md (the monolith spine).

The spine is DELEGATION-ONLY by construction: chapters carry a one-paragraph
intro and a TL;DR authored once in scripts/monolith.yaml (spine-only prose),
then per-page entries built live from each page's frontmatter description and
the FIRST SENTENCE of its TL;DR block. No paragraph of a deep-dive page can
end up in the spine, and the spine cannot drift from the pages: when a page's
title, description, or TL;DR changes, regeneration picks it up and --check
fails until the spine is regenerated.

Chapter structure mirrors the source guide's 11-chapter monolith shape
, adapted to this repo's tree; the source's ecosystem-survey chapter
is deliberately not ported.

Deterministic: no timestamps; chapter order comes from the spec file.

Usage:
  scripts/generate-monolith.py           # write guide/vibe-guide.md
  scripts/generate-monolith.py --check   # fail (exit 1) if the file drifted
"""

from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import markdown  # noqa: E402
import yamlmini  # noqa: E402

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC_REL = "scripts/monolith.yaml"
OUT_REL = "guide/vibe-guide.md"
GUIDE_PREFIX = os.path.join("guide", "")

SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?])\s+(?=[A-Z0-9])")
TLDR_BQ_RE = re.compile(r"^>\s*\*\*TL;DR\.?\*\*\s*(.*)$")
TLDR_BOLD_RE = re.compile(r"^\*\*TL;DR\*\*:?\s*(.*)$")
ENUM_PREFIX_RE = re.compile(r"^\d+[.)]\s*")
MIN_DIGEST_CHARS = 40


def fail(msg):
    sys.exit(f"FAIL {msg}")


def read_version():
    with open(os.path.join(REPO_ROOT, "VERSION"), encoding="utf-8") as f:
        return f.read().strip()


def first_sentence(text):
    text = " ".join(text.split())
    parts = SENTENCE_SPLIT_RE.split(text, maxsplit=1)
    return parts[0].strip()


def extract_tldr(rel, body):
    """Return the TL;DR text of a page. Supports the three repo forms:
    a '> **TL;DR.** ...' blockquote, a '## TL;DR' heading followed by
    bullets, or a '**TL;DR**: ...' bold paragraph. Fails loudly if none
    is present."""
    lines = body.splitlines()
    for i, line in enumerate(lines):
        m = TLDR_BQ_RE.match(line.strip())
        if m:
            collected = [m.group(1)]
            j = i + 1
            while j < len(lines) and lines[j].lstrip().startswith(">"):
                collected.append(lines[j].lstrip().lstrip(">").strip())
                j += 1
            return " ".join(part for part in collected if part)
        m = TLDR_BOLD_RE.match(line.strip())
        if m:
            collected = [m.group(1)]
            j = i + 1
            while j < len(lines) and lines[j].strip():
                collected.append(lines[j].strip())
                j += 1
            return " ".join(collected)
        if line.strip() == "## TL;DR":
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j >= len(lines):
                fail(f"{rel}: '## TL;DR' heading has no content")
            first = lines[j].strip()
            fence = None
            for prefix in ("```", "~~~"):
                if first.startswith(prefix):
                    fence = prefix
                    break
            if fence:
                j += 1
                collected = []
                while j < len(lines) and not lines[j].strip().startswith(fence):
                    part = ENUM_PREFIX_RE.sub("", lines[j].strip())
                    if part:
                        collected.append(part)
                    j += 1
                return "; ".join(collected)
            else:
                collected = [first.lstrip("- ").strip()]
                j += 1
                while (j < len(lines) and lines[j].strip()
                       and not lines[j].lstrip().startswith("#")):
                    collected.append(lines[j].strip())
                    j += 1
            return " ".join(part for part in collected if part)
    fail(f"{rel}: no TL;DR block found (neither '> **TL;DR.**', "
          f"'## TL;DR', nor '**TL;DR**: ...')")


def load_page(entry):
    """entry is either a path string (a guide page: title, description, and
    TL;DR digest are pulled live from the page) or a mapping with path,
    title, and blurb (for satellite pages outside the guide page contract —
    the spine still links them, but their text is authored in the spec)."""
    if isinstance(entry, str):
        path_rel = entry
        explicit = None
    else:
        path_rel = entry.get("path")
        explicit = entry
        if not explicit.get("title") or not explicit.get("blurb"):
            fail(f"{SPEC_REL}: mapping page entries need 'path', 'title', 'blurb': {entry}")
    if not path_rel:
        fail(f"{SPEC_REL}: page entry without a path")
    full = os.path.join(REPO_ROOT, path_rel)
    if not os.path.exists(full):
        fail(f"{SPEC_REL}: page does not exist: {path_rel}")
    if explicit is not None:
        link = os.path.relpath(path_rel, "guide")
        return {
            "title": explicit["title"].strip(),
            "description": explicit["blurb"].strip().rstrip("."),
            "digest": explicit["blurb"].strip().rstrip("."),
            "link": link,
            "is_explicit": True,
        }
    with open(full, encoding="utf-8") as f:
        text = f.read()
    fm, body, _offset = yamlmini.parse_frontmatter(text, path_rel)
    for key in ("title", "description"):
        if not fm.get(key):
            fail(f"{path_rel}: frontmatter missing '{key}'")
    tldr = extract_tldr(path_rel, body)
    digest = first_sentence(tldr)
    if len(digest) < MIN_DIGEST_CHARS:
        # A list-shaped TL;DR can yield a too-short first "sentence"
        # (e.g. "1."); widen to the first three sentences instead.
        digest = " ".join(SENTENCE_SPLIT_RE.split(tldr)[:3]).strip()
    if len(digest) < MIN_DIGEST_CHARS:
        fail(f"{path_rel}: TL;DR first sentence too short to route: '{digest}'")
    if not path_rel.startswith(GUIDE_PREFIX):
        link = os.path.relpath(path_rel, "guide")
    else:
        link = path_rel[len(GUIDE_PREFIX):]
    return {
        "title": fm["title"].strip(),
        "description": fm["description"].strip().rstrip("."),
        "digest": digest.rstrip("."),
        "link": link,
        "is_explicit": False,
    }


def page_line(page):
    if page["is_explicit"]:
        return (f"- **Full coverage → [{page['title']}]({page['link']})** — "
                f"{page['description']}.")
    return (f"- **Full coverage → [{page['title']}]({page['link']})** — "
            f"{page['description']}. TL;DR opens: \"{page['digest']}.\"")


def build_monolith(spec, version):
    out = []
    chapters = spec.get("chapters")
    appendices = spec.get("appendices")
    if not chapters:
        fail(f"{SPEC_REL}: 'chapters' missing or empty")
    if not appendices:
        fail(f"{SPEC_REL}: 'appendices' missing or empty")

    out.append("---")
    out.append('title: "Working with Mistral AI Vibe"')
    out.append('description: "The monolith spine of the guide: twelve chapters routing every topic to its deep-dive page, with generated per-page digests. Delegation only - every mechanic lives in the page it links to"')
    out.append("tags: [guide, monolith, index]")
    out.append("---")
    out.append("")
    out.append("# Working with Mistral AI Vibe")
    out.append("")
    out.append(f"> **{spec['banner']}** Documented surface: {spec['surface']}.")
    out.append("> Mechanics cite the oracle, [`verified-mechanics.md`](../docs/mechanics/verified-mechanics.md), as `(PART-XXX)`.")
    out.append("")
    out.append("This is a community guide, not official Mistral documentation. Every")
    out.append("mechanic it routes to is verified against the public CLI surface and cited")
    out.append("against the mechanics oracle; use it critically. Structure and pedagogy are")
    out.append("adapted from Florian Bruniaux's community guide with attribution and")
    out.append("share-alike recorded in [`NOTICE.md`](../NOTICE.md).")
    out.append("")
    out.append("> **TL;DR.** This page is the map, not the territory: twelve chapters")
    out.append("> route every topic to the deep-dive page that owns it, one paragraph of")
    out.append("> spine prose per chapter and a generated digest per page. If you want a")
    out.append("> mechanic, follow the link; if you want the whole guide condensed to")
    out.append("> tables, that is the [cheatsheet](cheatsheet.md).")
    out.append("")
    out.append("**Read if** you are new to the guide and want the tour before choosing a")
    out.append("path. **Skip if** you already know what you need — the [guide index](README.md)")
    out.append("lists every page flat, and the [cheatsheet](cheatsheet.md) answers daily")
    out.append("lookup questions faster than this spine.")
    out.append("")
    out.append("The spine is generated (`scripts/generate-monolith.py`, spec in")
    out.append("`scripts/monolith.yaml`) and never edited by hand; a paragraph that")
    out.append("exists in a deep-dive page must not exist here, and the generator")
    out.append("enforces it by never copying page prose — per-page entries are built")
    out.append("from frontmatter and the first sentence of each page's TL;DR.")
    out.append("")
    out.append("## Contents")
    out.append("")
    for i, ch in enumerate(chapters, 1):
        anchor = markdown.slugify(f"{i}. {ch['title']}")
        out.append(f"{i}. [{ch['title']}](#{anchor})")
    out.append("")
    out.append("Appendices:")
    out.append("")
    for ap in appendices:
        anchor = markdown.slugify(ap["title"])
        out.append(f"- [{ap['title']}](#{anchor})")
    out.append("")

    for i, ch in enumerate(chapters, 1):
        out.append(f"## {i}. {ch['title']}")
        out.append("")
        out.append(" ".join(line.strip() for line in ch["intro"].strip().splitlines()))
        out.append("")
        out.append("> **TL;DR.** " + " ".join(ch["tldr"].strip().splitlines()))
        out.append("")
        for path_rel in ch["pages"]:
            out.append(page_line(load_page(path_rel)))
        out.append("")

    for ap in appendices:
        out.append(f"## {ap['title']}")
        out.append("")
        out.append(" ".join(line.strip() for line in ap["intro"].strip().splitlines()))
        out.append("")
        for path_rel in ap["pages"]:
            out.append(page_line(load_page(path_rel)))
        out.append("")

    out.append("## Known gaps")
    out.append("")
    out.append("- **Commercial claims are not oracle-verified.** Plan, price, and seat")
    out.append("  rows anywhere in this guide are dated snapshots of public pages,")
    out.append("  reproduced as evidence, never as quotes.")
    out.append("- **This spine routes; it does not teach.** If a mechanic you need is")
    out.append("  missing from the page it routes to, the gap belongs there, not here.")
    out.append("")
    out.append("## About this guide")
    out.append("")
    out.append(f"Guide version {version}. Structure and pedagogy adapted from the")
    out.append("community guide by Florian Bruniaux (CC BY-SA 4.0); mechanics rewritten")
    out.append("and independently verified against Mistral's Vibe products from public")
    out.append("sources — see [`NOTICE.md`](../NOTICE.md) for the license split and the")
    out.append("attribution chain.")
    return "\n".join(out) + "\n"


def main():
    check = "--check" in sys.argv[1:]
    with open(os.path.join(REPO_ROOT, SPEC_REL), encoding="utf-8") as f:
        spec = yamlmini.parse(f.read(), SPEC_REL)
    content = build_monolith(spec, read_version())
    path = os.path.join(REPO_ROOT, OUT_REL)

    committed = None
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            committed = f.read()

    if committed != content:
        if check:
            print(f"FAIL {OUT_REL}: drifted from the spec and guide pages; "
                  "regenerate with scripts/generate-monolith.py")
            sys.exit(1)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"wrote {OUT_REL}")
    else:
        print(f"{OUT_REL} already up to date" if not check
              else "monolith drift check: clean")


if __name__ == "__main__":
    main()
