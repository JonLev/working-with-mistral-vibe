---
title: "Skill Design Patterns"
description: "Nine architecture patterns for Vibe skills: ground-truth injection, skill-body reference paths, detection-only scope, handler dispatch, versioned subdirectories, two-tier standards, committed plans, runtime prompt logging, and adaptive unified/parallel evaluation"
tags: [skills, patterns, design, multi-agent, hooks]
---

# Skill Design Patterns

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Practical patterns for skills that go beyond a single-agent, single-file
prompt: subagents that re-discover the same facts, standards applied to the
wrong files, skills that blur detection with remediation, plans that vanish
with the session. Every mechanic on this page is cited inline against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md); structure and
pedagogy are adapted from the source guide, and the nine patterns themselves
are observed in Packmind's public skills and evaluation tooling.

## TL;DR

- A skill is a directory containing a `SKILL.md`. Discovery runs: builtins
  (reserved names `vibe`, `skill-creator`) → `skill_paths` config entries →
  project `<root>/.vibe/skills/` then `<root>/.agents/skills/` per trusted
  root → user `~/.vibe/skills/` then `~/.agents/skills/` → registry skills
  behind an experimental flag; first match wins on a name collision
  (PART-SKILLS section 1.2).
- Frontmatter supports exactly seven keys. Unknown keys are silently
  ignored, so any invented key — including a path-filter key — parses and
  then does nothing (PART-SKILLS section 1.1).
- Two mechanisms from the source guide do not exist in Vibe: frontmatter
  path filters, and an auto-loaded rules directory. Their replacements are
  paths written in the skill body, resolved against the skill base
  directory that the `skill` tool returns (PART-SKILLS section 1.4), and
  subdirectory `AGENTS.md` files lazily injected on `read_file`
  (PART-AGENTSMD).
- Most patterns reduce to one discipline: decide in the orchestrator what
  each subagent sees. The `task` tool passes a self-contained text string to
  a fresh session and returns text only, and subagents cannot spawn
  subagents (PART-AGENTS section 9).

*Read if you design skills that orchestrate multiple subagents, filter
standards by file scope, or need durable plans and prompt logs. Skip if you
write single-file skills and want the format reference only — read the
mechanics section below and stop.*

## Pattern selection

| # | Pattern | Solves | Primary Vibe mechanics |
|---|---|---|---|
| 1 | Shared Ground Truth Injection | N subagents re-discovering the same baseline facts | `task` tool: self-contained text prompt, fresh session, text-only result (PART-AGENTS section 9) |
| 2 | Pre-filtered References via Skill-Body Paths | Standards applied to files they were not written for | No `paths:` frontmatter; skill body + base directory + sampled file listing (PART-SKILLS sections 1.1, 1.4) |
| 3 | Detection-Only Scope Boundary | False positives and incomplete fixes mixed in one skill | `allowed-tools` frontmatter; read-only agent profiles (PART-SKILLS section 1.1; PART-AGENTS section 7) |
| 4 | Input-Handler Dispatch | Heterogeneous input types growing a branching main file | Support files read on demand, relative to the skill dir (PART-SKILLS sections 1.4, 1.5) |
| 5 | Versioned Sub-directories | Wrapping a CLI tool across breaking versions | Optional `scripts/`, `references/`, `assets/` dirs; registry pin manifests (PART-SKILLS sections 1.1, 1.6) |
| 6 | Two-Tier Standards | Long standards inflating every review | No rules directory; subdirectory `AGENTS.md` lazy injection (PART-AGENTSMD) |
| 7 | Plans as Committed Artifacts | Session-scoped plans with no durable record | Plan agent writes under the plans dir; sessions persist (PART-AGENTS section 7; PART-SESSIONS section 3) |
| 8 | Runtime Prompt Logging | Prompts lost when a provider call fails | Hook payloads carry full tool input/output; `transcript_path` (PART-HOOKS section 3.2) |
| 9 | Adaptive Unified/Parallel Mode | One agent vs N agents, decided by budget | `auto_compact_threshold` default 200,000; `task` subagents (PART-SESSIONS section 4; PART-AGENTS section 9) |

