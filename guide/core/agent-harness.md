---
title: "Agent Harness Engineering"
description: "The runtime harness as an engineering discipline: the four-layer taxonomy, nine components, the lethal-trifecta security model, CI/CD and verification patterns, and a concrete Vibe CLI checkpoint."
tags: [guide, agents, architecture, security, observability]
---

# Agent Harness Engineering

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Every command, flag, config key, file path, and payload field here cites the mechanics oracle, [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as `(PART-XXX)`. Claims marked *live-verified on 2.25.0* were executed against the installed CLI; the rest are source-verified at release 2.25.8. Backend tags `[stable]` / `[unified-harness]` mark where the session backend changes the mechanic.

> **TL;DR.** A raw LLM is not an agent; it becomes one when a harness supplies the loop, context, tools, state, permissions, and verification around it. The unit you evaluate is the **model-harness pair**, never the model alone. This page gives the four-layer taxonomy, the nine runtime components, a security model (the lethal trifecta), and the verification and observability patterns that make an agent trustworthy — each grounded in Vibe's actual surface.

**Read if** you design, evaluate, or harden agent infrastructure. **Skip if** you want usage recipes only — the [workflows pages](../workflows/README.md) cover those.

## The core claim

A harness owns the agent loop, tools, context, state, and permissions. Surveys decompose it into observation, context, control, action, state, and verification; *Code as Agent Harness* (arXiv 2605.18747) adds that code itself is the executable substrate for tools, memory, and control. Taxonomies, not performance proofs.

The controlled evidence is narrower: *The Scaffold Effect in Coding Agents* (arXiv 2607.22585) ran two fixed models across three harnesses on 50 Terminal-Bench Pro tasks. Harness choice moved tokens per solved task by up to 40x, while paired pass-rate differences stayed within 0-8 percentage points and were mostly not significant. The harness dominates cost and failure behavior without dominating accuracy; model-harness compatibility can still bind. Report the pair, the task set, and the budget.

This page uses **agent harness** in its runtime sense. A repository can add a **repository harness** around it — instructions, setup, task state, and verification gates committed with the code. The split is practical: a project improves its repository harness without switching runtimes, and switches runtimes without discarding project practice. Loop, graph, and judgment design is a separate page: [Loop & Graph Engineering](./loop-graph-engineering.md).

## 0. Four layers, four responsibilities

| Layer | Responsibility | Examples | What it does not replace |
|-------|----------------|----------|--------------------------|
| **Model** | Generates and reasons over tokens | `mistral-medium`, `devstral`, any configured provider model (PART-CONFIG section 1.1) | Tools, policy, durable state, execution |
| **Runtime harness** | Runs the agent loop; mediates tools, context, permissions, recovery | Vibe CLI, other terminal coding agents | Project-specific instructions and delivery gates |
| **Repository harness** | Makes one codebase legible and verifiable to a runtime | `AGENTS.md`, setup scripts, lockfiles, task state, tests (PART-AGENTSMD) | The runtime's model routing, tool loop, approval gates |
| **Orchestrator** | Coordinates multiple runs, workspaces, or harnesses | Fleet schedulers, workspace managers, control planes | The underlying runtime agent loop |

The boundary test: a product that only schedules or inspects another runtime's sessions is an orchestrator; one that supplies the model-and-tools loop itself is a runtime harness; something committed with the repository that tells any compatible runtime how to work safely is a repository harness. Products can span two layers without collapsing the taxonomy.

**Meta-harness** is overloaded. In the optimizer-research sense it proposes changes to a target harness, evaluates candidates, and promotes or rejects versions. A client that merely dispatches tasks to existing harnesses is an orchestrator, not an optimizer.

| View | Primary question | Core artifact |
|------|------------------|---------------|
| **Loop engineering** | What feedback repeats, and what stops it? | Goal, action, observation, verification, stopping rule |
| **Graph engineering** | Which nodes, edges, transitions, checkpoints are executable? | Versioned workflow graph and shared state schema |
| **Harness engineering** | What context, tools, policy, state, verification bound execution? | Runtime and repository controls |
| **Orchestration** | How are runs, workspaces, budgets, people coordinated? | Scheduler or control plane |

A loop can be encoded as a graph; a harness executes either while adding permissions and verification; an orchestrator schedules harnesses without owning their loops. Compare products inside the same layer before comparing feature counts. See [Loop & Graph Engineering](./loop-graph-engineering.md).

## 1. Three foundational properties

- **Executability.** The harness verifies what the agent actually did, not what it said it did. Tool calls produce recorded effects; every message lands in the session's `messages.jsonl` (PART-SESSIONS section 3.1). A wrapper that logs prompts and completions cannot tell a successful tool call from a hallucinated one.
- **Inspectability.** Failures produce actionable diagnostics. Vibe writes a rotating log at `$VIBE_HOME/logs/vibe.log` (`LOG_LEVEL`, `LOG_MAX_BYTES`; PART-CLI), and hook invocations receive `session_id`, `transcript_path`, and `cwd` (PART-HOOKS section 3.2), so instrumentation points at the exact transcript.
- **Statefulness.** Continuity lives outside the context window: each session persists as `meta.json` + `messages.jsonl` under `$VIBE_HOME/logs/session/`, resumable by ID (globally, partial IDs accepted) or by continue (per-terminal pointer, latest in the working directory) (PART-SESSIONS sections 3.1-3.3). Once sessions outlive context resets, statefulness stops being optional.

## 2. The nine components

The structure works as an evaluation checklist; Vibe's mapping follows each component and is summarized in the [checkpoint](#vibe-implementation-checkpoint).

### 2.1 While-loop engine

Perceive (context, tool outputs, latest instruction), plan (LLM call), act (execute tools). Failure modes: uncapped iterations, mishandled malformed tool calls, unbounded context growth. Vibe's programmatic mode hard-caps all three: `--max-turns N`, `--max-price DOLLARS`, `--max-tokens N` apply in `-p` mode and interrupt the session when exceeded (PART-CLI).

| Horizon | Boundary | Typical controls | Where it usually lives |
|---|---|---|---|
| **Inner loop** | One agent run | Tool results, targeted tests, local checks | Runtime plus repository harness |
| **Outer loop** | Task or pull request | Full suites, deeper review, independent verifiers | Repository harness plus CI |
| **Meta loop** | Across many runs | Failure mining, rule and verifier updates | Team process |

A review comment that recurs should become a test, rule, instruction file, hook, or verifier at the earliest loop that can catch it — never a repeated prompt. Build one bounded loop before adding autonomous layers: autonomy expanding faster than verification is the documented failure mode of lights-off setups. The only in-session recurrence primitive in Vibe is `/loop`: fixed interval (minimum 30 s), max 50 per session, fires only when no turn is active, survives resume (PART-SESSIONS section 5).

### 2.2 Context management

What enters the prompt each iteration: history, tool outputs, task state, instructions. Strategies: compaction, sliding window, retrieval. Vibe grounds the first in config: `auto_compact_threshold` (default 200,000 tokens; per-model override; `0` disables) triggers compaction before a turn when usage crosses the threshold; `/compact [instructions]` compacts on demand with an optional custom `compaction_prompt_id`; a context-warning middleware warns once at 50% of the threshold (PART-SESSIONS section 4). The threshold is per-model tunable — do not design around a fixed window number.

### 2.3 Tool registry

The catalog of tools with name, schema, permission posture. A static registry loads every schema on every call; a dynamic one loads what the task needs. Forty schemas when the model needs four add noise and cost. Vibe filters the registry with globs or `re:` regex: a non-empty `enabled_tools` leaves only matching tools active, `disabled_tools` removes after that, `tool_paths` adds custom-tool directories (PART-CONFIG section 1.3).

### 2.4 Sub-agent management

Delegation to specialized agents with their own context and bounded scope; the worker never sees the parent's full context. Vibe's entire delegation surface is the `task` tool: `TaskArgs(task, agent)`, `agent` defaulting to `"explore"` (PART-AGENTS section 9). Constraints that shape design: only `agent_type = "subagent"` profiles spawn; depth is capped at 1 (subagents cannot spawn subagents); results are text-only (`TaskResult(response, turns_used, completed)`), summarized by the parent; child sessions persist under the parent's `agents/` directory and are resumable; the child inherits the parent's permission store. Plan hub-and-spoke, never trees.

### 2.5 Native tools and loadable skills

Native tools are runtime operations (files, search, shell, web, delegation). Skills are loadable instruction modules invoked through a tool. A skill can bundle deterministic scripts, but the skill itself is not deterministic: the model still interprets its instructions. Test the scripts with ordinary assertions; test the model-mediated part behaviorally.

### 2.6 Session persistence

State that survives context resets — the agent reconstructs its position from externalized artifacts, not in-context history. In Vibe, each session directory holds `meta.json` (session id, git commit and branch, pinned model, loops, title) and `messages.jsonl`; the first user message pins the resolved `active_model`, so resume keeps the model even if the default changed (PART-SESSIONS sections 3.1, 3.5). Resume restores the transcript, not your acceptance criteria — persist the requirement map and evidence separately. See [Memory Systems](./memory-systems.md).

### 2.7 Dynamic prompt assembly

The step that turns state (task + context + tool definitions + instructions) into the actual prompt. Assembly fails through conflicting rule injection, overlapping tool schemas, stale retrieved context. Harnesses that log the assembled prompt, not just the response, are far easier to debug. Vibe's instruction layer is explicit and hierarchical: `~/.vibe/AGENTS.md` (user, always loaded), project `AGENTS.md` files walking up from each project root to its trust root, subdirectory `AGENTS.md` files injected lazily when a file beneath them is read; priority is project over user, closer directory over distant, and these instructions override default behavior (PART-AGENTSMD).

### 2.8 Lifecycle hooks

Injection points at defined runtime events — where you add audit logging, permission validation, output sanitization, metrics. Only hooks with documented blocking semantics can stop an action.

Vibe's CLI hook surface has exactly three events, wire protocol `[stable]`: `pre_tool` (before the approval prompt; first deny short-circuits), `post_tool` (iff the tool body ran), `post_agent` (once per turn; `match`/`strict` forbidden on it) (PART-HOOKS section 1). Hooks are shell commands: JSON payload on stdin, decision JSON on stdout (`decision: allow|deny`, `reason`; `tool_input` rewrite on `pre_tool`, `additional_context` on `post_tool`), 60 s default timeout, 1 MiB stdout cap (PART-HOOKS sections 2-3). Two semantics to design around: `post_agent` deny injects a retry user message, max 3 retries per turn (PART-HOOKS section 3.7); and hooks **fail open** — a failed hook lets the gated action proceed unless the tool hook sets `strict = true`, which escalates failure to deny (PART-HOOKS section 3.3). A hook is not a hard boundary until you opt into strict. There are no pre-LLM or post-LLM hooks on this surface; the Unified Harness separately declares six typed points — `pre_agent_turn`, `post_agent_turn`, `pre_llm_call`, `post_llm_call`, `pre_tool_call`, `post_tool_call` — `[unified-harness]` only (PART-HOOKS-UNIFIED section 6). Two surfaces, never one list.

### 2.9 Permission enforcement

Every consequential action needs an enforcement boundary before execution. Approval prompts alone are not an isolation strategy. Vibe's boundary has four parts:

1. **Agent profiles** replace permission modes: `ask` (approval for everything not allowlisted), `plan` (read-only; `write_file`/`edit` permission `never` plus a plans-directory allowlist), `accept-edits` (default; file tools auto-approve), `auto-approve` (bypasses per-call checks), cycled with Shift+Tab in the order `ask → plan → accept-edits → auto-approve` (PART-PERMISSIONS section 4.1; PART-AGENTS section 7).
2. **Per-tool rules**: `[tools.<name>]` sets `permission` (`ask`/`always`/`never`) plus `allowlist`/`denylist` (PART-PERMISSIONS section 4.5). Bash matches command prefixes with `denylist_standalone` and `sensitive_patterns` (default `["sudo"]`); `find -exec` always asks; file tools check denylist globs first, then allowlist globs, then sensitive patterns (`**/.env*`), then flag paths outside the workspace for approval (PART-PERMISSIONS sections 4.3-4.4).
3. **The trust model**: project config, hooks, and instructions load only from trusted roots; `trusted_folders.toml` records explicit decisions and the closest ancestor wins; `--trust` and `--worktree` grant session-only, in-memory trust; untrusted folders still work but contribute no configuration (PART-TRUST sections 3.1-3.5). This is the load-bearing defense against a poisoned repository: an untrusted clone's `AGENTS.md` and `.vibe/` are ignored.
4. **Isolation**: `--worktree [NAME]` checks out an isolated worktree under `$VIBE_HOME/worktrees/` on its own branch, trusted for the session (PART-WORKTREES). Vibe ships no OS-level sandbox — no container, VM, or network-policy layer exists in its documented surface. A worktree is a filesystem boundary for concurrent work, not a security sandbox; hard isolation comes from the environment you run Vibe in.

### Vibe implementation checkpoint

| Harness concern | Vibe mechanism | Oracle |
|---|---|---|
| Context and state | `auto_compact_threshold` (200k default, per-model, `0` off), `/compact [instructions]`, `compaction_prompt_id`; session store `meta.json` + `messages.jsonl`, `-c`/`--resume` | PART-SESSIONS sections 3-4 |
| Instruction assembly | `AGENTS.md` hierarchy: user always, project root-to-trust-root, lazy subdirectory files; project over user, closer wins | PART-AGENTSMD |
| Tool surface | `enabled_tools`/`disabled_tools` (glob, `re:`), `tool_paths`; layered `config.toml`: defaults < experiments < user < project < `VIBE_*` env < session overrides < agent profile < admin | PART-CONFIG sections 1.3, 2.1 |
| Delegation | `task` tool, default `explore`, depth limit 1, text-only `TaskResult`, child sessions persisted and resumable | PART-AGENTS section 9 |
| Isolation and policy | `trusted_folders.toml` + session-only `--trust`/`--worktree` grants; agent profiles; per-tool `ask`/`always`/`never` with prefix and glob lists; worktrees under `$VIBE_HOME/worktrees/`. No OS sandbox | PART-TRUST; PART-PERMISSIONS; PART-WORKTREES |
| Headless and CI | `-p` with `--max-turns`/`--max-price`/`--max-tokens`, `--output json\|streaming`; approval-required calls auto-DENIED (live-verified on 2.25.0); `ask_user_question` and `exit_plan_mode` force-disabled | PART-CLI; PART-TRUST section 3.4 |
| Inspection and control | `hooks.toml`: three events, fail-open unless `strict = true` `[stable]`; six typed hook points `[unified-harness]`; OTel export (`enable_otel`, `otel_endpoint`, `otel_redaction`) | PART-HOOKS; PART-HOOKS-UNIFIED section 6; PART-CONFIG section 1.8 |

One guard worth knowing: the agent-profile config layer strips `vibe_base_url` and related fields from any profile override, so a custom agent TOML cannot redirect API traffic (PART-CONFIG section 2.3).

## 3. The lethal trifecta: security model

Coined by Simon Willison (2025):

**Private data + untrusted content + external communication = documented exfiltration vector.**

Any two legs are manageable. All three, without structural isolation, give an attacker a path: plant instructions in data the agent reads (a doc, a code comment, a ticket), let the agent process them with its access to private data, then exfiltrate through its communication tools. Prompt injection via repository content is documented in the wild. The defense is structural, not prompt engineering. AgentDojo (arXiv 2406.13352) makes the threat measurable; CaMeL (arXiv 2503.18813) separates trusted control flow from untrusted data flow with capabilities enforced at call time — 77% task success with provable security versus 84% undefended. Security has a utility cost, paid outside the model.

| Defense layer | Mechanism | Where it sits in Vibe |
|-------|-----------|----------------------|
| Network isolation | Egress allowlist outside the agent | Not shipped; provide via container, VM, or proxy in the execution environment |
| Filesystem isolation | Writes confined to a scratch checkout | `--worktree` under `$VIBE_HOME/worktrees/` (PART-WORKTREES); untrusted roots contribute no config or instructions (PART-TRUST section 3.5) |
| Identity scoping | Per-session, least-privilege credentials | Not a CLI mechanic; MCP server auth (static header/env key or OAuth) is per server (PART-CONFIG section 1.4) |
| Output validation | Threat detection before production surfaces | `pre_tool` hooks deny or rewrite `tool_input`; `post_tool` hooks replace `tool_output_text` (PART-HOOKS section 3.3) |
| Read-only execution | Reads only; writes go through review | `plan` agent (write tools `never`), custom read-only agents via `enabled_tools` (PART-PERMISSIONS section 4.1; PART-AGENTS section 8) |

Approval volume turns human review into a formality. Vibe's default profile `accept-edits` already auto-approves file edits (PART-PERMISSIONS section 4.1), so by default the human is the only gate on the remaining tools — each of which should be allowlisted or denied structurally, not screened by attention. The defenses that scale: denylists, read-only profiles, `strict = true` hooks, trust scoping, and second-agent validation (section 8).

## 4. CI/CD agentic patterns

**Test selection as an agent primitive.** Before an agent runs in CI, decide what it runs. Deterministic test selection — by change relevance and past results, not the full suite — matters more for agents than for human CI: a human judges from experience whether a failure applies; an agent needs that judgment made for it, or it iterates against irrelevant failures. The known failure mode of such services is a single-writer history bottleneck under concurrent load; design for a stateless, append-only history from the start.

**The Vibe CI leg.** Bounded, non-interactive runs are a first-class mode:

```bash
vibe --trust -p "Run the test suite; if anything fails, diagnose and fix it." \
  --max-turns 10 --max-price 2.00 --output json --agent accept-edits
```

`-p` never prompts — approval-required calls are auto-DENIED unless the agent or permission config allows them (live-verified on 2.25.0) — so configure capability in config, not in a prompt (PART-CLI; PART-TRUST section 3.4). `--trust` grants session-only trust so CI skips the trust prompt (PART-TRUST section 3.3); the `--max-*` flags bound the run; `--output json` gives machine-readable results; `VIBE_*` env vars inject the API key and any config override without files (PART-CONFIG section 2.2). Run each job in a `--worktree NAME` for branch isolation; programmatic runs never auto-clean worktrees, so cleanup is CI's job (PART-WORKTREES). Managed agent-CI platforms from major vendors exist; this guide makes no product-vs-product claims (see [Known gaps](#known-gaps)).

## 5. Digital twin testing

Agents that call external services cannot be tested against production on the first pass. The distinction that matters: a **behavioral mock** maintains state that evolves through interactions — rate limits, delayed propagation, conditional dependencies — while a static mock returns fixed responses. An agent that retries after a 429 behaves differently against a mock that models the rate-limit window.

| Service class | Best available approach | Coverage |
|---------|---------------------|----------|
| Chat/IM platforms | Behavioral mock servers with state management | Most complete: web API, events, webhooks, interactive components |
| Generic HTTP | WireMock (stateful), Beeceptor | No per-service behavior; configurable for arbitrary HTTP |
| Identity providers | Community patterns, staging tenants | Auth flows only; custom build usually required |
| Issue trackers | Vendor staging environments | Isolation, not behavioral fidelity |

LangWatch's Scenario SDK is the nearest thing to systematic agent-vs-simulated-user testing without a live service: realistic multi-turn inputs, an agent-judge against success criteria. Deterministic parts of the system get ordinary tests.

## 6. Observability stack

| Signal | Vibe mechanism | Oracle |
|---|---|---|
| Traces | `enable_telemetry` (master switch), `enable_otel` + `otel_endpoint` (OTLP/HTTP), `otel_redaction` = `default\|none\|strict` | PART-CONFIG section 1.8 |
| Logs | `$VIBE_HOME/logs/vibe.log`, `LOG_LEVEL`, `LOG_MAX_BYTES` rotation | PART-CLI |
| Transcripts | Per-session `messages.jsonl`; hook payloads carry `session_id`, `transcript_path`, `cwd`, `tool_input`, `tool_status`, `tool_output_text` | PART-SESSIONS section 3.1; PART-HOOKS section 3.2 |
| Recurrence | `/loop` prompts persist in `meta.json`, survive resume | PART-SESSIONS section 5 |

A `post_tool` audit hook is the cheapest pipeline: it fires iff the tool body ran and receives the serialized result, so every executed action is recorded with its outcome, without touching the loop (PART-HOOKS sections 1, 3.2). The generic open-source baseline — OpenLLMetry or OpenInference instrumentation feeding a tracing backend (Langfuse, Phoenix) plus a quality evaluator — plugs in through the OTel export. Measurement discipline matters more than tooling: report distributions, not means, for multi-turn multi-tool work; harness failures live in the tails.

## 7. Component-stacking anti-patterns

Stacking planning, tools, memory, reflection, and retrieval is not monotonic. *Cross-Component Interference* (arXiv 2605.05716) tested all 32 subsets of five components on two benchmarks: a single-tool configuration beat the all-in system by 32% on one; a three-component subset beat it by 79% on the other. The rule survives the preprint caveat: **start with the smallest sufficient harness and require every added component to pass a paired ablation and regression test.**

Tests are necessary but not a proof bundle. For an agentic change, retain the requirement map, the commands run, their outputs, test results, and the review verdict — enough to reproduce acceptance. A green suite plus unrecorded manual fiddling is not evidence.

## 8. The creator-verifier pattern

Assign production and evaluation to separate steps or agents. The evidence is mixed — Self-Refine (arXiv 2303.17651) and Multiagent Debate (arXiv 2305.14325) report gains on selected tasks; *LLMs Cannot Self-Correct Reasoning Yet* (arXiv 2310.01798) finds intrinsic self-correction can degrade answers; judge-bias research documents systematic evaluator biases — so treat it as a design candidate, used when evaluation criteria are clear and refinement is measurable.

A fresh context is one dimension of independence. A verifier can still share the creator's blind spots:

| Independence dimension | Failure when shared | Stronger design |
|------------------------|---------------------|-----------------|
| **Context** | Reviewer inherits the creator's framing | Give the reviewer requirements, artifact, evidence — not the reasoning chain |
| **Model** | Correlated blind spots, self-preference | Stratify results by model where risk justifies cost |
| **Evidence and tools** | Both inspect the same incomplete signals | Add deterministic tests, traces, or a different inspection tool |
| **Role and incentives** | Reviewer optimizes for agreement | Require per-requirement pass/fail verdicts with evidence, not a quality score |
| **Escalation authority** | A probabilistic verdict becomes final | Define appeal, timeout, human checkpoint, fail-closed rules |

| Decision | Default owner | Escalate when |
|----------|---------------|---------------|
| Product intent, acceptable risk | Accountable human | Intent ambiguous or impact high |
| Decomposition and routing | Planning agent or orchestrator | Fan-out large, irreversible, cross-domain |
| Execution | Runtime and repository harness | A permission or policy boundary is reached |
| Mechanical acceptance | Deterministic gate (tests, linters, schemas) | Coverage incomplete or a check flaky |
| Semantic sufficiency | Reviewer agent for bounded work; human for high-impact | Verifier uncertain or outside its evidence |
| Release or policy exception | Human | Never silently auto-approve an exception |

Human judgment does not disappear when prompts are automated; it moves to loop design, quality criteria, and exception policy.

Two verified routes in Vibe: a **verifier subagent** — a custom agent TOML with `agent_type = "subagent"` and read-only `enabled_tools` (or the built-in `explore` profile), spawned with the `task` tool (PART-AGENTS sections 7-9) — or a **second programmatic run**, `vibe --trust -p ... --agent plan`, a read-only pass over the same worktree (PART-CLI; PART-PERMISSIONS section 4.1). The prompt does the structural work:

*"For each numbered requirement in `specs/checklist.md`, return a pass or fail verdict with file and line evidence. Do not propose fixes."*

Ask "does this satisfy requirement X," never "is this good." Vibe has no cross-session messaging mechanic: pass requirements, artifact, and evidence as files — a worktree is a natural carrier. The transport never creates independence; the five dimensions above do.

## 9. Reference architecture

```text
User instruction
      ↓
┌────────────────────────────────────────────────────────────┐
│                         HARNESS                             │
│  Context Mgmt ◄──► While-Loop Engine ◄──► Permission Gate   │
│        │                  │                    │           │
│  Session State       Prompt Assembly      Lifecycle Hooks    │
│        │                  │                    │           │
│   Tool Registry ◄──►     LLM Call      ◄── Subagent Mgmt     │
│                           │                               │
│                       Built-in Skills                      │
└────────────────────────────────────────────────────────────┘
      ↓
┌────────────────┐  ┌────────────────┐  ┌──────────────────┐
│ Isolation      │  │ Identity       │  │ Observability    │
│ (external:     │  │ gateway        │  │ (OTel export +   │
│ container/VM — │  │ (external)     │  │ session logs +   │
│ not in Vibe)  │  │                │  │ hook audit)      │
└────────────────┘  └────────────────┘  └──────────────────┘
```

In Vibe terms: the permission gate is agent profiles plus the per-tool chain plus the trust store (PART-PERMISSIONS; PART-TRUST); isolation is worktrees plus whatever container boundary CI provides, since no OS sandbox ships (PART-WORKTREES); the identity row is external infrastructure. The loop itself is covered in [Architecture](./architecture.md).

## Known gaps

- **No OS-level sandbox.** Vibe CLI's documented surface has no container, VM, or network-policy isolation. Everything here about sandbox-class isolation is external infrastructure, not a Vibe mechanic.
- **The `smart-approve` agent** (release 2.25.8, `[unified-harness]`) classifies each tool call and auto-runs the safe ones. Its classifier wiring lives in the private harness package; the oracle marks its exact behavior as needing public verification. Do not build on it yet.
- **Admin config layer.** Layer 8 of the config stack is org-enforced, in-memory config (PART-CONFIG section 2.1), but its endpoint and wire format are not publicly documented.
- **First-party CI integration.** Whether Mistral publishes a Vibe GitHub Action or CI app has no public backing either way; the CI recipe above uses only the plain CLI.
- **Master-loop internals.** The exact per-turn event anatomy of Vibe's agent loop is not in the oracle; section 2.1 describes the loop abstractly, and [Architecture](./architecture.md) covers it as far as evidence allows.
- **Practitioner testimony and optimizer research.** The source guide's video-evidence ledger and harness-optimizer benchmark survey were cut: their link fabric cannot survive this guide's link policy, and none of it changes the reader's next action here. The design rules that survived (bounded loops, paired ablation, proof bundles) stand on their own.
- **Orchestrator landscape.** The oracle covers no orchestrator products, so this page makes no product-vs-product claims at that layer.

## See also

- [Loop & Graph Engineering](./loop-graph-engineering.md) — feedback loops, workflow graphs, stopping rules, judgment boundaries
- [Architecture](./architecture.md) — the Vibe loop, tools, compaction, sessions
- [Context Engineering](./context-engineering.md) and [Memory Systems](./memory-systems.md) — what enters the prompt, what persists
- [Methodologies](./methodologies.md) — working patterns built on this harness
- [Glossary](./glossary.md) — runtime, repository harness, orchestrator definitions
- The mechanics oracle: [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md)
- [Workflows](../workflows/README.md): CI recipes ([Automation](../ops/automation.md)), agent teams on subagents ([Module 07](../learning-path/07-advanced.md)), [event-driven agents](../workflows/event-driven-agents.md)
- [Tools Reference](tools-reference.md): builtin-tool catalog and permission-rule format
- [Learning Path](../learning-path/README.md): the ordered curriculum
- Surfaces pages (desktop and web): not written yet
