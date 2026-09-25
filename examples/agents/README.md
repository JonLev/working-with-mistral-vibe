# Agent Profiles

Installable agent profiles for the Vibe CLI. Fifteen roles adapted from a public agent-template guide (structure and pedagogy adapted under CC BY-SA; mechanics rebuilt for Vibe and verified against the mechanics oracle). Each role is two files:

- `<name>.toml` — the agent profile: type, safety, tool overrides, model
- `prompts/<name>.md` — the role prompt the profile selects

## Install

Copy the profiles into a directory Vibe discovers, and the prompts where the profile can resolve them:

| Scope | Profiles | Prompts |
|---|---|---|
| Project (this repo only) | `.vibe/agents/<name>.toml` | `.vibe/prompts/<name>.md` |
| User (every project) | `~/.vibe/agents/<name>.toml` | `~/.vibe/prompts/<name>.md` |

```bash
# Project scope, from your repo root
mkdir -p .vibe/agents .vibe/prompts
cp examples/agents/*.toml .vibe/agents/
cp examples/agents/prompts/*.md .vibe/prompts/
```

The agent name is the TOML file stem — `code-reviewer.toml` becomes the agent `code-reviewer`. Project scope requires the project root to be trusted: untrusted roots get their `.vibe/` configuration (agents, prompts, config) ignored entirely, and the trust prompt offers to trust the repo or the directory. For non-interactive automation, `vibe --trust` grants trust for that invocation only.

Prompt resolution order: `.vibe/prompts/<id>.md` in project dirs first, then `~/.vibe/prompts/<id>.md`, then the built-in ids (`cli`, `explore`, `tests`, `lean`, `minimal`). So a project prompt with the same stem as a user prompt wins.

## Why the roles live in prompt files

The agent TOML has an `instructions` field, and the CLI parses it — but the agent loop does not consume it as part of the system prompt. Role guidance placed there would be silently dropped. So every profile sets `system_prompt_id = "<name>"` and the role text lives in `prompts/<name>.md`, which the CLI loads as the session's base prompt (the universal system prompt with tool and skill context is still rendered around it). Needs verification on your install: this is documented for the 2.25.0 line and could change in later releases.

## Selection

| How | Notes |
|---|---|
| `vibe --agent <name>` | At launch, for `agent_type = "agent"` profiles. Subagents cannot be selected this way — the CLI rejects them by design. |
| `default_agent = "<name>"` in `config.toml` | Applies in interactive and `-p` programmatic mode. Default is `accept-edits`. |
| Shift+Tab | Cycles `ask` → `plan` → `accept-edits` → `auto-approve` → custom primary agents, sorted by name. |

A profile whose file stem equals a built-in (`ask`, `plan`, `accept-edits`, `auto-approve`, `explore`) overrides that built-in.

## Delegation

`agent_type = "subagent"` profiles are delegation-only: the model spawns them with the `task` tool, they run without user interaction, and they return a text-only final message that the parent summarizes. The mechanics, all verified:

- Only `subagent` profiles can be spawned; requesting a primary agent raises a tool error.
- Depth limit is 1 — a subagent cannot spawn another subagent.
- Results are text-only; no message objects or files cross back.
- The `task` tool asks for approval unless the agent is allowlisted. The default allowlist is `["explore"]`, so every profile here needs either a one-time approval or an entry in your config:

```toml
[tools.task]
allowlist = ["explore", "code-reviewer", "security-auditor"]
```

- Vibe ships one built-in subagent, `explore` (read-only: `grep`, `read_file`, `skill`). The read-only reviewers here follow the same pattern but with their own role prompts.

In practice: name the subagent explicitly in the delegation, e.g. *"Use the task tool with agent `code-reviewer` to review the diff in src/api/."* Don't rely on the model picking a subagent on its own.

Backend caveat, live-verified on vibe 2.25.7: on the legacy backend, a trusted project's custom subagents spawn and report normally (verified end to end with `code-reviewer` reviewing a file with a planted SQL injection). On the Unified Harness backend of the same version, the `task` tool did not see the custom subagent and reported "agent type isn't registered", falling back to the built-in general subagent — the release notes fix custom-subagent spawning on the Unified Harness in 2.25.8. If delegation to these profiles silently falls back, check which backend your install runs (`--legacy-harness` forces the legacy one) and its version.

## The catalog