---

## The mechanics every pattern builds on — [stable]

Skills mechanics are live-verified on 2.25.0 and anchored to the documented
2.25.8 surface (PART-SKILLS).

### Frontmatter: seven keys, nothing else

The exact `SkillMetadata` schema (PART-SKILLS section 1.1):

| Key | Required | Constraints |
|---|---|---|
| `name` | yes | 1-64 chars, `^[a-z0-9]+(-[a-z0-9]+)*$`; should match the directory name (a mismatch only logs a warning — the skill loads under the frontmatter name) |
| `description` | yes | 1-1024 chars; the only text the model sees before loading the skill |
| `license` | no | License name or reference to a bundled license file |
| `compatibility` | no | Max 500 chars; environment requirements |
| `metadata` | no | Flat string-to-string map |
| `allowed-tools` | no | Space-delimited string or list of pre-approved tools; experimental |
| `user-invocable` | no | Bool, default `true`; `false` = model-only, hidden from the slash menu, `/skill-name` does not resolve |

Unknown keys are ignored by the parser. The shipped `skill-creator` builtin
is blunt about it: "Do not invent frontmatter keys." A `disable-model-invocation`
key (forces model-only even when `user-invocable` is true) exists at release
2.25.8 (source) but not in the 2.25.0 live baseline (PART-SKILLS section 1.1).

### Where skills live, and who wins

Discovery order, first match wins on a name collision (PART-SKILLS section
1.2):

1. Built-in skills (`vibe`, `skill-creator`) — reserved names; a discovered
   skill colliding with a builtin is silently skipped.
2. `skill_paths` entries from `config.toml` (absolute or cwd-relative).
3. Project dirs per trusted project root (trusted cwd plus `--add-dir`
   paths): `<root>/.vibe/skills/`, then `<root>/.agents/skills/`. An
   untrusted cwd contributes no project skill content.
4. User dirs: `~/.vibe/skills/`, then `~/.agents/skills/`.
5. Registry skills, only when `experimental_enable_registry_skills = true`
   — a local or builtin skill wins on collision.

```toml
# config.toml
skill_paths = ["/path/to/custom/skills"]   # additional search dirs
enabled_skills = ["code-review", "test-*"]  # allowlist (glob + re: regex supported)
disabled_skills = ["experimental-*"]        # blocklist
experimental_enable_registry_skills = false # default
```

### Scope and invocation

| Surface | Behavior |
|---|---|
| Project scope: `<root>/.vibe/skills/` | Checked into the repo, shared with the team (PART-SKILLS sections 1.2, 1.5) |
| Global scope: `~/.vibe/skills/` | Personal, available in every project (PART-SKILLS sections 1.2, 1.5) |
| `/skill-name` | Resolves only if `user-invocable` is true; the rest of the input is passed as extra instructions (PART-SKILLS section 1.3) |
| `skill` tool | Model-side load; permission `ALWAYS` (no approval prompt); returns the skill body, the skill's base directory ("Relative paths in this skill are relative to this base directory."), and a sampled `skill_files` listing of the skill directory (max 10 files listed) (PART-SKILLS section 1.4) |
| `/reload` | Picks up skill changes without restarting (PART-SKILLS section 1.5) |

Two load facts shape everything below. First, the `description` is the only
routing text the model sees before loading — it decides whether the skill
loads at all (PART-SKILLS section 1.1). Second, when a skill is already
loaded, the `skill` tool returns "Skill '`<name>`' is already loaded earlier in
this conversation. Reuse those instructions." — a skill loads once per
conversation (PART-SKILLS section 1.4).

---

## 1. Shared Ground Truth Injection

**Problem**: You launch N parallel subagents to audit or analyze a set of
artifacts. Each one independently discovers the same baseline facts — file
list, entry points, CLI commands, schema. That is N redundant reads, N
independent facts to trust, and N chances for one subagent to see a stale
file state.

**Pattern**: The orchestrator computes a shared factual baseline once, then
injects the same block verbatim into every subagent prompt.

