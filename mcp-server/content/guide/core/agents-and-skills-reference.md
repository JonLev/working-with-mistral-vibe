---
title: "Agents and Skills Reference"
description: "The complete mechanics of Vibe agents and skills: built-in agent profiles, custom agent TOML, the task tool, SKILL.md frontmatter, skill discovery, and the skills registry"
tags: [agents, skills, subagents, task-tool, reference]
---

# Agents and Skills Reference

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

## TL;DR

- Vibe ships with six built-in agents in the 2.25.0 core — `ask`, `plan`,
  `accept-edits`, `auto-approve`, the `explore` subagent, and the opt-in
  `lean` agent — plus `smart-approve` at 2.25.8, Unified Harness only. Each
  is a profile: a safety class plus config overrides layered onto the
  running session (PART-AGENTS section 7; PART-PERMISSIONS section 4.1).
- Custom agents are `NAME.toml` files discovered from `agent_paths` entries
  → project `.vibe/agents/` per trusted root → `~/.vibe/agents/`. Five keys
  are parsed as profile fields; every remaining key becomes a config
  override, so any `config.toml` field is valid in an agent TOML
  (PART-AGENTS section 8).
- The `task` tool is the only way to spawn a subagent: depth capped at 1,
  only `agent_type = "subagent"` profiles spawnable, text-only results
  (PART-AGENTS section 9).
- A skill is a directory containing a `SKILL.md`. Frontmatter supports
  exactly seven keys; unknown keys are silently ignored. Discovery runs:
  builtins (reserved names `vibe`, `skill-creator`) → `skill_paths` →
  project `.vibe/skills/` then `.agents/skills/` → user dirs → registry
  behind an experimental flag; first match wins (PART-SKILLS sections
  1.1–1.2).

*Read if you need a built-in agent's exact permission overrides, are writing
a custom agent TOML, or need the `task` tool's security constraints or the
`SKILL.md` schema. Skip if you want design patterns for multi-agent
orchestration — that is [Skill design patterns](skill-design-patterns.md),
which builds on this page's mechanics.*

## Built-in agents — quick reference

| Agent | `display_name` | Safety | One-line meaning | Backend |
|---|---|---|---|---|
| `ask` | Ask | `neutral` | Requires approval for tool executions | **[stable]** |
| `plan` | Plan | `safe` | Read-only agent for exploration and planning; writes only under the plans dir | **[stable]** |
| `accept-edits` | Accept Edits | `destructive` | Auto-approves file edits only; the default agent | **[stable]** |
| `smart-approve` | Smart Approve | `smart` | Classifies each tool call and auto-runs the safe ones, prompting only for risky ones | **[unified-harness]** |
| `auto-approve` | Auto Approve | `yolo` | Auto-approves all tool executions | **[stable]** |
| `explore` | Explore | `safe` | Read-only subagent for codebase exploration; not user-selectable | **[stable]** |
| `lean` | Lean | `neutral` | Lean 4 code analysis, proof assistance, and theorem proving; opt-in install | **[stable]** |

Safety values come from the `AgentSafety` enum: `safe | neutral |
destructive | yolo` in the 2.25.0 core, with `smart` added at 2.25.8
(PART-AGENTS section 7). Safety is a classification carried on the profile;
the actual tool behavior comes from each profile's overrides. The 2.25.0
live `--help` lists "Builtin: ask, plan, accept-edits, auto-approve"
(PART-CLI); the installed 2.25.7 build lists `ask, plan, accept-edits,
smart-approve, auto-approve` (live --help, vibe 2.25.7 (2026-09-24)) — the
oracle's `smart-approve` entry is tagged **[unified-harness]**, documented
in release 2.25.8 (source).

## Built-in agent profiles — [stable]

Definitions live in code, not TOML (`vibe/core/agents/models.py`); the
tables below are the TOML-equivalent overrides (PART-AGENTS section 7;
PART-PERMISSIONS section 4.1).

### `ask` — neutral

| Override | Value |
|---|---|
| `disabled_tools` | `["exit_plan_mode"]` |

Every tool call that is not auto-approved by the permission system goes
through the approval prompt. Read-only bash commands still auto-run: bash
safety classification is consulted before the agent approval gate
(PART-PERMISSIONS sections 4.1, 4.4).

