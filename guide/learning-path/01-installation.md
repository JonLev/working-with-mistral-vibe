---
title: "Module 01 — Installation and First Run"
description: "Install the Vibe CLI from the official channel, set up your API key, answer the folder-trust prompt, run your first session, and build the diff-review habit against the accept-edits default"
tags: [learning-path, installation, cli, trust, sessions, agents, beginner]
---

# Module 01 — Installation and First Run

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics on this page are cited inline as (PART-XXX) against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md). Anything the
oracle could not verify from public sources is in
[Known gaps](#known-gaps), never in the body. Structure and pedagogy are
adapted from the source guide; every mechanic is rebuilt from the oracle.

**Time:** ~45 min · **Complexity:** ★☆☆☆☆ · **Track:** Beginner — the first
module of the learning path. No prerequisites.

## TL;DR

- Install the Vibe CLI from the official channel: the script at
  `https://mistral.ai/vibe/install.sh`, which runs `uv tool install
  mistral-vibe` (PyPI package `mistral-vibe`, latest release 2.25.8). A
  Homebrew formula `mistral-vibe` was also observed (oracle, "Method and
  provenance"; PART-CLI). Per-OS variants and container images are not
  published here — see [Known gaps](#known-gaps).
- First-run sequence **[stable]**: `vibe --setup` (sets your API key and
  exits) → run `vibe` inside a project folder → answer the folder-trust
  prompt → type your first prompt (PART-CLI; PART-TRUST §3.2).
- The default agent is `accept-edits`, which auto-approves file edits
  (PART-AGENTS §7). Nothing will ask you to accept a diff before it lands,
  so reviewing edits after they apply — with an `@` file mention — is the
  habit this module installs (PART-SESSIONS §6.1).
- Keep the CLI current with `vibe update` or `vibe --check-upgrade`
  (PART-CLI).

*Read if you have never run Vibe and want a guided path from a clean
machine to your first reviewed edit. Skip if `vibe --version` already prints
a version and you have made one trust decision and reviewed one applied
edit.*

## Goal

Install the Vibe CLI, configure your API key, and complete one full session
in a project folder: trust decision, first prompt, applied edit, review.
Along the way, learn the prompt → response loop that every later module
builds on.

## What You'll Learn

- Install Vibe from the official channel and check the version
- Run the API-key setup and understand what `--setup` does
- Understand the folder-trust prompt, its four decisions, and what trust
  actually gates **[stable]**
- Start an interactive session and drive the core loop
- Review an applied edit with `@` file mentions, against the `accept-edits`
  default
- Use the five commands you need on day one

## Installation

The oracle records exactly two public install facts, and this page teaches
exactly those (oracle, "Method and provenance"; PART-CLI):

| Channel | What the oracle records |
|---|---|
| Official script | `https://mistral.ai/vibe/install.sh`, which runs `uv tool install mistral-vibe` — the PyPI package `mistral-vibe`, latest release 2.25.8 (2026-09-23) |
| Homebrew | Formula `mistral-vibe` (observed; the live baseline CLI was installed from it at `/opt/homebrew/bin/vibe`) |

```bash
uv tool install mistral-vibe
```

The command above is what the official install script runs. If you use
Homebrew, install the observed formula with `brew install mistral-vibe`.

Verify the install:

```bash
vibe --version
```

Expected: a single line of the form `vibe <X.Y.Z>` — the oracle's live
transcript printed `vibe 2.25.0`, and PyPI's latest at documentation time
is 2.25.8, so a fresh install prints `vibe 2.25.8` or newer (PART-CLI).

To check for a newer release later:

```bash
vibe --check-upgrade
```

`--check-upgrade` checks for a Vibe update now, prompts to install it, and
exits; `vibe update` is the same check as a subcommand (PART-CLI).

## First Run: Setup, Trust, First Prompt

### Step 1 — Set your API key

```bash
vibe --setup
```

`--setup` runs the API-key setup and exits; it does not start a session
(PART-CLI). Everything else in this module happens in the interactive CLI.

### Step 2 — Start Vibe in a project folder

```bash
cd ~/my-project
vibe
```

Vibe is best run from a project folder. In interactive startup, the
folder-trust prompt is offered when your current directory (a) is not your
home directory, (b) is not already trusted, (c) is not explicitly untrusted,
and (d) has "trustable files": an `AGENTS.md` at or above the directory
(within the git repo), or a local config dir — `.vibe/` containing
`config.toml`, `prompts/`, `tools/`, `skills/`, `plugins/`, `agents/`, or
`.agents/skills/` (PART-TRUST §3.2).

The prompt offers four decisions (PART-TRUST §3.2):

| Decision | Effect |
|---|---|
| Trust the repo | Persist the git repo root into `trusted` (offered when a `.git/HEAD` ancestor exists) |
| Trust this folder | Persist the current directory into `trusted` |
| Trust for this session | In-memory, session-only trust; nothing persisted |
| Decline | Persist the current directory into `untrusted`; the session runs with project config ignored |

Persistent decisions land in `$VIBE_HOME/trusted_folders.toml` (default
`~/.vibe/trusted_folders.toml`, since `VIBE_HOME` defaults to `~/.vibe`), as
absolute resolved paths under the `trusted` and `untrusted` keys; the file
is created on first run (PART-TRUST §3.1; PART-CLI).

Why the prompt exists — trust is the blast-radius control. From an
untrusted root, Vibe does not load the project's `.vibe/config.toml`,
`.vibe/hooks.toml`, `.vibe/{tools,skills,plugins,agents,prompts}`,
`.agents/skills`, or the repo `AGENTS.md`; from a trusted root it does.
User-level config under `~/.vibe` always loads. Declining is safe: the
directory stays writable and the session still works, just without that
project's configuration (PART-TRUST §3.5).

Two flags change the prompt **[stable]** (PART-TRUST §3.3):

| Flag | Behavior |
|---|---|
| `--trust` | Trusts the working directory for this invocation only, skips the prompt, and is never persisted to `trusted_folders.toml` — the right choice for scripts and non-interactive automation |
| `--add-dir DIR` | Adds another working directory: it joins the workspace roots and the session's write boundary, with the same session-only trust semantics as `--trust`; repeatable; not persisted to the trust store |

### Step 3 — Type your first prompt

Type a plain-English prompt at the session prompt. This is the core loop
of agentic coding with Vibe:

```text
Your prompt → Vibe reads files → Vibe proposes changes → Edits apply → You review
```

You can also start with an initial prompt directly from the shell:
`vibe "<prompt>"` passes the text as the initial prompt of the interactive
session (PART-CLI).

## Essential Commands

All five are built-in slash commands; descriptions are verbatim from the
command registry (PART-COMMANDS §2). **[stable]**

| Command | Aliases | Purpose |
|---|---|---|
| `/help` | | Show help message |
| `/status` | | Display agent statistics |
| `/clear` | `/new` | Start a new conversation. Optionally pass a prompt to seed it. |
| `/log` | | Show path to current interaction log file |
| `/exit` | `exit`, `quit`, `:q` | Exit the application |

Note: the bare aliases (`exit`, `quit`, `:q`) cannot take arguments
(PART-COMMANDS §2).

## Your First 5 Minutes

Work through the exercises in order; each one ends with something concrete
to observe. Everything runs on the default **[stable]** backend — no flags
beyond the ones shown.

### Exercise 1: Confirm the install

```bash
vibe --version
```

Expected observation: one line, `vibe <X.Y.Z>` (PART-CLI). If the shell
reports `command not found`, see [Troubleshooting](#troubleshooting).

### Exercise 2: Set your API key

```bash
vibe --setup
```

Expected observation: the API-key setup runs and the process exits —
`--setup` does not open a session (PART-CLI).

### Exercise 3: Make a trust decision

```bash
cd ~/my-project
vibe
```

Use a real project folder — ideally a git repo with an `AGENTS.md`, or a
`.vibe/` config dir, so the trust prompt has something to anchor on
(PART-TRUST §3.2).

Expected observation: the folder-trust prompt. Choose **Trust this folder**
(or **Trust the repo** if you own the whole repo). Then check what was
written:

```bash
grep -A2 'trusted' ~/.vibe/trusted_folders.toml
```

Expected observation: your project's absolute path under `trusted`
(PART-TRUST §3.1). Re-running `vibe` in the same folder skips the prompt —
the decision is persisted. Try the automation form once in a throwaway
folder:

```bash
vibe --trust
```

Expected observation: no trust prompt — `--trust` skips it for this
session only and writes nothing to `trusted_folders.toml` (PART-TRUST §3.3).

### Exercise 4: Your first prompt

In the session, type:

> *What files are in this project, and what does it do?*

Expected observation: Vibe reads the project structure and answers in its
own words. A well-formed reply looks like this (modeled, not a transcript):

```text
Reading the project first, then I'll summarize. [reads files]

The repo is a small Python package: `src/` holds the implementation,
`tests/` the pytest suite, and `pyproject.toml` declares the metadata and
dependencies. I did not change anything.
```

That is the shape to expect: intent up front, work in the middle, a close
that says what changed — here, nothing.

### Exercise 5: Review an applied edit

Still in the session, ask for a small edit:

> *Create `NOTES.md` with one line: what this project is about, based on
> the files you read.*

Expected observation: the file is created and the edit applies — with no
approval prompt. That is not a bug: the default agent is `accept-edits`,
which sets `write_file` and `edit` to permission `always` (PART-AGENTS §7).
Vibe will ask before other tool calls, but file edits land on their own.

Now the habit this module exists to install — verify what actually landed,
by mentioning the file with `@`:

> *@NOTES.md Quote the file exactly, line by line.*

An `@` mention of a text file injects a fresh read of that file as part of
your prompt — every mention re-reads the file, with no caching (PART-SESSIONS
§6.1). Expected observation: the agent quotes the real on-disk contents, so
a mismatch between what was claimed and what was written shows up
immediately. If the edit is wrong, rewind the conversation with `/rewind`
(also bound to pressing `Esc` twice) and re-ask (PART-COMMANDS §2).

Mention caps worth knowing before you rely on this heavily: one text-file
mention is capped at 2000 lines and 50 KB, at most 8 file mentions per
prompt, and a path outside the workspace is rejected with "Cannot attach
file outside the workspace" (PART-SESSIONS §6.1).

## The Core Concept: The Loop

Every interaction with Vibe follows one pattern (PART-AGENTS §7;
PART-SESSIONS §6.1):

```text
┌─────────────┐
│ You prompt  │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│ Vibe reads files │
│ and tools run    │
└──────┬───────────┘
       │
       ▼
┌────────────────────────┐
│ Edits apply (auto-     │
│ approved by default)   │
└──────┬─────────────────┘
       │
       ▼
┌────────────────────────┐
│ You review: transcript │
│ and @ re-read of files │
└──────┬─────────────────┘
       │
       ▼
┌──────────────────────┐
│ Next prompt, or fix  │
│ with /rewind         │
└──────────────────────┘
```

Two facts shape the loop on day one:

- **Sessions.** Each `vibe` launch starts a session — a conversation that
  persists while the CLI runs and is saved under `~/.vibe/logs/session/` as
  `meta.json` plus `messages.jsonl` (PART-SESSIONS §3.1). Resuming is a
  later module; for now, know that the record exists and `/log` shows the
  current interaction log file (PART-COMMANDS §2).
- **Agent selection.** The built-in order you cycle with `Shift+Tab` is
  `ask → plan → accept-edits → auto-approve` (PART-AGENTS §10). For
  exploration you don't want edits from, switch to `plan` — the read-only
  agent (PART-AGENTS §7).

## DO and DON'T

| DO | DON'T |
|---|---|
| Review every applied edit with an `@` mention before building on it (PART-SESSIONS §6.1) | Assume Vibe asked permission — the default `accept-edits` agent auto-approves `write_file` and `edit` (PART-AGENTS §7) |
| Run Vibe from a project folder, so the trust prompt and project config engage (PART-TRUST §3.2) | Run it from your home directory, Desktop, Documents, or Downloads — Vibe refuses those as the working directory (PART-TRUST §3.5) |
| Use `--trust` for scripts and automation, where nothing can answer a prompt (PART-TRUST §3.3) | Trust an unreviewed clone: trust loads that repo's `AGENTS.md`, hooks, and agent definitions (PART-TRUST §3.5) |
| Switch to the read-only `plan` agent before exploratory prompts (PART-AGENTS §7, §10) | Reach for `--auto-approve` / `--yolo` in your first week — they approve all tool calls for the session (PART-CLI) |

## Validation: You're Ready If

- [ ] `vibe --version` prints a version line
- [ ] `vibe --setup` has been run, and `vibe` in a project folder starts a session
- [ ] You can name the four trust decisions and where the persistent ones are stored
- [ ] You have completed one prompt → response cycle and recognize the loop
- [ ] You have seen an edit apply without an approval prompt and verified its contents with an `@` mention
- [ ] You can exit cleanly with `/exit`

## What's Next

Module 02 of this path (the core loop in depth) continues from here. For
the underlying machinery in the meantime, see the See also links below.

## Troubleshooting

### `vibe: command not found`

The install did not put `vibe` on your `PATH`. Re-run the official channel
(the script at `https://mistral.ai/vibe/install.sh` running `uv tool
install mistral-vibe`); on a Homebrew install the binary lands at
`/opt/homebrew/bin/vibe` — confirm that directory is on your `PATH`
(oracle, "Method and provenance"; PART-CLI).

### The untrusted-directory warning in programmatic mode

Programmatic runs (`vibe -p "<prompt>"`) in an untrusted directory print
this on stderr (verbatim from the oracle):

```text
Warning: <cwd> is not trusted; project configuration (<files>) will be ignored.
Re-run with --trust to trust this folder temporarily.
```

The run continues with project config ignored, and the message tells you
the fix — re-run with `--trust` (PART-TRUST §3.4). In interactive mode you
get the trust prompt instead (PART-TRUST §3.2).

### No trust prompt appeared

The prompt only appears when the folder is not your home directory, is not
already decided, and has trustable files — an `AGENTS.md` at/above it or a
`.vibe/` config dir (PART-TRUST §3.2). A bare scratch folder triggers no
prompt and no project config; use a real project, or pass `--trust`.

### Vibe refuses to start in a directory

Vibe refuses to treat your home directory, Desktop, Documents, Downloads,
`/System`, `/usr`, `/Library`, or `/Applications` as the working directory
(PART-TRUST §3.5). Run it from a project folder instead.

### An edit landed that you did not want

That is the `accept-edits` default working as designed (PART-AGENTS §7).
Rewind with `/rewind` (or `Esc` twice) to a previous message, verify the
file with an `@` mention (PART-SESSIONS §6.1), and re-ask — or switch to
the `ask` or `plan` agent with `Shift+Tab` before the next prompt
(PART-AGENTS §7, §10).

## See also

- [Guide index](../README.md) — the full tree with reading times.
- [How the Vibe CLI Works: Architecture and Internals](../core/architecture.md)
  — the agent loop, tool surface, and the permission and trust model in
  depth.
- [Memory Systems](../core/memory-systems.md) — what trust loads
  (`AGENTS.md`, project config) and the session store, covered fully.
- [Agents and Skills Reference](../core/agents-and-skills-reference.md) —
  every built-in agent profile, including `ask`, `plan`, `accept-edits`,
  and `auto-approve`.

## Known gaps

Items the oracle could not verify from public sources. They are not stated
as fact anywhere above.

- **Per-OS install variants** — the oracle records no Windows installer,
  PowerShell script, or OS-specific packages beyond the official script
  and the observed Homebrew formula. Not documented here.
- **Container images** — no Docker image availability is recorded. Not
  documented here.
- **What the install script does beyond `uv tool install mistral-vibe`** —
  e.g. whether it installs `uv` itself if missing. Not recorded.
- **The `--setup` UI** — the oracle records the flag as "Setup API key and
  exit" but not the prompts or screens it shows.
- **The interactive startup banner** — the exact text Vibe prints when a
  session opens is not recorded, so this module describes observations,
  not a welcome-screen transcript.
- **`/status` display fields** — the oracle records only its verbatim
  description ("Display agent statistics"); context-percentage readouts
  are not documented.
- **`Ctrl+C` behavior in the TUI** — not in the oracle's recorded surface.
- **Unified-harness backend** — the mechanics on this page are tagged
  **[stable]**; the experimental harness (`--experimental-harness`) is
  argparse-suppressed from `--help` when its package is not installed and
  was not exercised live in the oracle's sprint. First-run differences on
  that backend are not documented.
