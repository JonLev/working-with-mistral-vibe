# Stage 5: Execute - execution to merged PR

Execute the validated plan in an isolated worktree, task by task and
layer by layer, verify quality, create and merge the PR, then clean up.

Run `/clear` before this stage.

## Prerequisite

A validated plan must exist at `docs/plans/plan-{name}.md` with all
issues resolved (output of the validate stage).

## Step 1: Worktree setup

Start the execution session in an isolated worktree. From the repository
root, exit the current session and launch:

```bash
vibe --worktree <plan-name>
```

Verified mechanics, rely on them rather than guessing:

- The worktree is created under
  `$VIBE_HOME/worktrees/<repo-name>-<repo-hash>/<plan-name>`, checked
  out on a **branch named `<plan-name>`** (created if missing; reused
  only if it belongs to this repo and is on that branch - otherwise Vibe
  errors out).
- The worktree is `cd`-ed into and implicitly trusted for this session;
  no trust prompt appears, and nothing is written to the trust store.
- Put the prompt AFTER the flag value or use `--`, otherwise the string
  is treated as the worktree name:
  `vibe --worktree -- "Execute docs/plans/plan-<name>.md"`.
- Starting from a subdirectory enters the matching subdirectory inside
  the worktree.
- Sessions started in a worktree are directory-scoped; `vibe --resume
  <session-id>` carries a session across worktrees when you need it.

All execution happens inside this session. The main checkout stays clean
throughout. Untracked files (`.env`, local config) do not exist in the
worktree - copy what the build needs manually, and never commit
credentials.

## Step 2: TDD scaffolding

Only for tasks marked as TDD in the plan.

For each TDD task, before any implementation:

1. Write the failing test(s) that define the acceptance criteria.
2. Run the tests to confirm they fail (red).
3. Commit the failing tests.
4. Mark the test file in the task for the implementation pass to find.

Do not write implementation code in this step.

## Step 3: layer-based execution

Parse the task list from the plan. Group tasks by layer (Layer 1 =
foundation, Layer 2 = depends on Layer 1, etc.).

For each layer:

1. Identify all tasks in the layer.
2. Implement each task. Independent tasks may be delegated to bounded
   programmatic runs (below); otherwise work through them inline, one
   commit per task:
   `git commit -m "feat: {task-description}"`.
3. Wait for all tasks in the layer to complete before starting the next
   layer.

**Bounded programmatic runs for independent tasks** (optional):

```bash
vibe --worktree <task-id> --trust -p "<task description, files to
modify, acceptance criteria, relevant ADRs>" --max-turns 12 --max-price
2 --output json
```

Each run gets its own worktree on its own branch, so tasks cannot see
each other's half-finished state. In `-p` mode, approval-requiring tool
calls are auto-denied unless you pass `--auto-approve` or configure the
agent's permissions - grant write access deliberately, matched to what
the task is allowed to touch. Programmatic worktree runs are never
auto-cleaned; remove them explicitly when the task is merged.

On CLI releases where the `task` tool can spawn custom subagents
(`agent_type = "subagent"` profiles), a per-task subagent is an
alternative - depth 1, text-only result, parent summarizes. On 2.25.7
with the unified harness, custom subagents cannot yet be spawned; do not
build the stage around it.

**Drift detection**: after each layer, diff the actual changes against
the plan spec. If implementation deviates significantly from the plan
(new files not in plan, plan files untouched), flag it and ask how to
proceed. Do not silently continue on drift.

**Task instructions template** (inline or per run):

```text
You are implementing one task from a validated plan.
Task: {description}
Files to modify: {file list}
Acceptance criteria: {criteria}
Relevant ADRs: {adr list}

First principles:
- Build state-of-the-art. No workarounds, no legacy patterns.
- Fix at the correct architectural level, never with component-level
  hacks.
- If you discover that the plan is wrong or missing context, stop and
  report. Do not improvise architecture.

Commit your changes when complete with message:
"feat: {task-description}"
```

## Step 4: quality gate

Run in parallel where the project supports it:

- Linter
- Type checker (if applicable)
- Full test suite

If all pass: proceed to the smoke test.

If any fail: debug with the failure output. Up to **3 fix attempts**,
re-running the quality gate after each. Still failing after 3 attempts:
stop, report the failure with the full error output, and wait for human
intervention.

