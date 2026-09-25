# Vibe Scripts — Health Check, Setup Audit, Session Tools

Four small, dependency-light tools for operating a Vibe install. They are read-only examples: copy them anywhere on PATH, run them, read the output.

| Script | What it does |
|---|---|
| [check-vibe.sh](check-vibe.sh) | Health check: binary, version, upgrade surface, API key, config files, trust store, skills/agents dirs, session store. |
| [audit-vibe.sh](audit-vibe.sh) | Setup audit: scans config, skills, agents, hooks, plugins and MCP configuration for drift and schema violations. |
| [vibe-sessions.py](vibe-sessions.py) | List, search, inspect and resume sessions from the session store. Python 3 stdlib only. |
| [session-search.sh](session-search.sh) | Zero-dependency bash alternative for listing and searching sessions. |

Run them against the machine you are on; all four tolerate a partial or missing setup and report what they find instead of crashing.

## check-vibe.sh

`bash check-vibe.sh [project-dir]`

Checks, in order: the `vibe` binary on PATH (override with `VIBE=/path/to/vibe`), `vibe --version`, that `vibe --help` advertises `--check-upgrade`, the `MISTRAL_API_KEY` environment variable, `~/.vibe/config.toml` and the trusted project `.vibe/config.toml`, `hooks.toml` in both layers, the trust store `~/.vibe/trusted_folders.toml` (with a walk-up tri-state lookup mirroring the CLI's closest-ancestor rule), the four skills directories, the agents directories, and the session store `~/.vibe/logs/session`.

There is no `vibe doctor` command — the script says so, and the two closest equivalents are `vibe --check-upgrade` (updates) and this health check. Health failures print `[FAIL]`; the script exits non-zero when any check failed.

The vendor privacy/retention block from the source material was dropped on purpose: the analog is the `/data-retention` side-channel command inside an interactive session, which prints data-retention information from the running product. Side-channel commands run even while the agent is busy.

## audit-vibe.sh

`bash audit-vibe.sh` or `bash audit-vibe.sh --json`

Audits both config layers and every extension surface, re-derived from Vibe's actual layout:

- **Config** — `~/.vibe/config.toml` (always loads) and the project `.vibe/config.toml` discovered upward from the cwd (loads only when its root is trusted; an untrusted project file is reported as ignored). Flags a config with no `[[models]]` entries (the CLI refuses to start without one) and an `active_model` that matches no `[[models]]` alias.
- **Skills** — the four skills directories (`<root>/.vibe/skills/`, `<root>/.agents/skills/`, `~/.vibe/skills/`, `~/.agents/skills/`) plus `skill_paths`, in the CLI's first-match-wins order. Per `SKILL.md`: required `name` and `description`, the name pattern `^[a-z0-9]+(-[a-z0-9]+)*$`, name-vs-directory mismatch (loads under the frontmatter name), unknown frontmatter keys (silently ignored by Vibe — leftovers from another product's schema; remove them), reserved builtin names, and name collisions (the first match shadows the rest).
- **Agents** — `.vibe/agents/` and `~/.vibe/agents/` plus `agent_paths`. Per `NAME.toml`: a `name` key inside the file (the name is the file stem; the stray key is not consumed and can invalidate the profile as an override), `agent_type` in `agent|subagent`, `safety` in `safe|neutral|destructive|yolo`, `system_prompt_id` resolving to `.vibe/prompts/<id>.md`, `~/.vibe/prompts/<id>.md` or a builtin id, and `instructions` without `system_prompt_id` (the `instructions` field is parsed but not consumed by the agent loop — role prompts belong in `prompts/<id>.md`).
- **Hooks** — `.vibe/hooks.toml` (trusted roots only) then `~/.vibe/hooks.toml`. Per `[[hooks]]`: required non-blank `name`/`type`/`command`, `type` in the three valid events (`pre_tool`, `post_tool`, `post_agent`), `match`/`strict` forbidden on `post_agent` (a validation error that skips the hook), duplicate names across files (the project entry wins).
- **Plugins** — `.vibe/plugins/` and `~/.vibe/plugins/`. Notes that plugins resolve only on the unified harness (`--experimental-harness`); the stable CLI backend ignores them. Checks each package for a `plugin.json` manifest with the exact `$schema` literal and a valid name.
- **MCP drift** — `[[mcp_servers]]` names from both config layers versus mentions in `AGENTS.md` files on the path. Configured-but-unmentioned and mentioned-but-unconfigured are both reported. There is no standalone per-project MCP file outside plugin packages — MCP servers live in `config.toml` or inside a plugin's `mcp.json`.

