---
title: "Glossary"
description: "Definitions for every term this guide uses: universal agentic-coding vocabulary, plus the Vibe mechanics behind each product term"
tags: [reference, glossary, core]
---

# Glossary

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Definitions come in two halves. **Universal terms** are the tool-agnostic vocabulary of agentic coding; they transfer to any runtime harness. **Vibe mechanics** are product terms, rebuilt from the mechanics oracle ([verified-mechanics.md](../../docs/mechanics/verified-mechanics.md)) — every command, flag, key, and path carries a `(PART-…)` citation, and a backend tag (`[stable]`, `[unified-harness]`, `[both]`) marks where the session backend matters. Model-level concepts (tokens, temperature, attention) are out of scope.

**TL;DR**: One-short-definition-per-term reference. The universal half (harness family, loops, judgment allocation) is product-agnostic. The mechanics half covers Vibe's actual surface: agent profiles instead of permission modes, depth-1 subagents, programmatic mode that auto-denies instead of prompting, the `AGENTS.md` instruction hierarchy, config layering, trusted folders, two distinct hook surfaces, skills, MCP, connectors, plugins, worktrees, and sessions.

*Read if a term anywhere in this guide is unfamiliar, or you want the one-paragraph version of a Vibe mechanic. Skip if you want depth on a single system — each entry links to its deep-dive page.*

---

## Universal agentic-coding terms

Tool-agnostic. Where a term implies a mechanic, the Vibe implementation is cited; otherwise the definition stands on its own.

### Agent-computer interface

The commands, observations, feedback format, and interaction rules through which a model acts on a computer. A better interface can improve an agent without changing the model. SWE-agent (arXiv:2405.15793) uses the term for its repository-oriented command and feedback design. The interface is one component of a runtime harness, not only its visual UI. See [agent-harness.md](agent-harness.md).

### Agent harness (runtime harness)

The runtime around a model that executes an agent loop: it assembles context, exposes tools, applies permissions, preserves or restores state, and feeds tool results back to the model. Vibe CLI is a runtime harness; the model it runs is separate. Do not confuse it with the repository harness below. See [agent-harness.md](agent-harness.md).

### Agentic loop

The cycle an agent works through for every task: gather context, take action, verify results, repeat until done. Each tool result informs the next step. The extension points plug into specific phases of this loop — on Vibe, skills load on demand (PART-SKILLS section 1.4), hooks fire around tool calls and turns (PART-HOOKS section 1), and MCP servers and connectors add tools (PART-MCP section 1, PART-CONNECTORS section 2). See [architecture.md](architecture.md).

### Best-of-n

Generating n candidate solutions — runs, branches, or patches — and selecting by an explicit verification signal rather than by model self-assessment. On Vibe, parallel candidates ride `--worktree` (PART-WORKTREES) and scripted candidates ride programmatic mode (PART-CLI). See [methodologies.md](methodologies.md).

### Context window

