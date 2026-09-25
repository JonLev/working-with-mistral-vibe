---
title: "Development Methodologies Reference"
description: "Quick reference for 15 structured agentic-coding methodologies, with fit assessments against Vibe's real surface"
tags: [reference, tdd, design-patterns, workflows]
---

# Development Methodologies Reference

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

**TL;DR**: Fifteen structured methodologies for agentic coding, mapped on two axes (spec-first vs code-first, lean vs governed). The methodologies are tool-agnostic; what changes per tool is the fit. On Vibe, spec-first methods ride the plan agent plus checked-in `AGENTS.md`, parallel and best-of-n methods ride `--worktree`, automation rides programmatic mode with budgets plus `/loop`, and multi-agent work rides the `task` tool — which is depth-1, not an orchestration tree.

*Read if you want to pick a methodology and know how it maps onto Vibe's actual mechanisms. Skip if you already run one of these and just need workflow recipes — those are the [`guide/workflows/`](../workflows/README.md) pages.*

---

## Methodology is not harness ownership

Methodologies define how work is planned, checked, and improved. They do not determine which product owns the agent loop. Keep four layers separate: the model generates tokens, the runtime harness executes the loop, the repository harness supplies project-specific feedback (on Vibe: `AGENTS.md`, project config, skills, hooks — see [memory-systems.md](memory-systems.md)), and an orchestrator coordinates multiple runs (see [agent-harness.md](agent-harness.md)). The useful unit of evaluation is the model-harness pair, not the methodology brand. Shared terms are in the [glossary](glossary.md).

---

## Decision tree: what do you need?

```text
┌─ "I want quality code" ────────────→ TDD + verification loops (Tier 5, below)
│
├─ "I want to spec before code" ─────→ SDD / Doc-Driven (Tier 2) + Writing Effective Specs
│
├─ "I need to plan architecture" ────→ Plan-First Workflow (below)
│
├─ "I'm iterating on something" ──────→ Iterative loops / fresh context (Tier 6)
│
└─ "I need methodology theory" ───────→ Continue reading below
```

---

## Methodology map

Two axes: **Spec-First vs Code-First** (Y) and **Lean/Solo vs Enterprise/Governed** (X).

```text
                      SPEC / PLANNING FIRST
                                ▲
  ── lean · spec ──             │             ── governed · spec ──
                                │
  [Doc-Driven]  [SDD]           │    [BDD]  [ATDD]   [Req-Driven]
  [GSD]  [Plan-First]           │ [CDD] [ADR-Driven]  [DDD]  [BMAD]
                                │
  LEAN ─────────────────────────┼────────────────────────────────► ENTERPRISE
                                │
  ── lean · code ──             │             ── governed · code ──
                                │
  [Context Eng.]   [TDD]        │       [Multi-Agent]
  [Prompt Eng.]  [Iterative]    │       [Eval-Driven]       [FDD]
  [Ralph Loop]                  │           [JiTTesting]
                                │
                         CODE / EMERGENT
```

- **Top-left** (spec-first lean): `SDD`, `Doc-Driven`, `Plan-First`. Entry point for solo devs and small teams leaving "code first" behind.
- **Top-right** (spec-first governed): `BMAD`, `Req-Driven`, `ATDD`, `DDD`. Real governance, costly setup. ROI is driven by project complexity and requirement stability, not headcount.
- **Bottom-left** (code-first lean): the natural interactive-CLI terrain. `TDD` + iterative loops = the core solo workflow.
- **Bottom-right** (code-first at scale): `Multi-Agent`, `Eval-Driven`, `JiTTesting`. Patterns for high-volume teams.
- **On the axis**: `Plan-First`, `CDD`, `ADR-Driven`, `GSD` — hybrids that adapt to any context.

---

## The 15 methodologies

Organized as tiers from strategic orchestration down to optimization techniques.

### Tier 1: Strategic orchestration

| Name | What | Best for | Vibe fit |
|---|---|---|---|
| **BMAD** | Multi-role governance with a constitution as guardrail | High-complexity projects, stable requirements, compliance | Niche; role profiles port as agent TOML, but orchestration is depth-1 (see below) |
| **GSD** | 6-phase workflow with a fresh context per task | Solo devs, CLI-first work | Strong; fresh session per task, phases as skills |

