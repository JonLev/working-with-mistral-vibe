---
title: "Loop & Graph Engineering"
description: "Design bounded agent feedback loops and executable workflow graphs: durable state, explicit judgment allocation, inspectable evidence, and the Vibe mechanics that enforce them."
tags: [guide, agents, architecture, observability, evaluation]
---

# Loop & Graph Engineering

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Cited mechanics were live-verified against vibe 2.25.0 and re-checked against the 2.25.8 release source; the [mechanics oracle](../../docs/mechanics/verified-mechanics.md) holds the per-part stamps.

Loop engineering and graph engineering are practitioner labels, not formal standards; the underlying mechanisms — state machines, workflow graphs, checkpoints, review gates — are mature engineering techniques. A **loop** specifies feedback and stopping. A **graph** specifies executable topology. Neither establishes that an acceptance decision is correct.

## TL;DR

- Start with the smallest control structure that can make the required decision safely. Do not turn a single bounded task into a multi-agent graph because a framework makes it easy.
- Write loops and graphs as contracts: goal, state, actions, verification, stop rules, evidence. A model statement that it has finished is an observation, not acceptance evidence.
- Keep the control plane static; let dynamic execution create only bounded data within policy.
- Make execution durable — state outside the context window, idempotent side effects — and allocate judgment explicitly between deterministic checks, agents, and named humans.
- Vibe mapping: budget caps are `--max-turns` / `--max-price` / `--max-tokens` (PART-CLI), recurrence is `/loop` (PART-SESSIONS section 5), isolation is `--worktree` (PART-WORKTREES), the repository harness is the AGENTS.md hierarchy (PART-AGENTSMD), deterministic gates are hooks (PART-HOOKS).

*Read if you design agent feedback loops, scheduled automation, or workflow graphs around Vibe. Skip if single-shot prompts with harness defaults cover your work.*

The layer taxonomy — model, runtime harness, repository harness, orchestrator — is owned by [Agent Harness Engineering](agent-harness.md). This page owns the loop and graph contracts that make feedback and routing inspectable.

Contents: 1 Choose the smallest control structure · 2 Write a loop contract · 3 Write a graph contract · 4 Static and dynamic graphs · 5 Allocate judgment explicitly · 6 Make execution durable · 7 Observe and evaluate the system · 8 Vibe case study · 9 Anti-patterns · 10 Selection checklist

## 1. Choose the smallest control structure

Start with the simplest structure that can make the required decision safely.

| Need | Smallest suitable structure | What must still be specified |
|---|---|---|
| One bounded task with local tool feedback | Agent loop | stopping rule, tool policy, local verifier |
| Known branches, retries, parallel work, human interruption | Explicit workflow graph | state schema, routes, joins, checkpoint and recovery policy |

Every added component introduces state, overhead, and failure modes; every verifier, reviewer, or release gate introduces an acceptance boundary you must test. In Vibe terms: the agent loop is one CLI session; the repository harness is the checked-in AGENTS.md hierarchy plus your tests (PART-AGENTSMD); a graph runtime or orchestrator is something you add outside the session, and only when the table above says so.

## 2. Write a loop contract

A loop contract makes "keep going until it works" testable: it names the unit of work, its permitted actions, the evidence that counts as progress, and every allowed exit.

| Field | Questions the contract must answer | Vibe anchor |
|---|---|---|
| Goal and input | What requirement, repository revision, and expected artifact define this run? | the prompt plus the checked-out revision; a `--worktree` run pins its own branch (PART-WORKTREES) |
| State | What facts persist outside the context window? Who may update them? | files and AGENTS.md, not the conversation — compaction summarizes the transcript once `context_tokens` reaches `auto_compact_threshold` (default 200,000; `0` disables) [both] (PART-SESSIONS section 4) |
| Actions | Which tools, credentials, files, and external effects are permitted? | tool approval follows the selected `--agent` or `default_agent`; `--auto-approve`/`--yolo` removes the gate [stable] (PART-CLI) |
| Observation | Which tool outputs, tests, traces, and human feedback enter the next iteration? | the turn's tool results; hook payloads carry `tool_status` and `tool_output_text` [stable] (PART-HOOKS section 3.2) |
| Verification | Which deterministic checks, independent reviews, or human decisions can accept the work? | commands you run and gate with `pre_tool` hooks [stable] (PART-HOOKS) |
| Stop and escalation | What ends success, ends failure, consumes budget, times out, or requires a person? | `--max-turns`, `--max-price`, `--max-tokens` interrupt the session when exceeded [stable] (PART-CLI) |
| Evidence | Which commands, outputs, trace IDs, and versions prove the final claim? | the session's `messages.jsonl` transcript and `meta.json` [stable] (PART-SESSIONS section 3) |

