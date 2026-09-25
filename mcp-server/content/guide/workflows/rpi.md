---
title: "RPI: Research → Plan → Implement"
description: "A 3-phase feature development pattern with explicit GO/NO-GO validation gates between phases"
tags: [workflow, architecture, design-patterns, validation]
---

# RPI: Research → Plan → Implement

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

## TL;DR

```text
Phase 1 — Research:
  The agent explores feasibility, surfaces risks, asks decision questions
  Output: RESEARCH.md
  Gate: You decide GO / NO-GO

Phase 2 — Plan:
  The agent writes architecture decisions, implementation steps, test gates
  Output: PLAN.md
  Gate: You approve the plan before any code is written

Phase 3 — Implement:
  The agent implements step by step; each step's test gate must pass first
  Output: working code + passing tests
  Gate: each implementation step validated before the next begins
```

**Best for**: features with unclear feasibility, more than a day of work, unknown technical territory, or anything where discovering a wrong assumption late is costly. Everything on this page runs on the stable backend **[stable]** unless tagged otherwise.

*Read if you want gate-based feature development with human GO/NO-GO decisions before code exists. Skip if the change is small and obvious — direct prompting is cheaper than three phases.*

---

## When to Use RPI

### Use RPI when

- **Feasibility is unknown**: you have an idea but aren't sure it holds up technically
- **Scope is large**: more than a day's worth of implementation work
- **Requirements are fuzzy**: you know the outcome you want, not the path to it
- **Risk of wrong direction is high**: security, payments, data migrations, external integrations
- **You've been surprised before**: a feature looked simple, turned out to involve 6 other systems

### Skip RPI when