**BMAD (Breakthrough Method for Agile AI-Driven Development)** makes documentation the source of truth instead of code, with specialized roles (Analyst, PM, Architect, Developer, QA) under strict governance. Use for complex enterprise projects; avoid for MVPs and evolving requirements — it is brittle when specs change mid-project. On Vibe the roles become custom agent TOML profiles with `agent_type = "subagent"` (PART-AGENTS section 8), spawned through the `task` tool. Two hard constraints come from the mechanism, not the methodology: the `task` tool is depth-1 (subagents cannot spawn subagents) and results return to the parent as text only (PART-AGENTS section 9). Role separation survives; recursive role trees do not. Role prompts belong in a custom prompt file referenced by `system_prompt_id` — the `instructions` field of an agent TOML is parsed but not injected into the CLI system prompt in 2.25.0 (PART-AGENTS section 8).

**GSD (Get Shit Done)** attacks context rot with a six-phase workflow (Initialize, Discuss, Plan, Execute, Verify, Complete) and a fresh context per task. On Vibe, "fresh context" is a fresh session, not a fixed token window: `/clear` starts a new unpinned conversation (PART-SESSIONS section 3), and each phase can be a skill invoked as `/phase-name` or loaded by the model on demand (PART-SKILLS sections 1.3-1.4). State passes through git and files, never through chat history.

### Foundational discipline: the Plan-First workflow

> "Once the plan is good, the code is good."

Planning is a discipline, not a toggle. On Vibe it is the **plan agent** — a built-in, read-only profile — not a mode switch (PART-AGENTS section 7). [stable]

- `plan` is read-only: `write_file` and `edit` are set to `permission = "never"`, except for an allowlist under `$VIBE_HOME/plans/` where plan documents may be written; `read_file` reads freely.
- Select it with `vibe --agent plan`, the `default_agent = "plan"` config key, or Shift+Tab, which cycles `ask → plan → accept-edits → auto-approve` (PART-AGENTS sections 7-8, 10).

The loop:

1. **Exploration** (plan agent): the agent reads files and proposes an approach with trade-offs. No edits — thinking before action is enforced by the permission overrides, not by willpower.
2. **Validation** (you): the plan exposes assumptions and gaps. Correcting direction now beats correcting 100 written lines later. The plan is the contract.
3. **Execution**: switch to `accept-edits` (the default agent) or `auto-approve`; plan-to-code becomes mechanical translation.

**When to plan first:**

| Task complexity | Plan first? | Why |
|---|---|---|
| More than 3 files modified | Yes | Cross-file dependencies need architecture |
| More than 50 lines changed | Yes | Enough complexity for mistakes |
| Architectural changes | Yes | Impact analysis required |
| Unfamiliar codebase | Yes | Exploration before action |
| Typo or obvious fix | No | Planning overhead exceeds task time |
| Single-line change | No | Just do it |

Document your team's triggers in the project `AGENTS.md`, which is injected into every trusted session and overrides default behavior (PART-AGENTSMD):

```markdown
## Planning Policy
- ALWAYS plan first: API changes, database migrations, new features
- OPTIONAL planning: bug fixes under 10 lines, test additions
- NEVER skip: changes affecting more than 2 modules
```

### Tier 2: Specification and architecture

| Name | What | Best for | Vibe fit |
|---|---|---|---|
| **SDD** | Specs before code | APIs, contracts | Core pattern; spec lives in `AGENTS.md` + docs, validated by the plan agent |
| **Doc-Driven** | Docs are the source of truth | Cross-team alignment | Native; checked-in `AGENTS.md` is versioned with the code (PART-AGENTSMD) |
| **Req-Driven** | Rich artifact context, 20+ artifacts | Complex requirements | Heavy setup; artifacts live in docs, indexed leanly from `AGENTS.md` |
| **DDD** | Domain language first | Business logic | Design-time; ubiquitous language belongs in `AGENTS.md` |

**SDD (Spec-Driven Development)**: specifications before code; one structured iteration beats eight unstructured ones. On Vibe, `AGENTS.md` is the spec carrier that is always loaded, and the plan agent is the review gate that reads the spec before any edit is possible (PART-AGENTSMD, PART-AGENTS section 7).

**Doc-Driven Development**: living documentation, versioned in git, is the single source of truth; spec changes trigger implementation. The checked-in project `AGENTS.md` (loaded from each project root up to its trust root, closer directories winning) is exactly this (PART-AGENTSMD).

**Requirements-Driven Development**: a comprehensive implementation guide built from 20+ structured artifacts. Keep the artifacts as docs in the repo and reference them from `AGENTS.md`; see "The curse of instructions" below before loading all 20 into it.

