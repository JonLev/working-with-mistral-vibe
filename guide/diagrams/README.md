---
title: "Vibe: Visual Diagrams"
description: "Interactive Mermaid diagrams of the verified Vibe CLI mechanics, organized in 12 thematic files: foundations, context and sessions, configuration, architecture, MCP, workflows, multi-session patterns, security, cost, adoption, context engineering, and governance — each with an ASCII fallback"
tags: [reference, architecture, diagrams, mermaid]
---

# Vibe: Visual Diagrams

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Interactive Mermaid diagrams of the Vibe CLI's verified mechanics, organized
in 12 thematic files. Each diagram includes a Mermaid version (rendered
natively on GitHub) and an ASCII fallback. Every mechanic is rebuilt from the
mechanics oracle — nothing is transliterated from another product's guide.

> **TL;DR.** This directory is the visual index of the guide: 12 diagram
> files plus this README. Start at
> [Foundations](./01-foundations.md) if you are new,
> [Architecture Internals](./04-architecture-internals.md) for the loop and
> its seams, or jump by use case in the table below. Diagrams that depict a
> mechanic the oracle does not verify were dropped, not re-labeled — see each
> file's Known gaps.

**Read if** you want one picture before (or instead of) the prose pages.
**Skip if** you want recipes; the
[workflows](../workflows/README.md) are the practical entry.

---

## Visual Palette

All diagrams use one consistent palette:

| Color | Hex | Usage |
|-------|-----|-------|
| Warm Beige | `#F5E6D3` | User actions, input nodes |
| Orange Brulee | `#E87E2F` | Key decisions, product actions |
| Soft Green | `#7BC47F` | Success paths, recommendations |
| Alert Red | `#E85D5D` | Danger, anti-patterns, risks |
| Neutral Gray | `#B8B8B8` | Infrastructure, passive elements |
| Light Blue | `#6DB3F2` | Information, documentation refs |

## Mermaid Conventions

| Shape | Syntax | Meaning |
|-------|--------|---------|
| Rounded rect | `(text)` | Process step, action |
| Diamond | `{text}` | Decision point |
| Stadium | `([text])` | Start / End terminal |
| Hexagon | `{{text}}` | External system or API |
| Subroutine | `[[text]]` | Internal Vibe CLI component |
| Cylinder | `[(text)]` | Data store, persistent state |

---

## Navigation

| File | Diagrams | Topics |
|------|----------|--------|
| [01-foundations.md](./01-foundations.md) | 4 | Prompt assembly, turn loop, decision tree, agent modes |
| [02-context-and-sessions.md](./02-context-and-sessions.md) | 4 | Compaction model, AGENTS.md hierarchy, session continuity, fresh context |
| [03-configuration-system.md](./03-configuration-system.md) | 4 | Config precedence, skills vs. agents vs. commands, agent lifecycle, hooks pipeline |
| [04-architecture-internals.md](./04-architecture-internals.md) | 4 | Agent loop, tool families, system prompt assembly, sub-agent isolation |
| [05-mcp-ecosystem.md](./05-mcp-ecosystem.md) | 4 | MCP surface, MCP architecture, rug pull attack, MCP config |
| [06-development-workflows.md](./06-development-workflows.md) | 5 | TDD cycle, spec-first pipeline, plan-driven workflow, iterative refinement, polished-output fork |
| [07-multi-agent-patterns.md](./07-multi-agent-patterns.md) | 5 | Orchestration topologies, worktrees, dual-session planning, horizontal scaling, decision matrix |
| [08-security-and-production.md](./08-security-and-production.md) | 4 | Defense layers, isolation decision, verification paradox, CI/CD pipeline |
| [09-cost-and-optimization.md](./09-cost-and-optimization.md) | 3 | Model selection, cost optimization, token reduction |
| [10-adoption-and-learning.md](./10-adoption-and-learning.md) | 3 | Onboarding paths, verification protocol, trust calibration |
| [11-context-engineering.md](./11-context-engineering.md) | 4 | Context layers, adherence degradation, modular architecture, rule placement |
| [12-enterprise-governance.md](./12-enterprise-governance.md) | 3 | Governance risk tiers, MCP approval workflow, data classification |
| **Total** | **47** | |

47 diagrams in 12 files, plus this index — 13 files in the directory. Two
source-guide diagrams were dropped during porting because the oracle does not
verify their mechanics (one in 07, one in 09); each drop is recorded in the
owning file's Known gaps.

---

## Navigate by Use Case

### "I'm new to the Vibe CLI, where do I start?"

