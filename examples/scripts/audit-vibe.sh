#!/bin/bash
# audit-vibe.sh — audit a Vibe setup: config, skills, agents, hooks,
# plugins, MCP drift.
#
# Scans the user layer (~/.vibe) and the project layer (the .vibe/ root
# discovered upward from the working directory — only if that root is
# trusted; an untrusted project layer is ignored by the CLI and reported
# here as such) and prints findings. Findings are data, not errors: the
# script exits 0 unless it crashes.
#
# Usage:
#   bash audit-vibe.sh            # human-readable report (default)
#   bash audit-vibe.sh --json     # one JSON object
#   bash audit-vibe.sh --help
#
# Layout facts it relies on (all verified against the CLI source and live
# tree; see docs/mechanics/verified-mechanics.md):
#   - config:    ~/.vibe/config.toml always loads; <root>/.vibe/config.toml
#                only under a trusted root (PART-CONFIG §2.4-2.5)
#   - skills:    search order is skill_paths, then <root>/.vibe/skills/,
#                <root>/.agents/skills/, ~/.vibe/skills/, ~/.agents/skills/;
#                first match wins on name collision; builtin names vibe and
#                skill-creator are reserved (PART-SKILLS §1.2)
#   - SKILL.md:  frontmatter keys are exactly name, description, license,
#                compatibility, metadata, allowed-tools, user-invocable;
#                unknown keys are silently ignored (PART-SKILLS §1.1)
#   - agents:    TOML at <root>/.vibe/agents/ or ~/.vibe/agents/, file stem
#                is the name; keys display_name, description, safety
#                (safe|neutral|destructive|yolo), agent_type
#                (agent|subagent), system_prompt_id; the instructions field
#                is parsed but NOT consumed; every other key becomes a
#                config override (PART-AGENTS §8)
#   - hooks:     .vibe/hooks.toml (trusted) then ~/.vibe/hooks.toml; type is
#                one of pre_tool, post_tool, post_agent; match/strict are
#                forbidden on post_agent (PART-HOOKS §1-2)
#   - plugins:   .vibe/plugins/ and ~/.vibe/plugins/ — unified-harness only,
#                never resolved on the stable CLI backend (PART-PLUGINS §3)
#   - MCP:       [[mcp_servers]] in either config layer; there is no
#                standalone per-project MCP file outside plugin packages
#                (PART-CONFIG §1.4)
#
# Requires python3 >= 3.11 (tomllib). No third-party packages.

set -euo pipefail

VIBE_HOME="${VIBE_HOME:-$HOME/.vibe}"
MODE="human"

case "${1:-}" in
    --json) MODE="json" ;;
    --help|-h)
        grep '^#' "$0" | sed 's/^# \?//;s/^#//'
        exit 0
        ;;
    "") ;;
    *) echo "Unknown option: $1 (use --help)" >&2; exit 1 ;;
esac

python3 - "$VIBE_HOME" "$PWD" "$MODE" <<'PY'
import json
import os
import re
import sys
import tomllib
from pathlib import Path

VIBE_HOME = Path(sys.argv[1]).expanduser().resolve()
CWD = Path(sys.argv[2]).resolve()
MODE = sys.argv[3]

findings = []
def add(sev, area, msg):
    findings.append({"severity": sev, "area": area, "message": msg})

# ---------------------------------------------------------------- trust ----
def load_trust():
    f = VIBE_HOME / "trusted_folders.toml"
    trusted, untrusted = [], []
    if f.is_file():
        try:
            data = tomllib.loads(f.read_text())
            trusted = [str(p) for p in data.get("trusted", [])]
            untrusted = [str(p) for p in data.get("untrusted", [])]
        except tomllib.TOMLDecodeError as e:
            add("warn", "trust", f"trusted_folders.toml is not valid TOML: {e}")
    return trusted, untrusted