**DDD (Domain-Driven Design)**: align software with business language — ubiquitous language in code, bounded contexts, domain distillation (core vs support vs generic). The shared vocabulary belongs in the project `AGENTS.md` so every session inherits it.

### Tier 3: Behavior and acceptance

| Name | What | Best for | Vibe fit |
|---|---|---|---|
| **BDD** | Given-When-Then scenarios | Stakeholder collaboration | Strong; scenarios are plain files the agent executes via the bash tool |
| **ATDD** | Acceptance criteria first | Compliance, regulated | Strong; agents need unambiguous success conditions most of all |
| **CDD** | API contracts as interface | Microservices | Strong; contracts are files, tests run through bash (PART-CONFIG section 1.3) |

**BDD**: discovery (devs + business experts), formulation (Given-When-Then examples), automation (executable tests via Gherkin/Cucumber).

```gherkin
Feature: Order Management
  Scenario: Cannot buy without stock
    Given product with 0 stock
    When customer attempts purchase
    Then system refuses with error message
```

**ATDD**: acceptance criteria defined before coding, collaboratively. In agentic development this is the highest-leverage habit: agents need unambiguous done-conditions. Define criteria in Gherkin; the agent writes failing tests from the scenarios, not from implementation guesses; then implements until they pass.

*"Write failing tests for this feature file, then implement until they pass."* — the scenario is the contract; done is defined before code exists. For headless runs, programmatic mode auto-DENIES approval-required calls, so a CI run cannot escalate permissions mid-cycle (PART-CLI).

**CDD (Contract-Driven Development)**: API contracts (OpenAPI specs) as the executable interface between teams — contract as test, contract as stub.

**JiTTesting (Just-in-Time Testing)**: tests generated at PR time, designed to fail, then discarded after merge — no maintenance cost, no suite growth. TDD assumes the developer controls the pace of authoring; an agent generating hundreds of lines per hour breaks that assumption. At PR time an LLM infers diff intent, generates mutants, writes tests that catch them, and filters false positives (reported at Meta scale in "Just-in-Time Catching Test Generation at Meta", arXiv 2601.22832). No open-source implementation exists; approximate it by asking for tests that would catch regressions introduced by this diff specifically, running them, and discarding them.

### Tier 4: Feature delivery

| Name | What | Best for | Vibe fit |
|---|---|---|---|
| **FDD** | Feature-by-feature delivery | Parallel feature teams | Good; features parallelize across worktrees (PART-WORKTREES) |
| **Context Eng.** | Context as a first-class design element | Long sessions | Fundamental; see [context-engineering.md](context-engineering.md) |

**FDD**: develop overall model, build feature list, plan by feature, design by feature, build by feature. Parallel feature work maps to `vibe --worktree NAME`, which checks out an isolated worktree on branch `NAME` under `$VIBE_HOME/worktrees/`, implicitly trusted for the session (PART-WORKTREES).

**Context Engineering**: treat context as a design element — progressive disclosure (let the agent discover incrementally), memory management (conversation vs persistent state, see [memory-systems.md](memory-systems.md)), dynamic refresh. The Vibe-native primitives: skills load on demand rather than occupying the system prompt (PART-SKILLS section 1.4), subdirectory `AGENTS.md` files inject lazily when a file beneath them is read (PART-AGENTSMD), and `@path` mentions inject file content as a fresh read per mention, capped at 2000 lines and 50 KB per file, 8 files per prompt (PART-SESSIONS section 6).

### Tier 5: Implementation

| Name | What | Best for | Vibe fit |
|---|---|---|---|
| **TDD** | Red-Green-Refactor | Quality code | Core workflow; verification via bash tool or post-tool hooks |
| **Eval-Driven** | Evals for LLM outputs | AI products | Good; eval runs fit programmatic mode with JSON output |
| **Multi-Agent** | Orchestrate subagents | Complex tasks | Constrained; one level of delegation only (PART-AGENTS section 9) |

**TDD**: write the failing test, write minimal code to pass, refactor with tests green. With an agent, be explicit: *"Write failing tests that do not exist yet."*

**Verification loops** — the generalization of TDD that makes agentic work converge:

```text
Code generated → verification tool → feedback → improvement
```

An agent that can see what it has done produces better results; without a feedback mechanism it guesses. Verification by domain:

