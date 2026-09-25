---
title: "Learning Path"
description: "Entry page for the seven-module Vibe CLI learning path: module table, four learner tracks, checklist-only validation, product-surface routing, companions, time estimates, outcomes, and FAQ"
tags: [learning-path, curriculum, index, tracks, modules, surfaces]
---

# Learning Path

**Time:** 7¾–9 hours total · **Complexity:** ★☆☆☆☆ → ★★★★☆ · **Tracks:** Beginner, Practitioner, Production, Maintainer

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics on this page are cited inline as (PART-XXX) against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md). Anything the
oracle could not verify is in [Known gaps](#known-gaps), never in the body.
Curriculum structure is adapted from the source guide; every command, flag,
config key, and surface is rebuilt from the oracle.

**Master the Vibe CLI in seven modules — about 8–9 hours end to end. Go deep
on what matters to you with the surface routes and the companion project.**

This is your structured entry point. Follow the modules in order, then use the
[guide core](../README.md) for depth.

## TL;DR

- Seven modules take you from first run to multi-agent orchestration:
  installation and trust, the core loop, memory and config, agents, skills,
  hooks, advanced patterns — 465–540 minutes of focused module time.
- Validation is **checklist-only**: the CLI ships exactly two builtin skills
  (`vibe`, `skill-creator`) and no quiz or self-assessment command
  (PART-SKILLS §1.5; PART-COMMANDS §2). Every check is something you run and
  observe yourself.
- Four tracks from the companion progress skill — Beginner, Practitioner,
  Production, Maintainer — set your entry point. Modules 01–03 are
  prerequisites for 04–07.
- The path routes to the real product surfaces when the terminal alone stops
  being the whole story: Vibe Code Web cloud sessions (`&` prefix,
  `/teleport`), `/remote-project`, the VS Code extension and ACP, the desktop
  app, and plugins (PART-WEB; PART-PLUGINS §3).
- Two companions turn the path into one continuous exercise and a tracked
  progression: the Proofpack project and the learning-path progress skill.

*Read if you want an exercise-driven route into the Vibe CLI, whether from
zero or to consolidate habits you picked up ad hoc. Skip if you already run
agents, skills, and hooks in production — go straight to
[Architecture](../core/architecture.md) and the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md).*

---

## The 7-Module Path

| Module | Time | Focus | Complexity | Track |
|--------|------|-------|------------|-------|
| **[01-Installation and First Run](01-installation.md)** | ~45 min | Get the CLI running, trust the folder, first session | ★☆☆☆☆ | Beginner |
| **[02-The Core Loop](02-core-loop.md)** | ~60–75 min | How the CLI actually works turn by turn | ★★☆☆☆ | Beginner |
| **[03-Memory and Config](03-memory.md)** | ~60 min | `AGENTS.md` and `config.toml` | ★★☆☆☆ | Beginner |
| **[04-Agents and Specialization](04-agents.md)** | ~75–90 min | Agents as TOML profiles; the `task` tool | ★★★☆☆ | Practitioner |
| **[05-Skills](05-skills.md)** | ~60–75 min | Reusable capabilities in `SKILL.md` | ★★★☆☆ | Practitioner |
| **[06-Hooks](06-hooks.md)** | ~75 min | Event automation in `hooks.toml` | ★★★☆☆ | Practitioner |
| **[07-Advanced Patterns](07-advanced.md)** | ~90–120 min | Multi-agent orchestration, programmatic mode | ★★★★☆ | Production |

**Total: 7¾–9 hours** of focused module time (465–540 minutes), plus the
optional companions.

---

## How to Use This Path

### Step 1: Assess Your Level

The four track names come from the companion progress skill's track model.
Find yourself in the table and use the entry point — or start at Module 01 and
let the prerequisite gating do the sorting.

