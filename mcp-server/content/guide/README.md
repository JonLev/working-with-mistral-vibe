---
title: "Guide Index"
description: "Index of the working-with-mistral-vibe guide tree with reading times and page status"
tags: [meta, index]
---

# Guide Index

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Core theory, mechanics catalogs, surfaces, workflows, security, ops, roles,
> the learning path, and the satellites (monolith spine, cheatsheet, diagrams,
> quiz, translations, MCP server) are complete.

Reading times assume ~200 words per minute and are refreshed when the index
is updated. Mechanics claims anywhere in the tree cite the oracle,
[`docs/mechanics/verified-mechanics.md`](../docs/mechanics/verified-mechanics.md).

## Guide pages

| Page | What it is | Reading time | Status |
|---|---|---|---|
| [Style Guide](style-guide.md) | Voice, page contract, mechanics discipline, naming policy | 6 min | Complete |
| [Guide Index](README.md) | This page | 2 min | Updated with content changes |
| [Context Engineering](core/context-engineering.md) | Context budget, instruction hierarchy, team assembly, lifecycle, audits | 47 min | Complete |
| [Agent Harness](core/agent-harness.md) | Harness taxonomy, nine components, security, observability | 20 min | Complete |
| [Loop and Graph Engineering](core/loop-graph-engineering.md) | Loop and graph contracts, durability, judgment allocation | 18 min | Complete |
| [Methodologies](core/methodologies.md) | Fifteen AI-assisted development methodologies, spec writing | 19 min | Complete |
| [Memory Systems](core/memory-systems.md) | Three-track memory model, native stack, risks, decision frameworks | 24 min | Complete |
| [Skill Design Patterns](core/skill-design-patterns.md) | Nine architecture patterns for skills, mechanics rebuilt from Vibe | 22 min | Complete |
| [Architecture](core/architecture.md) | How the Vibe CLI works: loop, tools, compaction, subagents, trust | 26 min | Complete |
| [Glossary](core/glossary.md) | Universal agentic-coding terms and Vibe mechanics terms | 19 min | Complete |
| [Tools Reference](core/tools-reference.md) | Every built-in Vibe tool, permissions, enable/disable syntax | 25 min | Complete |
| [Settings Reference](core/settings-reference.md) | Every config.toml key, the eight-layer precedence stack | 31 min | Complete |
| [Hooks and Events Reference](core/hooks-events-reference.md) | hooks.toml wire protocol: 3 CLI events, decision contract, strict | 18 min | Complete |
| [Agents and Skills Reference](core/agents-and-skills-reference.md) | Agent TOML profiles, task tool, SKILL.md frontmatter, discovery | 22 min | Complete |
| [Plugins](core/plugins.md) | Agent Plugins 1.0 packages, import adapters, on-disk scopes | 15 min | Complete |
| [Learning Path](learning-path/README.md) | Seven-module curriculum entry: module table, four tracks, FAQ | 17 min | Complete |
| [Module 01 — Installation and First Run](learning-path/01-installation.md) | Install, trust prompt, first session, diff-review habit | 18 min | Complete |
| [Module 02 — The Core Loop](learning-path/02-core-loop.md) | Seven-step loop, WHAT/WHERE/HOW/VERIFY, compaction, sessions | 19 min | Complete |
| [Module 03 — Memory and Config](learning-path/03-memory.md) | AGENTS.md hierarchy, config.toml layering, system-prompt replacement | 20 min | Complete |
| [Module 04 — Agents](learning-path/04-agents.md) | Agent TOML profiles, tool restriction, task delegation | 21 min | Complete |
| [Module 05 — Skills](learning-path/05-skills.md) | SKILL.md frontmatter, routing descriptions, progressive disclosure | 29 min | Complete |
| [Module 06 — Hooks](learning-path/06-hooks.md) | hooks.toml, stdout JSON decisions, strict, fixture testing | 22 min | Complete |
| [Module 07 — Advanced Orchestration](learning-path/07-advanced.md) | Subagent orchestration, approval gates, worktrees, /loop, budgets | 30 min | Complete |
| [Workflows Index](workflows/README.md) | Selection table for the ten core workflows | 3 min | Complete |
| [Test-Driven Development](workflows/tdd.md) | Red-green-refactor with explicit prompting, verification gap | 14 min | Complete |
| [Spec-First](workflows/spec-first.md) | Specs as contracts before implementation, PRD quality checklist | 18 min | Complete |
| [RPI: Research-Plan-Implement](workflows/rpi.md) | GO/NO-GO gates between phases, phase artifacts as skills | 24 min | Complete |
| [Exploration](workflows/exploration.md) | Anti-anchoring, N approaches, quantified trade-offs | 9 min | Complete |
| [Production Reliability](workflows/production-reliability.md) | Escalation, circuit breakers, structured errors, handoff | 24 min | Complete |
| [Best-of-N](workflows/best-of-n.md) | Generate/select/verify with a frozen rubric, evidence boundary | 7 min | Complete |
| [Iterative Refinement](workflows/iterative-refinement.md) | Prompt-observe-reprompt, bounded auto-loops, quality gates | 21 min | Complete |
| [Task Management](workflows/task-management.md) | Session lifecycle protocol, file-based task convention, resume | 17 min | Complete |
| [Changelog Fragments](workflows/changelog-fragments.md) | Three-layer per-PR documentation enforcement | 8 min | Complete |
| [Event-Driven Agents](workflows/event-driven-agents.md) | External events trigger bounded headless runs, guardrails | 12 min | Complete |
| [Security Hardening](security/security-hardening.md) | Threat model, trust gate, hooks as guards, MCP vetting, governance tiers | 27 min | Complete |
| [Production Safety](security/production-safety.md) | Six production rules, CI guardrail stack, budgets, headless auto-DENY | 19 min | Complete |
| [Data Privacy](security/data-privacy.md) | What leaves the machine: egress inventory, risks, opt-outs, audit | 17 min | Complete |
| [Observability](ops/observability.md) | Session store, meta.json fields, hook loggers, OTel, cost method | 15 min | Complete |
| [AI Traceability](ops/ai-traceability.md) | Commit attribution (none by default), disclosure spectrum, industry policies | 30 min | Complete |
| [Team Metrics](ops/team-metrics.md) | DORA and SPACE in an AI-augmented context, agentic metrics, Vibe surfaces | 43 min | Complete |
| [Automation](ops/automation.md) | Programmatic mode for CI, budgets, scheduled `/loop` recurrence | 10 min | Complete |
| [AI Roles](roles/ai-roles.md) | Twenty-three role profiles, ownership-boundary career map, compensation evidence | 51 min | Complete |
| [Learning to Code with AI](roles/learning-with-ai.md) | The UVAL protocol against dependency, learning-mode Vibe configuration | 63 min | Complete |
| [Adoption Approaches](roles/adoption-approaches.md) | Decision tree, L0-L5 maturity, J-curve, pay-for portfolio exercise | 28 min | Complete |
| [The Vibe CLI](surfaces/cli.md) | The baseline surface: install, TUI vs programmatic mode with auto-DENY, agents, worktrees, sessions, when to pick it | 12 min | Complete |
| [Vibe Code Desktop App](surfaces/desktop.md) | The Electron macOS client and its bundled-harness session runtime; Work/Code modes, local/worktree/cloud sessions, subagent side panel; pinned to the inspected bundle | 12 min | Complete |
| [Vibe Code Web](surfaces/web.md) | The cloud surface: /teleport, &, /remote-project, the cloud session model, limits, sandbox — [docs-only] claims tagged | 10 min | Complete |
| [Migrating from Claude Code](surfaces/migrating-from-claude-code.md) | Concept-by-concept port of an existing agentic-CLI setup: what renames, what re-derives, what does not transfer | 11 min | Complete |
| [Monolith Spine](vibe-guide.md) | Twelve delegation-only chapters routing every topic to its deep-dive page; generated, cannot drift | 12 min | Complete |
| [Cheatsheet](cheatsheet.md) | Daily-reference tables: commands, flags, keys, modes, context, CI — every row oracle-cited | 23 min | Complete |
| [Translations and Language Adaptations](translations.md) | The language policy: English canonical, community adaptations under a provenance contract | 4 min | Complete |
| [Vibe Releases and Guide Re-verification](releases.md) | The release-tracking page: dated rows per CLI release, oracle re-verification status, banner re-stamp dates | 5 min | Complete |
| [Diagrams Index](diagrams/README.md) | Palette and shape conventions, navigation, use-case entry points for the 47-diagram set | 5 min | Complete |
| [Foundations Diagrams](diagrams/01-foundations.md) | 4-layer prompt assembly, turn loop, use-it decision tree, agent modes | 9 min | Complete |
| [Context and Sessions Diagrams](diagrams/02-context-and-sessions.md) | Compaction trigger model, AGENTS.md memory hierarchy, session continuity, fresh-context anti-pattern | 8 min | Complete |
| [Configuration System Diagrams](diagrams/03-configuration-system.md) | Eight-layer config stack, skills vs commands vs agents, agent lifecycle, hooks pipeline | 9 min | Complete |
| [Architecture Internals Diagrams](diagrams/04-architecture-internals.md) | Agent loop, tool families, system prompt assembly, subagent isolation | 8 min | Complete |
| [MCP Ecosystem Diagrams](diagrams/05-mcp-ecosystem.md) | Verified MCP surface, client-server protocol, rug-pull attack chain, config hierarchy | 8 min | Complete |
| [Development Workflows Diagrams](diagrams/06-development-workflows.md) | TDD cycle, spec-first pipeline, plan-driven workflow, iterative refinement, output fork | 12 min | Complete |
| [Multi-Agent Patterns Diagrams](diagrams/07-multi-agent-patterns.md) | Orchestration topologies, worktree multi-instance, dual-session, scaling, decision matrix | 10 min | Complete |
| [Security and Production Diagrams](diagrams/08-security-and-production.md) | 3-layer defense, isolation tree (no OS sandbox), verification paradox, CI/CD pipeline | 8 min | Complete |
| [Cost and Optimization Diagrams](diagrams/09-cost-and-optimization.md) | Model selection flow, cost-optimization tree, token-reduction pipeline | 7 min | Complete |
| [Adoption and Learning Diagrams](diagrams/10-adoption-and-learning.md) | Onboarding paths, UVAL protocol, trust calibration | 6 min | Complete |
| [Context Engineering Diagrams](diagrams/11-context-engineering.md) | 3-layer context system, adherence degradation, scoped files, rule placement | 8 min | Complete |
| [Enterprise Governance Diagrams](diagrams/12-enterprise-governance.md) | Governance risk tiers, MCP approval workflow, data classification | 7 min | Complete |