| Domain | Verification tool | What the agent sees |
|---|---|---|
| Backend | Tests (unit/integration) | Pass/fail status, error messages |
| Types | TypeScript compiler | Type errors, incompatibilities |
| Style | Linters, formatters | Style violations, formatting |
| Performance | Profilers, benchmarks | Execution time, memory |
| Security | Static analyzers | Vulnerability patterns |

Implementation patterns on Vibe:

- **Hooks**: a `post_tool` hook in `hooks.toml` runs after each tool call that actually executed (not on denials), so verification can gate every edit; failures are fail-open warnings unless `strict = true` [stable] (PART-HOOKS sections 1-2).
- **Programmatic CI gates**: `vibe -p "run the full test suite and fix failures" --max-turns N --output json` runs headless; approval-required calls are auto-DENIED, so the gate cannot silently escalate (PART-CLI).
- **Cross-checking**: one session codes, a second reviews — spawn the built-in read-only `explore` subagent via the `task` tool for an in-session review, or run the reviewer in a separate worktree (PART-AGENTS section 9, PART-WORKTREES).

**Eval-Driven Development**: TDD for LLM outputs — golden-answer checks, LLM-based grading, human reference. The closest Vibe primitive is programmatic mode: `vibe -p "<task>" --output json` returns all messages as structured entries, so an external harness can grade runs, and `--max-price` bounds the cost of a bad one (PART-CLI). Vibe ships no eval runner itself.

**Multi-Agent orchestration**: from single assistant to a team (analyst, architect, developer, reviewer). On Vibe this is a hub-and-spoke, not a tree: the `task` tool spawns `agent_type = "subagent"` profiles only, subagents cannot spawn subagents (depth limit 1, enforced with an explicit error), and the parent receives a text-only result it must summarize (PART-AGENTS section 9). The default subagent `explore` is read-only (`grep`, `read_file`, `skill`); richer roles are custom agent TOMLs with their own tool overrides (PART-AGENTS section 8). For parallelism beyond delegation, use worktrees, not subagents — see below.

### Tier 6: Optimization

| Name | What | Best for | Vibe fit |
|---|---|---|---|
| **Iterative loops** | Autonomous refinement | Optimization | Core; `/loop` for scheduled repeats [both] |
| **Fresh context** | Reset per task, state in files | Long autonomous sessions | Core; sessions + worktrees + files |
| **Prompt engineering** | Technique foundation | Everything | Prerequisite; tool-agnostic |

**Iterative refinement**: execute, observe, refine until an explicit done-condition. The Vibe-native forms: `/loop <interval> <prompt>` re-fires a prompt on a schedule (minimum 30 s interval, maximum 50 loops per session, prompts cannot start with `/`, loops survive resume and fire only when the session is idle) [both] (PART-SESSIONS section 5); for longer autonomy, repeated programmatic runs with `--max-turns`/`--max-price`/`--max-tokens` budgets and `--output streaming` for progress (PART-CLI).

**Fresh context (the Ralph loop)**: context rot is cured by starting over, not by summarizing harder. Spawn a fresh session per task — a new session, `/clear`, or a `vibe -p` run — with state persisted in git and progress files, never in chat history. Long autonomous runs (migrations, overnight batches) combine this with `--worktree` so each task gets a clean checkout, and rely on auto-compaction (default threshold 200,000 tokens, a compaction trigger, not a context window) only as a safety net (PART-SESSIONS sections 3-4, PART-WORKTREES).

**Prompt engineering**: zero-shot chain of thought, few-shot examples, structured prompts, position-sensitive instructions. Foundation for everything above; nothing in Vibe replaces it.

### ADR-Driven development

Architecture Decision Records drive implementation directly: write plain-English ADRs (context, decision, consequences), then execute them as skills.

1. Document the decision in ADR format.
2. Create an `implement-adr` skill: a directory with a `SKILL.md` whose frontmatter `name` matches the lowercase-hyphen regex and whose `description` is the routing text the model sees before loading (PART-SKILLS section 1.1).
3. Feed the ADR to the skill: `/implement-adr docs/adr/001-database-migration.md` (user-invocable skills resolve as `/skill-name`, PART-SKILLS section 1.3).
4. The agent executes against the ADR's acceptance criteria; tests verify.

```markdown
# ADR-001: Database Migration Strategy
## Context
Legacy MySQL schema needs migration to PostgreSQL for JSON support.
## Decision
Incremental dual-write pattern behind feature flags.
## Consequences
- Positive: zero-downtime migration
- Negative: temporary complexity during transition
```