### `plan` — safe

| Override | Value |
|---|---|
| `disabled_tools` | `["exit_plan_mode"]` (inherited via config) |
| `tools.write_file.permission` | `"never"`, allowlist `["<VIBE_HOME>/plans/*"]` |
| `tools.edit.permission` | `"never"`, allowlist `["<VIBE_HOME>/plans/*"]` |
| `tools.read_file` | allowlist `["<VIBE_HOME>/plans/*"]` (plans dir additionally readable) |

`write_file` and `edit` are hard-disabled except for plan files under the
plans dir; the plan glob is built as `PLANS_DIR.path / "*"` at runtime. The
plans dir lives under `VIBE_HOME` (default `~/.vibe`, PART-CLI environment
variables) — user-home territory, not the repo.

### `accept-edits` — destructive, the default agent

| Override | Value |
|---|---|
| `disabled_tools` | `["exit_plan_mode"]` |
| `tools.write_file.permission` | `"always"` |
| `tools.edit.permission` | `"always"` |

File tools always run; everything else follows normal permission
resolution. This is the profile `default_agent` falls back to
(PART-CONFIG section 1.5).

### `smart-approve` — [unified-harness]

Added in main 2.25.8, positioned between `accept-edits` and `auto-approve`
in the picker. Description: "Classifies each tool call and auto-runs the
safe ones, prompting only for risky ones". Safety is `AgentSafety.SMART`;
the classification is gated by the runtime "classify" tool mode, Unified
Harness only, and requires explicitly selecting it, for example
`--smart-approve` (PART-AGENTS section 7, 2.25.8 deltas). Config keys
`smart_approve_available` / `smart_approve_default` (experiment-driven)
expose the mode in the picker (PART-DELTAS section 6). Documented in
release 2.25.8 (source).

### `auto-approve` — yolo

| Override | Value |
|---|---|
| `bypass_tool_permissions` | `true` |
| `disabled_tools` | `["exit_plan_mode"]` |

`bypass_tool_permissions = true` executes everything with no per-call
checks (PART-PERMISSIONS section 4.2).

### `explore` — safe, the built-in subagent

| Override | Value |
|---|---|
| `agent_type` | `"subagent"` |
| `enabled_tools` | `["grep", "read_file", "skill"]` |
| `system_prompt_id` | `"explore"` → `vibe/core/prompts/explore.md` |

Delegation-only: it cannot be selected with `--agent` and is reachable only
through the `task` tool (PART-AGENTS sections 8, 9). The `explore.md`
system prompt is a terse "senior engineer analyzing codebases" prompt
demanding code/diagram-first output (PART-AGENTS section 9).

### `lean` — neutral, opt-in

`install_required = true`: hidden unless listed in `installed_agents`;
install via `/leanstall`. `system_prompt_id = "lean"` →
`vibe/core/prompts/lean.md`. The profile ships its own provider and model:
provider `mistral-testing` (`https://api.mistral.ai/v1`,
`MISTRAL_API_KEY`, backend `mistral`), model `labs-leanstral-1-5` with
alias `leanstral` (`thinking = "high"`, `temperature = 1.0`,
`auto_compact_threshold = 200000`), compaction model `mistral-small-latest`
(alias `devstral-compact`, `temperature = 0.2`, `thinking = "off"`),
`active_model = "leanstral"`, and `[tools.bash] default_timeout = 1200`.
At 2.25.8, `allowed_models` changed from `["leanstral"]` to
`["labs-leanstral-1-5"]` (PART-AGENTS section 7, 2.25.8 deltas).

## Selecting and switching agents — [stable]

