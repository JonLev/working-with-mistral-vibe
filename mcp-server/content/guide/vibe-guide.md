---
title: "Working with Mistral AI Vibe"
description: "The monolith spine of the guide: twelve chapters routing every topic to its deep-dive page, with generated per-page digests. Delegation only - every mechanic lives in the page it links to"
tags: [guide, monolith, index]
---

# Working with Mistral AI Vibe

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
> Mechanics cite the oracle, [`verified-mechanics.md`](../docs/mechanics/verified-mechanics.md), as `(PART-XXX)`.

This is a community guide, not official Mistral documentation. Every
mechanic it routes to is verified against the public CLI surface and cited
against the mechanics oracle; use it critically. Structure and pedagogy are
adapted from Florian Bruniaux's community guide with attribution and
share-alike recorded in [`NOTICE.md`](../NOTICE.md).

> **TL;DR.** This page is the map, not the territory: twelve chapters
> route every topic to the deep-dive page that owns it, one paragraph of
> spine prose per chapter and a generated digest per page. If you want a
> mechanic, follow the link; if you want the whole guide condensed to
> tables, that is the [cheatsheet](cheatsheet.md).

**Read if** you are new to the guide and want the tour before choosing a
path. **Skip if** you already know what you need — the [guide index](README.md)
lists every page flat, and the [cheatsheet](cheatsheet.md) answers daily
lookup questions faster than this spine.

The spine is generated (`scripts/generate-monolith.py`, spec in
`scripts/monolith.yaml`) and never edited by hand; a paragraph that
exists in a deep-dive page must not exist here, and the generator
enforces it by never copying page prose — per-page entries are built
from frontmatter and the first sentence of each page's TL;DR.

## Contents

