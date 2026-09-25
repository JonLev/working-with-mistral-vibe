---
title: "Vibe Cheatsheet"
description: "One-page daily reference for the Vibe CLI: slash commands, input conventions, agent modes, memory and config, context management, MCP, hooks, CLI flags, headless mode, and quick fixes"
tags: [cheatsheet, reference]
---

# Vibe Cheatsheet

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

One dense page of daily essentials for the Vibe CLI. Every command, flag, key,
and path below is rebuilt from the
[mechanics oracle](../docs/mechanics/verified-mechanics.md) and cites the PART
it came from; no mechanic is transliterated from any other product's guide.
Vibe's verified surface is smaller than a decade-old tool's — this page says so
where a category (pricing tiers, community tooling, keyboard-shortcut tables)
has no verified Vibe equivalent, instead of padding.

## TL;DR

- ~30 built-in slash commands, three hook events, five built-in agent profiles
  plus one opt-in (`lean`), one `task` tool with subagent depth capped at 1
  (PART-COMMANDS section 2; PART-HOOKS section 1; PART-PERMISSIONS section 4.1;
  PART-AGENTS section 9).
- The default agent is `accept-edits`: file edits run without prompts, everything
  else asks. `--yolo`/`--auto-approve` approves everything; `ask` asks for
  everything not allowlisted; `plan` is read-only (PART-PERMISSIONS section 4.1).
- Memory is `AGENTS.md` (project wins over user, closer directory wins);
  settings are `config.toml` in an eight-layer precedence stack
  (PART-AGENTSMD; PART-CONFIG section 2.1).
- Context auto-compacts at `auto_compact_threshold` tokens (default 200,000,
  `0` disables, per-model override wins), with a one-time warning at 50% of the
  threshold (PART-SESSIONS section 4.1).
- Headless: `vibe -p` with `--max-turns`/`--max-price`/`--max-tokens` and
  `--output text|json|streaming`; approval-requiring tool calls are auto-denied
  unless you pass `--auto-approve` (PART-CLI).

*Read if you use Vibe daily and want the verified surface on one page. Skip if
you want theory — the [core pages](core/architecture.md) cover that; this page
is lookup, not pedagogy.*

---

## Essential Slash Commands

The daily drivers. This is the complete built-in command list at 2.25.0
(PART-COMMANDS section 2); release 2.25.8 adds `/branch`, `/todo`
([unified-harness]), and restores `/plugins`/`/reload-plugins`
([unified-harness]) (PART-DELTAS; PART-COMMANDS section 2).

| Command | Action |
|---------|--------|
| `/help` | Contextual help (PART-COMMANDS section 2) |
| `/config` | Edit config settings (PART-COMMANDS section 2) |
| `/model` | Select active model; pins to the session and persists to config (PART-SESSIONS section 3.5) |
| `/thinking` | Select thinking level (PART-COMMANDS section 2) |
| `/status` | Agent statistics (PART-COMMANDS section 2) |
| `/compact [instructions]` | Summarize the conversation to free context; optional guidance appended to the summary request (PART-COMMANDS section 2; PART-SESSIONS section 4.2) |
| `/clear` (`/new`) | Start a new conversation; optional seed prompt; resets the model pin (PART-COMMANDS section 2; PART-SESSIONS section 3.5) |
| `/resume` (`/continue`) | Browse, resume, or delete saved sessions; `D` twice deletes a listed local session (PART-COMMANDS section 2; PART-SESSIONS section 3.3) |
| `/rewind` | Rewind to a previous message (also `Esc Esc` with empty input) (PART-COMMANDS section 2) |
| `/retry [instructions]` | Continue an interrupted model response, optionally with extra guidance (PART-COMMANDS section 2) |
| `/rename [title]` | Rename the session; a manual title is never overwritten by auto-generation (PART-SESSIONS section 3.4) |
| `/loop <interval> <prompt>` | Schedule a recurring prompt; `list` and `cancel <id\|all>` manage it (PART-SESSIONS section 5) |
| `/mcp` (`/connectors`) | Browse MCP servers and connectors; `<name>` lists tools; `add <url>`, `status`, `login <alias>`, `logout <alias>` (PART-MCP section 1.6) |
| `/skills` | Browse and import registry skills; gated by `experimental_enable_registry_skills` (PART-SKILLS section 1.6) |
| `/reload` | Reload configuration, agent instructions, and skills from disk (PART-COMMANDS section 2) |
| `/copy` | Copy the last agent message to the clipboard (PART-COMMANDS section 2) |
| `/paste-image` | Paste an image from the OS clipboard into the prompt; macOS only (PART-COMMANDS section 2) |
| `/voice` | Configure voice settings (PART-COMMANDS section 2) |
| `/theme` | Select theme (PART-COMMANDS section 2) |
| `/proxy-setup` | Configure proxy and SSL certificate settings (PART-COMMANDS section 2) |
| `/log` | Show the path to the current interaction log file (PART-COMMANDS section 2) |
| `/log-level [LEVEL]` | Change the log level for this session or persist it to config.toml (PART-COMMANDS section 2) |
| `/debug` | Toggle the debug console (PART-COMMANDS section 2) |
| `/teleport` | Teleport the session to Vibe Code Web (PART-COMMANDS section 2) |
| `/remote-project` | Select the Vibe Code Web project for this repository (PART-COMMANDS section 2) |
| `/data-retention` | Show data retention information (PART-COMMANDS section 2) |
| `/whoami` | Display the signed-in user, workspace, and plan (PART-COMMANDS section 2) |
| `/leanstall` / `/unleanstall` | Install / uninstall the opt-in Lean 4 proving agent (PART-COMMANDS section 2) |
| `/exit` | Exit (`exit`, `quit`, `:q`, `:quit` also work) (PART-COMMANDS section 2) |

