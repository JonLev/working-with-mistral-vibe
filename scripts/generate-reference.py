#!/usr/bin/env python3
"""generate-reference.py — generate machine-readable/reference.yaml.

Emits an index of every guide/ page: file path, title, description, tags
(from frontmatter) and headings with line numbers (from the page body). The
schema is documented in machine-readable/schema.md. Replaces the source
repo's hand-maintained 4K-line reference.yaml: the index is now a
generated artifact with a drift check, so "content nobody indexed is
content nobody can find" is enforced mechanically.

Also embeds the `onboarding:` section — the routing spec consumed by
tools/onboarding-prompt.md — from the hand-maintained source
scripts/onboarding.yaml (same pattern as scripts/monolith.yaml). Every stop
is validated at generation: the page must exist and an anchor, when given,
must resolve to a real heading, so a stale route fails the generator
instead of shipping a broken onboarding.

Deterministic: pages sorted by path, no timestamps — regeneration is
byte-identical and the drift check is exact.

Usage:
  scripts/generate-reference.py           # write machine-readable/reference.yaml
  scripts/generate-reference.py --check   # fail (exit 1) if the file drifted
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import markdown  # noqa: E402
import yamlmini  # noqa: E402

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUIDE_DIR = os.path.join(REPO_ROOT, "guide")
OUT_REL = "machine-readable/reference.yaml"
ONBOARDING_REL = "scripts/onboarding.yaml"


def y(value):
    """Emit a YAML flow scalar via JSON (valid YAML, deterministic quoting)."""
    return json.dumps(value, ensure_ascii=False)


def fail(msg):
    sys.exit(f"FAIL {msg}")


def read_version():
    with open(os.path.join(REPO_ROOT, "VERSION"), encoding="utf-8") as f:
        return f.read().strip()


def load_pages():
    pages = []
    for dirpath, dirnames, filenames in os.walk(GUIDE_DIR):
        dirnames.sort()
        for fn in sorted(filenames):
            if not fn.endswith(".md"):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, REPO_ROOT)
            with open(full, encoding="utf-8") as f:
                text = f.read()
            fm, body, offset = yamlmini.parse_frontmatter(text, rel)
            for key in ("title", "description"):
                if not fm.get(key):
                    sys.exit(f"FAIL {rel}: frontmatter missing '{key}'")
            pages.append({
                "rel": rel,
                "fm": fm,
                # heading lines are reported as file line numbers (1-based)
                "headings": [(lvl, txt, line + offset)
                             for lvl, txt, line in markdown.extract_headings(body)],
            })
    pages.sort(key=lambda p: p["rel"])
    return pages


# --- onboarding section (source: scripts/onboarding.yaml) ---

_anchor_cache = {}


def heading_anchors(rel):
    """GitHub-style heading slugs of a repo-relative markdown page (cached)."""
    if rel not in _anchor_cache:
        path = os.path.join(REPO_ROOT, rel)
        if not os.path.isfile(path):
            _anchor_cache[rel] = None
        else:
            with open(path, encoding="utf-8") as f:
                text = f.read()
            _anchor_cache[rel] = {markdown.slugify(t) for _, t, _ in
                                  markdown.extract_headings(text)}
    return _anchor_cache[rel]


def validate_stop(stop, where):
    if not isinstance(stop, dict) or not stop.get("page"):
        fail(f"{ONBOARDING_REL}: {where}: stop needs a 'page'")
    page = stop["page"]
    if heading_anchors(page) is None:
        fail(f"{ONBOARDING_REL}: {where}: page does not exist: {page}")
    anchor = stop.get("anchor")
    if anchor and anchor not in heading_anchors(page):
        fail(f"{ONBOARDING_REL}: {where}: anchor '{anchor}' not found in {page}")


def load_onboarding():
    """Parse and validate scripts/onboarding.yaml; return the spec dict."""
    src = os.path.join(REPO_ROOT, ONBOARDING_REL)
    with open(src, encoding="utf-8") as f:
        try:
            spec = yamlmini.parse(f.read(), ONBOARDING_REL)
        except yamlmini.YamlMiniError as e:
            fail(f"{ONBOARDING_REL}: parse error: {e}")

    for key in ("golden_rules", "goals", "tracks", "routes", "adaptive_triggers"):
        if key not in spec:
            fail(f"{ONBOARDING_REL}: missing '{key}' section")

    for key in ("page", "anchor"):
        if not spec["golden_rules"].get(key):
            fail(f"{ONBOARDING_REL}: golden_rules missing '{key}'")
    validate_stop(spec["golden_rules"], "golden_rules")

    def entry_list(section, fields):
        if not isinstance(spec[section], list) or not spec[section]:
            fail(f"{ONBOARDING_REL}: '{section}' must be a non-empty list")
        seen = set()
        for item in spec[section]:
            for field in fields:
                if not isinstance(item, dict) or not item.get(field):
                    fail(f"{ONBOARDING_REL}: {section} entry missing '{field}'")
            if item["id"] in seen:
                fail(f"{ONBOARDING_REL}: duplicate {section} id '{item['id']}'")
            seen.add(item["id"])
        return seen

    goal_ids = entry_list("goals", ("id", "label", "ask"))
    track_ids = entry_list("tracks", ("id", "label", "entry"))

    if not isinstance(spec["routes"], dict):
        fail(f"{ONBOARDING_REL}: 'routes' must be a mapping of goal -> track -> stops")
    if set(spec["routes"]) != goal_ids:
        missing = goal_ids - set(spec["routes"])
        extra = set(spec["routes"]) - goal_ids
        fail(f"{ONBOARDING_REL}: routes/goals mismatch "
             f"(missing: {sorted(missing)}, unknown: {sorted(extra)})")
    for goal, by_track in spec["routes"].items():
        if not isinstance(by_track, dict) or not by_track:
            fail(f"{ONBOARDING_REL}: routes.{goal}: expected track -> stops")
        for track in by_track:
            if track != "all" and track not in track_ids:
                fail(f"{ONBOARDING_REL}: routes.{goal}: unknown track '{track}'")
        for track in track_ids:
            if track not in by_track and "all" not in by_track:
                fail(f"{ONBOARDING_REL}: routes.{goal}: no route for track "
                     f"'{track}' and no 'all' fallback")
        for track, stops in by_track.items():
            if not isinstance(stops, list) or not stops:
                fail(f"{ONBOARDING_REL}: routes.{goal}.{track}: needs stops")
            for i, stop in enumerate(stops):
                validate_stop(stop, f"routes.{goal}.{track} stop {i + 1}")

    if not isinstance(spec["adaptive_triggers"], list) or not spec["adaptive_triggers"]:
        fail(f"{ONBOARDING_REL}: 'adaptive_triggers' must be a non-empty list")
    for i, trig in enumerate(spec["adaptive_triggers"]):
        where = f"adaptive_triggers entry {i + 1}"
        if not isinstance(trig, dict) or not trig.get("keywords"):
            fail(f"{ONBOARDING_REL}: {where}: needs 'keywords'")
        if not isinstance(trig["keywords"], list) or not trig["keywords"]:
            fail(f"{ONBOARDING_REL}: {where}: 'keywords' must be a non-empty list")
        for kw in trig["keywords"]:
            if not isinstance(kw, str) or not kw:
                fail(f"{ONBOARDING_REL}: {where}: empty keyword")
        validate_stop(trig, where)

    return spec


def build_onboarding(spec):
    out = ["onboarding:"]
    gr = spec["golden_rules"]
    out += [
        "  golden_rules:",
        f"    page: {y(gr['page'])}",
        f"    anchor: {y(gr['anchor'])}",
        "  goals:",
    ]
    for goal in spec["goals"]:
        out += [
            f"    - id: {y(goal['id'])}",
            f"      label: {y(goal['label'])}",
            f"      ask: {y(goal['ask'])}",
        ]
    out.append("  tracks:")
    for track in spec["tracks"]:
        out += [
            f"    - id: {y(track['id'])}",
            f"      label: {y(track['label'])}",
            f"      entry: {y(track['entry'])}",
        ]
    out.append("  routes:")
    for goal in spec["goals"]:
        out.append(f"    {goal['id']}:")
        by_track = spec["routes"][goal["id"]]
        # 'all' first, then explicit tracks, in spec track order.
        ordered = (["all"] if "all" in by_track else []) + \
                  [t["id"] for t in spec["tracks"] if t["id"] in by_track]
        for track in ordered:
            out.append(f"      {track}:")
            for stop in by_track[track]:
                out.append(f"        - page: {y(stop['page'])}")
                if stop.get("anchor"):
                    out.append(f"          anchor: {y(stop['anchor'])}")
                if stop.get("focus"):
                    out.append(f"          focus: {y(stop['focus'])}")
    out.append("  adaptive_triggers:")
    for trig in spec["adaptive_triggers"]:
        out.append("    - keywords: [" + ", ".join(y(k) for k in trig["keywords"]) + "]")
        out.append(f"      page: {y(trig['page'])}")
        if trig.get("anchor"):
            out.append(f"      anchor: {y(trig['anchor'])}")
        if trig.get("focus"):
            out.append(f"      focus: {y(trig['focus'])}")
    return out


def build_reference(pages, version, onboarding):
    out = [
        "# Generated by scripts/generate-reference.py from guide/ frontmatter and headings.",
        "# Do not edit by hand. Schema: machine-readable/schema.md.",
        f'version: "{version}"',
        "pages:",
    ]
    for p in pages:
        fm = p["fm"]
        out.append(f"  - path: {y(p['rel'])}")
        out.append(f"    title: {y(fm['title'])}")
        out.append(f"    description: {y(fm['description'])}")
        tags = fm.get("tags") or []
        if not isinstance(tags, list):
            sys.exit(f"FAIL {p['rel']}: 'tags' must be a list")
        out.append("    tags: [" + ", ".join(y(t) for t in tags) + "]")
        out.append("    headings:")
        if not p["headings"]:
            out.append("      []")
        for level, text, line in p["headings"]:
            out.append(f"      - level: {level}")
            out.append(f"        text: {y(text)}")
            out.append(f"        line: {line}")
    out += build_onboarding(onboarding)
    return "\n".join(out) + "\n"


def main():
    check = "--check" in sys.argv[1:]
    version = read_version()
    content = build_reference(load_pages(), version, load_onboarding())
    path = os.path.join(REPO_ROOT, OUT_REL)

    committed = None
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            committed = f.read()

    if committed != content:
        if check:
            print(f"FAIL {OUT_REL}: drifted from guide/ content; regenerate with "
                  "scripts/generate-reference.py")
            sys.exit(1)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"wrote {OUT_REL}")
    else:
        print(f"{OUT_REL} already up to date" if not check
              else "reference drift check: clean")


if __name__ == "__main__":
    main()
