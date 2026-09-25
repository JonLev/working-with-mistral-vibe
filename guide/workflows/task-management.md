---
title: "Task Management Across Sessions"
description: "Multi-session work in Vibe: resume mechanics, a file-based task-tracking convention, the session lifecycle protocol, and the progress-file continuity artifact, rebuilt on verified mechanics."
tags: [workflow, sessions, agents-md, tasks, resume]
---

# Task Management Across Sessions

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Mechanics on this page are cited inline as (PART-XXX) against the
> [mechanics oracle](../../docs/mechanics/verified-mechanics.md). The source
> guide built this workflow on a persistent task API that does not exist in
> Vibe; every replacement is stated in the body, and anything unresolved is
> in [Known gaps](#known-gaps), never stated as fact.

Work on a real project spans sessions: the terminal closes, context fills up,
days pass. The source guide solved continuity with a persistent,
dependency-aware task store. Vibe's verified surface answers differently:
**session resume exists; a persistent task store does not.** So the workflow
splits in two — conversation continuity rides the session store, and task
state lives in files in the repository, governed by AGENTS.md rules. This
page covers both halves, plus the session lifecycle protocol that makes them
reliably resumable.

## TL;DR

- Resuming conversations is native: `vibe -c` continues from the per-terminal
  last-session pointer (else the latest session in the current directory);
  `vibe --resume <id>` resolves globally and accepts partial IDs; the
  `/resume` picker lists and deletes sessions (PART-SESSIONS section 3).
- Sessions persist as `meta.json` plus `messages.jsonl` under
  `~/.vibe/logs/session/<prefix>_<date>_<shortid>/`, are scoped to their
  origin directory, and require `[session_logging] enabled` (default `true`)
  to resume at all (PART-SESSIONS section 3; PART-CONFIG section 1.9).
- Task tracking is a **file-based convention**: task files checked into the
  repo, plus AGENTS.md rules telling the agent how to read and update them
  (PART-AGENTSMD). No task tooling, task-list environment variable, or
  dedicated task store exists in the verified surface.
- The session lifecycle protocol — open session, work, handoff, resume —
  and its `progress.md` continuity artifact make resumption take seconds
  instead of a cold start.
- Crossing worktrees requires an explicit `--resume <id>`, because the
  folder-scoped `-c` and picker only see sessions started in that worktree
  (PART-WORKTREES).

*Read if your project spans multiple sessions, terminals, or days and you
need the agent to pick up exactly where it left off. Skip if your work
completes in a single session — the default harness already covers that.*

Contents: 1 What exists and what does not · 2 The session store and resume
mechanics · 3 Task state as a file-based convention · 4 The session
lifecycle protocol · 5 Resume patterns · 6 Integrations · 7 Anti-patterns ·
8 Troubleshooting · See also · Known gaps

## 1. What exists and what does not

| Capability | Vibe surface | Anchor |
|---|---|---|
| Resume a conversation | `-c`, `--resume <id>` (partial IDs), `/resume` picker | [stable] PART-SESSIONS section 3 |
| Session persistence | `meta.json` + `messages.jsonl` under `~/.vibe/logs/session/` | [stable] PART-SESSIONS section 3.1 |
| Scheduled check-ins | `/loop <interval> <prompt>` — fixed interval, min 30 s, max 50 per session, fires only when idle, survives resume | [both] PART-SESSIONS section 5 |
| Isolated parallel work | `--worktree [NAME]`; crossing worktrees needs `--resume <id>` | [stable] PART-WORKTREES |
| Persistent task store | **None.** File-based convention instead (task files + AGENTS.md rules) | PART-AGENTSMD |
| Task create/get/list/update tooling | **None.** | not in the verified surface |
| Todo command | A `/todo` delta exists only in release 2.25.8, gated on the experimental unified harness; its storage is not in the oracle | [unified-harness] PART-COMMANDS deltas; PART-DELTAS |

The correction, stated plainly: the source guide's task API —
create/get/list/update tooling, a task-list environment variable, and an
on-disk task store — has no Vibe equivalent. Everything below is built on
what the oracle verifies. Pinned version numbers and changelog references
from the source do not carry over.

**When to use this workflow:** projects spanning multiple sessions, task
hierarchies with dependencies, resumption after compaction or interruption.
**When not to:** single-session implementations, quick fixes, tasks
completable in under ten minutes.

## 2. The session store and resume mechanics

### 2.1 Storage layout

Session logging (default on, `[session_logging] enabled = true`) persists each
session under `$VIBE_HOME/logs/session/` — default `~/.vibe/logs/session/` —
in a directory named `<prefix>_<YYYYMMDD_HHMMSS>_<short-id>/` (default prefix
`session`; short id = first 8 hex of the session ID) containing `meta.json`
(metadata) and `messages.jsonl` (one JSON object per message)
(PART-SESSIONS section 3.1; PART-CONFIG section 1.9). `meta.json` records
the session ID, git branch and commit, `environment.working_directory` (which
follows a session move) and `origin_directory` (which stays where the session
began) — both make the session findable from either directory
(PART-SESSIONS section 3.1).

`/log` prints the path to the current session's log file (PART-COMMANDS
section 2), and `/rename <title>` writes a manual title that auto-generation
never overwrites (PART-SESSIONS section 3.4) — both useful when juggling
several parallel workstreams.

