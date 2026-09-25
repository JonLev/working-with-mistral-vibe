---
title: "How the Vibe CLI Works: Architecture and Internals"
description: "The Vibe CLI's verified internals: the agent loop and its seams, the tool surface, the tunable compaction trigger, depth-1 sub-agents, the permission and trust model, session persistence, extension surfaces, and the two session backends."
tags: [guide, architecture, cli, performance]
---

# How the Vibe CLI Works: Architecture and Internals

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Every command, flag, config key, file path, and payload field here cites the mechanics
oracle, [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as
`(PART-XXX)`. Claims marked *live-verified on 2.25.0* were executed against the installed
CLI; the rest are source-verified at release 2.25.8. Backend tags `[stable]` /
`[unified-harness]` / `[both]` mark mechanics that depend on the session backend;
`[docs-only]` marks claims that rest on product documentation the oracle could not
live-verify.

> **TL;DR.** The Vibe CLI is a runtime harness around one loop: send context to the
> model, execute the tool calls it returns, feed results back, repeat until it answers
> in text. Around the loop sit a config- and per-model-tunable compaction trigger (not a
> fixed window), a depth-1 sub-agent fork (`task`), a permission chain with **no OS
> sandbox** (trust + per-tool rules + worktrees), a JSONL session store you can resume,
> and extension surfaces: AGENTS.md, agents, skills, hooks, slash commands, MCP,
> connectors, plugins. The design bet is the one this guide keeps returning to: less
> scaffolding, more model.

**Read if** you want a mental model of what happens between your prompt and the model's
answer — the other theory pages assume this one. **Skip if** you want recipes; the
[workflows pages](../workflows/README.md) are the practical entry.

## Source transparency

This page is rebuilt from a single source of mechanics, not from vendor docs or
community inference. The oracle grades its own evidence, and this guide inherits that
grading:

| Tier | Description | Example on this page |
|------|-------------|----------------------|
| **Tier 1 — live-verified** | Executed against the installed CLI (vibe 2.25.0) during the oracle sprint | Approval-required calls are auto-DENIED in `-p` mode (PART-CLI) |
| **Tier 2 — source-verified** | Read from the repo at release tag `v2.25.8`; not live-executed | `/plugins` and `/reload-plugins` registered in 2.25.8 (PART-PLUGINS section 3.5) |
| **Tier 3 — docs-only** | Public product documentation, no live or source cross-check | Vibe Code Web sandbox and quota model (PART-WEB section 4.3) |

Where the tiers disagree or a mechanic has no public backing at all, the claim moves to
the [appendix](#appendix-what-we-do-not-know) or [Known gaps](#known-gaps) — never into
prose as fact. Prefer the repo over docs on any conflict (PART-CONFIG, source-of-truth
policy).

## Where the Vibe CLI sits

The Vibe CLI is a **runtime harness**: it owns the iterative model-and-tool loop for a
coding task. The model generates tokens; the repository supplies instructions, setup,
state, and verification; an orchestrator coordinates multiple runtime sessions. Those
layers answer different questions and should not be evaluated as interchangeable
products. The four-layer model is [Agent Harness Engineering](./agent-harness.md); this
page is the internals of one layer.

Engineering concepts change more slowly than product inventories, so the entry points
split accordingly:

| Entry point | Kind | Cadence |
|-------------|------|---------|
| [Agent Harness Engineering](./agent-harness.md) | Theory: layers, components, security model | Slow |
| [Loop & Graph Engineering](./loop-graph-engineering.md) | Theory: loops, graphs, stopping rules | Slow |
| [Context Engineering](./context-engineering.md), [Memory Systems](./memory-systems.md) | Theory: what enters the prompt, what persists | Slow |
| [Methodologies](./methodologies.md), [Glossary](./glossary.md) | Practice and vocabulary | Slow |
| This page | Verified inventory of one runtime | Re-verified per release (oracle release-sync contract) |

## TL;DR

1. **One loop.** `while (response has tool calls): execute; feed back`. No intent
   classifier, no router, no RAG pipeline decides anything — the model does
   ([Agent Harness Engineering](./agent-harness.md) section 2.1; the Vibe-specific
   seams the oracle verifies are in [section 1](#1-the-master-loop) below).
2. **A small verified tool surface.** Shell tools (`bash`, `git_bash`, `powershell`),
   file tools (`read_file`, `write_file`, `edit`), search (`grep`), delegation (`task`),
   `skill`, and the interactive `ask_user_question` / `exit_plan_mode` pair — each
   verified through the permission mechanics that gate it (PART-PERMISSIONS sections
   4.2-4.5; PART-AGENTS section 9; PART-SKILLS section 1.4). The complete per-tool
   catalog is [tools-reference.md](tools-reference.md), not this page.
3. **Compaction is a trigger, not a window.** `auto_compact_threshold` defaults to
   200,000 tokens, is per-model overridable, and fires before a turn when
   `context_tokens >= threshold`; `0` disables it (PART-SESSIONS section 4.1).
4. **Sub-agents are a depth-1 fork.** One `task` tool; subagents cannot spawn
   subagents (explicit `ToolError`); only text returns to the parent
   (PART-AGENTS section 9).
5. **The local boundary is trust, not a sandbox.** Trusted folders + per-tool
   permission chains + worktrees; no OS-level isolation ships (PART-TRUST;
   PART-PERMISSIONS section 4; PART-WORKTREES).

## 1. The master loop

The harness pattern is a `while` loop, and Vibe's design does not add a planner,
router, or retrieval pipeline in front of it:

```text
user prompt
     |
     v
+------------------------------+
|  model reasons over context  |   no classifier, no routing layer
+------------------------------+
     |
     v
 tool call? --yes--> execute tool --> feed result back --> loop
     |
     no
     |
     v
 text response (turn ends; post_agent hooks fire once per turn)
```

The oracle does not document Vibe's per-turn loop internals beyond the seams below, so
this section states only those seams — the rest is honestly unknown
([appendix](#appendix-what-we-do-not-know)).

Verified seams of the loop:

| Seam | What is verified | Citation |
|------|------------------|----------|
| Turn boundary | Before every turn, a middleware checks `context_tokens >= auto_compact_threshold` and can trigger compaction first; another warns once at 50% of the threshold | PART-SESSIONS section 4.1 |
| Tool call boundary | `pre_tool` hooks run before the permission prompt (first deny short-circuits); `post_tool` hooks run iff the tool body ran; `post_agent` runs once per turn after the response with no pending calls | PART-HOOKS section 1 |
| Prompt boundary | `@path` mentions inject file content per prompt — a synthetic `read_file` call in the stable backend, content blocks at turn start in the unified harness (max 2000 lines / 50 KB / 8 files per prompt) | PART-SESSIONS sections 6.1 |
| Turn cap | `--max-turns N`, `--max-price DOLLARS`, `--max-tokens N` apply in programmatic mode and interrupt the session when exceeded | PART-CLI |
| Conversation fork | `/branch` (release 2.25.8, source) forks the conversation into a new resumable session; `/rewind` (or `Esc Esc` on empty input) rewinds to a previous message | PART-COMMANDS section 2 |

Turn caps are the cheap insurance the source guide also recommends: an uncapped loop
can exhaust budget in ways that are hard to diagnose afterwards. In Vibe the caps are
CLI flags, not API parameters, and they only exist in `-p` mode (PART-CLI).

### Verified surface audit

The capabilities below are each verified by the oracle and covered in their own
sections here or in a sibling page:

| Capability | Mechanic | Section |
|------------|----------|---------|
| Delegation | `task` tool, depth-1 subagents (PART-AGENTS section 9) | [4](#4-sub-agent-architecture) |
| Scheduled prompts | `/loop <interval> <prompt>`, min 30 s, 50 loops/session, restored on resume (PART-SESSIONS section 5) | [7](#7-session-persistence) |
| Read-only exploration | Built-in `explore` subagent: `grep`, `read_file`, `skill` only (PART-AGENTS section 7) | [4](#4-sub-agent-architecture) |
| Planning | `plan` agent profile: write tools `never`, allowlist `~/.vibe/plans/*` (PART-PERMISSIONS section 4.1) | [5](#5-permissions-and-trust) |
| Extension | AGENTS.md, agent TOML, skills, hooks, slash commands, MCP, connectors, plugins | [8](#8-extension-surfaces) |
| Model switching | `/model` updates the session's pinned model immediately (PART-SESSIONS section 3.5) | [7](#7-session-persistence) |
| Isolation | `--worktree` checkouts under `$VIBE_HOME/worktrees/` (PART-WORKTREES) | [5](#5-permissions-and-trust) |
| Cloud handoff | `/teleport`, `&` prefix, `/remote-project` (PART-WEB section 4.1-4.2) | [10](#10-beyond-the-cli-desktop-and-web) |

## 2. The tool surface

The oracle verifies tools through the mechanics that use them — permissions, profiles,
and config — not through a complete catalog. What is verified:

| Tool | Verified role | Key behavior |
|------|---------------|--------------|
| `bash`, `git_bash`, `powershell` | Shell execution | Full guardrail chain: prefix allow/deny lists, `denylist_standalone`, sensitive first tokens, output cap 16000 bytes, default timeout 300 s (PART-PERMISSIONS section 4.4) |
| `read_file`, `write_file`, `edit` | File access | Per-call chain: scratchpad always writable, denylist checked before allowlist, sensitive patterns add a per-file prompt, outside-workspace paths add a permission (PART-PERMISSIONS section 4.3) |
| `grep` | Content search | Enabled in the `explore` subagent profile (PART-AGENTS section 7) |
| `task` | Sub-agent spawn | Effect kind `SUBAGENT`; permission `ask` with allowlist `["explore"]` (PART-AGENTS section 9) |
| `skill` | Skill loading | Permission `ALWAYS`; returns the skill body plus base directory and a sampled file listing (PART-SKILLS section 1.4) |
| `ask_user_question`, `exit_plan_mode` | User interaction | Disabled by the built-in agent profiles; force-disabled in `-p` mode (PART-PERMISSIONS section 4.1; PART-TRUST section 3.4) |

Three more surfaces add tools at runtime: `[[mcp_servers]]` entries publish
`{alias}_{tool}` tools under the same permission gate (PART-MCP sections 1.2, 1.7-1.8),
Mistral connectors publish `connector_{alias}_{tool}` proxies (PART-CONNECTORS sections
2.2-2.3), and `tool_paths` in `config.toml` loads custom tools from extra directories
or files (PART-CONFIG section 1.3).

Tool selection is model-driven — there is no routing table in the oracle — but the
*available set* is fully controlled: `enabled_tools` (exact names, globs like `bash*`,
or `re:` regex) narrows it, `disabled_tools` subtracts after that, and per-agent
overrides can flip any tool per profile (PART-CLI; PART-CONFIG section 1.3;
PART-AGENTS section 8). In `-p` mode, `--enabled-tools` disables everything not
matched (PART-CLI).

What the oracle does not contain: a verified complete inventory of builtin tools with
per-tool argument schemas and output caps. This page does not invent one; the complete
catalog lives in [tools-reference.md](tools-reference.md), built from the
installed-package schema dump (vibe 2.25.7, 2026-09-24).

## 3. Context management

### What enters one context

A session has a single context per turn. Verified constituents:

| Constituent | Mechanic | Citation |
|-------------|----------|----------|
| System prompt | Default prompt, or full replacement via `system_prompt_id` (bare filename resolved project `.vibe/prompts/` first, then `~/.vibe/prompts/`, then builtins) | PART-AGENTSMD; PART-SESSIONS section 4.3 |
| Instructions | `~/.vibe/AGENTS.md` always; project `AGENTS.md` from each root up to its trust root; subdirectory `AGENTS.md` lazily on `read_file`. Project beats user; closer directory beats distant | PART-AGENTSMD |
| Conversation history | Every message lands in the session's `messages.jsonl` | PART-SESSIONS section 3.1 |
| Tool results | Output of every executed tool call; bash output capped at `max_output_bytes = 16000` | PART-PERMISSIONS section 4.4 |
| Mentioned files | `@path` mentions, capped at 2000 lines / 50 KB per file / 8 files per prompt | PART-SESSIONS section 6.1 |

The exact token cost of each constituent per turn is not public; see the
[appendix](#appendix-what-we-do-not-know).

### Compaction: a tunable trigger, not a fixed window

The single number most pages get wrong is this one. `auto_compact_threshold` is a
**compaction trigger**, config- and per-model-tunable — not a model context window and
not a fixed constant of the product (PART-SESSIONS section 4.1):

| Property | Value | Citation |
|----------|-------|----------|
| Global default | `DEFAULT_AUTO_COMPACT_THRESHOLD = 200_000` tokens | PART-SESSIONS section 4.1 |
| Per-model override | `ModelConfig.auto_compact_threshold`; a validator copies the global value only into models that did not set their own | PART-SESSIONS section 4.1 |
| Observed in practice | Live `meta.json` showed user-added models at 800000 and 256000 — per-model values are common | PART-SESSIONS section 4.1 (live-verified on 2.25.0) |
| Trigger | Before every turn, if `threshold > 0 and context_tokens >= threshold` | PART-SESSIONS section 4.1 |
| Disable | `threshold = 0` | PART-SESSIONS section 4.1 |
| Early warning | `ContextWarningMiddleware` warns once per session at 50% of the threshold, injecting a `<vibe_warning>` | PART-SESSIONS section 4.1 |

Manual control: `/compact [instructions]` summarizes immediately, appending your
instructions to the configured `compaction_prompt`. On success the session stays the
same — a user-role envelope message marked `context_boundary="compaction"` is appended,
the `context_tokens` stat resets to 0, and the visible conversation is unchanged. On
`ContextTooLongError` the oldest round is dropped and retried up to 3 times; a failed
summary falls back to a dedicated no-tools call unless
`raise_on_compaction_failure = true`. Compaction also forces one background title
regeneration, because a compacted conversation reads differently from its first turn
(PART-SESSIONS sections 4.2, 4.4). A dedicated `compaction_model` can take the
summarization load (PART-SESSIONS section 4.3).

### Compaction drift and failure drift

Two degradation modes survive from the source guide's analysis because they are
harness-universal, and Vibe has verified countermeasures for both:

| Mode | Cause | Verified countermeasure |
|------|-------|------------------------|
| Compaction drift | Each summary loses nuance and breaks references to earlier detail | `/rewind` to recover a pre-compaction message; `/clear` to start an unpinned conversation; delegate exploration to `task` so noise never enters the main context (PART-COMMANDS section 2; PART-AGENTS section 9) |
| Failure drift | Repeated tool errors accumulate stack traces and retry noise; the loop follows the error narrative instead of the task | A `post_agent` hook that denies the turn injects a user message and retries (max 3 per turn) — a verified place to re-inject the original task statement (PART-HOOKS section 3.7) |

## 4. Sub-agent architecture

### Isolation model

```text
+------------------------------------------------------------+
| PARENT SESSION                                              |
|                                                             |
|   full conversation, permission store, session dir         |
|                     |                                       |
|        task(task="...", agent="explore")                    |
|                     v                                       |
|  +-----------------------------------------------------+   |
|  | CHILD (subagent)                                    |   |
|  |  fresh session id, is_subagent=true                 |   |
|  |  receives: the task text (+ scratchpad prefix)     |   |
|  |  inherits: parent permission store, hook config     |   |
|  |  cannot: spawn another subagent (depth limit 1)      |   |
|  |  returns: text only                                  |   |
|  +-----------------------------------------------------+   |
|                     v                                       |
|   TaskResult(response, turns_used, completed)               |
|   only this text enters the parent's context                 |
+------------------------------------------------------------+
```

Everything in that diagram is oracle-backed (PART-AGENTS section 9):

- One tool: `task`, with args `{ "task": <text>, "agent": <profile> }`; `agent`
  defaults to `"explore"`.
- **Depth limit 1.** If the active profile is itself a subagent, the tool raises
  `ToolError("Agent depth limit of 1 reached. Complete the task in the current
  subagent.")` — no recursion, ever.
- Only `agent_type = "subagent"` profiles are spawnable; requesting a primary agent
  raises a `ToolError` stating the security constraint explicitly. Subagents are also
  not selectable as the primary agent (`--agent` refuses them).
- The result is text-only: `TaskResult(response, turns_used, completed)` — no message
  objects, no files. The parent model summarizes it to you.
- The child is a real session: fresh ID, `parent_session_id` set, persisted under
  `<parent session dir>/agents/` with the agent name as prefix, and resumable.
  `share_permissions=True` — the child inherits the parent's permission store.
- The child runs without user interaction. The built-in `explore` enables only `grep`,
  `read_file`, and `skill`, with the terse `explore.md` system prompt; a custom
  subagent's tool set is whatever its overrides enable — read-only-ness comes from the
  profile, not the mechanism.
- Spawn permission: `[tools.task]` defaults to `permission = "ask"` with
  `allowlist = ["explore"]`, so the built-in is auto-approved and custom subagents
  require approval unless allowlisted (PART-AGENTS section 9).
- Hooks inherit: the child loads the same `hooks.toml` files, with
  `parent_session_id` in its hook payloads (PART-AGENTS section 9; PART-HOOKS
  section 3.2).

Custom subagents are plain agent TOML with `agent_type = "subagent"`, discovered from
`agent_paths` config entries, project `.vibe/agents/`, or `~/.vibe/agents/`; every
non-schema key in the file becomes a config override, so a subagent can pin
`active_model`, swap `system_prompt_id`, and set `[tools.*]` tables (PART-AGENTS
section 8).

### Depth 1 means hub-and-spoke, explicitly

With recursion impossible, every multi-agent arrangement in Vibe is a **hub-and-spoke**:
the parent is the only coordinator; children never see each other or the parent's
context. Two consequences for how you write `task` arguments:

| Rule | Why | Citation |
|------|-----|----------|
| Context is never inherited automatically | The child receives the task string only (plus the scratchpad prefix) | PART-AGENTS section 9 |
| Pass findings forward explicitly | Chain results through the parent: worker B's task must quote worker A's result | Consequence of text-only `TaskResult` |

*The wrong way:* delegate "find the session-token logic" and then, separately, "find
its callers" — the second child does not know what the first found. *The right way:*
wait for the first result, then send
*"Find all callers of `<exact-function-from-result>` across the codebase and return
file:line evidence."*

If workers would need to talk to each other, the decomposition is wrong — the shared
step belongs in the parent. On the unified harness, subagents are first-class child
sessions controlled by their parent, and no longer prompt for tool permission when the
parent is in auto-approve mode (2.25.5); subagents defined in `~/.vibe/agents` or
`.vibe/agents` are spawnable again as of 2.25.8 (PART-AGENTS section 9,
[unified-harness]).

## 5. Permissions and trust

### The tool gate

Every tool call passes one gate (PART-PERMISSIONS section 4.2):

```text
1. bypass_tool_permissions (config, --auto-approve, or the auto-approve profile)
   -> execute everything, no per-call checks
2. tool.resolve_permission(args)
   -> a PermissionContext, or None ("no opinion")
3. None -> fall back to config [tools.<name>].permission (default ASK)
4. ALWAYS -> execute; NEVER -> skip with feedback; ASK -> prompt
   (approve once / for session / permanently; permanently persists
   to [tools.<name>] in config)
```

File tools add a per-call chain — scratchpad paths always writable, denylist before
allowlist (fnmatch on the resolved path), sensitive patterns (default `**/.env*`-style
globs) adding a per-file prompt, outside-workspace paths adding an
`OUTSIDE_DIRECTORY` permission (PART-PERMISSIONS section 4.3). Bash adds its own
guardrails: tree-sitter command parsing, prefix-match denylists, a
`denylist_standalone` for bare interpreters (`python`, `bash`, ...), an always-ask rule
for `find -exec`, an outside-directory scan that runs **even for allowlisted
commands**, `sensitive_patterns = ["sudo"]`, `max_output_bytes = 16000`,
`default_timeout = 300` (PART-PERMISSIONS section 4.4).

### Agent profiles set the default posture

| Profile | Safety | Meaning | Citation |
|---------|--------|---------|----------|
| `ask` | neutral | Every non-allowlisted call prompts | PART-PERMISSIONS section 4.1 |
| `plan` | safe | Write tools `never` except `~/.vibe/plans/*`; read-only otherwise | PART-PERMISSIONS section 4.1 |
| `accept-edits` (default) | destructive | File edits auto-approved, everything else normal | PART-PERMISSIONS section 4.1 |
| `auto-approve` | yolo | `bypass_tool_permissions = true` | PART-PERMISSIONS section 4.1 |
| `smart-approve` (2.25.8) | smart | Classifies each call, auto-runs the safe ones — [unified-harness], exact behavior needs public verification | PART-AGENTS section 7; PART-DELTAS |

Select with `--agent NAME`, `default_agent` in `config.toml`, or Shift+Tab cycling
(`ask -> plan -> accept-edits -> auto-approve -> custom agents`) (PART-AGENTS sections
7, 10).

### Trust: the actual local boundary

Vibe has **no OS-level sandbox** — no container, no syscall filter, no network policy
ships with the CLI. The local boundary is three verified mechanisms:

| Layer | Mechanic | Citation |
|-------|----------|----------|
| Trust store | `$VIBE_HOME/trusted_folders.toml` with `trusted` / `untrusted` path arrays; tri-state closest-ancestor lookup; `--trust` grants session-only, in-memory trust | PART-TRUST sections 3.1, 3.3 |
| Untrusted behavior | Project `config.toml`, `hooks.toml`, `.vibe/{tools,skills,plugins,agents,prompts}`, and repo `AGENTS.md` are not loaded; the cwd stays writable; user-level `~/.vibe` content always loads | PART-TRUST section 3.5 |
| Workspace widening | `--add-dir` roots join `Workspace.authorized_roots` and act as project roots without entering the trust store; dangerous directories (home, Desktop, system paths) are refused as workdir | PART-TRUST sections 3.3, 3.5 |
| Isolation | `--worktree [NAME]` checks out under `$VIBE_HOME/worktrees/`, implicitly trusted for the session, auto-cleaned on exit only if untouched | PART-WORKTREES |

The trust prompt itself is offered only when the cwd is undecided and has "trustable
files" (an `AGENTS.md` at or above cwd, or a local `.vibe/` config dir); decisions are
trust-the-repo, trust-the-cwd, session-only, or decline (PART-TRUST section 3.2).

## 6. Programmatic mode

`vibe -p [TEXT]` runs headless: send prompt, output response, exit. The verified
contract (PART-CLI; PART-TRUST section 3.4):

| Aspect | Behavior |
|--------|----------|
| Approval semantics | **Approval-required calls are auto-DENIED** (live-verified on 2.25.0: effect status `cancelled`, not executed). The agent and `default_agent` config both apply; a read-only `echo hello` still ran under `--agent ask`, because bash safety classification approves safe commands before the approval gate |
| Interactive tools | `ask_user_question` and `exit_plan_mode` are force-disabled |
| Trust | Never prompts; run `--trust` for non-interactive automation, or accept the untrusted-workspace warning (project config ignored) |
| Budgets | `--max-turns N`, `--max-price DOLLARS`, `--max-tokens N` — session interrupted when exceeded |
| Tool narrowing | `--enabled-tools` (exact / glob / `re:`) disables all other tools; `--disabled-tools` subtracts after |
| Output | `--output text` (default), `json` (all messages at end), `streaming` (newline-delimited JSON per message) |
| Resume | `--resume` requires an explicit session ID in `-p` mode |
| Config | Any config key overrides as `VIBE_<KEY>`, nested as `VIBE_SECTION__KEY` (e.g. `VIBE_TOOLS__BASH__PERMISSION=always`); `~/.vibe/.env` fills unset keys, shell wins |

The auto-DENY result is the one to internalize for CI: a programmatic run is
conservative by default, not permissive. Anything you want executed headless must be
allowlisted in config, enabled by the selected agent profile, or explicitly approved
with `--auto-approve` / `--yolo`.

## 7. Session persistence

### Storage layout

Sessions are plain files under `$VIBE_HOME/logs/session/` (override:
`session_logging.save_dir`) (PART-SESSIONS section 3.1):

```text
~/.vibe/logs/session/
  .session_index.json                  # listing cache, reconciled by mtime
  .last_session/<tty>                  # per-terminal pointer used by -c
  session_<YYYYMMDD_HHMMSS>_<short-id>/
    meta.json                          # metadata (schema below)
    messages.jsonl                     # one JSON object per message
  active/  capabilities/               # live-install dirs
  unified/                             # full-UUID harness sessions ([unified-harness])
```

`meta.json` (live-verified on 2.25.0) records `session_id`, `parent_session_id`,
`start_time`/`end_time`, `git_commit`/`git_branch`,
`environment.working_directory` (follows a session move) and `origin_directory`
(stays where it began — a moved session is findable from both), `username`,
`child_sessions`, `loops` (scheduled `/loop` prompts, restored on resume), `title` and
`title_source`, `experiments`, a `config` snapshot including the pinned
`active_model`, plus `total_messages`, `agent_profile`, `stats`, `system_prompt`,
`tools_available`, `last_message_fingerprint`, `import_provenance`,
`created_worktree` (PART-SESSIONS sections 3.1, 3.4, 3.5).

### Resume semantics

| Mechanism | Scope | Behavior |
|-----------|-------|----------|
| `-c` / `--continue` | Folder-scoped | Per-TTY pointer first, else most recent session reaching the cwd; errors if none |
| `--resume <ID>` | Global | Resolves by ID with no directory filter; partial IDs supported, latest wins on ambiguity; requires an ID in `-p` mode |
| `/resume` (alias `/continue`) | Folder-scoped picker | Sorted by recency; `D` twice deletes a listed session (never the active one) |
| `/clear` (alias `/new`) | New conversation | Unpinned — follows current config, resets the model pin |

(PART-SESSIONS sections 3.2-3.3, 3.5; PART-COMMANDS section 2.)

Two persistence behaviors worth knowing: the **first user message pins the resolved
model alias** into the session's config snapshot, so a resumed session keeps its model
even if the configured default changed (`/model` updates the pin; a removed model falls
back to the current default); and **session titles** are auto-generated by a background
LLM call on a cheap title model (first after the opening turn, then every 6 steps, and
always after a compaction; capped if it falls back to the active model), while
`/rename <title>` writes a `manual` title that auto-generation never overwrites
(PART-SESSIONS sections 3.4-3.5).

Because `-c` and the picker are directory-scoped, a worktree sees only its own
sessions; carry a session across worktrees with `--resume <ID>` (PART-SESSIONS section
3.2; PART-WORKTREES).

## 8. Extension surfaces

Every way to teach the harness something new, each verified:

| Surface | What it adds | Where it lives | Backend |
|---------|--------------|----------------|---------|
| AGENTS.md | Instructions injected into the prompt (project beats user, closer dir wins) | `~/.vibe/AGENTS.md`; project roots up to trust root; subdirs lazily | [stable] (PART-AGENTSMD) |
| Agent TOML | Primary and subagent profiles; any config key as override | `agent_paths` config, `.vibe/agents/`, `~/.vibe/agents/` | [stable] (PART-AGENTS section 8) |
| Skills | `SKILL.md` directories; frontmatter `name`/`description` required; `/skill-name` or model-invoked | Builtins first (`vibe`, `skill-creator`, reserved), then `skill_paths`, project `.vibe/skills` + `.agents/skills`, user `~/.vibe/skills` + `~/.agents/skills`, then registry (experimental); first match wins | [stable] (PART-SKILLS section 1) |
| Hooks | `pre_tool` / `post_tool` / `post_agent` — exactly three event types; command subprocess, stdin JSON, exit 0 + stdout JSON decision (`allow`/`deny`), fail-open unless `strict = true` | `<project>/.vibe/hooks.toml` (trusted only), `--add-dir` roots, then `~/.vibe/hooks.toml` | [both] (PART-HOOKS sections 1-3) |
| Slash commands | ~28 builtins (`/help`, `/config`, `/model`, `/compact`, `/resume`, `/loop`, `/rewind`, `/branch` in 2.25.8, ...); custom commands via user-invocable skills | Registered in code | [stable] (PART-COMMANDS section 2) |
| MCP servers | External tools `{alias}_{tool}`, under the same permission gate; transports `http` / `streamable-http` / `stdio`; OAuth is the default auth with OS-keyring token storage | `vibe mcp add`, `[[mcp_servers]]` in `config.toml` | [stable] (PART-MCP section 1) |
| Connectors | Mistral-hosted tool proxies `connector_{alias}_{tool}`; auto-discovered when a Mistral provider with API key is configured; bootstrap cached 600 s | `enable_connectors` + `[[connectors]]` | [both]; default-enabled split below (PART-CONNECTORS section 2) |
| Plugins | Agent Plugins 1.0 packages (`plugin.json` + portable `skills/` and `mcp.json`, plus an `ai.mistral.vibe` extension for hooks, knowledge, agents) | `~/.vibe/plugins/`, `<project>/.vibe/plugins/` | **[unified-harness] only** (PART-PLUGINS section 3) |

Do not overstate the plugin surface: the legacy backend never resolves plugins, and
`/plugins` / `/reload-plugins` were withheld in 2.25.0 and only registered in 2.25.8,
both gated on `--experimental-harness` (PART-PLUGINS section 3.5). There is no
marketplace or install registry in the source (PART-PLUGINS section 3.3).

## 9. The two backends

Vibe CLI 2.25.x ships two session backends (oracle, Backend tags section):

| Backend | Selection | Status |
|---------|-----------|--------|
| **[stable]** | Default; no flag | Today's documented default |
| **[unified-harness]** | `--experimental-harness`, requires the `mistralai_vibe_local_harness` package | The flag is **argparse-suppressed from `--help` when that package is not installed** — if you do not see the flag, the harness is not on your machine |

Where the backend changes behavior, this guide tags it. The verified differences:

| Mechanic | [stable] | [unified-harness] |
|-----------|----------|-------------------|
| Hooks | 3 event types in `hooks.toml` | Same 3 `hooks.toml` types, **plus** a separate 6-point typed API (`pre_agent_turn`, `post_agent_turn`, `pre_llm_call`, `post_llm_call`, `pre_tool_call`, `post_tool_call`) (PART-HOOKS-UNIFIED section 6) |
| Connectors | Discovered connector stays disabled until an explicit `[[connectors]]` entry | Ready connectors enabled by default, in memory only (PART-CONNECTORS section 2.4) |
| Plugins | Never resolved | Resolved; `/plugins`, `/reload-plugins` (2.25.8) (PART-PLUGINS section 3.5) |
| Mentioned files | Synthetic `read_file` call per mention | Content blocks attached at turn start (PART-SESSIONS section 6.1) |
| Sessions | `session_<ts>_<id>/` store | Additional `unified/<uuid>/` store; schema not publicly verified (PART-SESSIONS section 3.1) |
| `/teleport` | Available | Unavailable — the unified harness does not teleport (PART-WEB section 4.1) |

Permission decisions are shared: the unified binding translates the same per-call
resolver to the runtime's `ask` seam — both backends "decide approvals the same way,
off the same code" (PART-PERMISSIONS section 4.4, [unified-harness] note).

## 10. Beyond the CLI: desktop and web

The same agent ships on more surfaces; treat the tagged claims accordingly:

- **Vibe Code Web.** `/teleport` moves the current session to the cloud (zstandard-
  compressed messages and diffs, one-way); `& <prompt>` spawns a new cloud session from
  the CLI; `/remote-project` binds the repo to a web project in
  `~/.vibe/projects.toml` (PART-WEB sections 4.1-4.2). The cloud model itself —
  per-session single-tenant sandbox, 24 h duration, 3 h inactivity, sessions run
  Mistral Medium 3.5, sandbox deleted at end with branches/commits persisting — is
  **[docs-only]**: the oracle could not live-verify any of it (PART-WEB section 4.3).
- **VS Code and other IDEs.** A marketplace extension ships the agent built in and
  shares config and sessions with the CLI; Vibe implements the Agent Client Protocol
  and is published in the ACP registry, so it runs in other ACP-compatible clients —
  **[docs-only]** (PART-WEB section 4.4).
- **Vibe Code desktop.** The 0.12.0 app bundle ships its own Python app-server and a
  bundled harness 0.5.1; release notes confirm subagent side panels, session-location
  indicators (local / worktree / cloud), and pinned sessions per project —
  **[desktop-0.12.0]**; the GUI was not driven live (PART-WEB section 4.6).

## 11. Philosophy: less scaffolding, more model

The architecture bet behind everything above: put capability in the model, keep the
harness legible.

| Instead of | Vibe does |
|------------|-----------|
| Intent classifiers and task routers | One loop; the model decides which tool, when |
| Retrieval pipelines over the codebase | `grep`, `read_file`, and the `explore` subagent; the model navigates |
| Orchestration state machines | The conversation as state, persisted as `messages.jsonl` |
| Hard-coded safe/unsafe command lists only | A legible permission chain you can read in one table (section 5 above) |
| Scaffolding to recover context | One tunable compaction trigger plus explicit `/compact` |

The trade-offs are the source guide's trade-offs, and they survive the port: fewer
components mean fewer failure modes and one place to look when something breaks, at
the cost of fine-grained control — you get the model's judgment, not a pipeline you
can constraint-program. The verified counterweights are the ones this page has already
shown: per-tool permission chains, depth-1 delegation, turn caps in programmatic mode,
and fail-open-by-default hooks you can make `strict` where a wrong tool call would hurt
(PART-PERMISSIONS; PART-AGENTS section 9; PART-CLI; PART-HOOKS section 3.3).

## Appendix: what we do not know

Honesty about the boundaries of the verified surface — none of the below is stated as
fact anywhere in this guide:

| Topic | What we do not know | Why |
|-------|--------------------|----|
| Per-turn context-budget breakdown | Exact token cost of system prompt, instructions, history, and tool results per turn | Not in the oracle; the constituents are verified (section 3), the accounting is not |
| Master-loop internals | Step-by-step turn anatomy beyond the seams in section 1 — stop-condition handling, retry policy, event ordering | Oracle covers the seams (middleware, hooks, caps) and nothing finer |
| Per-model context windows | The actual window size of any Mistral model | Model specification, not harness mechanics; and compaction's threshold is not a window (section 3) |
| Token accounting | Which tokenizer `context_tokens` uses and its overheads | Not in the oracle |
| Exact system-prompt text | The default prompt body beyond its resolution rules | Not in the oracle |
| Session-file stability | Whether `meta.json` / `messages.jsonl` are a supported external API | The oracle verifies the format; it verifies no stability promise |

## Known gaps

- **The builtin-tool catalog lives elsewhere.** The oracle verifies tools only through
  permission and profile mechanics; the per-tool catalog (argument schemas, defaults)
  is [tools-reference.md](tools-reference.md), built from the installed-package schema
  dump (vibe 2.25.7) — section 2 here stays deliberately partial.
- **`smart-approve` (2.25.8, [unified-harness])** — the classifier's tool-mode wiring
  lives in the private harness package; exact behavior needs public verification. Do
  not build on it.
- **Unified-harness session store** — `~/.vibe/logs/session/unified/<uuid>/` exists on
  a live install, but whether it shares the `meta.json`/`messages.jsonl` schema is not
  verified.
- **Custom-agent `instructions` field** — parsed in 2.25.0 but consumed only by the
  plugin snapshot machinery; whether it ever reaches the model in the CLI is
  unresolved.
- **`ContextWarningMiddleware` config gating** — the middleware and its 50% threshold
  are verified; the `context_warnings` flag relationship is not.
- **Admin config layer** — layer 8 of the config stack is org-enforced and in-memory;
  its endpoint and wire format are not publicly documented.
- **Vibe Code Web runtime** — every cloud-session limit, quota, and sandbox detail is
  docs-only; the docs themselves carry TODO notes.
- **Plugin UX beyond the manifest** — plugin resolution is source-verified, but
  `/plugins` flows were not exercisable without the harness package; treat the
  surfaces as released, not as battle-tested.
- **Sandboxing** — repeated because it matters: there is no OS-sandbox mechanic
  anywhere in the oracle. The local boundary is trust + per-tool permissions +
  worktrees; anything stronger is infrastructure you add yourself.

## See also

- [Agent Harness Engineering](./agent-harness.md) — the four-layer model this runtime
  sits in; loop, components, security
- [Context Engineering](./context-engineering.md) and [Memory Systems](./memory-systems.md) —
  what enters the context, what persists across sessions
- [Loop & Graph Engineering](./loop-graph-engineering.md) — loop contracts and stopping
  rules built on this harness
- [Methodologies](./methodologies.md) — working patterns on top of the loop
- [Glossary](./glossary.md) — the vocabulary used across these pages
- The mechanics oracle: [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md)
- The [style guide](../style-guide.md) for this guide's voice and evidence rules
- [Tools Reference](tools-reference.md): the complete builtin-tool catalog and permission-rule format
- [Workflows](../workflows/README.md): step-by-step recipes; CI recipes with programmatic mode are in [Automation](../ops/automation.md); sub-agent team patterns in [Module 07](../learning-path/07-advanced.md)
- [Learning Path](../learning-path/README.md): the ordered curriculum
- Surfaces pages (desktop and web in depth): not written yet; the verified web surface is in the oracle, PART-WEB