Documentation and code stay synchronized, decisions stay traceable, and ADRs communicate intent to humans and agents alike.

---

## Parallel, best-of-n, and automated execution

Three execution patterns cut across methodologies; all are Vibe mechanics, not methodology features.

| Pattern | Mechanism | Notes |
|---|---|---|
| Parallel tracks | `vibe --worktree NAME` | One worktree per track on its own branch, implicitly trusted; interactive runs auto-clean a worktree with no changes, programmatic runs never do (PART-WORKTREES) |
| Best-of-n | `--worktree` + `-p` | Run n candidate implementations in n worktrees with `--max-price` budgets, compare the diffs, merge the winner (PART-WORKTREES, PART-CLI) |
| Automation | `-p` + `/loop` | Headless runs auto-DENY approval-required calls; `--auto-approve`/`--yolo` opts a run into allowing all tool calls; `/loop` schedules repetition inside a session (PART-CLI, PART-SESSIONS section 5) |

Worktree sessions are directory-scoped: `-c` and the resume picker only see sessions started inside that worktree, so carry cross-worktree work with `--resume <ID>` (PART-WORKTREES, PART-SESSIONS section 3).

---

## SDD tools

Third-party spec-driven development toolkits exist and are worth knowing by shape, not by install command. Their bundled slash-command sets target their own harness surfaces; on Vibe, port the workflow as skills and spec files rather than expecting the commands to exist.

| Tool | Use case | Shape |
|---|---|---|
| **Spec Kit** | Greenfield, governance | Five phases: constitution, specify, plan, tasks, implement |
| **OpenSpec** | Brownfield, change management | Two folders: `specs/` (current truth) and `changes/` (proposals); proposal → review → apply → archive |
| **Specmatic** | API contract testing | Contract-as-test (generated from OpenAPI), contract-as-stub, breaking-change detection |
| **Spec-to-Code Factory** | Greenfield, enforcement | Multi-agent reference implementation (break, model, act, debrief) |

None of these is verified against Vibe's surface by the mechanics oracle; treat their phases as methodology input, rebuilt with Vibe primitives (skills, `AGENTS.md`, plan agent).

---

## Writing effective specs

Based on published analysis of thousands of agent configuration files (Addy Osmani, "How to Write Good Specs for AI Agents").

### The six essential components

| Component | What to include | Example |
|---|---|---|
| **Commands** | Executable, with flags | `npm test -- --coverage` |
| **Testing** | Framework, coverage target, locations | vitest, 80%, `tests/` |
| **Project structure** | Explicit directories | `src/`, `lib/`, `tests/` |
| **Code style** | One example beats paragraphs | show a real function |
| **Git workflow** | Branch, commit, PR format | `feat/name`, conventional commits |
| **Boundaries** | Permission tiers | see below |

### Permission tiers

On Vibe these are not prose wishes — they are config keys. `[tools.<name>] permission` accepts `ask`, `always`, or `never`; the bash tool additionally auto-allows `allowlist` command prefixes and auto-denies `denylist` prefixes (PART-CONFIG section 1.3).

| Tier | Config form | Use for |
|---|---|---|
| Always do | `permission = "always"`, or a bash `allowlist` prefix | Safe actions: lint, format, test |
| Ask first | `permission = "ask"` (default) | High-impact changes: deletes, publishes |
| Never do | `permission = "never"`, or a bash `denylist` prefix | Hard stops: commit secrets, force-push main |

### The curse of instructions

The same analysis found that more instructions means worse adherence to each one. On Vibe this is structural: the project `AGENTS.md` is injected wholesale into every trusted session (PART-AGENTSMD), so every line you add taxes every turn. Countermeasures, all oracle-backed:

- Keep `AGENTS.md` to policy; push procedure into **skills**, loaded on demand by the `skill` tool (PART-SKILLS section 1.4).
- Use **subdirectory `AGENTS.md`** files, injected lazily only when a file beneath them is read (PART-AGENTSMD).
- Use **`@path` mentions** for just-in-time context: the file content arrives as a fresh read per mention, capped (PART-SESSIONS section 6).

### Monolithic vs modular specs

| Project size | Approach |
|---|---|
| Small (under 10 files) | Single spec file |
| Medium (10-50 files) | Sectioned spec, feed per task |
| Large (50+ files) | Subdirectory `AGENTS.md` by domain, skills for procedure |