### 2.2 `-c`, `--resume`, and the picker

| Invocation | Semantics |
|---|---|
| `vibe -c` | Continues from the per-terminal last-session pointer (`~/.vibe/logs/session/.last_session/<tty>`); if it does not reach the current directory, the most recent session **in the current cwd**; error if none exists (PART-SESSIONS section 3.2) |
| `vibe --resume <id>` | Resolves **globally** — no directory filter — with partial/short IDs; when several match, the latest wins (PART-SESSIONS section 3.3) |
| `vibe --resume` (no id) | Interactive picker; in programmatic mode (`-p`) an ID is required (PART-SESSIONS section 3.3) |
| `/resume` (alias `/continue`) | In-session picker, folder-scoped listing; `D` twice deletes a listed session — never the active one (PART-COMMANDS section 2; PART-SESSIONS section 3.3) |

Folder scoping is the rule that trips people: `-c` and the picker only see
sessions whose `origin_directory` or `environment.working_directory` matches
the launch directory (PART-SESSIONS section 3.2). Two consequences:

- A worktree has its own session scope. To carry a session into a worktree —
  or from one worktree to another — use the global `--resume <id>`
  (PART-WORKTREES).
- Resuming keeps the session's pinned `active_model` even if the configured
  default changed (PART-SESSIONS section 3.5).

## 3. Task state as a file-based convention

With no task store, the repository is the task store. The convention has two
parts: a task file (or files) checked into the repo, and AGENTS.md rules that
tell every session how to maintain them.

### 3.1 The AGENTS.md rules

AGENTS.md files are the instruction hierarchy Vibe loads into every session:
user-level `~/.vibe/AGENTS.md` always; project `AGENTS.md` at the repo root
and every level walking up from each project root to its trust root (trusted
folders only); subdirectory files load lazily when a file below them is read.
Priority is project over user, closer directory over distant
(PART-AGENTSMD).

Rules to write into the project AGENTS.md:

```markdown
## Task tracking

- Task state lives in `tasks/backlog.md`. Read it before starting work.
- Update the task file in the same turn you finish or change a task:
  set status (pending / active / blocked / done) and record evidence
  (test command + result) for every `done`.
- Never mark a task `done` without a passing verification command recorded
  next to it.
- One task `active` at a time. Dependencies are explicit: a task lists the
  task IDs it depends on; do not start a task whose dependencies are not
  all `done`.
```