def trust_status(path, trusted, untrusted):
    """Walk-up tri-state: the closest recorded ancestor decides."""
    probe = Path(path).resolve()
    while True:
        s = str(probe)
        if s in untrusted:
            return "untrusted"
        if s in trusted:
            return "trusted"
        if probe == probe.parent:
            return None
        probe = probe.parent

# ---------------------------------------------------------------- config ---
def load_toml(path):
    try:
        with open(path, "rb") as f:
            return tomllib.load(f), None
    except FileNotFoundError:
        return None, None
    except tomllib.TOMLDecodeError as e:
        return None, f"invalid TOML: {e}"

def find_project_root():
    """Walk up from CWD looking for .vibe/config.toml, never into the home
    directory's own .vibe (the CLI stops at VIBE_HOME.parent)."""
    probe = CWD
    stop = VIBE_HOME.parent
    while True:
        if probe == stop or probe == probe.parent:
            return None
        if (probe / ".vibe" / "config.toml").is_file():
            return probe
        probe = probe.parent

trusted, untrusted = load_trust()
status = trust_status(CWD, trusted, untrusted)
root_trusted = status == "trusted"

user_cfg, err = load_toml(VIBE_HOME / "config.toml")
if err:
    add("fail", "config", f"~/.vibe/config.toml: {err}")
elif user_cfg is None:
    add("info", "config", "no user config.toml — built-in defaults apply")

proj_root = find_project_root()
proj_cfg, proj_cfg_err = None, None
if proj_root:
    if trust_status(proj_root, trusted, untrusted) == "trusted":
        proj_cfg, proj_cfg_err = load_toml(proj_root / ".vibe" / "config.toml")
        if proj_cfg_err:
            add("fail", "config", f"{proj_root}/.vibe/config.toml: {proj_cfg_err}")
    else:
        add("warn", "config",
            f"project config at {proj_root}/.vibe/config.toml is IGNORED: root not trusted")

for label, cfg in (("user", user_cfg), ("project", proj_cfg)):
    if not cfg:
        continue
    models = cfg.get("models", [])
    if not models:
        add("fail", "config", f"{label} config: no [[models]] — Vibe refuses to start without at least one")
    if "active_model" in cfg:
        alias = cfg["active_model"]
        aliases = [m.get("alias", m.get("name")) for m in models if isinstance(m, dict)]
        if models and alias not in aliases:
            add("warn", "config",
                f"{label} config: active_model '{alias}' is not the alias of any [[models]] entry ({', '.join(map(str, aliases))})")

# ---------------------------------------------------------------- skills ---
VALID_FM = {"name", "description", "license", "compatibility", "metadata",
            "allowed-tools", "user-invocable"}
BUILTIN_SKILLS = {"vibe", "skill-creator"}
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

def parse_frontmatter(text):
    """Split --- frontmatter; return (dict-of-key->list-of-values, error)."""
    if not text.startswith("---"):
        return None, "no frontmatter block"
    parts = re.split(r"^-{3,}\s*$", text, maxsplit=2, flags=re.M)
    if len(parts) < 3:
        return None, "unterminated frontmatter block"
    fm = {}
    key = None
    for line in parts[1].splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if m:
            key = m.group(1)
            fm.setdefault(key, [])
            if m.group(2).strip():
                fm[key].append(m.group(2).strip().strip("'\""))
        elif line.lstrip().startswith(("- ", "  ")) and key:
            fm[key].append(line.strip().lstrip("- ").strip().strip("'\""))
        else:
            return None, f"unparsable frontmatter line: {line!r}"
    return fm, None

def skill_dirs(cfg):
    """Ordered search dirs per the CLI order, labeled."""
    dirs = []
    if cfg:
        for p in cfg.get("skill_paths", []):
            dirs.append(("skill_paths", Path(str(p)).expanduser()))
    if root_trusted:
        dirs.append(("project", CWD / ".vibe" / "skills"))
        dirs.append(("project", CWD / ".agents" / "skills"))
        if proj_root and proj_root != CWD:
            dirs.append(("project", proj_root / ".vibe" / "skills"))
    dirs.append(("user", VIBE_HOME / "skills"))
    dirs.append(("user", Path.home() / ".agents" / "skills"))
    return dirs