---

## Combination patterns

| Situation | Recommended stack | Notes |
|---|---|---|
| Solo MVP | SDD + TDD | Minimal overhead, quality focus |
| Team 5-10, greenfield | SDD + TDD + BDD | Governance + quality + collaboration |
| Microservices | CDD + Specmatic | Contract-first, parallel dev |
| Existing SaaS (100+ features) | OpenSpec-style change tracking + BDD | Change tracking, no spec drift |
| High-complexity / compliance | BMAD + contract testing | Full governance + contracts |
| LLM-native product | Eval-Driven + Multi-Agent | Self-improving systems; mind the depth-1 delegation limit |

---

## Quick reference table

| Methodology | Level | Primary focus | Best context | Learning curve |
|---|---|---|---|---|
| BMAD | Orchestration | Governance | High complexity, stable requirements | High |
| SDD | Specification | Contracts | Any | Medium |
| Doc-Driven | Specification | Alignment | Any | Low |
| Req-Driven | Specification | Context | Complex requirements, many artifacts | Medium |
| DDD | Specification | Domain | Complex business domain | Very high |
| BDD | Behavior | Collaboration | Multi-role stakeholder involvement | Medium |
| ATDD | Behavior | Compliance | Regulated, explicit acceptance criteria | Medium |
| CDD | Behavior | APIs | Service boundaries, parallel teams | Medium |
| FDD | Delivery | Features | Feature teams, parallel delivery | Medium |
| Context Eng. | Delivery | AI sessions | Any | Low |
| TDD | Implementation | Quality | Any | Low |
| Eval-Driven | Implementation | AI outputs | Any | Medium |
| Multi-Agent | Implementation | Complexity | Any | Medium |
| Iterative | Optimization | Refinement | Any | Low |
| Prompt Eng. | Optimization | Foundation | Any | Very low |

---

## See also

- [context-engineering.md](context-engineering.md) — the context half of Context Engineering
- [memory-systems.md](memory-systems.md) — the repository harness as long-lived memory
- [agent-harness.md](agent-harness.md) — harness taxonomy and evaluation
- [architecture.md](architecture.md) — how the runtime loop actually executes
- [loop-graph-engineering.md](loop-graph-engineering.md) — loop and graph patterns for autonomous work
- [glossary.md](glossary.md) — shared terms
- [guide/workflows/tdd.md](../workflows/tdd.md) — practical TDD with Vibe
- [guide/workflows/spec-first.md](../workflows/spec-first.md) — spec-first development walkthrough
- [guide/workflows/rpi.md](../workflows/rpi.md) — plan-driven development with the plan agent and GO/NO-GO gates
- [guide/workflows/iterative-refinement.md](../workflows/iterative-refinement.md) — refinement loops
- [guide/learning-path/](../learning-path/README.md) — ordered curriculum
- guide/surfaces/ — per-surface mechanics (not written yet)

---

## Known gaps

- **No browser-driving or computer-use equivalent.** The source guide's frontend "browser preview" verification row and its browser-extension pattern have no counterpart in the verified Vibe surface; the local boundary is trust plus per-tool permissions plus worktrees. Visual verification stays manual. Any methodology that leans on "the agent looks at the rendered page" is not executable on Vibe today.
- **Third-party SDD tool integrations are unverified.** Spec Kit, OpenSpec, Specmatic, and Spec-to-Code Factory are described generically; the oracle covers no Vibe integration for any of them, and their slash-command sets do not exist in Vibe. Port their phases as skills and specs.
- **The `instructions` field of a custom agent TOML is parsed but not injected into the CLI system prompt in 2.25.0** (PART-AGENTS section 8; the oracle lists its unified-harness consumption as needing public verification). BMAD-style role ports must ride `system_prompt_id` custom prompt files instead.
- **GSD's "fresh 200k contexts" does not translate literally.** Vibe has no fixed context window in the verified surface; `auto_compact_threshold` (default 200,000 tokens, tunable per model) is a compaction trigger (PART-SESSIONS section 4). Say "fresh session per task", not "200k context".
- **JiTTesting has no open-source implementation**; the Vibe approximation (ephemeral, diff-targeted tests run via the bash tool and discarded) is a pattern, not a tool.
- **Eval-Driven has no built-in runner.** Programmatic mode with `--output json` and budget flags (PART-CLI) is the closest primitive; grading infrastructure is your own.
