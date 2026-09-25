---
title: "The Vibe CLI"
description: "The Vibe CLI as the baseline surface of this guide: install and updates, the interactive TUI vs programmatic -p mode with auto-DENY semantics, agents and subagents, worktrees, sessions and resume, and when to pick the CLI over Vibe Code desktop, Vibe Code Web, or the VS Code extension."
tags: [guide, surfaces, cli]
---

# The Vibe CLI

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Every command, flag, config key, and file path here cites the mechanics oracle,
> [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as
> `(PART-XXX)` or `(PART-XXX section N)`. Mechanics live-verified on the
> installed CLI are marked as such; the rest are source-verified at release
> 2.25.8, with the live baseline being 2.25.0.

Surface mechanics only — loop internals are in
[Architecture](../core/architecture.md) and automation depth is in
[Automation](../ops/automation.md).

> **TL;DR.** The Vibe CLI is the terminal coding agent and the baseline surface
> the rest of this guide documents: open source at
> github.com/mistralai/mistral-vibe (Apache-2.0), installed from PyPI as
> `mistral-vibe` via `https://mistral.ai/vibe/install.sh` (Method and
> provenance). It has exactly two run modes — the interactive TUI and
> programmatic `-p` — and in `-p` mode approval-required tool calls are
> **auto-DENIED, not auto-approved** (PART-CLI, live verification). Agents are
> approval postures (`ask`, `plan`, `accept-edits`, `auto-approve`), cycled with
> Shift+Tab (PART-AGENTS sections 7 and 10); subagents are read-only
> delegation via the `task` tool (PART-AGENTS section 9). Worktrees, sessions
> and resume, and `/loop` round out the surface. Deep internals live in
> [Architecture](../core/architecture.md); automation depth lives in
> [Automation](../ops/automation.md).

**Read if** you are installing or driving the CLI itself, or you need the
run-mode, agent-posture, worktree, or session mechanics that the rest of the
guide assumes. **Skip if** you have already settled the CLI basics and want a
specific surface — [Vibe Code desktop](./desktop.md),
[Vibe Code Web](./web.md) — or the internals in
[Architecture](../core/architecture.md).

## 1. What the CLI is

The Vibe CLI (`vibe`) is the terminal coding agent and the baseline surface of
this guide: every other chapter documents behavior that is either this surface
or built on top of it. The project is open source at
<https://github.com/mistralai/mistral-vibe> under Apache-2.0, and the
installable artifact is the PyPI package `mistral-vibe` (Method and provenance
section). This page covers the surface mechanics; the single agent loop that
powers every run — interactive or headless — is covered in
[Architecture](../core/architecture.md).

## 2. Install, first run, and updates [stable]

| Step | Command / behavior | Citation |
|---|---|---|
| Official install | `https://mistral.ai/vibe/install.sh` runs `uv tool install mistral-vibe` (both verified 2026-09-24) | Method and provenance section |
| Homebrew fallback | `brew install mistral-vibe` | Method and provenance section ("Homebrew `mistral-vibe`" provenance row) |
| API key setup | `vibe --setup` — sets up the API key and exits | PART-CLI |
| First-run trust prompt | Interactive startup offers the workspace-trust prompt when the cwd is not the home directory, not already trusted, not explicitly untrusted, and has trustable files (`AGENTS.md` at/above cwd, or a `.vibe/` config dir) | PART-TRUST section 3.2 |
| Update check | `vibe update` or `--check-upgrade` — check for an update now, prompt to install it, and exit | PART-CLI |

The trust prompt's decisions persist into `$VIBE_HOME/trusted_folders.toml`
(`trust_repo`, `trust_cwd`, `decline`) or stay session-only
(`trust_session`, in-memory and never persisted); declining runs the session
with project config ignored (PART-TRUST sections 3.1-3.2). A full walkthrough
of the trust model, including the untrusted-folder behavior and the
dangerous-directory guard, is in [Settings Reference](../core/settings-reference.md).

## 3. The two run modes [stable]

| Mode | Invocation | What happens | Citation |
|---|---|---|---|
| Interactive TUI | `vibe [PROMPT]` | Full terminal UI; optional initial prompt; trust prompt and approval callbacks surface to the TUI | PART-CLI; PART-TRUST section 3.4 |
| Programmatic | `vibe -p [TEXT]` | Send prompt, output response, exit; headless session; machine-readable output | PART-CLI; PART-TRUST section 3.4 |

### Programmatic flags

| Flag | Binds | Citation |
|---|---|---|
| `--max-turns N` | Max assistant turns; `-p`-only | PART-CLI |
| `--max-price DOLLARS` | Max cost in dollars; session interrupted on exceed; `-p`-only | PART-CLI |
| `--max-tokens N` | Max total prompt + completion tokens across the session; `-p`-only | PART-CLI |
| `--enabled-tools TOOL` | Exact names, globs (`bash*`), or `re:` regex; repeatable; in `-p` mode disables all non-matching tools. `--disabled-tools` subtracts after it | PART-CLI |
| `--output text\|json\|streaming` | `text` (default), `json` (all messages at end), `streaming` (newline-delimited JSON per message) | PART-CLI |

### Auto-DENY, not auto-approve (live-verified)

The docs.mistral.ai agents page claims `-p` mode "falls back to auto-approve"
when `--agent` is omitted. That is wrong, and the oracle settles it with live
runs (vibe 2.25.0, 2026-09-24):

- **Approval-required tool calls in `-p` mode are auto-DENIED** — the effect
  reports status `cancelled` — not auto-approved (PART-CLI, live verification,
  test 1).
- **`--agent` and `default_agent` both apply in `-p` mode**: a gated command
  under `--agent ask` was cancelled, and the same under
  `VIBE_DEFAULT_AGENT=ask` was cancelled too (PART-CLI, live verification,
  tests 1-2).
- **Read-only bash still runs**: an `echo hello` under `--agent ask` executed —
  bash safety classification approves safe commands before the agent approval
  gate is consulted (PART-CLI, live verification, test 3).

Pass `--auto-approve`/`--yolo` to allow all tool calls headlessly (PART-CLI).
For the CI-oriented view — trust, allowlists, budget patterns — see
[Automation](../ops/automation.md), which documents this same surface in depth.

## 4. Agents and the loop, at user level [stable]

Agents are approval postures, selected at launch and switchable mid-session:

| Agent | Posture | Safety class | Citation |
|---|---|---|---|
| `ask` | Requires approval for tool executions | `neutral` | PART-AGENTS section 7 |
| `plan` | Read-only for exploration and planning; write tools `never` except `~/.vibe/plans/*` | `safe` | PART-AGENTS section 7 |
| `accept-edits` (default) | Auto-approves file edits only | `destructive` | PART-AGENTS section 7 |
| `auto-approve` | Auto-approves all tool executions | `yolo` | PART-AGENTS section 7 |

- Select with `vibe --agent NAME` (builtins, or a custom
  `~/.vibe/agents/NAME.toml`); `default_agent` in `config.toml` (default
  `accept-edits`) applies in both interactive and `-p` mode (PART-CLI;
  PART-AGENTS section 10).
- Interactive: Shift+Tab cycles `ask → plan → accept-edits → auto-approve`,
  then custom agents sorted by name; the switch applies to the running session
  (PART-AGENTS section 10).
- `--auto-approve`/`--yolo` combines with any agent and approves all tool calls
  (PART-AGENTS section 10).

Every run is a single agent loop — one turn cycle driving tools against the
workspace. That loop's internals are not this page's subject: see
[Architecture](../core/architecture.md). The agent catalog (including custom
agent TOML schema) is in
[Agents and Skills Reference](../core/agents-and-skills-reference.md).

### Subagents via the `task` tool

Delegation goes through the `task` tool, and only through it (PART-AGENTS
section 9):

- The built-in `explore` subagent is read-only — it enables only `grep`,
  `read_file`, and `skill`, with the `explore` system prompt (PART-AGENTS
  section 9).
- Depth is capped at 1: a subagent cannot spawn a subagent; only
  `agent_type = "subagent"` profiles are spawnable, and a primary-agent name
  errors out (PART-AGENTS section 9).
- Results are text-only: the parent receives `TaskResult(response, turns_used,
  completed)` and summarizes it to the user — no message objects, no files
  (PART-AGENTS section 9).

**[unified-harness]** Under the unified harness, subagents are first-class
child sessions: `subagents no longer prompt for tool permission when the
parent session is in auto-approve mode` (2.25.5 changelog delta), subagents
defined in `~/.vibe/agents` or `.vibe/agents` can be spawned again and
per-agent `system_prompt_id` is honored (2.25.8 changelog deltas)
(PART-AGENTS section 9).

## 5. Worktrees [stable]

`vibe --worktree [NAME]` runs inside an isolated git worktree (PART-WORKTREES):

| Aspect | Named form (`--worktree NAME`) | Unnamed form (`--worktree`) |
|---|---|---|
| Branch | Branch named `NAME` (created if missing, attached if it exists) | Always `vibe/<name>` |
| Worktree name | `NAME` | Slugified from the prompt (max 40 chars) or a random slug; claims a free name (`-2`, `-3`, ... on collision) |
| Reuse | Only when the worktree belongs to the same repo on branch `NAME`; otherwise errors out | Never reuses; always creates new |

- **Location**: `$VIBE_HOME/worktrees/<repo-name>-<repo-hash>/<name>`
  (PART-WORKTREES).
- **Trust**: the worktree is entered and implicitly trusted for the session —
  an in-memory grant, never persisted to `trusted_folders.toml` (PART-WORKTREES;
  PART-TRUST section 3.3).
- **Argument order**: `vibe --worktree "Fix the login bug"` treats the string
  as the NAME; put the prompt first or use `--` (PART-WORKTREES).
- **Cleanup**: on interactive exit, a worktree Vibe created this run is removed
  automatically iff no uncommitted changes, no untracked files, and no commits
  beyond the starting commit; otherwise Vibe asks keep-vs-remove. Programmatic
  runs (`-p ... --worktree NAME`) never clean up automatically
  (PART-WORKTREES).
- **Session scope**: `-c`/`--resume` picker are directory-scoped, so they only
  see sessions started inside that worktree; `--resume <ID>` (global) carries a
  session across worktrees (PART-WORKTREES).

## 6. Sessions and resume [stable]

| Mechanic | Behavior | Citation |
|---|---|---|
| `vibe -c` / `--continue` | Continues the most recent session that reaches the current cwd — per-terminal pointer first, else most recent in the folder; errors if none | PART-SESSIONS section 3.2 |
| Folder scoping | A session matches if `origin_directory` or `environment.working_directory` equals the launch directory; `-c` and the picker are folder-scoped | PART-SESSIONS sections 3.1-3.2 |
| `--resume <SESSION_ID>` | Resolves by ID globally — no working-directory filter; partial IDs supported, latest wins on multiple matches | PART-SESSIONS section 3.3 |
| Bare `--resume` | Interactive picker; in `-p` mode it is an error ("requires a session ID in programmatic mode") | PART-SESSIONS section 3.3 |
| Model pinning | The first user message pins the resolved `active_model` alias into the session's config snapshot; resuming keeps the pinned model even if the default changes; `/clear` starts an unpinned conversation | PART-SESSIONS section 3.5 |
| Titles | Auto-generated in the background (interactive CLI); `/rename <title>` writes a `manual` title that auto-generation never overwrites | PART-SESSIONS section 3.4 |

Sessions live under `$VIBE_HOME/logs/session/` as
`<prefix>_<YYYYMMDD_HHMMSS>_<short-id>/` directories containing `meta.json`
and `messages.jsonl`; session logging must be enabled or `-c`/`--resume` raise
an error (PART-SESSIONS sections 3.1-3.3).

## 7. `/loop` in brief [both]

`/loop <interval> <prompt>` schedules a recurring prompt inside one live
session: interval `<number><unit>` with `s|m|h|d` and a 30-second minimum, at
most 50 loops per session, idle-only firing, and persistence in the session's
`meta.json` so loops are restored on resume; `/loop list` and
`/loop cancel <id|all>` manage them (PART-SESSIONS section 5). The full
mechanics and the `/loop`-vs-cron decision are in
[Automation](../ops/automation.md).

## 8. The unified harness as the forward path [unified-harness]

This guide documents the **unified harness as the primary forward path** and
the **stable backend as today's default** (Backend tags
section). The flag to select the experimental backend,
`--experimental-harness`, is **argparse-suppressed from `--help` when the
`mistralai_vibe_local_harness` package is not installed** — so on most
installs the flag is invisible, not missing (Backend tags section;
`vibe/_experimental_harness.py`, v2.25.0).

