---
title: "Module 05 — Skills"
description: "Learning-path module 05 (Practitioner track): build scoped Vibe skills — the SKILL.md frontmatter schema, description-as-routing-rule with anti-triggers, discovery order and trust gating, invocation control, progressive disclosure via the skill tool, manual evaluation with programmatic mode, and retirement"
tags: [learning-path, skills, skill-md, routing, progressive-disclosure, exercises]
---

# Module 05 — Skills

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics on this page are cited inline as (PART-XXX) against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md). Anything the
oracle could not verify is in [Known gaps](#known-gaps), never in the body.
Structure and pedagogy are adapted from the source guide; every mechanic is
rebuilt from the oracle. Every mechanic on this page is backend **[stable]**.

**Time:** ~60-75 min · **Complexity:** ★★★☆☆ · **Track:** Practitioner

## TL;DR

- A **skill** is a directory containing a `SKILL.md` file: YAML frontmatter
  plus a Markdown body, with optional `scripts/`, `references/`, and
  `assets/` support directories. Vibe follows the agentskills.io Agent Skills
  spec for the format; `user-invocable` is a Vibe extension beyond it
  (PART-SKILLS §1.1).
- `description` (1–1024 chars) is **the only text the model sees before
  loading the skill** — so it is a routing rule, not documentation. Write
  triggers and anti-triggers into it (PART-SKILLS §1.1).
- Discovery order: builtins (the names `vibe` and `skill-creator` are
  reserved) → `skill_paths` config entries → project
  `<root>/.vibe/skills/` then `<root>/.agents/skills/` (trusted roots only) →
  user `~/.vibe/skills/` then `~/.agents/skills/` → registry skills
  (experimental flag). First match wins on a name collision (PART-SKILLS
  §1.2).
- Progressive disclosure is a mechanic, not a convention: the `skill` tool
  loads the body, hands the model the skill's base directory, and returns a
  sampled file listing (max 10 files); re-loads are refused with
  "already loaded earlier in this conversation" (PART-SKILLS §1.4).
- Invocation control at this surface is `user-invocable` alone. `false` means
  model-only: the skill is hidden from the slash menu and `/skill-name` does
  not resolve, but the model can still load it (PART-SKILLS §1.3).
- Guarantees — enforced ordering, required artifacts, hard stops — belong in
  code, hooks, CI. A skill carries judgment, and prose never enforces
  (PART-HOOKS).

*Read if you repeat a procedure or a domain rule across sessions — review
checklists, release steps, project conventions — and want it loaded only when
a request matches. Skip if your instructions are short and relevant to nearly
every session: put them in `AGENTS.md` and they load anyway, with no routing
to get right (see [Module 03](03-memory.md)).*

## Goal

Create a project skill that gives Vibe relevant knowledge or a reusable
procedure without loading its full content into every session — and know when
a skill is the wrong mechanism.

## What You'll Learn

- What a skill is, what the model sees before loading one, and when skills
  beat `AGENTS.md`, agents, and hooks
- The verified `SKILL.md` frontmatter schema, and which keys do not exist
- Writing `description` as a routing rule with anti-triggers
- The discovery order, trust gating, and name-collision rules
- Controlling invocation with `user-invocable`
- Structuring a skill for progressive disclosure
- Evaluating a skill by hand in fresh sessions, with a no-skill baseline
- Owning, reviewing, and retiring skills

---

## What Are Skills?

A skill is a directory containing a `SKILL.md` file. The frontmatter
`description` is advertised to the model during the session; the full
instructions load only when you or the model invoke the skill — you by typing
`/skill-name`, the model through the `skill` tool (PART-SKILLS §1.1, §1.3,
§1.4).

This makes skills useful for repeated procedures, checklists, and reference
material that would be too costly or distracting as always-loaded
instructions in `AGENTS.md` (PART-AGENTSMD).

### Example: a review-standards skill

Instead of explaining your review approach in each session, create a project
skill whose description says when it applies:

```markdown
---
name: review-standards
description: Apply this project's review conventions when reviewing a diff or proposed change before merge. Do not use for dependency upgrades or documentation-only changes.
---

# Review Standards

- Review the smallest realistic change that fixes the issue.
- Check behavior through public interfaces, not implementation details.
- Run the relevant test file before the full suite.
```

The model sees the name and description during the session. It loads the body
when the current request matches the description, or when you type
`/review-standards` (PART-SKILLS §1.3).

### Skills vs AGENTS.md vs agents vs hooks

| Mechanism | Best for | Loading or execution |
|---|---|---|
| `AGENTS.md` | Short facts and rules relevant to most sessions | Injected into the system prompt at session start (PART-AGENTSMD) |
| Skill | Reusable knowledge, judgment, or an adaptable procedure | `description` advertised; body loaded on invocation (PART-SKILLS §1.1, §1.4) |
| Agent profile | A repeated role with a pinned toolset and persona, or delegated read-only investigation | Runs as a config-override layer on the session; subagents run in their own session (PART-AGENTS §8-9) |
| Hook or scripted workflow | Preconditions, ordering, retries, stop rules, and checks that must be enforced | Executed by the harness from `hooks.toml` (PART-HOOKS) |

Numbered steps are not automatically a reason to leave the skill format. Move
an operation into a hook, script, or CI job when correctness depends on
guaranteed ordering, a required artifact, a retry policy, or a hard stop. Keep
judgment in the skill — assessing ambiguity, choosing between acceptable
trade-offs. Prose in a `SKILL.md` never enforces anything.

---

## Choose the Ownership Scope First

Sharing a skill does not require co-maintaining one universal copy. As
[Un Skill n'est pas une librairie](https://devx.writizzy.blog/p/un-skill-nest-pas-une-lib)
argues, appropriation, local context, and silent behavioral drift can cost
more than copying the file and specializing it.

Use one of these scopes:

| Scope | Location or channel | Maintenance contract |
|---|---|---|
| Personal | `~/.vibe/skills/` (also `~/.agents/skills/`) | Optimized for one person's habits; no compatibility promise (PART-SKILLS §1.2) |
| Project or team | `<root>/.vibe/skills/` (also `<root>/.agents/skills/`), committed to Git | Shared conventions with a named owner and review path; loads only under trusted roots (PART-SKILLS §1.2) |
| Extra directories | `skill_paths` entries in `config.toml` (absolute or cwd-relative) | You own the wiring and the contents (PART-SKILLS §1.2) |
| Registry | `experimental_enable_registry_skills` plus the `/skills` browser | Discovery source, not a maintenance contract; local and builtin skills win on name collision (PART-SKILLS §1.6) |

For security, treat any downloaded skill as an executable dependency: it can
contain instructions, pre-approved tool grants (`allowed-tools`), and scripts.
For ownership, treat it as situated context: record its scope, owner,
assumptions, and retirement signal. These rules are complementary.

The registry is opt-in and experimental: it is gated by
`experimental_enable_registry_skills` (default `false`), pulls shared workspace
skills from Mistral, and requires a Mistral provider with a usable API key
(PART-SKILLS §1.6). Pins live in `~/.vibe/skills.toml` (global) and
`<root>/.vibe/skills.toml` (project, which wins), with `latest` as a reserved
version alias that always resolves to the newest version server-side
(PART-SKILLS §1.6). Browse with `/skills`; see [Known gaps](#known-gaps) for
what was not live-exercised.

---

## Creating Your First Skill

A project skill lives in `.vibe/skills/{skill-name}/`. The required file is
`SKILL.md` — YAML frontmatter delimited by `---` lines, followed by a
Markdown body. Frontmatter must be the first thing in the file; text before
the first `---` is a parse error (PART-SKILLS §1.1).

### File location

```text
my-project/
└── .vibe/
    └── skills/
        └── review-standards/
            └── SKILL.md
```

### Frontmatter schema

Every key the verified schema accepts (PART-SKILLS §1.1):

| Key | Required | Constraints and behavior |
|---|---|---|
| `name` | yes | 1–64 chars, `^[a-z0-9]+(-[a-z0-9]+)*$` — lowercase alphanumerics and hyphens, no leading, trailing, or consecutive hyphens. Should match the directory name; a mismatch only logs a warning — the skill loads under the frontmatter name |
| `description` | yes | 1–1024 chars. Routing text; the **only** text the model sees before loading the skill |
| `license` | no | String; license name or reference to a bundled license file |
| `compatibility` | no | Max 500 chars; environment requirements |
| `metadata` | no | Flat string-to-string map; values coerced to strings |
| `allowed-tools` | no | Space-delimited string or list of strings; **experimental** — pre-approved tools |
| `user-invocable` | no | Bool, default `true`. `false` = model-only: hidden from the slash menu, `/skill-name` does not resolve |

Unknown keys are silently ignored. The shipped `skill-creator` builtin puts it
plainly: "Do not invent frontmatter keys. Fields from other products (e.g.
`visibility`, `defaultEnabled`) are not part of Vibe's schema and are
ignored." (PART-SKILLS §1.1). There is no `triggers`, `auto_invoke`, or
`keywords` key — a routing description is the only discovery surface.

A complete, canonical example:

```markdown
---
name: code-review
description: Perform automated code reviews
license: MIT
compatibility: Python 3.12+
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - ask_user_question
---

# Code review skill

This skill helps analyze code quality and suggest improvements.
```

(PART-SKILLS §1.1, canonical example from the README.)

### Discovery: search order and collisions

Vibe discovers skills in this order, first match by name winning
(PART-SKILLS §1.2):

1. **Built-in skills** — the names `vibe` and `skill-creator` are reserved; a
   discovered skill colliding with a builtin name is silently skipped at load
   time
2. `skill_paths` entries from `config.toml` (absolute or cwd-relative)
3. **Project dirs, per project root**: `<root>/.vibe/skills/` then
   `<root>/.agents/skills/` — only for trusted roots (the trusted working
   directory plus `--add-dir` paths); an untrusted root contributes nothing
4. **User dirs**: `~/.vibe/skills/` then `~/.agents/skills/` (always active)
5. **Registry skills** — only when `experimental_enable_registry_skills =
   true`, loaded last; a local or builtin skill wins on collision

Filtering in `config.toml`, if you need it (PART-SKILLS §1.2):

```toml
skill_paths = ["/path/to/custom/skills"]   # additional search dirs
enabled_skills = ["code-review", "test-*"]  # allowlist; glob and re: regex supported
disabled_skills = ["experimental-*"]        # blocklist; ignored when enabled_skills is set
experimental_enable_registry_skills = false # default
```

Changes on disk — new skills, edits, removals — are picked up with
`/reload`, which reloads configuration, agent instructions, and skills from
disk (PART-SKILLS §1.5; PART-COMMANDS §2).

### The built-in skills

Two skills ship in the CLI itself, registered in code rather than as files
(PART-SKILLS §1.5):

| Builtin | Invocation | Role |
|---|---|---|
| `vibe` | Model-only (`user_invocable = false`) | The CLI's self-awareness reference: documents `VIBE_HOME` layout, config keys, tools, skills, agents, MCP, hooks, sessions, and more. The model loads it for any question about Vibe itself |
| `skill-creator` | You and the model | Loads "before creating, updating, or deleting a Vibe skill"; documents the whole format, the discovery order, scope choice, and support files |

The `skill-creator` skill is the canonical helper for skill work: before
creating or changing a skill, let it load (ask the model to create a skill, or
invoke `/skill-creator`) and follow the format it documents (PART-SKILLS
§1.5).

---

## Skill Discovery and Invocation

### Write the description as a routing rule

The model decides relevance from `description` alone — that is the verified
mechanic, and it makes the source's doctrine literal (PART-SKILLS §1.1).
Include:

- What the skill does
- The situations where it should be used
- Important anti-triggers, when adjacent tasks belong elsewhere

```yaml
description: Review database schema and query changes for indexes, locking, and migration safety. Use for SQL migrations and slow-query investigations; do not use for application-level API design.
```

### User invocation: /skill-name

Input starting with `/` is classified in order: registered slash commands
first, then `/skill-name` skill resolution, then `!` shell, then plain prompt
— so a skill never shadows a built-in command (PART-SKILLS §1.3). For a
`/skill-name` input, the first whitespace-delimited word is lowercased and
looked up; it resolves only if the skill exists **and** is user-invocable,
and the remainder of the input is passed to the skill as extra instructions
(PART-SKILLS §1.3):

```text
/review-standards Focus on the auth changes
```

Expected behavior: the skill body loads with "Focus on the auth changes" as
additional instructions.

Typing a `/word` mid-prompt (not as the first word) shows an inline
ghost-text preview of the best-matching skill name, with Tab to accept; only
skills are offered this way (PART-SKILLS §1.3).

### Model invocation: the skill tool

The model loads skills through the `skill` tool: argument `{ "name":
<skill name> }`, permission `ALWAYS` — loading a skill never prompts for
approval (PART-SKILLS §1.4). The result is a `<skill_content name="...">`
envelope containing:

- The skill body
- The skill's base directory, with "Relative paths in this skill are relative
  to this base directory."
- A sampled `<skill_files>` listing of the skill directory — max 10 files,
  walk capped at 200 entries, skipping `.git`, `node_modules`, caches, and
  build dirs; `SKILL.md` itself is excluded

If the skill was already loaded, the tool refuses and returns: "Skill
'\<name\>' is already loaded earlier in this conversation. Reuse those
instructions." (PART-SKILLS §1.4). An invoked body therefore stays in the
conversation — there is no re-load path.

### Control who can invoke it

`user-invocable` decides whether the `/skill-name` path resolves
(PART-SKILLS §1.3):

| Setting | Effect | Appropriate for |
|---|---|---|
| `user-invocable: true` (default) | You and the model can invoke it | Review checklists, release procedures, any manual workflow |
| `user-invocable: false` | Model-only: hidden from the slash menu, `/skill-name` treated as a plain prompt; still loadable by the model | Background domain knowledge with no useful slash command |

The builtin `vibe` skill is the shipped example of model-only: it is
`user_invocable = false`, live-verified (PART-SKILLS §1.5, §1.7). There is no
"manual only" flag at this surface — see [Known gaps](#known-gaps).

### Review allowed-tools before trusting a third-party skill

`allowed-tools` is an experimental list of pre-approved tools in the
frontmatter (PART-SKILLS §1.1). Read the exact scope and duration of the
pre-approval as unresolved — [Known gaps](#known-gaps) — but treat the field
as a capability grant either way: a broad entry in a downloaded skill
materially changes its risk. Audit it before use, the way you audit a
dependency's install script.

---

## Progressive Disclosure

Keep `SKILL.md` focused and move detailed material into supporting files.
The optional directories come from the Agent Skills spec, which Vibe follows
(PART-SKILLS §1.1):

```text
review-standards/
├── SKILL.md
├── references/
│   ├── migration-safety.md
│   └── locking-notes.md
└── scripts/
    └── select-affected-tests.sh
```

Link each supporting file from `SKILL.md` and say when to open or execute it.
The mechanics make this work: the `skill` tool hands the model the skill's
base directory and states that relative paths resolve against it, and the
sampled `<skill_files>` listing acts as a menu of what exists (PART-SKILLS
§1.4). Filenames you can see are cheap; file bodies load only on demand.

---

## Common Skill Patterns

### Pattern 1: project conventions

Use a project skill when the advice depends on repository architecture,
team decisions, or local tooling.

```markdown
---
name: python-standards
description: Apply this repository's Python typing, import, packaging, and test conventions when editing Python code.
---

# Python Standards

- Use type hints on public functions.
- Keep tests next to their package under `tests/`.
- Follow the repository's configured formatter and linter.
- Verify with the narrowest relevant test target first.
```

### Pattern 2: domain knowledge

Background rules the model should apply whenever the domain comes up, with no
useful manual entry point:

```markdown
---
name: payment-rules
description: Apply this product's payment state machine, idempotency, and audit rules when changing checkout or refund flows.
user-invocable: false
---

# Payment Rules

- Never log card data or payment secrets.
- Reuse the existing idempotency key at retry boundaries.
- Treat provider callbacks as untrusted and potentially duplicated.
- Verify state transitions against the canonical state machine.
```

### Pattern 3: manual workflow

A procedure you run yourself; the remainder of your `/skill-name` input is
passed in as extra instructions (PART-SKILLS §1.3):

```markdown
---
name: release-check
description: Prepare and verify a release candidate for this repository.
---

# Release Check

1. Read the repository release instructions.
2. Verify the version and the working tree.
3. Run the required checks.
4. Report blockers without publishing.
```

The model can adapt these steps — that is the point of a skill. If publishing
must never happen before a specific gate, enforce that gate in a script,
hook, or CI job; do not rely on the prose.

---

## Exercises

### Exercise 1: Build a review skill and load it

Create a project skill with a routing description, then load it both ways.

```bash
mkdir -p .vibe/skills/pr-review
cat > .vibe/skills/pr-review/SKILL.md << 'EOF'
---
name: pr-review
description: Run this repository's code review checklist when reviewing a pull request, a diff, or proposed changes before merge. Do not use for dependency upgrades or documentation-only changes.
metadata:
  owner: platform-team
  version: 1.0.0
---

# PR Review Checklist

## When to apply

Use for code reviews of proposed changes before merge.
Do not use for dependency upgrades or documentation-only changes.

## Checklist

1. The change takes the smallest realistic path to the fix.
2. Behavior is exercised through public interfaces.
3. New or changed behavior has a covering test.
4. No secret or credential is introduced.

## Verification

Run the relevant test file for the touched code before the full suite.

## Report

Report each finding with file and line, ordered by severity, and state
plainly what you did not check.
EOF
```

Start `vibe` in the project, run `/reload`, then invoke:

```text
/pr-review Focus on the auth changes
```

Expected observations:

- The skill resolves — it exists and is user-invocable (default), and
  "Focus on the auth changes" is passed in as extra instructions
  (PART-SKILLS §1.3).
- The model follows the checklist and the report format from the body.

Then ask the model to load the same skill again: *"Load the pr-review
skill."* Expected: the `skill` tool refuses with "Skill 'pr-review' is
already loaded earlier in this conversation. Reuse those instructions."
(PART-SKILLS §1.4).

A response in the guide's discipline looks like this:

> Loading the review checklist, then I'll read the auth changes and report
> findings by severity.
>
> `src/auth/session.ts` — two findings:
>
> - MEDIUM — `verifyToken` has no covering test; the checklist's
>   behavior-with-test rule fails here
> - LOW — a hardcoded fallback TTL differs from the documented default
>
> I ran only `auth.test.ts` per the skill's verification step; the full
> suite has not run. No merge blockers beyond the missing test.

### Exercise 2: Verify routing in fresh sessions

Each prompt needs a fresh session — the skill tool refuses re-loads within a
conversation, and an earlier load would contaminate the next case
(PART-SKILLS §1.4). Start a new session per prompt:

| Prompt | Expected routing |
|---|---|
| *"Review the changes in this diff before I merge"* | Skill should load via the `skill` tool (PART-SKILLS §1.4) |
| *"Update the README title to match the new product name"* | Anti-trigger — the description excludes documentation-only changes; the skill should not load (PART-SKILLS §1.1) |

For the positive case, inspect the result too: the skill should route
correctly **and** the review should follow the checklist. Triggering alone is
not success — that is the two-property test in the evaluation section below.

### Exercise 3: Probe the guardrails

Run each probe and read the behavior:

1. **Reserved names.** Rename your skill directory to
   `.vibe/skills/skill-creator/`, run `/reload`, then invoke `/skill-creator`.
   Expected: the **builtin** loads, not your file — a discovered skill
   colliding with a builtin name is silently skipped at load time
   (PART-SKILLS §1.2).
2. **Name mismatch.** Restore the directory to `pr-review` but set the
   frontmatter `name: review-checklist`. Run `/reload`, then
   `/review-checklist`. Expected: the skill loads under the frontmatter name;
   the mismatch with the directory only logs a warning (PART-SKILLS §1.1).
3. **Model-only.** Restore `name: pr-review`, add `user-invocable: false`,
   run `/reload`, then type `/pr-review`. Expected: it no longer resolves as
   a skill — the input is treated as a plain prompt (PART-SKILLS §1.3). In a
   fresh session, a matching review request should still load it via the
   `skill` tool.
4. **Allowlist.** Add to `.vibe/config.toml`:

   ```toml
   enabled_skills = ["pr-review"]
   ```

   Run `/reload`. Expected: every other discovered skill is hidden —
   `enabled_skills` is an allowlist (PART-SKILLS §1.2). Remove the key and
   `/reload` again.

### Exercise 4: Run a with/without baseline

Skills are evaluated by comparison. Run the same review prompt with the skill
enabled, then disabled as a baseline:

```bash
vibe --trust -p "Review the working tree changes and report anything that would block merge." --output json
VIBE_DISABLED_SKILLS='["pr-review"]' vibe --trust -p "Review the working tree changes and report anything that would block merge." --output json
```

Expected observations:

- Both runs complete without approval prompts for skill loading — the
  `skill` tool's permission is `ALWAYS` (PART-SKILLS §1.4) — and the JSON
  output ends with the session's message entries (PART-CLI).
- `VIBE_DISABLED_SKILLS` is the `VIBE_*` env form of the `disabled_skills`
  blocklist: `VIBE_*` overrides any config field, and `disabled_skills`
  hides matching skills (PART-CLI; PART-SKILLS §1.2).
- Keep the prompts read-only: in programmatic mode, approval-required tool
  calls are auto-denied, not auto-approved — pass `--auto-approve` only if
  the prompt genuinely needs gated tools (PART-CLI).

Compare the two outputs against explicit assertions (checklist followed,
severity ordering, no invented findings). The no-skill run is the baseline;
the delta is what the skill is worth.

---

## Evaluation and Iteration

Vibe has no skill-evaluation subsystem — no eval file format, no runner, no
grading harness (see [Known gaps](#known-gaps)). Evaluation is a manual
discipline, and programmatic mode is the execution vehicle. Test two
independent properties:

1. **Trigger correctness** — does the model load the skill on relevant
   prompts and skip it on irrelevant ones? (Exercise 2.)
2. **Output quality** — when loaded, does the result satisfy explicit
   assertions? (Exercise 4.)

Rules of the discipline:

- Fresh session per prompt (the skill tool refuses re-loads within a
  conversation, and prior loads leak into later judgments — PART-SKILLS
  §1.4).
- With-skill and without-skill runs, the no-skill run as the baseline
  (Exercise 4).
- Record the model, Vibe version, prompt set, number of runs, assertions,
  pass counts, and variance. `--output json` gives you comparable transcripts
  (PART-CLI).
- Choose acceptance thresholds from the risk and failure cost of the
  specific skill. A universal pass-rate target hides the denominator, the
  variance, and the severity of individual failures.
- LLM self-critique is an evidence generator, not independent proof. Review
  important outputs with deterministic checks or a qualified human.

Triggering is not quality. A skill that loads on every adjacent prompt and
degrades the common case is worse than no skill.

---

## Skill Lifecycle

1. **Scope** — personal, project/team, extra dirs, or registry; name the
   owner (PART-SKILLS §1.2).
2. **Baseline** — collect representative prompts before adding the skill
   (Exercise 4).
3. **Create** — the smallest useful `SKILL.md` plus supporting files;
   `skill-creator` documents the format and loads before skill create,
   update, and delete (PART-SKILLS §1.5).
4. **Evaluate** — routing and output quality in fresh sessions.
5. **Observe** — capture real misses, wrong-context activations, and stale
   advice.
6. **Review** — propose changes, re-run the baseline before accepting them.
7. **Retire** — remove skills that are unused, stale, redundant, or harmful.

There is no context-cost or unused-skill report at the verified surface —
retirement review is manual (see [Known gaps](#known-gaps)). Do not archive a
retired skill inside a discovered directory: every subdirectory with a
`SKILL.md` under a search path is a discovery candidate, so a "retired" skill
in `.vibe/skills/` stays live (PART-SKILLS §1.2). Preserve it in Git history
or move it outside the discovered directories with a dated retirement note,
then `/reload` (PART-SKILLS §1.5; PART-COMMANDS §2).

---

## DO / DON'T

| DO | DON'T |
|---|---|
| Keep one clear responsibility per skill | Create skills with overlapping routing descriptions |
| Write `description` as a routing rule with triggers and anti-triggers | Invent frontmatter keys — unknown keys are silently ignored (PART-SKILLS §1.1) |
| Record scope, owner, assumptions, and retirement criteria in `metadata` | Treat a registry import as a maintenance contract |
| Keep `SKILL.md` short; link supporting files | Load a whole reference library into the body |
| Review a third-party skill's instructions, scripts, and `allowed-tools` before use | Treat `allowed-tools` as a security boundary — it is experimental |
| Compare with and without the skill in fresh sessions | Infer output quality from successful invocation |
| Put guaranteed gates in code, hooks, CI | Keep retired skills inside discovered directories |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Skill never appears | The project root is untrusted — untrusted roots contribute no `.vibe/` or `.agents/` content | Trust the folder, use `--add-dir`, or move the skill to `~/.vibe/skills/` (PART-SKILLS §1.2) |
| `/name` typed mid-prompt does not invoke | Only the first word resolves as a skill command; mid-prompt `/word` shows a ghost-text preview instead | Start the input with `/name`, or Tab-accept the preview (PART-SKILLS §1.3) |
| `/name` sends as a plain prompt | `user-invocable: false` — the skill is model-only | Intended; remove the flag to make it user-invocable (PART-SKILLS §1.3) |
| Edits to `SKILL.md` have no effect | Skills are read at discovery time | Run `/reload`; it is rejected while the agent is busy — retry when idle (PART-SKILLS §1.5; PART-COMMANDS §2) |
| A skill you wrote shadows nothing / is missing | Its name collides with a builtin (`vibe`, `skill-creator`) and is silently skipped | Rename the skill (PART-SKILLS §1.2) |
| Other skills disappeared | `enabled_skills` is set — an allowlist hides everything else | Remove the key or add the names to it (PART-SKILLS §1.2) |

## Validation: You're Ready If

- Your skill is stored at `.vibe/skills/{name}/SKILL.md` with a `name` that
  matches its directory and passes the frontmatter schema
- Its `description` covers triggers and important anti-triggers, and you can
  say why that field alone decides routing (PART-SKILLS §1.1)
- You can state the discovery order and where each of your skills loads from
- You invoked your skill as `/skill-name` with trailing text, and saw the
  model load it via the `skill` tool — and saw the re-load refusal
- You ran a with/without baseline in fresh sessions and compared outputs
  against explicit assertions
- You know which guarantees belong in a hook, script, or CI job — not in
  skill prose
- You know how to retire the skill: move it out of discovered directories and
  `/reload`

## Known gaps

- **Live-run note (2026-09-24, vibe 2.25.7): the skill tool does not refuse re-loads on the live CLI.** Asking the model to load `pr-review` twice in one conversation, both loads completed and returned the identical `<skill_content>` envelope — no "Skill 'pr-review' is already loaded earlier in this conversation. Reuse those instructions." refusal (three independent live runs, `--output json`, entries both `status: completed`). The refusal is what the oracle documents (PART-SKILLS §1.4); on the installed 2.25.7 it was not reproduced. Treat the no-re-load guarantee as unenforced on this build: fresh sessions per prompt (Exercise 2, Exercise 4) remain the reliable evaluation discipline.
- **Live-run note (2026-09-24, vibe 2.25.7): `VIBE_DISABLED_SKILLS` must carry a JSON array, not a bare word.** The exercise's original `VIBE_DISABLED_SKILLS=pr-review` form crashed the CLI at startup (`LayerImplementationError: Layer 'environment': _build_config_snapshot() failed` — the env layer tries to decode complex config fields as JSON). The corrected form `VIBE_DISABLED_SKILLS='["pr-review"]'` runs, hides the skill from routing (zero `skill` tool loads in the baseline run while the same prompt loads it without the variable), and is the form shown above. The `VIBE_*`-overrides-config mechanic itself is confirmed live.
- **`disable-model-invocation` does not exist at the live-verified surface.**
  The 2.25.0 baseline has no such field; a `disable-model-invocation` boolean
  (making a skill model-un-invocable, i.e. manual-only) appears in the 2.25.8
  source tree only and was not exercised against a live install. Invocation
  control as taught here is `user-invocable` alone (PART-SKILLS §1.1).
- **`allowed-tools` scope and duration.** The key is schema-verified as an
  experimental list of pre-approved tools, but which turn or toolset the
  pre-approval covers is not verified at this surface. Treat it as unverified
  capability, audit it in third-party skills, and do not rely on it for
  safety.
- **No skill-evaluation subsystem.** There is no eval file format or runner,
  and no equivalent to a context-cost/unused-skill report command. The
  source's doctor command and eval framework were dropped; evaluation here is
  the manual programmatic-mode discipline (PART-CLI).
- **Registry browser flows.** `/skills`, pin manifests, and version
  resolution are source-verified only — `experimental_enable_registry_skills`
  was false on the verification machine and no end-to-end import/pin run was
  made (PART-SKILLS §1.6). Pin-update reporting beyond the `latest` alias is
  unverified.
- **Re-invoking `/skill-name` in the same conversation.** The
  already-loaded refusal is verified on the `skill` tool path
  (PART-SKILLS §1.4); whether the user-side `/skill-name` path produces the
  same refusal is not separately verified.
- **`AGENTS_HOME`.** `~/.agents` is hard-coded in 2.25.0 and cannot be
  redirected by an environment variable; future overridability is unverified
  (PART-SKILLS §1.2).

## See also

- [Skill design patterns](../core/skill-design-patterns.md) — reusable skill
  patterns at full depth
- [Agents and skills reference](../core/agents-and-skills-reference.md) — the
  companion specialization mechanism, including the built-in skill inventory
- [Memory systems](../core/memory-systems.md) — `AGENTS.md`, the
  always-loaded instruction layer a skill complements
- [Hooks and events reference](../core/hooks-events-reference.md) — the
  enforcement side of the guarantees-vs-judgment split
- [Settings reference](../core/settings-reference.md) — `skill_paths`,
  `enabled_skills`, and the config stack they resolve through
- [Module 06 — Hooks](06-hooks.md) — the next module: enforced automation
- [Style guide](../style-guide.md)
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md)

Structure and pedagogy adapted from the source guide under CC BY-SA 4.0 —
see [NOTICE.md](../../NOTICE.md). Mechanics rebuilt from the oracle.