[Agent Harness Engineering](agent-harness.md) defines the inner (tool feedback), outer (delivery verification), and meta (harness-change evaluation) horizons; apply the loop contract at each boundary. A model statement that it has finished is an observation, not acceptance evidence — the stop rule belongs to the contract, and the hard stops a controller can enforce in Vibe are the `--max-*` caps, not conditions written in prose (PART-CLI).

## 3. Write a graph contract

Use an explicit graph when routing itself is material: state, conditional branches, parallel work, interrupts, persistence as first-class artifacts. Nodes can contain model calls or conventional code, which is why a graph is not synonymous with a multi-agent system. A graph contract should be reviewable without running the graph.

| Element | Minimum contract |
|---|---|
| Graph identity | graph and policy versions, owner, compatible state schema |
| State | typed fields, confidentiality, writer, reducer or conflict rule, retention |
| Node | purpose, input and output, idempotency boundary, timeout, side effects |
| Edge | source, destination, condition, routing evidence, forbidden transitions |
| Join | expected inputs, timeout, missing-input behavior, merge rule |
| Retry | retryable failures, cap, backoff, compensation or escalation |
| Checkpoint | persistence boundary, resume semantics, migration compatibility |
| Completion | legal terminal states and the authority that can mark each one |

The contract must distinguish a valid route from a correct result: a state machine can reject an illegal transition while still carrying an incorrect requirement or a flawed review verdict forward.

### Practical example: a bounded change-review graph

```yaml
graph: change-review
version: 1
state:
  requirement: { writer: human, immutable_after: triage }
  patch_ref: { writer: implement, validator: commit_exists }
  test_evidence: { writer: verify, validator: command_and_exit_status }
  remaining_rework_budget:
    type: integer
    writer: retry_router
    initial: 2
    minimum: 0
    maximum: 2
    decrement: { when: verification_failed_and_value_gt_0, by: 1 }
nodes:
  triage: { timeout: 10m, output: approved_plan }
  implement: { side_effect: git_worktree }
  verify: { input: patch_ref, output: test_evidence }
  retry_router:
    input: [test_evidence, remaining_rework_budget]
    behavior: decrement_if_budget_remains_then_route
  review: { input: [patch_ref, test_evidence], authority: accept_or_escalate }
terminals:
  done: { condition: accepted_with_evidence }
  failed: { conditions: [rework_budget_exhausted, policy_violation] }
  escalated: { condition: human_escalation }
edges:
  - triage -> implement: approved_plan
  - triage -> failed: policy_violation
  - implement -> verify: patch_ref_exists
  - implement -> failed: policy_violation
  - verify -> retry_router: verification_failed
  - verify -> failed: policy_violation
  - retry_router -> implement: rework_budget_decremented
  - retry_router -> failed: rework_budget_exhausted
  - verify -> review: verification_passed
  - review -> done: accepted_with_evidence
  - review -> failed: policy_violation
  - review -> escalated: ambiguous_or_high_impact
```

The `retry_router` is the only writer allowed to decrement the counter; once the budget reaches zero, the next failed verification reaches the `failed` terminal. The example does not give the reviewer authority to accept an untested patch. In a production design, add the exact test command, budget unit, trace fields, and side-effect rules.

## 4. Static and dynamic graphs

A **static graph** fixes its topology in reviewed configuration or code. A **dynamic graph** creates or changes tasks, dependencies, routes, or workers during execution.

| Aspect | Static graph | Dynamic graph |
|---|---|---|
| Best for | stable roles, approved transitions, review gates, known workflow | discovered tasks, work queues, dependency expansion, adaptive routing |
| Main benefit | inspectable before execution | can respond to new evidence |
| Main risk | brittleness when the task does not fit | unreviewed routes, unbounded work, topology drift |
| Required control | version review and route tests | creation policy, budget, provenance, validation, audit log, revocation |

Dynamic does not mean that a model may write arbitrary workflow code and execute it. Keep the control plane static where consequences are high — allowed node types, permissions, transitions, concurrency, budgets, release authority — and let dynamic execution create only bounded data within that policy. Vibe's own control plane is deliberately static: `hooks.toml` defines exactly three event types (`pre_tool`, `post_tool`, `post_agent`) [stable] (PART-HOOKS section 1), and even scheduled loops stay inside fixed machinery — a `/loop` prompt cannot start with `/`, so recurrence is prompting, not new control flow (PART-SESSIONS section 5).

