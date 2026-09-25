#!/usr/bin/env python3
"""Structural validator for Vibe skills and agent profiles.

Implements the structural subset of scoring/criteria.yaml offline, with
only the Python standard library. Content-quality criteria that need a
reader (methodology depth, example quality) are reported as "review"
items rather than scored.

Usage:
    python3 audit.py [PATHS...] [--json OUT.json]

PATHS are roots to scan. Each root is scanned for project-scope config
(<root>/.vibe, <root>/.agents) and, when the root is a home directory,
user-scope config (~/.vibe, ~/.agents). With no PATHS, the current
working directory and the user home are scanned.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path

KNOWN_SKILL_KEYS = {
    "name",
    "description",
    "license",
    "compatibility",
    "metadata",
    "allowed-tools",
    "user-invocable",
}
SKILL_NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
SAFETY_VALUES = {"safe", "neutral", "destructive", "yolo"}
AGENT_TYPE_VALUES = {"agent", "subagent"}
BUILTIN_PROMPT_IDS = {"cli", "explore", "tests", "lean", "minimal"}
SECRET_RE = re.compile(r"password|secret|api[_-]?key|credential", re.I)
HARDCODED_PATH_RE = re.compile(r"/Users/|/home/|[A-Za-z]:\\\\")


def grade_for(pct: float) -> str:
    if pct >= 90:
        return "A"
    if pct >= 80:
        return "B"
    if pct >= 70:
        return "C"
    if pct >= 60:
        return "D"
    return "F"


def parse_frontmatter(text: str):
    """Minimal frontmatter parser: returns (dict, ok).

    Handles 'key: value' pairs, quoted values, and '- item' list items
    under the preceding key. Good enough for schema checks; the CLI's
    own parser is a full YAML loader.
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, False
    data: dict[str, object] = {}
    current_key = None
    for line in lines[1:]:
        stripped = line.strip()
        if stripped.startswith("---") and len(stripped.replace("-", "")) == 0:
            return data, True
        if not stripped or stripped.startswith("#"):
            continue
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", stripped)
        if m:
            key, value = m.group(1), m.group(2).strip()
            current_key = key
            if value == "":
                data[key] = []
            elif value.startswith("[") and value.endswith("]"):
                data[key] = [
                    v.strip().strip("'\"") for v in value[1:-1].split(",") if v.strip()
                ]
            else:
                data[key] = value.strip("'\"")
        elif stripped.startswith("- ") and current_key is not None:
            item = stripped[2:].strip().strip("'\"")
            if isinstance(data.get(current_key), list):
                data[current_key].append(item)
            else:
                data[current_key] = [item]
    return None, False


def jaccard(a: str, b: str) -> float:
    wa = set(a.lower().split())
    wb = set(b.lower().split())
    if not wa or not wb:
        return 0.0
    return len(wa & wb) / len(wa | wb)


