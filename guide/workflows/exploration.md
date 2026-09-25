---
title: "Exploration Before Implementation"
description: "Ask the agent for multiple approaches with quantified trade-offs before any code is written, to prevent anchoring on the first proposed solution"
tags: [workflow, architecture, design-patterns]
---

# Exploration Before Implementation

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Structure and pedagogy adapted from the source guide (CC BY-SA 4.0, see [`NOTICE.md`](../../NOTICE.md)). Every command, flag, config key, and file path on this page cites the mechanics oracle, [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), inline as `(PART-XXX)`. Backend tags `[stable]` / `[unified-harness]` mark mechanics that depend on the session backend.

## TL;DR

```text
1. Describe the problem — no code, no preconceived solution
2. Request 3-5 approaches with trade-offs
3. Ask for a quantified comparison
4. Choose one
5. Only then implement
```

Key insight: **once a model proposes a concrete solution, it can unintentionally narrow your thinking.**

**Read if** you are starting a feature with several plausible designs and a choice that is expensive to reverse. **Skip if** the fix is obvious from the symptoms, the pattern already exists in the codebase, or it is a time-critical hotfix.

## The problem: anchoring

Before coding, ask the agent for multiple approaches with trade-offs. This prevents anchoring bias: the tendency to fixate on the first solution proposed — the model's, or yours. The failure mode runs in both directions: lead with "I'm thinking Redis" and you have eliminated most of the solution space before exploration starts; accept the first proposal you receive and you never see the alternatives that would have fit better.

## The pattern

### Step 1: Problem statement only

Start with the problem, not a solution direction:

*I need to handle user sessions in a Node.js API. Requirements: 10K concurrent users; session data is user ID, permissions, preferences; sessions must survive server restarts.*

Not this (it anchors on Redis):

*I'm thinking of using Redis for sessions. How should I implement it?*

### Step 2: Request multiple approaches

*Give me 4 different approaches to solve this. For each, include: architecture overview; pros and cons; performance characteristics; complexity to implement.*

### Step 3: Quantified comparison

*Now rank these approaches on a 1-10 scale for: latency (lower is better); scalability (10K to 100K users); operational complexity; development time.*

### Step 4: Choose, then implement

*I'll go with approach B (JWT + Redis hybrid). Now implement it following our existing patterns in `src/auth/`.*

## Anti-anchoring prompts

Agents can fixate on their first suggestion. These prompts combat that:

| Prompt type | Template | Effect |
|-------------|----------|--------|
| **Fresh start** | *"Ignore any prior ideas. Generate 4 novel approaches to [X]."* | Forces diversity |
| **Reflection loop** | *"Generate 3 options, then critique each, then recommend."* | Self-correction |
| **Quantified trade-offs** | *"Rank by [metric1], [metric2], [metric3] with scores 1-10."* | Objective comparison |
| **Devil's advocate** | *"What are the strongest arguments against your recommendation?"* | Surfaces hidden trade-offs |
| **Constraint variation** | *"Now solve the same problem with [opposite constraint]."* | Expands the solution space |

### Example: anti-anchoring prompt

I need pagination for a REST API with 1M+ records.

IMPORTANT: don't suggest offset-based pagination first. Generate 4 different pagination strategies, including at least one unconventional approach. For each: how it works (2-3 sentences); best use case; worst use case; performance at 1M records. Then recommend one, explaining why it beats the others for my use case.

### Reflection loop prompt

```text
For implementing real-time notifications:

Phase 1: Generate 3 approaches (WebSockets, SSE, long polling).
Phase 2: For each, list 2 things that could go wrong in production.
Phase 3: Based on Phase 2, which approach is most resilient?

Show your reasoning for each phase.
```

## When to use

### Use exploration

| Scenario | Why |
|----------|-----|
| Greenfield features | No existing pattern to follow |
| Architecture decisions | High impact, hard to reverse |
| Multiple valid approaches | Need an informed choice |
| Unfamiliar domain | You don't know what you don't know |
| Team disagreement | Neutral analysis of options |

### Skip exploration

| Scenario | Why |
|----------|-----|
| Bug fixes | Solution usually obvious from symptoms |
| One valid approach | No real choice to make |
| Time-critical hotfixes | Speed beats perfection |
| Following an existing pattern | Decision already made |
| Trivial changes | Overhead not worth it |

