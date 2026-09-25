---
title: "Module 02 — The Core Loop"
description: "How Vibe works turn by turn: the seven-step loop, intelligent scope, compaction, agents and thinking levels, the WHAT/WHERE/HOW/VERIFY request framework, and session rewind and resume"
tags: [learning-path, core-loop, agents, compaction, sessions, prompting]
---

# Module 02 — The Core Loop

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics on this page are cited inline as (PART-XXX) against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md). Anything the
oracle could not verify from public sources is in
[Known gaps](#known-gaps), never in the body. Structure and pedagogy are
adapted from the source guide; every mechanic is rebuilt from the oracle.

**Time:** ~60–75 min · **Complexity:** ★★☆☆☆ · **Track:** Beginner

Prerequisite: Module 01 (Installation & Setup) — you can run `vibe` in a
project folder.

## TL;DR

- Every turn runs the same seven-step loop: you prompt, the agent reads
  (`grep`, `read_file`), analyzes, decides, proposes, you review, changes
  land on disk. The decision point is the tool gate (PART-PERMISSIONS §4.1–§4.4).
- The agent reads with intelligent scope: it searches first and reads what
  your prompt points at. `@` mentions are the one scope mechanic with hard,
  verified caps — 2,000 lines and 50 KB per file, 8 files per prompt
  (PART-SESSIONS §6.1).
- There is no live context meter. In Vibe, 200,000 is
  `auto_compact_threshold`, the default compaction trigger — not a context
  window. `/compact [instructions]` summarizes on demand (PART-SESSIONS
  §4.1–§4.2).
- "Modes" are agents: `ask`, `plan`, `accept-edits` (the default), and
  `auto-approve`, cycled with Shift+Tab. There are no `/plan`, `/think`, or
  `/mode` commands. Thinking is a per-model setting, selected at runtime with
  `/thinking` (PART-AGENTS §7, §10; PART-CONFIG §1.1; PART-COMMANDS §2).
- Sessions persist under `~/.vibe/logs/session/` and resume with `vibe -c`,
  `vibe --resume <ID>`, or `/resume`. `/rewind` (or Esc Esc) steps back;
  `/clear` starts fresh (PART-SESSIONS §3.1–§3.5; PART-COMMANDS §2).

*Read if you are new to Vibe and want to understand what actually happens
between your prompt and the diff. Skip if you already work daily in the CLI
and know how the tool gate and the agent cycle behave.*

## Goal

Understand how Vibe actually works: the turn loop, how it reads your project,
how compaction keeps a session going, what the agent selection really changes,
and how to structure a request so the first response is the useful one.

## What You'll Learn

- The complete interaction loop (prompt → read → analyze → decide → propose → review → apply)
- How the agent reads and scopes your project
- How compaction works and when to trigger it manually
- Agents: `ask`, `plan`, `accept-edits`, `auto-approve`, and thinking levels
- How to structure effective requests
- How sessions persist, rewind, and resume

## The Complete Loop (Deep Dive)

Every interaction with Vibe follows this sequence:

```text
┌──────────────────────────────────────────────────────────────┐
│ 1. YOU PROMPT                                                │
│    "Fix the bug in auth.js on line 45"                       │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. VIBE READS                                                │
│    - Reads auth.js in full (read_file)                       │
│    - Finds related files (auth-test.js, config.js)           │
│    - Understands the error context                           │
│    - Analyzes call sites where auth.js is used (grep)        │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 3. VIBE ANALYZES                                             │
│    - Identifies the root cause                               │
│    - Considers side effects                                  │
│    - Plans minimal changes                                   │
│    - Checks for tests                                        │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 4. VIBE DECIDES                                              │
│    Does the change need tests? → Suggest test updates        │
│    Is the tool call safe? → The tool gate prompts you        │
│      or auto-approves, per the selected agent                │
│    Should multiple files change? → Show full scope           │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 5. VIBE PROPOSES                                             │
│    Shows you:                                                │
│    - Description of changes                                  │
│    - diff view (what's changing)                            │
│    - Reasoning                                               │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 6. YOU REVIEW                                                │
│    - Read the diff carefully                                 │
│    - Ask questions if unclear                                │
│    - Accept or reject the changes                           │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 7. CHANGES APPLIED                                           │
│    - Files updated on disk                                   │
│    - You can now test/run the code                           │
│    - Next iteration begins                                  │
└──────────────────────────────────────────────────────────────┘
```

Step 4 is the part you control most: the tool gate runs before a tool
executes. In order, it checks the bypass flag (set by `auto-approve` or
`--auto-approve`), then the tool's own per-call resolution, then the tool's
configured permission — which defaults to `ask`, meaning a prompt (PART-PERMISSIONS
§4.2). Which tool calls run without a prompt depends on the selected agent:
under the default `accept-edits` agent, `write_file` and `edit` run
automatically, so step 7 happens without a prompt for file changes (PART-PERMISSIONS
§4.1). That is the habit to build here: review the diff after each turn,
because file edits are not gated by default.

For larger reads, the agent can also delegate exploration to the built-in
`explore` subagent through the `task` tool — read-only, text-only result back
to the parent (PART-AGENTS §9) — and load instructions with the `skill` tool
(PART-SKILLS §1.4).

## How the Agent Reads Your Project

The agent doesn't read everything. It's **intelligent about scope**: search
first, read what the search turns up, follow the callers.

### Example: You ask "Fix the login bug"

The agent will:

1. **Search for "login"** in your codebase (`grep`)
2. **Find `auth.js`, `login.js`, `auth-controller.js`**
3. **Read those files first** (`read_file`)
4. **Find callers** (what calls these files?)
5. **Read tests** (if they exist)
6. **Find related config** (environment variables, constants)

What it won't do is read your whole tree because you mentioned one bug —
unless the prompt is vague enough to force the search wide. The verified
scope mechanic on your side is the `@` mention (PART-SESSIONS §6.1):

- `@path` stays in the prompt text, and a mentioned text file is read fresh
  into the turn — as an injected read on the stable backend, or as attached
  content blocks on the unified-harness backend. Re-mentioning re-reads.
- **Folders are not auto-read**: the path stays in the message for the agent
  to read or grep on demand.
- Caps: 2,000 lines and 50 KB per mentioned file, at most 8 file mentions
  per prompt (PART-SESSIONS §6.1).

### Be specific about scope

| Prompt | Effect |
|---|---|
| *"Fix the bugs"* | The agent has to guess which files; the search goes wide and the first proposal may miss your intent |
| *"Fix the login bug in `auth.js` on line 45"* | The agent reads exactly what matters and proposes a minimal change |

## Context and Compaction

**Context** is the conversation the model sees each turn: your prompt, the
agent's messages, tool results, file reads. Every turn re-sends it, so a
long session costs more and drifts. Vibe manages that with compaction — not
with a meter.

| Mechanic | Verified value | Citation |
|---|---|---|
| Default compaction trigger | `auto_compact_threshold = 200000` tokens (global default) | PART-SESSIONS §4.1; PART-CONFIG §1.1 |
| Per-model override | `auto_compact_threshold` inside a `[[models]]` entry wins over the global value | PART-CONFIG §1.1 |
| Disable auto-compaction | `auto_compact_threshold = 0` | PART-SESSIONS §4.1 |
| When it fires | Before every turn, if the context token count has reached the threshold | PART-SESSIONS §4.1 |
| Warning | Once per session, at 50% of the threshold | PART-SESSIONS §4.1 |
| Manual compaction | `/compact [instructions]` | PART-COMMANDS §2; PART-SESSIONS §4.2 |

Read the first row carefully: **200,000 is a compaction trigger, not a
context window.** Vibe has no live percentage meter, and the oracle records
no window figure for the default model — don't infer one from the threshold.
The only meter-like behavior is a one-time-per-session warning once the
context reaches half the threshold (PART-SESSIONS §4.1).

### `/compact` — the manual valve

```text
/compact keep the validator API decisions, drop the transcript of test runs
```

`/compact` optionally takes instructions, appended to the configured
`compaction_prompt` to steer the summary. On success it appends a summary
message and resets the context token counter; the session and the visible
conversation continue unchanged (PART-SESSIONS §4.2). You can compact multiple
times in one session.

## Modes Are Agents (and One Model Setting)

Vibe has no `/plan`, `/think`, or `/mode` commands (PART-COMMANDS §2). What
other tools call "modes" maps to two verified mechanics: which agent is
selected, and the thinking level of the model.

### The four cycled agents [stable]

| Agent | Safety | Approval behavior | Use for |
|---|---|---|---|
| `ask` | neutral | "Requires approval for tool executions" — every tool call not allowlisted prompts | Reviewing every action; unfamiliar repos |
| `plan` | safe | "Read-only agent for exploration and planning" — `write_file` and `edit` are `never`, except plan files under `~/.vibe/plans/` | Complex features, risky changes, when you're unsure of the approach |
| `accept-edits` (default) | destructive | "Auto-approves file edits only" — `write_file` and `edit` run without prompts, other tools follow the normal gate | Small fixes, contained features, the daily default |
| `auto-approve` | yolo | "Auto-approves all tool executions" — bypasses the tool gate entirely | Disposable dirs, throwaway experiments, never a repo you care about |

Descriptions verbatim; overrides per (PART-PERMISSIONS §4.1; PART-AGENTS §7).

Switching:

- **Shift+Tab** cycles the running session through `ask → plan → accept-edits →
  auto-approve`, then any custom agents by name (PART-AGENTS §10).
- `vibe --agent plan` selects at launch (PART-CLI; PART-AGENTS §10).
- `default_agent` in `~/.vibe/config.toml` (default `accept-edits`) sets the
  startup agent for interactive and programmatic mode (PART-CONFIG §1.5).

The `plan` agent is Vibe's plan mode: it explores and reasons, and the only
files it can write are plan documents under `~/.vibe/plans/` (the
`$VIBE_HOME/plans/*` allowlist) (PART-AGENTS §7; PART-PERMISSIONS §4.1). The
flow you want: *plan → review the plan → Shift+Tab to `accept-edits` → apply.*

### Thinking levels [stable]

Thinking is a per-model setting — `thinking = "off" | "low" | "medium" |
"high"` on a `[[models]]` entry, default `"off"`; the shipped default model
entry uses `"high"` (PART-CONFIG §1.1). At runtime, `/thinking` selects the
level (PART-COMMANDS §2). Use a high level for architecture decisions and
hard bugs; it costs latency and tokens.

## Structuring Effective Requests

### The framework: WHAT, WHERE, HOW, VERIFY

Good requests follow this pattern:

| Part | Purpose | Example |
|---|---|---|
| **WHAT** | The goal | "Fix the null pointer bug" |
| **WHERE** | The scope | "in `src/auth/login.js` on line 45" |
| **HOW** | Constraints | "without changing the API signature" |
| **VERIFY** | Expected result | "All existing tests should pass" |

### Example good request

```text
Fix the bug where login fails for emails with + symbols
WHERE: src/controllers/auth.js, line 78 (email validation regex)
HOW: Update the regex to allow + in emails, but keep existing validation otherwise
VERIFY: Existing tests in tests/auth.test.js should pass
```

### Example poor request

```text
Fix the bugs
```

The agent has to ask follow-up questions instead of solving — or worse, it
guesses a scope you didn't intend.

## Sessions: Rewind, Resume, and Clear

A **session** is your current conversation. Sessions are logged under
`~/.vibe/logs/session/` (PART-SESSIONS §3.1), and the first user message pins
the resolved model alias into the session — resuming later keeps that model
even if your default changed (PART-SESSIONS §3.5).

| Action | Command | Effect | Citation |
|---|---|---|---|
| Step back | `/rewind`, or Esc Esc with empty input | Rewind to a previous message | PART-COMMANDS §2 |
| Continue the last session here | `vibe -c` | Resumes the most recent session for this folder, pinned model kept | PART-SESSIONS §3.2 |
| Resume by ID, from anywhere | `vibe --resume <ID>` | Global lookup; partial IDs supported | PART-SESSIONS §3.3 |
| Pick a session | `/resume` (alias `/continue`) | Picker over saved sessions; `D` twice deletes one | PART-COMMANDS §2; PART-SESSIONS §3.3 |
| Start fresh | `/clear` (alias `/new`, optional seed prompt) | New conversation; resets the model pin | PART-COMMANDS §2; PART-SESSIONS §3.5 |

There is no `/checkpoint`-style save command in Vibe (PART-COMMANDS §2 lists
the complete set). The verified equivalents are `/rewind` for stepping back
inside a session and resume for returning to one later. Session logging must
be enabled for any of the resume paths (PART-SESSIONS §3.3).

## Exercises

### Exercise 1 — Run the loop end to end (~15 min)

In a scratch directory, start a session and drive one full loop:

```bash
$ mkdir -p /tmp/vibe-loop-lab && cd /tmp/vibe-loop-lab
$ vibe
... trust prompt on first run in this folder (PART-TRUST §3) ...
```

Accept the trust prompt on first run (PART-TRUST §3), then send a
WHAT/WHERE/HOW/VERIFY request:

*“Create a utility function `validate_email` that returns a boolean. WHERE:
`src/utils/validators.py`. HOW: no external dependencies; reject empty
strings and addresses without a TLD. VERIFY: `tests/test_validators.py`
passes via `python3 -m pytest`.”*

Expected observations:

- The agent opens by stating what it will do, writes both files, and closes
  with what changed and any assumptions.
- The file edits (`write_file`) run **without** an approval prompt — you are
  on the default `accept-edits` agent (PART-PERMISSIONS §4.1).
- The test run prompts for approval: `pytest` is not on the default bash
  allowlist (`cd, echo, git diff, git log, git status, tree, whoami` plus
  read-only commands) (PART-PERMISSIONS §4.4).

Illustrative transcript (the agent's phrasing varies):

```text
> Create a utility function validate_email that returns a boolean. ...

Creating a validators module from scratch. I'll write the function, add a
test file, then run the tests.

  write_file src/utils/validators.py
  write_file tests/test_validators.py

Files written; running the test suite now.

  bash: python3 -m pytest tests/          [approval prompt — you approve]
  6 passed in 0.02s

Wrote validate_email in src/utils/validators.py — plain-string checks plus a
TLD requirement, no dependencies — and six cases in tests/test_validators.py
covering the edge cases you listed. All six pass on the run above. I assumed
a src/ layout and created the package.
```

Review the diff, then iterate once: *“Looks good, but also reject addresses
with spaces.”* Watch that the follow-up edits only the relevant parts —
that's the minimal-change habit from step 3 of the loop.

### Exercise 2 — Point the scope with an `@` mention (~10 min)

In the same session, mention the file you care about:

*“@src/utils/validators.py — add a `validate_phone` sibling function in the
same file, same constraints, and extend the test file.”*

Expected observations:

- The mentioned file's content arrives in the turn — on the stable backend
  as an injected read right after your message; re-mentioning re-reads it
  (PART-SESSIONS §6.1).
- The mention caps are the guardrail: 2,000 lines and 50 KB per file, 8
  files per prompt (PART-SESSIONS §6.1).
- The prompt is shorter and the first response is on target — scope you
  pointed at, not scope the agent had to guess.

### Exercise 3 — Cycle agents; meet `plan` (~15 min)

Press Shift+Tab repeatedly and watch the footer: the cycle is
`ask → plan → accept-edits → auto-approve` (PART-AGENTS §10). Switch to
`plan`, then send:

*“Refactor `src/utils/validators.py` into a package with one module per
validator, and tell me the migration steps.”*

Expected observations:

- Read-only exploration: `grep` and `read_file` run; no project files change.
- `write_file` and `edit` are refused outside `~/.vibe/plans/` — the only
  writes the `plan` agent can make are plan documents under `~/.vibe/plans/`
  (PART-AGENTS §7; PART-PERMISSIONS §4.1).
- You get a plan with rationale. Shift+Tab back to `accept-edits`, re-send,
  and watch the same change get applied this time.

### Exercise 4 — Thinking, compaction, and sessions (~20 min)

Work through the session mechanics in one sitting:

1. `/thinking` — pick a level. This sets the per-model thinking setting
   (`thinking = "off"|"low"|"medium"|"high"`, PART-CONFIG §1.1;
   PART-COMMANDS §2).
2. Keep working until the session is long, then run
   `/compact keep the validator API decisions, drop test-run transcripts`.
   Expected: the history is summarized; the same session and the same visible
   conversation continue (PART-SESSIONS §4.2).
3. `/rewind` (or Esc Esc) — step back to the message before a bad turn and
   rephrase (PART-COMMANDS §2).
4. `/exit`, then from the same directory: `vibe -c`. Expected: the most
   recent session for that folder resumes with its pinned model
   (PART-SESSIONS §3.2, §3.5). From any other directory, `vibe --resume <ID>`
   still finds it; partial IDs work (PART-SESSIONS §3.3).
5. `/clear` — expected: a new conversation; the model pin is reset
   (PART-COMMANDS §2; PART-SESSIONS §3.5).

## DO / DON'T

| DO | DON'T |
|---|---|
| Point the prompt at files and lines with WHAT/WHERE/HOW/VERIFY | Send "fix the bugs" and let the agent guess the scope |
| Review the diff every turn — file edits are auto-approved by default | Assume `accept-edits` means "Vibe asked me first" |
| Switch to `plan` for broad or risky changes, then apply | Run `auto-approve` anywhere a script could do damage |
| `/compact` with instructions when a long session drifts | Treat 200,000 as a context window — it's the compaction trigger |
| Resume with `vibe -c` to keep a session's pinned model | Expect a live context percentage — there is no meter |

## Key Takeaways

- Every request follows: prompt → read → analyze → decide → propose → review → apply.
- Be specific (WHAT/WHERE/HOW/VERIFY) for faster, on-target results.
- Compaction is threshold-based: `auto_compact_threshold` (default 200,000)
  triggers automatically; `/compact [instructions]` triggers manually.
- "Modes" are agents — `plan` before risky changes, `accept-edits` as the
  daily default — plus the `/thinking` level.
- Sessions persist and resume (`vibe -c`, `--resume`, `/resume`); `/rewind`
  and `/clear` manage the conversation in place.

## Validation: You're Ready If

- [ ] You can recite the seven loop steps and say where the tool gate sits
- [ ] You can name the four cycled agents and their approval behavior
- [ ] You know what `auto_compact_threshold` is — and that it is not a context window
- [ ] You have run `/compact`, `/rewind`, and `vibe -c` at least once
- [ ] Your last request used all four parts of WHAT/WHERE/HOW/VERIFY

## What's Next

Module 03 covers memory and configuration: the `AGENTS.md` instruction
hierarchy, `config.toml` layering, and how Vibe remembers your preferences
between sessions.

## See Also

- [Context engineering](../core/context-engineering.md) — managing context
  deliberately across a whole task, beyond the compaction basics here
- [Agents and skills reference](../core/agents-and-skills-reference.md) —
  custom agent TOML, the `task` tool, and the skills system
- [Tools reference](../core/tools-reference.md) — the full tool surface and
  per-tool permission keys
- [Memory systems](../core/memory-systems.md) — the session store and
  durable instruction files, in depth

## Known Gaps

- **Context-window size.** The actual context window of the default model
  (`mistral-vibe-cli-latest`) is absent from the oracle; this page states no
  window figure. `auto_compact_threshold` (default 200,000) is a compaction
  trigger, not a window (PART-SESSIONS §4.1).
- **The 50% warning's config flag.** A middleware warns once per session at
  50% of the compaction threshold (PART-SESSIONS §4.1); whether the
  `context_warnings` config flag is what enables it is unverified.
- **Complete tool inventory.** The tools named here (`bash`, `read_file`,
  `write_file`, `edit`, `grep`, `task`, `skill`) are verified where cited
  (PART-PERMISSIONS §4.1, §4.3–§4.4; PART-AGENTS §7, §9; PART-SKILLS §1.4),
  but a complete per-tool inventory is not yet in the oracle.
- **No live meter.** Vibe has no context-percentage display; the one-time
  50%-of-threshold warning is the only meter-like mechanic. Don't port
  percentage-band habits from other tools.