On Vibe this is not a convention bolted onto the mechanism — it is what the
mechanism demands. Subagents are spawned with the `task` tool, whose argument
is a single self-contained text string; the child is a fresh session, and the
parent receives only the accumulated text of the child's response
(`TaskResult` with `response`, `turns_used`, `completed` — no message
objects, no files) (PART-AGENTS section 9). Whatever the subagent must know,
the orchestrator must write into that string.

```text
Orchestrator (parent session)
  ├── Read entry points → extract module groups
  ├── List files → get current list
  ├── List CLI commands → get current commands
  └── Compile into one "Ground truth" block

Dispatch (one task call per scope)
  ├── subagent 1: ground truth block + "Your scope: section A"
  ├── subagent 2: ground truth block + "Your scope: section B"
  └── subagent 3: ground truth block + "Your scope: section C"
```

What goes in the shared block: navigation or file hierarchy, current CLI
commands or API endpoints (to catch references to removed commands), the
domain entity list, the current date (to catch stale version references).

The block must be a string pasted into the task description, not a file
reference. If you point subagents at "read `docs.json`", each one reads it
independently — the failure mode you are eliminating. One structural
constraint: the depth limit on `task` is 1, and only subagent profiles are
spawnable (PART-AGENTS section 9), so the orchestrator is always the
top-level session. Design the pipeline as one dispatcher fanning out, never
as a tree.

Example task description (italic user-voice quote):

*"Audit the authentication module. Ground truth — module entry points:
`src/auth/session.ts`, `src/auth/token.ts`. CLI commands (current): `auth
login`, `auth refresh`, `auth logout`. Today: 2026-09-24. Your scope: token
rotation only. Report mismatches between docs and code; do not edit files."*

**When to use**: any parallel audit or evaluation where the baseline is
identical across workers. **When not to**: a single subagent, or baselines
that genuinely differ per scope — then the shared block is noise. Size the
block to what each worker needs, not everything you could include: for a
5-subagent audit, every 500 tokens of ground truth costs 2,500 across the
fan-out.

---

## 2. Pre-filtered References via Skill-Body Paths

**Problem**: You have a set of standards files — coding conventions,
security policies, style guides — each applying to a specific subset of
files. Pass all of them to a review agent and it applies test rules to
migrations and API rules to components: false positives, wasted context.

**Pattern — and the correction that comes with it**: The source guide's
form of this pattern put a `paths:` glob in each rule file's frontmatter.
That form does not exist in Vibe. The frontmatter schema supports exactly
the seven keys listed above; unknown keys are silently ignored, so a
`paths:` key would parse and then be dropped (PART-SKILLS section 1.1). Do
not write one.

The Vibe form moves the filtering into the skill body:

- Put each scoped standard in its own file under the skill directory —
  `references/` is a conventional location; the Agent Skills specification,
  which Vibe follows, defines optional `scripts/`, `references/`, `assets/`
  directories (PART-SKILLS section 1.1).
- In the `SKILL.md` body, write a dispatch table: scope, reference file,
  glob.
- Tell the model to resolve those relative paths against the skill base
  directory — the `skill` tool result states that relative paths in the skill
  are relative to the base directory, and includes a sampled listing of the
  skill's files so the model knows what exists before reading anything
  (PART-SKILLS section 1.4).

