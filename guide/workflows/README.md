---
title: "Agentic-Coding Workflows"
description: "Step-by-step guides for common development patterns with the Vibe CLI: prompting discipline, planning gates, verification loops, and automation"
tags: [workflow, guide, index]
---

# Agentic-Coding Workflows

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

**TL;DR**: Ten recipe pages, one per recurring job: explore before you implement, gate research and planning before code, test before you write, verify before you trust, and document before you merge. The prompting discipline is tool-agnostic; where a recipe touches Vibe mechanics — programmatic mode, hooks, agents, worktrees, `/loop` — it cites the verified surface, and automation always runs headless with explicit budgets.

*Read if you want a proven recipe for a specific kind of work instead of inventing a prompt sequence per task. Skip if you want the mechanics reference first — start with [methodologies](../core/methodologies.md) and come back when you need concrete runs.*

---

## Folder Map

Three groups, ordered by how soon a new team needs them:

- **Discipline first** — [exploration](exploration.md), [rpi](rpi.md), [spec-first](spec-first.md), [tdd](tdd.md): constrain the agent before it writes code.
- **Quality loops** — [iterative-refinement](iterative-refinement.md), [best-of-n](best-of-n.md), [production-reliability](production-reliability.md): improve, compare, and harden what exists.
- **Operations** — [task-management](task-management.md), [changelog-fragments](changelog-fragments.md), [event-driven-agents](event-driven-agents.md): track, document, and automate across sessions and events.

Every page follows the same template: the problem, the cycle, anti-patterns, and Known gaps.

---

## Quick Selection Guide

| Workflow | Problem it solves | Read if / Skip if |
|---|---|---|
| [Exploration](exploration.md) | The agent anchors on its first proposed design before alternatives are considered | Read if you are entering an unfamiliar codebase or an ambiguous feature. Skip if the approach is already decided and validated. |
| [RPI: Research → Plan → Implement](rpi.md) | Wrong assumptions surface after days of implementation instead of hours | Read if feasibility is unknown or the feature spans more than a day. Skip if the change is small and well understood. |
| [Spec-First Development](spec-first.md) | Requirements mutate mid-implementation because nobody wrote them down | Read if the feature needs team alignment or a documentation-first trail. Skip for a one-file fix with an obvious shape. |
| [TDD](tdd.md) | The agent writes code first and tests to match, so the tests prove nothing | Read if the functionality is critical or regression-prone. Skip for throwaway prototypes and pure refactors with an existing suite. |
| [Iterative Refinement](iterative-refinement.md) | One-shot prompts leave mediocre output on the table | Read if quality matters more than latency and you can afford review cycles. Skip if the first acceptable answer is the goal. |
| [Best-of-N](best-of-n.md) | Several plausible solutions exist with material trade-offs and you cannot see them from one sample | Read if you have a stable rubric and a reviewer or executable check that can rank candidates. Skip if there is one obvious approach. |
| [Production Reliability](production-reliability.md) | Long agentic runs fail silently, loop forever, or hand off garbage to a human | Read if your agents operate near production or unattended. Skip if a human watches every turn. |
| [Task Management](task-management.md) | Multi-session work loses state between sessions | Read if tasks span days and multiple sessions or a team. Skip for single-session tasks that fit in one context window. |
| [Changelog Fragments](changelog-fragments.md) | Release notes are reconstructed weeks after the code merged, under time pressure | Read if your team ships frequently from an active main branch. Skip if you are the sole author and release manager. |
| [Event-Driven Agents](event-driven-agents.md) | A human types every prompt, even for routine, well-specified trigger events | Read if tickets, alerts, or CI events should start bounded, guarded runs. Skip if all your work is hand-steered and interactive. |

---

## Where the mechanics live

The recipes stay light on mechanics by design; each links out at the point of use. The reference homes:

- [Development Methodologies Reference](../core/methodologies.md) — which methodology fits which job, mapped onto Vibe's actual mechanisms
- [Memory Systems](../core/memory-systems.md) — the `AGENTS.md` instruction hierarchy every discipline-first recipe leans on
- [Hooks and Events Reference](../core/hooks-events-reference.md) — the three hook events and the decision contract behind every guardrail
- [Agents and Skills Reference](../core/agents-and-skills-reference.md) — agent profiles, the `task` tool, and skills
- [Settings Reference](../core/settings-reference.md) — `config.toml` keys for tools, agents, and permissions
- [Loop & Graph Engineering](../core/loop-graph-engineering.md) — the control-contract discipline behind automated loops
- [Context Engineering](../core/context-engineering.md) — what the model sees, and why that decides the run

The learning path builds the same material as a course: [core loop](../learning-path/02-core-loop.md), [memory](../learning-path/03-memory.md), [agents](../learning-path/04-agents.md), [skills](../learning-path/05-skills.md), [hooks](../learning-path/06-hooks.md), [advanced](../learning-path/07-advanced.md).

---

## Workflow Template Structure

New recipe pages follow the source guide's template, adapted to this guide's page contract:

1. YAML frontmatter, the verification banner, a TL;DR block, and a *Read if / Skip if* routing line
2. The Problem — the failure mode the workflow exists to prevent
3. The Cycle — the repeating loop, with prompts as italic user-voice quotes and mechanics cited to the verified surface
4. Anti-Patterns — a table of wrong moves and their corrections
5. See also and Known gaps — what this page does not cover, and what does not exist yet

---

## Known gaps

- **Ten workflows, not thirty.** Source-guide topics that document product surfaces with no verified Vibe equivalent are intentionally absent; everything that exists in this folder is listed above.
- **Recipes assume the stable backend.** Where a recipe depends on unified-harness-only behavior, the page tags it; the shared banner documents the release surface (2.25.8) against a live-verified baseline of 2.25.0.
- **No CI-integration recipe yet.** Event-driven automation and the CI gate in [changelog-fragments](changelog-fragments.md) cover the patterns; a dedicated CI-platform recipe would need its own verification pass.