| Surface | Behavior |
|---|---|
| `vibe --agent NAME` | Validated against discovered + available agents. A subagent name errors with the exact `ValueError` in the custom agents section below (PART-AGENTS sections 8, 10) |
| `default_agent` | `config.toml` key, default `accept-edits`; applies in interactive and programmatic (`-p`) mode alike (PART-CONFIG section 1.5; PART-PERMISSIONS section 4.1) |
| Shift+Tab | Cycles `get_agent_order()`: `ask → plan → accept-edits → auto-approve` → custom primary agents sorted by name. The switch applies to the running session — profile overrides are re-installed via the config orchestrator's `AgentProfileLayer` (PART-AGENTS section 10) |
| `--auto-approve` / `--yolo` | Without `--agent`, selects the `auto-approve` profile. With `--agent X`, keeps profile X and additionally sets `force_bypass_tool_permissions` — so it combines with any agent and approves all tool calls (PART-PERMISSIONS section 4.1; PART-AGENTS section 10) |
| Programmatic mode (`-p`) | The selected agent (or `default_agent`) is honored: live tests show approval-required tool calls are auto-DENIED (effect status `cancelled`), not auto-approved. Pass `--auto-approve`/`--yolo` to allow all tool calls headlessly (PART-CLI, live verification on 2.25.0) |
| `--agent lean` before install | Errors via `excluded_agent_message`: "Agent 'lean' requires installation. Run it once via --agent 'lean', or add it to 'installed_agents'." (PART-AGENTS section 10) |

The docs.mistral.ai claim that `-p` mode "falls back to auto-approve" when
`--agent` is omitted is contradicted by live verification on 2.25.0: the
README and `--help` are right, the agent is honored, and approval-required
calls are cancelled (PART-CLI).

## Custom agents — [stable]

### Where agent TOML files live

Search-path order, first match by name wins; later duplicates are skipped
with a debug log (PART-AGENTS section 8):

| Order | Location | Notes |
|---|---|---|
| 1 | `agent_paths` entries (`config.toml`) | Absolute or relative to cwd |
| 2 | `.vibe/agents/` under each project root | Trusted cwd + `--add-dir` roots; discovered root-level only |
| 3 | `~/.vibe/agents/` | User dir |

The file is `NAME.toml` and the agent name is the file stem — there is no
`name` field. Files load at startup and are re-discovered on workspace
move. A custom TOML whose stem equals a builtin name replaces the builtin,
logging "Custom agent `&lt;name&gt;` overrides builtin agent".

### Parsed fields, and what everything else means

Five keys are parsed as profile fields (`AgentProfile.from_toml`);
everything else in the table becomes an override applied as a dedicated
`AgentProfileLayer` on the config orchestrator (PART-AGENTS section 8):

| Key | Required | Meaning |
|---|---|---|
| `display_name` | no | Defaults to the stem title-cased |
| `description` | no | Defaults to empty |
| `safety` | no | `safe` \| `neutral` \| `destructive` \| `yolo` (visual hint only); defaults to `neutral` |
| `agent_type` | no | `agent` (default) or `subagent` |
| `instructions` | no | Optional free text; see Known gaps — parsed but unconsumed by the legacy agent loop in 2.25.0 |
| *any other key* | — | Config override: `active_model`, `allowed_models`, `system_prompt_id`, `enabled_tools`, `disabled_tools`, `bypass_tool_permissions`, `[tools.<tool>]` `permission`/`allowlist`/`denylist`/`default_timeout`, `providers`, `models`, `compaction_model`, and so on |

Because every remaining key is an override, any `config.toml` field is
valid in an agent TOML. A broken definition (invalid override keys) fails
validation on a throwaway orchestrator copy and is dropped at discovery
with a warning.

At 2.25.8, `AgentProfile` gained `source_path` (the file a profile was
parsed from) — "The Unified Harness advertises a subagent to the model
with the path of the file behind it" (PART-AGENTS section 7, 2.25.8
deltas; **[unified-harness]**). Also documented in release 2.25.8
(source): a new install flow for opt-in built-in agents
(`vibe/core/agents/install.py`) (PART-DELTAS section 6).

### `agent_type` semantics

| `agent_type` | Selectable with `--agent` | Spawnable via `task` |
|---|---|---|
| `"agent"` (default) | Yes; also reachable via Shift+Tab cycle | No |
| `"subagent"` | No — raises `ValueError: Agent '<name>' is a subagent and cannot be used as the primary agent. Only agents of type 'agent' can be selected with --agent.` | Yes — the only way in |

A subagent is delegation-only: spawned by the model through the `task`
tool, it runs without user interaction and returns a text-only final
message to the parent (PART-AGENTS sections 8, 9).

### `system_prompt_id` resolution