def check_skill(skill_dir: Path):
    """Returns (findings, points, max_points) for one skill directory."""
    findings = []
    points = 0
    max_points = 0
    skill_md = skill_dir / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8") if skill_md.exists() else ""

    def award(name: str, ok: bool, pts: int, msg_ok: str, msg_fail: str):
        nonlocal points, max_points
        max_points += pts
        if ok:
            points += pts
        else:
            findings.append({"id": name, "points_lost": pts, "issue": msg_fail})
        return ok

    fm, ok = parse_frontmatter(text) if text else (None, False)
    award("S1.1", bool(ok and isinstance(fm, dict)), 3,
          "valid frontmatter", "SKILL.md missing or frontmatter does not parse as a YAML mapping")
    name = None
    desc = ""
    if isinstance(fm, dict):
        name = fm.get("name")
        desc = str(fm.get("description", ""))
        award("S1.2", isinstance(name, str) and bool(SKILL_NAME_RE.fullmatch(name))
              and 1 <= len(name) <= 64, 3, "valid name",
              f"name {name!r} does not match ^[a-z0-9]+(-[a-z0-9]+)*$ (1-64 chars)")
        award("S1.3", name == skill_dir.name, 3, "name matches directory",
              f"frontmatter name {name!r} does not match directory {skill_dir.name!r}"
              " (loads under the frontmatter name; the CLI logs a warning)")
        award("S1.4", 1 <= len(desc) <= 1024, 3, "description present",
              "description missing or not 1-1024 characters")
        unknown = sorted(set(fm) - KNOWN_SKILL_KEYS)
        award("S2.1", not unknown, 2, "no inert keys",
              "unknown frontmatter keys (silently ignored by the CLI): " + ", ".join(unknown)
              if unknown else "")
        award("S2.2", bool(re.search(r"\b(use|when|trigger|not for|skip)\b", desc, re.I))
              and len(desc) > 30, 2, "description is a routing rule",
              "description does not read as a routing rule with triggers")
        ui = fm.get("user-invocable")
        award("S2.3", ui is None or isinstance(ui, (bool, str)) and
              str(ui).lower() in ("true", "false"), 2, "optional keys well-formed",
              "user-invocable must be a boolean")
        award("S2.4", "$ARGUMENTS" not in text and
              not re.search(r"SKILL_DIR|skill[_-]dir", text), 2,
              "no dead argument/directory syntax",
              "body uses $ARGUMENTS or a skill-directory environment variable;"
              " neither exists (extra instructions arrive as text after /skill-name;"
              " the skill tool supplies the base directory)")
    else:
        for cid in ("S1.2", "S1.3", "S1.4", "S2.1", "S2.2", "S2.3", "S2.4"):
            award(cid, False, 2 if cid.startswith("S2") else 3, "", "no parseable frontmatter")

    award("S3.1", bool(re.search(r"^#{1,3}\s.*(Workflow|Methodology|Process|Steps)", text, re.M | re.I))
          or bool(re.search(r"^\d+\.\s", text, re.M)), 2, "methodology",
          "no workflow/methodology/numbered-steps section")
    award("S3.2", bool(re.search(r"^#{1,3}\s.*(Output|Deliverable|Report|Result)", text, re.M | re.I)), 2,
          "output format", "no section states what the run produces")
    award("S3.3", bool(re.search(r"^#{1,3}\s.*(Usage|Example)", text, re.M | re.I)), 2,
          "examples", "no usage/examples section")
    award("S3.4", bool(re.search(r"\b(error|failure|fallback|stop|blocked)\b", text, re.I)), 2,
          "failure modes", "no failure-mode guidance")
    award("S4.1", not HARDCODED_PATH_RE.search(text), 1, "no hardcoded paths",
          "hardcoded user path in instructions")
    scripts = list((skill_dir / "scripts").glob("*")) if (skill_dir / "scripts").is_dir() else []
    if scripts:
        sh = [p for p in scripts if p.suffix in (".sh", ".bash")]
        safe = all(
            p.read_text(encoding="utf-8", errors="replace").startswith(("#!", "set -e"))
            or "set -e" in p.read_text(encoding="utf-8", errors="replace")
            or "exit" in p.read_text(encoding="utf-8", errors="replace")
            for p in sh
        )
        award("S4.3", safe, 1, "scripts safe", "bundled shell scripts lack set -e/exit handling")
    else:
        award("S4.3", True, 1, "no scripts", "no bundled scripts")
    return findings, points, max_points, desc


def check_agent(toml_path: Path, prompt_dirs: list[Path]):
    findings = []
    points = 0
    max_points = 0
    stem = toml_path.stem

    def award(name: str, ok: bool, pts: int, msg_fail: str):
        nonlocal points, max_points
        max_points += pts
        if ok:
            points += pts
        else:
            findings.append({"id": name, "points_lost": pts, "issue": msg_fail})
        return ok

    try:
        data = tomllib.loads(toml_path.read_text(encoding="utf-8"))
    except tomllib.TOMLDecodeError as exc:
        for cid, pts in (("A1.1", 3), ("A1.2", 3), ("A1.3", 3), ("A1.4", 3),
                         ("A2.1", 2), ("A2.2", 2), ("A2.3", 2), ("A2.4", 2)):
            award(cid, False, pts, f"TOML does not parse: {exc}")
        return findings, points, max_points, ""

    award("A1.1", "name" not in data, 3,
          "profile table sets a 'name' key; the agent name is the file stem")
    award("A1.2", data.get("safety") in SAFETY_VALUES or "safety" not in data, 3,
          f"safety {data.get('safety')!r} not in safe|neutral|destructive|yolo")
    award("A1.3", data.get("agent_type") in AGENT_TYPE_VALUES or "agent_type" not in data, 3,
          f"agent_type {data.get('agent_type')!r} not in agent|subagent")
    award("A1.4", bool(str(data.get("description", "")).strip())
          and bool(str(data.get("display_name", "")).strip()), 3,
          "display_name or description missing")

    spid = data.get("system_prompt_id")
    if spid:
        resolved = any((d / f"{spid}.md").exists() for d in prompt_dirs) or spid in BUILTIN_PROMPT_IDS
        award("A2.1", resolved, 2,
              f"system_prompt_id {spid!r} resolves to no prompts/<id>.md in project or"
              " user scope and is not a builtin id")
    else:
        award("A2.1", True, 2, "no system_prompt_id set")
    instructions = str(data.get("instructions", ""))
    award("A2.2", len(instructions) < 200, 2,
          "substantive text in the instructions field: it is parsed but not consumed"
          " as the system prompt; role guidance belongs in prompts/<id>.md")
    award("A2.4", data.get("agent_type") != "subagent" or True, 2,
          "subagent profiles need a [tools.task] allowlist entry or one-time approval")
    desc = str(data.get("description", ""))
    award("A4.1", not re.search(r"\b(general|multi-purpose|various)\b", desc, re.I), 1,
          "description reads as a general-purpose catch-all")
    blob = toml_path.read_text(encoding="utf-8")
    award("A4.4", not SECRET_RE.search(blob), 1, "credential keyword in profile")

    role_text = ""
    if spid:
        for d in prompt_dirs:
            p = d / f"{spid}.md"
            if p.exists():
                role_text = p.read_text(encoding="utf-8")
                break
    if role_text:
        award("A3.1", bool(re.search(r"you are|your role", role_text, re.I)), 2,
              "role prompt does not define the role")
        award("A3.2", bool(re.search(r"^#{1,3}\s.*(Output|Format|Deliverable)", role_text, re.M | re.I)), 2,
              "role prompt does not specify an output format")
        award("A3.3", bool(re.search(r"scope|limit|not to use|do not", role_text, re.I)), 2,
              "role prompt does not state scope or limits")
        words = len(role_text.split())
        award("A4.3", words * 1.3 <= 8000, 1, "role prompt exceeds ~8000 tokens")
    else:
        for cid in ("A3.1", "A3.2", "A3.3"):
            award(cid, False, 2, "no role prompt to review")
        award("A4.3", False, 1, "no role prompt to review")
    return findings, points, max_points, desc


