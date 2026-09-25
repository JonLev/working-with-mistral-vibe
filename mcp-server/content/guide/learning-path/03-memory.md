---
title: "Module 03 — Memory and Config"
description: "Learning-path module 03 (Beginner track): durable instructions in Vibe — the AGENTS.md hierarchy and the trust gate, config.toml and its eight-layer stack, model and compaction keys, and full system-prompt replacement, with five hands-on exercises"
tags: [learning-path, memory, agents-md, config, trust, exercises]
---

# Module 03 — Memory and Config

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics on this page are cited inline as (PART-XXX) against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md). Anything the
oracle could not verify is in [Known gaps](#known-gaps), never in the body.
Structure and pedagogy are adapted from the source guide; every mechanic is
rebuilt from the oracle. Every mechanic on this page is backend **[stable]**.

**Time:** ~60 min · **Complexity:** ★★☆☆☆ · **Track:** Beginner — the first
module that changes how every later session behaves.

## TL;DR

- Vibe has no memory subsystem to switch on and nothing to configure into
  existence. Durable instructions are files you write by hand: `AGENTS.md`
  files injected into the system prompt, plus `config.toml` layers that
  resolve every setting (PART-AGENTSMD; PART-CONFIG).
- The instruction hierarchy has three scopes: user (`~/.vibe/AGENTS.md`,
  always loaded), project (an `AGENTS.md` at the project root and at every
  directory from each open project root up to its trust root, loaded only
  when the root is trusted), and subdirectory (injected lazily on the first
  `read_file` below it). Project beats user; closer project files beat
  distant ones (PART-AGENTSMD).
- Trust is the gate, not the location: an untrusted root contributes no
  `AGENTS.md` and no project `.vibe/config.toml`, while user-level files
  always load (PART-TRUST).
- Config resolves through eight layers: defaults < GrowthBook < user TOML <
  project TOML < `VIBE_*` env < session overrides < agent profile < admin
  (PART-CONFIG §2.1).
- Write `AGENTS.md` by hand and keep it minimal. The effectiveness study
  (arXiv 2602.11988) measured roughly +4% average task improvement for
  hand-written context files, while init-style auto-generation hurt 5 of 8
  evaluated settings at roughly +20% cost. This guide takes the study's side
  against auto-generation.

*Read if you want the agent to follow your rules and preferences without
repeating them each session. Skip if you already maintain an `AGENTS.md` —
go straight to the [Settings reference](../core/settings-reference.md) for
the full key catalog.*

## Goal

Make Vibe follow your rules and preferences across sessions. By the end you
will have a hand-written project `AGENTS.md`, a user-level `~/.vibe/AGENTS.md`
entry, a pinned model in `~/.vibe/config.toml`, and a working answer to "which
file wins?"

## What You'll Learn

- How the `AGENTS.md` instruction hierarchy works, and which file wins a conflict
- What the evidence says makes an `AGENTS.md` effective, and what makes one harmful
- Why trust decides whether project instructions load at all
- How `config.toml` resolves through eight layers, and where model and compaction keys live
- How to replace the system prompt entirely — and why you usually should not

## 1. The instruction hierarchy

Vibe's durable "memory" is instruction files, injected into the system prompt
at session start. There are exactly three scopes (PART-AGENTSMD):

| Scope | File | Loaded when | Typical content |
|---|---|---|---|
| User | `~/.vibe/AGENTS.md` | every session | personal defaults: reply format, tooling preferences, timezone |
| Project | `AGENTS.md` at the project root, plus every `AGENTS.md` walked up from each open project root to its trust root (inclusive) | when the root is trusted and `include_project_context` is on (default on) | team standards, stack, security rules, current status |
| Subdirectory | `AGENTS.md` in subdirectories of an open root | lazily, on the first `read_file` of a file below them | scope-local rules, e.g. for `docs/` or `scripts/` |

Priority, from the prompt text Vibe itself injects: project instructions take
priority over user instructions; among project files, instructions closer to
the working directory take priority; each `AGENTS.md` applies to its own
directory and all of its descendants within the project. User instructions
arrive as "User instructions — Contents of ~/.vibe/AGENTS.md", project files as
"Project instructions (checked into the codebase)" (PART-AGENTSMD).

### What Vibe does not have

There is no `MEMORY.md`, no auto-memory directory, and no separately
auto-loaded rules file. Vibe does not extract preferences from your sessions
and write them anywhere (PART-AGENTSMD; the absence is anchored to the 2.25.0
live baseline plus the 2.25.8 documented surface — see
[Known gaps](#known-gaps)). Sessions do persist as transcripts you can resume,
but that is conversational history, not knowledge; full coverage in
[Memory systems](../core/memory-systems.md).

If you learned a three-level pyramid elsewhere (global / project /
personal-local), drop it. Vibe's levels are: user → project (walked up to the
trust root) → subdirectory scope. There is no separate personal-local override
layer: the committed-vs-personal split is a committed `AGENTS.md` and project
`.vibe/config.toml` versus your own `~/.vibe/` files — and the gate between
them is trust, not `.gitignore` (PART-AGENTSMD; PART-TRUST).

## 2. Write it by hand: the evidence

The source guide this path adapts from recommends generating your context
file with an init-style command. The measured evidence says otherwise. An
AGENTS.md effectiveness study (arXiv 2602.11988) evaluated hand-written and
auto-generated context files across coding-agent settings and found:

| The study's DOs | The study's DON'Ts |
|---|---|
| Write the file by hand — roughly +4% average task improvement | Auto-generate it with an init-style command — hurt 5 of 8 evaluated settings, at roughly +20% cost |
| Keep it minimal | Include codebase overviews or directory trees |
| Specify tooling and commands ("run `pnpm test` before claiming done") | Duplicate information the agent can find elsewhere in the repo |
| Use it for security and style rules | Delegate writing to a stronger model — stronger models did not write better context files |

Numbers are the study's findings on its evaluated settings, not measurements
of Vibe. The direction is clear, and this guide takes the study's side: write
the file yourself. Vibe's documented surface makes the decision easy anyway —
the complete command list contains no `AGENTS.md` generator, so hand-writing
is also the only option (PART-COMMANDS).

### Section taxonomy that earns its tokens

Five sections cover what the study found useful. Each carries only information
not available elsewhere in the repo:

```markdown
# checkout-service

## Purpose
Payment processing backend: card validation and transaction logging.
Security-critical — never log card numbers; the on-call owner reviews
changes here before merge.

## Stack
- TypeScript on Node.js (Express)
- PostgreSQL; migrations via `pnpm db:migrate`
- pnpm is the only package manager — never use npm or yarn

## Standards
- All exports must be typed
- Tests are required for new features: `pnpm test`
- No debug logging in production code

## Rules
- Ask before cross-file refactors

## Current Status
Building the checkout flow; active work in `src/checkout/`.
```

`Purpose` carries the security rules the study endorses. `Stack` and
`Standards` name the commands the agent should run. `Rules` is behavioral.
`Current Status` is the one section you update as you go — it is how a fresh
session starts knowing what you are doing without being told.

### The user-level file

For preferences that apply to every project, edit `~/.vibe/AGENTS.md`:

```markdown
# My defaults

## Communication
- Be direct and factual; show working in steps
- Suggest alternatives when a request is ambiguous

## Tooling
- TypeScript for new JS projects; Python for scripts
- Timezone: America/New_York
```

Both files load together; on a conflict, the project file wins
(PART-AGENTSMD).

## 3. Trust: the gate in front of project instructions

Project instructions and project config are only read from trusted roots. On
first entry into an untrusted directory that contains a trustable file — an
`AGENTS.md` at or above the working directory (within the git repo), or a
local config dir (`.vibe/` with `config.toml`, `prompts/`, `tools/`,
`skills/`, `plugins/`, `agents/`, or `.agents/skills/`) — interactive Vibe
offers the workspace trust prompt (PART-TRUST §3.2):

| Decision | Effect |
|---|---|
| Trust the repo root | persists the git repo root into `trusted` in `~/.vibe/trusted_folders.toml` (offered when a `.git/HEAD` ancestor exists) |
| Trust this directory | persists the working directory into `trusted` |
| Trust for this session | in-memory only; never persisted |
| Decline | persists the directory into `untrusted`; the session runs with project config ignored |

Decisions persist in `~/.vibe/trusted_folders.toml`; the closest trusted or
untrusted ancestor of a path decides, and undecided paths are treated as
untrusted (PART-TRUST §3.1). From an untrusted root, Vibe loads no project
`.vibe/config.toml`, nothing from `.vibe/{tools,skills,plugins,agents,prompts}`
or `.agents/skills`, and no repo `AGENTS.md` — while your `~/.vibe/` files
always load (PART-TRUST §3.5). `--trust` grants trust for one invocation only
and skips the prompt; `--add-dir` paths join the workspace with the same
session-only trust (PART-TRUST §3.3; PART-CLI).

The blast radius is concrete: a checked-in `AGENTS.md` is injected into every
trusted session in the repo, so anyone who can write to the branch writes
instructions every contributor's agent will follow. Keep secrets out of it;
API keys are read from the environment, never stored in config
(PART-CONFIG §2.2).

## 4. config.toml and the layer stack

Vibe config is TOML, resolved through eight layers. Highest number wins
(PART-CONFIG §2.1):

| # | Layer | Read from | Applies |
|---|---|---|---|
| 1 | defaults | schema defaults | always |
| 2 | GrowthBook | experiment-mapped values | when an experiment routes a value |
| 3 | user TOML | `~/.vibe/config.toml` | always — always trusted |
| 4 | project TOML | `.vibe/config.toml`, discovered walking up from the working directory | only when the file's parent directory is trusted |
| 5 | environment | `VIBE_*` variables | when set, per run |
| 6 | session overrides | CLI/session options, e.g. `--enabled-tools` | per session |
| 7 | agent profile | the active agent's overrides | per agent |
| 8 | admin | org-enforced config | fetched at session start |

Scalar keys replace; list keys such as `skill_paths` append; `[[providers]]`
and `[[mcp_servers]]` union by name (PART-CONFIG §2.1). Every schema key is
overridable per run as `VIBE_<KEY>`, nested keys as
`VIBE_SECTION__KEY` (PART-CONFIG §2.2):

```bash
VIBE_ACTIVE_MODEL=devstral vibe -p "hi"
VIBE_TOOLS__BASH__PERMISSION=always vibe
```

Implicit writes — "approve permanently" answers, `/config` edits, migrations —
persist to the user layer by default, and only fall back to a trusted project
layer when no user file exists: "User config wins by default: a project config
discovered by walking up parents is rarely the scope the user meant in a
monorepo" (PART-CONFIG §2.3).

### Key mapping from the source guide

The source's JSON settings keys map to `config.toml` like this. Two of them
map to nothing — they do not exist in Vibe's schema (PART-CONFIG §1.10):

| Source key | Vibe equivalent | Notes |
|---|---|---|
| `model` | `active_model` plus a `[[models]]` entry | `active_model` resolves through an alias; `temperature` (float), `thinking` (`"off"`/`"low"`/`"medium"`/`"high"`, default `"off"`), and a per-model `auto_compact_threshold` live on the `[[models]]` entry (PART-CONFIG §1.1) |
| `context_threshold` | `auto_compact_threshold` | an int token count, not a ratio; global default `200000`; a per-model value wins (PART-CONFIG §1.1) |
| `auto_compact` | none | the verified key list has no compaction on/off switch — only the threshold, plus `/compact` to compact on demand (PART-CONFIG §1.1, §1.10; PART-COMMANDS) |
| `require_diff_review` | none | no such config key exists (PART-CONFIG §1.10) |
| `max_file_size` | none | no such config key exists (PART-CONFIG §1.10) |

A user-level config that pins the model and its compaction budget:

```toml
# ~/.vibe/config.toml
active_model = "mistral-medium-3-5"

[[models]]
name = "mistral-vibe-cli-latest"
provider = "mistral"
alias = "mistral-medium-3-5"
temperature = 0.2
thinking = "high"
auto_compact_threshold = 200000
```

These values mirror the builtin defaults — default active model
`mistral-vibe-cli-latest` with alias `mistral-medium-3-5`, thinking `"high"`,
temperature `1.0` — made explicit and adjusted (PART-CONFIG §1.1). If you
need a different threshold for one model only, set
`auto_compact_threshold` on that `[[models]]` entry; models without their own
value follow the global key (PART-CONFIG §1.1). The full key catalog —
providers, tools, MCP, agents, telemetry — is in the
[Settings reference](../core/settings-reference.md).

## 5. Replacing the system prompt entirely

One Vibe mechanic the source guide has no counterpart for: a file in
`~/.vibe/prompts/` selected by `system_prompt_id` (default `"cli"`) entirely
replaces the default system prompt — not a supplement, a replacement. Put
`my-prompt.md` in that directory and set `system_prompt_id = "my-prompt"`
(the filename minus `.md`) to switch to it; `compaction_prompt_id` (default
`"compact"`) swaps only the compaction prompt from the same directory
(PART-AGENTSMD; PART-CONFIG §1.10).

Full replacement drops everything the default prompt teaches the model about
tools and behavior, including the `AGENTS.md` injection scaffolding you rely
on. On the Beginner track, treat it as a power move: put rules in `AGENTS.md`,
which is additive, and reach for prompt replacement only when you want a
genuinely different operating persona.

## Exercises

### Exercise 1 — Your first project AGENTS.md

```bash
mkdir -p ~/labs/vibe-mem-lab && cd ~/labs/vibe-mem-lab
git init
cat > AGENTS.md << 'EOF'
# vibe-mem-lab

## Purpose
Scratch repository for learning how Vibe loads instructions.

## Standards
- All functions must have type signatures

## Rules
- Every reply in this repository must end with the line: lab rules loaded
EOF
vibe
```

Expected:

- Vibe offers the workspace trust prompt: the directory is not trusted and
  now contains a trustable file (an `AGENTS.md` at the working directory;
  a `.vibe/` config dir would also qualify), and `git init` gives it a repo
  root to offer (PART-TRUST §3.2).
- Trust the repo root, then ask: *"Add a `greet` function to `hello.ts` that
  returns `Hello, World!`."* The reply follows both `AGENTS.md` rules.
- Edit `AGENTS.md` mid-session (add a rule), run `/reload` — "Reload
  configuration, agent instructions, and skills from disk" — and ask again;
  the new rule applies without a restart (PART-COMMANDS).

A reply in the right shape, illustrative rather than a transcript:

```text
Adding greet() to hello.ts, typed per the repository rules.

export function greet(): string {
  return "Hello, World!";
}

One file changed. The signature is explicit because AGENTS.md requires it.

lab rules loaded
```

### Exercise 2 — User-level instructions

```bash
cat >> ~/.vibe/AGENTS.md << 'EOF'

## Reply format
- Begin every reply with the word: LAB
EOF
mkdir -p ~/labs/scratch && cd ~/labs/scratch
vibe --trust -p "Reply with one sentence: what format rules were you given?"
```

Expected: the reply begins with `LAB`. The scratch directory has no
`AGENTS.md`, so the only instruction source is the user file, which loads in
every session regardless of trust; `--trust` grants session trust for the
directory and skips the interactive prompt (PART-AGENTSMD; PART-TRUST §3.3,
§3.5). Then delete the block from `~/.vibe/AGENTS.md` — the rule now applies
to every session on the machine, which is the point and the hazard.

### Exercise 3 — Which file wins

```bash
cd ~/labs/vibe-mem-lab
cat >> AGENTS.md << 'EOF'

## Reply format
- Begin every reply with the word: PROJECT
EOF
vibe --trust -p "Reply with one sentence: which format rule applies here?"
```

Expected: the reply begins with `PROJECT`, not `LAB` from Exercise 2 —
project instructions take priority over user instructions (PART-AGENTSMD).
If the user-level rule from Exercise 2 is gone, redo Exercise 2 first so the
conflict is real.

### Exercise 4 — Watch the trust gate close

```bash
mkdir -p ~/labs/untrusted-check && cd ~/labs/untrusted-check
cat > AGENTS.md << 'EOF'
# Rules
- Every reply must mention: hidden rule
EOF
vibe -p "In one sentence: what rules apply in this directory?"
```

Expected: this warning on stderr, verbatim in shape, and a reply that does
not mention the hidden rule — the repo `AGENTS.md` is not loaded from an
untrusted root, and programmatic mode never prompts (PART-TRUST §3.4, §3.5):

```text
Warning: <cwd> is not trusted; project configuration (<files>) will be ignored.
Re-run with --trust to trust this folder temporarily.
```

If no warning appears, a parent of the directory is already trusted — pick a
fresh path; the closest trusted or untrusted ancestor decides (PART-TRUST
§3.1). Re-run with `--trust` prepended and the hidden rule appears in the
reply: session trust is granted, nothing is persisted (PART-TRUST §3.3).

### Exercise 5 — Pin the model in config.toml

If `~/.vibe/config.toml` already exists, merge these keys into it instead of
overwriting — an existing file may carry `[tools.*]` state and is rewritten
in place by config migrations (PART-CONFIG §1.3, §1.11). Otherwise:

```bash
mkdir -p ~/.vibe
cat > ~/.vibe/config.toml << 'EOF'
active_model = "mistral-medium-3-5"

[[models]]
name = "mistral-vibe-cli-latest"
provider = "mistral"
alias = "mistral-medium-3-5"
temperature = 0.2
thinking = "high"
auto_compact_threshold = 200000
EOF
cd ~/labs/vibe-mem-lab && vibe
```

In the session, run `/model` ("Select active model"). Expected: the picker
opens with `mistral-medium-3-5` selected — the alias your `active_model`
resolved to; the first user message pins that resolved alias into the session
(PART-COMMANDS; PART-SESSIONS §3.5). Run `/config` to see where edits land:
the user layer by default (PART-CONFIG §2.3). Any of it yields to the
environment layer for a single run, e.g.
`VIBE_ACTIVE_MODEL=... vibe` outranks both TOML files (PART-CONFIG §2.1–2.2).

Cleanup for all exercises: remove the `LAB` block from `~/.vibe/AGENTS.md`,
revert or delete the lab directories, and optionally remove their entries
from the `trusted` array in `~/.vibe/trusted_folders.toml` (PART-TRUST §3.1).

## DO / DON'T

| DO | DON'T |
|---|---|
| Write `AGENTS.md` by hand — roughly +4% average task improvement (arXiv 2602.11988) | Auto-generate it — an init-style generator hurt 5 of 8 evaluated settings at roughly +20% cost (arXiv 2602.11988) |
| Keep it minimal; carry only information not found elsewhere in the repo | Paste codebase overviews or directory trees (arXiv 2602.11988) |
| Specify tooling and commands the agent should run | Duplicate docs the agent can read anyway |
| Use it for security and style rules | Store secrets in a file injected into every trusted session |
| Commit the project `AGENTS.md`; it is team infrastructure | Run conflicting rules in user and project files |
| Keep `Current Status` current as work moves | Assume Vibe remembers preferences across sessions — durable memory is files, not transcripts |

## Validation: You're Ready If

- You created a project `AGENTS.md`, saw the trust prompt, and watched the agent follow a rule out of it.
- You can name the three scopes — user, project, subdirectory — and say which wins a conflict: project over user, closer project files over distant ones (PART-AGENTSMD).
- You can explain why an untrusted directory's `AGENTS.md` was ignored, and what `--trust` changes (PART-TRUST).
- You pinned a model with `temperature`, `thinking`, and a per-model `auto_compact_threshold` in `~/.vibe/config.toml` and saw the alias in `/model`.
- You know what Vibe does not have: no auto-extracted memory, no memory directory, no init-style generator (PART-AGENTSMD; PART-COMMANDS).

The next module covers agents: the profiles that override config (layer 7),
custom agent TOML, and subagents — [Agents and skills
reference](../core/agents-and-skills-reference.md) is the full-depth companion.

## Known gaps

- **Live-run note (2026-09-24, vibe 2.25.7):** in Exercise 4 the untrusted
  warning fires verbatim and the project `AGENTS.md` is not injected as
  instructions — but when asked "what rules apply here", the agent may
  still open the directory's `AGENTS.md` as an ordinary file and quote it.
  The trust gate verified here is instruction injection, not file
  readability; expect the warning plus instruction-following to differ, and
  prefer a rule-following prompt (Exercise 1/3 style) over a
  rule-discovery prompt when demonstrating the gate (PART-TRUST
  sections 3.3-3.5).

- **No loading confirmation is verified.** The oracle verifies that
  `AGENTS.md` content is injected into the prompt, but no startup message or
  UI indicator confirming the load is verified for 2.25.8. The exercises
  therefore verify loading by behavior — the agent follows the rule — not by
  a banner.
- **Study figures are external.** The +4%, 5-of-8, and +20% numbers are the
  findings of arXiv 2602.11988 on its evaluated coding-agent settings. They
  are directional evidence for hand-writing context files, not a Vibe
  benchmark.
- **No verified size limit.** The oracle documents no token cap or truncation
  behavior for oversized `AGENTS.md` files. "Keep it minimal" is the study's
  guidance, not a Vibe limit.
- **Subdirectory injection triggers.** Lazy injection is documented on
  `read_file`; whether other file-reading tools trigger it is not verified
  (PART-AGENTSMD).
- **Absence of auto-memory is anchored, not guaranteed.** No
  auto-memory feature appears in the 2.25.0 live baseline or the 2.25.8
  documented surface; a future release could add one this page does not
  predict.
- The source guide's community-tools appendix (third-party memory products
  with dated popularity metrics) was dropped entirely: the oracle verifies
  none of those tools for Vibe, and the metrics would not survive an update
  cycle.

## See also

- [Memory systems](../core/memory-systems.md) — the AGENTS.md hierarchy, the session store, cross-session tooling, and team sharing at full depth
- [Settings reference](../core/settings-reference.md) — every config.toml key the verified surface covers, the eight-layer stack, `VIBE_*` overrides, trust gating
- [Agents and skills reference](../core/agents-and-skills-reference.md) — agent profiles (layer 7 of the config stack) and custom agent TOML
- [Style guide](../style-guide.md) — voice and page contract for this guide
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md)

Structure and pedagogy adapted from the source guide under CC BY-SA 4.0 —
see [NOTICE.md](../../NOTICE.md). Mechanics rebuilt from the oracle.
