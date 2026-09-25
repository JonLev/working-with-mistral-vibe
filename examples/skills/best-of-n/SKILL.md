---
name: best-of-n
description: Generate bounded independent candidates for one task, score them blind against a rubric frozen before generation, and verify the selected result with a proof log. Use when a task has several plausible solutions, a wrong choice is costly, and an executable check or independent reviewer can evaluate the result. Do not use for mechanical work with one clear implementation and a direct acceptance test - one deterministic attempt beats ceremony.
---

# Best-of-N selection and proof

Run this when a wrong choice is expensive and selection can be checked.
Do not run it when the acceptance test is already clear and the solution
space is narrow.

## Inputs to collect before generation

- Task scope, exclusions, repository revision, environment,
  permissions, and budget.
- Acceptance criteria, mandatory failure conditions, and executable
  checks.
- A rubric with weights, observable anchors, a passing threshold, a
  tie-breaker, the candidate count (or a predeclared batch schedule),
  and a stop rule.
- The proof-log location: a file in the repository (for example
  `docs/proof-logs/<task>.md`) or the session scratchpad.

If any item is missing, return `needs_contract` and list the missing
fields. Do not generate candidates first and invent the rubric
afterward.

## Procedure

1. Freeze the contract in the proof log. Default to three candidates.
   Use five only when the expected improvement justifies the additional
   generation, scoring, and verification cost. If work runs in batches,
   declare every batch and the between-batch stop condition before
   generation.
2. Generate each candidate from the same frozen contract. Do not reveal
   candidate text, scores, or private reasoning across generators. Assign
   an opaque identifier to every generated candidate. For code, isolate
   candidates from each other: one `vibe --worktree <candidate-id>`
   session per candidate gives separate diffs by construction - each
   worktree lives under `$VIBE_HOME/worktrees/` on its own branch,
   implicitly trusted for the session. Bound each generation run:
   `vibe --worktree <candidate-id> --trust -p "<task contract>"
   --max-turns N --max-price D --output json`. Add one proof-log line
   for every generated candidate, including rejected ones.
3. Preserve each candidate as a separate artifact: a worktree diff
   against the common base revision for code, a file per candidate for
   text. Blind provenance and presentation order for scoring when
   practical.
4. Apply the fixed rubric to every candidate in the declared N, or to
   every candidate in the completed predeclared batch. Record
   criterion-level evidence and disqualify mandatory failures.
5. Select the highest passing candidate using the declared tie-breaker.
   Treat any combination of candidate fragments as a new synthesized
   candidate with its own ID, score, and verification.
6. Run the declared executable checks in the recorded environment. For
   headless verification runs, use programmatic mode with a budget:
   `vibe --trust -p "<run the checks and report exactly what passes>"
   --max-turns N --output json`. In `-p` mode, approval-requiring tool
   calls are auto-denied unless `--auto-approve` is passed or the
   agent/permission config allows them - a verify-only run therefore
   cannot edit files even if the prompt asks it to. Match the agent to
   what the run is allowed to touch, and grant more only deliberately.
   Capture commands, output location, exit status, artifact hash or
   revision, and uncovered scope.
7. If executable verification cannot decide the requirement, request a
   reviewer who did not generate the candidate and who receives a fresh
   task packet. On CLI releases where the `task` tool can spawn custom
   subagents (agent_type = "subagent" profiles), a subagent reviewer is
   one option: fresh context, depth 1, text-only result. Record shared
   model, context, tools, and repository access as correlation risks.
8. Finish the proof log with `PASS`, `FAIL`, or `UNKNOWN`. `UNKNOWN`
   blocks a claim that the requirement was verified.

## Guardrails

- Candidate generation is not selection. Selection is not synthesis.
  Majority vote is not evidence of correctness.
- Never use a self-grading generator as the only acceptance gate.
- Generate and score all candidates in the declared N before selection.
  A batched run may stop only after the complete predeclared batch is
  evaluated and its predeclared stop condition is met. Do not keep
  sampling until an answer feels persuasive.
- Do not claim candidates are independent solely because they came from
  different sessions. State the isolation controls and the remaining
  shared context.
- Preserve failed candidates and failed checks in the proof log. They
  bound what was actually tested.
- Worktrees from programmatic runs are never auto-cleaned: remove them
  explicitly once the selection is recorded.

## Required output

Return this concise record and write the full details to the proof log:

```text
BEST-OF-N RESULT
Task: <scope>
Contract: <rubric version, N or batch schedule, stop rule>
Candidates: <every generated candidate ID>
Selected: <candidate ID or none>
Verification: PASS | FAIL | UNKNOWN
Evidence: <proof-log path and artifact links>
Remaining limits: <uncovered scope or none>
```

## Proof-log format

```markdown
# Proof log: <task>

## Contract
Scope, exclusions, base revision, budget, environment, permissions.

## Rubric
Criteria, weights, anchors, threshold, tie-breaker. Frozen at <time>.

## Candidates
| ID | Worktree / artifact | Status | Notes |

## Scores
Per candidate, per criterion, with evidence pointers.

## Verification
Commands, output locations, exit statuses, hashes, uncovered scope.
```