def scan_skills(cfg):
    seen = {}
    seen_paths = set()
    for scope, d in skill_dirs(cfg):
        if not d.is_dir():
            continue
        for child in sorted(d.iterdir()):
            skill_md = child / "SKILL.md"
            if not child.is_dir() or not skill_md.is_file():
                continue
            # The CLI dedups by resolved path: a symlinked skill dir reached
            # through two search paths is ONE skill, not a collision.
            resolved = child.resolve()
            if str(resolved) in seen_paths:
                continue
            seen_paths.add(str(resolved))
            name = child.name
            text = skill_md.read_text(encoding="utf-8", errors="replace")
            fm, err = parse_frontmatter(text)
            if err:
                add("fail", "skills", f"{skill_md}: {err}")
                continue
            fname = (fm.get("name") or [""])[0]
            desc = (fm.get("description") or [""])[0]
            where = f"{scope} {skill_md}"
            if not fname:
                add("fail", "skills", f"{where}: frontmatter is missing required key 'name'")
                fname = name
            if not desc:
                add("fail", "skills", f"{where}: frontmatter is missing required key 'description' (the only routing text the model sees)")
            elif not (1 <= len(desc) <= 1024):
                add("warn", "skills", f"{where}: description is {len(desc)} chars (must be 1-1024)")
            if fname and not NAME_RE.match(fname):
                add("fail", "skills", f"{where}: name '{fname}' fails ^[a-z0-9]+(-[a-z0-9]+)*$")
            if fname != name:
                add("warn", "skills", f"{where}: frontmatter name '{fname}' != directory name '{name}' (loads under the frontmatter name; mismatch only logs)")
            unknown = [k for k in fm if k not in VALID_FM]
            if unknown:
                add("warn", "skills", f"{where}: unknown frontmatter keys {sorted(unknown)} are silently IGNORED — remove them (they are leftovers from another product's schema)")
            if fname in BUILTIN_SKILLS:
                add("fail", "skills", f"{where}: name '{fname}' is reserved (builtin skill); this skill is silently skipped")
            if fname in seen:
                add("warn", "skills",
                    f"name collision on '{fname}': {seen[fname]} loads (first match wins); {where} is shadowed")
            else:
                seen[fname] = where
    return seen

skill_names = {}
if user_cfg or proj_cfg:
    skill_names = scan_skills(proj_cfg or user_cfg)

# --------------------------------------------------------------- agents ----
VALID_SAFETY = {"safe", "neutral", "destructive", "yolo"}
VALID_AGENT_TYPE = {"agent", "subagent"}
BUILTIN_PROMPTS = {"cli", "explore", "tests", "lean", "minimal"}

def resolve_prompt(prompt_id, label, where):
    candidates = []
    if root_trusted:
        candidates.append(CWD / ".vibe" / "prompts" / f"{prompt_id}.md")
        if proj_root and proj_root != CWD:
            candidates.append(proj_root / ".vibe" / "prompts" / f"{prompt_id}.md")
    candidates.append(VIBE_HOME / "prompts" / f"{prompt_id}.md")
    if not any(c.is_file() for c in candidates) and prompt_id not in BUILTIN_PROMPTS:
        add("warn", "agents",
            f"{where}: system_prompt_id '{prompt_id}' resolves to no file ({', '.join(str(c) for c in candidates)}) and is not a builtin id ({', '.join(sorted(BUILTIN_PROMPTS))})")