| Profile | Type | Safety | Model | Role |
|---|---|---|---|---|
| [adr-writer.toml](./adr-writer.toml) | agent | safe | default | Detect and draft Architecture Decision Records; prints them for you to save |
| [architecture-reviewer.toml](./architecture-reviewer.toml) | subagent | safe | default | Structural review of a plan or change set; reports blockers and concerns |
| [code-reviewer.toml](./code-reviewer.toml) | subagent | safe | default | Line-level review with OWASP, defensive-code audit, severity classification |
| [devops-sre.toml](./devops-sre.toml) | agent | neutral | default | FIRE-framework incident response; destructive commands hard-denied |
| [implementer.toml](./implementer.toml) | agent | neutral | local | Mechanical execution of a fully specified, bounded task |
| [integration-reviewer.toml](./integration-reviewer.toml) | subagent | safe | default | Catches "builds but doesn't connect": ports, env vars, library APIs |
| [loop-monitor.toml](./loop-monitor.toml) | agent | safe | local | Status line per check on a long-running session's log |
| [output-evaluator.toml](./output-evaluator.toml) | subagent | safe | local | LLM-as-a-judge verdict: APPROVE / NEEDS_REVIEW / REJECT with scores |
| [plan-challenger.toml](./plan-challenger.toml) | subagent | safe | default | Adversarial plan review with a refutation pass |
| [planner.toml](./planner.toml) | agent | safe | default | Read-only decomposition; emits the plan in the response |
| [planning-coordinator.toml](./planning-coordinator.toml) | subagent | safe | default | Synthesizes specialist reports into one dependency-ordered plan |
| [refactoring-specialist.toml](./refactoring-specialist.toml) | agent | neutral | default | Behavior-preserving refactoring in small, test-verified steps |
| [security-auditor.toml](./security-auditor.toml) | subagent | safe | default | OWASP Top 10 audit; reports severity-classified findings |
| [security-patcher.toml](./security-patcher.toml) | agent | neutral | default | Patches auditor findings one at a time, after explicit confirmation |
| [test-writer.toml](./test-writer.toml) | agent | neutral | default | Behavior-focused tests in the project's existing framework |

### The read-only pattern

The reviewers (`code-reviewer`, `architecture-reviewer`, `integration-reviewer`, `security-auditor`, `output-evaluator`, `plan-challenger`), plus `planner`, `adr-writer`, `planning-coordinator`, and `loop-monitor`, report instead of fixing. Their profiles enforce that with three overrides — the tool allowlist does the work, and the permission blocks are the backstop:

```toml
enabled_tools = ["read_file", "grep", "bash"]

[tools.write_file]
permission = "never"

[tools.edit]
permission = "never"
```

`safety = "safe"` is also set on these, but treat it as a visual hint in the UI, not an enforcement mechanism — the tool configuration is what actually blocks writes.

### The denylist pattern

`devops-sre` encodes its "never run destructive commands" rule as a bash denylist. Denylist entries are command prefixes that are auto-denied outright — no approval prompt can override them:

```toml
[tools.bash]
denylist = [
  "kubectl delete",
  "kubectl scale",
  "terraform destroy",
  "rm -rf",
]
```

Everything else the role proposes still goes through the normal approval gate (`safety = "neutral"`, default `ask` permission).

## Frontmatter mapping

The source templates were single markdown files with YAML frontmatter. Vibe profiles are TOML, and the keys don't map one-to-one:

| Source key | Vibe equivalent | Notes |
|---|---|---|
| `name` | file stem | `<name>.toml` in `.vibe/agents/` or `~/.vibe/agents/` |
| `description` | `description` | One line; for subagents this is what you delegate against |
| `model: opus/sonnet/haiku` | `active_model` | Only verified aliases: `mistral-medium-3-5` (the default), `local`. Omit the key to use the default. Profiles here omit it except where a cheap tier genuinely fits. |
| `tools: Read, Grep, ...` | `enabled_tools` | Vibe tool names: `read_file`, `write_file`, `edit`, `grep`, `bash`, `task`, `skill`, `web_fetch`, `web_search`, `todo`, `ask_user_question` |
| role body | `prompts/<name>.md` via `system_prompt_id` | The `instructions` TOML field is parsed but not consumed by the agent loop |
| — | `agent_type` | `agent` (user-facing) or `subagent` (delegation-only, via the `task` tool) |
| — | `safety` | `safe` / `neutral` / `destructive` / `yolo` — visual hint only |
| — | `[tools.<tool>]` | Any per-tool config key: `permission` (`ask`/`always`/`never`), `allowlist`, `denylist` |
| `capabilities: NO: ...` | no equivalent | Use `enabled_tools` / `disabled_tools` and per-tool permissions |
| `auto_invoke`, `requires_approval` | no equivalent | Approval is governed by `safety`, per-tool permissions, and allowlists |

Any config.toml key is valid in an agent TOML as a profile-scoped override — `active_model`, `allowed_models`, `enabled_tools`, `[tools.*]`, and the rest.

## Models

Two aliases are verified against the oracle:

- Omitting `active_model` uses the session default, `mistral-medium-3-5`.
- `active_model = "local"` is devstral on the builtin llamacpp provider (`http://127.0.0.1:8080/v1`). It needs a local server running; if you don't run one, delete the `active_model` line from `implementer.toml`, `loop-monitor.toml`, and `output-evaluator.toml` and they fall back to the default model.

The source guide's three-tier model ladder (heavy/medium/cheap) doesn't exist in Vibe; the profiles here express it as: everything runs the default model, and the high-frequency or mechanical roles optionally run the local devstral alias.

## Known gaps

- The source's slash-command pipelines (`/plan-validate`, `/plan-start` and friends) have no Vibe equivalent; the reviewers here are delegated directly via the `task` tool instead.
- The source ran reviewers as spawned subagents with an elaborate orchestration layer; Vibe's depth limit of 1 means a subagent cannot itself delegate. Chain reviews from a primary agent, not from each other.
- Subagent descriptions are not advertised to the model in the 2.25.0 line the way the source assumed; name the agent explicitly when delegating.
- On the Unified Harness backend before 2.25.8, custom subagents from `.vibe/agents/` are not spawnable via the `task` tool (live-verified on 2.25.7: the tool reports the agent as not registered and falls back). The profiles themselves load and validate on both backends; only delegation is affected.
