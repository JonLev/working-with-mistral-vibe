---
name: plan-pipeline
description: Orchestrate the complete plan-to-execution pipeline for a non-trivial feature - challenge product direction, lock architecture, write a five-phase plan, validate it in two layers, then execute it in an isolated worktree. Use for any feature touching more than two files or involving architecture decisions; run a single stage when only that gate is needed. Skip for typos, trivial refactors, and other changes where a planning mistake is cheap to undo.
---

# Plan Pipeline Orchestrator

Orchestrates the complete plan-to-execution pipeline. Runs the full
pipeline or a single isolated stage.

The `skill` tool supplies this skill's base directory when it loads;
relative paths in this skill resolve against it. Substitute it for
`<skill-dir>` when following the stage files.

## Stages

| Stage | Stage file | Purpose |
|---|---|---|
| 1 | `<skill-dir>/stages/ceo-review.md` | Challenge the brief, lock product direction |
| 2 | `<skill-dir>/stages/eng-review.md` | Lock architecture, diagrams, and test matrix |
| 3 | `<skill-dir>/stages/start.md` | 5-phase planning: PRD, research, ADRs, task list |
| 4 | `<skill-dir>/stages/validate.md` | 2-layer validation before any code is written |
| 5 | `<skill-dir>/stages/execute.md` | Worktree isolation, layered execution, quality gate, PR |

Read the stage file for the stage you are running and follow it step by
step. Stages expect to run in order; each stage's output is written to disk
before the next stage begins.

## Usage

```text
/plan-pipeline                     full pipeline, asks for context
/plan-pipeline --from=start        skip gates, start from planning
/plan-pipeline --from=validate     validate an existing plan
/plan-pipeline --from=execute      execute a validated plan
```

Text after `/plan-pipeline` is the user's extra instructions: the feature
description, a pointer to a PRD file, and optionally a `--from=<stage>`
flag naming the stage to start from. Stage names are `ceo-review`,
`eng-review`, `start`, `validate`, `execute`. Unrecognized extra
instructions are treated as the feature description.

## When to use each stage

- **ceo-review**: before any significant feature when the direction is
  not locked. Especially valuable when the request is specific -
  specificity signals the requester has already collapsed the solution
  space.
- **eng-review**: after direction is locked. Required for features with
  async components, external dependencies, or multi-step flows.
- **start**: for any non-trivial feature touching more than two files or
  involving architecture decisions.
- **validate**: always before execute. The cost of validation is
  negligible against the cost of discovering issues mid-execution.
- **execute**: after validate confirms all issues are resolved.

## Workflow

1. Collect context: what is being built, and which stage do we start
   from (respect a `--from=<stage>` extra instruction)?
2. ceo-review: product direction gate (skippable with
   `--from=eng-review` or later).
3. eng-review: architecture gate (skippable with `--from=start` or
   later).
4. CHECKPOINT: ask the user to confirm direction and architecture
   before planning.
5. start: run 5-phase planning, produce `docs/plans/plan-{name}.md`.
6. CHECKPOINT: present the plan for review before validation.
7. validate: 2-layer validation (structural plus specialist review).
8. execute: worktree isolation, layered execution, quality gate, PR.

## Dependency graph

```text
   ceo-review
        |
   eng-review
        |
      start
        |
    validate
        |
    execute
```

## Notes

Each stage writes its output to disk before the next stage begins. If
the pipeline is interrupted, resume with `--from=<stage>` using the
correct stage name. All decisions are recorded in
`docs/plans/plan-{name}.md` and the corresponding ADRs in `docs/adr/`.

Execution-stage isolation uses Vibe's worktree mechanics: the execute
stage starts the execution session with `vibe --worktree <name>`, which
creates (or reuses) a worktree under `$VIBE_HOME/worktrees/` on a branch
named `<name>`, implicitly trusted for the session. Worktree sessions
are directory-scoped; use `vibe --resume <session-id>` to carry a session
across worktrees.