```markdown
---
name: qa-review
description: Review changed files against the coding standards that match their scope.
user-invocable: true
---

# QA review

References live in `references/`, relative to this skill's base directory.

| Scope | Reference | Matches |
|---|---|---|
| Unit tests | `references/testing.md` | `**/*.spec.ts`, `**/*.test.ts` |
| Migrations | `references/migrations.md` | `migrations/**` |
| API routes | `references/api.md` | `src/routes/**` |

Load only the reference rows whose glob matches the files under review.
```

Orchestrator logic, if the filtering happens in a dispatcher rather than
inside the skill:

```text
1. Determine modified files.
2. For each scope row in the dispatch table: match the glob.
3. Include a reference file only if at least one modified file matches.
4. Pass the filtered references to each review subagent.
```

**Why it works**: a test file is not checked against migration rules; a
route file is not checked against test conventions; each subagent's context
holds only actionable rules. With 50 standards and a change touching 8 spec
files, the agent reads 3 references instead of 50.

**When to use**: any rule set with clear file-type scopes. **When not to**:
genuinely global rules — those belong in the skill body itself, or in a
checked-in `AGENTS.md` (see pattern 6).

---

## 3. Detection-Only Scope Boundary

**Problem**: A skill that both detects issues and fixes them has two
failure modes — false positives (fixed something that was not a problem)
and incomplete fixes (detected correctly, fixed wrong). Mixing the two
makes both worse and gives the user no review checkpoint.

**Pattern**: Scope skills to detection only. The skill produces a report;
remediation is a separate step the user triggers after reading it.

On Vibe, say it in the two places that actually bind:

1. The `description` — the only text the model sees before loading, so the
   boundary must be visible there (PART-SKILLS section 1.1).
2. The tool surface. Loading a skill needs no approval (the `skill` tool is
   permission `ALWAYS`, PART-SKILLS section 1.4), so prose is not a
   security boundary — the agent's tool permissions are. Two enforcement
   levers exist: the experimental `allowed-tools` frontmatter key
   (pre-approve only the tools the skill should touch, PART-SKILLS section
   1.1), and running the session under a read-only agent profile — the
   built-in `plan` agent is "Read-only agent for exploration and planning",
   with `write_file` and `edit` at `permission = "never"` except for the
   plans directory (PART-AGENTS section 7).

```markdown
---
name: api-drift-audit
description: Detect documented API endpoints that no longer exist in code. Report only; never edits files.
allowed-tools:
  - read_file
  - grep
user-invocable: true
---

# API drift audit

This skill detects drift between docs and code. It does not fix anything:
no file writes, no edits. Output is a report of mismatches only.
```

**When to break the rule**: skills built for automated remediation —
codemod-style, dependency-update — are the exception. They should say so in
their `description`, and should land changes in reviewable units.

**The practical value**: detection-only skills are safe to run against any
branch and in automated contexts, which makes them worth running more
often, on more code. The boundary is real when the tool surface enforces
it, not just the prose.

---

## 4. Input-Handler Dispatch

**Problem**: A skill that handles two or more heterogeneous input types —
a tracked issue vs a design mockup, a config file vs a pasted error —
either grows a branching main file or becomes too rigid for varied entry
points.

**Pattern**: One handler file per input type in a subdirectory of the
skill; the `SKILL.md` dispatches. The main file stays clean; each handler
holds the full parsing instructions for its type.

```text
.vibe/skills/create-em-spec/
├── SKILL.md                 # asks which input type, dispatches
└── inputs/
    ├── github-issue.md      # handler: issue text → spec
    └── visual-mockup.md     # handler: screenshot description → spec
```

```markdown
## Step 1: Identify input type

Ask the user which input they are providing.

- Tracked issue → read `inputs/github-issue.md` and follow it.
- Visual mockup → read `inputs/visual-mockup.md` and follow it.
```

The mechanics back this directly: support files are referenced relative to
the skill directory and read on demand — the `skill` tool returns the base
directory and tells the model that relative paths resolve against it
(PART-SKILLS sections 1.4, 1.5). The `inputs/` subdirectory is your own
convention; the specification's optional `scripts/`, `references/`,
`assets/` names are the portable ones (PART-SKILLS section 1.1).

**When to use**: input types that need substantially different parsing
logic, not just different field names. If two handlers would differ by
fewer than a handful of steps, keep them inline. The pattern pays off when
each handler exceeds roughly 100 lines.

---

## 5. Versioned Sub-directories for Tool-Version Coupling

**Problem**: A skill wraps a CLI tool whose behavior changes between
versions. The skill must detect the installed version and adapt.

**Pattern**: One subdirectory per tool version inside the skill, each with
the version-specific instructions. `SKILL.md` detects the version at
runtime and reads the matching file relative to the skill base directory
(PART-SKILLS section 1.4).

```text
.vibe/skills/update-playbook/
├── SKILL.md
└── tool-versions/
    ├── v1.21/
    │   └── apply-changes.md
    ├── v1.23/
    │   └── apply-changes.md
    └── v1.24/
        └── apply-changes.md
```

```markdown
## Step 1: Detect tool version

Run: `my-cli --version`

- Output starts with "1.21" → read `tool-versions/v1.21/apply-changes.md`
- Output starts with "1.23" → read `tool-versions/v1.23/apply-changes.md`
- Output starts with "1.24" → read `tool-versions/v1.24/apply-changes.md`
- Unrecognized → stop and tell the user which versions are supported
```

**Anti-pattern**: do not create a `my-skill-v2/` directory beside
`my-skill/`. Both would load as separate skills — discovery deduplicates by
name, and `/skill-name` resolves by name (PART-SKILLS sections 1.2, 1.3) —
so you get two near-identical entries in the slash menu and no way to say
which is current. Version the content inside the skill, not the skill
itself.

Vibe also has a native answer when the thing being versioned is the skill
itself: the skills registry pins a skill to a version. Pin manifests live in
`~/.vibe/skills.toml` (global) and `<root>/.vibe/skills.toml` (project,
which wins), each entry carrying `name`, `skill_id`, `version` (an integer
or the `latest` alias, which always resolves server-side), and
`description`; registry skills are materialized under
`~/.vibe/skills-registry-cache/<skill_id>/<version>/SKILL.md` (PART-SKILLS
section 1.6). This is gated behind
`experimental_enable_registry_skills = true` and requires a Mistral
provider, so treat it as the roadmap for shared-skill versioning, not the
default.

**When to use**: the wrapped tool has breaking changes across versions you
must support simultaneously. Supporting only the latest version? Update the
skill in place, and `/reload` picks up the change (PART-SKILLS section 1.5).

---

## 6. Two-Tier Standards

**Problem**: A comprehensive coding standard runs 1,000-5,000 words.
Loading it in full for every file review inflates cost and dilutes
attention.

**Pattern**: A short summary tier that loads automatically, plus a full
canonical standard read on demand.

The source guide's summary tier was an auto-loaded rules directory. Vibe
has no auto-loaded rules directory — there is no rules-dir equivalent, and
inventing frontmatter keys to emulate one does nothing (PART-SKILLS section
1.1). The honest Vibe form of "loads automatically, scoped to the right
files" is subdirectory `AGENTS.md`:

| Tier | Where | Loads |
|---|---|---|
| Summary (100-300 words, 3-5 imperative rules) | `AGENTS.md` next to the files it governs | Lazily, when a file below it is read (PART-AGENTSMD) |
| Full canonical standard | A plain doc in the repo, or a skill's `references/` | Only when the model reads it on demand |

```text
src/__tests__/AGENTS.md     # 5 testing rules; injected when a test file is read
docs/standards/testing.md   # full canonical standard; read on demand
```

The summary references the full document by path. The full standard must
not itself be an `AGENTS.md` — an `AGENTS.md` in a subdirectory is exactly
the thing that auto-injects. The injection is scoped and prioritized: each
`AGENTS.md` applies to its own directory and descendants, and when several
are present, closer directories take priority (PART-AGENTSMD).

**Maintenance**: the two-tier split creates a duplication risk. Keep the
summary to bullet rules only, so it changes rarely; when the canonical
standard changes, update the summary in the same commit.

**When to use**: teams with more than about 10 scoped standards, or
standards averaging more than 500 words. Below that, one tier in a
project-root `AGENTS.md` is simpler.

---

## 7. Plans and Specs as Committed Artifacts

**Problem**: Plans written during a session are durable only to a point.
On Vibe, the built-in `plan` agent may write plan files, but its write
allowlist points at the plans directory under `VIBE_HOME` (default
`~/.vibe`, PART-CONFIG section 2.4) — user-home territory, not the repo
(PART-AGENTS section 7). Sessions themselves persist under
`$VIBE_HOME/logs/session/` as `meta.json` plus `messages.jsonl` and are
resumable (PART-SESSIONS section 3), so a plan survives for *you* — but it
is not greppable by the team, not diffable against the code, and not
versioned with it.

**Pattern**: Commit plans and their companion specs into the repo as dated
pairs.

```text
docs/plans/
├── 2026-03-15-auth-refactor.md         # plan: phases, tasks, commit messages
└── 2026-03-15-auth-refactor-design.md  # spec: context, alternatives, rationale
```

The plan carries the implementation breakdown with an explicit commit
message per task; the spec carries what will not be obvious from the code
six months later — constraints, rejected alternatives, the reasoning. Name
them `YYYY-MM-DD-<slug>.md` and `YYYY-MM-DD-<slug>-design.md` so pairs stay
adjacent in listings.

The repo is the right surface for this on Vibe: project `AGENTS.md` files
are described as "checked into the codebase" (PART-AGENTSMD) — the same
logic applies to plans. A new session, or a teammate's session, reads
`docs/plans/` and picks up in-progress work without reconstructing it from
git log.

**When to use**: multi-session implementation tasks where continuity
matters — roughly, if the work spans more than a day or more than one
session. **When not to**: single-session tasks that fit in one commit; the
ceremony outweighs the record.

---

## 8. Runtime Prompt Logging

**Problem**: When a provider call fails or an orchestrated subagent returns
something unexpected, the exact prompt that was sent is the thing you need
and the thing you no longer have. A debug flag only helps when you
remember to pass it.

**Pattern**: Persist the prompt as part of the run, always on, before the
call it records. Never let logging failures break the run.

Vibe gives you two grounded layers.

**Layer 1 — what the harness already persists.** Subagent task prompts are
not lost: each `task` call creates a child session, logged under
`<parent session dir>/agents/` with a prefix of the agent name, persisted
and resumable (PART-AGENTS section 9). And every hook invocation receives
`transcript_path`, pointing at the session's `messages.jsonl` (PART-HOOKS
section 3.2). If you need to inspect what an agent was told, the session
store has it.

**Layer 2 — a project-visible log you own.** A `post_agent` hook — one
`hooks.toml` entry, no flag — fires once per turn and receives
`session_id`, `transcript_path`, `cwd`, and `parent_session_id` on its
stdin; `pre_tool` and `post_tool` hooks receive the full `tool_input`,
`tool_status`, and `tool_output_text` of each call (PART-HOOKS sections 1,
3.2). Log from there into a persistent, repo-relative directory:

```toml
# <project>/.vibe/hooks.toml — loaded when the folder is trusted (PART-HOOKS section 1)
[[hooks]]
name = "log-turn-record"
type = "post_agent"
command = "uv run python scripts/log_turn.py"   # reads stdin JSON, appends to .agent-logs/
timeout = 10.0
description = "Append the turn record to the project prompt log."
```

Three properties make it safe, and two of them are native:

| Constraint | How Vibe provides it |
|---|---|
| Always-on, no flag | Hooks fire per event unconditionally when configured (PART-HOOKS section 1) |
| Never throws | Hook failure is fail-open by default: a non-zero exit or bad output emits a UI warning and the session proceeds (`strict = true` escalates — do not set it on a logging hook, PART-HOOKS section 3.3) |
| Cheap | The hook runs as a subprocess with a 60s default timeout and a 1 MiB stdout cap; exit 0 with empty stdout is a clean no-op (PART-HOOKS sections 2, 3.1, 3.3) |

The wire protocol is [stable] and the same `hooks.toml` system runs on both
backends (PART-HOOKS section 1). Keep the log outside temp directories —
the point is persistence across runs.

**When to use**: any skill or pipeline where prompts are assembled
dynamically — ground truth injection, evaluator instructions, file
content. The value scales with prompt complexity; one append per turn is
cheap insurance. **When not to**: static single-prompt skills, where the
session store already contains everything.

---

## 9. Adaptive Unified/Parallel Mode

**Problem**: N files to evaluate. One agent seeing everything catches
cross-file contradictions but pays full context on every file; N parallel
agents are cheaper and faster but each is blind to everything outside its
slice.

**Pattern**: Estimate the combined token count before committing to a
strategy, and gate on it: below the threshold, unified mode; above it,
parallel mode with one subagent per slice.

```text
estimate combined tokens
  ↓
below threshold → one session evaluates all files   (cross-file detection)
above threshold → task call per file, parallel      (per-file depth)
```

The reference number on Vibe is the documented auto-compaction threshold:
`auto_compact_threshold` defaults to 200,000 tokens (config-level, with a
per-model override; `0` disables), and compaction triggers before a turn
when `context_tokens >= threshold` (PART-SESSIONS section 4). A unified-mode
budget must sit well below that — the evaluation prompt, the file content,
and the response all share the window, and compaction mid-evaluation loses
exactly the context you were consolidating. The source's observed default
of 100,000 tokens for this gate is a reasonable starting point.

On Vibe, the parallel side has a hard shape: subagents spawn only through
the `task` tool, depth is capped at 1, and each result is text-only
(`response`, `turns_used`, `completed`) — the parent never receives message
objects or files, only the accumulated text, which it then summarizes to
the user (PART-AGENTS section 9). So the unified/parallel choice is really:
"does the cross-file signal survive a text round-trip through the parent?"

**Why the threshold matters**: in unified mode, one session holds both the
root-level instructions and a scoped standard, and can catch the
contradiction between them; in parallel mode, each subagent sees only its
assigned slice. The threshold preserves cross-file intelligence for small
inputs while staying inside practical limits for large ones.

**Token estimation**: a rough estimate suffices — `chars / 4` for English
text. The cost of being 10% wrong on the estimate is far below the cost of
the extra precision.

---

## Known gaps

- **No path-filter frontmatter key.** The absence of a `paths:` key is
  stated as fact per the exact `SkillMetadata` schema (PART-SKILLS section
  1.1), anchored to the 2.25.0 live baseline and the 2.25.8 documented
  surface. A future release could add one; this page does not predict it.
- **No auto-loaded rules directory.** Same anchoring: the oracle records no
  rules-dir equivalent anywhere in the skills or instruction-file surface.
  Pattern 6's replacement (subdirectory `AGENTS.md`) is the verified
  mechanism.
- **`allowed-tools` is experimental.** The Agent Skills specification marks
  it experimental, and the oracle records no live verification of its
  enforcement behavior (PART-SKILLS section 1.1). The read-only agent
  profile (PART-AGENTS section 7) is the enforced boundary; treat
  `allowed-tools` as declarative until verified.
- **Registry skills are source-verified, not live-exercised.** The
  `/skills` browser flows (import, pin, version switching) could not be
  exercised live in the oracle's sprint; the versioning mechanics in
  pattern 5 rest on source inspection only (PART-SKILLS section 1.6).
- **Cross-CLI skill sharing.** The source guide's tenth section — one skill
  directory per agent CLI convention side by side — was cut: the oracle
  verifies Vibe's own discovery paths (`.vibe/skills/` then
  `.agents/skills/`, PART-SKILLS section 1.2) and that Vibe follows the
  Agent Skills specification (PART-SKILLS section 1.1), but nothing about
  which other products read which directories. Whether `.agents/skills/`
  is a portable cross-product location is plausible and unverified.
- **Subagent `AGENTS.md` visibility.** Whether a `task`-spawned child loads
  project `AGENTS.md` files the way its parent does is not covered by the
  oracle; pattern 9's parallel-mode framing deliberately does not depend on
  it.

## See also

- [Memory systems](memory-systems.md) — the AGENTS.md hierarchy and
  hook-driven durable writes
- [Agent harness](agent-harness.md) — where skills sit in the four-layer
  model
- [Loop-graph engineering](loop-graph-engineering.md) — durable execution
  contracts for orchestrated runs
- [Methodologies](methodologies.md) — how skills ride the plan agent and
  `--worktree`
- [Architecture](architecture.md) — the session store and subagent model
- [Context engineering](context-engineering.md) — budget accounting for
  everything this page injects
- [Glossary](glossary.md)
- [Style guide](../style-guide.md)
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md)

See also: [hooks reference](hooks-events-reference.md), [tools reference](tools-reference.md), [workflows](../workflows/README.md), the [learning path](../learning-path/README.md), and the [examples templates](../../examples/README.md). Surfaces pages are not written yet.