1. [Quick Start](#1-quick-start)
2. [Core Concepts: the Loop, Context, and the Harness](#2-core-concepts-the-loop-context-and-the-harness)
3. [Memory and Configuration](#3-memory-and-configuration)
4. [Agents and Specialization](#4-agents-and-specialization)
5. [Skills](#5-skills)
6. [Sessions, Context, and Daily Commands](#6-sessions-context-and-daily-commands)
7. [Hooks: Programmable Guardrails](#7-hooks-programmable-guardrails)
8. [MCP, Connectors, and Plugins](#8-mcp-connectors-and-plugins)
9. [Security and Production](#9-security-and-production)
10. [Operations, Teams, and Adoption](#10-operations-teams-and-adoption)
11. [Workflows and Methodologies](#11-workflows-and-methodologies)
12. [The Surfaces: CLI, Desktop, and Web](#12-the-surfaces-cli-desktop-and-web)

Appendices:

- [Appendix A — Glossary](#appendix-a--glossary)
- [Appendix B — Cheatsheet](#appendix-b--cheatsheet)
- [Appendix C — Diagrams](#appendix-c--diagrams)
- [Appendix D — Quiz](#appendix-d--quiz)
- [Appendix E — Machine-Readable Index and the MCP Server](#appendix-e--machine-readable-index-and-the-mcp-server)
- [Appendix F — Vibe Releases and Guide Re-verification](#appendix-f--vibe-releases-and-guide-re-verification)
- [Appendix F — Translations and Language Adaptations](#appendix-f--translations-and-language-adaptations)

## 1. Quick Start

Vibe is usable in minutes: run the setup once, answer the folder-trust prompt, and start a session in a real repository (PART-CLI; PART-TRUST section 3.2). This chapter routes installation, first run, and the diff-review habit — and points at the adoption page when the question is how a team should start rather than how the tool installs.

> **TL;DR.** Install, trust the folder, run one real task before configuring anything. Configuration earns its place through friction, not ambition: start with a minimal `AGENTS.md` and add only what you observe you need.

- **Full coverage → [Learning Path](learning-path/README.md)** — Entry page for the seven-module Vibe CLI learning path: module table, four learner tracks, checklist-only validation, product-surface routing, companions, time estimates, outcomes, and FAQ. TL;DR opens: "Seven modules take you from first run to multi-agent orchestration: installation and trust, the core loop, memory and config, agents, skills, hooks, advanced patterns — 465–540 minutes of focused module time. - Validation is **checklist-only**: the CLI ships exactly two builtin skills (`vibe`, `skill-creator`) and no quiz or self-assessment command (PART-SKILLS §1.5; PART-COMMANDS §2)."
- **Full coverage → [Module 01 — Installation and First Run](learning-path/01-installation.md)** — Install the Vibe CLI from the official channel, set up your API key, answer the folder-trust prompt, run your first session, and build the diff-review habit against the accept-edits default. TL;DR opens: "Install the Vibe CLI from the official channel: the script at `https://mistral.ai/vibe/install.sh`, which runs `uv tool install mistral-vibe` (PyPI package `mistral-vibe`, latest release 2.25.8)."

## 2. Core Concepts: the Loop, Context, and the Harness

Everything else in this guide assumes one mental model: the Vibe CLI is a runtime harness around a single loop — send context to the model, execute the tool calls it returns, feed the results back (PART-CLI; PART-SESSIONS). The three deep dives here are the theory layer: how the harness is built, how context is engineered inside it, and how to evaluate the model-harness pair rather than the model alone.

> **TL;DR.** One loop, a small verified tool surface, a tunable compaction trigger instead of a fixed context window, and a permission chain you control — that is the whole model. Each deep dive gives one of those its full chapter.

- **Full coverage → [How the Vibe CLI Works: Architecture and Internals](core/architecture.md)** — The Vibe CLI's verified internals: the agent loop and its seams, the tool surface, the tunable compaction trigger, depth-1 sub-agents, the permission and trust model, session persistence, extension surfaces, and the two session backends. TL;DR opens: "The Vibe CLI is a runtime harness around one loop: send context to the model, execute the tool calls it returns, feed results back, repeat until it answers in text."
- **Full coverage → [Context Engineering](core/context-engineering.md)** — Filling the context window with the right information at the right time in Vibe: the AGENTS.md instruction hierarchy, config.toml layering, budget math, compaction, modular architecture, team assembly, audits, and reduction techniques. TL;DR opens: "Context engineering is the discipline of filling the context window with the right information at the right time."
- **Full coverage → [Agent Harness Engineering](core/agent-harness.md)** — The runtime harness as an engineering discipline: the four-layer taxonomy, nine components, the lethal-trifecta security model, CI/CD and verification patterns, and a concrete Vibe CLI checkpoint. TL;DR opens: "A raw LLM is not an agent; it becomes one when a harness supplies the loop, context, tools, state, permissions, and verification around it."

## 3. Memory and Configuration

Durable context in Vibe lives in two files: `AGENTS.md` carries instructions to the agent, `config.toml` carries settings for the harness (PART-AGENTSMD; PART-CONFIG). Both layer user scope against project scope, both are gated by folder trust, and both punish padding — the strongest evidence favors small, human-written instruction files.

> **TL;DR.** Write instructions by hand, keep them minimal, and put each one at the scope where it applies; configure the harness in `config.toml` and remember that project beats user. The reference pages document every verified key and the full precedence stack.

- **Full coverage → [Memory Systems](core/memory-systems.md)** — Durable memory in Vibe: the AGENTS.md instruction hierarchy, the session store, hook-driven cross-session writes, team sharing, multi-agent coordination, architecture patterns, risks, and decision frameworks. TL;DR opens: "Memory in Vibe splits into three tracks: the **native stack** (the AGENTS.md instruction hierarchy plus the on-disk session store), **cross-session tooling** you wire yourself (a `post_agent` hook appending durable notes, or a third-party MCP memory server), and **team sharing** (a checked-in `AGENTS.md` as the shared layer). - Vibe has no automatic memory extraction."
- **Full coverage → [Settings Reference](core/settings-reference.md)** — Every config.toml key the verified surface covers — models and providers, voice, tools, MCP servers, agents, skills, connectors, telemetry, session logging, top-level scalars — plus the eight-layer precedence stack, VIBE_* environment overrides, trusted-folder gating, and config migrations. TL;DR opens: "Two TOML scopes exist: user `~/.vibe/config.toml` (always loaded) and project `.vibe/config.toml` (loaded only when the discovered file's parent directory is trusted)."
- **Full coverage → [Module 03 — Memory and Config](learning-path/03-memory.md)** — Learning-path module 03 (Beginner track): durable instructions in Vibe — the AGENTS.md hierarchy and the trust gate, config.toml and its eight-layer stack, model and compaction keys, and full system-prompt replacement, with five hands-on exercises. TL;DR opens: "Vibe has no memory subsystem to switch on and nothing to configure into existence."

## 4. Agents and Specialization

Specialization in Vibe is a TOML file: an agent profile restricts tools and injects a prompt, the `task` tool delegates work to a subagent with isolated context, and the built-in profiles cover the common postures from read-only to auto-approve (PART-AGENTS; PART-PERMISSIONS section 4.1).

> **TL;DR.** Delegate the second repetitive task, not the first: extract an agent profile when a pattern repeats, restrict its tools to what it needs, and let the depth-1 `task` fork keep search noise out of your main context.

- **Full coverage → [Agents and Skills Reference](core/agents-and-skills-reference.md)** — The complete mechanics of Vibe agents and skills: built-in agent profiles, custom agent TOML, the task tool, SKILL.md frontmatter, skill discovery, and the skills registry. TL;DR opens: "Vibe ships with six built-in agents in the 2.25.0 core — `ask`, `plan`, `accept-edits`, `auto-approve`, the `explore` subagent, and the opt-in `lean` agent — plus `smart-approve` at 2.25.8, Unified Harness only."
- **Full coverage → [Module 04: Agents & Specialization](learning-path/04-agents.md)** — Learning Path Module 04: build specialized Vibe agents as TOML profiles, restrict their toolsets with config overrides, delegate to subagents with the task tool, and decide when a specialized agent beats the default session. 75-90 min, Practitioner track. TL;DR opens: "An agent in Vibe is a **profile**, not a prompt file: a safety class plus a set of config overrides layered onto the running session above your user and project `config.toml` (PART-AGENTS section 8; PART-CONFIG section 2.1). - Custom agents are TOML files — `~/.vibe/agents/NAME.toml` for you, `.vibe/agents/NAME.toml` for a trusted project."

## 5. Skills

A skill is a folder with a `SKILL.md`: a description the model uses for routing, instructions it loads on demand, and optional scripts and assets (PART-SKILLS). Skills are how you encode a repeatable practice once and let the agent find it again on its own.

> **TL;DR.** Write the description as a routing rule, keep the body lean, and evaluate a skill like any other change. The deep dives cover the frontmatter schema, nine architecture patterns, and the discovery order.

- **Full coverage → [Skill Design Patterns](core/skill-design-patterns.md)** — Nine architecture patterns for Vibe skills: ground-truth injection, skill-body reference paths, detection-only scope, handler dispatch, versioned subdirectories, two-tier standards, committed plans, runtime prompt logging, and adaptive unified/parallel evaluation. TL;DR opens: "A skill is a directory containing a `SKILL.md`."
- **Full coverage → [Module 05 — Skills](learning-path/05-skills.md)** — Learning-path module 05 (Practitioner track): build scoped Vibe skills — the SKILL.md frontmatter schema, description-as-routing-rule with anti-triggers, discovery order and trust gating, invocation control, progressive disclosure via the skill tool, manual evaluation with programmatic mode, and retirement. TL;DR opens: "A **skill** is a directory containing a `SKILL.md` file: YAML frontmatter plus a Markdown body, with optional `scripts/`, `references/`, and `assets/` support directories."

## 6. Sessions, Context, and Daily Commands

Sessions are the unit of work: the compaction trigger keeps a session inside its context budget, the session store persists it for `/resume`, and the slash-command surface inspects and controls all of it (PART-SESSIONS section 4.1; PART-COMMANDS section 2).

> **TL;DR.** Watch context with `/status`, summarize with `/compact`, start clean with `/clear`, and treat one task per session as the default. The lifecycle protocol keeps long-running work inspectable and resumable.

- **Full coverage → [Module 02 — The Core Loop](learning-path/02-core-loop.md)** — How Vibe works turn by turn: the seven-step loop, intelligent scope, compaction, agents and thinking levels, the WHAT/WHERE/HOW/VERIFY request framework, and session rewind and resume. TL;DR opens: "Every turn runs the same seven-step loop: you prompt, the agent reads (`grep`, `read_file`), analyzes, decides, proposes, you review, changes land on disk."
- **Full coverage → [Task Management Across Sessions](workflows/task-management.md)** — Multi-session work in Vibe: resume mechanics, a file-based task-tracking convention, the session lifecycle protocol, and the progress-file continuity artifact, rebuilt on verified mechanics. TL;DR opens: "Resuming conversations is native: `vibe -c` continues from the per-terminal last-session pointer (else the latest session in the current directory); `vibe --resume <id>` resolves globally and accepts partial IDs; the `/resume` picker lists and deletes sessions (PART-SESSIONS section 3). - Sessions persist as `meta.json` plus `messages.jsonl` under `~/.vibe/logs/session/<prefix>_<date>_<shortid>/`, are scoped to their origin directory, and require `[session_logging] enabled` (default `true`) to resume at all (PART-SESSIONS section 3; PART-CONFIG section 1.9). - Task tracking is a **file-based convention**: task files checked into the repo, plus AGENTS.md rules telling the agent how to read and update them (PART-AGENTSMD)."
- **Full coverage → [Session Observability: Logs, Resume, Audit, and Cost](ops/observability.md)** — What the Vibe CLI records by itself (session store, harness log, OTel), how to find and resume sessions, how to add a hook-based activity logger, and how to read the logs for quality and cost. TL;DR opens: "Vibe writes a session store under `$VIBE_HOME/logs/session/` — one directory per session with a fully documented `meta.json` and a `messages.jsonl` transcript — plus a harness log at `$VIBE_HOME/logs/vibe.log` and an optional OpenTelemetry export."

## 7. Hooks: Programmable Guardrails

Hooks are guard programs: three events in `hooks.toml` — `pre_tool`, `post_tool`, `post_agent` — receive a JSON payload on stdin and answer with a decision object on stdout (PART-HOOKS). They fail open unless a table sets `strict = true`; the unified harness adds its own typed points (PART-HOOKS-UNIFIED).

> **TL;DR.** Warn by default, enforce with `strict = true` only where a wrong call has real blast radius, and test a deny guard against fixtures before you trust it live.

- **Full coverage → [Hooks and Events Reference](core/hooks-events-reference.md)** — The hooks.toml wire protocol: three CLI event types, the stdin/stdout decision contract, matcher syntax, fail-open vs strict, post_agent retries, and the unified-harness six-point hook surface. TL;DR opens: "There are exactly three `hooks.toml` event types: `pre_tool`, `post_tool`, `post_agent` (PART-HOOKS section 1)."
- **Full coverage → [Module 06: Hooks and Events](learning-path/06-hooks.md)** — Learning Path Module 06: register Vibe hooks in hooks.toml, make tool decisions with stdout JSON from pre_tool, post_tool, and post_agent hooks, choose a failure posture with strict, and test a deny guard with three fixtures before running it live. ~75 min, Practitioner track. TL;DR opens: "A Vibe hook is a shell command registered in a `hooks.toml` file, not a prompt file or a config key."

## 8. MCP, Connectors, and Plugins

Everything outside the process boundary arrives through extension surfaces: MCP servers registered with `vibe mcp add` or `[[mcp_servers]]`, Mistral connectors auto-discovered on a Mistral provider, and plugin packages built on the public Agent Plugins 1.0 spec, with import adapters for foreign formats (PART-MCP; PART-CONNECTORS; PART-PLUGINS).

> **TL;DR.** Add servers deliberately, vet what they can reach, and remember connectors arrive enabled by default under the unified harness. The deep dives cover the config surface, the plugin model, and the per-tool permission chain that governs all of it.

- **Full coverage → [Plugins](core/plugins.md)** — The Vibe plugin system: Agent Plugins 1.0 packages and manifest rules, the ai.mistral.vibe client extension (runtime hooks, knowledge, agents, libraries, connectors), on-disk scopes, failure semantics, the /plugins commands, and foreign-format import adapters. TL;DR opens: "A plugin is a directory containing a `plugin.json` manifest conforming to the Agent Plugins 1.0 spec: a closed top-level field set, `$schema` fixed to `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`, and a `name` matching `^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$` with no `--`/`..` (spec sections 5.2, 5.5; PART-PLUGINS sections 3.1, 3.2). - v1 defines exactly two portable component types: skills at `skills/<dir>/SKILL.md` and MCP servers at a root `mcp.json`."
- **Full coverage → [Tools Reference](core/tools-reference.md)** — Every built-in Vibe tool: one-line catalog, enable/disable syntax, per-call permission resolution, per-tool parameters and config defaults, and MCP/connector proxy naming. TL;DR opens: "The installed 2.25.7 package ships 26 built-in tool names across eight families: 3 file tools, 3 foreground shell tools, 12 managed-shell session tools (flag-gated), 1 search tool, and 7 others (`task`, `skill`, `ask_user_question`, `exit_plan_mode`, `todo`, `web_fetch`, `web_search`) (installed-package schema dump, vibe 2.25.7 (2026-09-24)). - Read-only and interactive tools default to `permission = "always"` (`read_file`, `grep`, `skill`, `ask_user_question`, `exit_plan_mode`, `todo`, the session readers); mutating tools default to `"ask"` (`write_file`, `edit`, the shell tools, `task`, `web_fetch`, `web_search`) (installed-package schema dump, vibe 2.25.7 (2026-09-24)). - `--enabled-tools` / `--disabled-tools` take exact names, globs (`bash*`), or `re:` regex, and are repeatable; in programmatic mode (`-p`), `--enabled-tools` is exclusive — it disables all other tools."

## 9. Security and Production

The security model composes three verified gates — folder trust, the permission chain, and hooks — plus the operational rules for pointing the tool at production systems (PART-TRUST; PART-PERMISSIONS; PART-HOOKS). The deep dives here are the threat model and hardening guide, the production safety rules, and the data-privacy inventory of what leaves the machine.

> **TL;DR.** Trust is the root permission: an untrusted folder runs without project config, and a declined trust prompt is a deny, not a fallback. From there: restrict tools, guard the risky calls with strict hooks, bound headless runs with budgets, and know your egress.

- **Full coverage → [Security Hardening for Agentic Coding with Vibe](security/security-hardening.md)** — Threat taxonomy for the Vibe CLI: injected-instruction sources, MCP and skills supply chain, the enforcement layer of config permissions and hooks, DIY container isolation, response playbooks, kill switch, and tiered governance — every mechanic rebuilt from the verified oracle. TL;DR opens: "An agentic coding tool runs with your privilege level: anything you can do, the agent can do."
- **Full coverage → [Production Safety Rules](security/production-safety.md)** — Six non-negotiable rules for teams running Vibe against production systems, each enforced through verified mechanics: config deny rules, strict hooks, AGENTS.md policy, and headless CI bounds. TL;DR opens: "Six rules — port stability, database safety, feature completeness, infrastructure lock, dependency safety, pattern following — each enforceable through three verified layers: `[tools.*]` deny rules in project `.vibe/config.toml` (deterministic, checked first), `strict = true` hooks in `.vibe/hooks.toml` (your logic, fail-closed), and `AGENTS.md` policy (model-followed, not a gate)."
- **Full coverage → [Data Privacy in Vibe: What Leaves Your Machine](security/data-privacy.md)** — The verified egress inventory for Vibe — model traffic, telemetry, the experiment layer, the skills registry, the connectors gateway, teleport — the risks that survive any retention policy, the in-product privacy controls, and a canary-based audit checklist. Retention and training terms are marked unverified and delegated to /data-retention. TL;DR opens: "Every file Vibe reads, every command it runs, and every tool result it collects is sent as model context to the active provider's `api_base` — `https://api.mistral.ai/v1` by default (PART-CONFIG §1.1)."

## 10. Operations, Teams, and Adoption

Once individuals use the tool, the questions become organizational: what to measure, how to attribute AI-assisted changes, how to automate recurring runs, and how to roll the practice out to a team. These pages cover the observability surfaces, the traceability policy, the metrics frameworks, automation with budgets, role-by-role guidance, and the adoption decision framework.

> **TL;DR.** Measure accepted outcomes, not activity; make attribution a deliberate policy choice; automate with bounded programmatic runs. Nobody has team adoption fully figured out — the adoption page is honest about that, including the studies.

- **Full coverage → [AI Code Traceability & Attribution](ops/ai-traceability.md)** — Disclosure spectrum, attribution methods, industry policies, and the Vibe mechanics that implement them: no default trailer, an AGENTS.md rule, hooks on commit commands, and the session store as evidence. TL;DR opens: "A commit Vibe writes carries **no attribution trailer at all** — no `Co-Authored-By`, no `Generated-with`, nothing; it is indistinguishable from a human commit unless your team adds attribution itself (*live-verified on 2.25.7*, T8)."
- **Full coverage → [Team Metrics for AI-Augmented Engineering](ops/team-metrics.md)** — How to measure and pilot a tech-product team practicing agentic coding. DORA, SPACE, the metrics that matter when agents write much of your code, and the measurement surfaces Vibe actually gives you. TL;DR opens: "Keep DORA as the delivery-system foundation, SPACE for the people inside it, and add the AI-specific and agentic metrics the standard frameworks don't cover — while distrusting every activity metric that goes up just because agents write more code."
- **Full coverage → [Automation: Headless CI Runs and Scheduled Loops](ops/automation.md)** — The two automation surfaces in the verified Vibe CLI surface: programmatic mode (-p) for CI/CD with auto-DENY semantics, budget flags, and tool narrowing, and /loop for fixed-interval in-session recurrence — with three CI pattern sketches and the decision table between them. TL;DR opens: "Two automation surfaces exist in the verified CLI, and neither is a daemon. **Headless runs** are `vibe -p "<prompt>"`: one process, machine-readable output, never a prompt — approval-required tool calls are **auto-DENIED**, not auto-approved, so a CI run is conservative by default (PART-CLI; PART-TRUST section 3.4; live-verified on 2.25.7, T4). **Scheduled recurrence** is `/loop`: a fixed-interval prompt firing inside one live session, minimum 30 seconds, at most 50 loops per session, restored on resume (PART-SESSIONS section 5)."
- **Full coverage → [AI Roles and Career Paths: The New Engineering Landscape](roles/ai-roles.md)** — Evidence-bounded map of current AI role families, emerging specializations, and capabilities absorbed into broader engineering jobs. TL;DR opens: "The market separates more reliably by **ownership boundary** than by title."
- **Full coverage → [Learning to Code with AI: The Conscious Developer's Guide](roles/learning-with-ai.md)** — Research-based guide for developers learning to code effectively with AI assistance: the UVAL protocol against dependency, the three dependency patterns, the productivity curve, the attention cost of the review shift — with every tool-specific callout rebuilt on the Vibe CLI's verified surface. TL;DR opens: "AI assistance can make you faster or make you hollow — the difference is whether understanding survives the loop."
- **Full coverage → [Choosing Your Adoption Approach](roles/adoption-approaches.md)** — Adoption decision framework for agentic coding with Vibe: starting points, the L0-L5 maturity scale, the J-curve, team-size guidance, and a portfolio exercise for deciding what you pay for. TL;DR opens: "Nobody has adoption figured out — not this guide, not the vendors."

## 11. Workflows and Methodologies

The workflows are the recipe layer: step-by-step patterns from test-driven development to event-driven agents, each mapped onto Vibe's actual surface instead of transliterated from another tool — every mechanic inside them cites the oracle. The methodology reference and the loop and graph engineering pages are the theory they descend from.

> **TL;DR.** Pick a workflow per problem shape — verification-first, spec-first, exploration, or refinement — and let the plan agent, worktrees, and budgeted programmatic runs carry the mechanics.

- **Full coverage → [Development Methodologies Reference](core/methodologies.md)** — Quick reference for 15 structured agentic-coding methodologies, with fit assessments against Vibe's real surface. TL;DR opens: "Fifteen structured methodologies for agentic coding, mapped on two axes (spec-first vs code-first, lean vs governed)."
- **Full coverage → [Loop & Graph Engineering](core/loop-graph-engineering.md)** — Design bounded agent feedback loops and executable workflow graphs: durable state, explicit judgment allocation, inspectable evidence, and the Vibe mechanics that enforce them. TL;DR opens: "Start with the smallest control structure that can make the required decision safely."
- **Full coverage → [Agentic-Coding Workflows](workflows/README.md)** — Step-by-step guides for common development patterns with the Vibe CLI: prompting discipline, planning gates, verification loops, and automation. TL;DR opens: "Ten recipe pages, one per recurring job: explore before you implement, gate research and planning before code, test before you write, verify before you trust, and document before you merge."
- **Full coverage → [Test-Driven Development with Vibe](workflows/tdd.md)** — Red-green-refactor with explicit prompting: how to run TDD cycles with an agentic CLI that defaults to implementation-first. TL;DR opens: "Red → Green → Refactor; But you MUST prompt the agent explicitly:; "Write a FAILING test for [feature]."
- **Full coverage → [Spec-First Development](workflows/spec-first.md)** — Define the spec in AGENTS.md (or a spec file it references) before implementation, and verify against it. TL;DR opens: "Write the spec into AGENTS.md (or a spec file it references); The agent loads AGENTS.md automatically at session start; Implementation follows the spec; Verify the result against the spec — in a separate run."
- **Full coverage → [RPI: Research → Plan → Implement](workflows/rpi.md)** — A 3-phase feature development pattern with explicit GO/NO-GO validation gates between phases. TL;DR opens: "Phase 1 — Research:; The agent explores feasibility, surfaces risks, asks decision questions; Output: RESEARCH.md; Gate: You decide GO / NO-GO; Phase 2 — Plan:; The agent writes architecture decisions, implementation steps, test gates; Output: PLAN.md; Gate: You approve the plan before any code is written; Phase 3 — Implement:; The agent implements step by step; each step's test gate must pass first; Output: working code + passing tests; Gate: each implementation step validated before the next begins."
- **Full coverage → [Exploration Before Implementation](workflows/exploration.md)** — Ask the agent for multiple approaches with quantified trade-offs before any code is written, to prevent anchoring on the first proposed solution. TL;DR opens: "Describe the problem — no code, no preconceived solution; Request 3-5 approaches with trade-offs; Ask for a quantified comparison; Choose one; Only then implement."
- **Full coverage → [Production Reliability Patterns](workflows/production-reliability.md)** — Escalation design, circuit breakers, structured error propagation, graceful degradation, human handoff, and source conflict resolution for systems built around an agentic CLI. TL;DR opens: "Escalate on programmatic signals (explicit request, policy gap, retry; budget exhausted) — never on model confidence scores; Put a circuit breaker around every failing dependency; Propagate structured errors (is_retryable, error_category,; alternative_approach) — not exception strings; Return partial results with coverage annotations, not nothing; Hand off structured payloads with a recommended next action; Resolve source conflicts by date when possible; surface the rest."
- **Full coverage → [Best-of-N: Generate, Select, and Verify](workflows/best-of-n.md)** — A bounded protocol for generating independent candidates, selecting against a fixed rubric, and recording executable evidence. TL;DR opens: "Freeze the task contract and the rubric before generating anything; Generate N independent candidates (isolated worktrees, bounded runs); Blind-score every candidate against the frozen rubric; Select the highest passing candidate; synthesize only deliberately; Verify outside the generation context (executable checks, fresh reviewer); Publish the proof log: scores, commands, results, unknowns."
- **Full coverage → [Iterative Refinement](workflows/iterative-refinement.md)** — The prompt-observe-reprompt loop that steers agentic coding, plus bounded auto-loops, hook-driven quality gates, and the review auto-correction pattern, rebuilt on verified Vibe mechanics. TL;DR opens: "Initial prompt with a clear goal; Agent produces output; Evaluate against stated criteria; Specific feedback: "Change X because Y"; Repeat until the criteria pass — then stop."
- **Full coverage → [Changelog Fragments: Enforced Per-PR Documentation](workflows/changelog-fragments.md)** — A 3-layer enforcement pattern for the Vibe CLI that ensures every PR is documented at write time, never at release time: an AGENTS.md rule, an edit-time hook nudge, and a CI gate. TL;DR opens: "One YAML fragment per PR, written while implementing, validated by CI, assembled automatically at release."
- **Full coverage → [Event-Driven Agent Automation](workflows/event-driven-agents.md)** — Trigger Vibe agents from external events — issue trackers, CI, alerting webhooks — via programmatic mode, with budget and hook guardrails. TL;DR opens: "Instead of invoking the CLI for each task, let external events drive it: a webhook or CI receiver filters the event, extracts context as data, and shells out to programmatic mode — `vibe --trust -p "<task>" --output json --max-turns N` — never prompting, because approval-requiring calls are auto-DENIED in `-p` mode unless `--auto-approve`/`--yolo` or the agent's permission config allows them (PART-CLI; PART-TRUST section 3.4)."
- **Full coverage → [Module 07: Advanced Orchestration](learning-path/07-advanced.md)** — Learning Path Module 07 (capstone): orchestrate one parent session over parallel subagents with the task tool, gate risky calls with hooks and per-tool permissions, isolate releases in worktrees, run headless with budgets, and schedule recurring work with /loop. 90-120 min, Production track. TL;DR opens: "Vibe has one delegation mechanism: the **`task` tool** spawning `agent_type = "subagent"` profiles."

## 12. The Surfaces: CLI, Desktop, and Web

One harness, three clients. This chapter routes the product-surface pages: the CLI as the baseline everything else builds on, the Vibe Code desktop app with its bundled harness session runtime, Vibe Code Web with its teleport bridges and cloud sandboxes, and the migration chapter for porting a setup from another agentic CLI (PART-CLI; PART-WEB). Desktop and web claims are pinned to the bundle and docs versions they were verified against; the pages carry their own Known gaps.

> **TL;DR.** Start with the CLI; add the desktop app for a GUI session client that runs the same harness out of the box, and the web surface for sandboxed cloud sessions reached by /teleport, &, and /remote-project. Porting from another tool is a rename-and-re-derive exercise the migration page maps row by row.

- **Full coverage → [The Vibe CLI](surfaces/cli.md)** — The Vibe CLI as the baseline surface of this guide: install and updates, the interactive TUI vs programmatic -p mode with auto-DENY semantics, agents and subagents, worktrees, sessions and resume, and when to pick the CLI over Vibe Code desktop, Vibe Code Web, or the VS Code extension. TL;DR opens: "The Vibe CLI is the terminal coding agent and the baseline surface the rest of this guide documents: open source at github.com/mistralai/mistral-vibe (Apache-2.0), installed from PyPI as `mistral-vibe` via `https://mistral.ai/vibe/install.sh` (Method and provenance)."
- **Full coverage → [Vibe Code Desktop App: The Bundled-Harness macOS Client](surfaces/desktop.md)** — The Vibe Code desktop app as verified from public artifacts: an Electron macOS application whose session runtime is the bundled vibe-app-server on mistralai_vibe_local_harness 0.5.1 — the same Session Protocol the CLI reaches via --experimental-harness. Work/Code modes, local/worktree/cloud session locations, the subagent side panel, and the six typed hook points. Oracle facts tagged [desktop-0.12.0]; installed bundle re-inspected at 0.14.0 on 2026-09-25. TL;DR opens: "The Vibe Code desktop app is an Electron macOS application whose session runtime is a bundled `vibe-app-server` built on `mistralai_vibe_local_harness` 0.5.1 — the same Session Protocol the CLI reaches only via `--experimental-harness` (oracle backend tags; PART-HOOKS-UNIFIED)."
- **Full coverage → [Vibe Code Web](surfaces/web.md)** — The cloud surface: three bridges from the CLI (/teleport, &, /remote-project), the cloud session model (entities, lifecycle, limits, sandbox), prerequisites, the CLI/VS Code/Web comparison, and the Slack integration — with every claim tagged [stable] or [docs-only]. TL;DR opens: "Vibe Code Web runs sessions in a per-session cloud sandbox instead of on your machine."
- **Full coverage → [Migration from Another Agentic CLI](surfaces/migrating-from-claude-code.md)** — Concept-by-concept port of an existing setup: which mechanics rename, which must be re-derived, and which do not transfer — every row cited to the oracle.

## Appendix A — Glossary

Every term this guide uses, defined once: universal agentic-coding vocabulary plus the Vibe mechanics behind each product term.

- **Full coverage → [Glossary](core/glossary.md)** — Definitions for every term this guide uses: universal agentic-coding vocabulary, plus the Vibe mechanics behind each product term. TL;DR opens: "One-short-definition-per-term reference."

## Appendix B — Cheatsheet

The daily-reference condensation of this guide: the command, flag, and key tables, rebuilt from the oracle with a citation on every row.

- **Full coverage → [Vibe Cheatsheet](cheatsheet.md)** — One-page daily reference for the Vibe CLI: slash commands, input conventions, agent modes, memory and config, context management, MCP, hooks, CLI flags, headless mode, and quick fixes. TL;DR opens: "~30 built-in slash commands, three hook events, five built-in agent profiles plus one opt-in (`lean`), one `task` tool with subagent depth capped at 1 (PART-COMMANDS section 2; PART-HOOKS section 1; PART-PERMISSIONS section 4.1; PART-AGENTS section 9). - The default agent is `accept-edits`: file edits run without prompts, everything else asks. `--yolo`/`--auto-approve` approves everything; `ask` asks for everything not allowlisted; `plan` is read-only (PART-PERMISSIONS section 4.1). - Memory is `AGENTS.md` (project wins over user, closer directory wins); settings are `config.toml` in an eight-layer precedence stack (PART-AGENTSMD; PART-CONFIG section 2.1). - Context auto-compacts at `auto_compact_threshold` tokens (default 200,000, `0` disables, per-model override wins), with a one-time warning at 50% of the threshold (PART-SESSIONS section 4.1). - Headless: `vibe -p` with `--max-turns`/`--max-price`/`--max-tokens` and `--output text|json|streaming`; approval-requiring tool calls are auto-denied unless you pass `--auto-approve` (PART-CLI)."

## Appendix C — Diagrams

Forty-eight Mermaid diagrams with ASCII fallbacks, re-labeled for Vibe; each links back into the prose page that covers its topic.

- **Full coverage → [Vibe: Visual Diagrams](diagrams/README.md)** — Interactive Mermaid diagrams of the verified Vibe CLI mechanics, organized in 12 thematic files: foundations, context and sessions, configuration, architecture, MCP, workflows, multi-session patterns, security, cost, adoption, context engineering, and governance — each with an ASCII fallback. TL;DR opens: "This directory is the visual index of the guide: 12 diagram files plus this README."

## Appendix D — Quiz

The question bank: multiple-choice questions grounded in the oracle and the pages of this guide, with backlinks to the section each answer comes from.

- **Full coverage → [Quiz](../quiz/README.md)** — The working-with-mistral-vibe question bank: nine topic files, 123 oracle-grounded questions, the schema, and the validator. TL;DR opens: "One YAML file per topic area, nine files, 123 questions — every one grounded in the mechanics oracle or a specific guide page, with a resolving `doc_reference` backlink, and distractors built from real Vibe confusions (fail-open vs `strict`, session-only `--trust`, programmatic auto-DENY, project-beats-user config) rather than trivia."

## Appendix E — Machine-Readable Index and the MCP Server

The same guide, as data: a generated index of every page and heading, and an npm MCP server that serves the pages and the index as tools to any MCP-compatible client. Code is MIT, content is CC BY-SA 4.0 — the split is recorded in NOTICE.md.

- **Full coverage → [Reference Index Schema](../machine-readable/schema.md)** — The generated index of every guide page — paths, titles, descriptions, tags, headings with line numbers — and the contract it follows.
- **Full coverage → [MCP Server](../mcp-server/README.md)** — The npm server that serves the guide's pages and the reference index as tools to any MCP-compatible client; MIT code, CC BY-SA 4.0 content.

## Appendix F — Vibe Releases and Guide Re-verification

The release-tracking page: every mistral-vibe release that affects the guide gets a dated row — what changed for guide content, whether the oracle was re-verified, and when the page banners were re-stamped. It is the trigger surface for the guide's re-verification loop.

- **Full coverage → [Vibe Releases and Guide Re-verification](releases.md)** — The release-tracking page: every mistral-vibe release that affects this guide gets a dated row — what changed for guide content, whether the oracle was re-verified, and when the page banners were re-stamped. TL;DR opens: "The CLI's public changelog records breaking changes between releases (for example, the `hooks.toml` event renames), so this guide treats every new `mistral-vibe` release as a re-verification event: a dated row lands here, the oracle is re-run against the new release, and every page banner is re-stamped. `scripts/check-vibe-release.sh` compares the guide's recorded documented surface against the latest public release (PyPI + the repository's tags) and exits non-zero when a pass is due; CI runs it as a warning, because content staleness is not a build failure."

## Appendix F — Translations and Language Adaptations

English is the only maintained edition; community adaptations are listed under a provenance contract (pinned guide version and source SHA, declared coverage).

- **Full coverage → [Translations and Language Adaptations](translations.md)** — The guide's language policy: English is the only maintained edition, and community adaptations are accepted under a provenance contract — pinned guide version and source SHA, declared coverage, listed in a public registry. TL;DR opens: "English is the only edition this repository writes, updates, and vouches for."

## Known gaps

- **Commercial claims are not oracle-verified.** Plan, price, and seat
  rows anywhere in this guide are dated snapshots of public pages,
  reproduced as evidence, never as quotes.
- **This spine routes; it does not teach.** If a mechanic you need is
  missing from the page it routes to, the gap belongs there, not here.

## About this guide

Guide version 0.2.0. Structure and pedagogy adapted from the
community guide by Florian Bruniaux (CC BY-SA 4.0); mechanics rewritten
and independently verified against Mistral's Vibe products from public
sources — see [`NOTICE.md`](../NOTICE.md) for the license split and the
attribution chain.