def scan_agents():
    dirs = []
    if root_trusted:
        dirs.append(CWD / ".vibe" / "agents")
        if proj_root and proj_root != CWD:
            dirs.append(proj_root / ".vibe" / "agents")
    dirs.append(VIBE_HOME / "agents")
    for cfg in (user_cfg, proj_cfg):
        if cfg:
            for p in cfg.get("agent_paths", []):
                dirs.append(Path(str(p)).expanduser())
    for d in dirs:
        if not d.is_dir():
            continue
        for tf in sorted(d.glob("*.toml")):
            where = str(tf)
            data, err = load_toml(tf)
            if err:
                add("fail", "agents", f"{where}: {err}")
                continue
            stem = tf.stem
            if "name" in data:
                add("warn", "agents",
                    f"{where}: a 'name' key inside an agent TOML is not consumed (the name is the file stem '{stem}') — as a stray override key it can invalidate the whole profile at discovery")
            at = data.get("agent_type", "agent")
            if at not in VALID_AGENT_TYPE:
                add("fail", "agents", f"{where}: agent_type '{at}' is invalid (agent | subagent)")
            safety = data.get("safety", "neutral")
            if safety not in VALID_SAFETY:
                add("fail", "agents", f"{where}: safety '{safety}' is invalid (safe | neutral | destructive | yolo)")
            if "system_prompt_id" in data:
                resolve_prompt(str(data["system_prompt_id"]), "agent", where)
            elif "instructions" in data:
                add("info", "agents",
                    f"{where}: has 'instructions' but no system_prompt_id — the instructions field is parsed and carried on the profile but NOT consumed by the agent loop; role prompts belong in prompts/<id>.md selected via system_prompt_id")

def scan_agents_if_any():
    scan_agents()

scan_agents_if_any()

# ---------------------------------------------------------------- hooks ----
VALID_HOOK_TYPES = {"pre_tool", "post_tool", "post_agent"}

def scan_hooks():
    files = []
    if root_trusted:
        for r in {CWD, proj_root} - {None}:
            files.append(("project", r / ".vibe" / "hooks.toml"))
    files.append(("user", VIBE_HOME / "hooks.toml"))
    seen_names = {}
    for scope, hf in files:
        if not hf.is_file():
            continue
        data, err = load_toml(hf)
        if err:
            add("fail", "hooks", f"{hf}: {err}")
            continue
        for h in data.get("hooks", []):
            name = h.get("name", "<unnamed>")
            where = f"{scope} {hf} hook '{name}'"
            if not h.get("name"):
                add("fail", "hooks", f"{hf}: [[hooks]] entry without a name")
            if "type" not in h:
                add("fail", "hooks", f"{where}: missing type (pre_tool | post_tool | post_agent)")
            else:
                t = h["type"]
                if t not in VALID_HOOK_TYPES:
                    add("fail", "hooks", f"{where}: type '{t}' is not one of the three hook events {sorted(VALID_HOOK_TYPES)} — the hook is skipped")
                elif t == "post_agent":
                    if "match" in h:
                        add("fail", "hooks", f"{where}: match is forbidden on post_agent (validation error, hook skipped)")
                    if "strict" in h:
                        add("fail", "hooks", f"{where}: strict is forbidden on post_agent (validation error, hook skipped)")
            if not str(h.get("command", "")).strip():
                add("fail", "hooks", f"{where}: missing or blank command")
            if scope == "project" and name in seen_names:
                add("info", "hooks", f"hook name '{name}' also defined in {seen_names[name]}; the project entry wins, the other is dropped")
            seen_names.setdefault(name, f"{scope} {hf}")

scan_hooks()