What diverges under the unified harness, each with its deep-dive page:

| Divergence | Backend tag | Where |
|---|---|---|
| Plugins and `/plugins` (plus `/reload-plugins`, restored at 2.25.8) | [unified-harness] | PART-PLUGINS; see [Plugins](../core/plugins.md) |
| Connectors enabled in memory by default | [both] | PART-CONNECTORS |
| Six typed hook points (vs three CLI events) | [unified-harness] | PART-HOOKS-UNIFIED; see [Hooks and Events Reference](../core/hooks-events-reference.md) |
| `/teleport` unavailable under the experimental harness | [stable] | PART-WEB section 4.1 |
| `smart-approve` agent — classifies each tool call, auto-runs the safe ones, prompts only for risky ones; documented in release 2.25.8 source, not live-verified | [unified-harness] | PART-AGENTS section 7 main deltas; PART-DELTAS |

## 9. When to pick the CLI

| Surface | Runs where | Non-interactive mode | Best for | Citation |
|---|---|---|---|---|
| Vibe CLI | Your terminal, your machine | Yes — `vibe -p "..."` with `--output json` | Automation, CI, scripts, full local control | PART-CLI; PART-WEB section 4.4 |
| Vibe Code desktop | Native app; local, worktree, or cloud sessions from the Code home | Not verified as a surface mechanic | GUI-driven sessions, pinned projects, subagent side panel | [desktop-0.12.0] (PART-WEB section 4.6); see [Vibe Code desktop](./desktop.md) |
| Vibe Code Web | Remote single-tenant sandbox; no local install | No (web sessions; spawn from web, CLI `&`, or `/teleport`) | Isolated runs, GitHub-centric flows, no local machine access | PART-WEB sections 4.2-4.3 [docs-only]; see [Vibe Code Web](./web.md) |
| VS Code extension | Inside VS Code (agent built in; no CLI install required); ACP for other IDEs | No non-interactive mode | Editor-embedded sessions; shared config and sessions with the CLI | PART-WEB section 4.4 [docs-only] |