Findings are labeled `[FAIL]` (schema violation, will break at load), `[WARN]` (works, but wrong or fragile), or `[info]` (worth knowing). Model-tier checks from the source rubric were dropped — any provider/model combination is valid config here; the rubric gained the skill-frontmatter checks (inert keys, name-matches-directory, description presence) instead.

## vibe-sessions.py

`python3 vibe-sessions.py <command> [flags]`

Reads the real session layout: one directory per session under `~/.vibe/logs/session/`, named `session_<YYYYMMDD_HHMMSS>_<shortid>/`, holding `meta.json` and `messages.jsonl`; the `.session_index.json` listing cache (used as a cache and reconciled against `meta.json` mtime, like the CLI) and the `.last_session/<tty>` per-terminal pointers.

- `recent [N]` — newest sessions first, with title, short id, cwd.
- `search WORD...` — multi-word AND search over message text.
- `info ID` — partial match on the short id or session id; prints metadata including the pinned `active_model` from the session's config snapshot.
- `resume ID` — prints `vibe --resume <full-id>` (add `--exec` to run it). `--resume` resolves ids globally, with no folder scoping.
- `pointers` — the per-TTY last-session pointers that drive `vibe -c`.
- Flags: `--json`, `--cwd DIR` (sessions reaching that directory), `--since 7d` or ISO date, `--limit N`. `VIBE_SESSION_DIR` overrides the session store location.

The source tool's per-project directory tree does not exist in Vibe — sessions are folder-scoped only through `meta.json`'s `origin_directory`/`environment.working_directory`, which is what `--cwd` filters on.

## session-search.sh

`bash session-search.sh [-n N] [words...]`, `bash session-search.sh --resume <partial-id>`

The same job as `vibe-sessions.py search`/`recent` in plain grep/sed — no jq, no Python. Lists recent session dirs (the dir-name timestamp keeps `ls` order roughly chronological), AND-searches `messages.jsonl` across all sessions, and prints a ready-to-run `vibe --resume` command for a partial id. `VIBE_HOME` and `VIBE_SESSION_DIR` override the paths.

## What was dropped from the source tooling, and why

- **Vendor privacy/retention block** (health check) — replaced by a pointer to the `/data-retention` side-channel command; the retention story belongs to the running product, not a shell script.
- **Doctor invocation** (health check) — there is no doctor command in Vibe. The health check was rebuilt from the actual surface: `--version`, `--help`, `--check-upgrade`, config/trust/session layout.
- **Doctor-style MCP listing** (health check) — `vibe mcp` is an interactive slash command, not a shell subcommand in 2.25.x; the audit script reads `[[mcp_servers]]` from config instead.
- **Per-project sessions tree** (session tools) — Vibe has no projects directory for sessions; the store is `~/.vibe/logs/session/` with folder scoping via `meta.json`.
- **LLM-driven pattern discovery** (session tools) — the source's "discover" command shells out to an LLM CLI to mine sessions for skill candidates; that is a different tool's job, and the source's index formats do not apply here.
- **Session-stats cost analysis** — built on the source product's activity-log token estimates. The port's `log-tool-calls.sh` hook (in [../hooks/](../hooks/)) writes a compatible JSONL audit log; a stats tool can be built on it when real data accumulates.
- **Model-tier quality checks** (audit) — any `[[models]]`/`[[providers]]` combination is valid config; the audit checks structural validity instead (at least one model, alias resolution).
- **Sync/reinstall scripts** — they manage the source product's installation layout, which has no Vibe equivalent.