# -------------------------------------------------------------- plugins ----
def scan_plugins():
    for label, d in (("project", CWD / ".vibe" / "plugins"),
                     ("user", VIBE_HOME / "plugins")):
        if not d.is_dir():
            continue
        children = [c for c in sorted(d.iterdir()) if c.is_dir()]
        if not children:
            add("info", "plugins", f"{label} plugins dir {d} exists but is empty")
            continue
        add("info", "plugins",
            f"{label} plugins dir {d}: {len(children)} package(s) — plugins resolve ONLY on the unified harness (--experimental-harness); the stable CLI backend ignores them entirely")
        for c in children:
            mf = c / "plugin.json"
            if not mf.is_file():
                add("warn", "plugins", f"{c}: no plugin.json manifest — not a loadable package")
                continue
            try:
                m = json.loads(mf.read_text())
            except json.JSONDecodeError as e:
                add("fail", "plugins", f"{mf}: invalid JSON: {e}")
                continue
            if m.get("$schema") != "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json":
                add("fail", "plugins", f"{mf}: $schema must be exactly 'https://agent-plugins.org/schemas/1.0.0/plugin.schema.json'")
            if not re.match(r"^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$", str(m.get("name", ""))):
                add("fail", "plugins", f"{mf}: name '{m.get('name')}' fails the plugin name pattern")

scan_plugins()

# ------------------------------------------------------------- mcp drift ---
def mcp_names(cfg):
    if not cfg:
        return []
    return [str(s.get("name")) for s in cfg.get("mcp_servers", []) if isinstance(s, dict)]

def find_agents_md_files():
    """AGENTS.md files between CWD and the filesystem root."""
    out, probe = [], CWD
    while True:
        f = probe / "AGENTS.md"
        if f.is_file():
            out.append(f)
        if probe == probe.parent:
            break
        probe = probe.parent
    return out

configured = sorted(set(mcp_names(user_cfg) + mcp_names(proj_cfg)))
agents_mds = find_agents_md_files()
mention_text = "\n".join(f.read_text(encoding="utf-8", errors="replace") for f in agents_mds)

for name in configured:
    if name not in mention_text:
        add("info", "mcp",
            f"server '{name}' is configured but not mentioned in any AGENTS.md on the path — tell the model it exists, or remove it")
# Heuristic reverse drift: "<name> MCP server" style mentions with no config.
for m in re.finditer(r"`?([a-z0-9][a-z0-9_-]{1,40})`?\s+MCP server", mention_text, re.I):
    mentioned = m.group(1).lower()
    if mentioned not in {"the", "a", "an", "this"} and mentioned not in [c.lower() for c in configured]:
        add("warn", "mcp",
            f"AGENTS.md mentions an MCP server '{mentioned}' that is not configured in either config layer (there is no standalone per-project MCP file outside plugin packages)")

if not configured:
    add("info", "mcp", "no [[mcp_servers]] configured in either config layer")

# -------------------------------------------------------------- summary ----
counts = {}
for f in findings:
    counts[f["severity"]] = counts.get(f["severity"], 0) + 1

if MODE == "json":
    print(json.dumps({
        "vibe_home": str(VIBE_HOME),
        "cwd": str(CWD),
        "cwd_trusted": root_trusted,
        "project_root": str(proj_root) if proj_root else None,
        "configured_mcp_servers": configured,
        "skills_found": sorted(skill_names),
        "findings": findings,
        "summary": counts,
    }, indent=2))
    sys.exit(0)

def sev_tag(s):
    return {"fail": "[FAIL]", "warn": "[WARN]", "info": "[info]"}[s]

print("=== Vibe setup audit ===")
print(f"vibe home:    {VIBE_HOME}")
print(f"cwd:          {CWD} ({'trusted' if root_trusted else 'NOT trusted — project layer ignored'})")
if proj_root:
    print(f"project root: {proj_root}")
print(f"skills loaded (first-match-wins order): {len(skill_names)}")
print(f"mcp servers configured: {', '.join(configured) if configured else 'none'}")
print()
if not findings:
    print("No findings.")
for f in findings:
    print(f"{sev_tag(f['severity'])} {f['area']}: {f['message']}")
print()
print(f"summary: {counts.get('fail', 0)} fail, {counts.get('warn', 0)} warn, {counts.get('info', 0)} info")
PY