Treat these rules as instructions, not enforcement: AGENTS.md steers the
model (it is injected with "these instructions OVERRIDE any default
behavior", PART-AGENTSMD), but a `pre_tool` or `post_agent` hook or a CI
check is what makes a rule a gate (PART-HOOKS sections 2-3).

### 3.2 Task files: what to record

The interesting fields from the source's task metadata port straight into
file entries. A task file is a table or list with whatever columns your
project needs — the convention, not the format, is the mechanic:

```markdown
# tasks/backlog.md

## T-4 Token refresh endpoint
- status: active
- depends: T-1 (login endpoint, done)
- files: src/auth/refresh.ts, src/middleware/auth.ts
- acceptance: POST /auth/refresh validates the refresh token and issues
  a new access token; tests in tests/refresh.spec.ts pass.
- notes: reuse the rotation logic from T-1; do not add a second token store.

## T-5 Integration tests
- status: pending
- depends: T-1, T-2, T-3
```

Design rules, each inherited from the source guide's good patterns:

- **Hierarchical decomposition**: break work into parent features and child
  tasks; mirror the natural project structure so dependencies are explicit.
- **Dependency-first ordering**: always list dependencies when a task
  references them; a "deploy" task without its "tests pass" dependency gets
  executed early by an eager agent.
- **Granular status updates**: one status change per unit of work, not one
  at the end. Frequent updates are what make resumption context-aware.
- **Self-contained context**: a task must be understandable by a future
  session with no memory of the last one — the bug, the expected behavior,
  the root-cause hypothesis, the relevant links.
- **Concise by design**: keep one-line summaries scannable in the file
  listing; detail lives in the task entry or a linked plan document, not in
  a subject line.

This is also what makes multi-terminal coordination work: two Vibe sessions
in the same repo read and write the same checked-in task file. The sessions
are independent (each has its own log and its own per-terminal `-c` pointer,
PART-SESSIONS sections 3.1-3.2); the file is the shared state. If both
terminals will *write*, give each writer its own `--worktree` and merge
(PART-WORKTREES) — or scope the task file so writers never touch the same
lines.

### 3.3 What the file convention survives

Because task state is ordinary repo content, it survives everything the
conversation does not: session end, system restarts, `/compact` (compaction
summarizes the transcript once `context_tokens` reaches
`auto_compact_threshold`, default 200,000 tokens; the session itself
continues, PART-SESSIONS section 4), and multi-day gaps. The inverse rule is
the one to internalize: **if you cannot reconstruct the work from files on
disk, your workflow will break at a session boundary.** Conversation memory
— including the resumable `messages.jsonl` — is a convenience, not the
system of record.

## 4. The session lifecycle protocol

Every agent session follows the same sequence from open to handoff. Defining
these steps explicitly, rather than leaving them implicit, is what makes
sessions reliably resumable after an interruption.

| Step | Action | Artifact | Anchor |
|---|---|---|---|
| START | Read project instructions | `AGENTS.md` (loaded automatically) | PART-AGENTSMD |
| INIT | Run environment bootstrap | `init.sh` / `npm install && npm run check` | your repo |
| READ | Load previous session state | `progress.md` (+ task file) | file convention |
| SELECT | Pick one task, set it active | task file | file convention |
| EXECUTE | Implement only that task | source files | — |
| VERIFY | Run verification (lint, tests, e2e) | exit codes | your checks |
| WRAP UP | Record completion and evidence | `progress.md` + task file | file convention |
| CLEANUP | Remove temp files; verify the repo restarts cleanly | repo state | — |
| COMMIT | Mark the session boundary | git history | — |
| HANDOFF | Write or update the handoff note | `docs/handoffs/` | file convention |

### The continuity artifact: `progress.md`

`progress.md` is the file that makes the READ step take seconds instead of
minutes. It lives in the project root, stays under about 50 lines, and is
written for the next agent session, not for a human reviewer. That
distinction matters: a handoff note is verbose by design — it tells a person
what happened, why decisions were made, what to watch for. `progress.md`
does something narrower. It records the active task ID, the last commit
hash, current blockers, and the single next action. No prose, no narrative.

```markdown
# Session Progress

last_updated: 2026-09-24
active_task: T-4
last_commit: a3f92c1
session_count: 3

## Status
- T-1: done (tests verified 2026-09-23)
- T-4: active (in progress)
- T-5: pending (blocked by T-2, T-3)

## Next action
Finish the refresh endpoint, then run: npm test -- --grep 'refresh'

## Blockers
None
```

The next session reads this at the READ step, picks up `active_task: T-4`,
orients itself in git history via the last commit, and moves directly to the
next action. No cold-start briefing required. `progress.md` (the agent's
machine-readable starting point) and the handoff note (the human's narrative)
serve different audiences reading the same session boundary; both are updated
at WRAP UP, which keeps them synchronized at no extra cost.

### The COMMIT step as a session boundary

A commit at the COMMIT step is not just a version-control operation. It is
the assertion that the repository is in a restartable state. The rule: only
commit when the task is complete and verified. A half-implemented task left
in a broken state means the next session's INIT step fails immediately —
informative, but cheaper to prevent by holding the commit until VERIFY
passes. For the failure mode when VERIFY is skipped, see
[Iterative Refinement](iterative-refinement.md) (its review loop keeps
acceptance and stop reasons distinct) and the verification discipline in
[Methodologies](../core/methodologies.md).

## 5. Resume patterns

### Days later, same terminal, same repo

```bash
vibe -c
```

The per-terminal pointer resolves the last session if it reaches the cwd;
otherwise the latest session in the cwd (PART-SESSIONS section 3.2). Then:

*"Read progress.md and tasks/backlog.md, summarize where the work stands,
and continue with the next action."*

The session transcript gives you the conversational thread back; the files
give you the ground truth. Read the files even when the transcript is
available — the transcript is what was said, the files are what was done.

### Different terminal, different machine checkout, or a worktree

```bash
vibe --resume 2d9a4db4
```

`--resume <id>` resolves globally with partial IDs (PART-SESSIONS section
3.3), which is also the only way to carry a session across worktrees
(PART-WORKTREES). If you do not know the ID, run `vibe --resume` for the
picker, or `ls ~/.vibe/logs/session/` and read any `meta.json` (fields
include `origin_directory`, `git_branch`, `title`) — PART-SESSIONS
section 3.1.

### Scheduled check-ins on long-running work

`/loop` schedules a recurring prompt on a fixed interval — `/loop
<interval> <prompt>` with units `s|m|h|d`, a 30-second minimum, at most 50
per session, firing only when the session is idle; loops survive resume, and
`/loop list` / `/loop cancel <id|all>` manage them (PART-SESSIONS section 5).
A check-in is a re-reading task, not a task executor:

*"Check tasks/backlog.md and progress.md; report the active task's status
and anything blocking it."*

Use it to keep a long-running session honest on a schedule; do not mistake
it for a dependency engine — it fires on a clock and evaluates nothing.

## 6. Integrations

### TDD + task files

Combine test-first development with the file convention by making the
red-green-refactor cycle explicit per task: for each component, a
"write failing tests" task that the "implement" task depends on, and a
"refactor" task that depends on the implementation. The acceptance field of
each task names the test command; a task is `done` only with its test
evidence recorded, which is exactly the AGENTS.md rule from section 3.1.
The methodology itself is covered in [Methodologies](../core/methodologies.md)
and [Iterative Refinement](iterative-refinement.md).

### Plan-to-tasks

Vibe has no plan mode toggle; planning rides the read-only `plan` agent,
whose `write_file`/`edit` permissions are `"never"` except for an allowlist
under `~/.vibe/plans/` — plan documents land there and nowhere else
(PART-AGENTS section 7). The plan-to-tasks step is a prompt:

*"Read the plan at ~/.vibe/plans/microservices-migration.md and convert it
into task entries in tasks/backlog.md, one per phase work item, with
dependencies mirroring the plan's ordering."*

Because plan files live outside the repo (`~/.vibe/plans/`), the conversion
into checked-in task files is also what makes the plan durable across
machines (PART-AGENTS section 7).

### Multi-session fan-out

Parallel workstreams get one `--worktree` each (PART-WORKTREES), a shared
checked-in task file for coordination, and explicit `--resume <id>` when a
workstream's session must move. Reviewer or exploration sub-tasks inside a
session can be delegated to subagent profiles through the `task` tool —
depth 1, text-only results (PART-AGENTS section 9) — but subagents do not
share your task-file writes unless their profile enables write tools, so
keep WRAP UP in the parent session.

## 7. Anti-patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| Monolithic task ("implement the entire payment system") | No resumable unit; progress is invisible | Break into phases and child tasks, each independently verifiable |
| Missing dependencies | An eager agent executes "deploy" before "tests pass" | List dependencies on every task; make the AGENTS.md rule enforce the order |
| Orphan task ("fix the bug from yesterday") | A future session has no idea what this means | Self-contained entries: symptom, expected behavior, root-cause hypothesis, links |
| Status mismatch (marked done, tests fail) | The file lies; resumption builds on sand | Verification command + recorded result required for every `done` |
| State only in conversation | Compaction summarizes it away; the next session never sees it | Files are the system of record: `progress.md`, task files, handoff notes |
| Generic task-file location shared across repos | Cross-project contamination; wrong state loaded | Task files live in the repo they describe — the folder scoping of sessions (PART-SESSIONS section 3.2) mirrors this rule |

## 8. Troubleshooting

**`-c` finds no session.** The per-terminal pointer did not reach the cwd
and no session in the current directory exists. Check the scope: `ls
~/.vibe/logs/session/` and read `meta.json` (`origin_directory`,
`environment.working_directory`) to find the session, then resume globally
with `--resume <id>` (PART-SESSIONS sections 3.1-3.3).

**Resume refuses with a session-logging error.** Resuming requires
`[session_logging] enabled = true` (the default; PART-CONFIG section 1.9) —
without logging there is nothing to resume (PART-SESSIONS section 3.3).

**A session will not follow you into a worktree.** By design: `-c` and the
picker are folder-scoped. Use the global `--resume <id>`
(PART-SESSIONS section 3.2; PART-WORKTREES).

**The agent ignores task-file dependencies.** AGENTS.md rules are
instructions, not gates. Tighten the prompt, restate the rule, and add a
deterministic gate — a `pre_tool` hook that denies the relevant tool calls,
or a CI check on the task file (PART-HOOKS sections 2-3).

## See also

- [memory-systems.md](../core/memory-systems.md) — the full native memory
  stack: AGENTS.md hierarchy, session store, cross-session writes
- [iterative-refinement.md](iterative-refinement.md) — the in-session loop
  this workflow hands off to
- [loop-graph-engineering.md](../core/loop-graph-engineering.md) — loop
  contracts and durable state for autonomous runs
- [settings-reference.md](../core/settings-reference.md) — `[session_logging]`
  and the config layer stack
- [agents-and-skills-reference.md](../core/agents-and-skills-reference.md) —
  the `plan` agent and subagent delegation
- [03-memory.md](../learning-path/03-memory.md) — the learning-path module
  on AGENTS.md and sessions

## Known gaps

- **Live-run note (2026-09-24, vibe 2.25.7).** Session lifecycle verified live end-to-end (fresh `-p` session, session ID found under `~/.vibe/logs/session/`, `--resume` with a partial ID restored full context, `-c` from the same directory continued the same thread; the file-based task convention — AGENTS.md rule driving a task-file status update with evidence plus `progress.md` — executed by the agent in one `-p` run). Two storage caveats observed on this install: (1) with the unified-harness backend (the default here), `-p` sessions log under `~/.vibe/logs/session/unified/<uuid>/` (a `meta.json` plus `journal/`/`chunks/`, no `messages.jsonl`); the `<prefix>_<date>_<shortid>/` layout of section 2.1 is the default-backend store and both exist side by side — `ls ~/.vibe/logs/session/` alone will not show unified sessions, so check `unified/` too when locating the newest session. (2) `meta.json` recorded `git_branch: null` and `git_commit: null` for every session observed on this host (both stores, including sessions inside git repos), so scripts must not rely on the git fields; `session_id`, `origin_directory`, and `environment.working_directory` were present and correct. Resume semantics themselves are unaffected.
- **No task tooling or store.** A persistent, dependency-aware task store —
  task create/get/list/update tooling, a task-list environment variable, a
  dedicated on-disk task directory — does not exist in the verified surface.
  The file-based convention in section 3 is the only supported port; do not
  wait for or invent tooling.
- **The `/todo` command is not usable guidance.** It appears only as a
  release-2.25.8 delta gated on the experimental unified harness
  ([unified-harness]), and its underlying storage is absent from the oracle
  (PART-COMMANDS deltas; PART-DELTAS). It must not be presented as
  available, and nothing on this page builds on it.
- **No cross-session messaging.** Sessions cannot talk to each other; the
  source guide's inter-session communication surface has no Vibe equivalent
  and was dropped. Coordination is the shared repo (task files, branches) or
  the `task` tool's parent-child delegation within one session
  (PART-AGENTS section 9).
- **Dependency "enforcement" is advisory.** AGENTS.md rules and task-file
  dependencies steer the model but cannot block an action by themselves;
  the verified gates are hooks (`pre_tool` deny, `post_agent` deny-retry
  capped at 3 per user turn, PART-HOOKS sections 3.3, 3.7) and checks you
  run outside the session. There is no task-level permission model.
- **Pinned source versions dropped.** The source guide's version pins and
  changelog references were removed per the port verdict; this page's only
  version anchor is the banner above.
