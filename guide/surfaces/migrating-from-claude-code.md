---
title: "Migrating from Claude Code to Vibe"
description: "Concept-by-concept port of an existing agentic-coding setup to Vibe: which mechanics rename (AGENTS.md, skills, config.toml), which must be re-derived (hooks, headless CI around auto-DENY), and which do not transfer — every row cited to the mechanics oracle."
tags: [guide, surfaces, migration, cli]
---

# Migrating from Claude Code to Vibe

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Every command, flag, config key, and file path here cites the mechanics oracle,
> [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as
> `(PART-XXX)`. Claims marked *live-verified* ran against the installed CLI
> (baseline 2.25.0); the rest are source-verified at release 2.25.8.

This page maps the source tool's mechanics onto Vibe's, concept by concept, and
marks what moves as-is, what must be re-derived, and what does not transfer.

> **TL;DR.** Most of a setup ports by renaming and re-keying: `CLAUDE.md` becomes
> `AGENTS.md`, skills written to the cross-tool `.agents/skills/` convention load
> with little or no change, and settings live in `config.toml` under Vibe's own
> key names (PART-AGENTSMD; PART-SKILLS). Three things do not port mechanically:
> the source tool's much larger hook-event surface becomes three CLI hook events
> plus six unified-harness hook points, so each hook's policy has to be re-derived
> (PART-HOOKS; PART-HOOKS-UNIFIED); headless runs auto-DENY approval-required
> calls instead of auto-approving them, so CI scripts must be designed around that
> (PART-CLI); and plugin agents, LSP servers, output styles, and workflows are
> recorded as unsupported package data, not converted (PART-PLUGINS section 3.6).

**Read if** you have a working setup — instruction files, hooks, skills, subagents,
MCP servers, CI scripts — in the source tool and want the same outcomes on Vibe
with minimum rework. **Skip if** you are starting from nothing; begin at the
[guide index](../README.md) instead.

## How this page was written

This chapter is written from public feature surfaces only: the
[mistralai-vibe repo](https://github.com/mistralai/mistral-vibe) at the released
tag, the installed CLI, docs.mistral.ai, and the
[Agent Plugins 1.0 spec](https://agent-plugins.org) — via the mechanics oracle,
[`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md). Every row
in the mapping table cites the oracle as `(PART-XXX)`; no mechanic here comes from
memory of either product, and mechanics the oracle marks unverified are in
[Known gaps](#known-gaps), never stated as fact. This is the one page where the
source product's terms appear; the guide's naming policy keeps them out of every
other chapter.

## The concept map

| Source concept | Vibe equivalent | Backend | Oracle citation |
|---|---|---|---|
| `CLAUDE.md` instruction files | `AGENTS.md`: user-level `~/.vibe/AGENTS.md` plus the project chain walking up from each open root to its trust root; subdirectory files are injected lazily when a file below them is read; in-prompt hierarchy is project (closer directory wins) over user; files load only for trusted folders | [stable] | PART-AGENTSMD |
| `settings.json` | `config.toml`: `~/.vibe/config.toml` plus project `.vibe/config.toml`, trusted-folder gated; layered defaults → user TOML → project TOML → `VIBE_*` env → session overrides (full stack below). Key names differ — session logging is `[session_logging] enabled`, not `log_interactions` | [stable] | PART-CONFIG sections 1–2; docs-drift ledger item 2 |
| Hook events (the source tool's public hooks reference lists many more than Vibe's three) | `hooks.toml`: `pre_tool` (can rewrite `tool_input`), `post_tool` (replace/append tool output), `post_agent` (deny → retry, max 3 per turn); fail-open unless `strict = true`; `fnmatch` glob or `re:` matchers; plus six typed hook points under the unified harness. The surface is smaller by design — migrate by re-deriving each hook's policy, not by renaming events | [stable] wire protocol; [unified-harness] 6-point API | PART-HOOKS; PART-HOOKS-UNIFIED |
| Slash commands | ~30 built-ins (`/compact` with a swappable prompt via `compaction_prompt_id`, `/resume`, `/config`, `/log`, `/mcp`, `/loop`, `/teleport`, `/remote-project`, `/rewind`, `/retry`, ...) plus user-invocable skills resolving as `/<skill-name>` custom commands | [stable] | PART-COMMANDS; PART-SKILLS section 1.3 |
| Subagents / agent frontmatter | Built-in agents `ask` / `plan` / `accept-edits` / `auto-approve` (plus opt-in `lean`), and the `explore` subagent spawned via the `task` tool; custom agents in TOML (`~/.vibe/agents/NAME.toml`, `.vibe/agents/`); stateful subagents under the unified harness | [stable]; [unified-harness] deltas | PART-AGENTS sections 7–9 |
| Skills | The Agent Skills format: `SKILL.md` with `name`, `description`, `user-invocable`, `allowed-tools` frontmatter; search order `skill_paths` → `.vibe/skills/` → `.agents/skills/` → `~/.vibe/skills/` → `~/.agents/skills/`. Skills written to the cross-tool `.agents/skills/` convention port with little or no change | [stable] | PART-SKILLS sections 1.1–1.2 |
| Plugins | Plugin folders on the [Agent Plugins 1.0 spec](https://agent-plugins.org); import adapters detect the `.claude-plugin/plugin.json` manifest and adapt skills, commands, MCP servers, and hooks; unsupported components are retained as package data, never fatal | [unified-harness] | PART-PLUGINS sections 3.1–3.6 |
| Permission modes | Agent modes: `ask` (approve each call), `plan` (read-only), `accept-edits` (file edits auto-approved; the default agent), `auto-approve` / `--auto-approve` / `--yolo` (all calls); plus the trust system (`trusted_folders.toml`, `--trust`), the file-tool permission chain, and bash allow/denylists | [stable] | PART-PERMISSIONS sections 4.1–4.5; PART-TRUST |
| MCP config | `vibe mcp add` / `vibe mcp remove`; `stdio` / `http` / `streamable-http` transports; OAuth browser login with tokens in the OS keyring, `--api-key-env` static auth for headless; Mistral connectors auto-discovered when a Mistral provider with a resolvable API key is configured | [stable]; connectors [both] | PART-MCP; PART-CONNECTORS |
| Context / compaction | `auto_compact_threshold` (global default 200,000; per-model override wins); `/compact [instructions]` with a custom `compaction_prompt_id`; `@` mentions re-read files every turn — no caching | [both] | PART-SESSIONS sections 4, 6 |
| Computer Use | No equivalent found in the public surface — see [What does not transfer](#what-does-not-transfer) | — | none in the oracle (see [Known gaps](#known-gaps)) |
| Headless / CI | `vibe -p` / `--prompt` with `--max-turns` / `--max-price` / `--max-tokens`, `--output text\|json\|streaming`, `--enabled-tools` / `--disabled-tools` (exact, glob, `re:`). Approval-required calls are auto-DENIED headlessly, not auto-approved — a deliberate difference to design CI around | [stable] | PART-CLI (live verification) |
| Plan Mode | The `plan` agent: write/edit tools hard-disabled except `~/.vibe/plans/*` | [stable] | PART-AGENTS section 7; PART-PERMISSIONS section 4.1 |
| Model selection | Models are configured, not fixed: default `mistral-vibe-cli-latest` (alias `mistral-medium-3-5`), a builtin `devstral` entry on `llamacpp`, plus any `[[models]]` entry; multi-provider `[[providers]]` with `api_style` `openai` / `reasoning` / `anthropic` / `openai-responses` / `vertex-anthropic`. The migration is harness-vs-harness, not model-vs-model: models from other providers run through Vibe | [stable] | PART-CONFIG section 1.1; docs-drift ledger item 6 |
| Worktrees | `--worktree [NAME]`: named form checks out a branch named `NAME`, unnamed form uses `vibe/<name>`; implicitly trusted for the session | [stable] | PART-WORKTREES |
| Automation | `/loop <interval> <prompt>` — idle-fired, persisted across resume — and programmatic `-p` mode; hooks for policy | [both]; `-p` [stable] | PART-SESSIONS section 5; PART-CLI |

## Config layering, exactly

The eight config layers, lowest to highest priority (PART-CONFIG section 2.1):

| # | Layer | Source |
|---|---|---|
| 1 | `DefaultConfigLayer` | schema defaults |
| 2 | `GrowthbookLayer` | experiment-mapped values |
| 3 | `UserConfigLayer` | `~/.vibe/config.toml` (always trusted) |
| 4 | `ProjectConfigLayer` | `./.vibe/config.toml` (only when trusted) |
| 5 | `EnvironmentLayer` | `VIBE_*` env vars |
| 6 | `OverridesLayer` | runtime dict (CLI/session options) |
| 7 | `AgentProfileLayer` | active agent profile overrides |
| 8 | `AdminConfigLayer` | org-enforced config (in-memory) |

Effective order: defaults < GrowthBook < user TOML < project TOML < `VIBE_*` env <
session overrides < agent profile < admin. Any schema key is overridable as
`VIBE_<KEY>`, nested as `VIBE_SECTION__KEY` — e.g. `VIBE_ACTIVE_MODEL=devstral`,
`VIBE_SESSION_LOGGING__ENABLED=false` (PART-CONFIG section 2.2).

When porting keys, watch the docs-drift ledger — these are the cases where
published docs name keys that Vibe does not read:

| Area | Drifted name | Canonical Vibe key | Citation |
|---|---|---|---|
| Session logging | `log_interactions` | `[session_logging] enabled` | docs-drift ledger item 2 |
| Bash allow/deny lists | `[tools.bash] allow` / `deny` | `allowlist` / `denylist` (plus `denylist_standalone`, `sensitive_patterns`) | docs-drift ledger item 1 |
| Programmatic approval | "`-p` falls back to auto-approve" | `--agent` / `default_agent` apply in `-p` mode; approval-required calls are auto-DENIED | docs-drift ledger item 3; PART-CLI (live verification) |

## What does not transfer

1. **No computer-use equivalent.** Nothing in the verified public surface
   documents a Vibe tool for driving a desktop GUI. Say it plainly and stop: a
   workflow that depends on it does not port. No roadmap is asserted either.
2. **Plugin components the import adapters do not convert.** Agents, LSP servers,
   output styles, workflows, and the source tool's `settings.json` are recorded
   as unsupported and retained as package data — never fatal, never converted
   (PART-PLUGINS section 3.6). Plan to rebuild agents as Vibe agent TOML and
   policy as `hooks.toml`.
3. **No 1:1 hook mapping.** The source tool's large hook-event surface has no
   event-by-event equivalent: Vibe has three CLI hook events (`pre_tool`,
   `post_tool`, `post_agent`) plus six typed hook points under the unified
   harness (PART-HOOKS; PART-HOOKS-UNIFIED). Re-derive each hook's policy against
   that smaller surface; do not attempt a rename pass.
4. **Nothing the oracle marks as non-existent gets promised.** Two concrete
   examples: no plugin marketplace or install-registry concept exists in the
   verified source — install means copying plugin folders into
   `~/.vibe/plugins/` or `<project-root>/.vibe/plugins/` (PART-PLUGINS
   section 3.3) — and no first-party CI product ships in the CLI (PART-CLI).

## Port order: move, re-derive, rebuild

**Move first (near-free).**

- Rename `CLAUDE.md` files to `AGENTS.md`; the user-level file goes to
  `~/.vibe/AGENTS.md`, project files stay in the repo. Closer directories
  override more distant ones, and files only load for trusted folders — trust
  the repo or nothing reads them (PART-AGENTSMD; PART-TRUST section 3.5).
- Copy skills into `.agents/skills/` (project) or `~/.agents/skills/` (user);
  both are on the search path. Unknown frontmatter keys are ignored, and the
  skill `name` must match `^[a-z0-9]+(-[a-z0-9]+)*$` (PART-SKILLS
  sections 1.1–1.2).
- Re-key settings into `config.toml`, using the canonical keys above. Start from
  the [Settings Reference](../core/settings-reference.md).

**Re-derive.**

- Hooks: for each source hook, decide which of `pre_tool` (gate and rewrite),
  `post_tool` (annotate or replace output), or `post_agent` (turn-level quality
  gate, deny → retry, max 3) expresses its policy. Anything that must block
  needs `strict = true` — the default is fail-open (PART-HOOKS sections 2–3).
- CI scripts: rewrite assumptions around auto-DENY. In `-p` mode,
  approval-required calls are denied, not approved; what runs headlessly must be
  allowlisted in config, enabled by the selected agent profile, or explicitly
  opted out via `--auto-approve` / `--yolo` (PART-CLI; PART-PERMISSIONS
  section 4.4). Note `git commit` is not in the default bash allowlist — add it
  to `[tools.bash] allowlist` or the job cannot commit (PART-PERMISSIONS
  section 4.4).

**Rebuild.**

- Agents: port each one as a TOML profile — file stem is the agent name, any
  `config.toml` key is a valid override, and `agent_type = "subagent"` makes it
  spawnable only through the `task` tool (PART-AGENTS sections 8–9). Put
  operative content in a `system_prompt_id` prompt and overrides, not in
  `instructions` (see [Known gaps](#known-gaps)).
- Plugin unsupported components: agents, LSP servers, output styles, and
  workflows stay as package data; nothing else happens to them until you rebuild
  each one natively (PART-PLUGINS section 3.6).

## Version pinning

The mapping is against CLI release 2.25.8 (documented surface, tag `v2.25.8`,
PyPI 2026-09-23) with the live baseline at 2.25.0 — mechanics marked live-verified
ran on the installed build; 2.25.8-only additions are documented in release
2.25.8 (source), not live-verified (PART-DELTAS). The plugin surface — including
the foreign-format import adapters — is [unified-harness]: it requires
`--experimental-harness` and the `mistralai_vibe_local_harness` package, and the
flag is suppressed from `--help` when that package is absent (PART-PLUGINS;
oracle Backend tags).

## Known gaps

- **No computer-use equivalent** exists in the verified public surface; the
  oracle documents neither a tool nor a roadmap for one. This gap is the reason
  the concept-map row reads "no equivalent found".
- **The import adapters are not live-exercised.** Plugin mechanics are
  [unified-harness] and the harness package was not installed on the live
  baseline, so adapter behavior (skills, commands, MCP servers, hooks adapted;
  unsupported components retained) rests on public source only (PART-PLUGINS
  sections 3.2, 3.6; oracle Backend tags).
- **`instructions` in a custom agent TOML is parsed but not verified to reach
  the model** — in the 2.25.0 CLI core it is consumed only by the plugin
  snapshot path (PART-AGENTS section 8; oracle "Needs public verification").
  Put operative content in `system_prompt_id` prompts and config overrides.
- **The `smart-approve` agent (release 2.25.8, [unified-harness])** classifies
  tool calls to auto-run safe ones, but the classifier wiring lives in the
  private harness package; only the agent definition and changelog are public
  (PART-AGENTS section 7 deltas; oracle "Needs public verification"). Do not
  design a migration around it yet.

## See also

- [Vibe CLI](cli.md), [Vibe Code Desktop](desktop.md), and
  [Vibe Code Web](web.md) — the surface chapters for each client
- [Settings Reference](../core/settings-reference.md) — every `config.toml`
  key and layer
- [Hooks and Events Reference](../core/hooks-events-reference.md) — the three
  CLI hook events and six unified-harness hook points in depth
- [Agents and Skills Reference](../core/agents-and-skills-reference.md) —
  agent TOML, the `task` tool, and the skills search order
- [Plugins](../core/plugins.md) — the Agent Plugins 1.0 surface and import
  adapters
- [Automation](../ops/automation.md) — headless `-p` runs and `/loop`, including
  the auto-DENY posture
- [Production Safety](../security/production-safety.md) — `strict` hooks and
  deny rules for guardrails that must block
- The mechanics oracle:
  [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md)
