---
title: "Context Engineering"
description: "Filling the context window with the right information at the right time in Vibe: the AGENTS.md instruction hierarchy, config.toml layering, budget math, compaction, modular architecture, team assembly, audits, and reduction techniques"
tags: [context, instructions, configuration, architecture, team, advanced]
---

# Context Engineering

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics on this page are cited inline as (PART-XXX) against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md). Anything the
oracle could not verify from public sources is in
[Known gaps](#known-gaps), never in the body. The structure and pedagogy are
adapted from the source guide; every mechanic is rebuilt from the oracle.

## TL;DR

- Context engineering is the discipline of filling the context window with
  the right information at the right time. Most output failures are context
  failures, not model failures.
- In Vibe, the static context system is the **AGENTS.md hierarchy**: user-level
  `~/.vibe/AGENTS.md` (always loaded), project `AGENTS.md` files loaded from
  each project root walking up to its trust root (trusted folders only), and
  subdirectory `AGENTS.md` files injected lazily when a file below them is
  read. Project instructions beat user instructions; closer directories win
  (PART-AGENTSMD).
- The config system is an eight-layer `config.toml` stack: defaults <
  GrowthBook < user < project < environment < session overrides < agent
  profile < admin (PART-CONFIG section 2.1).
- `auto_compact_threshold` (default 200,000 tokens, per-model overridable, `0`
  disables) is a **compaction trigger, not a context window**. A middleware
  warns once at 50 percent of the threshold (PART-SESSIONS section 4).
- The progression is monolith -> modular -> path-scoped. Measure with the
  token audit; retire rules with the archive and ejection patterns.

*Read if you maintain AGENTS.md files, config layers, or hooks for one or more
projects, or your sessions drift off-convention as they grow. Skip if you have
never written an instruction file and only run single-shot prompts.*

## Table of Contents

1. [What is context engineering](#1-what-is-context-engineering)
2. [The context budget](#2-the-context-budget)
3. [The AGENTS.md instruction hierarchy](#3-the-agentsmd-instruction-hierarchy)
4. [Config layering](#4-config-layering)
5. [Modular architecture](#5-modular-architecture)
6. [Team assembly](#6-team-assembly)
7. [The context lifecycle](#7-the-context-lifecycle)
8. [Quality measurement](#8-quality-measurement)
9. [Context reduction techniques](#9-context-reduction-techniques)
10. [Maturity assessment](#10-maturity-assessment)
11. [Signal taxonomy and causal attribution](#11-signal-taxonomy-and-causal-attribution)
12. [Loop closure: PR-based curation](#12-loop-closure-pr-based-curation)
13. [Ejection: disciplined de-engineering](#13-ejection-disciplined-de-engineering)
14. [Constitutional and self-consistency audits](#14-constitutional-and-self-consistency-audits)
15. [Multi-dev profile reconciliation](#15-multi-dev-profile-reconciliation)
16. [Token audit workflow](#16-token-audit-workflow)
17. [Attention mechanics and research patterns](#17-attention-mechanics-and-research-patterns)

---

## 1. What is context engineering

**"Context engineering is the art of filling the context window with the right
information at the right time."** (Andrej Karpathy). Three non-obvious
requirements hide in that sentence:

- **Filling**: populate the window deliberately. Leaving it empty wastes the
  model's capacity; filling it chaotically wastes tokens and degrades output.
- **Right information**: architecture decisions beat linting preferences;
  negative constraints ("never return raw database errors to the client") beat
  aspirations ("write clean code").
- **Right time**: API rules have no value while editing a frontend component.
  Loading everything always is the lazy default, and it degrades adherence.

### Prompt engineering vs. context engineering

| Dimension | Prompt engineering | Context engineering |
|---|---|---|
| Scope | One request | Entire session or system |
| Duration | Single interaction | Persistent across interactions |
| Effort | Per-request crafting | Upfront system design |
| Scale | Individual | Team or organization |
| Artifact | A prompt string | A configuration system |

Prompt engineering writes a good email to a contractor. Context engineering is
the onboarding doc, style guide, and team norms that make every email land. A
great prompt on top of poor context engineering still produces generic output,
because the model lacks structural knowledge of your project.

### Context engineering vs. context optimization

| Dimension | Context engineering | Context optimization |
|---|---|---|
| Core question | What should be in context? | What is the minimum high-signal token set? |
| Method | Add what the model needs to know | Remove what it does not |
| Failure mode | Missing critical information | Overshooting with irrelevant content |
| Output | A context system | A trimmed, high-fidelity configuration |

You do both. The engineering pass builds the complete picture; the
optimization pass (Section 9) prunes it.

**Synthesis vs. reasoning**: context synthesis is stateful and iterative — your
AGENTS.md files are synthesis. Reasoning is ephemeral — the model's
intermediate thoughts, debug traces, and tool chatter are discarded state.
Treating reasoning artifacts as synthesis material pollutes context and
accelerates rot. Keep them separate.

### Why it matters

1. The model has no persistent memory between sessions. Every session starts
   from zero unless context is deliberately provided.
2. The model cannot infer unstated conventions. Interfaces vs. `type` aliases,
   logging before throwing — these must be stated.
3. Instruction placement matters. A rule buried at line 400 of a 500-line
   AGENTS.md is followed less reliably than one in the first 50 lines.

The diagnostic reframe: **most output failures are context failures**. When the
model produces a generic response or violates a convention, the context was
incomplete, contradictory, or missing the right information at the right time.
Troubleshoot "what is missing from the context?", not "what is wrong with the
model?".

### The layers

| Layer | Artifact | Loaded when | Scope |
|---|---|---|---|
| **User** | `~/.vibe/AGENTS.md` | Always | All projects |
| **Project** | `AGENTS.md` from each open project root, walking up to its trust root | Session start; trusted roots only | Current project(s) |
| **Subdirectory** | `AGENTS.md` in subdirectories of an open root | Lazily, when a file below is read | That subtree |
| **Session** | Inline instructions, `VIBE_*` env overrides, session overrides | Runtime | Current session |

(PART-AGENTSMD for the first three; PART-CONFIG sections 2.2-2.3 for the
session layer.)

Each layer has different tradeoffs: user-level is always-on but cannot carry
project specifics; session instructions are flexible but evaporate; project
files are the workhorse — structured, versioned, reviewable. Put each piece of
information in the right layer rather than cramming everything into one file.

### Static vs. dynamic context

| Type | How assembled | Examples in Vibe |
|---|---|---|
| **Static** | Before the session, from files | `~/.vibe/AGENTS.md`, project and subdirectory `AGENTS.md`, the system prompt |
| **Dynamic** | At runtime, from tools | Tool outputs, `@`-mentioned file contents, MCP data |

Static context failure manifests as consistent convention violations; dynamic
context failure as the model acting on stale or incomplete information
mid-task. The two compose: static context sets the behavioral envelope,
dynamic context feeds each task.

### Why context rot is structural

Transformer attention is pairwise: attention relationships grow as n², not n.
Double the context and you quadruple what the model must weigh. Context rot —
progressive loss of instruction adherence as context grows — is baked into
the architecture, not a bug future models will eliminate. You cannot buy your
way out with a bigger window; you keep context lean and load information just
in time.

| Strategy | Mechanism | When to use |
|---|---|---|
| **Pre-loading** | Inject all potentially relevant context before inference | Known, stable requirements |
| **Just-in-time retrieval** | Retrieve exactly when the task demands it | Dynamic, task-specific context |

Vibe reflects both: project and user AGENTS.md files load upfront
(pre-loading), while subdirectory AGENTS.md files load only when a file below
them is read, and `@` mentions re-read file content at mention time
(just-in-time) (PART-AGENTSMD; PART-SESSIONS section 6).

---

## 2. The context budget

### Token math

Tokens ≈ characters ÷ 4 for English and code, rough but usable for budgets.
Every session starts with a fixed baseline before the first user message:

| Component | Loaded when | Budget behavior |
|---|---|---|
| `~/.vibe/AGENTS.md` | Always | Full size, every session, every project |
| Project `AGENTS.md` chain (root up to trust root) | Session start | Full size; grows with each level you add |
| Subdirectory `AGENTS.md` | Only when a file below is read | Zero until a task touches that subtree |
| System prompt | Always | Size not published; see Known gaps |
| `@`-mentioned files | Every turn | Re-read fresh each mention; capped at 2,000 lines / 50 KB per file, 8 files per prompt |
| `post_tool` hook `additional_context` | Per matching tool call | Appended to tool output each call |

(PART-AGENTSMD; PART-SESSIONS section 6; PART-HOOKS section 3.3.)

The structural point: the user file and the project chain are your always-on
overhead; subdirectory files are the escape valve that keeps always-on cost
flat as a project grows.

### Signs of context overload

- Adherence to early rules degrades as the session grows.
- The model restates or contradicts instructions you know are in context.
- Responses become generic; project-specific conventions stop appearing.
- Sessions slow down and drift toward compaction warnings.

Instruction files past a few hundred lines lose adherence in practice: rules
compete for attention, and the ones on page five lose to the ones on page one.
The ceiling is not a fixed number, but the direction is reliable — more
rules in one file means less adherence per rule.

### MECW: maximum effective context window

The usable window is smaller than the advertised one. MECW = the window minus
fixed overhead (instruction files, system prompt, tool schemas) minus the
degradation zone where recall weakens. Two levers raise MECW: shrink fixed
overhead (Section 9), and load on demand instead of upfront (Section 5).

### Path-scoping and budget efficiency

Arithmetic example. A monolithic project file carrying backend + frontend +
database + API rules costs ~8,000 always-on tokens. Path-scoped:

```text
Always-on: root AGENTS.md with shared rules        ~2,000 tokens
Active while reading files under src/api/:        +~1,500 tokens
Active while reading files under src/components/:  +~1,200 tokens
Active while reading files under prisma/:         +~800 tokens
```

Each subsystem gets its full rule set, but only when work touches that
subtree. In Vibe this is a real, verified mechanic, not an aspiration:
subdirectory AGENTS.md files are collected lazily between a read file's
parent and its containing open root, injected on `read_file` (PART-AGENTSMD).

### Compaction is a trigger, not a window

[both]

Do not conflate the compaction threshold with a context window size.
`auto_compact_threshold` is a config key — global default `200_000`, overridable
per model, `0` disables auto-compaction entirely. Before every turn, if
`threshold > 0` and `context_tokens >= threshold`, the middleware pipeline
runs a compaction. Live-verified on 2.25.0, the default Mistral model entries
carried 200000 while user-added models carried other values — per-model values
are common in practice (PART-SESSIONS section 4.1).

A `ContextWarningMiddleware` warns once per session when context reaches 50
percent of the threshold (PART-SESSIONS section 4.1). Treat the warning as
your signal to act, not the trigger itself.

`/compact [instructions]` runs compaction on demand:

- Extra instructions are appended to the compaction prompt under
  `## Additional Instructions` (PART-SESSIONS section 4.2).
- On success, a user-role envelope message marked
  `context_boundary="compaction"` is appended, `context_tokens` resets to 0,
  and the same session and visible conversation continue (PART-SESSIONS
  section 4.2).
- A failed summarization retries with a dedicated fallback call; on
  `ContextTooLongError` the oldest conversation round is dropped and retried
  up to 3 times (PART-SESSIONS section 4.2).
- The prompt and the summarizer model are configurable:
  `compaction_prompt_id` (custom `.md` file in `.vibe/prompts/` or
  `~/.vibe/prompts/`), `compaction_model`, and
  `raise_on_compaction_failure` for strict mode (PART-SESSIONS section 4.3).

Compaction is lossy by design: the summary is what survives. If certain facts
must survive verbatim, put them in an instruction file — that is what the
static layer is for. Model context window sizes are model specs, not config;
this guide states none (see Known gaps).

### `@` mentions are a running cost

[stable]

An `@path` mention stays literal in the prompt and injects a synthetic
`read_file` call, so the content arrives as a fresh tool result — there is no
caching or dedup; re-mentioning re-reads. Caps: 2,000 lines and 50 KB per
file, 8 file mentions per prompt (PART-SESSIONS section 6). Mentioning the
same file three times costs its tokens three times.

### Session-level budget switches

`--max-tokens N` caps total prompt + completion tokens across a programmatic
(`-p`) session and interrupts the run when exceeded; `--max-turns` caps
assistant turns (PART-CLI). Useful for canaries and batch jobs where a runaway
loop would otherwise burn the budget.

---

## 3. The AGENTS.md instruction hierarchy

[stable]

| Location | Loaded when | Role |
|---|---|---|
| `$VIBE_HOME/AGENTS.md` (`~/.vibe/AGENTS.md`) | Always (user source enabled) | User-level instructions |
| `<project-root>/AGENTS.md`, plus every `AGENTS.md` walking up from each open project root to its trust root (inclusive) | Session start, when `include_project_context` is on (default); roots must be trusted | Project instructions, "checked into the codebase" |
| `AGENTS.md` in subdirectories of an open root | Lazily, when a file below them is read | Scoped instructions |

(PART-AGENTSMD.)

**Priority semantics** (injected prompt, verbatim from the source): "When both
user-level and project-level instructions are present, project instructions
take priority over user instructions. When multiple project-level AGENTS.md
files are present, instructions closer to the working directory take
priority." Each file applies to its own directory and all descendants within
the project, and the whole set overrides default system-prompt behavior
(PART-AGENTSMD).

**Trust gating**: project AGENTS.md files load only for trusted folders. An
untrusted working directory runs with project configuration ignored and a
stderr warning suggesting `--trust`; `--trust` grants session-only trust and
is never persisted to `trusted_folders.toml`. User-level files always load
(PART-TRUST sections 3.4-3.5). Note the trust prompt itself triggers on
"trustable files" — an `AGENTS.md` at or above the working directory counts
(PART-TRUST section 3.2).

### What belongs at each level

**User (`~/.vibe/AGENTS.md`)** — identity and communication preferences,
cross-project conventions (commit style, PR format), universal security
constraints. Keep it small: it is overhead in every session of every project.

**Project root (`AGENTS.md`)** — stack and versions, architecture decisions
and their rationale, team conventions, testing requirements, path-scoped
pointers to structural indexes (Section 5).

**Subdirectory (`src/api/AGENTS.md`)** — rules that apply only within that
subtree. The directory position is the entire scope declaration; there are no
import directives to maintain (PART-AGENTSMD).

**Session** — one-off constraints ("do not change the public API surface in
this refactor"), experiment parameters, debug constraints. Anything you repeat
across sessions belongs in a file, not here.

### The altitude problem

| Altitude | Example | Verdict |
|---|---|---|
| Too vague | "Write clean code" | Cut: no behavior change |
| Too vague | "Follow security best practices" | Cut: replace with specific constraints |
| Productive | "Never expose raw database IDs in API responses; use UUIDs" | Keep: specific, overrides a likely default |
| Productive | "Use the `Result<T, E>` pattern for service functions, not try/catch" | Keep: specific, overrides a common default |
| Too granular | "Use 2-space indentation" | Cut: delegate to a formatter |
| Too granular | "Add JSDoc to every function" | Cut: delegate to a lint rule |

The test: would the model, with no project context, reasonably do something
different here? If yes, the rule earns its tokens. Aspirational rules are
ignored; mechanical rules belong in deterministic tooling, not probabilistic
instruction-following.

### Decision tree: where does this rule go?

```text
Relevant to every project I work on?
├── Yes → ~/.vibe/AGENTS.md
└── No ↓
Relevant to a specific subtree?
├── Yes → subdirectory AGENTS.md (e.g. src/api/AGENTS.md)
└── No ↓
Relevant to the whole project?
├── Yes → project root AGENTS.md
└── No ↓
Applies only to this task or session?
├── Yes → inline session instruction
└── No → not a rule; drop it
```

### Documented overrides

Conflicts resolve as project beats user and closer directory beats distant one
(PART-AGENTSMD). When a lower-level rule intentionally contradicts a
higher-level one, say so in the file — an undocumented override that
contradicts a parent rule reads as a conflict during audits, because that is
what it is. For full control, custom prompts in `$VIBE_HOME/prompts/*.md`
replace the default system prompt entirely when `system_prompt_id` names them
(PART-AGENTSMD).

---

## 4. Config layering

[stable]

Instruction files are one input. The rest of your configuration resolves
through an eight-layer `config.toml` stack, lowest to highest priority
(PART-CONFIG section 2.1):

| # | Layer | Source | Trust gating |
|---|---|---|---|
| 1 | Default | Schema defaults | Always |
| 2 | GrowthBook | Experiment-mapped values | Always |
| 3 | User | `~/.vibe/config.toml` | Always trusted |
| 4 | Project | `.vibe/config.toml`, discovered walking up from the working directory | Only when the file's parent directory is trusted |
| 5 | Environment | `VIBE_*` variables | Always |
| 6 | Session overrides | CLI/session options (`--enabled-tools`, `--disabled-tools`, MCP entries) | Per session |
| 7 | Agent profile | The active agent profile's overrides | Per session |
| 8 | Admin | Org-enforced config, fetched at session start | Org-wide |

Merge semantics are per-field: scalars replace; `tools` and `models` deep-merge;
list keys such as `disabled_tools`, `agent_paths`, `skill_paths` concatenate;
named collections (`providers`, `mcp_servers`, `connectors`) union by name
(PART-CONFIG section 2.1). Effective precedence in short: **defaults <
GrowthBook < user < project < env < session overrides < agent profile <
admin** — project TOML overrides user TOML, confirmed in code.

Environment overrides follow the pattern `VIBE_<KEY>`, nested keys as
`VIBE_SECTION__KEY`, e.g. `VIBE_ACTIVE_MODEL=local` or
`VIBE_SESSION_LOGGING__ENABLED=false` (PART-CONFIG section 2.2). Implicit
writes ("allow always" approvals, runtime config edits) persist to the user
layer by default — the code comment notes that a project config discovered by
walking up parents "is rarely the scope the user meant in a monorepo"
(PART-CONFIG section 2.3).

Two consequences for context engineering:

1. An untrusted project directory contributes nothing: its config layer is
   skipped and its config directories are not discovered (PART-CONFIG section
   2.5; PART-TRUST section 3.5). Trust is a prerequisite for repo-carried
   configuration of any kind.
2. `--add-dir` paths join the project roots and are implicitly trusted for the
   session, widening where files and project context come from (PART-TRUST
   section 3.3).

A key-by-key reference for `config.toml` lives in
[settings-reference.md](settings-reference.md); this section covers only the
layering that decides where a setting goes.

---

## 5. Modular architecture

### The problem with monolithic instruction files

A 600-line root AGENTS.md with no structure is the most common failure mode:

1. Rules from unrelated domains sit side by side.
2. Attention is not uniform — rules on page five get less weight than rules
   on page one.
3. Nobody can find the relevant rule quickly, so duplicates accumulate.
4. Every edit requires scanning the whole file for conflicts.
5. Adherence degrades continuously as the file grows.

The fix is architectural: decompose by domain, then load each module only when
relevant. In Vibe, the second half is native — subdirectory AGENTS.md files
load lazily on `read_file`, scoped between the read file's parent and its
containing open root (PART-AGENTSMD).

### The path-scoping pattern

```text
project/
├── AGENTS.md                    # Root: shared rules + pointers
├── src/
│   ├── api/
│   │   └── AGENTS.md            # API rules; loads when a file under src/api/ is read
│   ├── components/
│   │   └── AGENTS.md            # UI rules
│   └── lib/
│       └── AGENTS.md            # Shared-library rules
├── prisma/
│   └── AGENTS.md                # Database and migration rules
└── tests/
    └── AGENTS.md                # Testing conventions
```

Example `src/api/AGENTS.md`:

```markdown
# API rules

- Route handlers delegate to services; no business logic inline
- Validate all input at the boundary before processing
- Error responses use the standard shape: { error, code }
- Never log request bodies that may contain PII; log IDs only
```

These four rules are in context only when a file under `src/api/` is read.
They cost nothing while working in `src/components/`. No import list to
maintain: the tree is the configuration.

### Rules vs. skills

| Dimension | Rules | Skills |
|---|---|---|
| Nature | Constraints, conventions | Procedures, workflows |
| When active | Loaded with their scope | Invoked on demand |
| Example | "Never expose raw IDs in responses" | "How to add an API endpoint in this project" |
| Token cost | Always-on within scope | Paid only when used |

A rule states a boundary; a skill carries a multi-step procedure. Putting the
endpoint-creation procedure in a rule means paying 40 lines of procedure
tokens in every session that reads that scope. Skill design is its own page;
the budget principle stands: constraints live in AGENTS.md, procedures live
in load-on-demand artifacts.

### Progressive disclosure

Load what the task at hand needs, not what might ever be needed:

- **Always-on**: architecture decisions, naming conventions, security
  constraints.
- **On demand**: deployment procedures, test templates, migration recipes —
  referenced by pointer, loaded when a task warrants.

Configured MCP servers also contribute tool definitions to the prompt before
any user content; prune servers and tools you rarely use. The same
progressive-disclosure logic applies: a server used in fewer than a fifth of
a project's sessions should not ride along in the rest.

### Anti-pattern: the monolithic AGENTS.md

```markdown
# AGENTS.md (600 lines)

## Rules
1. Use TypeScript
2. No any types
3. Run tests before committing
[...497 more rules...]
```

Why it fails: early rules absorb the attention; frontend and backend rules
dilute each other; conflicts hide; adherence decays with size. The fix, in
order: extract rules by domain into subdirectory files, keep the root to
shared rules and pointers, move procedures into skills, and target under ~150
root lines after extraction.

### Structural metadata files

Rules and structure are different context types. Rules answer *how should I
work here?* — stable, almost always relevant. Structure answers *what is the
shape of this project?* — needed for implementation tasks, irrelevant for
review or debugging. The pattern: a small auto-generated file (~1K tokens)
capturing the structural shape, registered as a pointer, not auto-loaded:

| Section | Contents |
|---|---|
| `layers` | Architecture tiers with root paths and file counts |
| `component_domains` | Feature domains with paths and counts |
| `nested_contexts` | Every AGENTS.md below the root, with line count and focus |
| `stats` | Total files, test counts, schema model count |
| `key_paths` | Canonical paths the model frequently gets wrong |

Register it in a reference table inside the root AGENTS.md — the model reads
the table, knows what exists and why, and loads the file only when the task
warrants. The generation script counts directories and globs for nested
AGENTS.md files; no AST parsing. Never hand-curate it: auto-generated files
cannot drift from reality; curated ones can and will.

---

## 6. Team assembly

### The N x M x P problem

- **N developers** with different roles and preferences
- **M projects** with different stacks and conventions
- **P configurations**: each developer x project pair needs one

Maintaining N x M files by hand does not scale. The solution is profile-based
assembly: one shared module base, plus per-developer profiles selecting
modules and overlaying personal preferences. N x M collapses to N profiles
over 1 module base. Vibe's hierarchy already separates personal from shared
(user vs. project AGENTS.md); profiles solve the different problem of role- and
stack-specific assembly inside a project.

### Profile structure

```yaml
# profiles/alice.yaml
profile: { name: "Alice", role: "frontend", verbosity: "concise" }
modules:
  include: [shared/core-rules.md, shared/git-conventions.md, shared/security-baseline.md, frontend/react-patterns.md]
  exclude: [backend/database-rules.md]
overrides: ["Prefer named exports over default exports"]
```

The module library lives in `modules/` (`shared/`, `frontend/`, `backend/`,
`devops/`), version-controlled; profiles live in `profiles/`.

### Assembly script (generic)

```bash
#!/usr/bin/env bash
# scripts/assemble-context.sh <profile> [--check]
set -euo pipefail
PROFILE="$1"; CHECK="${2:-}"
MODULES=$(python3 -c "
import yaml
print('\n'.join(yaml.safe_load(open('profiles/${PROFILE}.yaml'))['modules']['include']))")
ASSEMBLED=$(mktemp)
echo "# Project instructions (generated from profile: $PROFILE)" > "$ASSEMBLED"
while IFS= read -r m; do
  echo "## From: ${m}" >> "$ASSEMBLED"; cat "modules/${m}" >> "$ASSEMBLED"
done <<< "$MODULES"
# then append profile 'overrides' as a final bullet list (same yaml read)

if [[ "$CHECK" == "--check" ]]; then
  diff -q AGENTS.md "$ASSEMBLED" > /dev/null && echo "OK" && exit 0
  echo "DRIFT: AGENTS.md does not match profile $PROFILE"; exit 1
fi
mv "$ASSEMBLED" AGENTS.md
```

Commit the profile, not the generated file (gitignore the output if each
developer assembles their own view). A weekly CI job regenerates and diffs
(`assemble-context.sh <profile> --check`) so nobody runs stale instructions —
a stale security rule is the failure this catches.

The personal-overrides tier duplicates what Vibe's user-level
`~/.vibe/AGENTS.md` does natively (PART-AGENTSMD): preferences that hold across
projects belong there, not in a per-project profile.

---

## 7. The context lifecycle

### Instruction debt

Rules accumulate and are rarely removed. Debt signs: a rule references a
library you dropped six months ago; two rules contradict; the same
constraint appears three times; developers ignore specific rules because
practice moved on. Each dead rule displaces a live one, and models behave
unpredictably under conflicting rules.

Run a quarterly audit as an actual session against your AGENTS.md files:

```text
Review every rule in each AGENTS.md for:
1. Relevance: does this still apply to the current stack and patterns?
2. Specificity: is this actionable, or too vague to enforce?
3. Conflicts: does this contradict another rule, in this file or a parent?
4. Coverage: is this already implied by a more general rule?

For each rule, classify as: KEEP | UPDATE | ARCHIVE | DELETE
```

### The update loop

The common mistake after a bad output is fixing it manually and moving on.
That wastes the signal.

```text
Bad loop:  wrong output -> manual fix -> same wrong output next session
Good loop: wrong output -> find the root cause (missing? vague? conflicting rule?)
        -> update the AGENTS.md -> correct output, permanently
```

Treat every bad output as a bug report against your instruction files. Record
the rationale inline when you add a rule from a failure — future auditors need
it, and the model applies a rule better when the why is stated.

### Knowledge feeding after sprints

End each sprint or release cycle with a short feeding session: new patterns
("we standardized on X for Y — add it"), anti-patterns ("X caused Y — add a
never-rule"), architecture decisions ("X over Y because Z, so the model stops
suggesting Y"), deprecations ("moving from X to Y — flag remaining X usages").

### The ACE pipeline

For automated or semi-automated workflows: **Assemble -> Check -> Execute**.

```bash
#!/usr/bin/env bash
# ace.sh <profile> <task-description>
set -euo pipefail
PROFILE="$1"; TASK="$2"

echo "=== ASSEMBLE ==="; ./scripts/assemble-context.sh "$PROFILE"
echo "=== CHECK ===";    ./scripts/run-canaries.sh
echo "=== EXECUTE ===";  vibe -p "$TASK"
```

`vibe -p` runs programmatic mode: send the prompt, print the response, exit
(PART-CLI). In programmatic mode tool approval follows the selected agent or
`default_agent`; approval-required calls are denied rather than prompted —
canary prompts that expect file writes need the right agent or
`--auto-approve` (PART-CLI). Build canaries accordingly (Section 8).

### Session retrospective

Before closing a session, ask: what patterns did we use that are not in
AGENTS.md? What did I correct that could become a rule? What decisions should
be documented? Generate 3-5 candidate rules, review, and merge the survivors.
This is how instruction files accumulate project knowledge rather than generic
rules.

### Context chaining

Pass a curated summary forward between sessions instead of discarding state:

```text
Session 1: task + AGENTS.md -> research + initial work -> summary.md
Session 2: task + AGENTS.md + summary.md -> implementation -> updated summary.md
Session 3: review, refine -> final artifacts + lessons for AGENTS.md
```

The summary must be curated (200-500 tokens of decisions, validated
approaches, dead ends), never a raw transcript — raw transcripts reintroduce
context rot. Vibe sessions persist under `$VIBE_HOME/logs/session/` as
`meta.json` + `messages.jsonl` and are resumable: `-c` continues the most
recent session reaching the working directory, `--resume <ID>` resumes
globally, partial IDs accepted (PART-SESSIONS section 3). Chaining is for
multi-day tasks where accumulated understanding is an asset; a clean
restart wins when early assumptions proved wrong.

---

## 8. Quality measurement

### Self-evaluation questions

Run quarterly against every AGENTS.md:

- **Relevance**: does the rule still match the current stack? Was it written
  for a problem that no longer exists?
- **Specificity**: could two developers read it differently? Is there at
  least one concrete example?
- **Conflicts**: does it contradict another rule, in this file, a
  subdirectory module, or the user file, without an explicit override note?
- **Coverage**: is it a special case of a more general rule that already
  exists?

A rule failing more than one check is a candidate for update or removal.

### Canary checks

Three to five fixed prompts that verify key conventions. Run them before and
after instruction-file changes to catch regressions:

```bash
#!/usr/bin/env bash
# scripts/run-canaries.sh
PASS=0; FAIL=0
check() {
  local name="$1" prompt="$2" expected="$3"
  result=$(vibe -p "$prompt" --output text 2>/dev/null)
  if echo "$result" | grep -qE "$expected"; then
    echo "PASS: $name"; PASS=$((PASS+1))
  else
    echo "FAIL: $name (expected: $expected)"; FAIL=$((FAIL+1))
  fi
}
check "Named exports" "Create a utility function that formats a date" "^export (function|const)"
check "No any type"   "Write a function that processes user data"      "^((?!: any).)*$"
echo "Canaries: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
```

`vibe -p ... --output text` is the programmatic form with plain-text output
(PART-CLI). Design canaries around read-only or edit-class prompts so
approval semantics do not skew results, or pin the agent explicitly with
`--agent` (PART-CLI).

### Adherence tracking

For each key rule, count violations across 10 consecutive interactions where
the rule should apply:

| Rule | Violations / 10 | Status |
|---|---|---|
| Named exports for utilities | 1/10 | Healthy |
| No raw IDs in API responses | 3/10 | Review wording |
| Structured logging everywhere | 5/10 | Rule too vague |

More than 20 percent violations means one of three things: too vague to
apply, conflicting with another rule, or buried too late in the file. Fix in
that order: add a concrete example and counter-example; resolve the conflict
explicitly; move the rule into the first third.

### Context debt score

```text
Context Debt Score = (total_rules / 150) x (conflicts_found / total_rules) x 100
```

| Score | Status | Action |
|---|---|---|
| < 30 | Healthy | Quarterly audit |
| 30-60 | Degraded | Prune, deduplicate, fix conflicts |
| 60-80 | Poor | Restructure |
| > 80 | Critical | Restart from your top 30 rules |

Count rules with `grep -c "^- " AGENTS.md */AGENTS.md`; conflicts need a
review pass — run it as a session against your own files.

### Drift detection

Canaries and violation counts need a human to notice. Embedding-based drift
detection catches shifts automatically: fix 5-10 probe prompts, capture a
golden baseline, then alert when the cosine distance of new outputs from
baseline crosses ~0.15 (calibrate to your own variance; track per-feature
drift when you need to know *what* changed). Worth it for pipelines; overkill
for interactive work with regular review.

### Metrics over time

| Metric | How to measure | Target |
|---|---|---|
| Always-on instruction size | `wc -c ~/.vibe/AGENTS.md AGENTS.md` | Under ~5,000 words |
| Rule count | `grep -c "^- "` across loaded files | Under 150 |
| File age | `git log --follow AGENTS.md` | Review every 6 months |
| Violation rate per key rule | Spot checks | Under 20 percent |
| Canary pass rate | `./scripts/run-canaries.sh` | 100 percent |

---

## 9. Context reduction techniques

### Path-scoping: the highest-leverage technique

For projects past ~200 lines of configuration:

1. Identify domain boundaries (api, ui, database, tests, infra).
2. Create `AGENTS.md` in each domain directory.
3. Move domain rules out of the root file into them.
4. Keep the root to shared rules and pointers.
5. Verify with canary checks.

In Vibe the loading is native: subdirectory files inject on `read_file`,
scoped to the subtree (PART-AGENTSMD). Target: root file under ~150 lines.

### Negative constraints

Negative constraints ("never do X") outperform positive instructions for
preventing bad patterns — naming the wrong thing and forbidding it is more
salient than describing the right thing.

| Pattern | Formulation | Adherence |
|---|---|---|
| Positive (weaker) | "Use structured logging for all services" | Lower |
| Negative (stronger) | "Never use console.log in services; use the structured logger" | Higher |

Apply wherever the wrong pattern is a common default: raw try/catch,
console.log, default exports, `any` types.

### Rule compression

Before (38 words): "When creating React components, always make sure to use
TypeScript interfaces for props, and define them before the component
declaration, not inline, to improve readability and enable reuse."

After (9 words): "React props: TypeScript interface, declared before
component, never inline."

Shorter rules receive more attention weight per rule. If a rule exceeds one
line, split constraint from explanation; keep the enforced constraint to one
line and move the why to a rationale note.

### Deduplication

Restating a constraint does not reinforce it; it dilutes total attention.
Common sources: a general rule in the root file plus a specific version in a
subdirectory module; a fix added without removing the vague rule it
supersedes; merges from multiple team members' files. Run a session: "list all
duplicate pairs in these files and recommend which version to keep by
specificity."

### The archive pattern

Deleting a rule loses the knowledge of why it existed. Archive instead:

```markdown
## Archived rules

### [Retired 2026-01] Use MongoDB for session storage
Replaced by: PostgreSQL, sessions table.
Reason: standardized on one database; MongoDB served only sessions.
```

The archive is never loaded; it is reference documentation that prevents the
same debate from recurring. Keep it outside any AGENTS.md the harness would
discover (PART-AGENTSMD) — e.g. `docs/context-archive.md`.

### The 80/20 rule for rules

A fifth of your rules drive most consequential decisions. Estimate per rule
how often it meaningfully changes output: daily -> keep, place early; weekly
-> keep, middle; monthly -> consider archive or an on-demand artifact; rarely
-> archive. Protect the rules that matter from dilution by the rules that do
not.

### Think in code

To answer "which files import module X?", do not read 30 files. Write the
query:

```bash
grep -r "import X" src/ --include="*.ts" | wc -l
find src/ -name "*.test.ts" | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn
```

One tool call and ~50 tokens instead of 30 calls and 15,000 tokens of mostly
irrelevant content. Apply to any explore-and-report task: counting, pattern
matching, dependency analysis. For tasks that genuinely need file contents
(edits, review), subagents are the better fit — see
[architecture.md](./architecture.md).

### Graduated context offloading via hooks

[stable]

Long sessions accumulate large tool outputs. Offload them with a `post_tool`
hook: Vibe's hook system has exactly three event types (`pre_tool`,
`post_tool`, `post_agent`); a `post_tool` hook fires after a tool body ran,
receives the full invocation JSON on stdin, and can replace the text the model
will see (PART-HOOKS sections 1-3).

```toml
# <project>/.vibe/hooks.toml — loaded only when the folder is trusted
[[hooks]]
name = "offload-large-output"
type = "post_tool"
match = "bash"
command = "python3 ./.vibe/hooks/offload-large-output.py"
description = "Persist large bash output to a file; keep a preview in context."
```

```python
# ./.vibe/hooks/offload-large-output.py
import json, sys, tempfile

payload = json.load(sys.stdin)
text = payload.get("tool_output_text", "")
THRESHOLD = 20_000  # characters, roughly 5K tokens

if len(text) > THRESHOLD:
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False,
                                     prefix="vibe-output-") as tmp:
        tmp.write(text)
    preview = "\n".join(text.splitlines()[:10])
    print(json.dumps({
        "decision": "deny",
        "reason": (f"[Output saved to {tmp.name}]\n"
                   f"Preview (first 10 lines):\n{preview}\n"
                   f"Use: cat {tmp.name}"),
    }))
# else: empty stdout, exit 0 — passthrough
```

The mechanism: a `post_tool` **deny** replaces `tool_output_text` with `reason`
and the chain continues — here "deny" is output rewriting, not a failure; the
model sees the preview and the path (PART-HOOKS section 3.3).
`additional_context` appends without replacing, if you prefer to keep the
original text. Hooks are fail-open by default: if this script errors or times
out (default 60s), the original output passes through with a warning;
`strict = true` escalates failure to clearing the output instead (PART-HOOKS
sections 2-3). Cap note: hook stdout is capped at 1 MiB — the decision JSON is
tiny, but keep guard scripts quiet.

The same pattern generalizes: MCP results, generated reports, and any bulky
artifact can be persisted to a file and referenced by path, with the hook
deciding what stays resident.

### Summary: reduction techniques by impact

| Technique | Context reduction | Effort | Note |
|---|---|---|---|
| Path-scoping | 40-50 percent of always-on | Medium | Native lazy loading (PART-AGENTSMD) |
| Negative constraints | 0 (reformulation) | Low | Stronger adherence per rule |
| Rule compression | 20-30 percent | Low | One line per constraint |
| Deduplication | 10-20 percent | Low | Removes dilution |
| Archive | 10-30 percent | Low | Preserves institutional memory |
| 80/20 reordering | 0 (reordering) | Low | Early placement wins attention |
| Think in code | 90 percent on exploration | Low | Replaces reads with scripts |
| Hook offloading | Variable | Medium | `post_tool` rewrite (PART-HOOKS) |

Sequence for a project with debt: path-scope, deduplicate, compress, archive,
reorder, then offload for long-running workflows.

---

## 10. Maturity assessment

Most teams reach Level 2 and stop, because Level 2 failures are invisible:
output quality is acceptable, so pressure to go further never appears.

| Level | Name | What exists | Failure mode |
|---|---|---|---|
| 0 | No configuration | No AGENTS.md anywhere | Generic output, zero project awareness |
| 1 | Flat config | One unstructured file | Rules pile up; adherence degrades past ~100 lines |
| 2 | Structured config | Sections; user/project separation | Works solo, breaks at team scale |
| 3 | Modular config | Subdirectory files, deliberate layering | Maintained but never verified |
| 4 | Measured config | Canaries, adherence tracking, audits | Works but drifts silently |
| 5 | Engineered system | Profiles, CI drift detection, ACE, quarterly audits | None identified |

Answer each question and stop at the first "No":

- **0 -> 1**: Is there an `AGENTS.md` in your project?
- **1 -> 2**: Do you separate user-level (`~/.vibe/AGENTS.md`) from project
  rules (root `AGENTS.md`)? Are sections clearly drawn?
- **2 -> 3**: Are subsystem rules in subdirectory files rather than the root?
  Is the root under 150 lines?
- **3 -> 4**: Do canaries verify key conventions? Do you track violation rates
  and audit after milestones?
- **4 -> 5**: Do developers assemble from profiles? Does CI catch drift? Do
  retros feed rules back?

| Your level | Next action |
|---|---|
| 0 | Write a minimal root AGENTS.md with 5-10 rules (Section 3) |
| 1 | Split user and project files |
| 2 | Path-scope your 2-3 highest-traffic subsystems |
| 3 | Write 3-5 canaries for your most-violated rules |
| 4 | Introduce profiles and CI drift detection |
| 5 | Keep the quarterly rhythm; the work is calibration |

Levels 0 to 2 take an afternoon. Level 3 to 4 is a measurement habit, not more
configuration — discipline matters more than knowledge from here up.

---

## 11. Signal taxonomy and causal attribution

A flat friction score (errors x 3 + retries x 2) tells you how much friction
happened, not which configuration caused it. Without typed signals, you fix
the wrong layer.

| Category | Definition | Example |
|---|---|---|
| **syntactic** | Tool error, parse failure, malformed call | Invalid JSON in a tool call |
| **semantic** | Output rejected, retry with clarification | "No, I meant the other format" |
| **procedural** | Rule conflict, missing step, wrong phase | Write-before-read violation |
| **alignment** | Out-of-scope change, hallucinated claim | Unrequested refactoring |
| **performance** | Token overrun, forced mid-task compaction | Session degrading past the 50 percent warning |

Weight by impact, not frequency: one alignment violation in a
production-critical flow outweighs 50 syntactic retries on a local script.

**Causal attribution**: capture the active context per friction event so you
can correlate rules to friction without judging the full session history:

```yaml
id: evt_bash_batching_001
category: procedural
tool: bash
retry_count: 4
description: "Three sequential calls where one batched call would suffice"
active_rules: [AGENTS.md, src/api/AGENTS.md]
suspected_cause: "no batching instruction in root file"
```

Store events as newline-delimited JSON, local and gitignored unless the team
chooses a shared store. Track friction **by pattern** over time
(`bash_no_batching: 47`, `write_before_read: 10`, ...) — the time series is
what proves a merged rule had an effect.

---

## 12. Loop closure: PR-based curation

The hidden failure mode at Level 5 is the open loop: reports pile up, nothing
merges. Close it by making curation output a diff, not a document.

**PR anatomy**: a config diff (patch-ready, not prose); the 3-5 friction
events that motivated it; before/after canary results on 10-20 probes; an
escalation counter if the suggestion appeared in prior reports unmerged. A
human merges or closes. Never auto-merge rules — the loop closes through human
judgment.

**A/B canaries**: run probe prompts against current and proposed
configuration and compare. In Vibe, configuration variants are cheap to
invoke: `VIBE_*` environment overrides apply any config key per invocation
(PART-CONFIG section 2.2), and `--workdir` selects a different working
directory (PART-CLI). Ten to twenty probes per change is sufficient; use
similarity for a first pass and judge only the divergent cases.

**Multi-timescale operation**:

| Loop | Trigger | Action |
|---|---|---|
| Real-time | Each completed turn | Append friction event; a `post_agent` hook can do this — it fires once per turn and receives `session_id`, `transcript_path`, `cwd` on stdin (PART-HOOKS sections 1, 3.2) |
| Weekly | Scheduled job | Aggregate; open a curation PR if signal threshold is met |
| Quarterly | Manual | Constitutional audit: overlap, dormant rules, profile consolidation |

The quarterly loop is not automatable usefully: it requires reading the
system's actual behavior, not its logs.

**Signal locality**: local scheduling for solo developers; a pushed,
anonymized signal store (private repo, not a third-party SaaS) for teams
needing cross-developer analysis; a shared hosted environment only if you
already run one.

**Suggestion suppression**: a suggestion appearing in three consecutive
reports without action changes state — pending human decision with a blocking
flag, or closed as won't-fix with a reason. Silent repetition is the open
loop wearing a disguise.

---

## 13. Ejection: disciplined de-engineering

Everything in this system helps you add. Nothing helps you remove, which is
why Level 5 systems silently degrade. A rule written for a sprint six months
ago can conflict with three newer rules and fire on edge cases nobody
anticipated; without an ejection path it stays forever, because removing feels
risky and auditing takes time nobody has.

**Ejection heuristics**:

- **Activation threshold**: rules that have not fired in a representative
  window are *candidates*, not proven dead weight — absence can mean dormancy,
  successful prevention, or missing telemetry. Define the window from your own
  task frequency.
- **ROI tracking**: a rule whose enforcement friction exceeds the friction it
  prevents is a candidate. The signal: it appears in friction events more often
  than in resolved ones, over 4+ weeks.
- **Profile overlap**: a rule in more than 80 percent of individual profiles
  belongs in the shared root file — a consolidation proposal, not an ejection.

**Ejection vs. archive**: ejection is candidate detection, never automatic
removal. A human makes the call; the rule moves to the archive with date and
reason (Section 9). The discipline commercial observability tooling skips is
exactly this: tracking what your *configuration* contains and proposing to
remove the parts causing harm.

---

## 14. Constitutional and self-consistency audits

A config that grows without constraint eventually contradicts itself: rule A
says "always use ESLint for formatting", rule B says "prefer Biome for speed".
A new reader follows neither, and nothing signals the conflict.

**Constitutional audit**: check each proposed rule change against an explicit
invariant list:

```yaml
# constitution.yaml (example)
invariants:
  - id: no-auto-commit
    rule: "Never commit without explicit user request"
    rationale: "Automated commit once bypassed a review gate"
  - id: diff-before-multi-file-change
    rule: "State the plan before multi-file edits"
    rationale: "Preserves human review in the loop"
```

Two checks per change: contradiction with any invariant, and conflict with any
existing rule in the loaded files. Both run as short sessions with the
constitution and rule inventory as context — a few hundred tokens per curation
run.

**Self-consistency check**: systems that describe their own state accumulate
documentation rot — the doc claims a state that no longer matches reality. Run
weekly, separate from curation:

| Claim | Verification |
|---|---|
| "N rules active" | `grep -c "^- " AGENTS.md */AGENTS.md` |
| "Last curation: date" | Most recent curation PR in git log |
| "Friction trending down" | 4-week moving average from the signal store |

When a claim diverges from measured state by more than 10 percent, append a
violations section to the next report. Documentation rot is normal; catching
it weekly is not.

---

## 15. Multi-dev profile reconciliation

Profile-based assembly gives each developer a personal profile; over time,
profiles diverge. Alice adds a rule preventing direct production database
access; Bob adds the same rule worded differently two weeks later; Carol
never adds it. The rule that belongs in the shared root ends up duplicated,
inconsistent, and unenforceable.

**Detection**: scan active profiles for rules appearing in more than half of
them:

```bash
#!/usr/bin/env bash
# profile-reconcile.sh [profiles-dir] [threshold]
PROFILES_DIR="${1:-profiles}"; THRESHOLD="${2:-0.5}"
total=$(find "$PROFILES_DIR" -name "*.yaml" | wc -l)
find "$PROFILES_DIR" -name "*.yaml" -exec yq '.overrides[]' {} \; \
  | sort | uniq -c | sort -rn \
  | awk -v t="$total" -v th="$THRESHOLD" '$1/t >= th {print "HOIST CANDIDATE ("$1"/"t"): "$2}'
```

A rule in 4 of 5 profiles belongs in the root `AGENTS.md`, not in four
profiles. Remember the resolution order when hoisting: project beats user, and
within project files the closer directory wins (PART-AGENTSMD).

**Preservation**: never hoist preferences. Behavioral rules (what the model
does) are hoist candidates; preference rules (how the model communicates —
tone, verbosity, language) stay personal. Vibe additionally gives every
developer a private user-level file (`~/.vibe/AGENTS.md`) that never enters
the repository (PART-AGENTSMD) — the natural home for exactly those rules.
Run the check monthly for 5+ developers, quarterly for 10+; output is a hoist
list with a proposed diff; a human applies it.

---

## 16. Token audit workflow

Theory converts to gains only when you measure actual overhead. Most
projects discover they carry thousands of tokens of fixed context before any
user task begins: user AGENTS.md, the project chain, hook output, MCP tool
definitions, and the system prompt all compound. Five minutes of auditing
produces an actionable plan.

### Step 1: measure the components

```bash
echo "=== USER ==="          && wc -c ~/.vibe/AGENTS.md
echo "=== PROJECT CHAIN ===" && find .. -maxdepth 2 -name AGENTS.md -exec wc -c {} +
echo "=== SUBDIR (lazy) ===" && find . -mindepth 2 -name AGENTS.md -exec wc -c {} +
```

The project chain runs from your project root up to the trust root — every
level in that walk is loaded at session start (PART-AGENTSMD). Subdirectory
files below the root are lazy: they cost nothing until a task reads a file
under them, so their size is a per-scope cost, not an always-on one.

### Step 2: calculate the budget

Sum the always-on components (user file + project chain) and divide by 4. Set
the number against your own `auto_compact_threshold` (default 200,000,
per-model overridable — PART-SESSIONS section 4.1): a 60K fixed overhead is
30 percent of the default threshold consumed before work begins.

### Step 3: classify by usage frequency

| Class | Definition | Action |
|---|---|---|
| Always critical | Applies to every task | Keep in root / user files |
| Sometimes | 20-40 percent of sessions | Keep if small; move to a subdirectory scope if large |
| Rarely | Under 10 percent | Move to an on-demand artifact |
| Never | Outdated or covered elsewhere | Delete or archive |

### Step 4: audit hook overhead

`post_tool` hooks run on every matching call, and their `additional_context`
or replacement text enters context each time. A hook appending 500 characters
across 150 calls per session adds roughly 19K tokens of context. List your
hooks and estimate per-call stdout by running each manually:

```bash
cat .vibe/hooks.toml ~/.vibe/hooks.toml 2>/dev/null | grep -E 'name|type|match'
```

Hook files load project-first (trusted only), then any `--add-dir` roots, then
the user file; duplicate names lose to the project entry (PART-HOOKS
section 1). High-overhead patterns: unconditional `git status` or `cat` on
every call, debug echoes never removed, multi-line summaries on tools called
hundreds of times.

### Step 5: action plan

| Action | Effort | Typical savings |
|---|---|---|
| Path-scope rarely-shared rules | 1-2h | 5-20K tokens always-on |
| Split large files into core + detail | 1-2h | 3-8K tokens |
| Trim hook stdout to essentials | 1h | 2-10K tokens |
| Compress verbose rules | 1-2h | 2-5K tokens |
| Archive dead rules | 30min | 1-2K tokens |

A first pass typically halves fixed context without infrastructure.

### The RAG question

Moving instruction files into a vector store with dynamic retrieval is a
valid optimization at scale, but check the math honestly: measure first
(Steps 1-3); a vector-database setup with a custom MCP server is a 1-2 week
project; if fixed context is already under 20K tokens after cleanup,
retrieval adds complexity for marginal gain. Vibe's lazy subdirectory loading
(PART-AGENTSMD) already gives you path-based lazy loading for free —
classification by directory achieves most of the benefit at none of the
infrastructure cost.

### Audit prompt template

Run this inside a project to produce a complete audit:

```text
Audit this project's context configuration for token overhead.

Step 1 — Inventory: every AGENTS.md loaded at session start (user file,
project chain up to the trust root) with line counts and approximate tokens
(chars/4), plus subdirectory files that load lazily.
Step 2 — Budget: total always-on tokens before any user task, broken down
by component, as a percentage of auto_compact_threshold.
Step 3 — Classification: ALWAYS / SOMETIMES / RARELY per file; flag any
RARELY file over 5K chars.
Step 4 — Hook audit: read .vibe/hooks.toml and ~/.vibe/hooks.toml; for each
hook: type, match, estimated stdout per invocation, per-tool-call or per-turn.
Step 5 — Plan: a prioritized table | Action | Savings | Effort | Risk |,
achievable without new infrastructure.
```

---

## 17. Attention mechanics and research patterns

### Lost in the middle

Retrieval and reasoning accuracy follow a U-shaped curve over position:
information at the start or end of a long context is recalled reliably;
information in the middle is not (Liu et al., "Lost in the Middle: How
Language Models Use Long Contexts"). The effect persists across model
generations. Implications:

- Put decision-critical rules at the top of each AGENTS.md, not the middle.
- When summarizing multiple sources, lead with the most relevant finding.
- First and last tool results in a batch are recalled more reliably than
  middle ones; split long evaluations into smaller batches.

Position within the window is a design variable, not an accident.

### The sandwich pattern

For long documents, place critical facts at both ends:

```text
[Critical facts block]
[Long document]
[Restate the task + critical facts]
```

Restating facts at the end is not redundancy; it compensates for the
middle-zone attention drop on the primary content. For very long documents,
analyze section by section and run an integration pass over the section
summaries — every pass stays within high-attention range.

### Progressive summarization risks

Summaries of summaries lose information invisibly: specifics (numbers, dates,
conditions) vanish first while narrative structure survives, and the model's
confidence does not drop with the loss — it answers fluently from compressed
patterns. Mitigations, as rules for summarization work:

```markdown
## Summarization rules
- Always retain exact numbers, dates, and proper nouns — never paraphrase them
- Mark summaries with their compression level
- If a specific fact is not in the summary you have, say so — do not reconstruct
  it from plausible inference
```

Limit chains to about two compression passes before returning to source
material. Vibe's compaction is a single-pass, prompt-controlled summary
(PART-SESSIONS section 4.2); custom `compaction_prompt_id` files are where
rules like these belong when compaction quality matters to your workflow.

### Stratified sampling for calibration

Random sampling hides systematic failures. Strata that matter for context
engineering:

| Stratum | Why it matters |
|---|---|
| Short context (under 5K tokens) | Baseline; should be near-perfect |
| Medium (5K-50K) | Where most real work happens |
| Long (50K+) | Where degradation first appears |
| Position-critical (key info in middle) | Tests lost-in-the-middle directly |
| High instruction density | Tests the rule ceiling |

A 20-point gap between strata is a signal aggregate accuracy would hide.

### Claim-source mapping

In agents synthesizing from multiple sources, keep claims traceable: tag
each claim with its source (tool name, file path, URL, or "inferred") and
flag inferred claims as uncertain in the output. Provenance is the difference
between synthesis and confident confabulation, and it survives compression
passes if the tags travel with the claims.

### Chain of thought is compute

A model's reasoning is operationally the intermediate tokens between input
and output. A transformer allowed to reason before answering can solve any
problem solvable by a Boolean circuit of constant depth (Zhou, Google
DeepMind) — token budget spent on reasoning is compute budget, not
commentary. This is why thinking levels exist as model configuration, and why
offloading *content* to files while keeping *reasoning* in context is the
right split.

### Persistent facts and the scratchpad

**Persistent facts**: a small block of must-reference facts at the top of the
system prompt or root AGENTS.md, always in the primacy position. Keep it
under ~500 tokens; past that it starts falling into its own middle zone.

**Scratchpad**: a working-state file the agent reads and rewrites across a
long task, instead of accumulating state in conversation history. In Vibe
the scratchpad is a first-class mechanic: the session scratchpad directory is
always writable — file-tool permission resolution returns an unconditional
ALLOW for scratchpad paths, before any denylist is even consulted
(PART-PERMISSIONS section 4.3). Bash guardrails exempt scratchpad paths from
outside-directory checks for the same reason (PART-PERMISSIONS section 4.4).
Working notes live in the file's start (primacy position), are
programmatically rewritable, and cost one read instead of N turns of history.

**Rolling summaries**: when accumulated history is unstructured conversation,
compress completed phases before they drift into the middle zone. Vibe does
this automatically at `auto_compact_threshold` with a single 50-percent
warning beforehand (PART-SESSIONS section 4) — for manual control, run
`/compact` with instructions at the warning rather than waiting for the
trigger, and configure a dedicated `compaction_model` if summarization
quality matters (PART-SESSIONS section 4.3).

---

## Known gaps

Items the oracle could not verify from public sources. None of these are
stated as fact above.

- **Model context window sizes** are model specs, not harness mechanics; the
  oracle carries none, and this page states no numbers. `auto_compact_threshold`
  is a config-driven compaction trigger only.
- **System prompt size** and any per-turn context-budget breakdown are not
  published in the oracle; the audit workflow measures instruction files only.
- **Mistral API prompt-caching semantics and pricing** (cache-hit behavior,
  TTL, cost) are not in the oracle — no cache-stability or caching-cost claims
  are made. The oracle notes only that the `cached_input_price` model field
  bills cache hits at the input price when unset (PART-CONFIG section 1.1).
- **The context-warning middleware's config gating**: the middleware and its
  50-percent threshold are verified (PART-SESSIONS section 4.1), but the
  oracle lists the relationship between the `context_warnings` config flag
  and the middleware as unconfirmed. The behavior is stated; the flag is not.
- **Admin layer endpoint and wire format** (layer 8 of the config stack) are
  unverified; the layer's existence is sourced, its transport is not
  (PART-CONFIG section 2.1).
- **Whether `.vibe/config.toml` in an `--add-dir` root (not the working
  directory) is loaded** is unverified; hooks from `--add-dir` roots are
  verified (PART-HOOKS section 1), config is not (oracle, Needs public
  verification).
- **Compression tooling equivalents** (CLI-output proxies, AST-based read
  filters) from third-party ecosystems have no Vibe-verified equivalent in
  the oracle; the hooks-based offloading pattern in Section 9 covers the
  tool-output tier only. Session-level token benchmarks (per-task and
  per-session ranges) are other-product measurements and were not ported.
- **Rule-count and adherence figures** (attention decay by position in an
  instruction file, negative-constraint advantage) are practitioner
  observations from the source guide, presented as heuristics; they are not
  measurements of Vibe or of any specific model.

## See also

- [architecture.md](./architecture.md) — how the harness, loop, and
  compaction fit together.
- [memory-systems.md](./memory-systems.md) — durable memory beyond
  instruction files, and instruction-poisoning risk.
- [agent-harness.md](./agent-harness.md) — the model-harness pair as the unit
  of evaluation.
- [loop-graph-engineering.md](./loop-graph-engineering.md) — loop contracts
  and judgment allocation for long-running work.
- [methodologies.md](./methodologies.md) — spec-first methodologies that pair
  with curated context.
- [glossary.md](./glossary.md) — term definitions.
- Mechanics: [verified-mechanics.md](../../docs/mechanics/verified-mechanics.md)

See also: the [config.toml key reference](settings-reference.md), the [hooks
reference](hooks-events-reference.md), the [tools reference](tools-reference.md),
the [workflows pages](../workflows/README.md), and the [learning
path](../learning-path/README.md).
