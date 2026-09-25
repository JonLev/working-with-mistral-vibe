---
title: "Module 04: Agents & Specialization"
description: "Learning Path Module 04: build specialized Vibe agents as TOML profiles, restrict their toolsets with config overrides, delegate to subagents with the task tool, and decide when a specialized agent beats the default session. 75-90 min, Practitioner track."
tags: [learning-path, agents, subagents, task-tool, permissions, config]
---

# Module 04: Agents & Specialization

**Time:** ~75-90 min · **Complexity:** ★★★☆☆ · **Track:** Practitioner

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics on this page are cited inline as (PART-XXX) against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md). Anything the
oracle could not verify is in [Known gaps](#known-gaps), never in the body.
Structure and pedagogy are adapted from the source guide; every mechanic is
rebuilt from the oracle.

## TL;DR

- An agent in Vibe is a **profile**, not a prompt file: a safety class plus a
  set of config overrides layered onto the running session above your user
  and project `config.toml` (PART-AGENTS section 8; PART-CONFIG section 2.1).
- Custom agents are TOML files — `~/.vibe/agents/NAME.toml` for you,
  `.vibe/agents/NAME.toml` for a trusted project. The file stem is the agent
  name. Five keys are profile fields; **every other key is a `config.toml`
  override**, so tool restriction is done with `enabled_tools`,
  `disabled_tools`, and `[tools.<tool>]` permission/allowlist/denylist
  (PART-AGENTS section 8; PART-CONFIG section 1.3).
- A role persona is a prompt file referenced by `system_prompt_id`
  (`.vibe/prompts/<id>.md`, then `~/.vibe/prompts/<id>.md`), not free text in
  the TOML (PART-AGENTS section 8).
- `agent_type = "subagent"` makes a profile delegation-only: the `task` tool
  spawns it, depth is capped at 1, and the parent gets a text-only result.
  `explore` is the built-in read-only subagent and the only one auto-allowed
  by default (PART-AGENTS section 9).
- Select a primary agent with `vibe --agent NAME`, `default_agent` in
  `config.toml`, or Shift+Tab cycling (PART-AGENTS section 10).

*Read if you repeat the same kind of task (review, audit, docs) and want a
pinned toolset, persona, and approval behavior for it. Skip if you run
one-off interactive sessions and never delegate — the built-in
`accept-edits` default already covers you.*

## Goal

Create specialized agents for specific tasks, restrict what each one can do,
and learn when a specialized agent or a subagent beats working in the default
session.

## What You'll Learn

- What a Vibe agent is (a profile of config overrides) and which ones ship
  built in
- Writing custom agents as TOML in `.vibe/agents/` or `~/.vibe/agents/`
- Restricting an agent's toolset with overrides — the honest form of sandboxing
- Giving an agent a persona with `system_prompt_id`
- Selecting agents: `--agent`, `default_agent`, Shift+Tab
- Delegating to subagents with the `task` tool, including parallel delegation
- Deciding between a specialized agent, a subagent, and the default session

---

## What Are Agents?

An agent is a **profile**: a safety class plus a set of config overrides that
are applied to the running session as a dedicated layer above user config,
project config, and session overrides (the `AgentProfileLayer`, layer 7 of 8 —
only admin config outranks it) (PART-CONFIG section 2.1; PART-AGENTS
section 8). A specialized agent is therefore the same engine with a different
toolset, a different system prompt, and different permission defaults —
not a different product.

### The built-in agents

| Agent | Safety | What it does | Selectable |
|---|---|---|---|
| `ask` | `neutral` | Requires approval for tool executions | Yes |
| `plan` | `safe` | Read-only agent for exploration and planning; writes only under the plans dir | Yes |
| `accept-edits` | `destructive` | Auto-approves file edits only; the default agent | Yes |
| `auto-approve` | `yolo` | Auto-approves all tool executions | Yes |
| `explore` | `safe` | Read-only subagent for codebase exploration | No — `task` tool only |
| `lean` | `neutral` | Lean 4 code analysis, proof assistance, theorem proving | Yes, once installed (opt-in) |
| `smart-approve` | `smart` | Classifies each tool call, auto-runs the safe ones, prompts for risky ones | **[unified-harness]**, explicit selection, 2.25.8 |

Safety values come from the `AgentSafety` enum: `safe | neutral | destructive |
yolo` (plus `smart` at 2.25.8, Unified Harness only). Safety is a
classification carried on the profile — a **visual hint only**; the actual
tool behavior comes from the profile's overrides (PART-AGENTS section 7).
Every built-in profile disables `exit_plan_mode` (PART-AGENTS section 7).

### Default session vs specialized agent

| Aspect | Default session | Specialized agent |
|---|---|---|
| Scope | General purpose | One role, one job |
| Toolset | Everything your config allows | Whatever the profile enables/disables |
| System prompt | The built-in `cli` prompt | The profile's `system_prompt_id` |
| Permissions | Your `config.toml` defaults | Profile overrides layered on top |
| Invocation | `vibe` | `vibe --agent NAME`, `default_agent`, Shift+Tab |
| Best at | Exploration, novel tasks, conversation | Repeated tasks with clear success criteria |

---

## Custom Agents: TOML, Not Markdown

A custom agent is a `NAME.toml` file. The file stem **is** the agent name —
there is no `name` field. Vibe discovers profiles in this order, first match
by name winning (PART-AGENTS section 8):

1. `agent_paths` entries in `config.toml` (absolute or cwd-relative)
2. `.vibe/agents/` under each **trusted** project root (plus `--add-dir`
   roots; an untrusted cwd contributes nothing)
3. `~/.vibe/agents/` (user)

### The schema

| Key | Required | Meaning |
|---|---|---|
| *(file stem)* | — | The agent name; a stem matching a builtin replaces that builtin (logged) |
| `display_name` | No | Defaults to the stem, title-cased |
| `description` | No | One-line role text |
| `safety` | No | `safe`, `neutral`, `destructive`, or `yolo`; default `neutral`; visual hint only |
| `agent_type` | No | `agent` (default, user-facing) or `subagent` (delegation-only) |
| *any other key* | — | A `config.toml` override: `enabled_tools`, `disabled_tools`, `active_model`, `system_prompt_id`, `[tools.<tool>]` tables, `providers`, `models`, ... |

A definition with invalid override keys fails validation and is **dropped at
discovery with a warning** — a typo does not half-load (PART-AGENTS
section 8).

Restriction is done with the same keys `config.toml` uses (PART-CONFIG
section 1.3; PART-PERMISSIONS section 4):

| Override | Effect |
|---|---|
| `enabled_tools = [...]` | When non-empty, **only** matching tools are active (glob or `re:` patterns) |
| `disabled_tools = [...]` | Applied after `enabled_tools` filtering |
| `[tools.<tool>] permission` | `"ask"` (default), `"always"`, or `"never"` |
| `[tools.<tool>] allowlist` / `denylist` | Bash: command prefixes auto-allowed / auto-denied; file tools: path globs, denylist checked first |

There is no capability allow/deny syntax, no auto-invoke flag, and no
per-agent approval toggle at the verified surface. If a mechanic you remember
from another tool is not in the table above, it does not exist here — build
the behavior from overrides.

### Personas live in prompt files

Give a role its voice with `system_prompt_id`, resolved in this order:
`.vibe/prompts/<id>.md` in project dirs first, then
`~/.vibe/prompts/<id>.md`, then the built-in ids `cli`, `explore`, `tests`,
`lean`, `minimal` (PART-AGENTS section 8). The TOML `instructions` field is
parsed but not consumed by the CLI agent loop — see
[Known gaps](#known-gaps); do not use it as the persona mechanism.

---

## Three Design Patterns

Three runnable profiles, one per recurring role. Each is complete — paste it
into the named file and it loads.

### Pattern 1: Quality Checker

Audits without editing: it runs your commands and reports, but its write
tools are gone.

```toml
# <project>/.vibe/agents/quality-checker.toml
agent_type = "agent"
display_name = "Quality Checker"
description = "Runs the test suite and linters and reports failures; never edits source."
safety = "safe"
disabled_tools = ["write_file", "edit"]

[tools.bash]
permission = "ask"
allowlist = ["git status", "git diff", "pnpm test", "pnpm lint", "pnpm typecheck"]
denylist = ["rm -rf *", "sudo"]
```

Bash allowlist entries are command prefixes — a part is auto-allowed when it
is allowlisted and touches no directory outside the workspace; everything
else asks (PART-CONFIG section 1.3; PART-PERMISSIONS section 4.4). The
`denylist` is checked before the allowlist, so `rm -rf *` stays denied even
if a wider allow were added later.

### Pattern 2: Security Specialist (a subagent)

Delegation-only: the model spawns it through the `task` tool while you keep
working in the parent session.

```toml
# <project>/.vibe/agents/security-audit.toml
agent_type = "subagent"
display_name = "Security Audit"
description = "Read-only subagent that scans for injection risks, auth mistakes, and secret exposure, and returns a severity-ranked report."
safety = "safe"
system_prompt_id = "security-audit"
disabled_tools = ["write_file", "edit", "bash"]
```

The persona, at `<project>/.vibe/prompts/security-audit.md` (resolution order
in PART-AGENTS section 8):

```markdown
You audit code for security defects, nothing else.

Scan for: injection (SQL, command, path traversal), authentication and
authorization mistakes, hardcoded secrets and credentials, unsafe
deserialization.

Report each finding with a severity (CRITICAL / HIGH / MEDIUM / LOW), the
file and line, and the minimal fix. Do not edit files. If you find nothing,
say so plainly rather than padding the report.
```

The `task` tool's permission defaults to `ask` with an allowlist of
`["explore"]` — so the first spawn of `security-audit` prompts you. To
auto-allow it, extend the allowlist (fnmatch patterns over the agent name;
denylist wins) in your `config.toml` or a parent agent's overrides
(PART-AGENTS section 9):

```toml
[tools.task]
allowlist = ["explore", "security-audit"]
```

### Pattern 3: Documentation Writer

Full write access to docs, no shell. A different model and persona are
pinned per role — the point of specialization.

```toml
# <project>/.vibe/agents/doc-writer.toml
agent_type = "agent"
display_name = "Doc Writer"
description = "Rewrites README and API documentation from the current source; proposes edits, runs no commands."
safety = "neutral"
system_prompt_id = "doc-writer"
active_model = "mistral-medium-latest"
disabled_tools = ["bash"]
```

The persona, at `<project>/.vibe/prompts/doc-writer.md`: plain-language
style rules — lead with what the reader must do, show a code example per
feature, no unexplained jargon. Write it as you wrote
`security-audit.md` above.

---

## Selecting and Switching Agents

| Mechanism | Command / key | Notes |
|---|---|---|
| At launch | `vibe --agent NAME` | Validated against discovered and available agents; a subagent name errors (see below) |
| Always | `default_agent = "quality-checker"` in `config.toml` | Default is `accept-edits`; applies in interactive **and** programmatic (`-p`) mode |
| Interactive | Shift+Tab | Cycles `ask → plan → accept-edits → auto-approve → custom agents (sorted by name)`; applied to the running session |
| Combined | `--agent NAME --auto-approve` | Keeps the profile and additionally bypasses tool permission prompts (`--yolo` is the same flag) |

`--agent` and `default_agent` in programmatic mode are live-verified: a
gated command under `--agent ask -p` is cancelled (auto-denied, no user to
ask), while a read-only command still runs (PART-CLI; PART-AGENTS
section 10; PART-CONFIG section 1.5).

Related config keys (PART-CONFIG section 1.5): `agent_paths` (extra search
dirs), `enabled_agents` (when set, **only** matching agents are available;
globs or `re:`), `disabled_agents` (ignored when `enabled_agents` is set),
`installed_agents` (opt-in builtins such as `lean`).

---

## Delegation: the task Tool and Subagents

The `task` tool is the only way to spawn a subagent. Its prompt says:
"Launch a subagent for complex multi-step work. Provide a self-contained
description. The subagent runs read-only and returns a final message —
summarize it to the user yourself." (PART-AGENTS section 9).

| Property | Behavior |
|---|---|
| Args | `task` (required text), `agent` (subagent name, default `"explore"`) |
| Spawnable | Only `agent_type = "subagent"` profiles; a primary agent name raises a tool error |
| Depth | Capped at 1 — a subagent cannot spawn subagents |
| Result | Text-only: `response` (accumulated assistant text), `turns_used`, `completed` |
| Interaction | None — the child runs without user prompts; its tool events surface only as task progress lines |
| Session | Child session is logged under the parent's session dir in `agents/`, named with the agent prefix; resumable |
| Parallelism | Multiple `task` calls in one assistant turn run concurrently — the same rule as any tool calls in a turn |

The built-in `explore` subagent enables only `grep`, `read_file`, and `skill`
with the `explore` system prompt (PART-AGENTS section 7). The read-only
property of a custom subagent comes from **its profile** (the
`disabled_tools` list in `security-audit.toml` above), not from the
mechanism — a custom subagent's toolset is whatever its overrides enable
(PART-AGENTS section 9).

Unified Harness notes: subagents no longer prompt for tool permission when
the parent session is in auto-approve mode (2.25.5), and TOML-defined
subagents from `~/.vibe/agents` or `.vibe/agents` can be spawned again as
of 2.25.8 — both **[unified-harness]** (PART-AGENTS section 9).

---

## When to Use Agents

| Reach for a specialized agent when | Stay in the default session when |
|---|---|
| You do the same task repeatedly (review, audit, docs) | You are exploring or learning the codebase |
| You want a pinned, restricted toolset — a real blast-radius limit | The task is novel and needs the full toolset |
| You want a fixed persona and model per role | You want conversational back-and-forth |
| The task has clear success criteria | You are debugging something that changes shape as you go |
| Reach for a **subagent** specifically when: read-only investigation whose text result the parent summarizes, or several such investigations at once in one turn | You need to interact mid-task — subagents cannot ask you anything |

---

## Exercises

### Exercise 1: Cycle the built-ins

Launch `vibe` in any project and press Shift+Tab repeatedly.

Expected observation: the active mode cycles `ask → plan → accept-edits →
auto-approve` in that fixed order, wrapping around, and the switch applies
to the running session without a restart (PART-AGENTS section 10).

### Exercise 2: Build and use the Quality Checker

```bash
mkdir -p .vibe/agents
cat > .vibe/agents/quality-checker.toml << 'EOF'
agent_type = "agent"
display_name = "Quality Checker"
description = "Runs the test suite and linters and reports failures; never edits source."
safety = "safe"
disabled_tools = ["write_file", "edit"]

[tools.bash]
permission = "ask"
allowlist = ["git status", "git diff", "pnpm test", "pnpm lint", "pnpm typecheck"]
denylist = ["rm -rf *", "sudo"]
EOF
```

Then:

```bash
vibe --agent quality-checker
```

Prompt it: *"Run the test suite and summarize the failures."*

Expected observations:

- Allowlisted commands run without prompts; anything else the agent tries
  asks first (PART-PERMISSIONS section 4.4).
- Ask it to fix a failing test: it cannot — `write_file` and `edit` are
  absent from its toolset (PART-CONFIG section 1.3).
- Press Shift+Tab: your agent now appears in the cycle after `auto-approve`,
  among custom agents sorted by name (PART-AGENTS section 10).

A response in the guide's discipline looks like this:

> Running the suite first, then I'll report each failure with its error.
>
> `pnpm test` finished with 2 failures:
>
> - `validators.test.js` — `formatDate` returns `undefined` for pre-1970
>   dates (3 cases)
> - `api.test.js` — the timeout test failed once, passed on a rerun
>
> The date bug is `getYear()` in `formatDate`; the fix is `getFullYear()`. I
> did not edit the file — this agent's write tools are disabled. The timeout
> failure I could not reproduce, so I would not block on it.

### Exercise 3: Delegate to the Security Audit subagent

Create `security-audit.toml` and `prompts/security-audit.md` from Pattern 2,
then in a normal session prompt:

*"Use the task tool with agent security-audit to scan `src/` for SQL string
concatenation and hardcoded secrets."*

Expected observations:

- The first `task` call prompts for approval — the default allowlist is
  `["explore"]` (PART-AGENTS section 9). Approve once, or add the
  `[tools.task]` allowlist from Pattern 2 and restart.
- The subagent runs without further interaction and returns a text-only
  result; the parent session summarizes it to you (PART-AGENTS section 9).
- The child session is logged under the parent's session directory in
  `agents/` with the `security-audit` prefix (PART-AGENTS section 9).
- Spawn two investigations in one turn ("also scan `config/` for exposed
  env handling") — both `task` calls run concurrently (PART-HOOKS section
  3.6).

### Exercise 4: Probe the guardrails

Run each of these and read the error:

```bash
vibe --agent explore
```

Expected: agent selection refuses the subagent — only `agent_type = "agent"`
profiles can be selected with `--agent` (PART-AGENTS section 8).

Then, inside a session, ask the `security-audit` subagent (through a `task`
call) to delegate part of its work to another subagent.

Expected: a tool error — "Agent depth limit of 1 reached. Complete the task
in the current subagent." (PART-AGENTS section 9).

### Exercise 5: Make it your default

Add to `~/.vibe/config.toml` (or `.vibe/config.toml` in a trusted project):

```toml
default_agent = "quality-checker"
```

Start `vibe` with no flags, then run the same prompt from Exercise 2 through
programmatic mode:

```bash
vibe -p "Run the allowlisted git status and report the result."
```

Expected: the Quality Checker profile is active in both modes —
`default_agent` applies in interactive and programmatic mode alike
(PART-CONFIG section 1.5; PART-CLI live tests).

---

## DO / DON'T

| DO | DON'T |
|---|---|
| Give each agent one narrow purpose with clear output | Create agents with overlapping purposes |
| Restrict the toolset you don't need — `disabled_tools` plus per-tool `permission` | Trust the `safety` field to restrict anything — it is a visual hint only |
| Put the persona in a prompts file via `system_prompt_id` | Put persona text in the TOML `instructions` field — it is not consumed |
| Version-control `.vibe/agents/` and `.vibe/prompts/` with the project | Create an agent for a one-off task — just ask the session |
| Test each agent on a sample task before relying on it | Give an audit agent `bypass_tool_permissions = true` |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Custom agent never appears | File is outside the search path, or the project root is untrusted — project dirs load only under trusted roots | Move it to `.vibe/agents/` in a trusted root or `~/.vibe/agents/`; check `agent_paths` (PART-AGENTS section 8; PART-CONFIG section 2.5) |
| Agent disappeared after an edit | Invalid override keys fail validation and the profile is dropped at discovery with a warning | Check every key against the `config.toml` schema (PART-AGENTS section 8) |
| `vibe --agent <name>` errors "is a subagent" | Expected — subagents are delegation-only | Invoke it through the `task` tool (PART-AGENTS sections 8-9) |
| Every `task` spawn prompts for approval | Default allowlist is `["explore"]` | Add the name under `[tools.task] allowlist` (PART-AGENTS section 9) |
| Your agent replaced a builtin | File stem matches a builtin name | Rename the file, or accept the override — it is logged either way (PART-AGENTS section 8) |

## Validation: You're Ready If

- You have created at least one custom agent TOML and selected it with
  `--agent`
- You can say what the five parsed profile fields are, and why everything
  else in the file is an override
- You can restrict an agent's toolset two ways: remove the tool
  (`disabled_tools`) and gate the calls you keep (`permission`,
  `allowlist`, `denylist`)
- You can explain why `safety` is not a restriction mechanism
- You have spawned a subagent through the `task` tool and seen the parent
  summarize its text-only result
- You know the two hard limits of delegation: subagent-only spawn, depth 1

## Known gaps

- **Live-run note (2026-09-24, vibe 2.25.7):** the first pass of this page
  disabled a `search_replace` tool in its examples; that name was retired by
  the config migration that renamed `search_replace` to `edit`
  (PART-CONFIG section 1.11). The examples now disable `write_file` and
  `edit` only, which was re-verified live: the Quality Checker profile
  loaded, ran its allowlisted `git status`, and both a `write_file` call and
  a shell-based write workaround were denied.

- **The `instructions` TOML field**: parsed and carried on the profile, but
  in the verified core it is consumed only by plugin snapshot machinery, not
  appended to the CLI system prompt. The oracle lists it as needing public
  verification; this module deliberately does not teach it — use
  `system_prompt_id` (PART-AGENTS section 8).
- **Per-tool `allow`/`deny` doc alias**: the vendor docs list the bash keys
  as `allow`/`deny`; the verified code reads `allowlist`/`denylist` only, and
  unknown keys are silently ignored. Flagged for public verification — write
  `allowlist`/`denylist` (PART-CONFIG section 1.3).
- **List merge semantics in agent layers**: `tools` is a deep-merge config
  section, but whether a list field inside an agent's `[tools.*]` table
  merges with or replaces the lower layers' lists is not separately
  verified. The examples in this module list every command they rely on, so
  they hold under either semantics (PART-CONFIG sections 1.3, 2.1).
- **`smart-approve`**: **[unified-harness]**, added at 2.25.8, gated by the
  runtime "classify" tool mode and requiring explicit selection. It is
  documented for release 2.25.8 but was not exercisable against the live
  2.25.0 baseline; treat it as documented-only until you run it yourself
  (PART-AGENTS section 7).
- **Programmatic-mode fallback**: the vendor docs claim `-p` mode "falls
  back to auto-approve" without `--agent`; live tests settle it —
  `default_agent` applies in `-p` mode. Stated per the oracle's live runs,
  not the docs (PART-CLI).

## See also

- [Agents and skills reference](../core/agents-and-skills-reference.md) —
  full built-in profile tables, discovery order, and the `task` tool
  constraints
- [Settings reference](../core/settings-reference.md) — every `config.toml`
  key, the eight-layer precedence stack, and trust gating
- [Agent harness](../core/agent-harness.md) — where agent profiles sit in
  the session model
- [Skill design patterns](../core/skill-design-patterns.md) — reusable
  knowledge modules, the companion specialization mechanism
- [Hooks and events reference](../core/hooks-events-reference.md) —
  turn-level automation around the agents you build here
- [Memory systems](../core/memory-systems.md) — durable conventions via
  `AGENTS.md`, the instruction side of specialization
- [Style guide](../style-guide.md)
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md)