1. [Quick Decision Tree](./01-foundations.md#quick-decision-tree-should-i-use-the-vibe-cli):
   Should I use the Vibe CLI?
2. [The Turn Loop](./01-foundations.md#the-turn-loop): How does a request
   actually run?
3. [Agent Modes Comparison](./01-foundations.md#agent-modes-comparison): What
   do the agent profiles approve automatically?
4. [Onboarding Adaptive Learning Paths](./10-adoption-and-learning.md#onboarding-adaptive-learning-paths):
   Which path fits me?

### "I want to understand the architecture"

1. [The Agent Loop](./04-architecture-internals.md#the-agent-loop): Core
   execution engine
2. [System Prompt Assembly](./04-architecture-internals.md#system-prompt-assembly):
   How the prompt is built
3. [Prompt Assembly: The Four-Layer Model](./01-foundations.md#prompt-assembly-the-four-layer-model):
   The transformation model
4. [Tool Families and Selection](./04-architecture-internals.md#tool-families-and-selection):
   What tools are available

### "I'm worried about security"

1. [MCP Rug Pull Attack Chain](./05-mcp-ecosystem.md#mcp-rug-pull-attack-chain):
   The main threat vector
2. [Security 3-Layer Defense Model](./08-security-and-production.md#security-3-layer-defense-model):
   How to protect yourself
3. [Isolation Decision Tree](./08-security-and-production.md#isolation-decision-tree):
   When to isolate
4. [The Verification Paradox](./08-security-and-production.md#the-verification-paradox):
   Don't trust the agent to verify itself

### "I want to reduce my token costs"

1. [Model Selection Decision Flow](./09-cost-and-optimization.md#model-selection-decision-flow):
   Pick the right model
2. [Cost Optimization Decision Tree](./09-cost-and-optimization.md#cost-optimization-decision-tree):
   Systematic cost reduction
3. [Token Reduction Strategies Pipeline](./09-cost-and-optimization.md#token-reduction-strategies-pipeline):
   Context hygiene and thresholds
4. [The Compaction Model](./02-context-and-sessions.md#the-compaction-model):
   Manage context size

### "I want to use multiple agents"

1. [Orchestration: 3 Topologies](./07-multi-agent-patterns.md#orchestration-3-topologies):
   Coordination patterns
2. [Multi-Session Decision Matrix](./07-multi-agent-patterns.md#multi-session-decision-matrix):
   Which pattern to use?
3. [Worktree Multi-Instance Pattern](./07-multi-agent-patterns.md#worktree-multi-instance-pattern):
   Parallel isolation
4. [Sub-Agent Context Isolation](./04-architecture-internals.md#sub-agent-context-isolation):
   How subagents are isolated

### "I want to set up MCP servers"

1. [The Vibe MCP Surface](./05-mcp-ecosystem.md#the-vibe-mcp-surface): What
   servers exist
2. [MCP Architecture: Client-Server Protocol](./05-mcp-ecosystem.md#mcp-architecture-client-server-protocol):
   How it works
3. [MCP Config Hierarchy](./05-mcp-ecosystem.md#mcp-config-hierarchy): Where
   configs live

### "I want to govern the Vibe CLI across my team"

1. [Governance Risk Tiers: What to Control and When](./12-enterprise-governance.md#governance-risk-tiers-what-to-control-and-when):
   Which control level fits your context?
2. [MCP Governance Workflow](./12-enterprise-governance.md#mcp-governance-workflow):
   Approval pipeline for MCP servers
3. [Data Classification and Vibe Access Rules](./12-enterprise-governance.md#data-classification-and-vibe-access-rules):
   What the agent can and cannot access
4. [Choosing Your Adoption Approach](../roles/adoption-approaches.md#decision-tree):
   Team-size and rollout guidance

### "I want to improve the agent's context adherence"

1. [Rule Placement Decision Tree](./11-context-engineering.md#rule-placement-decision-tree):
   Where does this rule go?
2. [The 3-Layer Context System](./11-context-engineering.md#the-3-layer-context-system):
   User / project / session
3. [Context Budget and Adherence Degradation](./11-context-engineering.md#context-budget-and-adherence-degradation):
   Why rules stop being followed
4. [Monolithic vs. Modular Instruction Architecture](./11-context-engineering.md#monolithic-vs-modular-instruction-architecture):
   Path-scoping as the fix

---

## Known gaps

- **Dropped diagrams.** The source guide's cross-session messaging diagram
  (no verified registry or inbox mechanic; see
  [07](./07-multi-agent-patterns.md#known-gaps)) and its subscription-tiers
  diagram (no Vibe billing surface; see
  [09](./09-cost-and-optimization.md#known-gaps)) were not ported.
- **Unified-Harness surfaces are mostly not diagrammed.** The six typed
  harness hook points and the plugin system are experimental, backend-gated
  mechanics; the diagrams here stick to the stable CLI surface (see
  [Hooks and Events Reference](../core/hooks-events-reference.md#unified-harness-hook-points-unified-harness)).
- **No ASCII-only visual reference page.** The source guide keeps a separate
  printable ASCII collection; this repo has none, and each diagram's
  `<details>` fallback is the only ASCII form.
- **Diagram counts track the files as shipped.** If a porting package drops
  or reshapes a diagram, this index's table is the place that total is
  stated; the source guide's totals do not apply.

---

Back to [guide/README.md](../README.md)