## 5. Allocate judgment explicitly

Automation moves judgment; it does not erase it. Write down who owns the quality bar, decomposition, tool permission, exceptions, acceptance verdict, and release decisions. The person leaves the repetitive execution loop while remaining in the governance loop — never infer from "no human in the loop" that no human is accountable.

| Loop | Primary responsibility | Human role |
|---|---|---|
| Execution loop | plan, act, observe, verify, retry within a budget | handle exceptions and escalations that exceed policy |
| Governance loop | define goals, permissions, budgets, acceptance policy, release authority | remain accountable for risk and irreversible effects |
| Improvement loop | inspect traces and failures; propose changed prompt, graph, policy, or harness | approve the versioned change against held-out evidence |

| Decision | Prefer | Why |
|---|---|---|
| schema, required command, prohibited transition | deterministic validator or policy engine | exact, repeatable, auditable |
| ambiguous requirement, risk trade-off, business priority | accountable human | requires authority and context outside the run |
| exploratory analysis, qualitative ranking | agent or model judge, with sampled adjudication | useful signal, never a sole production gate |
| release or irreversible external effect | named human or pre-authorized policy | establishes accountability and exception handling |

Creator-verifier separation is a treatment to test, not proof of independence: a reviewer with fresh context can still share the same flawed specification, model, or incentives. Compare self-review, fresh-context review, different-model review, deterministic checks, and human adjudication on the same sampled defects, and record false accepts, false rejects, and the evidence each verdict used. Vibe's deterministic gates are hooks: `pre_tool` deny blocks a call (with `strict = true`, a hook *failure* denies as well), and a `post_agent` deny injects a retry message — at most 3 retries per user turn [stable] (PART-HOOKS sections 3.3, 3.7). In programmatic mode, approval-required calls are auto-denied unless `--auto-approve`/`--yolo` is passed (PART-CLI): in headless loops, the judgment you did not configure is "no", not "yes".

## 6. Make execution durable

Distinguish process recovery from product recovery: resuming an interrupted run establishes continuity of execution, but does not show the delivered result was sufficient or that its effects can be reversed. After a false acceptance you need detection, containment, an owner, and an exercised restoration path — application rollback can leave data mutations and external effects untouched.

| Requirement | Design question |
|---|---|
| Persisted state | Can another process reconstruct the run from a durable record? |
| Idempotency | What happens if a node or tool call runs again after a resume? |
| Checkpointing | At which safe boundaries can the system resume? |
| External effects | Which idempotency key, receipt, compensation, or read-before-write rule protects each effect? |
| Recovery | Who retries, who resolves conflicts, and when does recovery escalate? |
| Versioning | Can an old checkpoint be resumed under a changed graph or policy? |

Durable execution means an interruption does not silently lose, duplicate, or invent work — it is not merely saving chat history. What Vibe persists [stable]: sessions live under `$VIBE_HOME/logs/session/` as `meta.json` + `messages.jsonl`, resumable with `-c` (per-terminal pointer, then most recent in the directory) or `--resume <ID>` (global; partial IDs accepted); session logging must be enabled (PART-SESSIONS section 3). Scheduled loops persist in `meta.json`, are restored on resume, and a firing that conflicts with an active turn is skipped and retried on the next poll — idempotent at turn granularity (PART-SESSIONS section 5). Worktrees record ownership (branch, starting commit, a per-session marker guarding concurrent use) under `$VIBE_HOME/worktrees/.claims/`; interactive cleanup happens only when a worktree has no uncommitted changes, no untracked files, and no commits beyond the starting commit — programmatic runs never clean up automatically, so cleanup belongs in the contract (PART-WORKTREES).

Do not claim crash recovery unless it has been exercised: interrupt a run at a defined point, resume it in a clean process, and inspect the state transition, external effects, evidence record, and duplicate-work behavior.

## 7. Observe and evaluate the system

A trace needs enough evidence to answer four questions: what ran, why it routed, what state changed, and who accepted the result.

| Layer | Minimum evidence |
|---|---|
| Runtime loop | model and harness version, tool calls, permissions, retry, stop reason |
| Graph | graph and policy version, node, edge, route reason, state before and after, join wait, checkpoint, resume |
| Repository harness | setup command, changed artifact, verifier command, output, exit status |
| Orchestrator | dispatch, ownership, queue wait, handoff, lease, escalation, human checkpoint |
| Judgment | evaluator identity and provenance, evidence references, verdict, overturn, exception authority |