The docs' own comparison line: CLI = terminal plus non-interactive; VS Code =
editor context via ACP; Web = remote sandbox. Custom agents, skills, MCP
servers, and connectors work on all three (PART-WEB section 4.4). Teleport
moves the current session from CLI to Web one-way — you cannot pull a session
back to the local CLI (PART-WEB section 4.1).

## Known gaps

- **`/skills` registry not exercised live**: `experimental_enable_registry_skills`
  is false on the oracle's test machine and no LLM session was run; only
  source-level verification exists (Needs public verification, skills/commands
  pass). `/skills` appears in the command table only if
  `registry_skills_enabled` (PART-COMMANDS).
- **`smart-approve` exact behavior is public-changelog-only**: the classifier's
  tool-mode wiring lives in the private harness package; only the public
  changelog and the agent definition were inspectable (PART-AGENTS section 7
  main deltas; Needs public verification, hooks/agents pass). Do not rely on
  its behavior beyond the one-line description.
- **Theme values not enumerated**: the accepted values of `theme` live in
  uninspected constants; enumerate before relying on `/theme` values (Needs
  public verification, config/trust/permissions pass).
- **Whether `.vibe/config.toml` loads from an `--add-dir` root**: the add-dir
  root joins `project_roots`, but `ProjectConfigLayer` roots its walk-up at
  the session cwd only; likely not loaded from add-dirs — verify with a live
  run before relying on it (PART-TRUST section 3.3; Needs public verification,
  config/trust/permissions pass).
- **Unified-harness mechanics are source-verified, not live-exercised**:
  `mistralai_vibe_local_harness` is not installed in the Homebrew venv, so
  subagent-first-class behavior, plugins, and the typed hook points rest on
  public source and the desktop bundle (Backend tags section).
- **Web/desktop comparison rows are [docs-only] or release-notes-only**: no
  cloud-session or desktop UI verification was possible in the oracle's
  sprint (PART-WEB sections 4.3-4.4; Needs public verification,
  MCP/connectors/plugins/web pass).

## See also

- [Architecture](../core/architecture.md) — the single agent loop behind both
  run modes
- [Automation](../ops/automation.md) — the `-p` surface in CI depth: trust,
  allowlists, budgets, and `/loop` vs cron
- [Agents and Skills Reference](../core/agents-and-skills-reference.md) —
  builtin and custom agent catalog, subagent profiles
- [Settings Reference](../core/settings-reference.md) — `config.toml` keys,
  the trust model, and the dangerous-directory guard
- [Vibe Code desktop](./desktop.md) and [Vibe Code Web](./web.md) — the
  sibling surfaces in the section 9 decision table
- The mechanics oracle:
  [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md)