The id must be a bare filename. Resolution order
(`vibe/core/prompts/__init__.py`, PART-AGENTS section 8):

1. `.vibe/prompts/<id>.md` in project dirs
2. `~/.vibe/prompts/<id>.md`
3. Built-in ids: `cli`, `explore`, `tests`, `lean`, `minimal`

### The docs example: `redteam.toml`

From the oracle (PART-AGENTS section 8):

```toml
# ~/.vibe/agents/redteam.toml
agent_type = "agent"
display_name = "Red team"
description = "Read-only audit agent for security review."
safety = "safe"
active_model = "mistral-medium-latest"
system_prompt_id = "redteam"
disabled_tools = ["search_replace", "write_file"]

[tools.bash]
permission = "ask"

[tools.read_file]
permission = "always"
```

For this to load, `redteam.md` must exist at `.vibe/prompts/redteam.md` or
`~/.vibe/prompts/redteam.md` (no builtin `redteam` id exists).

Plugin-shipped agents (`agent_plugins_1_0` format) are a separate schema —
always subagents, with their own field limits — covered in
[Plugins](plugins.md) (PART-AGENTS section 8).

### Agent config keys

```toml
# config.toml (PART-CONFIG section 1.5)
default_agent = "accept-edits"   # builtin: ask, plan, accept-edits, auto-approve;
                                # applies in interactive AND programmatic (-p) mode
agent_paths = ["/extra/agent/dir"] # extra dirs (abs or cwd-relative)
enabled_agents = ["custom-*"]      # when set, ONLY matching agents are available
disabled_agents = ["explore"]      # ignored when enabled_agents is set
installed_agents = ["lean"]        # opt-in builtin agents explicitly installed
```

`enabled_agents` / `disabled_agents` match with exact names, glob patterns
(`custom-*`), and regex with a `re:` prefix (PART-AGENTS section 8; PART-
CONFIG section 1.5).

## The `task` tool — [stable]

Tool: `task`, builtin, effect kind `SUBAGENT`. Shipped prompt
(`vibe/core/tools/builtins/prompts/task.md`): "Launch a subagent for
complex multi-step work. Provide a self-contained description. The
subagent runs read-only and returns a final message — summarize it to the
user yourself."

### Args and result

| Field | Type | Meaning |
|---|---|---|
| `task` (arg) | `str`, required | The task description; must be self-contained — the child is a fresh session |
| `agent` (arg) | `str`, default `"explore"` | The subagent profile to use |
| `response` (result) | `str` | Accumulated assistant text — text-only; no message objects, no files |
| `turns_used` (result) | `int` | Counts the child's assistant messages |
| `completed` (result) | `bool` | Errors append `[Subagent error: ...]` and mark the result incomplete |

### Security constraints

All three raise `ToolError` (PART-AGENTS section 9):

| Constraint | Exact error |
|---|---|
| Depth limit 1 — a subagent cannot spawn subagents | `Agent depth limit of 1 reached. Complete the task in the current subagent.` |
| Only `agent_type = "subagent"` profiles are spawnable | `Agent '<n>' is a <type> agent. Only subagents can be used with the task tool. This is a security constraint to prevent recursive spawning.` |
| Unknown agent name | `Unknown agent: <name>` |

The depth limit means an orchestrated run is one dispatcher fanning out —
never a tree. The read-only property of a subagent comes from its profile's
tool set (the built-in `explore` enables only `grep`/`read_file`/`skill`),
not from the mechanism: a custom subagent is whatever its overrides enable.

### Permission config

`TaskToolConfig`: `permission = "ask"` by default, `allowlist =
["explore"]` — the built-in `explore` subagent is auto-approved; any other
subagent requires approval unless allowlisted. Patterns are fnmatch over
the agent name; the denylist wins over the allowlist. Configurable via
`[tools.task]` in `config.toml` or agent overrides (PART-AGENTS section 9).

### Child session mechanics

Each `task` call creates a child session via `create_child(parent,
agent_name)` (PART-AGENTS section 9):

