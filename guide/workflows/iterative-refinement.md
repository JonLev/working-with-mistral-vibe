---
title: "Iterative Refinement"
description: "The prompt-observe-reprompt loop that steers agentic coding, plus bounded auto-loops, hook-driven quality gates, and the review auto-correction pattern, rebuilt on verified Vibe mechanics."
tags: [workflow, refinement, feedback, loops, hooks]
---

# Iterative Refinement

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Mechanics on this page are cited inline as (PART-XXX) against the
> [mechanics oracle](../../docs/mechanics/verified-mechanics.md). Where the
> source guide assumed a mechanic that Vibe does not have, the correction is
> stated in the body; anything unresolved is in
> [Known gaps](#known-gaps), never stated as fact.

Prompt, observe, reprompt until satisfied. That loop is the core steering
mechanism of agentic coding: the agent produces output fast, and the quality
you get is a function of the feedback you give. This page covers the manual
loop, the bounded automatic versions, the quality gates you can wire between
iterations, and the anti-patterns that waste iterations.

## TL;DR

```text
1. Initial prompt with a clear goal
2. Agent produces output
3. Evaluate against stated criteria
4. Specific feedback: "Change X because Y"
5. Repeat until the criteria pass — then stop
```

Key insight: **specific feedback beats vague feedback**, and **a loop without
a stop rule is not a workflow, it is a leak**.

Corrections carried over from the source guide, stated plainly:

- There is no autonomous "goal" command in Vibe. A goal is prompt text; the
  evaluator is you, a script you run, or a hook you configure — not the CLI.
- `/loop <interval> <prompt>` is a fixed-interval scheduled prompt, not a
  condition loop. It re-fires a prompt on a clock (minimum 30 s, maximum 50
  per session, only when the session is idle); it never evaluates a
  condition (PART-SESSIONS section 5).
- The only hard budgets the CLI enforces are the programmatic-mode caps
  `--max-turns`, `--max-price`, `--max-tokens` (PART-CLI). Prose such as
  "maximum 5 iterations" is a request, not an enforced stop.
- There is no stop hook. The nearest verified quality gate is a `post_agent`
  hook: it fires once per turn, and `decision: "deny"` injects a retry user
  message, at most 3 retries per user turn (PART-HOOKS section 3.7).

*Read if you steer an agent through multiple passes — code, scripts, or
reviews — or want an agent to self-correct inside a bounded run. Skip if
single-shot prompts with default harness behavior cover your work.*

Contents: 1 The loop · 2 Feedback patterns · 3 Bounded auto-loops ·
4 Quality gates between iterations · 5 Script generation workflow ·
6 Iteration strategies · 7 The review auto-correction loop · 8 Anti-patterns ·
9 State files and escalation · See also · Known gaps

## 1. The loop

### Step 1: Initial prompt

State intent and constraints up front. Iteration is cheaper when the first
output is already aimed.

*"Create a React component for a user profile card. Show avatar, name, bio.
Include an edit button. Use Tailwind CSS. Must be mobile-responsive."*

### Step 2: Observe

The agent produces code. Evaluate against the requirement: does it meet the
stated constraints, what is missing, what is wrong, what is merely worse than
it could be. Run the checks you will ultimately use to accept the work —
type-check, lint, tests — before forming opinions.

### Step 3: Specific feedback

Give targeted corrections, each with a location, an action, and a reason:

*"Good start. Changes needed: (1) the avatar should be circular, not square;
(2) the edit button should only show for the user's own profile — add an
`isOwner` prop; (3) the bio should truncate after three lines with a
'Show more' toggle."*

### Step 4: Repeat — and stop

*"Better. One more thing: add a loading skeleton state while the profile data
is fetching."*

Then stop. Once the stated criteria pass, further passes cost tokens and
introduce churn without a target. If the remaining dissatisfaction is a new
requirement, say so and restart the loop deliberately rather than drifting.

A compact worked example, with the agent's responses showing the
open-signal-close discipline (illustrative, not a captured run):

```text
User:    Create a debounce function in TypeScript.

Agent:   I'll write a small `debounce` with a typed signature, then show usage.

Agent:   [implements] Done: `debounce.ts` exports the wrapper. Open question:
         should the trailing call preserve the original return type? I left it
         as `void` for now.

User:    Yes — preserve the original return type, and add cancellation support.

Agent:   Two changes: return-type preservation via generics, plus a
         `cancel()` on the returned function. Re-running the type-check
         first so I don't build on a broken base.

Agent:   Both changes are in; `tsc --noEmit` passes. Remaining known gap:
         no unit tests yet — say the word and I'll add them.

User:    Add JSDoc, export the types separately, add unit tests.

Agent:   Closing pass: JSDoc on the exported API, types in `types.ts`, and
         five unit tests covering leading/trailing edge and cancel.
         `npm test` passes (5/5). The utility is complete as specified.
```

## 2. Feedback patterns

Effective feedback:

| Pattern | Example |
|---|---|
| Specific location | "Line 23: change `===` to `==`" |
| Clear action | "Add an error boundary around the form" |
| Reason given | "Remove the console.log because it leaks user data" |
| Priority marked | "Critical: fix the SQL injection. Nice-to-have: add pagination." |

Ineffective feedback, with corrections:

| Anti-pattern | Why it fails | Better alternative |
|---|---|---|
| "Make it better" | No direction | "Improve readability by extracting the validation logic" |
| "This is wrong" | No specifics | "The date format should be ISO 8601, not a Unix timestamp" |
| "I don't like it" | Subjective | "Use function components instead of class components" |
| "Fix the bugs" | Too vague | "Fix: (1) null check on line 12, (2) off-by-one in the loop" |

## 3. Bounded auto-loops

The agent can self-iterate, but only inside boundaries you make real. The
source guide drove this with two mechanics that do not exist in Vibe's
verified surface; here is what replaces them.

### What starts the next iteration

| Need | Mechanism | Stop evidence |
|---|---|---|
| Clarify a requirement or judge a design | Manual feedback in an interactive session | A person accepts the result against the stated criteria |
| A bounded, verifiable task across turns | Programmatic run with budget caps | `--max-turns` / `--max-price` / `--max-tokens` interrupt the session when exceeded; `--output json` gives the machine-readable result (PART-CLI) |
| Re-check an external state periodically | `/loop <interval> <prompt>` | Each firing records an observation; cancellation (`/loop cancel <id\|all>`) is separate from task acceptance (PART-SESSIONS section 5) |

### The bounded run, concretely

State the goal, the checks, and the budget in one programmatic invocation.
Budget flags apply only in programmatic mode (`-p`), which is what makes them
real: the session is interrupted when a cap is exceeded (PART-CLI).

```bash
vibe --trust -p "Goal: fix the flaky retry test in tests/retry.spec.ts.
First identify a check that fails because of the defect; fix it; require
the same check to pass afterwards; touch only src/retry.ts and
tests/retry.spec.ts; run the regression suite before finishing." \
  --max-turns 25 --max-price 2 --output json
```

Programmatic-mode semantics you must design around (PART-CLI; PART-TRUST
sections 3.3-3.4):

- Approval-required tool calls are **auto-denied** in `-p` mode unless
  `--auto-approve`/`--yolo` is passed or the selected agent or permission
  config allows them. A run that needs to write files needs
  `--agent accept-edits` (auto-approves edits) or `--auto-approve`.
- `--trust` grants session-only trust — it skips the trust prompt and is
  never persisted (PART-TRUST section 3.3).
- A read-only bounded run is `--agent plan` — its `write_file`/`edit`
  permissions are `"never"`, so it cannot modify the repo at all
  (PART-AGENTS section 7).

### Completion criteria in the prompt

Because no command enforces a condition, put the condition in the prompt and
make it checkable:

*"Improve the algorithm's performance. Success criteria: 95th-percentile
response under 100 ms on the benchmark in `bench/run.ts`; all existing tests
still pass. Stop after at most 5 measured attempts, or earlier if an attempt
improves the metric by less than 5%. Report each attempt's measurement."*

That last sentence is a stop request the model can honor — the enforced stop
is still the `--max-*` cap (PART-CLI). Treat prompt-level limits as policy the
model follows, not a counter the runtime tracks.

### Scheduled re-checking, not condition loops

`/loop` exists in Vibe, with different semantics than the source guide
assumed. It schedules a prompt on a fixed interval: `/loop <interval>
<prompt>` with units `s|m|h|d`, a 30-second minimum, at most 50 loops per
session, firing only when no turn is active, surviving resume; the prompt
cannot start with `/`; `/loop list` shows the table and `/loop cancel
<id|all>` removes loops (PART-SESSIONS section 5). Use it when "look again
every 30 minutes" is the actual need — for example *"Check whether the CI run
on this branch has finished; if it failed, summarize the failures."* It does
not evaluate your acceptance criteria, and a recurring prompt is not, by
itself, orchestration; see
[Loop & Graph Engineering](../core/loop-graph-engineering.md) for where
recurrence belongs in a loop contract.

## 4. Quality gates between iterations

The source guide wired automatic verification to a stop hook that fired when
the agent finished. Vibe has no stop hook: `hooks.toml` defines exactly three
events — `pre_tool`, `post_tool`, `post_agent` — and hooks are fail-open
unless a tool hook sets `strict = true` (PART-HOOKS sections 1-2). The two
verified gates that approximate "verify between iterations":

### Edit-time gate: `post_tool`

A `post_tool` hook fires if and only if the tool body actually ran. A hook
matched to the edit tools can run a check and append its output to the tool
result the model sees, via `hook_specific_output.additional_context`
(PART-HOOKS sections 3.2-3.3). Failures become visible immediately, and the
agent can self-correct in the same turn:

```toml
# <project>/.vibe/hooks.toml
[[hooks]]
name = "lint-after-edit"
type = "post_tool"
match = "re:(write_file|edit)"
command = "python ./.vibe/hooks/lint-gate.py"
```

```python
# ./.vibe/hooks/lint-gate.py
import json, subprocess, sys

payload = json.load(sys.stdin)
result = subprocess.run(["npm", "run", "lint"], capture_output=True, text=True)
if result.returncode != 0:
    print(json.dumps({
        "decision": "allow",
        "hook_specific_output": {
            "additional_context": "Lint failed after this edit:\n" + result.stdout[-2000:]
        },
    }))
# Empty stdout + exit 0 = passthrough.
```

### Turn-level gate: `post_agent`

A `post_agent` hook fires once per turn, after the agent finishes responding
with no pending tool calls. `decision: "deny"` with a `reason` injects the
reason as a user message asking the agent to retry — at most 3 retries per
user turn; the counter resets on each new user message, and a hook that
allows resets its own counter (PART-HOOKS sections 3.2-3.3, 3.7). `post_agent`
hooks accept no `match` and no `strict` (PART-HOOKS section 2):

```toml
[[hooks]]
name = "quality-gate"
type = "post_agent"
command = "python ./.vibe/hooks/turn-gate.py"
```

The gate script runs type-check, lint, and tests; on failure it prints
`{"decision": "deny", "reason": "<first failure, trimmed>"}`. With the retry
cap at 3, the worst case is bounded: three denied turns, then the session
proceeds. If the gate script itself fails — non-zero exit, timeout
(default 60 s), non-conforming stdout — the hook fail-opens with a warning
unless `strict = true` is set on a tool hook (PART-HOOKS sections 3.3, 3.5).
Design the gate to fail loudly, and do not treat a fail-open pass as green.

## 5. Script generation workflow

Script and automation generation is where iterative refinement pays fastest:
scripts are self-contained, testable in isolation, and immediately reusable.
The source guide's "70-90% time savings" figure is a practitioner
self-report, not a measurement — treat it as a directional claim.

Most production-ready scripts emerge after 3-7 iterations:

| Iteration | Focus | Prompt pattern |
|---|---|---|
| 1 | Basic functionality | "Create a script that [goal]" |
| 2-3 | Constraints and edge cases | "Add [constraint]. Handle [edge case]." |
| 4-5 | Hardening | "Add error handling, logging, input validation" |
| 6-7 | Polish | "Optimize for [metric]. Add usage docs." |

Worked example (PowerShell), one prompt per iteration:

1. *"Create a PowerShell function to list pods in a Kubernetes namespace."*
2. *"Add: filter by label selector and pod status. Show: pod name, status, age, restarts."*
3. *"Add: ability to delete pods matching the filter. Require: confirmation before deletion."*
4. *"Handle: kubectl not found, invalid namespace, permission denied. Add: verbose logging with `-Verbose`."*
5. *"Add: dry-run mode, JSON output for piping, help documentation. Ensure: works on Windows, Linux, macOS."*

Common pitfalls:

| Pitfall | Example | Mitigation |
|---|---|---|
| Hallucinated commands | `apt-get` on macOS | Pin the platform: "Ubuntu 22.04 only" |
| Security gaps | No input validation | Request explicitly: "validate all user inputs" |
| Over-engineering | Pulls in unnecessary libraries | "Minimal dependencies, stdlib preferred" |
| Context drift | Forgets requirements after iteration 5 | Checkpoint prompt: "Recap current requirements before the next change" |
| Platform assumptions | Bash features in `sh` | "POSIX-compliant" or "bash 4+" |

Iteration template:

```text
Current script: [paste or @-mention the file]

Iteration goal: [specific improvement]

Constraints:
- Must preserve: [existing behavior to keep]
- Must not: [things to avoid]
- Target environment: [OS, shell, runtime]

Success criteria: [how to verify this iteration worked]
```

## 6. Iteration strategies

When the feedback queue is longer than one pass, pick an order deliberately:

- **Breadth-first** — fix everything at one level before going deeper: first
  all type errors, then all lint warnings, then coverage, then performance.
  Best when many small defects block each other.
- **Depth-first** — complete one area fully before moving on: perfect the
  authentication flow, then user management, then settings. Best when areas
  are independent and you want one shippable slice early.
- **Priority-based** — security fixes, then data-integrity bugs, then UX,
  then style. Best under time pressure; ensures the expensive defects die
  first.

## 7. The review auto-correction loop

A specialized loop where the agent reviews, fixes, and re-reviews inside a
fixed budget. Acceptance requires evidence; stopping the loop does not
establish success.

```text
Review (identify issues)
      |
      v
Fix (apply corrections)
      |
      v
Re-review (verify fixes, detect new issues)
      |
      v
Accept on evidence <---- budget or no-progress -> stop with reason
```

Prompt template:

*"Review this PR with auto-correction. (1) Review with three scoped passes:
consistency, principles, defensive coding. (2) Fix all Must-fix findings.
(3) Re-review to verify the fixes introduced no new issues. (4) Fix all
Should-fix findings. (5) Re-review once more. (6) Accept only when every
blocking finding has a verified disposition and the required checks pass on
the current revision. Maximum 3 iterations; stop as EXHAUSTED if the budget
is consumed without acceptance; stop as NO-PROGRESS if two passes resolve
no blocking finding and produce no new evidence. A small diff is not
acceptance. Keep FAILED, EXHAUSTED, and UNKNOWN distinct from ACCEPTED."*

For the multi-reviewer variant, the fan-out rides the `task` tool: it spawns
subagent profiles (custom `agent_type = "subagent"` TOMLs, or the built-in
read-only `explore`), cannot recurse — depth is capped at 1 — and returns
text-only results the parent compares and summarizes (PART-AGENTS section 9).
Give each reviewer a distinct scope in its task description; adding reviewers
alone does not create independence.

Safeguards:

| Safeguard | Purpose | Implementation |
|---|---|---|
| Max iterations | Prevent infinite loops | State the cap in the prompt; enforce hard bounds with `--max-turns` (PART-CLI) or a `post_agent` retry cap of 3 per user turn (PART-HOOKS section 3.7) |
| Quality gates | Verify specified properties | Run type-check, lint, and tests after each fix; record the revision and results |
| Protected files | Prevent risky changes | Name them: "Do not modify package.json, migrations, or .env" |
| Progress check | Bound unproductive work | Track resolved blocking findings and new evidence; no progress is a stop reason, not acceptance |
| Recovery | Preserve a recoverable state | Checkpoint (commit) before fixes; note that rollback restores code, not mutated external state |

One-pass review versus the convergence loop:

| Aspect | One-pass review | Convergence loop |
|---|---|---|
| Detection | One opportunity to find issues | Find, fix, verify, repeat — either can still miss defects |
| Follow-up awareness | None | Each iteration sees the previous one |
| False positives | Can re-flag already-fixed code | Re-review catches this |
| Time cost | Fastest | 3+ review passes |
| Quality claim | Needs outcome evaluation | Needs outcome evaluation — more passes alone prove nothing |

Use one-pass for small diffs and experienced reviewers; use the bounded loop
for changes that need several correction passes, and keep the sign-off policy
of sensitive paths (security, migrations) human-owned either way.

Anti-patterns in review loops:

| Anti-pattern | Problem | Correction |
|---|---|---|
| Infinite loop | No bounded stop conditions | Set budgets and progress checks independently of acceptance |
| Scope creep | Each iteration silently changes requirements | Version the criteria; record who changed what and why, then re-run affected verification |
| Breaking fixes | A fix introduces new bugs | Re-review after each fix; run the quality gates |
| Protected file changes | Fixes touch package manifests, migrations | Explicit skip list in the prompt |
| Context loss | Original findings forgotten by iteration 3 | Maintain an issue list in a file across iterations |

## 8. Anti-patterns

### Moving target

```text
Wrong:   "Actually, let's change the approach entirely..." (five times)
Right:  Commit to an approach; iterate within it. If the approach is
        wrong, say so and restart deliberately.
```

### Perfectionism loop

```text
Wrong:  Keep improving forever.
Right:  Set "good enough" criteria up front — tests pass, main use cases
        handled, no critical issues — then ship and improve later.
```

### Lost context

```text
Wrong:  After many iterations, the goal has evaporated.
Right:  Periodically restate it: "Reminder: we're building a rate limiter.
        Current state: basic implementation works. Next: the Redis backend."
```

Compaction makes the last one mechanical: once `context_tokens` reaches
`auto_compact_threshold` (default 200,000 tokens; `0` disables auto-compaction),
the transcript is summarized — the conversation continues in the same session,
but details not carried into the summary are gone (PART-SESSIONS section 4).
You can compact deliberately with `/compact [instructions]` and steer what the
summary keeps (PART-SESSIONS section 4.2). State that matters across
iterations belongs in files, not in the hope that compaction preserves it.

## 9. State files and escalation

Long iteration chains break at session boundaries. The fix is the same one
[Task Management Across Sessions](task-management.md) develops in full: keep
a state file the agent reads at the start of each cycle — current target,
attempts so far, known issues, completed items:

```json
{
  "current_case": "test_auth_token_refresh",
  "attempts": 2,
  "known_issues": ["test_legacy_migration_edge_case"],
  "completed": ["test_login", "test_logout", "test_session_timeout"]
}
```

The state file survives compaction, restarts, and fresh sessions, because it
is a file in the repo rather than conversation memory. The attempt cap in the
file (skip a case after 3 failed attempts, flag it for review) is what keeps
the chain from burning tokens on a stubborn case.

Escalation when iterations keep failing on the same problem:

1. **Decompose**: break the failing task into 2-3 independent sub-tasks.
2. **Collect context**: dump errors, traces, and attempted fixes into a file
   the next attempt reads.
3. **Agent escalation**: retry the specific failing case with a different
   profile — a custom agent TOML in `~/.vibe/agents/` can carry a stronger
   `active_model` and its own tool permissions (PART-AGENTS section 8),
   selected with `--agent NAME` (PART-CLI).
4. **Human escalation**: file the issue with the collected context attached,
   marked as known-issue.

Never silently drop work: every failure is resolved, escalated, or written
down. This mirrors the durability rules in
[Loop & Graph Engineering](../core/loop-graph-engineering.md) — state lives
outside the context window, and every stop has a reason.

## See also

- [loop-graph-engineering.md](../core/loop-graph-engineering.md) — loop
  contracts, judgment allocation, and where `/loop`-style recurrence belongs
- [methodologies.md](../core/methodologies.md) — iterative refinement among
  the other development methodologies
- [hooks-events-reference.md](../core/hooks-events-reference.md) — the three
  hook events and the full wire protocol behind the quality gates
- [agents-and-skills-reference.md](../core/agents-and-skills-reference.md) —
  subagent profiles for review fan-out
- [context-engineering.md](../core/context-engineering.md) — what compaction
  keeps and what it costs
- [task-management.md](task-management.md) — the multi-session half of this
  loop: state files, resume mechanics, handoff discipline

## Known gaps

- **No condition loop or goal evaluator.** The source guide's autonomous
  goal command does not exist in the verified surface; no Vibe mechanism
  evaluates an acceptance condition on its own. The evaluator is a person, a
  script you run, or a `post_agent` hook with at most 3 deny-retries per
  user turn (PART-HOOKS section 3.7). Everything stricter is outside the
  session.
- **No prompt-time hooks.** The source guide injected guidance at prompt
  time; Vibe's stable hook surface has exactly three events — `pre_tool`,
  `post_tool`, `post_agent` — so nudges move to edit time (`post_tool` with
  `additional_context`) or turn end (`post_agent` deny-retry) (PART-HOOKS
  sections 1, 3.3, 3.7). The six-point harness hook API is
  [unified-harness] only and is not part of the stable surface
  (PART-HOOKS-UNIFIED).
- **No persistent todo store.** The source guide tracked iterations with
  built-in task tooling; none exists in the verified surface. Use the
  file-based convention (state or task files plus AGENTS.md rules,
  PART-AGENTSMD). A `/todo` command appears only as a release-2.25.8 delta
  gated on the experimental unified harness, and its underlying storage is
  not in the oracle — do not build on it (PART-COMMANDS deltas; PART-DELTAS).
- **Budget caps exist only in programmatic mode.** `--max-turns`,
  `--max-price`, `--max-tokens` apply with `-p` (PART-CLI); an interactive
  session has no enforced budget, so interactive iteration limits are prompt
  discipline only.
- **Time-savings figures are self-reported.** The script-generation ROI
  numbers inherited from the source guide are practitioner claims, not
  measurements; the guide does not reproduce them as fact.