## Directory map

| Directory | Purpose | Status |
|---|---|---|
| `core/` | Theory deep dives and mechanics catalogs | Complete |
| `workflows/` | Step-by-step workflows | Complete |
| `security/` | Hardening and production safety | Complete |
| `ops/` | Observability, traceability, team metrics | Complete |
| `roles/` | Working with AI by role, adoption | Complete |
| `surfaces/` | CLI, desktop, web chapters; migration chapter | Complete |
| `learning-path/` | Seven-module curriculum | Complete |
| `diagrams/` | 47 Mermaid diagrams with ASCII fallbacks, re-labeled for Vibe | Complete |
| `images/` | The one ported editorial infographic (deployment paths), embedded from Adoption Approaches | Complete |

## Satellites

| Location | Purpose | Status |
|---|---|---|
| [Quiz](../quiz/README.md) | 123 oracle-grounded questions in nine topic files, schema-validated in CI | Complete |
| `machine-readable/` | Generated `reference.yaml` for LLM consumption, plus the translations registry | Complete |
| `examples/` | Installable templates: agents, skills, hooks, commands | Complete |
| `mcp-server/` | npm MCP server serving the guide pages and the reference index as tools; MIT code, CC BY-SA content | Complete (publishing pending) |
| [Monolith Spine](vibe-guide.md) | The delegation-only chapter map, generated | Complete |

## Known gaps

- **Desktop and web surfaces move faster than this guide.** The surfaces
  chapters pin every claim to the artifact it was verified against: the desktop
  chapter to the inspected app bundle (0.12.0 per the oracle, 0.14.0 installed
  at re-inspection) and the web chapter to docs fetched 2026-09-24, tagged
  [docs-only] throughout. Re-verify both on every app release; each page
  carries its own Known gaps.
- The four source pages known-issues, release history, credits, and
  translations are deliberately not ported as such: the translations policy
  is [its own page](translations.md), and release history is replaced by the
  [Vibe releases tracking page](releases.md) with its re-verification
  trigger. The source's third-party tool survey
  page is also deliberately not ported, and Vibe has no OS-level
  sandbox, so no sandbox-native page exists — the manual isolation patterns
  live in [Security Hardening](security/security-hardening.md) and the
  [isolation diagram](diagrams/08-security-and-production.md).
- Two source diagrams were dropped in the port for lack of a
  verified Vibe mechanic: the subscription-tiers diagram (vendor pricing)
  and the cross-session-messaging diagram — recorded in the
  [diagrams index](diagrams/README.md).
- Reading times are computed by hand at index-update time; no automation
  checks them yet.