| Mechanic | Behavior |
|---|---|
| Session identity | Fresh session ID, `is_subagent = true`, `parent_session_id` set |
| Session log | Under `<parent session dir>/agents/` with a prefix of the agent name; persisted and resumable |
| Permissions | `share_permissions = true` — the child inherits the parent's permission store |
| Streaming | Disabled in the child |
| Prompt | The task text, prefixed with the parent's scratchpad dir when one exists ("Scratchpad directory: ... You can read and write files here without permission prompts.") |
| Results | `SubagentRunAccumulator` collects the child's assistant text; tool stream events surface to the parent only as task progress lines (`{tool_name}: {display}`); the parent model then summarizes the returned text to the user |
| Hooks | The child inherits the parent's hook config (the same `hooks.toml` files are loaded); child hook payloads carry `parent_session_id`. On the legacy 2.25.0 backend, CLI hooks run in subagents; on the experimental harness this was fixed in 2.25.1 |

### Unified Harness deltas — [unified-harness]

The harness backend tracks subagents as first-class child sessions
(PART-AGENTS section 9; all items documented in release 2.25.8 (source)
unless noted):

| Release | Delta |
|---|---|
| 2.25.1 | CLI hooks fixed to run in subagents on the harness backend |
| 2.25.5 | "Subagents no longer prompt for tool permission when the parent session is in auto-approve mode under the Unified Harness" |
| 2.25.5 | "Configurable live subagent status and read-only transcript switching from the interactive prompt" — config key `show_subagent_status_list = true` (PART-DELTAS section 6). Also subagent conversation history is readable through the owning parent session, and "A subagent Session is controlled by its parent" — direct client calls against a child are rejected |
| 2.25.8 | "Unified Harness: subagents defined in ~/.vibe/agents or .vibe/agents can be spawned again" |

Also 2.25.8: per-agent `system_prompt_id` is honored on the unified
backend. Subagent telemetry operations (`SubagentOperation` /
`SubagentOutcome` / `SubagentProfileSource`, including `subagent.list`)
are tracked in the harness adapter.

## Skills

### `SKILL.md` frontmatter — [stable]

A skill is a directory containing a `SKILL.md`: YAML frontmatter delimited
by `---` lines, followed by a Markdown body. Frontmatter must be the first
thing in the file (text before the first `---` is a parse error) and must
be a YAML mapping (PART-SKILLS section 1.1).

| Key | Required | Constraints |
|---|---|---|
| `name` | yes | 1–64 chars, `^[a-z0-9]+(-[a-z0-9]+)*$`; should match the directory name — a mismatch only logs a warning, the skill loads under the frontmatter name |
| `description` | yes | 1–1024 chars; routing text — the only text the model sees before loading the skill |
| `license` | no | License name or reference to a bundled license file |
| `compatibility` | no | Max 500 chars; environment requirements |
| `metadata` | no | Flat string-to-string map; values coerced to `str` |
| `allowed-tools` | no | Space-delimited string or list of pre-approved tools; experimental |
| `user-invocable` | no | Bool, default `true`; `false` = model-only: hidden from the slash menu, `/skill-name` does not resolve |

Unknown keys are **ignored**. The shipped `skill-creator` builtin says: "Do
not invent frontmatter keys. Fields from other products (e.g.
`visibility`, `defaultEnabled`) are not part of Vibe's schema and are
ignored." Vibe follows the Agent Skills specification
(agentskills.io) for skill format and structure; `user-invocable` is a
Vibe extension beyond the spec, and the optional `scripts/`,
`references/`, `assets/` directories come from the spec
(PART-SKILLS section 1.1).

Added only in main 2.25.8 (not in the 2.25.0 live baseline) — documented
in release 2.25.8 (source), PART-SKILLS section 1.1:

- `disable-model-invocation` — forces model-only even when
  `user-invocable` is true (`model_invocable = model_invocable and not
  meta.disable_model_invocation`).
- OpenAI `agents/openai.yaml` metadata inside the skill dir —
  `policy.allow_implicit_invocation` (default true); unknown policy keys
  are invalid, so a typo cannot silently re-enable model invocation.

### Canonical example (PART-SKILLS section 1.1, verbatim)

```markdown
---
name: code-review
description: Perform automated code reviews
license: MIT
compatibility: Python 3.12+
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - ask_user_question
---

# Code review skill

This skill helps analyze code quality and suggest improvements.
```

### Discovery order and precedence — [stable]

