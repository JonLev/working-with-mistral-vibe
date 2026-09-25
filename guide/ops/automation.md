---
title: "Automation: Headless CI Runs and Scheduled Loops"
description: "The two automation surfaces in the verified Vibe CLI surface: programmatic mode (-p) for CI/CD with auto-DENY semantics, budget flags, and tool narrowing, and /loop for fixed-interval in-session recurrence — with three CI pattern sketches and the decision table between them."
tags: [guide, ops, automation, ci, cli]
---

# Automation: Headless CI Runs and Scheduled Loops

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Every command, flag, config key, and file path here cites the mechanics oracle,
> [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as
> `(PART-XXX)`. Claims executed against the installed CLI are marked *live-verified
> on 2.25.7* and cite
> [`docs/mechanics/live-checks.md`](../../docs/mechanics/live-checks.md);
> the rest are source-verified at release 2.25.8.
Both surfaces are [stable] mechanics — no experimental harness required.
> **TL;DR.** Two automation surfaces exist in the verified CLI, and neither is a
> daemon. **Headless runs** are `vibe -p "<prompt>"`: one process, machine-readable
> output, never a prompt — approval-required tool calls are **auto-DENIED**, not
> auto-approved, so a CI run is conservative by default (PART-CLI; PART-TRUST
> section 3.4; live-verified on 2.25.7, T4). **Scheduled recurrence** is `/loop`:
> a fixed-interval prompt firing inside one live session, minimum 30 seconds, at
> most 50 loops per session, restored on resume (PART-SESSIONS section 5). For
> anything richer — cron expressions, event ingestion, cross-run state — the
> scheduler is your shell or CI platform, shelling out to `-p`.

**Read if** you want Vibe to run in CI, cron, or on an in-session schedule without
a human typing the prompt. **Skip if** you want external events (tickets, alerts,
webhooks) to *trigger* runs — that receiver architecture is
[Event-Driven Agent Automation](../workflows/event-driven-agents.md); this page is
the surface underneath it.

## 1. The two surfaces

| Surface | What it is | Runs where | Backend | Citation |
|---|---|---|---|---|
| Scheduled recurrence | `/loop <interval> <prompt>` — fixed-interval prompt | Inside one live session; fires only when idle | [both] | PART-SESSIONS section 5 |
| Headless run | `vibe -p "<prompt>"` — send prompt, output response, exit | Any process: CI job, cron line, script | [stable] | PART-CLI; PART-TRUST section 3.4 |

No scheduler ships in the CLI. A `-p` run exits after responding, and the
unified-harness loop implementation is disabled when headless (PART-SESSIONS
section 5) — so recurring work is either a loop inside a session you keep open, or
your cron/CI invoking `-p` once per fire.

## 2. Programmatic mode for CI/CD [stable]

The canonical invocation — non-interactive trust, pinned posture, hard budget,
machine-readable output (PART-CLI; PART-TRUST sections 3.3-3.4):

```bash
vibe --trust -p "<prompt>" \
  --agent accept-edits \
  --output json \
  --max-turns 30 --max-price 2.00 --max-tokens 400000
```

| Flag | Binds | Citation |
|---|---|---|
| `--trust` | Session-only trust grant; never persisted to `trusted_folders.toml`; built for non-interactive automation | PART-TRUST section 3.3 |
| `-p` / `--prompt` | Programmatic mode: send prompt, output response, exit | PART-CLI |
| `--agent NAME` | `ask`, `plan`, `accept-edits`, `auto-approve`, or custom `~/.vibe/agents/NAME.toml`; `default_agent` (default `accept-edits`) applies in `-p` mode too — pin the posture explicitly | PART-CLI; PART-PERMISSIONS section 4.1 |
| `--output text\|json\|streaming` | `json` = all messages at end; `streaming` = newline-delimited JSON per message | PART-CLI |
| `--max-turns N` / `--max-price DOLLARS` / `--max-tokens N` | Hard bounds; session is interrupted when exceeded; **`-p`-only** — no verified cap exists for unattended interactive sessions | PART-CLI |
| `--enabled-tools TOOL` | Exact names, globs (`bash*`), or `re:` regex; repeatable; in `-p` mode disables every non-matching tool. `--disabled-tools` subtracts after it | PART-CLI |
| `--worktree [NAME]` | Isolated git worktree under `$VIBE_HOME/worktrees/`, implicitly trusted for the session | PART-WORKTREES |
| `--workdir DIR`, `--add-dir DIR` | Working directory; extra trusted-for-session roots (repeatable) | PART-CLI; PART-TRUST section 3.3 |

### Auto-DENY is the default posture

In `-p` mode the session runs headless: every approval or user-input callback the
runtime would raise is auto-denied, and `ask_user_question` / `exit_plan_mode` are
force-disabled (PART-TRUST section 3.4). An approval-required call is denied, never
silently approved (PART-CLI, live verification). Live-verified on 2.25.7: an
unlisted, approval-required `mkdir` under a custom allowlist failed with
`{"code": "tool_denied", ...}` and never executed (T4).

Read-only commands still run: bash safety classification approves safe commands
before the agent approval gate is consulted — under `--agent ask`, an `echo` ran
while an approval-requiring `touch` was denied (PART-CLI, live verification).
Anything you want executed headless must be allowlisted in config, enabled by the
selected agent profile, or explicitly opted out.

> Wire-shape note for receivers: an auto-denied call reported effect status
> `cancelled` on 2.25.0 and `failed` with the `tool_denied` error code on 2.25.7 —
> the semantics are identical. Key your parser on the error code, not the status
> label ([`live-checks.md`](../../docs/mechanics/live-checks.md),
> wire-shape deltas note).

### The deliberate opt-outs

| Opt-out | What it grants | Citation |
|---|---|---|
| `--auto-approve` / `--yolo` | Without `--agent`: selects the `auto-approve` profile (`bypass_tool_permissions = true`). With `--agent X`: keeps profile X and additionally force-bypasses its permissions | PART-CLI; PART-PERMISSIONS section 4.1 |
| `[tools.bash] allowlist` | Prefix match auto-allows headless (live-verified on 2.25.7: an allowlisted `echo probe-ok` ran while denylisted and unlisted commands were denied, T4) | PART-PERMISSIONS sections 4.4-4.5 |
| Agent profile | e.g. `plan` (write tools `never`, read-only) or `accept-edits` (file edits auto-approved) | PART-PERMISSIONS section 4.1 |

Admonition, because CI amplifies it: a `--yolo` job's blast radius is everything the
runner can reach — every tool call executes with no per-call check. And without
`--trust`, the run is not merely untrusted: the committed project
`.vibe/config.toml` (allowlists, permission rules) is **silently ignored** with a
stderr warning, and the run proceeds on defaults only (PART-TRUST sections
3.4-3.5; live-verified on 2.25.7: untrusted cwd, project allowlist not loaded,
approval-required command denied, T6). Your guardrails do nothing unless the job
passes `--trust`.

Prefix matching is the ceiling of config rules: bash denylists match command
prefixes, and the outside-workdir scan runs even for allowlisted commands (a
`grep ... /etc/passwd`-style call is never silently auto-allowed)
(PART-PERMISSIONS section 4.4). Content-level rules need a `strict = true`
`pre_tool` hook — see
[Production Safety Rules](../security/production-safety.md) (PART-HOOKS section 3).

### Worktrees and resume in CI

`--worktree NAME` checks out a branch named `NAME` (named form; the unnamed form
uses `vibe/<name>`), reuses a worktree only if it belongs to the same repo on the
same branch, and errors otherwise (PART-WORKTREES). Two CI-specific facts: a
programmatic run (`-p ... --worktree NAME`) **never cleans up its worktree
automatically** — pruning is the job's responsibility (PART-WORKTREES) — and the
`worktree_limit = 15` cap (0-100) is documented in release 2.25.8 (source), not
live-verified (PART-DELTAS). Put the prompt first or use `--`; a bare string after
`--worktree` is the NAME (PART-WORKTREES).

`--resume <SESSION_ID>` works in `-p` mode with an explicit ID (bare `--resume` is
an error there), resolves globally with partial IDs supported, and requires
`session_logging.enabled = true` — disabled session logging raises an error that
kills the run (PART-SESSIONS section 3.3; PART-CONFIG section 1.9).

## 3. Scheduled recurrence in-session: `/loop` [both]

The exact rules (PART-SESSIONS section 5):

| Rule | Value |
|---|---|
| Syntax | `/loop <interval> <prompt>` — confirm message reports the loop id and interval |
| Interval | `<number><unit>`, unit `s\|m\|h\|d`; **minimum 30 s** after unit conversion (`1m` = 60 s, valid) |
| Prompt | Non-empty; **cannot start with `/`** |
| Per-session cap | 50 loops (hard; "Loop limit reached (50 per session).") |
| Scheduling | Fixed-interval: `next_fire_at` advances after each firing, not from turn completion |
| Firing | Idle-only — the earliest due loop fires only when no turn is active and no turns are queued; conflicts are skipped and retried on the next poll |
| Persistence | Stored in the session's `meta.json` `loops`; **restored on resume** (`--resume`/`-c`) |
| Inspection | `/loop list` (or bare `/loop`) — table of prompt, next fire, interval, id |
| Kill switch | `/loop cancel <id\|all>` — `all` clears every loop and reports the count |

`/loop` is rejected while the agent is busy (it mutates session state). And note
what it is not: no cron expressions, no one-shot delays, no per-loop budget — the
budget flags are `-p`-only (PART-CLI), so a looped turn has no verified price cap
(see [Known gaps](#known-gaps)).

### `/loop` or cron + `-p`?

| Question | `/loop` | cron + `-p` |
|---|---|---|
| Runs unattended (no live session) | No — it lives in one session | Yes |
| Needs accumulated context per fire | Yes — same conversation each fire | Fresh run each time, or `--resume <id>` for continuity |
| Needs a hard `--max-price` bound | Not available (budgets are `-p`-only, PART-CLI) | Yes — `--max-price` / `--max-turns` / `--max-tokens` |
| Output consumed by a machine | No (turn output lands in the session) | `--output json` / `streaming` |
| Survives a machine restart | Only via `--resume` (loops are restored, PART-SESSIONS section 5) | Your scheduler's job |

Rule of thumb: `/loop` for "keep checking while I work in this session";
cron + `-p` for everything that must run when nobody is attached.

## 4. CI pattern sketches

Three shapes; each is one command plus the two facts that make it safe.

**Read-only PR reviewer.** The `plan` profile has write tools hard-disabled
(`permission = "never"` except `~/.vibe/plans/*`), and `--enabled-tools` narrows
the surface further (PART-PERMISSIONS section 4.1; PART-CLI):

```bash
vibe --trust --agent plan -p \
  "Review this pull request for correctness, security regressions, and missing tests. Report findings with file:line evidence; do not modify files." \
  --enabled-tools read_file --enabled-tools grep --enabled-tools "bash*" \
  --output json --max-turns 15 --max-price 1.00
```

Anything outside the narrowed surface is auto-denied (section 2); the review job
cannot write to the checkout even if the model tries.

**Code-change job with a narrow allowlist.** Commit the project allowlist, then
trust it into the run — without `--trust` the file is ignored (T6,
live-verified on 2.25.7):

```toml
# <project>/.vibe/config.toml — prefix matching (PART-PERMISSIONS section 4.4)
[tools.bash]
allowlist = ["uv run pytest", "git add", "git commit", "git status", "git diff"]
```

```bash
vibe --trust -p "Fix the failing test under tests/ and commit the fix on this branch." \
  --worktree "ci-fix-$CI_JOB_ID" \
  --max-turns 40 --max-price 3.00 --output json
```

Two CI facts: `git commit` is not in the default bash allowlist, so headless it
is denied without this entry or `--auto-approve` (live-verified on 2.25.7, T8
note); and a programmatic worktree run never auto-cleans — the job prunes
`$VIBE_HOME/worktrees/` itself (PART-WORKTREES), within the `worktree_limit = 15`
cap documented in release 2.25.8 (source) (PART-DELTAS).

**Scheduled drift check.** Cron fires; `--resume` carries the conversation so each
run compares against the last report (PART-SESSIONS section 3.3):

```bash
# crontab: report at 06:00 daily
0 6 * * * cd /srv/app && vibe --trust -p \
  "Compare the deployed API behavior against docs/api.md and report any drift since the last report." \
  --resume driftcheck-9f2a \
  --output json --max-turns 10 --max-price 1.00
```

The same command is a GitHub Actions `run:` step unchanged. Requirements:
`--resume` needs an explicit ID in `-p` mode (partial IDs match, latest wins), and
`session_logging.enabled = true` must be set in config
or the run errors out (PART-SESSIONS section 3.3; PART-CONFIG section 1.9).

## Known gaps

- **No first-party CI integration in the verified surface.** Nothing in the oracle
  documents a Vibe GitHub App, CI-side product, or scheduler daemon; we assert
  neither existence nor a roadmap — the automation surface is exactly
  `vibe -p` plus your platform.
- **No budget for `/loop`.** Budget flags are `-p`-only (PART-CLI); looped turns in
  an interactive session have no verified price or turn cap beyond the 50-loop
  session limit. Bound a recurring job with cron + `-p` if spend matters.
- **`worktree_limit = 15` is source-only.** Documented in release 2.25.8
  (PART-DELTAS), not live-verified on the installed build.
- **Background shell sessions and richer scheduling (cron expressions, one-shot
  delays, queues) are not covered here** — none exists in the verified surface;
  the surrounding architecture is
  [Event-Driven Agent Automation](../workflows/event-driven-agents.md).
- **Cross-run spend accounting is not a Vibe feature.** Budgets bound one session;
  anything aggregate is your CI platform's reporting on top of `--output json`
  (PART-CLI).

## See also

- [Event-Driven Agent Automation](../workflows/event-driven-agents.md) — the
  receiver architecture (event sources, filters, guardrails) that shells out to
  the `-p` surface this page documents
- [Production Safety Rules](../security/production-safety.md) — CI guardrails in
  depth: `strict` hooks, deny rules, and the headless-run safety contract
- [Session Observability](./observability.md) — consuming `--output json`, the
  session store, and cost tracking for automated runs
- The mechanics oracle: [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md);
  live security transcripts: [`live-checks.md`](../../docs/mechanics/live-checks.md)