| Scenario | Better approach |
|---|---|
| Fix is obvious (typo, wrong color) | Direct edit |
| Feature well-understood, requirements clear | [Spec-first](spec-first.md) |
| Exploration mode (you don't know what you want yet) | Direct prompting, iterate |
| Tiny change, single file | Just do it |

### Decision heuristic

Ask yourself: "If the research phase reveals a serious problem, am I glad I didn't spend 2 days implementing first?" If yes, run RPI. Research typically takes 30-60 minutes and can save days.

---

## How the Gates Work

RPI has two human gates and one automated gate per implementation step.

```text
[Idea]
   |
   v
[Phase 1: Research]
   |
   +- NO-GO -> Stop. Document why. Archive RESEARCH.md.
   |
   +- GO -------------------------------------------------------->
                                                                 |
                                                       [Phase 2: Plan]
                                                                 |
                                          +- Needs revision -> iterate with the agent
                                          |
                                          +- Approved -------------------------------->
                                                                                      |
                                                                          [Phase 3: Implement]
                                                                              Step 1 -> Test gate
                                                                              Step 2 -> Test gate
                                                                              Step 3 -> Test gate
                                                                                   |
                                                                                [Done]
```

**Gate 1 (after Research)**: you read `RESEARCH.md` and make a GO/NO-GO decision. The most important gate — it prevents building the wrong thing entirely.

**Gate 2 (after Plan)**: you review `PLAN.md` before any code is written. Revisions here are free; revisions after approval cost implementation time.

**Step gates (during Implement)**: each implementation step must pass its test gate before the agent moves on. Automated, no human action unless a step fails.

---

## Phase 1: Research

### What research covers

Five questions:

1. **What already exists?** Relevant code, libraries, prior attempts
2. **What needs to be built?** Scope boundary, components to create vs modify
3. **What are the risks?** Technical, security, integration, performance
4. **What are the decision points?** Architecture choices that shape the whole plan
5. **What is the effort estimate?** Rough sizing before committing to a plan

### Running research on Vibe

Two ways to enforce read-only research, one soft and one hard:

- **Soft (default agent + rules)**: the default agent (`accept-edits`) auto-approves file edits, so "don't modify code" is prompt discipline backed by an `AGENTS.md` rule (PART-AGENTSMD; PART-PERMISSIONS §4.1). Fine when you're watching the session.
- **Hard (the plan agent)**: `vibe --agent plan` is mechanically read-only — `write_file` and `edit` are set to permission `never`, with an allowlist covering only `$VIBE_HOME/plans/*` (PART-AGENTS §7; PART-PERMISSIONS §4.1). It cannot slip into implementation. The trade-off: it also cannot write `RESEARCH.md` into your repo, so either keep the research doc under `~/.vibe/plans/` (its only writable surface) or have a follow-up writable session transcribe the findings to `docs/features/<feature>/RESEARCH.md`.

Invoke the phase with the research skill (see [Skills](#skills-the-three-phase-entry-points)):

```text
/rpi-research payment-processing
```

The rest of the line after the skill name is passed to the skill as extra instructions (PART-SKILLS §1.3), so scope limits can ride along:

```text
/rpi-research payment-processing Focus area: src/payments/ and src/routes/checkout.ts. Do not explore frontend or auth.
```

### RESEARCH.md template

```markdown
# Research: [Feature Name]

**Date**: [YYYY-MM-DD]
**Requested**: [One-sentence description of the feature]
**Status**: PENDING DECISION

---

## What Exists Today

### Relevant Code
- [file path]: [what it does, why it matters]

### Relevant Libraries
- [library]: [currently used / available / needs to be added]

### Prior Attempts or Related Work
- [existing partial implementation, related PR, note in codebase]

---

## What Needs to Be Built

### New Files
- [file path]: [purpose]

### Files to Modify
- [file path]: [what changes, why]

### External Dependencies
- [dependency]: [reason needed, version constraint if any]

---

## Risks

| Risk | Likelihood | Impact | Notes |
|---|---|---|---|
| [risk description] | Low/Med/High | Low/Med/High | [mitigation or blocker] |

---

## Architecture Decision Points

Questions that need a decision before planning can start:

1. **[Decision]**: Option A (pros: X, cons: Y) vs Option B (pros: X, cons: Y)

---

## Effort Estimate

- Research-to-plan: [time]
- Implementation: [time range]
- Testing: [time]
- **Total estimate**: [range]

**Confidence in estimate**: Low / Medium / High
**Why**: [reason for confidence level]

---

## Recommendation

[GO / NO-GO / NEEDS CLARIFICATION]

[1-3 sentences explaining the recommendation]

---

**Decision**: [ ] GO  [ ] NO-GO  [ ] NEEDS CLARIFICATION
**Notes**: [human fills this in]
```

### What a NO-GO looks like

Common NO-GO reasons: the external API doesn't support the required operation (technical blocker); the "simple feature" requires rewriting the auth layer (scope creep discovered); an existing library or config change solves it more simply (better alternative exists); the feature is valid but the timing is wrong (risk too high for now).

Archive NO-GO research docs. They are records of decisions made and why.

---

## Phase 2: Plan

Phase 2 starts only after you mark `RESEARCH.md` with GO. A good plan is specific enough that a different engineer — or the agent in a fresh session — could execute it without asking questions.

Invoke:

```text
/rpi-plan payment-processing
```

### PLAN.md template

```markdown
# Plan: [Feature Name]

**Date**: [YYYY-MM-DD]
**Research**: [link to RESEARCH.md]
**Estimated effort**: [from research]
**Risk level**: Low / Medium / High

---

## Summary

[2-4 sentences: what this implements, major design decisions, what it does NOT include]

---

## Architecture Decisions

[Resolve each decision point from research]

1. **[Decision]**: Chose [Option] because [reason]

---

## Implementation Steps

Steps must be sequential and independently testable.

### Step 1: [Name]

**Files**: [list of files to create or modify]
**What to build**: [precise description]
**Test gate**: [specific command that must exit 0 before Step 2 starts]

[...continue for all steps]

---

## Success Criteria

- [ ] [Testable criterion — observable behavior, not implementation]
- [ ] All step test gates pass

---

## Out of Scope

- [thing excluded]
- [thing excluded]

---

## Risks Accepted

[From RESEARCH.md: which risks are accepted and how they're mitigated]

---

## Rollback Plan

If implementation fails mid-way:
- [what to undo]
- [how to restore previous state]

---

**Plan approved?** [ ] YES — proceed to implementation
**Revision notes**: [human fills this in if changes needed]
```

### Reviewing the plan

Check before approving:

- Steps are in the right order, with no hidden dependencies
- Test gates are concrete and runnable commands, not "it looks right"
- Out-of-scope is explicit (this is what stops the agent from over-building)
- A rollback plan exists for anything touching data or shared state

If the plan needs changes, ask for a revision before approving. Revision before approval is free; after approval it costs implementation time.

---

## Phase 3: Implement

### The step-gate pattern

Implementation runs step by step; each step has a test gate; the agent does not start the next step until the current gate passes.

Invoke:

```text
/rpi-implement payment-processing
```

Rules carried by the implement skill and your `AGENTS.md`:

```markdown
## RPI Rules
- Research runs read-only — no code modifications during research
- Plan produces only PLAN.md — no implementation code
- Implement runs one step at a time and waits for the step's test gate before the next
- A failed gate stops the work; the agent reports and asks, it does not improvise a fix
- Commit after each step that passes its gate, referencing the step in the message
```

### What happens during implementation

For each step, the agent:

1. Implements only what the step specifies
2. Runs the test gate exactly as written in the plan
3. If the gate passes: commits with a message referencing the step, announces readiness for the next step
4. If the gate fails: reports the failure, the exact test output, and the likely cause — and stops

Sample failure report (the agent reports, you decide):

```text
Step 2 gate failed.

Gate: npm test src/middleware/rate-limit.test.ts — all 4 tests pass
Output:
  FAIL src/middleware/rate-limit.test.ts
  ● limiter › blocks the 101st request from the same IP

Likely cause: the limiter reads the request IP from req.ip, but the test
superseded it with a socket address.

Options:
1. Fix: read the IP from the X-Forwarded-For header when present
2. Revise plan: the test assumption doesn't match the deployment proxy setup
3. Stop and investigate: unexpected, may indicate a config problem

Which should I do?
```

You decide. The agent does not auto-fix and proceed — that is how implementations drift from plans.

### Step gates in CI

Step gates can be verified headless. In programmatic mode, approval-requiring tool calls are auto-DENIED unless `--auto-approve`/`--yolo` is passed or the agent/permission config allows them — so a gate-check run fails closed rather than waiting on a human (PART-TRUST §3.4):

```bash
vibe --trust -p "Read docs/features/payment-processing/PLAN.md. Run only Step 2's test gate exactly as written and report the command, exit code, and output. Do not modify anything." --max-turns 6 --output json
```

`--trust` grants session-only trust; `--max-turns`/`--max-price`/`--max-tokens` bound the run; `--output json` gives machine-readable entries (PART-CLI; PART-TRUST §3.3). Note the gate command itself: test commands are not in the default bash read-only allowlist, so either allowlist them in `config.toml` (`[tools.bash] allowlist = ["npm test"]`) or accept the denial and run the suite outside the agent (PART-PERMISSIONS §4.4).

---

## Skills: the three phase entry points

Vibe has no custom command-file mechanism; user-invocable skills are the only user-defined slash-command surface (PART-SKILLS §1.1-1.3). Each phase becomes a skill directory under `.vibe/skills/`:

```text
.vibe/skills/
├── rpi-research/
│   └── SKILL.md      # /rpi-research
├── rpi-plan/
│   └── SKILL.md      # /rpi-plan
└── rpi-implement/
    └── SKILL.md      # /rpi-implement
```

Frontmatter contract (PART-SKILLS §1.1): `name` (1-64 chars, lowercase alphanumerics and hyphens, matching the directory name) and `description` (1-1024 chars, the routing text the model sees before loading) are required; `user-invocable` defaults to `true`, which is what makes `/rpi-research` resolve. The rest of the invocation line after the skill name is passed to the skill as extra instructions (PART-SKILLS §1.3). Project skills load only when the project root is trusted — `--add-dir` roots count, untrusted roots contribute nothing (PART-SKILLS §1.2).

Complete `rpi-research` skill:

````markdown
---
name: rpi-research
description: RPI Phase 1 - run read-only feasibility research for a feature and produce RESEARCH.md with a GO/NO-GO recommendation. Use when starting a feature whose feasibility, scope, or risks are unclear.
---

# RPI Phase 1: Research

The feature to research is described in the extra instructions that came with
this invocation. If none were provided, ask before starting.

## Instructions

1. Research read-only: do not modify code files. If you are the plan agent,
   persist output only under ~/.vibe/plans/; otherwise write the single
   artifact docs/features/<feature>/RESEARCH.md
2. Explore the codebase to answer:
   - What already exists that's relevant?
   - What files will need to change or be created?
   - What are the technical risks?
   - What decisions need to be made before planning?
   - What is a rough effort estimate?
3. Write RESEARCH.md using the project template (risks table, decision points,
   effort estimate with confidence, recommendation)
4. End with a clear recommendation: GO, NO-GO, or NEEDS CLARIFICATION
5. Ask the user for their GO/NO-GO decision before proceeding

## Constraints

- Do NOT write implementation code
- Do NOT modify existing files other than creating RESEARCH.md
- Do NOT plan implementation steps — that is Phase 2
- If uncertain about scope, surface it as a decision point
````

`rpi-plan` and `rpi-implement` follow the same shape: `name`/`description` frontmatter plus the phase instructions. `rpi-plan` pre-checks that `RESEARCH.md` carries a GO decision before planning, resolves every decision point, writes sequential steps each with a concrete test-gate command, and stops for your approval. `rpi-implement` pre-checks the plan is approved, then runs one step at a time: implement only the step, run its gate exactly as written, commit on pass (`feat(<feature>): step N — <name>`), stop and report on failure. Skill design guidance: [skill-design-patterns.md](../core/skill-design-patterns.md).

---

## Worked Example

**Request**: "Add rate limiting to the public API endpoints."

### Phase 1: Research output (abbreviated)

```markdown
# Research: API Rate Limiting

**Date**: 2026-03-12
**Status**: PENDING DECISION

## What Exists Today
- `src/middleware/` — has auth middleware, no rate limiting
- `package.json` — express-rate-limit not installed, redis available
- `src/routes/api.ts` — 14 public endpoints, unauthenticated mixed with authenticated

## Risks
| Redis connection failure disables all API access | Low | High | Fallback to in-memory if Redis unavailable |
| Rate limit too aggressive — breaks integrations | Medium | High | Survey current usage patterns first |

## Architecture Decision Points
1. Library: express-rate-limit (maintained) vs custom middleware
2. Bypass: allow internal services to bypass rate limiting?

## Effort Estimate
- Implementation: 2-4 hours; Testing: 2 hours; **Total: 4-6 hours**

**Recommendation**: GO — standard problem, good library options, main risk
(Redis fallback) is solvable.
```

**Human decision**: GO. Use express-rate-limit. No IP bypass for now.

### Phase 2: Plan (abbreviated)

```markdown
# Plan: API Rate Limiting

## Architecture Decisions
1. express-rate-limit with rate-limit-redis store
2. No IP bypass initially
3. Unauthenticated: 100 req/15 min. Authenticated: 1000 req/15 min.
4. Redis failure fallback: in-memory store

## Implementation Steps

### Step 1: Install dependencies and configure Redis store
**Files**: package.json, src/config/rate-limit.ts
**Test gate**: npm install completes; src/config/rate-limit.ts imports without errors

### Step 2: Implement rate limiter middleware
**Files**: src/middleware/rate-limit.ts
**Test gate**: npm test src/middleware/rate-limit.test.ts — limiter blocks the 101st request from the same IP within 15 minutes

### Step 3: Apply to routes
**Files**: src/routes/api.ts
**Test gate**: integration test — unauthenticated route returns 429 after 100 requests

### Step 4: Add Redis fallback
**Files**: src/config/rate-limit.ts
**Test gate**: with Redis unavailable, API still responds 200 (not 500) and in-memory limiting is active
```

**Human review**: Approved.

### Phase 3: Implementation

The agent implements Step 1, runs its gate, commits `feat(rate-limit): step 1 — dependencies and config`, then Steps 2-4 in sequence. Each commit is clean; each gate must pass before the next step starts. If Step 2's gate fails, it reports (see the sample failure report above) and waits.

---

## Comparison to Other Workflows

| Workflow | Phase structure | Human gates | Best for |
|---|---|---|---|
| **RPI** | Research + Plan + Implement | GO/NO-GO + plan approval | Unknown feasibility, >1 day, high risk of wrong direction |
| **Spec-first** | Spec + Implement | Spec review | Design-focused work, API contracts, team alignment |
| **TDD** | Test-first + Implement | None (tests are the gate) | Test coverage as driver, refactoring |
| **Direct** | None | None | Simple changes, obvious scope, under 2 hours |

**RPI vs spec-first**: spec-first is design-oriented — you define what the system should do, then the agent implements it. RPI is implementation-oriented with validation gates — you describe a goal, the agent researches how to achieve it, and you agree on a plan before touching code. Use spec-first when the design is clear; use RPI when the technical path is not. See [spec-first.md](spec-first.md).

**RPI vs TDD**: TDD's gates are tests; RPI's gates are human decisions plus tests. They compose well: RPI's implement phase is exactly TDD's red-green cycle with a step granularity. See [tdd.md](tdd.md).

**RPI vs direct**: for anything under 2 hours with clear scope, just ask. RPI's research phase alone takes 30-60 minutes; the overhead pays off on multi-day features where a wrong assumption discovered late is much more expensive.

---

## Tips and Troubleshooting

### The agent skips to implementation during research

The plan agent makes this structurally impossible: `--agent plan` has `write_file`/`edit` at permission `never` (PART-AGENTS §7). With a writable agent, fall back to the `AGENTS.md` RPI rules and an explicit line in the invocation:

```text
/rpi-research payment-processing Research only. Do not modify files. Output goes to RESEARCH.md.
```

### Research runs too long

Scope it in the invocation — the text after the skill name is handed to the skill as extra instructions (PART-SKILLS §1.3):

```text
/rpi-research payment-processing Focus area: src/payments/, src/routes/checkout.ts. Do not explore: frontend, auth, unrelated modules. Complete in this session.
```

### The plan has too many steps

More than 6-8 steps usually means the scope needs reduction, not more granular steps:

> *The plan has too many steps. What is the minimal viable scope that delivers the core value? Revise the plan to implement only that, with a "Future work" section for the rest.*

### Test gates are vague

Reject vague gates before approving. Push back:

> *Step 3's test gate is "verify rate limiting works." Make it specific: what command do I run, and what output do I expect when it passes?*

```text
Good:   Test gate: npm test src/middleware/rate-limit.test.ts — all 4 tests pass
Bad:    Test gate: rate limiting is working correctly
```

### A step gate fails repeatedly

Two failures means investigate the plan, not keep iterating:

> *Stop implementation. The Step 2 gate has failed twice. Review the plan — is the gate achievable given the Step 1 output? Do we need to revise the plan before continuing?*

---

## File Structure Summary

```text
docs/features/                 # phase artifacts (any repo location works)
└── [feature-name]/
    ├── RESEARCH.md            # Phase 1 output (human annotates GO/NO-GO)
    └── PLAN.md                # Phase 2 output (human annotates approval)

.vibe/skills/
├── rpi-research/SKILL.md       # /rpi-research
├── rpi-plan/SKILL.md          # /rpi-plan
└── rpi-implement/SKILL.md      # /rpi-implement

AGENTS.md                       # RPI rules (loaded every session, PART-AGENTSMD)
```

Archive completed features:

```bash
mkdir -p docs/features/_archive
mv docs/features/payment-processing docs/features/_archive/
```

The archive is a learning resource: completed `RESEARCH.md` and `PLAN.md` files show how previous features were reasoned about.

---

## Known gaps

- The plan agent's writable surface is only `$VIBE_HOME/plans/*` — in-repo `RESEARCH.md`/`PLAN.md` must be written by a writable session (the default `accept-edits` agent) or transcribed by you (PART-AGENTS §7; PART-PERMISSIONS §4.1).
- **Live-run note (2026-09-24, vibe 2.25.7):** in a headless `-p` run, the plan agent could NOT write under `~/.vibe/plans/` — `write_file` there was auto-DENIED by the approval policy (writes inside the repo were denied too, as expected), while reading `~/.vibe/plans/*` via its read allowlist works. The oracle (PART-AGENTS §7; PART-PERMISSIONS §4.3) says the plan profile's `write_file` allowlist `$VIBE_HOME/plans/*` should resolve to `always`; live 2.25.7 (unified backend) diverges for writes in `-p` mode. The working path is the one the page already describes: have the plan agent deliver the research in-chat (it can also persist to the session scratchpad under `~/.vibe/logs/session/<backend>/<id>/scratchpad/`), and transcribe it to `docs/features/<feature>/RESEARCH.md` yourself or via the default `accept-edits` agent. Whether an interactive session prompts for and permits the plans-dir write was not verified (interactive-only).
- No persistent todo store exists in the verified surface; step progress tracking lives in `PLAN.md` itself (check the step off when its gate passes) or a `TASKS.md` file driven by an `AGENTS.md` rule (PART-AGENTSMD). A `/todo` command exists only as a release-2.25.8 delta gated on the experimental unified harness **[unified-harness]** — not available on the stable surface (PART-COMMANDS; PART-DELTAS).
- Project skills under `.vibe/skills/` load only in trusted roots; an untrusted directory silently loses the `/rpi-*` invocations (PART-SKILLS §1.2).
- If research is delegated to a subagent via the `task` tool, results are text-only and subagents cannot spawn further subagents (depth limit 1) — the subagent cannot write `RESEARCH.md` for you unless its profile enables write tools (PART-AGENTS §9).

## See also

- [spec-first.md](spec-first.md): spec as contract when the design is already clear
- [tdd.md](tdd.md): test-gated implementation for Phase 3
- [agents-and-skills-reference.md](../core/agents-and-skills-reference.md): agent profiles and the `task` tool
- [skill-design-patterns.md](../core/skill-design-patterns.md): writing the `/rpi-*` skills well
- [hooks-events-reference.md](../core/hooks-events-reference.md): mechanical enforcement beyond prompts
- [methodologies.md](../core/methodologies.md): where RPI sits among the structured methodologies
- [agent-harness.md](../core/agent-harness.md): the harness layer the gates run inside
