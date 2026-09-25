---
title: "Memory Systems"
description: "Durable memory in Vibe: the AGENTS.md instruction hierarchy, the session store, hook-driven cross-session writes, team sharing, multi-agent coordination, architecture patterns, risks, and decision frameworks"
tags: [memory, agents-md, sessions, hooks, mcp, team, multi-agent, security]
---

# Memory Systems

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics on this page are cited inline as (PART-XXX) against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md). Anything the
oracle could not verify from public sources is in
[Known gaps](#known-gaps), never in the body. Structure and pedagogy are
adapted from the source guide; every mechanic is rebuilt from the oracle.

## TL;DR

- Memory in Vibe splits into three tracks: the **native stack** (the
  AGENTS.md instruction hierarchy plus the on-disk session store), **cross-session
  tooling** you wire yourself (a `post_agent` hook appending durable notes, or
  a third-party MCP memory server), and **team sharing** (a checked-in
  `AGENTS.md` as the shared layer).
- Vibe has no automatic memory extraction. There is no auto-memory directory,
  no `MEMORY.md`, and no separately auto-loaded rules file. Durable user
  preferences live in `~/.vibe/AGENTS.md`; durable project conventions live
  in a checked-in `AGENTS.md` (PART-AGENTSMD).
- The session store gives you resumable conversational memory, not knowledge:
  each session persists as `meta.json` plus `messages.jsonl` under
  `~/.vibe/logs/session/`, resumable by ID or from the same directory, with
  the model pinned per session (PART-SESSIONS section 3).
- The verified cross-session write pattern is a `post_agent` hook: it fires
  once per turn, receives `session_id`, `transcript_path`, and `cwd`, and can
  append durable notes to an `AGENTS.md` or a notes file. That is the honest
  Vibe form of hook-driven memory writes (PART-HOOKS sections 1 and 3.7).
- A poisoned checked-in `AGENTS.md` affects every trusted session in the repo.
  The trust gate is the blast-radius control, and it is coarse (PART-AGENTSMD;
  PART-TRUST sections 3.1-3.5).

*Read if you maintain AGENTS.md files across projects, want sessions to
accumulate knowledge instead of evaporating, or are evaluating third-party
memory tooling for Vibe. Skip if you run single-shot prompts and never resume
sessions.*

## Table of Contents

1. [TL;DR: three-track model](#1-tldr-three-track-model)
2. [The native stack](#2-the-native-stack)
3. [Cross-session memory (single user)](#3-cross-session-memory-single-user)
4. [Team sharing](#4-team-sharing)
5. [Multi-agent shared memory](#5-multi-agent-shared-memory)
6. [Architecture patterns](#6-architecture-patterns)
7. [Risks and security](#7-risks-and-security)
8. [Decision frameworks](#8-decision-frameworks)
9. [Benchmarks and evaluation](#9-benchmarks-and-evaluation)
10. [Open problems](#10-open-problems)
11. [Known gaps](#known-gaps)

---

## 1. TL;DR: Three-Track Model

| | Native stack | Cross-session tooling | Team / multi-agent |
|---|---|---|---|
| **Mechanisms** | `~/.vibe/AGENTS.md`, project `AGENTS.md` chain, subdirectory `AGENTS.md`, session store | `post_agent` hook writer; third-party MCP memory server | Checked-in `AGENTS.md`; shared MCP server |
| **Write path** | You, by hand | Hook, automatically per turn (PART-HOOKS) | Git review flow |
| **Read path** | Injected every session; session store via `--resume`/`-c` | File read or MCP tool call | Same as native, per clone |
| **Decay** | Your pruning discipline | Whatever you implement | Your pruning discipline |
| **Infra** | None | A script, or an external server | None for the static layer |

Three findings that should shape how you think about memory in Vibe:

1. **Vibe does not remember for you.** The native stack is files you maintain
   and transcripts Vibe persists. Anything beyond that is tooling you wire:
   a hook that captures, or a server that stores. Treat claims of automatic
   extraction in third-party tools as features to verify, not defaults to
   assume.
2. **Instruction files are an unguarded write surface.** `AGENTS.md` content is
   injected into every trusted session and "OVERRIDE any default behavior";
   the model is told to follow it "exactly as written" (PART-AGENTSMD). One
   poisoned line in a checked-in file propagates to every developer and agent
   that trusts the repo. See
   [section 7.1](#71-memory-poisoning-via-checked-in-agentsmd).
3. **Session memory is transcript, not knowledge.** `messages.jsonl` replays
   the conversation; it does not distill it. Resume is recall, not learning.
   The distillation step — what other ecosystems call consolidation — is the
   part you must build or buy.

---

## 2. The Native Stack

### 2.1 AGENTS.md: the instruction hierarchy

AGENTS.md files are persistent instructions Vibe injects at session start:
your preferences, conventions, and project context, loaded before the first
user message.

| Location | Loaded when | Role |
|---|---|---|
| `~/.vibe/AGENTS.md` (`$VIBE_HOME/AGENTS.md`) | Always | User-level instructions |
| `<project-root>/AGENTS.md`, plus every `AGENTS.md` walking up from each project root to its trust root | Trusted project roots, `include_project_context` (default on) | Project instructions, checked into the codebase |
| `AGENTS.md` in subdirectories of an open root | Lazily, when a file below them is read (injected on `read_file`) | Scoped instructions |

(PART-AGENTSMD.)

Priority, from the injected prompt itself: project instructions beat user
instructions; among multiple project files, the one closer to the working
directory wins; each file applies to its own directory and its descendants;
and the whole set overrides the default system prompt (PART-AGENTSMD).
Project roots must be trusted — "Files are only loaded for trusted folders"
(PART-AGENTSMD; PART-TRUST section 3.5). `--add-dir` roots join the project
roots and are implicitly trusted for the session (PART-TRUST section 3.3).

**Minimum viable AGENTS.md.** Vibe infers the tech stack, layout, and most
conventions from the code itself. Add only what the code cannot tell it:

```markdown
# Project Name

One-sentence description.

## Commands
- `pnpm dev` - Start development server
- `pnpm test` - Run tests
- `pnpm lint` - Check code style
```

**The discoverability filter**: before adding any line, ask "can the agent
find this by reading the codebase?" If yes, cut it. What earns a line:
tooling gotchas (`use uv, not pip`), operational landmines (`legacy/ is
deprecated but imported by prod`), and conventions that conflict with
standard patterns.

**The anchoring risk**: every line loads in every session, regardless of
task. A stale entry pointing at a deprecated library biases the agent toward
it on every prompt. Pruning AGENTS.md is maintenance, not cleanup.

**When the file grows**, structure it in three layers — WHAT (stack and
structure), WHY (architecture decisions), HOW (working conventions) — so a
reader can prune by layer. Treat the file as compounding memory: never
correct the agent twice for the same mistake; add the correction when it
generalizes.

### 2.2 The session store

Every session is persisted to disk as two files (PART-SESSIONS section 3,
live-verified on 2.25.0):

```text
~/.vibe/logs/session/session_<YYYYMMDD_HHMMSS>_<short-id>/
  meta.json        # metadata: session_id, parent_session_id, git_commit,
                  # git_branch, title, loops, config snapshot (pinned model),
                  # total_messages, agent_profile, environment, stats
  messages.jsonl  # one JSON object per message
```

- The save dir is `session_logging.save_dir` (default `~/.vibe/logs/session/`);
  logging is `session_logging.enabled` (default on) (PART-SESSIONS section 3.1).
- `~/.vibe/logs/session/.session_index.json` is a listing cache reconciled
  against each `meta.json` mtime; a `.last_session/<tty>` pointer tracks the
  latest session per terminal (PART-SESSIONS section 3.1).
- **Resume**: `-c`/`--continue` picks the per-terminal pointer, else the most
  recent session reaching the current directory; `--resume <ID>` resolves
  globally by ID with partial-ID matching; `/resume` opens the folder-scoped
  picker (PART-SESSIONS sections 3.2-3.3).
- **Model pinning**: the first user message pins the resolved `active_model`
  into the session's config snapshot; resuming keeps the pinned model even if
  the default changes; `/model` updates it; `/clear` starts a fresh unpinned
  conversation (PART-SESSIONS section 3.5).
- **Compaction** summarizes the same session in place — the session, its
  store, and the visible conversation continue; `auto_compact_threshold`
  (default 200,000 tokens, `0` disables) triggers before a turn
  (PART-SESSIONS section 4).

The store is conversational memory: perfect for "pick up where I left off,"
useless for "what did we decide about auth six weeks ago" unless you resume
that exact session.

### 2.3 What Vibe does not have

Stated plainly, because tooling ecosystems advertise equivalents: Vibe has
no automatic memory extraction, no auto-memory directory, no `MEMORY.md`, and
no separately auto-loaded rules file. The oracle, at the documented 2.25.8
surface, contains none of these. If you are porting a habit from another
tool:

| Habit from other tools | Vibe reality |
|---|---|
| Auto-curated memory file | Maintain `AGENTS.md` yourself |
| Rules directory auto-loaded per path | Subdirectory `AGENTS.md`, injected lazily on `read_file` (PART-AGENTSMD) |
| Per-agent memory frontmatter | No such field; subagents inherit the harness, not a private memory store (PART-AGENTS section 9) |
| Background consolidation pass | None; see [section 3.1](#31-the-verified-write-pattern-a-post_agent-hook) for the hook you can wire |

Durable user preferences live in `~/.vibe/AGENTS.md`; durable project
conventions live in a checked-in `AGENTS.md`. Everything else is session
state.

### 2.4 Limits of the native stack

| Limit | Consequence |
|---|---|
| No semantic retrieval | AGENTS.md loads linearly, every session; there is no search-by-meaning over instruction files |
| Per-machine session store | `~/.vibe/logs/session/` is local; nothing syncs it across devices |
| No cross-project aggregation | What you learned in project A does not surface in project B unless you put it in `~/.vibe/AGENTS.md` |
| No consolidation | Nothing prunes, deduplicates, or re-validates your files; staleness is entirely your problem |
| Subagents share no conversational state | The parent passes a task string; the child returns text (PART-AGENTS section 9) |

---

## 3. Cross-Session Memory (Single User)

### 3.1 The verified write pattern: a `post_agent` hook

A `post_agent` hook fires once per turn, after the agent finishes responding
with no pending tool calls (PART-HOOKS section 1). Its stdin payload carries
`session_id`, `transcript_path` (the `messages.jsonl` of the running
session), `cwd`, and `parent_session_id` when it runs inside a subagent
(PART-HOOKS section 3.2). That is everything a memory writer needs: read the
turn's transcript, extract what matters, append it somewhere durable.

```toml
# <project>/.vibe/hooks.toml (trusted folder) or ~/.vibe/hooks.toml
[[hooks]]
name = "append-session-notes"
type = "post_agent"
command = "python ./.vibe/hooks/write-notes.py"
description = "Append durable notes from the turn transcript."
```

The handler shape follows the documented guard-script pattern (PART-HOOKS
section 3.8): read the JSON payload from stdin, do the work, exit 0. For a
memory writer, emit `{"decision": "allow"}` — the append is the side effect:

```python
import json, sys

payload = json.load(sys.stdin)
# payload: session_id, transcript_path, cwd (PART-HOOKS section 3.2)
# read messages.jsonl at transcript_path, distill the turn,
# append one dated entry to AGENTS.md or a notes file.
print(json.dumps({"decision": "allow"}))
```

Why this is the honest write path, mechanically:

| Property | Value | Citation |
|---|---|---|
| Fires | Once per turn, no pending tool calls | PART-HOOKS section 1 |
| Cost | Zero agent tokens — the agent never calls a memory tool | PART-HOOKS section 1 |
| `match`/`strict` | Forbidden on `post_agent` | PART-HOOKS section 2 |
| `deny` effect | `reason` injected as a new user message; the model retries the turn, max 3 retries per user turn | PART-HOOKS sections 3.3, 3.7 |
| Failure | Fail-open: warning, turn proceeds — a failed writer silently loses the capture | PART-HOOKS section 3.3 |
| Bounds | 60 s default timeout, 1 MiB stdout cap, own process group, session cwd | PART-HOOKS sections 3.1, 3.5 |

Two design consequences. First, use `allow` plus side effect, not `deny`:
`deny` is a retry mechanism, not a write path. Second, because `strict` cannot
be set on `post_agent`, there is no way to make a failed memory hook loud —
build your own failure logging into the script, or you will lose writes
without an error (PART-HOOKS sections 2-3.3).

### 3.2 Ordering with compaction

Capture and compaction do not race in Vibe. A `post_agent` hook runs at the
end of its turn; auto-compaction triggers *before* a turn, when
`context_tokens` crosses the threshold (PART-SESSIONS section 4.1). So
end-of-turn capture always precedes the next compaction — the conflict
pattern known from hook capture in other harnesses, where a save could be
eaten by an auto-compact mid-pipeline, does not arise at this seam. It can
still arise *inside* your writer if you batch turns; write per turn.

### 3.3 Choosing third-party memory tooling

Third-party memory tools exist for the MCP ecosystem and can be pointed at
Vibe; the oracle deliberately covers no specific product, so this guide
endorses none. What survives from the source guide's survey is the selection
criteria — apply them to any candidate:

| Criterion | Question to ask |
|---|---|
| Write path | Hook-driven (automatic, zero token cost) or tool-call-driven (the agent must decide to remember, each call costs tokens)? |
| Retrieval shape | Lexical, semantic vector, graph traversal, or hybrid fusion — matched to your actual queries? |
| Decay model | Importance-weighted, TTL, temporal windows, or nothing? |
| Team primitive | Real multi-user scoping, or a single-tenant store retrofitted with a shared key? |
| Provenance | Can you answer "who wrote this, from which session, based on what evidence"? |
| Failure mode | What happens when the writer dies — error, or silent loss? |
| Reproducibility | Are its benchmark claims backed by a published corpus and adapter code, or vendor numbers? |

Two principles carry over regardless of tool. Hook-driven writes beat
tool-call-driven writes as a default, because automatic extraction at zero
token cost outperforms voluntary store calls the model must remember to make.
And hybrid retrieval (lexical + semantic + graph fused, e.g. by reciprocal
rank fusion) beats pure vector search when queries include exact-match
signal — function names, error strings — that embeddings smear.

### 3.4 MCP memory servers, generically

Any MCP server can be added — `vibe mcp add` (transports `http`,
`streamable-http`, `stdio`) or an `[[mcp_servers]]` block in `config.toml`
(PART-MCP sections 1.1-1.2). A memory MCP server is therefore not a special
integration; it is one more server with tools. What the harness guarantees:

- Published tool names are `{server-alias}_{tool-name}` (PART-MCP section 1.7).
- MCP tools are ordinary tools under the permission gate: per-tool
  `permission = ask|always|never` keyed by the published name, e.g.
  `[tools.mem_search]` (PART-MCP section 1.8; PART-PERMISSIONS section 4.5).
- A server can be silenced without removal: `disabled = true` hides all its
  tools; `disabled_tools` hides named ones (PART-MCP section 1.9).

The comparison you should make is not "which memory product is native" —
none is — but "which store, reached through an ordinary permission-gated
tool, with writes driven by my own hook."

---

## 4. Team Sharing

### 4.1 The shared layer: a checked-in AGENTS.md

Team memory in Vibe is the same mechanism as personal memory, distributed by
Git: one `AGENTS.md` per project root, reviewed like code. The trust model
frames the blast radius (PART-TRUST sections 3.1-3.5):

- Folders become trusted through `trusted_folders.toml` (`trusted` /
  `untrusted` lists of resolved absolute paths), a session-only `--trust`
  grant, or the interactive trust prompt — which is offered precisely when
  the cwd has "trustable files", including an `AGENTS.md` at or above it
  (PART-TRUST sections 3.1-3.2).
- Untrusted roots contribute nothing: their project `AGENTS.md` and project
  config are not loaded (PART-TRUST section 3.5).
- Declining trust runs the session with project configuration ignored, not
  blocked (PART-TRUST section 3.2).

### 4.2 Dynamic shared memory

The static layer carries standards; it does not carry decisions. For a
dynamic, shared store, the generic MCP path from
[section 3.4](#34-mcp-memory-servers-generically) is the mechanism: one
server, every teammate's Vibe pointed at it, scoping enforced by the server
(or not — see the risk matrix below). No team-native memory tool is verified
in the oracle, so this guide makes no product recommendation.

### 4.3 Why the team gap is structural

The absence of a dominant team solution is not a maturity question. Every
retrofit fights the same barriers: single-tenant storage models, the real
engineering cost of multi-user auth, privacy and sharing pulling in opposite
directions (local store versus vendor data residency), and no shared
taxonomy for scoping memory across users. A checked-in `AGENTS.md`
sidesteps all of it by distributing through the review flow you already run —
at the cost of being write-once-at-review-time, not a live store.

---

## 5. Multi-Agent Shared Memory

### 5.1 What Vibe actually gives you

Vibe's subagent mechanics define what "shared memory" can mean here
(PART-AGENTS section 9):

| Mechanic | Value |
|---|---|
| Entry point | The single `task` tool; args `task` (text) and `agent` (default `"explore"`) |
| Depth | 1 — a subagent cannot spawn a subagent; recursion raises a `ToolError` |
| Result | Text-only `TaskResult(response, turns_used, completed)` — no message objects, no files |
| Child sessions | Persisted under `<parent session dir>/agents/`, resumable, `parent_session_id` linked |
| Permissions | Child inherits the parent's permission store |
| Hooks | Child inherits the parent's `hooks.toml`; payloads carry `parent_session_id` |

The coordination contract is therefore narrow: the parent's task string in,
one text blob out. There is no shared blackboard, no shared session history,
no message-object passing. Two durable artifacts emerge from every
delegation: the child's own persisted session (retrievable, auditable) and
whatever the parent chooses to write down. If you want delegation to
accumulate knowledge, the parent — or a `post_agent` hook — must write it to a
file, because the harness will not.

### 5.2 Patterns beyond the harness

When you need more than text-in/text-out, the generic patterns from the
multi-agent literature apply on top of the `task` seam:

- **MCP as blackboard**: multiple agents read and write a shared semantic
  store through ordinary MCP tool calls. Works, but MCP was designed for
  user-to-agent context access; agent-to-agent coordination is a workaround,
  not a designed use.
- **Shared ground truth in files**: the cheapest correct pattern — a
  checked-in `AGENTS.md` or notes file is the one memory every session in the
  repo reads anyway (PART-AGENTSMD). Pair it with a reviewer-creator split:
  one agent proposes the note, another verifies it against the code.
- **Leases and signals**: distributed locks plus pub/sub over a shared store
  solve write conflicts between concurrent agents — and deserve
  distributed-systems scrutiny (lease expiry on crash, delivery guarantees,
  clock skew) that no memory product ships as verified.
- **Agent-to-agent protocols**: industry protocols for agent interoperability
  exist and complement MCP; memory sharing between agents is eventually a
  protocol problem, not a storage problem.

---

## 6. Architecture Patterns

Five patterns crystallize from memory tooling generally. Most tools
implement exactly one; they do not compose well. Use them as a vocabulary for
evaluating anything you build or buy.

| Pattern | Shape | Trade |
|---|---|---|
| Hook-driven lifecycle capture | Turn ends → hook extracts → compressed note injected next session | Zero agent cooperation needed; the only verified Vibe write path (PART-HOOKS) |
| MCP as blackboard | Shared store via tool calls | Coordinates agents through a seam designed for user context |
| Episodic + permanent graph | Decaying observations plus a persistent typed-relation graph | Two storage models to keep in sync; the graph answers "how do these relate" |
| Temporal knowledge graph | Every edge carries a validity window; point-in-time queries | Overhead on every retrieval; only justified when "what did we believe then" is a real question |
| Hybrid retrieval fusion | Lexical + semantic + graph, fused by reciprocal rank fusion | ~20 lines of fusion code; the cost is keeping three indexes in sync |

**Storage backend right-sizing** — the generic table, independent of any
product:

| Scenario | Correct backend | Avoid |
|---|---|---|
| Solo, single machine | Embedded store (SQLite-class) | A database service for one user |
| Solo, multi-device | Cloud KV + vector | An embedded file on a network mount |
| Small team, self-hosted | Postgres with a vector extension | A single file with multiple writers |
| Team needing temporal queries | Graph store | Flat snapshot stores |
| Compliance-bound | Self-hosted, with export | Cloud-only vendors without export |
| Prototype | Plain files in Git | Anything with an SLA |

The consistent missing option across memory tooling is the boring one:
Postgres plus a vector extension, with its mature concurrent-write handling
and row-level security. When a team outgrows a single-user store, that is the
first place to look.

---

## 7. Risks and Security

### 7.1 Memory poisoning via checked-in AGENTS.md

AGENTS.md content is injected into every trusted session with the highest
instruction priority: it "OVERRIDE[s] any default behavior and you MUST
follow them exactly as written" (PART-AGENTSMD). A session does not
distinguish "instructions my maintainer wrote" from "instructions in a file
that came with the clone". Concretely:

- A single line added to a checked-in `AGENTS.md` — by a compromised
  dependency, an attacker landing a PR, or a careless merge — propagates to
  every trusted session every developer runs in that repo.
- The blast radius is the trust root. Project files load from each project
  root up to its trust root (PART-AGENTSMD), so a file at the trust root
  reaches every subproject.
- The trust gate is coarse: trust is per-folder, tri-state
  (`trusted`/`untrusted`/session), and recorded in
  `~/.vibe/trusted_folders.toml` (PART-TRUST section 3.1). `--add-dir` roots
  are implicitly trusted for the session (PART-TRUST section 3.3) — a hook or
  config pulled from an add-dir rides in with project-instruction privileges.
- The one structural mitigation is that untrusted roots contribute nothing:
  an untrusted clone's `AGENTS.md` is not loaded at all (PART-TRUST section
  3.5). Treat an unfamiliar clone as untrusted until reviewed.

What Vibe does not give you: per-line provenance, content validation on
load, or an audit trail of which instruction influenced which turn. Review
`AGENTS.md` diffs with the same scrutiny as executable code — that is the
entire defense.

### 7.2 Stale memory driving wrong decisions

Nothing in the native stack re-validates an instruction against the code it
describes. A convention that outlives its context is still loaded, still
prioritized, and still followed "exactly as written" (PART-AGENTSMD). The
anchoring risk from [section 2.1](#21-agentsmd-the-instruction-hierarchy) is
the mechanism; the mitigation is scheduled pruning and a rule of thumb —
every entry names the condition under which it stops being true.

### 7.3 Context budget exhaustion

Memory reads are not free, and nothing budgets them for you:

- Every AGENTS.md in scope loads every session, linearly, before the first
  user message (PART-AGENTSMD). Six files walking up a monorepo are six
  injections.
- Every enabled MCP tool's schema occupies context; a memory server with a
  large tool surface is a standing tax. Silence it with `disabled = true` or
  `disabled_tools` until needed (PART-MCP sections 1.2, 1.9).
- No retrieval path in the oracle exposes a token budget. If your hook
  writer or MCP tool returns "the 20 most relevant notes," you own bounding
  what "a note" costs.

### 7.4 Exfiltration

`messages.jsonl` is a full transcript — prompts, tool inputs, tool outputs —
persisted on disk under `~/.vibe/logs/session/` (PART-SESSIONS section 3.1).
Two surfaces follow from that: any hook command receives `transcript_path`
and can read the entire session (PART-HOOKS section 3.2), and any MCP server
receives whatever an agent sends it, under your permission gate but not under
your encryption policy (PART-MCP section 1.4). Third-party hooks and memory
servers should be treated as readers of everything the session has seen.

### 7.5 Risk matrix

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Poisoned AGENTS.md propagates to every trusted session | High if trust is granted casually | Critical | Review AGENTS.md diffs like code; distrust unfamiliar clones (PART-TRUST section 3.5) |
| Stale instructions bias every turn | High | High | Scheduled pruning; entries state their expiry condition |
| Context blown by instruction files and tool schemas | Medium | High | Discoverability filter; `disabled`/`disabled_tools` (PART-MCP section 1.9) |
| Hook memory writer fails silently (fail-open, no `strict` on `post_agent`) | Medium | Medium | Log failures inside the script; monitor the notes file |
| Transcript exfiltration via hook or MCP server | Low | Critical | Vet hook commands; scope MCP permissions per tool (PART-MCP section 1.8) |
| Vendor lock-in on a hosted memory store | Low short-term | Medium | Prefer stores with export; keep a file-based fallback layer |
| Adoption on unaudited benchmark claims | High | Medium | Demand corpus, adapter, and reproduction steps |

---

## 8. Decision Frameworks

### 8.1 Decision matrix

| Need | Mechanism | Citation |
|---|---|---|
| Durable personal preferences | `~/.vibe/AGENTS.md` | PART-AGENTSMD |
| Team conventions, all projects | Checked-in `AGENTS.md` per repo | PART-AGENTSMD |
| Scope a convention to one subtree | Subdirectory `AGENTS.md` (lazy on `read_file`) | PART-AGENTSMD |
| Continue yesterday's conversation | `-c`, `--resume <ID>`, `/resume` | PART-SESSIONS sections 3.2-3.3 |
| Keep a model across a resumed session | Session model pinning | PART-SESSIONS section 3.5 |
| Automatic durable notes, per turn | `post_agent` hook appending to a file | PART-HOOKS sections 1, 3.7 |
| Semantic recall across projects | A third-party MCP memory server, permission-gated | PART-MCP sections 1.2, 1.8 |
| Delegate read-only exploration | `task` tool with the `explore` subagent | PART-AGENTS section 9 |
| Coordinate concurrent agents | Files as ground truth; leases/signals only if you build them | PART-AGENTS section 9 |
| Prevent memory loading from an untrusted source | Trust gate: leave the folder untrusted | PART-TRUST sections 3.1, 3.5 |

### 8.2 Implementation patterns

**Pattern A — solo, local, zero infra.**

```text
~/.vibe/AGENTS.md        # personal preferences, all projects
<repo>/AGENTS.md         # project conventions, checked in
<repo>/.vibe/hooks.toml  # post_agent note-writer (section 3.1)
```

Covers durable conventions plus per-turn capture. The session store already
gives resume; the hook adds distillation.

**Pattern B — team, shared standards plus shared memory.**

```text
Static:   <repo>/AGENTS.md            # reviewed like code, loaded by every trusted session
Dynamic:  one shared MCP memory server # same config block in every teammate's config.toml
```

The static layer is verified mechanics; the dynamic layer is generic MCP
(PART-MCP). Decide the scoping model *before* pointing a team at a shared
store — see section 7.1 for what a shared write surface means.

**Pattern C — multi-agent, shared knowledge.**

```text
Parent delegates via task (text in, TaskResult out)
Shared durable memory = the repo's files, not a blackboard
A post_agent hook distills what either session learned into those files
```

The harness persists child sessions under `<parent session dir>/agents/`
(PART-AGENTS section 9), so the audit trail exists — the accumulation step is
yours.

---

## 9. Benchmarks and Evaluation

No memory benchmark numbers are carried over from the source guide's survey;
they were tool-vendor claims against a moving field. What survives is the
methodology, which you should apply to any memory tooling — including your
own hook writer:

- **Named academic frameworks** measure distinct things: retention under
  constrained capacity, coherence over very long histories, performance per
  unit of compute, and multi-turn recall plus reasoning-trace fidelity.
  Match the benchmark to your failure mode, or the number is decoration.
- **Skepticism rule**: when a tool reports a recall figure, ask for the
  corpus, the adapter code, and the reproduction steps. Self-published
  numbers on self-chosen corpora are marketing until reproduced.
- **Measure your own loop**: the metric that matters is end-to-end — tokens
  spent on memory reads versus turns saved on your tasks. Aggregate
  vendor overhead numbers tell you nothing about your repo.
- **Decay models** come in three documented families: importance-weighted
  decay (retrieval slows fading), hard caps (simple, but can truncate a
  load-bearing entry), and temporal validity windows (point-in-time
  correctness, at scanning cost). The production-correct combination is
  importance at write time, recency at read time, reinforcement on
  retrieval, and consolidation triggered by token budget rather than
  entry count.

---

## 10. Open Problems

These have no tooling answer today, in Vibe's ecosystem or the wider one:

- **Cross-project memory**: what project A taught you that applies to
  project B. The hierarchy scopes instructions per project; only
  `~/.vibe/AGENTS.md` crosses projects, and it is one unstructured file.
- **Memory versioning**: no store in this space has a Git equivalent —
  branches, merges, rollback — for semantic memory. File-based notes inherit
  Git's text semantics, which resolve text conflicts, not contradictions.
- **Consolidation**: merging overlapping notes, converting relative dates,
  retiring contradicted facts. Vibe has nothing native, so it lands on your
  hook writer.
- **Conflict resolution between writers**: two sessions appending
  contradictory notes implicitly resolve last-write-wins. CRDTs and vector
  clocks are standard in collaborative editing and absent from memory tools.
- **Provenance**: which session wrote this note, from what evidence.
  Nothing surfaces it; post-mortems on memory-driven mistakes start from
  nothing.
- **Cost attribution**: is the memory layer worth its token cost on *this*
  project? No mechanism answers it; the measurement loop above is the only
  path.

The core diagnosis carries over intact: the field treats memory as a storage
problem when it is a coordination problem. Storage is largely solved;
deciding what to keep, when it expires, and who may write it is not.

---

## Known gaps

- **No automatic memory extraction exists in the oracle** at the documented
  2.25.8 surface. This page states its absence as fact per the port
  instructions, but absence of evidence is anchored to the 2.25.0 live
  baseline plus the 2.25.8 documented surface; a future release could add a
  memory feature this page does not predict.
- **Unified-harness session store schema**: the harness backend's store
  (`~/.vibe/logs/session/unified/<uuid>/`) is observed live but its
  `meta.json`/`messages.jsonl` schema was not inspectable; a hook writer
  targeting harness sessions should not assume the legacy schema (per the
  oracle's needs-verification list).
- **`post_agent` payload evolution**: whether newer harness versions add
  fields to the `post_agent` payload is not publicly documented; writers
  should tolerate unknown fields (the hook pipeline itself ignores unknown
  JSON fields, PART-HOOKS section 3.3).
- **Third-party memory products**: no specific memory MCP server or hook
  tool is verified in the oracle. This guide deliberately names none and
  verifies none; the selection criteria in section 3.3 are the transferable
  content.
- **Benchmark figures**: all quantitative claims about memory tools from
  the source survey were cut rather than restated; none are verified for any
  Vibe-compatible tooling.

## See also

- [Context engineering](./context-engineering.md) — the AGENTS.md hierarchy
  and config layering from the budget side
- [Agent harness](./agent-harness.md) — where instruction files sit in the
  four-layer model
- [Loop-graph engineering](./loop-graph-engineering.md) — durable execution
  contracts, of which memory writes are one instance
- [Methodologies](./methodologies.md)
- [Architecture](./architecture.md) — the session store and subagent model
  at full depth
- [Glossary](./glossary.md)
- [Style guide](../style-guide.md)
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md)

See also: [hooks reference](hooks-events-reference.md), [tools reference](tools-reference.md), and the [learning path](../learning-path/README.md). Surfaces pages (desktop and web in depth) are not written yet.