For the runtime and harness layers Vibe gives you durable records: `meta.json` captures session id, pinned model, `tools_available`, and stats; hook payloads carry `session_id`, `transcript_path` (the `messages.jsonl`), `cwd`, `tool_input`, `tool_status`, and `tool_output_text` [stable] (PART-SESSIONS section 3; PART-HOOKS section 3.2). Redact sensitive prompt text, tool arguments, and identifiers before exporting telemetry.

Evaluate the exact model-harness pair, revision, permission set, graph version, budget, and task distribution. A green control-flow test shows the graph followed its contract; it does not prove the patch meets the requirement — pair workflow tests with requirement-level verification, recovery drills, and repeated representative tasks.

Bound the shared queue, not just each run: a task with a finite retry budget can still add work faster than reviewers can accept it. Reserve verification capacity before dispatch; pause new authoring at an owner-approved queue or age limit, when a required reviewer is unavailable, or when queue telemetry is stale; resume below a distinct threshold with fresh telemetry, or the scheduler oscillates.

## 8. Vibe case study: inner loop plus repository harness

Vibe owns the interactive model-and-tool loop: a session reads your prompt, runs tool calls under the selected agent's approval policy, and persists every turn. The repository harness is the AGENTS.md hierarchy — user `~/.vibe/AGENTS.md` always loaded; project `AGENTS.md` from each project root up to its trust root; subdirectory files injected lazily when a file below them is read; priority project over user, closer directory over distant [stable] (PART-AGENTSMD). Make the stop rule explicit: a targeted test passes, the change is reviewed against the requirement, and no budget or policy exit has fired. Do not infer a general graph runtime from hooks or subagents.

### Budgets, enforced and stated

Programmatic mode (`vibe -p`) runs one prompt to completion, and its caps are controller-enforced: `--max-turns N` (assistant turns), `--max-price DOLLARS`, `--max-tokens N` (total prompt + completion tokens) each interrupt the session when exceeded [stable] (PART-CLI). A limit written into a prompt is judged by the model from the conversation; a cap flag is checked by the controller before more work happens — prefer the flag for hard stops. In `-p` mode, approval-required tool calls are auto-denied (PART-CLI): pre-authorize exactly what the loop may do through `--agent` or permission config, or pass `--auto-approve`/`--yolo` deliberately.

### Recurrence: `/loop` [both]

`/loop <interval> <prompt>` schedules a prompt at a fixed interval (`<number>` plus `s|m|h|d`; minimum 30 s; at most 50 scheduled loops per session). The prompt must be non-empty and cannot start with `/` — a scheduled loop is prompting, not command invocation, so any invocation boundary must be explicit and tested. A loop fires only when no turn is active and none is queued; a firing that conflicts with an active turn is skipped and retried on the next poll. Loops persist in the session's `meta.json` and are restored on `-c`/`--resume`; manage them with `/loop list` and `/loop cancel <id|all>`. `/loop` itself is rejected while the agent is busy (PART-SESSIONS section 5).

For a recurring triage check, the scheduled prompt is itself the contract: *"/loop 2h Check the CI log for new test failures. For each failing test, reproduce it before proposing a fix, and do not start a second fix while one is in progress."*

### Isolation: worktrees [stable]

Run each parallel loop instance in its own worktree. `vibe --worktree NAME` creates (or reuses, same repo and branch only) a worktree under `$VIBE_HOME/worktrees/` on branch `NAME`; the unnamed form always creates a fresh one on a `vibe/<name>` branch. Worktrees are implicitly trusted for the session. Because `-c` and the resume picker are directory-scoped, carry a session across worktrees with `--resume <ID>` (PART-WORKTREES; PART-SESSIONS section 3).

### Compose recurring triage with bounded work

A scheduled check discovers work; admission decides whether a candidate may start; a bounded task pursues a finish condition; the review policy decides acceptance.

| Stage | Required evidence or decision |
|---|---|
| Detect | Identify an eligible issue and the repository revision examined |
| Admit | Check whether the same issue, revision, and criteria are already owned by an active run; reserve verification capacity |
| Work | Freeze the task, allowed changes, acceptance criteria, and total attempt budget |
| Verify | Reproduce the defect before the fix; retain the relevant checks on the candidate revision |
| Accept or stop | Record the review decision, or the failure, exhausted-budget, or escalation reason |

