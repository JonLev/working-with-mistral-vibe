---
title: "Module 07: Advanced Orchestration"
description: "Learning Path Module 07 (capstone): orchestrate one parent session over parallel subagents with the task tool, gate risky calls with hooks and per-tool permissions, isolate releases in worktrees, run headless with budgets, and schedule recurring work with /loop. 90-120 min, Production track."
tags: [learning-path, orchestration, subagents, task-tool, hooks, skills, permissions, worktrees, programmatic-mode, loop]
---

# Module 07: Advanced Orchestration

**Time:** ~90-120 min · **Complexity:** ★★★★☆ · **Track:** Production

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics on this page are cited inline as (PART-XXX) against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md). Anything the
oracle could not verify from public sources is in
[Known gaps](#known-gaps), never in the body. Structure and pedagogy are
adapted from the source guide; every mechanic is rebuilt from the oracle.

## TL;DR

- Vibe has one delegation mechanism: the **`task` tool** spawning
  `agent_type = "subagent"` profiles. Depth is capped at 1 — subagents cannot
  spawn subagents — results are text-only, and subagents run without user
  interaction (PART-AGENTS section 9).
- There are no recursive agent trees and no agent chains. The honest
  orchestration shape is **one parent session issuing `task` calls**:
  sequentially when each step needs the previous result, or in parallel when
  the calls are independent — tool calls within a single turn run
  concurrently (PART-HOOKS section 3.6).
- Conditional routing is a **`pre_tool` hook** with `match = "task"` that
  reads `tool_input.agent` and denies with a reason, plus per-subagent tool
  permissions (PART-HOOKS sections 3.3-3.4; PART-CONFIG section 1.3).
- Approval gates are **per-tool permissions**: `permission = "ask"` plus
  `allowlist`/`denylist` in `[tools.*]` (PART-CONFIG section 1.3;
  PART-PERMISSIONS section 4). Live tests settle the headless case — under
  the `ask` agent in `-p` mode, approval-required calls are auto-DENIED, so
  publish steps stay interactive (PART-CLI live tests).
- Custom slash commands are **skills**: a skill named `release-workflow` with
  `user-invocable: true` resolves as `/release-workflow`, with the rest of the
  input as extra instructions (PART-SKILLS section 1.3).
- Isolation is `vibe --worktree [NAME]` (named form: branch `NAME`; unnamed
  form: a `vibe/<name>` branch; implicitly trusted for the session)
  (PART-WORKTREES). Unattended runs are `vibe -p` with `--max-turns`,
  `--max-price`, `--max-tokens`, `--output json` (PART-CLI). Recurring work is
  `/loop <interval> <prompt>` — minimum 30 s, 50 loops per session, fires
  only when idle, survives resume (PART-SESSIONS section 5).

*Read if you coordinate multiple checks or specialized steps into one
workflow — release flows, audit fan-outs, scheduled maintenance — and want
the risky steps gated. Skip if you run single interactive sessions; Modules
01-04 already cover that, and this module builds on [Module 04's
agents](04-agents.md).*

## Goal

Orchestrate a multi-agent workflow inside one Vibe session: parallel and
conditional delegation to subagents, error handling that degrades instead of
aborting, approval gates on the dangerous steps, isolation in worktrees, and
headless runs with budgets. The capstone exercise wires all of it into one
release flow.

## What You'll Learn

- What multi-agent orchestration is in Vibe: one parent, `task` calls, depth 1
- Three product-agnostic orchestration patterns — sequential, parallel,
  conditional — and their honest Vibe implementations
- Error handling: graceful degradation, retry, rollback
- Approval gates with `[tools.*]` permissions, interactively and headless
- Isolation with `vibe --worktree`
- Orchestration from scripts: `-p` mode with turn, price, and token budgets
- Scheduling recurring prompts with `/loop`

---

## The Delegation Model: One Parent, N Subagents

A multi-agent workflow in Vibe is **one parent session** delegating work to
**subagent profiles** through the `task` tool. The tool takes a required
`task` string and an `agent` name (default `explore`) and returns a
`TaskResult`: the accumulated assistant text, `turns_used`, and `completed`
(PART-AGENTS section 9). Everything else follows from four hard constraints:

| Constraint | Mechanic | Design implication |
|---|---|---|
| Subagents are spawned only via the `task` tool | A profile with `agent_type = "subagent"` is delegation-only; `vibe --agent <name>` refuses it (PART-AGENTS sections 8-9) | You cannot launch a subagent from a script or a shell; orchestration happens inside the parent session |
| Depth limit is 1 | A `task` call from inside a subagent errors: "Agent depth limit of 1 reached. Complete the task in the current subagent." (PART-AGENTS section 9) | No recursive trees, no chains of agents — one parent, flat delegation |
| Results are text-only | The parent receives `response` text plus `turns_used` and `completed`; no message objects, no files (PART-AGENTS section 9) | Each subagent's contract must be "return a report"; structured data has to be serialized into the text |
| No user interaction | Subagents run without prompts to you; tool events surface as task progress lines, and the parent summarizes the result (PART-AGENTS section 9) | Never route a step that needs your judgment into a subagent — keep it in the parent |

The default `task` permission is `ask` with `allowlist = ["explore"]`, so the
built-in read-only `explore` subagent is auto-approved and any other
subagent prompts once unless you allowlist it under `[tools.task]`
(PART-AGENTS section 9).

Subagents inherit the parent's hook configuration, and their hook payloads
carry `parent_session_id` (PART-AGENTS section 9). A subagent that fails does
not throw — its errors append `[Subagent error: ...]` to the returned text
and mark the result incomplete (PART-AGENTS section 9). That is the raw
material for everything below.

## Orchestration Patterns

The three patterns below are product-agnostic doctrine. What changes per
product is the implementation; the Vibe implementations are given with each.

### Pattern 1: Sequential (Pipeline)

Each step needs the previous step's output, so the parent issues `task`
calls in successive turns, reading each text result before planning the
next. Vibe enforces nothing here — the sequencing comes from the data
dependency, and the depth limit already guarantees a single parent.

```text
        parent session
              |
   step 1: task -> [auditor subagent]  -> text report
              |
   parent reads report, decides next step
              |
   step 2: task -> [changelog subagent] -> text draft
              |
   parent merges the drafts and reports to you
```

**When to use**: workflows where step N+1 genuinely needs step N's output —
parse, then design, then generate. If the steps are independent, you are
paying latency for nothing; use Pattern 2.

### Pattern 2: Parallel (Fork-Join)

The parent issues several `task` calls in **one turn**. Tool calls within a
single LLM turn run concurrently (PART-HOOKS section 3.6), so independent
checks genuinely overlap:

```text
              parent session
                    |
       one turn, two task calls
          /                  \
 [release-auditor]     [changelog-drafter]     (concurrent)
          \                  /
     parent joins the two text results
                    |
             release report
```

**When to use**: independent checks — quality scan, security audit,
coverage. This is the corrected form of the source guide's "chains of
agents": one parent orchestrating parallel `task` calls, not agent trees.

### Pattern 3: Conditional (If-Then)

Routing lives in two verified mechanisms, not in an "agent that picks
agents":

```text
              parent session
                    |
          task call for <agent>
                    |
   pre_tool hook (match = "task")  reads tool_input.agent
          /                \
   deny + reason       allow
       |                   |
  model re-routes     subagent runs
  to an allowed agent
```

1. A **`pre_tool` hook** with `match = "task"` fires before the permission
   prompt, reads `tool_input.agent`, and can deny with a reason; the denial
   comes back to the model as a `<tool_error>` naming the hook, and the
   model re-routes (PART-HOOKS sections 1 and 3.3-3.4).
2. **Per-agent tool permissions**: each subagent profile carries its own
   `[tools.*]` tables, so what a routed agent *can do* is bounded by its
   profile — `enabled_tools`, `disabled_tools`, and per-tool
   `permission`/`allowlist`/`denylist` (PART-AGENTS section 8; PART-CONFIG
   section 1.3).

**When to use**: policy routing — "during a release, only these subagents
may run" — or when the wrong specialist has dangerous tools.

### Choosing a pattern

| Pattern | Dependency between steps | Latency | Vibe mechanism |
|---|---|---|---|
| Sequential (pipeline) | Output of step N feeds step N+1 | Sum of steps | Successive `task` calls in successive turns (PART-AGENTS section 9) |
| Parallel (fork-join) | None | Slowest branch | Multiple `task` calls in one turn — they run concurrently (PART-HOOKS section 3.6) |
| Conditional (if-then) | Routing rule exists | Varies | `pre_tool` hook deny + per-profile `[tools.*]` permissions (PART-HOOKS section 3.3; PART-CONFIG section 1.3) |

## Error Handling: Degrade, Retry, Roll Back

### Graceful degradation

A failed branch arrives as text: the error is appended as
`[Subagent error: ...]` and `completed` is false, while the other branches
return normally (PART-AGENTS section 9). The parent therefore always gets to
aggregate — report the failed check as failed, publish the rest:

```text
[release-auditor]    FAILED  -> "[Subagent error: tests failed]" (completed = false)
[changelog-drafter]  DONE    -> draft text (completed = true)
        |
[parent joins results]
        |
Release blocked: audit failed. Changelog draft is ready and preserved.
```

The doctrine: make each subagent's contract "return a verdict in text", so
the parent can join partial results instead of losing the whole turn.

### Retry

Retry loops around subagents are **not** a shell mechanic — subagents are
not invocable from a script, only through `task` (PART-AGENTS section 9).
The verified retry surfaces are:

| Mechanism | Scope | Limit |
|---|---|---|
| `post_agent` hook deny | Fires after the turn; the `reason` is injected as a new user message and the model retries the turn | Max 3 retries per hook per user turn; a hook that allows resets its counter (PART-HOOKS sections 3.3 and 3.7) |
| `/retry [instructions]` | You, after an interrupted model response; optional extra instructions | A non-side-channel command — rejected while the agent is busy (PART-COMMANDS section 2) |
| `--resume <SESSION_ID>` | Relaunch a saved session by ID — global, not folder-scoped; partial IDs supported | Requires session logging enabled; bare `--resume` is an error in `-p` mode (PART-SESSIONS section 3.3) |

Use the hook when the failure is mechanical and detectable at turn end (a
check failed, a file was not written); use `/retry` when the model was
interrupted mid-response.

### Rollback

| Stage | Mechanic | Note |
|---|---|---|
| Before anything runs | `vibe --worktree [NAME]` — the release runs on its own branch in its own checkout (PART-WORKTREES) | The named form checks out a branch named `NAME`; the unnamed form a `vibe/<name>` branch |
| During the session | `/rewind` — rewind to a previous message (or press Esc twice) (PART-COMMANDS section 2) | Conversation-level, not filesystem-level |
| Context loss mid-run | Compaction fallback: on a failed summarizer call a dedicated fallback call runs, and `ContextTooLongError` drops the oldest round and retries up to 3 times (PART-SESSIONS section 4.2) | Automatic while `raise_on_compaction_failure = false`, the default |
| Discarding the attempt | Worktree cleanup: on exit, a worktree Vibe created this run is removed automatically iff there are no uncommitted changes, no untracked files, and no commits beyond the starting commit; otherwise Vibe asks keep-vs-remove. Programmatic runs never clean up automatically (PART-WORKTREES) | The blast radius of a bad release is a deletable branch |

The doctrine: run risky coordinated work in a worktree so "undo" means
"delete the branch", not "un-pick the changes".

## Approval Gates

An approval gate is a per-tool permission, not a script you write:

```toml
# .vibe/config.toml (or an agent profile's overrides) — release gates
[tools.bash]
permission = "ask"
allowlist = ["git status", "git diff", "git log", "git tag"]
denylist = ["git push --force", "git push -f", "rm -rf *", "sudo"]
```

- `allowlist` entries are command **prefixes** that run without asking;
  `denylist` prefixes are auto-denied, and denylist wins (PART-CONFIG
  section 1.3; PART-PERMISSIONS section 4.4).
- Anything not allowlisted asks — so `git tag` above runs, while
  `git push` (deliberately absent from the allowlist) prompts every time.
  That prompt is the gate.
- The default `ask` agent already prompts for every tool call that is not
  allowlisted (PART-PERMISSIONS section 4.1), and every tool defaults to
  `permission = "ask"` (PART-PERMISSIONS section 4.5) — gates are mostly a
  matter of what you *allow*, not what you block.

The headless case is settled by live tests (vibe 2.25.0, 2026-09-24):
**under the `ask` agent in programmatic mode, approval-required calls are
auto-DENIED** — the effect reports `status: "cancelled"` — while read-only
bash commands still run because bash safety classification approves them
before the agent gate is consulted. Use `--auto-approve`/`--yolo` to allow
everything headlessly, which is exactly what you do not want on a publish
step (PART-CLI live tests). Production doctrine: run the checks and drafts
headless with allowlists and budgets; keep the publish step in an
interactive session where the approval prompt can actually reach a human.

## Isolation: Run Releases in a Worktree

`vibe --worktree [NAME]` gives the whole workflow its own checkout
(PART-WORKTREES):

| Form | Worktree / branch | Reuse |
|---|---|---|
| `vibe --worktree release-07` | Worktree `release-07` on a **branch named `release-07`** (created if missing) | Reused only if it belongs to the same repo and is on branch `NAME`; otherwise Vibe errors out |
| `vibe --worktree` | Worktree named after the prompt (slug, max 40 chars) on a **`vibe/<name>` branch** | Never reused; a free name is claimed on collision (`-2`, `-3`, ...) |

The worktree lives under `$VIBE_HOME/worktrees/<repo-name>-<repo-hash>/`
and is **implicitly trusted for the session** — an in-memory grant, never
persisted — so project `.vibe/` content (config, hooks, agents, skills)
that travels with the branch loads without a trust prompt
(PART-WORKTREES; PART-CONFIG section 2.5). Argument order matters:
`vibe --worktree "Fix the login bug"` treats the string as the NAME; put
the prompt first or use `--` (PART-WORKTREES). Cleanup on exit follows the
rules in the rollback table above.

## Unattended Runs: Programmatic Mode with Budgets

`-p` mode runs one prompt, prints the response, and exits. The verified
surface (PART-CLI):

```bash
vibe --trust -p "Use the release-workflow skill up to the publish step and report blockers." \
  --max-turns 12 --max-price 0.50 --max-tokens 200000 --output json
```

| Flag | Effect |
|---|---|
| `-p [TEXT]` | Programmatic mode; tool approval follows the selected agent or `default_agent` (PART-CLI) |
| `--max-turns N` | Cap on assistant turns (programmatic mode only) (PART-CLI) |
| `--max-price DOLLARS` | Session interrupted if cost exceeds the limit (PART-CLI) |
| `--max-tokens N` | Session interrupted if total prompt + completion tokens exceed the limit (PART-CLI) |
| `--output json` | All messages at the end as JSON; `streaming` is newline-delimited JSON per message (PART-CLI) |
| `--trust` | Trust the working directory for this invocation only; skips the trust prompt — the flag for non-interactive automation (PART-CLI) |

Budgets make unattended orchestration safe to schedule: an runaway loop
dies at the turn, price, or token cap instead of running all night. Pair
with a worktree so a budgeted run cannot dirty your real checkout, and
remember the approval semantics above — anything that would have prompted
is denied, not approved, in `-p` mode under `ask` (PART-CLI live tests).

## Scheduling: `/loop`

Recurring prompts are `/loop` (PART-SESSIONS section 5):

```text
/loop 30s Run the allowlisted release checks and list blockers in one line.
```

| Rule | Value |
|---|---|
| Interval format | `<number><unit>`, unit `s\|m\|h\|d`; minimum 30 s enforced after conversion (PART-SESSIONS section 5) |
| Per-session cap | 50 loops; then "Loop limit reached (50 per session.)" (PART-SESSIONS section 5) |
| Prompt | Non-empty and cannot start with `/` (PART-SESSIONS section 5) |
| Firing | Only when the session is idle — no active or queued turn; conflicts are skipped and retried on the next poll (PART-SESSIONS section 5) |
| Persistence | Stored in the session's `meta.json` and restored on resume — loops survive `--resume`/`-c` (PART-SESSIONS section 5) |
| Management | `/loop list` (also `ls`, or bare `/loop`); `/loop cancel <id\|all>` (PART-SESSIONS section 5) |

Because loops fire only when idle, a loop prompt never interrupts a
running turn — but it also never overlaps, so do not use `/loop` as a
parallel worker pool. It is a recurring check, not a scheduler for
concurrent jobs.

## Exercises

### Exercise 1: Watch the fork-join run

In any project, start `vibe` and prompt:

*"In one turn, use the task tool twice with the explore agent: one
investigation of how the source tree under src/ is organized, one of how
the tests are organized."*

Expected observations:

- Both `task` calls run concurrently — tool calls within a single turn run
  concurrently (PART-HOOKS section 3.6).
- Neither spawn prompts for approval — the default `[tools.task]` allowlist
  is `["explore"]` (PART-AGENTS section 9).
- Each subagent returns text only; the parent summarizes both results to
  you (PART-AGENTS section 9).

Then ask the session to have a subagent spawn another subagent. Expected:
a tool error — "Agent depth limit of 1 reached. Complete the task in the
current subagent." (PART-AGENTS section 9).

### Exercise 2: A conditional gate hook

```bash
mkdir -p .vibe/hooks
cat > .vibe/hooks.toml << 'EOF'
[[hooks]]
name = "release-subagent-policy"
type = "pre_tool"
match = 're:(task|subagent\.spawn)'
command = "python3 .vibe/hooks/check-subagent.py"
strict = true
description = "Only release subagents may be spawned during a release."
EOF
cat > .vibe/hooks/check-subagent.py << 'EOF'
import json, sys

payload = json.load(sys.stdin)
tool_input = payload.get("tool_input", {}) or {}
agent = tool_input.get("agent") or tool_input.get("agentType") or "explore"
allowed = {"release-auditor", "changelog-drafter"}
if agent not in allowed:
    print(json.dumps({
        "decision": "deny",
        "reason": (
            f"Subagent '{agent}' is not allowed here. "
            f"Use one of: {', '.join(sorted(allowed))}."
        ),
    }))
    sys.exit(0)
# Passthrough: empty stdout, exit 0.
EOF
```

Restart `vibe` in the project (the project root must be trusted — project
hooks load only under trusted roots) and prompt it: *"Use the task tool with
agent explore to investigate src/."*

Expected observations:

- The hook receives the invocation JSON on stdin with `tool_name` and
  `tool_input`, and fires before the permission prompt (PART-HOOKS sections
  1 and 3.2).
- The call is denied and skipped; the model sees
  `<tool_error>Tool 'task' was denied by hook 'release-subagent-policy':
  ...</tool_error>` and either re-routes or tells you it cannot
  (PART-HOOKS section 3.3).
- Break the script (exit 1): with `strict = true` a failing `pre_tool` hook
  denies the call — the policy fails closed (PART-HOOKS section 3.3).

### Exercise 3: Approval gates, interactive and headless

Add to `.vibe/config.toml` in a trusted project:

```toml
[tools.bash]
permission = "ask"
allowlist = ["git status", "git diff", "git log", "git tag"]
denylist = ["git push --force", "git push -f", "rm -rf *", "sudo"]
```

Then run each of these and compare:

```bash
vibe -p "Use the bash tool to run exactly: echo hello" --agent ask --max-turns 3 --output json
vibe -p "Use the bash tool to run exactly: git push" --agent ask --max-turns 3 --output json
```

(Add `--trust` if the directory is not yet trusted.)

Expected observations:

- `echo hello` executes — read-only commands are approved by bash safety
  classification before the agent gate is consulted (PART-CLI live tests).
- The `git push` effect reports `status: "cancelled"` — an
  approval-requiring call under the `ask` agent is auto-DENIED in `-p`
  mode (PART-CLI live tests).
- Interactively, the same `git push` prompts you instead: `git push` is not
  in your allowlist, so it asks every time (PART-PERMISSIONS section 4.4).
  The prompt is the gate; publish steps belong where it can fire.

### Exercise 4: Isolate the release in a worktree

```bash
vibe --worktree release-07
```

Expected observations:

- You are inside a worktree under `$VIBE_HOME/worktrees/` on a branch named
  `release-07`; there was no trust prompt — the worktree is implicitly
  trusted for the session (PART-WORKTREES).
- Exit immediately with no changes: the worktree Vibe just created is
  removed automatically (PART-WORKTREES). Commit something, exit again:
  Vibe asks keep-vs-remove instead (PART-WORKTREES).
- Try the unnamed form on a prompt:
  `vibe --worktree -- "Draft release notes for 3.5.0"` — without the `--`,
  the string would be taken as the NAME (PART-WORKTREES).

### Exercise 5 (capstone): a multi-agent, hooked, skill-gated release flow

You will build one release flow: two subagents, a routing hook, an
allowlist config, an approval-gated publish, and a user-invocable skill,
run in a worktree. Use a throwaway git repo so the tag and push are safe
(a local `git init` project with a `CHANGELOG.md` is enough; `git push`
will fail at the remote, which still exercises the gate).

**Step 1 — the subagents.** Two profiles in `.vibe/agents/`; the file stem
is the agent name (PART-AGENTS section 8):

```bash
mkdir -p .vibe/agents
cat > .vibe/agents/release-auditor.toml << 'EOF'
agent_type = "subagent"
display_name = "Release Auditor"
description = "Read-only release readiness checks: uncommitted changes, untracked files, failing tests."
safety = "safe"
enabled_tools = ["bash", "grep", "read_file"]

[tools.bash]
permission = "ask"
allowlist = ["git status", "git diff", "git log", "git tag -l"]
EOF
cat > .vibe/agents/changelog-drafter.toml << 'EOF'
agent_type = "subagent"
display_name = "Changelog Drafter"
description = "Drafts the CHANGELOG.md entry for a release from git history."
safety = "neutral"
enabled_tools = ["bash", "read_file", "write_file"]

[tools.bash]
permission = "ask"
allowlist = ["git log", "git tag -l"]

[tools.write_file]
permission = "ask"
allowlist = ["**/CHANGELOG.md"]
EOF
```

The auditor is read-only by its toolset. The drafter can write exactly one
file: the `allowlist` globs are matched with fnmatch against the resolved
absolute path, and everything outside them falls back to `ask`
(PART-CONFIG section 1.3; PART-PERMISSIONS sections 4.3 and 4.5).

**Step 2 — the routing hook.** Install the Exercise 2 hook and script
(`release-subagent-policy`, allowing exactly these two subagents).

**Step 3 — the allowlist.** In `.vibe/config.toml`:

```toml
[tools.task]
permission = "ask"
allowlist = ["explore", "release-auditor", "changelog-drafter"]

[tools.bash]
permission = "ask"
allowlist = ["git status", "git diff", "git log", "git tag"]
denylist = ["git push --force", "git push -f", "rm -rf *", "sudo"]
```

`git push` stays off the allowlist on purpose — the publish gate is the
approval prompt. `git tag` is allowlisted so the tag step runs without a
prompt (PART-CONFIG section 1.3; PART-PERMISSIONS section 4.4).

**Step 4 — the skill.** Skills live in `<root>/.vibe/skills/<name>/SKILL.md`
in trusted projects (PART-SKILLS section 1.2):

```bash
mkdir -p .vibe/skills/release-workflow
cat > .vibe/skills/release-workflow/SKILL.md << 'EOF'
---
name: release-workflow
description: Orchestrate a release end to end. Use when the user asks to cut, draft, or publish a release. Runs readiness checks through subagents and gates the publish step behind explicit approval.
user-invocable: true
---

# Release workflow

Orchestrate one release. You are the parent; delegate only with the task
tool, and never spawn a subagent from inside another subagent.

## Procedure

1. The version target is in the extra instructions (the text after
   /release-workflow). If it is absent, ask the user for it before doing
   anything else.
2. In ONE turn, spawn both checks as parallel task calls so they run
   concurrently:
   - agent `release-auditor`: "Run the release readiness checks and
     report blockers with file and line. Return a verdict in your final
     message."
   - agent `changelog-drafter`: "Draft the CHANGELOG.md entry for
     <version> from the git log since the last tag."
3. Join the two text results. If the auditor's verdict lists blockers,
   stop and report them; do not proceed to publish.
4. Publish: create the annotated tag for <version>. Then run
   `git push origin <tag>` — it will prompt for approval. That prompt is
   the release gate; do not bypass it and do not retry it silently.
5. Close by reporting: version, tag, changelog summary, audit verdict,
   and anything you did not do.
EOF
```

**Step 5 — run it.**

```bash
vibe --worktree release-07
```

Inside the session:

```text
/release-workflow 3.5.0
```

Expected observations:

- `/release-workflow` resolves: the first whitespace-delimited word is
  lowercased and looked up, and the skill loads only because
  `user-invocable: true`; the remainder — `3.5.0` — arrives as extra
  instructions (PART-SKILLS section 1.3).
- The project `.vibe/` files traveled with the branch into the worktree,
  and the worktree is implicitly trusted, so the config, hook, agents, and
  skill all load without prompts (PART-WORKTREES; PART-CONFIG section 2.5).
- Both `task` calls land in one turn and run concurrently; neither prompts
  — they are allowlisted under `[tools.task]` (PART-HOOKS section 3.6;
  PART-AGENTS section 9).
- The parent summarizes each subagent's text-only result — it does not
  replay their transcripts (PART-AGENTS section 9).
- The tag step runs (allowlisted); `git push` prompts — the gate
  (PART-PERMISSIONS section 4.4).
- Decline the push, then prompt the session to spawn some other subagent
  ("also have explore look at the tree"): the hook denies it with the
  policy reason (PART-HOOKS section 3.3).

A closing response in this guide's discipline looks like:

> Audit and changelog draft are done; publish is waiting on you.
>
> - `release-auditor`: clean working tree, no untracked files, tests pass.
>   Verdict: no blockers.
> - `changelog-drafter`: CHANGELOG.md entry drafted for 3.5.0 from the 14
>   commits since the last tag; I have not committed it.
> - Tag `v3.5.0` was created (allowlisted). `git push` was declined at the
>   approval prompt, so nothing left the machine.
>
> Next step is yours: approve the push, or tell me to drop the tag.

**Step 6 — validate headless.** Dry-run the same flow with a budget:

```bash
vibe --trust --worktree release-07 -p "Run the release-workflow skill up to but not including the publish step. Report the audit verdict and the changelog draft." --max-turns 12 --output json
```

Expected: the checks and draft run under the budgets; a publish attempt
would report `status: "cancelled"` — approval-required calls are
auto-denied headless (PART-CLI live tests); and the worktree is **not**
cleaned up on exit — programmatic runs never clean up automatically
(PART-WORKTREES).

### Exercise 6: Schedule a recurring check

In the interactive session:

```text
/loop 30s Run the allowlisted release checks and report blockers in one line.
```

Expected observations:

- A confirmation names the loop id and the interval; loops get 8-hex-char
  ids (PART-SESSIONS section 5).
- `/loop list` shows a table of Prompt | Next in | Every | ID; a second
  prompt only fires once the session is idle (PART-SESSIONS section 5).
- Exit and `vibe --resume <id>`: the loop is restored on resume — loops
  live in the session's `meta.json` (PART-SESSIONS sections 3.3 and 5).
- Try `/loop 5s ...`: rejected — minimum interval is 30 s
  (PART-SESSIONS section 5). Clean up with `/loop cancel all`.

---

## DO / DON'T

| DO | DON'T |
|---|---|
| One parent, flat fan-out — sequential or parallel `task` calls | Build recursive agent trees — depth is capped at 1 (PART-AGENTS section 9) |
| Make each subagent's contract "return a verdict in text" | Expect structured payloads or files from `task` — results are text-only (PART-AGENTS section 9) |
| Gate risky calls with `[tools.*]` `permission = "ask"` plus a narrow `allowlist` | Allowlist the publish step, or run it under `--auto-approve` |
| Run coordinated work in `--worktree` so rollback means deleting a branch | Let an orchestration run touch your real checkout |
| Use `strict = true` on policy hooks so they fail closed | Rely on fail-open hooks (default) for enforcement — a broken hook then lets the call through (PART-HOOKS section 3.3) |
| Give unattended runs budgets: `--max-turns`, `--max-price`, `--max-tokens` | Schedule a loop and assume approval prompts work headless — `-p` denies what it cannot ask (PART-CLI live tests) |
| Test the flow on a throwaway repo first | Wire a release flow straight to a shared remote |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| The hook never fires | Project hooks load only under trusted roots; or a duplicate `name` lost to the project entry | Trust the root (or launch in the worktree — implicitly trusted); hook names are the dedupe key (PART-HOOKS sections 1 and 3.6; PART-CONFIG section 2.5) |
| Every `task` spawn prompts for approval | Default `[tools.task]` allowlist is `["explore"]` | Add your subagents under `[tools.task] allowlist` (fnmatch patterns; denylist wins) (PART-AGENTS section 9) |
| A spawned subagent "cannot write" | Its profile restricts the toolset, or the path is outside its `allowlist` — and results are text-only regardless | Fix the profile's `[tools.*]` tables; report through the text result (PART-AGENTS section 8; PART-PERMISSIONS section 4.3) |
| `-p` run reports `status: "cancelled"` on a tool call | Expected: approval-required calls are auto-denied headless under the selected agent | Allowlist the call, or keep it interactive; `--auto-approve` allows everything (PART-CLI live tests) |
| `/release-workflow` does not resolve | Skill missing, not in a search path, or `user-invocable` not `true` | Check `.vibe/skills/release-workflow/SKILL.md` in a trusted root; run `/reload` after edits (PART-SKILLS sections 1.2-1.3; PART-COMMANDS section 2) |
| `vibe --agent <name>` errors "is a subagent" | Expected — subagents are delegation-only | Invoke through the `task` tool (PART-AGENTS section 8) |
| `/loop 5s` rejected, or loops stop at 50 | Minimum interval 30 s; per-session cap 50 | Use a valid interval; cancel finished loops with `/loop cancel <id\|all>` (PART-SESSIONS section 5) |
| Worktree still exists after exit | Commits, changes, or untracked files are present — or it was a `-p` run, which never auto-cleans | Keep it, or remove the branch and worktree yourself (PART-WORKTREES) |
| `/retry` or `/rewind` rejected | They are not side-channel commands — rejected while the agent is busy | Retry when the session is idle (PART-COMMANDS section 2) |

## Validation: You're Ready If

- You can state the four delegation constraints — subagent-only spawn,
  depth 1, text-only results, no user interaction — and what each rules out
- You have seen two `task` calls in one turn run concurrently and the
  parent join their text results
- You can route with a `pre_tool` hook on `match = "task"` and explain why
  `strict = true` is the fail-closed setting
- You can build an approval gate with `[tools.*]` `permission` +
  `allowlist`/`denylist`, and you know what happens to a gated call in
  `-p` mode under the `ask` agent
- You have run a workflow inside `--worktree` and can explain its cleanup
  rules
- You can launch an unattended run with turn, price, and token budgets
- You have completed the capstone: subagents + hook + skill + gates,
  end to end

## Known gaps

- **Live-run note (2026-09-24, vibe 2.25.7): no `task` tool on the live default backend — subagent spawns route through `subagent.spawn`.** In live `-p` sessions the model has no `task` tool; it discovers and uses `subagent.spawn` (with `subagent.wait` for results). The live `pre_tool` payload for a spawn carries `tool_name: "subagent.spawn"` and `tool_input` keys `agentName` (instance name), `agentType` (profile), and `message` (the task text) — there is no `tool_input.agent` on the wire. Exercise 2's original `match = "task"` therefore never fired, and the original script's `tool_input.agent` read never matched; both are corrected above (`match = 're:(task|subagent\.spawn)'`, agent read from `agent` or `agentType`) and the corrected hook was verified live to deny a non-allowed spawn (`hook_completed: Denied tool 'spawn'` naming `release-subagent-policy`, call `skipped`) and to passthrough the two allowed agents. Use a TOML literal string (single quotes) for the regex `match`: in a basic string the `\.` escape makes the whole `hooks.toml` unparseable and the hook silently never loads (verified live). The `task`/`tool_input.agent` shape remains what the oracle documents for the legacy backend (PART-HOOKS §3.4; PART-AGENTS §9); keep both spellings covered as the corrected matcher does.
- **Live-run note (2026-09-24, vibe 2.25.7): the built-in `explore` subagent and `.vibe/agents` profiles are not spawnable on the live baseline.** A spawn with `agentType: "explore"` fails (`subagent_type_not_found`; the model reports the type "isn't recognized"), and spawns of `release-auditor` / `changelog-drafter` from `.vibe/agents` likewise fail — matching the 2.25.8 changelog delta ("subagents defined in ~/.vibe/agents or .vibe/agents can be spawned again" on the unified backend, i.e. broken on the installed 2.25.7). What does work live, verified end to end: two spawns issued in one turn run concurrently, `subagent.wait` returns text-only results, and the parent joins and summarizes both (the fork-join core of Exercise 1 and the capstone) — via the default `generic` subagent type. Treat the named-profile paths of Exercise 1 and the capstone as documented-not-live on 2.25.7.
- **Recursive orchestration**: the source guide's "chains of agents" do not
  exist — the `task` tool enforces depth 1, and only
  `agent_type = "subagent"` profiles are spawnable. This module re-scopes
  chaining to one parent issuing sequential or parallel `task` calls
  (PART-AGENTS section 9).
- **Structured inter-agent payloads**: `TaskResult` carries text
  (`response`, `turns_used`, `completed`) — no message objects, no files.
  Any structured exchange must be serialized into the text by convention;
  there is no verified schema mechanism for it (PART-AGENTS section 9).
- **Shell-level retry and rollback scripts around agents**: the source's
  retry loop and rollback script invoke agents from a shell; subagents are
  reachable only through the `task` tool, so those are cut. The verified
  retry and rollback surfaces are the `post_agent` deny loop (max 3 per
  turn), `/retry`, `--resume <ID>`, worktree cleanup, `/rewind`, and the
  compaction fallback (PART-HOOKS section 3.7; PART-COMMANDS section 2;
  PART-SESSIONS sections 3.3 and 4.2; PART-WORKTREES).
- **Post-deploy monitoring**: no oracle-verified deployment trigger,
  health-check hook, or CI-notification mechanic exists in Vibe. The
  source's post-deploy curl script is cut; staged rollout here means the
  approval gate plus a worktree you can delete.
- **Headless scheduling**: `/loop` is verified for interactive sessions
  (loops are typed as slash commands and fire only when idle); the unified
  backend disables its scheduler when headless. Scheduling a `-p` run from
  cron is standard shell practice, but nothing inside Vibe schedules
  programmatic runs (PART-SESSIONS section 5).
- **Unified Harness subagent deltas**: 2.25.8 fixes subagent spawning from
  `~/.vibe/agents` and `.vibe/agents` on the unified backend and honors
  per-agent `system_prompt_id` there; hooks run inside subagents on the
  unified backend only since 2.25.1. These are
  **[unified-harness]** behaviors verified from source, not exercised
  against the live baseline (PART-AGENTS section 9).
- **Live baseline**: the oracle's live runs (approval semantics, hook
  execution) used vibe 2.25.0; 2.25.8 additions are verified from
  main-branch source. Expected observations above describe the documented
  2.25.8 surface (PART-CLI; PART-DELTAS).

## See also

- [Agents and skills reference](../core/agents-and-skills-reference.md) —
  full profile schema, discovery order, and `task` tool constraints
- [Hooks and events reference](../core/hooks-events-reference.md) — the
  three hook types, the stdin/stdout contract, and matcher syntax
- [Settings reference](../core/settings-reference.md) — every
  `config.toml` key including `[tools.*]`, and trust gating
- [Skill design patterns](../core/skill-design-patterns.md) — writing the
  skill bodies your workflows dispatch to
- [Tools reference](../core/tools-reference.md) — per-tool config keys and
  the permission resolution order
- [Memory systems](../core/memory-systems.md) — durable conventions across
  the sessions your orchestrations run in
- [Module 04: Agents & Specialization](04-agents.md) — profiles, personas,
  and the delegation basics this module builds on
- [Style guide](../style-guide.md)
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md)

You have finished the seven-module path. The core references above are the
depth layer; revisit them as your workflows grow.