## Working with Vibe

The methodology is pure prompting, but three Vibe mechanics make it easier to run: the plan agent for the post-decision plan, `AGENTS.md` to make the habit default, and the `task` tool to parallelize reconnaissance. All are `[stable]` (PART-AGENTS; PART-AGENTSMD).

### With the plan agent [stable]

Exploration happens **before** you hand off to the plan agent. Run the exploration in your normal session, choose the approach, then switch:

1. Explore: *"I need to add caching to the API. What are my options?"* — in your default session.
2. Choose: *"Let's go with approach C (edge caching with Cloudflare)."*
3. Plan and implement: switch to the plan agent with Shift+Tab (agent cycling order: `ask → plan → accept-edits → auto-approve`, PART-AGENTS §10) or start the session with `vibe --agent plan` (PART-CLI).

The plan agent is read-only: `write_file` and `edit` have permission `never` except for an allowlist on `~/.vibe/plans/*`, and `read_file` also allowlists the plans directory (PART-AGENTS §7). It explores and records plan files under `$VIBE_HOME/plans/` (default `~/.vibe/plans/`, PART-CLI); nothing else in your tree is writable while it is active. That read-only profile is exactly what you want after a decision: the plan agent can survey the codebase and write the plan, but cannot jump ahead into implementation.

### With AGENTS.md [stable]

Make exploration the default by putting the rule in your project's `AGENTS.md` (PART-AGENTSMD). Project `AGENTS.md` files are loaded from each project root up to its trust root, and closer files take priority over distant ones; they only load for trusted folders (PART-AGENTSMD).

```markdown
## Workflow preferences

### Before new features
When implementing new features, first explore 3-4 approaches
with trade-offs before committing to implementation.
Use a quantified comparison (1-10 scale) for:
- Performance
- Maintainability
- Time to implement
```

### With the task tool [stable]

Two distinct jobs, one tool:

- **Reconnaissance.** Spawn the built-in `explore` subagent with the `task` tool while you keep discussing approaches in the parent session. The `explore` profile is read-only (`enabled_tools`: `grep`, `read_file`, `skill`), returns a text-only result that the parent summarizes, and subagents cannot spawn further subagents (depth limit 1) (PART-AGENTS §7, §9). Use it to gather the facts each candidate needs — current call sites, existing patterns, dependency versions — without spending your main context.
- **Follow-up tracking.** The verified surface has **no persistent todo store**. Record the chosen approach and its follow-up items in a task file (for example `TASKS.md`) and add a rule to `AGENTS.md` telling the agent to read and update it (PART-AGENTSMD). A `/todo` command exists only as a `[unified-harness]`-gated delta in release 2.25.8 (PART-COMMANDS) — do not build on it.

### Headless exploration [stable]

Exploration is read-only, so it fits programmatic mode well:

```text
vibe --trust -p "Survey how src/auth/ handles sessions today. No code changes." --max-turns 5 --output json
```

`-p` mode never prompts: every approval-requiring tool call is auto-denied and the session runs headless, so a read-only survey cannot escalate into writes (PART-CLI; PART-TRUST §3.4). `--trust` grants session-only trust for the working directory — `trusted_folders.toml` is not modified (PART-TRUST §3.3). Bound the run with `--max-turns` and `--max-price` (both apply in `-p` mode only) and capture results with `--output json` (PART-CLI).

## Anti-patterns

### Premature anchoring

```text
Wrong:   "I want to use Redis for caching. How do I set it up?"
Right:   "I need caching for API responses. What are my options?"
```

You have eliminated most of the solution space before exploring.

### Shallow comparison

```text
Wrong:   "Which is better: Redis or Memcached?"
Right:   "Compare Redis, Memcached, and in-process caching for a
          50MB cache, read-heavy workload (95% reads), single-server
          deployment. Include latency, memory overhead, and
          operational complexity."
```

### Ignoring trade-offs

```text
Wrong:   "Just tell me the best approach."
Right:   "What would I give up by choosing approach A over B?
          What scenarios would make me regret this choice?"
```

### Analysis paralysis

```text
Wrong:   Exploring 10 options for a simple feature
Right:   "Give me your top 3 approaches, no more."
```

Set a limit, make a decision, iterate if needed.

## Example session