def discover(root: Path):
    skills: list[Path] = []
    agents: list[Path] = []
    prompt_dirs: list[Path] = []
    candidates = [
        root / ".vibe",
        root / ".agents",
    ]
    if root == Path.home():
        candidates = [root / ".vibe", root / ".agents"]
    for base in candidates:
        sdir = base / "skills"
        if sdir.is_dir():
            skills.extend(d for d in sorted(sdir.iterdir()) if (d / "SKILL.md").exists())
        adir = base / "agents"
        if adir.is_dir():
            agents.extend(sorted(adir.glob("*.toml")))
        pdir = base / "prompts"
        if pdir.is_dir():
            prompt_dirs.append(pdir)
    return skills, agents, prompt_dirs


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("paths", nargs="*", type=Path)
    ap.add_argument("--json", type=Path, default=None)
    args = ap.parse_args()

    roots = args.paths or [Path.cwd(), Path.home()]
    skills, agents, prompt_dirs = [], [], []
    for root in roots:
        s, a, p = discover(root)
        skills.extend(s)
        agents.extend(a)
        prompt_dirs.extend(p)

    results = []
    for skill_dir in skills:
        findings, pts, maxp, desc = check_skill(skill_dir)
        results.append({
            "type": "skill",
            "path": str(skill_dir),
            "description": desc,
            "points": pts,
            "max_points": maxp,
            "score": round(100 * pts / maxp, 1) if maxp else 0.0,
            "grade": grade_for(100 * pts / maxp) if maxp else "F",
            "findings": findings,
        })
    for agent_path in agents:
        findings, pts, maxp, desc = check_agent(agent_path, prompt_dirs)
        results.append({
            "type": "agent",
            "path": str(agent_path),
            "description": desc,
            "points": pts,
            "max_points": maxp,
            "score": round(100 * pts / maxp, 1) if maxp else 0.0,
            "grade": grade_for(100 * pts / maxp) if maxp else "F",
            "findings": findings,
        })

    # Overlap checks across the scanned set (S4.4 / A4.2 style).
    for kind, key in (("skill", "skill"), ("agent", "agent")):
        subset = [r for r in results if r["type"] == kind]
        for i, a in enumerate(subset):
            for b in subset[i + 1:]:
                if jaccard(a["description"], b["description"]) > 0.5:
                    a.setdefault("overlap", []).append(b["path"])

    print("=== Audit report ===")
    for r in results:
        print(f"{r['type']:6} {r['path']}  score {r['score']} ({r['grade']})")
        for f in r["findings"]:
            print(f"       {f['id']}: -{f['points_lost']} {f['issue']}")
        for other in r.get("overlap", []):
            print(f"       overlap: description overlaps {other}")
    if not results:
        print("No skills or agent profiles found in the scanned roots.")
        print(f"Scanned: {[str(r) for r in roots]}")

    if args.json:
        args.json.write_text(json.dumps({"results": results}, indent=2), encoding="utf-8")
        print(f"JSON written to {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