Side-channel note: `/help`, `/status`, `/log`, `/copy`, and the other
`side_channel` commands run while the agent is busy; `/clear`, `/compact`,
`/rewind`, `/resume`, `/reload`, `/retry` are rejected while busy and must be
retried when idle (PART-COMMANDS section 2).

---

## Input Conventions

| Input | Behavior |
|-------|----------|
| `@path/to/file.py` | File mention: injected as a fresh `read_file` result after your message — re-mentioning re-reads. Caps: 2,000 lines and 50 KB per file, 8 file mentions per prompt (PART-SESSIONS section 6.1) |
| `@path/to/folder/` | Not auto-read; the path stays in the message for the agent to read or grep on demand (PART-SESSIONS section 6.1) |
| `@image.png` | Native multimodal attachment (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`); 10 MiB per image, 8 images per message; requires `supports_images = true` on the active model (PART-SESSIONS section 6.1) |
| `!shell-command` | Runs directly in your shell, bypassing the agent; idle session required, cannot queue (PART-SESSIONS section 6.2) |
| `&prompt` | Prefix form of `/teleport`: sends the prompt to a Vibe Code Web sandbox and returns a link (PART-SESSIONS section 6.3) |
| `/skill-name args` | Invokes a user-invocable skill; `user-invocable: false` skills stay model-only (PART-SKILLS section 1.3) |

---

## Lesser-Known Features (Verified, Worth Keeping)

The habit behind this table: read the public `CHANGELOG.md` in the
mistral-vibe repo. Every row below was a changelog-visible delta at some point;
PART-DELTAS tracks what 2.25.8 added over the 2.25.0 live baseline
(`worktree_limit = 15`, `show_subagent_status_list`, the `smart-approve` agent,
`/branch`).

| Feature | What it does |
|---------|--------------|
| `/loop <interval> <prompt>` | Recurring prompt, min 30 s, max 50 per session, fired only when the session is idle, persisted in `meta.json` and restored on resume (PART-SESSIONS section 5) |
| `--worktree [NAME]` | Isolated git worktree under `~/.vibe/worktrees/`; named form branches `NAME`, unnamed form branches `vibe/<name>`; implicitly trusted; auto-removed on exit if clean (PART-WORKTREES) |
| `--resume <partial-id>` | Global resume by (partial) session ID — not folder-scoped like `-c` and the picker, so it carries sessions across worktrees (PART-SESSIONS sections 3.2–3.3) |
| `-p` auto-DENY | In programmatic mode, approval-requiring tool calls are cancelled, not auto-approved — `--agent`/`default_agent` both apply (PART-CLI, live-verified) |
| `VIBE_*` env overrides | Any config key: `VIBE_ACTIVE_MODEL=local`; nested with `__`: `VIBE_TOOLS__BASH__PERMISSION=always` (PART-CONFIG section 2.2) |
| `pre_tool` argument rewrite | A hook can return `hook_specific_output.tool_input` and fully replace the model's tool arguments (PART-HOOKS section 3.3) |
| `post_agent` deny-retry | A denied `post_agent` hook injects its reason as a user message so the agent retries — max 3 per turn (PART-HOOKS section 3.7) |
| MCP OAuth by default | `vibe mcp add` without static-auth flags persists OAuth and opens a browser login; `--no-login` skips; tokens live in the OS keyring (PART-MCP sections 1.1, 1.4–1.5) |
| Session model pinning | The first user message pins `active_model` into the session; resume keeps the pin even if the default changed (PART-SESSIONS section 3.5) |
| Manual session titles | `/rename` writes a `manual` title that auto-generation never overwrites (PART-SESSIONS section 3.4) |
| `smart-approve` agent | Classifies each tool call and auto-runs the safe ones; released in 2.25.8, [unified-harness] only (PART-AGENTS section 7; PART-DELTAS) |

---

## Agent Modes

Built-in profiles (PART-PERMISSIONS section 4.1). `Shift+Tab` cycles
`ask → plan → accept-edits → auto-approve`, then custom agents sorted by name
(PART-AGENTS section 10).

| Agent | File edits (`write_file`, `edit`) | Other tool calls | Notes |
|-------|-----------------------------------|------------------|-------|
| `ask` | Asks | Asks (anything not allowlisted) | Neutral safety (PART-PERMISSIONS section 4.1) |
| `plan` | Blocked (`permission = "never"`), except plan files under `~/.vibe/plans/` | Read tools allowed | Read-only exploration and planning (PART-PERMISSIONS section 4.1) |
| `accept-edits` (default) | Auto-approved | Normal gate: allowlist → permission → prompt | `default_agent` defaults to this (PART-PERMISSIONS section 4.1; PART-CONFIG section 1.5) |
| `auto-approve` | Auto | Auto (`bypass_tool_permissions = true`) | Selected by `--auto-approve`/`--yolo` without `--agent` (PART-PERMISSIONS section 4.1) |
| `explore` | — | `grep`, `read_file`, `skill` only | Subagent, spawned via the `task` tool, not selectable with `--agent` (PART-AGENTS sections 7, 9) |
| `lean` | — | — | Opt-in Lean 4 proving agent; install via `/leanstall` (PART-AGENTS section 7) |

`--agent X --auto-approve` keeps profile X and additionally approves all tool
calls (PART-PERMISSIONS section 4.1). The approval prompt itself offers
approve once / for session / permanently (persists into `[tools.<name>]` in
config) / decline (PART-PERMISSIONS section 4.2).

---

## Memory and Config Levels

Two instruction systems, both TOML/Markdown files, both layered
(PART-AGENTSMD; PART-CONFIG).

| Level | File | Loaded when | Scope |
|-------|------|-------------|-------|
| User memory | `~/.vibe/AGENTS.md` | Always | You, all projects (PART-AGENTSMD) |
| Project memory | `AGENTS.md` from each project root up to its trust root | Trusted folders only | Team, checked into the repo (PART-AGENTSMD) |
| Subdirectory memory | `AGENTS.md` in subdirectories | Lazily, when a file below is read | Scoped to that subtree (PART-AGENTSMD) |

Priority, in the injected prompt's own words: project instructions take
priority over user instructions; closer directories override more distant ones
(PART-AGENTSMD).

| Config level | File | Loaded when |
|-------------|------|-------------|
| User | `~/.vibe/config.toml` | Always (PART-CONFIG section 2.1) |
| Project | `.vibe/config.toml` (discovered walking up from the working directory) | Only when its parent directory is trusted (PART-CONFIG section 2.5) |

The full precedence stack, lowest to highest: schema defaults < GrowthBook
experiments < user TOML < project TOML < `VIBE_*` env vars < session overrides
(`--enabled-tools` etc.) < active agent profile < admin config
(PART-CONFIG section 2.1). Full key reference:
[settings reference](core/settings-reference.md).

---

## The `.vibe/` Project Folder

Only entries the oracle verifies (PART-CONFIG sections 2.4–2.5; PART-AGENTS
section 8; PART-SKILLS section 1.2; PART-AGENTSMD):

```text
<project>/.vibe/
├── config.toml    # project config; loaded only when the folder is trusted (PART-CONFIG 2.5)
├── hooks.toml     # project hooks; trusted only; wins over the user file on name clashes (PART-HOOKS 1)
├── agents/        # custom agent TOML profiles, e.g. redteam.toml (PART-AGENTS 8)
├── skills/        # project skills (PART-SKILLS 1.2)
├── prompts/       # custom system prompts, resolved before ~/.vibe/prompts/ (PART-AGENTSMD; PART-AGENTS 8)
├── tools/         # custom tools (PART-CONFIG 2.5)
└── plugins/       # plugin imports; [unified-harness] surface (PART-CONFIG 2.5; PART-PLUGINS)

<project>/.agents/skills/   # additional project skills dir (PART-SKILLS 1.2)
```

The global tree under `~/.vibe/` (all derived from `VIBE_HOME`, default
`~/.vibe`): `config.toml`, `AGENTS.md`, `hooks.toml`, `.env`,
`trusted_folders.toml`, `projects.toml`, `cache.toml`, `agents/`, `prompts/`,
`skills/`, `tools/`, `plugins/`, `skills-registry-cache/`, `plans/`,
`worktrees/`, `logs/` (including `logs/session/`), and `vibehistory`
(PART-CONFIG section 2.4).

---

## Typical Workflow

Adapted to Vibe's verified loop mechanics:

```text
1. Start session      → vibe (trust prompt on first run in a folder; PART-TRUST 3.2)
2. Pick the agent      → Shift+Tab, or vibe --agent plan for complex work (PART-AGENTS 10)
3. Describe the task   → WHAT/WHERE/HOW/VERIFY; use @file mentions (PART-SESSIONS 6.1)
4. Watch the gate      → accept-edits auto-approves edits; everything else prompts (PART-PERMISSIONS 4.1)
5. Review changes      → read every diff before approving anything else
6. Verify             → run the tests (ask the agent, or !pytest yourself; PART-SESSIONS 6.2)
7. Commit             → when the task is done and green
8. Mind the warning   → the 50%-of-threshold context warning means /compact soon (PART-SESSIONS 4.1)
9. Close or resume     → /exit; vibe -c next time, or vibe --resume <id> across worktrees (PART-SESSIONS 3.2–3.3)
```

---

## Context Management

Vibe's verified model is token-count-based, not percentage-based
(PART-SESSIONS section 4.1). The source-guide habit of "compact at 70%,
clear at 90%" is not a Vibe mechanic — do not carry it over.

| Mechanic | Value | Citation |
|----------|-------|----------|
| `auto_compact_threshold` | Default 200,000 tokens; per-model override wins; `0` disables auto-compaction | PART-CONFIG section 1.1; PART-SESSIONS section 4.1 |
| Warning | One `<vibe_warning>` per session when context reaches 50% of the threshold | PART-SESSIONS section 4.1 |
| `/compact [instructions]` | Summarizes the conversation; your instructions are appended to the summary request; a fallback summarizer runs if the first attempt fails | PART-SESSIONS section 4.2 |
| `/clear [prompt]` | New conversation; resets the model pin | PART-COMMANDS section 2; PART-SESSIONS section 3.5 |
| `/status` | Agent statistics | PART-COMMANDS section 2 |
| `/rewind` | Step back to a previous message instead of nuking the session | PART-COMMANDS section 2 |

| Sign | Action |
|------|--------|
| 50%-of-threshold warning fired | Finish the current task, then `/compact` |
| Responses getting thin, details drifting | `/compact [focus the summary on X]` |
| Task boundary reached | `/clear` and re-state only what the next task needs |
| Model answering about the wrong file | `@`-mention the exact file so it is re-read fresh (PART-SESSIONS section 6.1) |

Session recovery (PART-SESSIONS sections 3.2–3.3):

| Command | Usage |
|---------|-------|
| `vibe -c` | Continue the most recent session in this directory (per-terminal pointer, folder-scoped) |
| `vibe --resume` | Interactive picker, folder-scoped |
| `vibe --resume <id>` | Global resume by full or partial ID — works across worktrees |
| `/resume` in-session | Browse, resume, or delete saved sessions |

Session logging must be enabled (`[session_logging] enabled = true`, the
default) or `-c`/`--resume` refuse to run (PART-SESSIONS section 3.3).

---

## Under the Hood (Quick Facts)

| Concept | Key point |
|---------|-----------|
| Loop | One tool-call loop per session; hooks fire per tool call (`pre_tool`/`post_tool`) and per turn (`post_agent`) around it (PART-HOOKS section 1) |
| Tools | 26 built-in tool names across eight families per the installed 2.25.7 schema dump — full catalog in the [tools reference](core/tools-reference.md) |
| Context | 200,000-token default auto-compaction threshold, per-model override (PART-SESSIONS section 4.1) |
| Subagents | All spawns route through the `task` tool; depth capped at 1 (no recursive spawning); text-only results back to the parent (PART-AGENTS section 9) |
| Permission gate | Bypass flag → per-tool resolver → config permission → session permission store → prompt (PART-PERMISSIONS section 4.2) |
| Skills | `SKILL.md` + YAML frontmatter; discovery: builtins → `skill_paths` → project `.vibe/skills/` → `.agents/skills/` → user `~/.vibe/skills/` → `~/.agents/skills/` → registry (PART-SKILLS sections 1.1–1.2) |
| Trust | Untrusted folders keep a writable cwd but contribute no project config, hooks, skills, agents, or repo `AGENTS.md` (PART-TRUST section 3.5) |

Deep dives: [architecture](core/architecture.md),
[agents and skills](core/agents-and-skills-reference.md).

---

## Harness Choice in Four Layers

Product-agnostic — pick the smallest control structure that safely solves the
need.

| Layer | Owns | Start here |
|-------|------|-------------|
| Model | Reasoning and tool-call proposals | [Glossary](core/glossary.md) |
| Runtime harness | Tool loop, permissions, and recovery | [Agent harness](core/agent-harness.md) |
| Repository harness | Instructions, task state, and verification | [Context engineering](core/context-engineering.md) |
| Orchestrator | Coordination between runtimes or sessions | [Loop and graph engineering](core/loop-graph-engineering.md) |

Choose a bounded loop for one repeated task; an explicit graph for routing,
joins, parallelism, interruption, or durable recovery; a repository harness
(`AGENTS.md`, skills, hooks) for repeatable project behavior; an orchestrator
only when coordination between several runs is the constraint. Specify success,
failure, timeout, budget, and escalation before execution. In Vibe terms:
`/loop` covers the bounded loop (PART-SESSIONS section 5), `--max-turns` /
`--max-price` / `--max-tokens` bound a headless run (PART-CLI), and
`--worktree` isolates it (PART-WORKTREES).

---

## Quick Prompting Formula

```text
WHAT: [Concrete deliverable]
WHERE: [File paths]
HOW: [Constraints, approach]
VERIFY: [Success criteria]
```

Example:

```text
Add input validation to the login form.
WHERE: src/components/LoginForm.tsx
HOW: Use the existing schema module, show inline errors
VERIFY: Empty email shows the error banner, invalid format shows the error banner
```

`@`-mention the WHERE files so their content is in context before the agent
starts (PART-SESSIONS section 6.1).

---

## MCP Servers

The verified surface: the `vibe mcp` subcommand, `[[mcp_servers]]` in
config.toml, three transports, static or OAuth auth, and the in-session
`/mcp` browser (PART-MCP). No third-party server catalog — any
spec-compliant server works.

`vibe mcp add` flags (PART-MCP section 1.1):

| Flag | Meaning |
|------|---------|
| `--transport {http,streamable-http,stdio}` | Default `streamable-http` |
| `--url URL` | Remote server URL (http transports) |
| `--command`, `--arg`, `--env` | stdio process setup (`--command` required for stdio) |
| `--header NAME=VALUE` | Static HTTP header; stored in plaintext — use `--api-key-env` for secrets |
| `--api-key-env` / `--api-key-header` / `--api-key-format` | Static auth: env var, header (default `Authorization`), format (default `Bearer {token}`) |
| `--no-login` | Persist an OAuth server without starting browser login |

Any static-auth flag selects static auth; otherwise the server persists as
OAuth and browser login starts immediately (PART-MCP section 1.1). `vibe mcp
remove` also deletes stored OAuth tokens (PART-MCP section 1.1).

```toml
# ~/.vibe/config.toml (PART-MCP section 1.2)
[[mcp_servers]]
name = "fetch_server"
transport = "stdio"          # or "http" or "streamable-http" (PART-MCP 1.3)
command = "uvx"
args = ["mcp-server-fetch"]
env = { "DEBUG" = "1" }

[[mcp_servers]]
name = "linear"
transport = "streamable-http"
url = "https://mcp.example.com/mcp"

[mcp_servers.auth]           # http transports only
type = "static"              # or "oauth" (PART-MCP 1.4)
api_key_env = "MY_TOKEN_VAR"
```

Tools publish as `{server-alias}_{tool-name}` and are permission-configured
like built-ins in `[tools.<published name>]` (PART-MCP sections 1.7–1.8).
Per-server knobs: `prompt`, `startup_timeout_sec` (10.0), `tool_timeout_sec`
(60.0), `sampling_enabled`, `disabled`, `disabled_tools`
(PART-MCP section 1.2). In session: `/mcp` lists servers and connectors,
`/mcp <name>` lists tools, `/mcp status` shows auth status
(PART-MCP section 1.6).

---

## Creating Custom Components

### Custom agent — `~/.vibe/agents/redteam.toml` (or `.vibe/agents/`)

Every key beyond the header fields is a config override — any `config.toml`
field is valid here (PART-AGENTS section 8):

```toml
agent_type = "agent"          # or "subagent": delegation-only via the task tool (PART-AGENTS 8-9)
display_name = "Red team"
description = "Read-only audit agent for security review."
safety = "safe"               # safe | neutral | destructive | yolo (visual hint)
system_prompt_id = "redteam"  # a .md file in .vibe/prompts/ or ~/.vibe/prompts/
disabled_tools = ["write_file", "edit"]

[tools.bash]
permission = "ask"
```

### Skill — `<skill-dir>/SKILL.md`

```markdown
---
name: code-review
description: Perform automated code reviews
user-invocable: true
allowed-tools:
  - read_file
  - grep
---
# Code review skill

This skill helps analyze code quality and suggest improvements.
```

Required: `name` (lowercase alnum + hyphens, 1–64 chars) and `description`
(1–1024 chars); `user-invocable: false` makes the skill model-only
(PART-SKILLS section 1.1). Project skills live in `.vibe/skills/`, user
skills in `~/.vibe/skills/`; `/reload` picks up changes (PART-SKILLS
sections 1.2, 1.5). Design patterns: [skill design
patterns](core/skill-design-patterns.md).

### Hook — `<project>/.vibe/hooks.toml`

Exactly three event types: `pre_tool`, `post_tool`, `post_agent`
(PART-HOOKS section 1):

```toml
[[hooks]]
name = "deny-rm-rf"
type = "pre_tool"          # pre_tool | post_tool | post_agent
match = "bash"             # fnmatch glob or "re:" regex; tool hooks only
command = "python ./.vibe/hooks/guard-bash.py"
timeout = 60.0             # default 60 s
strict = true              # fail-closed instead of fail-open (tool hooks only)
description = "Reject destructive shell commands."
```

The hook reads a JSON payload from stdin and prints a JSON decision to stdout
(PART-HOOKS section 3):

```python
import json, sys
payload = json.load(sys.stdin)
command = payload.get("tool_input", {}).get("command", "")
if "rm -rf" in command:
    print(json.dumps({"decision": "deny",
                      "reason": "rm -rf is blocked by the deny-rm-rf hook."}))
    sys.exit(0)  # empty stdout + exit 0 = passthrough
```

Full wire protocol and the six [unified-harness] hook points:
[hooks events reference](core/hooks-events-reference.md).

### Custom system prompt — `~/.vibe/prompts/<id>.md`

Replaces the default system prompt entirely when `system_prompt_id = "<id>"`;
`compaction_prompt_id` swaps only the compaction prompt (PART-AGENTSMD;
PART-CONFIG section 1.10).

---

## Anti-Patterns

| Don't | Do |
|-------|----|
| Vague prompts ("fix the auth") | Name the files with `@` mentions and use WHAT/WHERE/HOW/VERIFY (PART-SESSIONS section 6.1) |
| Approve edits without reading them | `accept-edits` auto-approves file edits by default — read the diff before the next prompt (PART-PERMISSIONS section 4.1) |
| Run `--yolo` in production | Keep the prompt gate; scope auto-approval with `allowlist` in `[tools.*]` instead (PART-CONFIG section 1.3) |
| Wait for context to fill before planning | Act on the 50%-of-threshold warning: finish the task, `/compact` (PART-SESSIONS section 4.1) |
| Negative constraints only ("don't touch X") | Provide the alternative: "don't touch X; add the equivalent in Y" |
| One giant session for everything | `/clear` at task boundaries; the old session stays resumable (PART-COMMANDS section 2) |

---

## CLI Flags Quick Reference

Every flag from the `vibe --help` transcript (PART-CLI):

| Flag | Usage |
|------|-------|
| `PROMPT` (positional) | Initial prompt to start the interactive session with |
| `-p`, `--prompt [TEXT]` | Programmatic mode: send prompt, output response, exit; approval follows the selected agent |
| `--max-turns N` | Max assistant turns (`-p` only) |
| `--max-price DOLLARS` | Max cost in dollars; interrupts the session (`-p` only) |
| `--max-tokens N` | Max total prompt + completion tokens (`-p` only) |
| `--enabled-tools TOOL` | Enable specific tools; in `-p` this disables all others; exact names, globs (`bash*`), or `re:` regex; repeatable |
| `--disabled-tools TOOL` | Disable tools after the enabled filter; same pattern syntax; repeatable |
| `--output {text,json,streaming}` | Programmatic output: text (default), JSON at end, or newline-delimited JSON per message |
| `--agent NAME` | Pick the agent: `ask`, `plan`, `accept-edits`, `auto-approve`, or a custom profile from `~/.vibe/agents/` |
| `--auto-approve`, `--yolo` | Approve all tool calls for the selected agent |
| `--setup` | Set up the API key and exit |
| `--check-upgrade` | Check for an update, prompt to install, exit |
| `--workdir DIR` | Change to this directory before running |
| `--worktree [NAME]` | Run in a git worktree under `~/.vibe/worktrees/`; implicitly trusted (PART-WORKTREES) |
| `--add-dir DIR` | Extra working directory, implicitly trusted for the session; repeatable |
| `--trust` | Trust the working directory for this invocation only; skips the trust prompt; for non-interactive automation |
| `-c`, `--continue` | Continue the most recent session in this directory |
| `--resume [SESSION_ID]` | Resume; without an ID, interactive picker |
| `-v`, `--version` / `-h`, `--help` | Version / help |

Subcommands: `vibe update` (same as `--check-upgrade`), `vibe mcp add|remove`
(PART-CLI; PART-MCP section 1.1). Environment: `VIBE_HOME` (default `~/.vibe`),
`LOG_LEVEL` (also `/log-level` in session), `LOG_MAX_BYTES`, and any `VIBE_*`
config override (PART-CLI; PART-CONFIG section 2.2).

---

## Debug Commands

```bash
vibe --version        # Version
vibe --check-upgrade  # Check for an update, prompt to install
vibe update           # Same check from the subcommand
vibe --setup          # (Re-)configure the API key
LOG_LEVEL=DEBUG vibe   # Verbose logging to $VIBE_HOME/logs/vibe.log
```

In session: `/log` (log file path), `/log-level` (session level), `/debug`
(debug console), `/status` (statistics), `/mcp status` (server auth status)
(PART-COMMANDS section 2; PART-MCP section 1.6; PART-CLI).

---

## CI/CD Mode (Headless)

```bash
# Non-interactive analysis; untrusted folders only warn but pass --trust for automation
vibe --trust -p "analyze this file for security issues" --output json

# Bounded run: turn and price caps (both -p only)
vibe --trust -p "fix the failing tests" --max-turns 10 --max-price 1.00 --output json

# Auto-accept everything (know the blast radius first)
vibe --trust -p "fix typos" --auto-approve

# Tool-restricted run: --enabled-tools is exclusive in -p mode
vibe --trust -p "run the linter" --enabled-tools "bash*" --output json
```

Live-verified on 2.25.0 (PART-CLI): with `--agent ask` (or a `default_agent`
of `ask`), an approval-requiring tool call is **cancelled** — auto-DENIED, not
auto-approved. `--agent` and `default_agent` both apply in `-p` mode; pass
`--auto-approve`/`--yolo` when a run must approve everything. Read-only bash
commands still run under `ask` because the bash safety classification approves
them before the agent gate. Programmatic mode also disables
`ask_user_question` and `exit_plan_mode`, and every callback request is
denied — the run cannot stop and ask (PART-TRUST section 3.4).

---

## The Golden Rules

1. **Read every diff.** The default agent auto-approves file edits
   (PART-PERMISSIONS section 4.1) — the safety net is you.
2. **Act on the context warning.** Compact at the 50%-of-threshold warning or
   a task boundary, not after quality degrades (PART-SESSIONS section 4.1).
3. **Be specific.** WHAT/WHERE/HOW/VERIFY, with `@` mentions for the WHERE.
4. **Plan before risky work.** `vibe --agent plan` or `Shift+Tab` to `plan`
   for read-only exploration (PART-PERMISSIONS section 4.1).
5. **Write an `AGENTS.md` for every project.** Project instructions override
   user instructions; subdirectory files scope narrowly (PART-AGENTSMD).
6. **Commit after each completed task.** Small diffs review faster than large
   ones.
7. **Know what is sent.** Telemetry is on by default (`enable_telemetry`);
   `/data-retention` states the retention policy; OTel export is opt-in via
   `enable_otel` (PART-CONFIG section 1.8; PART-COMMANDS section 2). See
   [data privacy](security/data-privacy.md).

---

## Quick Decision Tree

```text
Simple task       → Just ask; accept-edits defaults handle edits
Complex task      → plan agent first, then accept-edits to execute (PART-PERMISSIONS 4.1)
Risky change      → --agent plan; or /rewind if it went wrong (PART-AGENTS 10)
Repeating prompt  → skill in .vibe/skills/ (PART-SKILLS 1.2)
Recurring chore   → /loop <interval> <prompt> (PART-SESSIONS 5)
Isolated feature  → vibe --worktree (PART-WORKTREES)
Context warning   → /compact now; /clear at the task boundary (PART-SESSIONS 4.1)
Scheduled in CI   → vibe -p with --max-turns/--max-price (PART-CLI)
```

---

## Common Issues Quick Fix

| Problem | Solution |
|---------|----------|
| `vibe: command not found` | Reinstall via the official installer, which runs `uv tool install mistral-vibe` (oracle method and provenance section; PART-CLI) |
| API key missing / wrong | `vibe --setup`, or set the provider's `api_key_env_var` (default `MISTRAL_API_KEY`) (PART-CLI; PART-CONFIG section 1.1) |
| Context warning fired | `/compact` — the threshold is `auto_compact_threshold` (PART-SESSIONS section 4.1) |
| "not trusted" warning; project config ignored | Interactive: accept the trust prompt. Automation: `--trust` (session-only) or persist in `trusted_folders.toml` (PART-TRUST sections 3.2–3.4) |
| No `doctor` command | It does not exist in the verified CLI. Use `vibe --check-upgrade`, `vibe update`, `vibe --setup`, `/log`, `LOG_LEVEL=DEBUG` (PART-CLI) |
| MCP server not working | `/mcp` (list), `/mcp <name>` (its tools), `/mcp status` (auth); OAuth re-login via `/mcp login <alias>` (PART-MCP section 1.6) |
| A tool always asks | Add a prefix to `[tools.bash] allowlist` or a path glob to `[tools.read_file] allowlist` — note the keys are `allowlist`/`denylist`, not the docs' `allow`/`deny` (PART-CONFIG section 1.3; oracle docs-drift ledger, item 1) |
| Hook never fires | Hooks fail open by default; check the 60 s timeout, your matcher glob, and `LOG_LEVEL=DEBUG`; `strict = true` makes failures deny instead of warn (PART-HOOKS sections 2–3) |
| Session cannot resume | `[session_logging] enabled` must be true; `--resume <id>` is global, `-c` is folder-scoped (PART-SESSIONS section 3.3) |

Health check (all verified commands, PART-CLI; PART-MCP section 1.6):

```bash
which vibe && vibe --version && vibe --check-upgrade
# then, inside a session: /status and /mcp status
```

---

## Cost Notes

Only what the oracle verifies — no vendor pricing tables here.

- Model prices live in `[[models]]`: `input_price` and `output_price` are
  floats per million tokens and feed the `--max-price` cap (PART-CONFIG
  section 1.1).
- `--max-price DOLLARS` interrupts a programmatic session when the cost
  exceeds the limit (PART-CLI).
- `/whoami` shows the signed-in user, workspace, and plan (PART-COMMANDS
  section 2); `/status` shows agent statistics (PART-COMMANDS section 2).
- Auto-updates and update checks are config-gated (`enable_auto_update`,
  `enable_update_checks`) if bandwidth matters (PART-CONFIG section 1.10).

---

## See Also

- [Settings reference](core/settings-reference.md) — every config.toml key
- [Agents and skills reference](core/agents-and-skills-reference.md)
- [Hooks events reference](core/hooks-events-reference.md)
- [Tools reference](core/tools-reference.md)
- [Task management workflow](workflows/task-management.md)
- [Automation in ops](ops/automation.md)
- [Guide index](README.md)

---

## Known Gaps

- **Keyboard shortcuts are mostly undocumented by the oracle.**
  Source-verified: `Shift+Tab` cycles agents (PART-AGENTS section 10), `Esc Esc`
  rewinds (PART-COMMANDS section 2), and the docs list `Ctrl+\` (debug console)
  and `Ctrl+P`/`Alt+Up` rewind navigation — but the docs' shortcut table is a
  secondary source under H1 and was not verified against the CLI source. No
  full shortcut table is written here for that reason.
- **No verified statusline or live token/cost display.** `/status` exists but
  its exact rendering is not documented in the oracle; there is no verified
  equivalent of a customizable statusline.
- **`smart-approve` internals** (released 2.25.8, [unified-harness]) are not
  publicly documented beyond the agent definition (PART-DELTAS; oracle "needs
  public verification").
- **`theme` accepted values** are not enumerated in the oracle.
- **`/skills` registry browser** flows were source-verified only, not
  exercised live (PART-SKILLS section 1.6).
- **Exit codes** beyond argparse errors (`rc=2` on bad `vibe mcp add` usage,
  `rc=1` on OAuth login failure — PART-MCP section 1.1) are not enumerated.