The token capacity a model can attend over in one call: the agent's working memory. Mechanically, what a Vibe session manages is not the model's window but the compaction threshold at which the harness summarizes the conversation (see [Compaction](#compaction-both)); window sizes themselves are model spec, not mechanics (PART-SESSIONS section 4). See [context-engineering.md](context-engineering.md).

### Evaluation harness

A repeatable setup that runs an agent or model against defined tasks and records outcomes, costs, traces, or scores. It measures a system; it does not need to own the system's interactive tool loop or act on a repository. SWE-bench tooling is an evaluation harness; a coding runtime is a harness that can be evaluated with one. See [agent-harness.md](agent-harness.md).

### Graph engineering

The design of an agent workflow as an explicit executable graph with versioned state, nodes, edges, routing conditions, joins, and recovery behavior. A graph can contain loops, but the two terms are not synonyms: a loop describes repeated feedback, a graph describes the topology that routes work and state. The label is emerging, not standardized. See [loop-graph-engineering.md](loop-graph-engineering.md).

### Harness-model pair

The exact combination of model, runtime harness, configuration, tool set, repository environment, and budget used for a run. Evaluate the pair as one unit: changing the harness can change accuracy, cost, and failure modes with the model fixed. The Scaffold Effect study (arXiv:2607.22585) provides controlled evidence across two models and three coding harnesses. See [agent-harness.md](agent-harness.md).

### Harnessability

A working evaluation dimension for how reliably a model follows a particular harness under realistic pressure: required checks, policy boundaries, recovery protocol, state transitions, escalation rules. It is not a scalar or an intrinsic model property. Report observed rates and failure modes for a specific harness-model pair, not a universal score. See [agent-harness.md](agent-harness.md).

### Harness optimizer

An outer-loop system that proposes changes to a target harness, evaluates candidate versions, and retains or rejects those changes against defined metrics. Its search target may include prompts, context rules, tools, control flow, verification, or memory policy. It does not replace the runtime loop it evaluates. See [agent-harness.md](agent-harness.md).

### Judgment allocation

The explicit assignment of decisions across humans, models, deterministic checks, policy engines, and external authorities: who sets the quality bar, what evidence is admissible, who decides it is sufficient, who handles exceptions. Automating execution relocates human judgment to loop design, policy, and escalation; it does not eliminate it. See [loop-graph-engineering.md](loop-graph-engineering.md).

### Loop engineering

The design of a repeated feedback process that finds or receives work, invokes an agent, observes results, verifies progress, and chooses the next action until a stopping rule fires. Practitioner vocabulary, not a formal standard. A loop may be encoded inside a graph and bounded by a harness; the scheduled form on Vibe is `/loop` (see [Loop automation](#loop-automation-both)). See [loop-graph-engineering.md](loop-graph-engineering.md).

### Meta-harness

An overloaded term with two uses. In optimizer research: a system around one or more target harnesses that generates or modifies candidate harnesses, runs evaluations, and uses the results to guide another optimization step. Some products use the word for a common client that dispatches tasks to existing runtime harnesses — this guide classifies that second role as an orchestrator. See [agent-harness.md](agent-harness.md).

### Orchestrator

A system that coordinates runs, workspaces, queues, budgets, handoffs, or human approvals across one or more agents. It may call a separate runtime harness without owning the model-tool-observation loop itself. See [agent-harness.md](agent-harness.md).

### Prompt injection

Hostile instructions embedded in a file, web page, or tool result that attempt to redirect the agent toward actions you never requested. Vibe's structural defenses are the per-call permission chain and bash guardrails (PART-PERMISSIONS sections 4.2-4.4) and trust gating, which keeps an untrusted directory's config, hooks, skills, and `AGENTS.md` out of the session entirely (PART-TRUST section 3.5).

### Repository harness

The project-specific layer that makes an agent run repeatably inside a repository: instructions, environment setup, durable state, test commands, verification gates, recovery conventions. On Vibe it is checked-in `AGENTS.md`, `.vibe/` config, hooks, skills, and custom agents (PART-AGENTSMD, PART-CONFIG section 2.5, PART-HOOKS section 1, PART-SKILLS section 1.2). It grounds and checks the runtime harness; it does not replace the runtime's model-tool loop. See [agent-harness.md](agent-harness.md) and [memory-systems.md](memory-systems.md).

### Scaffold effect

The variation in outcome, token use, and failure mode caused by the surrounding agent harness while the model is held fixed. In one controlled coding study, harness choice changed token use per solved task by up to 40 times while pass-rate differences stayed between 0 and 8 percentage points and were mostly not statistically significant. Evidence from a bounded experiment, not a universal ranking. (arXiv:2607.22585)

### Tool

An action the agent can take: read a file, edit code, run a shell command, search, spawn a subagent. Tools are what make the loop agentic — without them the model can only respond with text. On Vibe every tool call passes the per-call permission chain before it runs (PART-PERMISSIONS sections 4.2-4.4).

### Turn

One complete response within a session: it begins when you send a message and ends when the agent finishes, with any number of tool calls in between. On Vibe, `post_agent` hooks fire once per turn (PART-HOOKS section 1).

### Verification loop

A session pattern where you give the agent a check it can run — a test suite, a build, a screenshot comparison — and it iterates until the check passes instead of stopping after one attempt. It is the prerequisite for unattended runs: without one, the only signal that the agent is finished is the agent itself. On Vibe the scheduling layer for unattended checks is `/loop` (PART-SESSIONS section 5). See [methodologies.md](methodologies.md).

---

## Vibe mechanics

Every mechanic below comes from the oracle. Backend tags mark where the stable CLI backend and the Unified Harness (`--experimental-harness`) differ.

### AGENTS.md

The markdown instruction file Vibe loads as persistent guidance (PART-AGENTSMD). Three levels: user `~/.vibe/AGENTS.md` always loads; project `AGENTS.md` files load from each project root walking up to its trust root; `AGENTS.md` files in subdirectories load lazily when a file beneath them is read. Priority: project over user, closer directory over distant one; `AGENTS.md` overrides the default system prompt. Project files load only for trusted folders. There is no auto-loaded rules file — scoped `AGENTS.md` in subdirectories is the path-scoping mechanism. See [memory-systems.md](memory-systems.md).

### Agent profile [stable]

Vibe's counterpart to a permission mode: a named configuration layered onto the config stack (the agent profile layer, PART-CONFIG section 2.1) that sets tool permissions and disabled tools. The four built-ins are defined in code, not TOML (PART-PERMISSIONS section 4.1, PART-AGENTS section 7):

| Profile | Safety | Behavior |
|---|---|---|
| `ask` | neutral | every tool call not allowlisted goes through approval |
| `plan` | safe | read-only: `write_file` and `edit` hard-disabled (`permission = "never"`) with a `$VIBE_HOME/plans/*` allowlist; `read_file`'s allowlist includes the plans directory |
| `accept-edits` | destructive | file tools always run, everything else normal; the default `default_agent` |
| `auto-approve` | yolo | `bypass_tool_permissions = true` — approves all tool calls |

Select with `vibe --agent NAME` or the `default_agent` config key; Shift+Tab cycles `ask → plan → accept-edits → auto-approve`, then custom agents (PART-AGENTS section 10). Custom profiles are `NAME.toml` files in `~/.vibe/agents/` or `.vibe/agents/`; any config key is a valid override, and a custom profile may replace a built-in of the same name (PART-AGENTS section 8). `plan` is a profile, not a mode toggle: write tools are hard-disabled at the config layer with the plans directory as the only exemption. Release 2.25.8 (source) adds a fifth profile, `smart-approve`, which classifies each tool call and auto-runs the safe ones — Unified Harness only (PART-AGENTS section 7, PART-DELTAS); see Known gaps.

### Built-in skills [stable]

The two skills registered in code rather than as `SKILL.md` files: `vibe` — the CLI's self-awareness reference, model-only (`user-invocable false`), documenting config, tools and permission resolution, skills, hooks, sessions, and AGENTS.md discovery — and `skill-creator`, which loads before creating or updating a skill. Their names are reserved; a discovered skill colliding with a builtin name is silently skipped (PART-SKILLS section 1.5).

### Cloud session [docs-only]

A session run by Vibe Code Web in an isolated single-tenant sandbox: spawned from the web, from the CLI with `&`, or via `/teleport`; lifecycle Start / Clone / Run / Review / End; the sandbox is deleted at session end while branches, commits, and PRs persist in GitHub. Described per docs.mistral.ai only — no live verification was possible (PART-WEB section 4.3).

### Compaction [both]

Automatic summarization of the conversation before the context grows past the limit. The threshold is `auto_compact_threshold` (default 200,000 tokens), overridable per model; `0` disables auto-compaction. It triggers before a turn when context tokens reach the threshold, with a one-time warning at 50% of it. `/compact [instructions]` compacts manually; the compaction prompt is swappable via `compaction_prompt_id`, and an optional `compaction_model` does the summarizing. Compaction keeps the same session and visible conversation (PART-SESSIONS section 4). See [context-engineering.md](context-engineering.md).

### Config layering [stable]

The eight-layer stack Vibe merges config from, lowest to highest: defaults < GrowthBook experiments < user `~/.vibe/config.toml` < project `.vibe/config.toml` (trusted only) < `VIBE_*` environment variables < session overrides < agent profile < admin. Project config overrides user config; scalars replace, lists concatenate, tables union by name (PART-CONFIG section 2.1). Any config key is overridable as `VIBE_<KEY>`, nested keys as `VIBE_SECTION__KEY`; `~/.vibe/.env` supplies keys the shell has not set (PART-CONFIG section 2.2).

### Connector [both]

A Mistral-hosted tool source, auto-discovered when `enable_connectors` (default `true`) and a configured Mistral provider with a usable API key (PART-CONNECTORS section 2.2). Tools publish as `connector_{alias}_{tool}` and are disabled per connector or per tool via `[[connectors]]` entries (PART-CONNECTORS sections 2.1, 2.3). Backend split: the default backend keeps a discovered connector disabled until it has an explicit `[[connectors]]` entry; the Unified Harness enables ready connectors in memory (PART-CONNECTORS section 2.4).

### Hook [both]

A shell command that runs automatically at a fixed point in the session — deterministic, never at the model's discretion. Two distinct surfaces, not one list. In `hooks.toml` (`<project>/.vibe/hooks.toml` for trusted roots, then `~/.vibe/hooks.toml`) there are exactly three event types: `pre_tool`, `post_tool`, and `post_agent` (once per turn) — `[stable]` (PART-HOOKS sections 1-2). The Unified Harness separately declares six typed points — `pre_agent_turn`, `post_agent_turn`, `pre_llm_call`, `post_llm_call`, `pre_tool_call`, `post_tool_call` — `[unified-harness]` (PART-HOOKS-UNIFIED section 6).

### Loop automation [both]

A recurring prompt scheduled inside the session with `/loop <interval> <prompt>` — minimum interval `30s`, at most 50 loops per session, prompts may not start with `/`. Managed with `/loop list` and `/loop cancel <id|all>`. Loops persist in the session's `meta.json` and are restored on resume; they fire only when the session is idle (PART-SESSIONS section 5).

### MCP server [stable]

An external tool source added with `vibe mcp add NAME` (transports `http`, `streamable-http` — the default — and `stdio`) or as an `[[mcp_servers]]` entry in `config.toml`. OAuth browser login is the default; static auth via `--api-key-env` (PART-MCP sections 1.1-1.4). Tools publish as `{alias}_{tool}` and take per-tool permissions exactly like built-in tools (PART-MCP sections 1.7-1.8).

### Permission rule [stable]

A `[tools.<name>]` table in `config.toml` or an agent profile: `permission` = `ask` / `always` / `never`, plus per-tool lists. File tools match path globs with the denylist checked before the allowlist; the bash tool matches command prefixes, with `denylist_standalone` for bare commands and `sensitive_patterns` (default `["sudo"]`) that always ask (PART-PERMISSIONS sections 4.3-4.5). "Approve permanently" at the prompt writes the approved pattern back into the tool's `allowlist` (PART-PERMISSIONS section 4.2).

### Plugin [unified-harness]

An installable package resolved only by the Unified Harness — the default backend never resolves plugins (PART-PLUGINS section 3). A plugin is a directory with an Agent Plugins 1.0 `plugin.json` manifest; the portable components are skills (`skills/<dir>/SKILL.md`) and MCP servers (`mcp.json`), and Vibe's `ai.mistral.vibe` extension adds runtime hooks, knowledge, and agents. Plugins live in `~/.vibe/plugins/` (user) or `.vibe/plugins/` (project; project wins). `/plugins` and `/reload-plugins` are registered in release 2.25.8 (source) (PART-PLUGINS sections 3.1-3.5).

### Programmatic mode [stable]

`vibe -p [TEXT]` (alias `--prompt`): send one prompt, print the response, exit. It never prompts — approval-required tool calls are auto-DENIED, and `ask_user_question` and `exit_plan_mode` are force-disabled (live-verified on 2.25.0) (PART-CLI, PART-TRUST section 3.4). Budgets apply only here: `--max-turns`, `--max-price`, `--max-tokens`; `--resume` requires an explicit session ID (PART-CLI). Pass `--auto-approve`/`--yolo` when a run should approve every tool call; pass `--trust` to skip the trust prompt in automation (PART-CLI, PART-TRUST section 3.3).

### Rewind [stable]

`/rewind` rewinds the conversation to a previous message; pressing Esc twice on empty input does the same (PART-COMMANDS section 2). Rewinding is conversation-level only: Vibe has no mechanic that snapshots and restores the filesystem, so a rewound conversation does not revert edits already on disk — use git or a worktree for that. See [architecture.md](architecture.md).

### Session [stable]

A conversation with its own context, persisted on disk and resumable. Sessions are scoped to their directory: `-c` continues the most recent session for this terminal and working directory, while `--resume [ID]` resolves globally and accepts partial IDs (PART-SESSIONS sections 3.2-3.3). The first user message pins the session's active model; resuming keeps the pin even if the configured default changed (PART-SESSIONS section 3.5).

### Session store [stable]

The on-disk session layout: `$VIBE_HOME/logs/session/<prefix>_<timestamp>_<short-id>/` containing `meta.json` (session id, parent session, git state, pinned model, scheduled loops, title) and `messages.jsonl` (one JSON object per message) (PART-SESSIONS section 3.1). See [architecture.md](architecture.md).

### Skill [stable]

A directory containing a `SKILL.md`: YAML frontmatter — `name` and `description` required; `user-invocable` (default `true`) controls whether `/skill-name` resolves for you or the skill stays model-only — followed by a markdown body (PART-SKILLS section 1.1). The format follows the Agent Skills specification. Discovery order: built-ins (names reserved) → `skill_paths` config entries → project `.vibe/skills/` then `.agents/skills/` per project root → user `~/.vibe/skills/` then `~/.agents/skills/` → registry; first match wins on a name collision (PART-SKILLS section 1.2). Invoke a user-invocable skill with `/skill-name [extra instructions]`; the model loads any skill through the `skill` tool, which returns the body, the skill's base directory, and a file listing (PART-SKILLS sections 1.3-1.4).

### Skills registry [stable, experimental flag]

Mistral-hosted shared skills, gated by `experimental_enable_registry_skills` (default `false`) plus a Mistral provider and API key. Pinned in `~/.vibe/skills.toml` (global) or `<root>/.vibe/skills.toml` (project; project wins); versions are integers with a `latest` alias; pinned skills are materialized under `~/.vibe/skills-registry-cache/<skill_id>/<version>/` and browsed with `/skills`. Local and built-in skills win name collisions (PART-SKILLS section 1.6).

### Slash commands [stable]

Commands typed at the prompt starting with `/`. The built-in set in 2.25.0: `/help`, `/config`, `/model`, `/skills`, `/thinking`, `/reload`, `/clear`, `/copy`, `/paste-image`, `/log`, `/log-level`, `/debug`, `/compact`, `/exit`, `/status`, `/whoami`, `/teleport`, `/remote-project`, `/proxy-setup`, `/resume`, `/rename`, `/mcp`, `/voice`, `/leanstall`, `/unleanstall`, `/rewind`, `/retry`, `/loop`, `/data-retention`, `/theme` (PART-COMMANDS section 2). Release 2.25.8 (source) adds `/plugins` and `/reload-plugins` (Unified Harness) and `/todo` (Unified Harness) and `/branch` (PART-COMMANDS section 2, PART-DELTAS). A leading `/` also resolves user-invocable skills (PART-SKILLS section 1.3).

### Subagent [stable]

A child session the model spawns through the `task` tool (args: `task`, and `agent` defaulting to `explore`). Only profiles with `agent_type = "subagent"` are spawnable, and depth is capped at 1 — a subagent cannot spawn another (an explicit tool error). The result returned to the parent is text-only: `response`, `turns_used`, `completed`. Child sessions persist under the parent's session directory (`agents/`), are resumable, and inherit the parent's permission store (PART-AGENTS section 9). Built-in subagent profiles: `explore` (read-only — `grep`, `read_file`, `skill`) and `lean`, the opt-in Lean 4 proving agent installed via `/leanstall` (PART-AGENTS section 7).

### Surface

A place you run Vibe: the CLI, Vibe Code Web, the VS Code extension (Vibe implements the Agent Client Protocol, ACP), and the Vibe desktop app. Per the docs, custom agents, skills, MCP servers, and connectors work across CLI, VS Code, and Web; the desktop app's specifics are release-notes-level (PART-WEB sections 4.4, 4.6).

### System prompt replacement [stable]

A custom prompt file that entirely replaces the default system prompt: place `NAME.md` in `$VIBE_HOME/prompts/` or a project `.vibe/prompts/` and set `system_prompt_id = "NAME"`. Resolution checks project prompt dirs, then `~/.vibe/prompts/`, then built-in ids (`cli`, `explore`, `tests`, `lean`, `minimal`) (PART-AGENTSMD, PART-AGENTS section 8).

### Teleport [stable]

`/teleport` moves the current session to Vibe Code Web: it checks the git repository (a push may be required first) and uploads the conversation. One-way — the docs list return teleport as a planned follow-up; there is no mechanic for pulling a cloud session back into the local CLI. Unavailable under `--experimental-harness`. The `&` prefix is the other direction: it spawns a new cloud session from a prompt and prints the web URL (PART-WEB sections 4.1-4.2).

### Thinking level [stable]

The reasoning budget knob: `/thinking` selects the thinking level for the session (PART-COMMANDS section 2), and models take a `thinking` setting in their model config (values such as `high` or `off`) (PART-AGENTS section 7). The oracle does not enumerate the full level set — see Known gaps.

### Trusted folder [stable]

A directory recorded in `~/.vibe/trusted_folders.toml` (`trusted` and `untrusted` arrays of resolved paths; the closest ancestor with a decision wins, so trust and untrust are inherited down the tree) (PART-TRUST section 3.1). Trust gates everything project-scoped: `.vibe/` config, hooks, skills, agents, and repo `AGENTS.md` load only from trusted roots, while an untrusted working directory stays writable but contributes no configuration (PART-TRUST section 3.5). `--trust` and `--worktree` grant session-only trust, never persisted; `--add-dir` roots join the workspace implicitly trusted (PART-TRUST section 3.3).

### Worktree [stable]

`vibe --worktree [NAME]` runs the session in a git worktree under `$VIBE_HOME/worktrees/<repo-name>-<repo-hash>/` (PART-WORKTREES, PART-CLI). With a name: checked out on a branch named `NAME`, reused only for the same repo and branch. Without: named after the prompt (slugified, max 40 chars) on a `vibe/<name>` branch, never reused. The worktree is implicitly trusted for the session and removed on exit if it has no uncommitted changes, untracked files, or new commits. Sessions are directory-scoped, so carry one across worktrees with `--resume <ID>` (PART-WORKTREES).

---

## Aliases and near-synonyms

Names you will meet in the CLI that are aliases of another mechanic:

| Alias | Canonical | Note |
|---|---|---|
| `--yolo` | `--auto-approve` | same flag (PART-CLI) |
| `--prompt` | `-p` | programmatic mode (PART-CLI) |
| `/connectors` | `/mcp` | one browser for MCP servers and connectors (PART-MCP section 1.6) |
| `/continue` | `/resume` | session picker (PART-SESSIONS section 3.3) |
| `/new` | `/clear` | new conversation, optional seed prompt (PART-COMMANDS section 2) |
| Esc Esc (empty input) | `/rewind` | rewind to a previous message (PART-COMMANDS section 2) |

---

## Known gaps

- **No checkpoint mechanic.** `/rewind` rewinds the conversation only; nothing in the oracle snapshots or restores files (PART-COMMANDS section 2). The source guide's "checkpoint" term was dropped for this reason, not approximated.
- **No automatic memory.** Nothing in the oracle extracts or persists memories on its own; durable user preferences live in `~/.vibe/AGENTS.md`, durable project conventions in checked-in `AGENTS.md` (PART-AGENTSMD).
- **No documented OS-level sandboxing surface.** The closest mechanics are the bash guardrails — `denylist`, `denylist_standalone`, `sensitive_patterns`, output and timeout caps — inside the per-call permission chain (PART-PERMISSIONS section 4.4).
- **No multi-session agent-team or peer-messaging mechanic.** Vibe's multi-agent surface is depth-1 subagents through the `task` tool (PART-AGENTS section 9).
- **No deferred MCP tool-schema loading.** The oracle documents tool publication and per-tool permissions (PART-MCP sections 1.7-1.8) but no on-demand schema fetch.
- **Admin config layer endpoint.** The layer exists in the stack (PART-CONFIG section 2.1) but its endpoint and wire format are not publicly documented; treat org-enforced config as present but unverifiable.
- **`smart-approve` classifier wiring.** The profile is defined in release 2.25.8 (source) (PART-AGENTS section 7, PART-DELTAS); the classifier's tool-mode wiring lives in a private package and is not publicly documented.
- **Vibe Code Web runtime.** Limits, quotas, and sandbox contents are docs-only, not live-verified (PART-WEB section 4.3).
- **Thinking level values.** The oracle shows the `/thinking` command and model-config `thinking` values (`high`, `off`) but does not enumerate the full level set (PART-COMMANDS section 2, PART-AGENTS section 7).

---

## See also

- [agent-harness.md](agent-harness.md) — the harness family in depth
- [loop-graph-engineering.md](loop-graph-engineering.md) — loops, graphs, judgment allocation
- [context-engineering.md](context-engineering.md) — context budget and compaction strategy
- [memory-systems.md](memory-systems.md) — the AGENTS.md instruction hierarchy in depth
- [architecture.md](architecture.md) — how the Vibe session loop works
- [methodologies.md](methodologies.md) — verification loops and best-of-n in practice
- The mechanics: [verified-mechanics.md](../../docs/mechanics/verified-mechanics.md)

See also: the [workflows pages](../workflows/README.md) (workflow recipes per methodology), the [tools reference](tools-reference.md) (per-tool catalog), and the [learning path](../learning-path/README.md). Surfaces pages (CLI, desktop, and web in depth) are not written yet.