| Track | You are here if | Entry point |
|---|---|---|
| **Beginner** | Day 1 with the Vibe CLI | 01 → 02 → 03 (~2.5 hours), then keep going in order |
| **Practitioner** | Using the CLI 1–4 weeks | Skim 01–03, deep-dive 04–07 |
| **Production** | Running the CLI on real repositories, or for a team | 01–03 if new to the mechanics, otherwise 06–07 plus the [product surfaces](#current-product-surfaces) |
| **Maintainer** | Own the team's Vibe configuration — `config.toml`, `AGENTS.md`, skills, hooks | The full path, then the [companions](#step-5-keep-progress-in-the-project) and the [Settings reference](../core/settings-reference.md) |

### Step 2: Choose Your Track

Three goal-based routes through the same seven modules:

**Track A: Master the Fundamentals (7¾–9 hours)** — Beginner → Practitioner

- Follow modules 01–07 in order
- Complete every exercise
- Close each module with its "You're Ready If" checklist

**Track B: Skill-Focused Deep Dive (3–5 hours)** — Beginner → Practitioner

- Modules 01–02 for the basics
- Jump to Module 04, 05, or 06 based on your goal
- Go deep on that one module; link to advanced patterns as needed

**Track C: Team Adoption (7¾–9 hours)** — Production → Maintainer

- Modules 01–02 to teach the fundamentals
- Module 03 for shared configuration (`AGENTS.md`, `config.toml`)
- Modules 04–07 as team workflows
- Validate with each module's checklist, identify gaps, and build the
  follow-up training plan from them

### Step 3: Learn & Validate

Each module includes:

- **Reading** (10–30 min): concepts and mental models
- **Hands-on practice** (20–45 min): commands you run yourself
- **Validation**: a "You're Ready If" checklist

Validation is checklist-only. The CLI ships exactly two builtin skills —
`vibe` (model-only self-awareness reference) and `skill-creator` — and no
quiz or self-assessment command (PART-SKILLS §1.5; PART-COMMANDS §2). The
commands you will use constantly while working the modules are all verified
(PART-COMMANDS §2, [stable]):

| Command | What it does |
|---|---|
| `/help` | Show help message |
| `/status` | Display agent statistics |
| `/model` | Select the active model; persists to the session and config (PART-SESSIONS §3.5) |
| `/compact [instructions]` | Compact conversation history by summarizing; optional instructions guide the summary (PART-SESSIONS §4.2) |
| `/rewind` | Rewind to a previous message; Esc Esc with empty input does the same |
| `/clear` | Start a new conversation, optionally seeded with a prompt; resets the model pin (PART-SESSIONS §3.5) |
| `/resume` | Browse, resume, or delete saved sessions; also `vibe --resume [SESSION_ID]` and `vibe -c` (PART-SESSIONS §3.2–3.3) |
| `/exit` | Exit the application; bare `exit`, `quit`, `:q` also work |

### Step 4: Go Deeper

After this path, you have options — all links below exist in this guide:

| Option | Where |
|---|---|
| **A: Deep reference** | [Architecture](../core/architecture.md), [Settings reference](../core/settings-reference.md), [Tools reference](../core/tools-reference.md) |
| **B: Master a domain** | [Memory systems](../core/memory-systems.md), [Skill design patterns](../core/skill-design-patterns.md), [Hooks and events reference](../core/hooks-events-reference.md) |
| **C: Build with plugins** | [Plugins](../core/plugins.md) — Agent Plugins 1.0 packages, **[unified-harness]** only (PART-PLUGINS §3) |
| **D: Re-assess** | Re-run each module's "You're Ready If" checklist; there is no self-assessment command to invoke (PART-COMMANDS §2) |

### Step 5: Keep Progress in the Project

Two companions, both installable into your own projects. They land in a later
phase of this guide; the links resolve once they ship.

The [Proofpack companion project](../../examples/learning-project/README.md)
carries **one issue through all seven modules** — configuration,
implementation, tests, a guarded release check, evidence review — under an
evidence contract: no module is closed without observable evidence. Use it
when you want one continuous exercise instead of seven disconnected ones.

The [learning-path progress skill](../../examples/skills/learning-path/SKILL.md)
turns the seven modules into a local progression. It is a normal Vibe skill
(PART-SKILLS §1.1): the four tracks above, prerequisite gating (a module
opens only when its prerequisites' evidence exists), and evidence-gated
progression (a non-empty evidence note is required to complete a module).
Progress state is recommended at `~/.vibe/learning/progress.json` — inside
the `VIBE_HOME` tree (PART-CONFIG §2.4) — for cross-project progress, or
`<project>/.vibe/learning/` for per-project tracks. Its 1/3/7/14/30/60/90-day
review schedule is project policy, not a claim that one schedule is optimal
for every learner.

### Current Product Surfaces

The CLI is the primary surface, but not the only one. Route to these when the
module sequence touches them (PART-WEB; PART-PLUGINS §3):

| Surface | What it is | How you reach it | Backend |
|---|---|---|---|
| Vibe CLI | The terminal agent: interactive and programmatic (`vibe -p`) | `vibe`, `vibe --help` (PART-CLI) | [stable] |
| Vibe Code Web | Cloud sessions: each run gets an isolated single-tenant sandbox; spawn from the web, or from the CLI with the `&` prefix (new session) or `/teleport` (move the current session); one-way — you cannot pull a session back to the local CLI (PART-WEB §4.1–4.3) | `& <prompt>`, `/teleport` | Commands [stable]; cloud model [docs-only] |
| `/remote-project` | Binds this repository to a Vibe Code Web project (stored in `~/.vibe/projects.toml`) | `/remote-project` (PART-WEB §4.1) | [stable] |
| VS Code extension + ACP | "Mistral Vibe for VS Code" marketplace extension; ships the agent built in, shares config and sessions with the CLI; the ACP registry entry runs it in other ACP-compatible clients (PART-WEB §4.4) | VS Code marketplace; ACP registry | [docs-only] |
| Vibe Code desktop app | Desktop app with Work and Code modes; subagent side panel; the Code home shows whether a session runs locally, in a worktree, or in the cloud (PART-WEB §4.6) | The desktop app | [desktop-0.12.0] |
| Plugins | Filesystem plugin packages per the Agent Plugins 1.0 spec plus the `ai.mistral.vibe` extension: skills, MCP servers, hooks, knowledge, agents; `/plugins` and `/reload-plugins` (PART-PLUGINS §3) | `~/.vibe/plugins/`, `<project>/.vibe/plugins/` | [unified-harness] |

---

## Module Details

### Module 01: Installation and First Run (~45 min)

**Goal:** Get the Vibe CLI running and confirm it works

- Confirm the binary: `vibe --version`, `vibe --help` (PART-CLI)
- Set your API key with `vibe --setup`, which sets up the key and exits (PART-CLI)
- Answer the folder-trust prompt on first run in an untrusted folder;
  `--trust` skips it for automation, `--add-dir` widens the workspace (PART-TRUST §3)
- Run your first prompt and review the diff — the default agent `accept-edits`
  auto-approves file edits only, so the review habit is yours to build (PART-AGENTS §7)

**Complexity:** ★☆☆☆☆ · **Track:** Beginner
**Read:** [01-installation.md](01-installation.md)
**Then:** [Architecture](../core/architecture.md)

---

### Module 02: The Core Loop (~60–75 min)

**Goal:** Understand how Vibe works turn by turn

- The interaction loop: prompt → tool → decision → feedback
- Agents and thinking levels: Shift+Tab cycles `ask → plan → accept-edits → auto-approve` (PART-AGENTS §10); `/thinking` selects the level, `thinking` is a per-model config key (PART-COMMANDS §2; PART-CONFIG §1.1)
- Compaction: `/compact [instructions]` and the `auto_compact_threshold` trigger (PART-SESSIONS §4)
- Session mechanics: `/clear`, `/rewind`, `/resume` (PART-SESSIONS §3)

**Complexity:** ★★☆☆☆ · **Track:** Beginner
**Read:** [02-core-loop.md](02-core-loop.md)
**Then:** [Loop and graph engineering](../core/loop-graph-engineering.md)

---

### Module 03: Memory and Config (~60 min)

**Goal:** Configure Vibe for your workflow

- `AGENTS.md` discovery, hierarchy, and priority semantics (PART-AGENTSMD)
- The eight-layer `config.toml` precedence stack (PART-CONFIG §2.1)
- Environment variables: `VIBE_*` overrides any config field; `VIBE_HOME` relocates the home tree (PART-CONFIG §2.2, §2.4)
- Full system-prompt replacement via `system_prompt_id` and `~/.vibe/prompts/` (PART-AGENTSMD)

**Complexity:** ★★☆☆☆ · **Track:** Beginner
**Read:** [03-memory.md](03-memory.md)
**Then:** [Memory systems](../core/memory-systems.md) and the [Settings reference](../core/settings-reference.md)

---

### Module 04: Agents and Specialization (~75–90 min)

**Goal:** Create focused agents for specific tasks

- Agents are TOML profiles — `~/.vibe/agents/NAME.toml` or `<project>/.vibe/agents/NAME.toml`; every non-profile key is a `config.toml` override (PART-AGENTS §8)
- Tool restriction with `enabled_tools`, `disabled_tools`, and per-tool `permission`/`allowlist`/`denylist` (PART-CONFIG §1.3)
- Personas via `system_prompt_id` prompt files (PART-AGENTS §8)
- Selection: `vibe --agent NAME`, `default_agent`, Shift+Tab (PART-AGENTS §10)
- Delegation: the `task` tool spawns `agent_type = "subagent"` profiles, depth capped at 1 (PART-AGENTS §9)

**Complexity:** ★★★☆☆ · **Track:** Practitioner
**Read:** [04-agents.md](04-agents.md)
**Then:** [Agents and skills reference](../core/agents-and-skills-reference.md)

---

### Module 05: Skills (~60–75 min)

**Goal:** Build reusable capabilities the model loads on demand

- `SKILL.md` format and YAML frontmatter: `name`, `description`, and the rest of the verified schema (PART-SKILLS §1.1)
- Discovery and precedence: builtins → `skill_paths` → project `.vibe/skills/` → user `~/.vibe/skills/`; first match wins (PART-SKILLS §1.2)
- Invocation: `/skill-name` for users, the `skill` tool for the model (PART-SKILLS §1.3–1.4)
- The builtin `skill-creator` skill loads before you create or update a skill (PART-SKILLS §1.5); changes are picked up with `/reload` (PART-COMMANDS §2)

**Complexity:** ★★★☆☆ · **Track:** Practitioner
**Read:** [05-skills.md](05-skills.md)
**Then:** [Skill design patterns](../core/skill-design-patterns.md)

---

### Module 06: Hooks (~75 min)

**Goal:** Automate responses to system events, with an explicit failure posture

- Exactly three events: `pre_tool`, `post_tool`, `post_agent` (PART-HOOKS §1)
- Registration is `<project>/.vibe/hooks.toml` (trusted) then `~/.vibe/hooks.toml`: `[[hooks]]` with `name`, `type`, `command`, `match`, `timeout`, `strict` (PART-HOOKS §2)
- The decision contract is stdout JSON — `{"decision": "allow"|"deny", ...}` — not exit codes (PART-HOOKS §3.3)
- Hooks fail open by default; `strict = true` makes tool hooks fail closed (PART-HOOKS §3.3)

**Complexity:** ★★★☆☆ · **Track:** Practitioner
**Read:** [06-hooks.md](06-hooks.md)
**Then:** [Hooks and events reference](../core/hooks-events-reference.md)

---

### Module 07: Advanced Patterns (~90–120 min)

**Goal:** Orchestrate multi-agent workflows and run the agent programmatically

- Delegation is the `task` tool only: subagent profiles, depth capped at 1, text-only results returned to the parent (PART-AGENTS §9)
- One parent orchestrating parallel `task` calls — multiple task calls in one turn run concurrently (PART-HOOKS §3.6)
- Programmatic mode: `vibe -p`, `--max-turns`, `--max-price`, `--output {text,json,streaming}` (PART-CLI)
- Worktree isolation with `--worktree` for risky changes (PART-CLI; PART-WORKTREES)

**Complexity:** ★★★★☆ · **Track:** Production
**Read:** [07-advanced.md](07-advanced.md)
**Then:** [Methodologies](../core/methodologies.md)

---

## After the Learning Path

### Assessment

There is no self-assessment command to run (PART-COMMANDS §2). To measure
where you stand: re-run each module's "You're Ready If" checklist and note
which items you cannot demonstrate. The gaps are your personalized next-step
plan. The companion progress skill records exactly this — track, prerequisites
met, and a non-empty evidence note per module.

### Specialization

Choose where to go next:

| Interest | Path |
|----------|------|
| How the CLI actually works | [Architecture](../core/architecture.md) |
| Team conventions, memory, settings | [Memory systems](../core/memory-systems.md) · [Settings reference](../core/settings-reference.md) |
| Extending with skills | [Skill design patterns](../core/skill-design-patterns.md) |
| Automation and guardrails | [Hooks and events reference](../core/hooks-events-reference.md) |
| Agent anatomy and tool policy | [Agents and skills reference](../core/agents-and-skills-reference.md) · [Tools reference](../core/tools-reference.md) |
| Programmatic and multi-agent work | [Loop and graph engineering](../core/loop-graph-engineering.md) · [Context engineering](../core/context-engineering.md) |
| Terms and definitions | [Glossary](../core/glossary.md) |

### Practice

- [Proofpack companion project](../../examples/learning-project/README.md):
  one issue carried through all seven modules with an evidence contract
- Project of your own: pick a repeated task, build the agent or skill for it,
  gate it with a hook, and run it programmatically

---

## Time Estimates

**For different goals:**

- **Just getting started:** ~2 hours — Modules 01–02 only (105–120 min)
- **Daily usage:** 5–6 hours — Modules 01–05 (300–345 min)
- **Team adoption:** 7¾–9 hours — Modules 01–07 (465–540 min)
- **Deep mastery:** the path plus the guide's core pages — the
  [Guide Index](../README.md) lists reading times per page
- **Specialization:** depends on the domain; start from the table above

---

## What You'll Be Able to Do

After this learning path, you can:

- Run the Vibe CLI day to day without the docs: prompt, review diffs, compact,
  rewind, resume
- Write durable instructions — `AGENTS.md` hierarchy plus `config.toml`
  layering — for yourself and for a team
- Build specialized agents as TOML profiles and delegate to subagents with
  the `task` tool
- Package reusable skills and wire hooks that gate tool calls with an explicit
  failure posture
- Orchestrate parallel subagent work and run sessions programmatically
- Say where each product surface begins and ends: CLI, Vibe Code Web, VS Code
  and ACP, the desktop app, plugins

---

## Common Questions

**Q: Can I skip modules?**
A: Yes, but 01–03 are prerequisites for 04–07. If you already have the
basics, start at Module 04.

**Q: How long does it really take?**
A: About 8–9 hours for the full path. Budget extra time for exercises and for
the companion project if you take it on.

**Q: Do I need prior experience with the CLI?**
A: No. Start at Module 01. If you have used it before, skim 01–02.

**Q: Is there a quiz or self-assessment command?**
A: No. The CLI ships exactly two builtin skills (`vibe`, `skill-creator`)
and no quiz or self-assessment command (PART-SKILLS §1.5; PART-COMMANDS §2).
Each module validates with a checklist you verify by running things. If you
want quizzes, they have to ship as a real user-invocable skill
(PART-SKILLS §1.3).

**Q: After this, where do I go for depth?**
A: The [guide core](../README.md) for theory and reference, and the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md) when you need
to know exactly what a mechanic does.

---

## Ready? Start Here

**First time:** → [Module 01: Installation and First Run](01-installation.md)
**Already using the CLI:** → Assess your level in Step 1, jump to the relevant module
**Team adoption:** → [Module 03: Memory and Config](03-memory.md)

**Quick assessment:** there is no self-assessment command (PART-COMMANDS §2).
Use the Step 1 track table — it takes five minutes — and let the first
module's checklist tell you whether you guessed your level right.

---

## Known gaps

- **No quiz mechanics anywhere.** The builtin skill set is exactly two
  (`vibe`, `skill-creator`, PART-SKILLS §1.5) and the slash-command list has
  no quiz or self-assessment entry (PART-COMMANDS §2). This page therefore
  validates by checklist only and does not offer a graded assessment; a quiz
  would have to ship as a real user-invocable skill (PART-SKILLS §1.3).
- **Install channels are not published here.** The oracle records only the
  observed Homebrew install (`mistral-vibe`, 2.25.0); exact per-OS install
  commands and any Docker image are not verified. Module 01 teaches first-run
  mechanics, not install channels.
- **Cloud, editor, and desktop facts are docs-verified, not driven.** The
  Vibe Code Web session model (PART-WEB §4.3) and the VS Code extension and
  ACP (PART-WEB §4.4) were verified from public docs only; the desktop facts
  (PART-WEB §4.6) come from the 0.12.0 bundle's own release notes, not from
  driving the UI. Treat feature claims on those surfaces as
  documented-only until you run them yourself.
- **Plugins are Unified-Harness-only.** `/plugins` and `/reload-plugins`
  were withheld in 2.25.0 and are registered in main 2.25.8 behind the
  experimental harness (PART-PLUGINS §3.5); plugin mechanics are not
  exercisable on the stable backend. The main-2.25.8 builtin `vibe` plugin
  package additionally ships four skills through the plugin path
  (PART-PLUGINS §3.4) — distinct from the two code-registered builtin skills
  the CLI reports.
- **Companion links are forward references.** The Proofpack project and the
  progress skill land in a later phase of this guide; until then their links
  are the agreed target paths, not yet existing files.

## See also

- [Guide Index](../README.md) — reading times and status for every guide page
- [Architecture](../core/architecture.md) — how the CLI works, for depth after Module 02
- [Style guide](../style-guide.md) — voice, page contract, mechanics discipline
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md) — the verified source for every mechanic on this page