A worked exploration, showing the response discipline this guide asks of the agent: it opens by stating what it will do, signals the transition from options to ranking, and closes with a recommendation and its rationale.

**You:** *I need real-time updates in our React dashboard. About 50 metrics update every 5 seconds. We currently poll, and users complain about stale data.*

**Agent:** I'll lay out four viable approaches with their trade-offs, then rank them against your constraints once you confirm them. Here they are, ordered by latency:

- **A) WebSockets** — full duplex, the server pushes anytime. Lowest latency, but connection management and scaling add complexity. Best for sub-second updates and bidirectional communication.
- **B) Server-Sent Events (SSE)** — unidirectional server-to-client stream over HTTP. Simple, auto-reconnects, one-way only. Best for dashboard feeds and notifications.
- **C) Long polling** — the client holds a request until data is ready. Works everywhere, but higher latency and more server load. Best for legacy compatibility.
- **D) GraphQL subscriptions** — WebSocket-based with a GraphQL schema. Type-safe, selective updates, but requires GraphQL infrastructure.

Tell me your team's experience and scaling target and I'll score them.

**You:** *Rank these for our use case: React, 50 metrics, 5-second refresh, and the team has no WebSocket experience.*

**Agent:** Scoring on your four constraints, then a recommendation. Scores (1-10, higher is better):

| Approach | Latency | Complexity | Team fit | Scalability |
|----------|---------|------------|----------|-------------|
| WebSockets | 10 | 4 | 3 | 7 |
| SSE | 8 | 8 | 8 | 8 |
| Long polling | 5 | 9 | 9 | 5 |
| GraphQL subscriptions | 9 | 3 | 2 | 7 |

**Recommendation: SSE.** Best balance of simplicity and real-time capability: your team can implement it in a day, and it handles 50 metrics at 5-second updates comfortably. The trade-off is one-way flow — acceptable here since the dashboard only receives. If you later need bidirectional or sub-second updates, WebSockets is the upgrade path, and the SSE event stream ports to it. Want me to plan the implementation against your existing components?

## Known gaps

- **No native multi-candidate mechanism.** The documented surface has no built-in sampler that generates N independent proposals in one call; the diversity here comes from your prompts. For generating and scoring independent candidate *patches*, see [Best-of-N: Generate, Select, Verify](./best-of-n.md), which builds the protocol from ordinary runs.
- **Live-run note (2026-09-24, vibe 2.25.7):** the claim that the plan agent "records plan files under `$VIBE_HOME/plans/`" did not hold in a headless `-p` run: its `write_file` to `~/.vibe/plans/` was auto-DENIED by the approval policy (writes into the repo were denied too, as expected), while reading `~/.vibe/plans/*` via the read allowlist works. The oracle (PART-AGENTS §7; PART-PERMISSIONS §4.3) says the plan profile's `write_file` allowlist `$VIBE_HOME/plans/*` should resolve to `always`; live 2.25.7 (unified backend) diverges for writes in `-p` mode. Correction: the plan itself is still produced and delivered in-chat; live it also persists to the session scratchpad (`~/.vibe/logs/session/<backend>/<id>/scratchpad/`) — retrieve it from there, or transcribe it into the repo with a writable agent. Interactive-mode write behavior was not verified (interactive-only).
- **No persistent todo store** in the stable surface; a `/todo` command appears only as a `[unified-harness]`-gated 2.25.8 delta (PART-COMMANDS) and is not relied on anywhere in this guide.
- **The source guide's effect-size claims were dropped.** Its "+20-30% decision quality, +40% alternatives identified" figures came from practitioner studies this guide did not re-verify against the oracle; the causal claim (anchoring narrows options; explicit multi-approach prompts widen them) is kept, the numbers are not.

## See also

- [Best-of-N: Generate, Select, Verify](./best-of-n.md) — the bounded generate/select/verify protocol for when exploration produces candidate implementations
- [Methodologies](../core/methodologies.md) — where exploration sits relative to TDD and spec-first habits
- [Agents and Skills Reference](../core/agents-and-skills-reference.md) — the plan agent, the `explore` subagent, and the `task` tool in depth
- [Context Engineering](../core/context-engineering.md) — what the agent actually sees while it explores your codebase
- [Memory Systems](../core/memory-systems.md) — how a chosen approach survives across sessions