Keep the identifier across scheduled checks: a later firing must not create a second worker for the same active task or reset its consumed budget. The 50-loops cap bounds the schedule, not the work (PART-SESSIONS section 5).

## 9. Anti-patterns

| Anti-pattern | Why it fails | Corrective action |
|---|---|---|
| "Keep trying until done" | no termination, cost, or escalation boundary | write explicit success, failure, budget, timeout, and human exits; in headless runs pass the `--max-*` caps (PART-CLI) |
| A diagram without executable semantics | reviewers cannot test routing, joins, or recovery | define state, node contracts, edge conditions, and checkpoint behavior |
| Dynamic topology without policy | a model can create hidden loops or unapproved effects | constrain allowed mutations, budget them, log provenance, validate every route |
| One agent both creates and accepts | self-review mistakes confidence for evidence | separate deterministic checks and sample independent or human review |
| Checkpoints without idempotency | resume can duplicate writes or corrupt state | use effect receipts, idempotency keys, upserts, or compensation |
| Token-only observability | cost cannot explain a bad route, stale state, or wrong verdict | trace topology, state transitions, evidence, and judgment |
| Calling a scheduler a runtime harness | obscures who owns tool policy and recovery | identify the owner of the actual model-tool-observation loop |
| Treating one anecdotal run as a benchmark | a single project cannot establish general performance | label scope, retain artifacts, avoid comparative claims |

## 10. Selection checklist

Before adding a loop, graph, or orchestrator, answer yes to each relevant question.

- [ ] The selected structure is the smallest one meeting the routing, durability, and authority requirements.
- [ ] The loop has explicit success, failure, timeout, budget, and escalation exits — enforced by caps, not prose (PART-CLI).
- [ ] State, side effects, evidence, and retention are defined outside the model context, not just in the transcript.
- [ ] Every graph node, edge, join, retry, and checkpoint has a reviewed contract.
- [ ] Static policy constrains dynamic task and route creation.
- [ ] Deterministic checks own what they can decide deterministically; hooks gate it (PART-HOOKS).
- [ ] Human authority is named for ambiguity, exceptions, release, and irreversible effects.
- [ ] Reviewer independence is measured, not assumed from role names.
- [ ] Resume behavior and side-effect idempotency have been tested under interruption.
- [ ] Traces reconstruct routing, state changes, evidence, and verdicts without exporting sensitive payloads.
- [ ] Evaluation records the exact model-harness pair, graph version, budget, task set, and failure modes.

Resolve every applicable unchecked item before increasing the system's routing scope, side effects, or release authority.

## Known gaps

- **No session-spanning goal evaluator.** The source guide's product adjudicates a long-running "goal" condition across sessions; the oracle documents no Vibe equivalent. The verified primitives are the `--max-*` caps, your verification commands, and `/loop` recurrence (PART-CLI, PART-SESSIONS section 5).
- **No external-event triggers or queue system.** The only in-session recurrence in the oracle is `/loop` (idle-fired, per-session cap). The source's external-scheduler and monitor/channel patterns were cut rather than transliterated; an external orchestrator remains outside the documented surface.
- **Unified-harness store.** The unified-harness backend keeps sessions under `~/.vibe/logs/session/unified/`; the layout was observed live but the schema was not inspected, and the unified-harness `/loop` implementation was verified from public source only (the package was not installed in the live test venv). Durability claims on this page cover the stable backend; see the oracle's "Needs public verification" section.
- **Desktop and web surfaces.** Loop, resume, worktree, and hook behavior was verified on the CLI; the desktop app and Vibe Code Web surfaces were not inspected for these mechanics.
- **Context budgets.** Per-turn context-budget breakdowns and per-model context windows are model specs, not mechanics; the oracle covers only the compaction trigger (`auto_compact_threshold`, PART-SESSIONS section 4).

## See also

- [Agent Harness Engineering](agent-harness.md) — layer taxonomy, feedback horizons, harness design
- [Context Engineering](context-engineering.md) — what fills the loop's context window, and compaction
- [Methodologies](methodologies.md) — where bounded loops fit larger workflows
- [Memory Systems](memory-systems.md) — AGENTS.md hierarchy and session persistence as memory
- [Architecture](architecture.md) — how the Vibe runtime loop is built
- [Glossary](glossary.md) — shared vocabulary
- [Style guide](../style-guide.md) — voice and page contract for this guide

See also: [tools reference](tools-reference.md), [workflows](../workflows/README.md), and the [learning path](../learning-path/README.md). Surfaces pages are not written yet.