**Integration smoke test** (skip for pure frontend or docs-only plans):

Run the smoke commands defined in the plan's `## Integration Verification`
section. Additionally:

- If GraphQL: run an introspection probe to verify the schema is
  accessible.
- If Docker services: scan container logs for ERROR-level entries.
- If new API routes: verify each returns expected status codes.

Smoke test failures get the same 3-attempt limit.

## Step 5: pre-PR documentation

In the worktree, before creating the PR.

**PRD reconciliation**: compare the implemented behavior against the
original PRD. Note any deviations or additions discovered during
implementation. Update the PRD with actuals. These updates ship in the
same PR as the feature.

**Plan archival**: move `docs/plans/plan-{name}.md` to
`docs/plans/completed/plan-{name}.md`. Update the status header.

Commit documentation updates:
`docs: reconcile PRD and archive plan for {feature-name}`.

## Step 6: push and PR

Push the worktree branch and create the PR with plain git plus, if
installed, the `gh` CLI (or `glab` on GitLab):

```bash
git push origin <plan-name>
gh pr create \
  --title "{feature-name}: {one-line summary from plan}" \
  --body-file .pr-body.md
```

PR body template:

```markdown
## Summary
{plan summary paragraph}

## Changes
{auto-generated from task list: bullet per task with files affected}

## ADRs
{list of ADRs created during this plan}

## Test Plan
{from plan test plan section}

## Smoke Test Results
{output from integration verification}
```

Merge using squash:

```bash
gh pr merge --squash --delete-branch
```

## Step 7: post-merge metrics

Switch back to the main checkout and update
`docs/plans/metrics/{name}.json` with execution data:

- Task count and per-layer breakdown
- TDD task count
- Diff stats (files changed, lines added/removed)
- Quality gate results (pass/fail, fix attempts)
- Smoke test results
- Drift score (0-1, how closely implementation matched plan)
- PR data (number, merge commit, timestamp)

Commit the metrics update.

## Step 8: worktree cleanup

Exit the worktree session. Verified cleanup rules:

- An interactive session auto-removes a worktree Vibe created this run
  **only if** there are no uncommitted changes, no untracked files, and
  no commits beyond the starting commit; otherwise it asks
  keep-vs-remove. A pre-existing attached branch is kept unless you
  confirm deletion.
- Programmatic worktree runs never auto-clean; remove them explicitly.
- Vibe records ownership under
  `$VIBE_HOME/worktrees/.claims/<repo-name>-<repo-hash>/` - nothing is
  removed without a claim record, so leftover worktrees from
  interrupted runs can be removed there too.

If a worktree outlived its session, remove it from the main checkout:

```bash
git worktree remove $VIBE_HOME/worktrees/<repo-dir>/<plan-name>
git worktree prune
```

## Example output

```text
Worktree session: vibe --worktree user-authentication (branch user-authentication)

TDD scaffolding: 2 tasks marked TDD
  RED: failing tests written for auth-token-validation
  RED: failing tests written for refresh-token-rotation
  Committed: "test: failing tests for auth pipeline (TDD)"

Layer 1 (3 tasks)...
  Implemented: JWT token generation service
  Implemented: user session model
  Implemented: auth middleware
  Layer 1 complete. 3 commits.

Drift check: Layer 1... no drift detected.

Layer 2 (2 tasks)...
  Implemented: login endpoint
  Implemented: refresh endpoint
  Layer 2 complete. 2 commits.

Quality gate...
  OK lint passed
  OK type check passed
  OK tests: 47 passed, 0 failed

Smoke test...
  OK GraphQL introspection
  OK POST /api/auth/login: 200
  OK POST /api/auth/refresh: 200

Pre-PR docs...
  PRD reconciled (1 minor deviation noted)
  Plan archived to docs/plans/completed/

PR created: #142 "user-authentication: JWT auth with refresh token rotation"
PR merged (squash). Branch deleted.

Metrics committed. Worktree auto-cleaned on exit.
Feature complete.
```

## When to use

After the validate stage confirms all issues are resolved. Never skip
validation: executing an unvalidated plan skips the independent review
that catches the issues cheap to fix on paper and expensive to fix in
code.

## Pipeline position

```text
ceo-review    -> product direction locked
eng-review    -> architecture locked
start         -> produce implementation plan
validate      -> validate before execution
execute       -> execute to merged PR              <- you are here
```