First match wins on a name collision (PART-SKILLS section 1.2):

| Order | Source | Notes |
|---|---|---|
| 1 | Built-in skills: `vibe`, `skill-creator` | Reserved names; a discovered skill colliding with a builtin is silently skipped |
| 2 | `skill_paths` entries (`config.toml`) | Absolute or cwd-relative; scope GLOBAL |
| 3 | Project dirs, per trusted project root: `<root>/.vibe/skills/` then `<root>/.agents/skills/` | Roots = trusted cwd + `--add-dir` paths; untrusted cwd contributes no project skill content |
| 4 | User dirs: `~/.vibe/skills/` then `~/.agents/skills/` | Scope GLOBAL |
| 5 | Registry skills (only when `experimental_enable_registry_skills = true`) | Loaded last — "a local/builtin skill wins" |

Project dirs are gated on trust (`trusted_folders.toml`); the user layer
is always active in the CLI. Filtering: `enabled_skills` non-empty is an
allowlist (everything else hidden); otherwise `disabled_skills` is a
blocklist. Both accept exact names, glob patterns (`test-*`), and regex
with a `re:` prefix (PART-SKILLS section 1.2; PART-CONFIG section 1.6).

### `/skill-name` invocation — [stable]

Input starting with `/` is classified in this order: `&teleport` →
registered slash command → `/skill-name` → `!bash` → plain prompt. A
`/skill-name` resolves only if the skill exists and `user_invocable` is
true; the remainder of the input is passed as `extra_instructions`. A
`/word` typed mid-prompt (not as the first word) shows an inline
ghost-text preview of the best-matching skill name, Tab to accept; only
skills are offered inline. A `user-invocable: false` skill is not
resolvable via `/skill-name` (it falls through to a plain prompt) but
remains loadable by the model through the `skill` tool (PART-SKILLS
section 1.3).

### The `skill` tool — [stable]

| Aspect | Behavior |
|---|---|
| Args | `{ "name": <skill name from available_skills> }` |
| Permission | `ALWAYS` — loading a skill never prompts |
| Result | A `<skill_content name="...">` envelope with the skill body, the skill's base directory ("Relative paths in this skill are relative to this base directory."), and a sampled `<skill_files>` listing |
| Sampling cap | Max 10 files listed, directory walk capped at 200 entries; `.git`, `node_modules`, `__pycache__`, `.venv`, `venv`, cache dirs, `dist`, `build` skipped; `SKILL.md` itself excluded from the listing |
| Already loaded | Returns "Skill '`<name>`' is already loaded earlier in this conversation. Reuse those instructions." — a skill loads once per conversation |
| Tool prompt | "Load a specialized skill by name. Follow the returned instructions step by step." |

(PART-SKILLS section 1.4.)

### Built-in skills — [stable]

Two, registered in code, not as `SKILL.md` files (PART-SKILLS section 1.5):

| Skill | `user_invocable` | Role |
|---|---|---|
| `vibe` | `false` (model-only) | The CLI self-awareness reference: `VIBE_HOME` layout, config keys, providers/models, tools and permission resolution, skills system, agents, hooks, CLI parameters, slash commands, environment variables, trusted folders. Its README URL template is substituted with the running version |
| `skill-creator` | `true` | Loads "before creating, updating, or deleting a Vibe skill"; documents the format, discovery order, scope choice, support files; changes are picked up with `/reload` |

### The skills registry (`/skills`) — [stable, experimental flag]

Gated by `experimental_enable_registry_skills` (default `false`), which
also gates the `/skills` slash command. Pulling shared workspace skills
from Mistral requires a configured Mistral provider with a usable API key
env var; local and builtin skills take precedence on name collision
(PART-SKILLS section 1.6).

| Mechanic | Behavior |
|---|---|
| Pin manifests | Global `~/.vibe/skills.toml`, project `<root>/.vibe/skills.toml` (TOML) |
| `ManifestEntry` fields | `name`, `skill_id`, `version` (int, or the reserved alias `"latest"`), `description` |
| `latest` alias | Always resolves to the newest version server-side; a pin set to it never reports "update available" |
| Cache dir | Registry skills materialize under `~/.vibe/skills-registry-cache/<skill_id>/<version>/SKILL.md`; a non-materialized or unsafe `skill_id` is skipped |
| Precedence | One active entry per name; the project manifest wins over global |
| `/skills` browser | Two tabs (Installed / importable catalog); bindings: `v` versions, `x` remove, `p` pin to project, `/` search, `←/→` switch tab, `Esc` close, `Backspace` back. Actions protocol: `detail`, `versions`, `import_skill` (with optional `alias`), `set_version`, `set_latest`, `set_alias`, `remove(name, scope)`. Pin labels: `latest (vN)`, `<alias> (vN)`, `vN`, or `local` |

### Skills config keys — [stable]

```toml
# config.toml (PART-CONFIG section 1.6)
skill_paths = ["/extra/skills"]               # extra dirs; ~ expanded, resolved
enabled_skills = ["search-*"]                # when non-empty, only matching skills load
disabled_skills = ["context7-mcp"]           # applied when enabled_skills is empty
experimental_enable_registry_skills = false  # registry gate; needs Mistral provider + key
```

## Known gaps

- **`instructions` in a custom agent TOML does not reach the model in the
  2.25.0 core.** The field is parsed and carried on the profile, but
  consumed only by the plugin snapshot machinery (`PluginAgentSnapshot`);
  the legacy agent loop does not append it to the CLI system prompt
  (PART-AGENTS section 8). Whether the unified backend or 2.25.8 consumes
  it for plain (non-plugin) agents is not covered by the oracle — put
  behavioral instructions in a `system_prompt_id` prompt file, which is
  verified to load.
- **`smart-approve` classifier internals are behind the private harness
  package.** The profile, `AgentSafety.SMART`, the "classify" tool mode
  gate, and the picker keys are source-verified for 2.25.8; the
  classification logic itself lives in the harness runtime, which was not
  installable in the oracle's environment (PART-AGENTS section 7; PART-
  PERMISSIONS section 4.4 note). The live 2.25.7 `--help` listing is the
  only live evidence of the mode (live --help, vibe 2.25.7 (2026-09-24)).
- **The `/skills` browser was not live-exercised.** Registry mechanics
  (pin manifests, `latest` alias, cache dir, precedence, browser bindings)
  are source-verified only (PART-SKILLS section 1.6); import, pin, and
  version-switching flows have no recorded live run.
- **`allowed-tools` enforcement is experimental and unverified live.**
  The key parses; the Agent Skills specification marks it experimental,
  and the oracle records no live verification of its enforcement behavior
  (PART-SKILLS section 1.1). Agent profiles with
  `enabled_tools`/`disabled_tools` overrides are the enforced boundary.
- **2.25.8 skills keys are source-verified only.** `disable-model-
  invocation` and `agents/openai.yaml` metadata are documented in release
  2.25.8 (source), absent from the 2.25.0 installed baseline (PART-SKILLS
  section 1.1).
- **Plugin-shipped agent details live on the plugins page.** The
  `agent_plugins_1_0` document schema (field limits, always-subagent rule)
  is cited in PART-AGENTS section 8; its install and management mechanics
  are not covered by this page's oracle ranges — see
  [Plugins](plugins.md).
- **`/leanstall` install flow.** The lean agent's `install_required`
  gating and the 2.25.8 `vibe/core/agents/install.py` install flow are
  source-verified (PART-AGENTS section 7; PART-DELTAS section 6); the
  `/leanstall` command's live behavior (downloads, prompts, failures) is
  not exercised in the oracle.

## See also

- [Skill design patterns](skill-design-patterns.md) — orchestration
  patterns built on these mechanics
- [Agent harness](agent-harness.md) — where agents and skills sit in the
  session model
- [Architecture](architecture.md) — the session store and subagent model
- [Memory systems](memory-systems.md) — AGENTS.md instruction files
- [Context engineering](context-engineering.md) — budgeting for
  subagent fan-outs
- [Tools reference](tools-reference.md) — per-tool permission resolution
- [Hooks events reference](hooks-events-reference.md) — hook payloads
  carrying `parent_session_id`
- [Settings reference](settings-reference.md) — `config.toml` in full
- [Plugins](plugins.md) — plugin-shipped agents and skills
- [Glossary](glossary.md)
- [Style guide](../style-guide.md)
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md)
