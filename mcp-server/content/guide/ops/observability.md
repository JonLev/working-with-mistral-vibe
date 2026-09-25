---
title: "Session Observability: Logs, Resume, Audit, and Cost"
description: "What the Vibe CLI records by itself (session store, harness log, OTel), how to find and resume sessions, how to add a hook-based activity logger, and how to read the logs for quality and cost."
tags: [guide, observability, ops, cli]
---

# Session Observability: Logs, Resume, Audit, and Cost

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Every command, flag, config key, file path, and payload field here cites the mechanics
> oracle, [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as
> `(PART-XXX)`. Claims executed against the installed CLI are marked *live-verified on
> 2.25.7* and cite
> [`docs/mechanics/live-checks.md`](../../docs/mechanics/live-checks.md);
> the oracle's own live transcripts (vibe 2.25.0) are attributed where quoted. The
> rest is source-verified at release 2.25.8.
Everything below is readable with the session store and standard shell tooling.
> **TL;DR.** Vibe writes a session store under `$VIBE_HOME/logs/session/` — one
> directory per session with a fully documented `meta.json` and a `messages.jsonl`
> transcript — plus a harness log at `$VIBE_HOME/logs/vibe.log` and an optional
> OpenTelemetry export. Resume rides on the store: `vibe -c` (cwd-scoped),
> `vibe --resume <id>` (global, partial IDs OK), `/resume` in-session. For
> tool-level audit the verified path is a `post_tool`/`post_agent` hook that appends
> the stdin payload to your own JSONL; cost control is `--max-price` / `--max-tokens`
> in programmatic mode, with per-model price fields feeding the cap.

**Read if** you need to find an old session, audit what an agent actually did, add
activity logging, or reason about spend. **Skip if** you only want the interactive
basics; [settings reference](../core/settings-reference.md) and
[architecture](../core/architecture.md) cover those.

## Observability by harness layer

Ported principle from the source guide, and the one worth keeping ahead of any
product mechanic: **capture evidence at the layer that made the decision.** A
dashboard that reports only tokens cannot establish whether the loop behaved
correctly. A runtime harness needs traces of model calls, tool calls, permissions,
and recovery; the trace must reconstruct why work moved, waited, repeated, or
stopped. The layering itself is [Agent Harness
Engineering](../core/agent-harness.md); loop contracts and stopping rules are
[Loop & Graph Engineering](../core/loop-graph-engineering.md).

Vibe gives you three native capture points, each at a different layer:

| Capture point | Layer | What it records | Backend |
|---|---|---|---|
| Session store (`meta.json` + `messages.jsonl`) | Session graph | Who, where, which model, which branch, what spawned what | [stable] |
| Hooks (`post_tool`, `post_agent`) | Tool call / turn | Every executed tool call and every finished turn, as a JSON payload you control | [stable] |
| OTel export (`enable_otel`) | Telemetry | Traces shipped to an OTLP/HTTP endpoint | [stable] |

Use stable event names and version every field that can change behavior. Treat
prompt text, tool arguments, tool results, file paths, and user identifiers as
sensitive payloads: redact or hash before export, and document which fields were
dropped. `otel_redaction` exists for exactly this on the OTel path (PART-CONFIG
§1.8); for your own hook logs, you are the redactor.

## What Vibe writes by itself

| Surface | Location | Contents | Citation |
|---|---|---|---|
| Session store | `$VIBE_HOME/logs/session/<prefix>_<YYYYMMDD_HHMMSS>_<id8>/` | `meta.json` + `messages.jsonl` | PART-SESSIONS §3.1 |
| Session index | `$VIBE_HOME/logs/session/.session_index.json` | Listing cache, reconciled against each `meta.json` mtime; corrupt index rebuilds | PART-SESSIONS §3.1 |
| Last-session pointer | `$VIBE_HOME/logs/session/.last_session/<tty>` | Per-terminal pointer used by `vibe -c` | PART-SESSIONS §3.1-3.2 |
| Harness log | `$VIBE_HOME/logs/vibe.log` | CLI diagnostics (not the conversation), rotated at `LOG_MAX_BYTES` (default 10485760) | PART-CLI |
| OTel traces | your collector, or Mistral's telemetry endpoint if `otel_endpoint` is empty | Model/tool spans (field names not oracle-verified — see [Known gaps](#known-gaps)) | PART-CONFIG §1.8 |

Default `$VIBE_HOME` is `~/.vibe` (PART-CLI). Session logging is controlled by
`[session_logging]` in `config.toml` and is **required for resume**:

```toml
[session_logging]
enabled = true          # default; disabling raises "Session logging is disabled.
                         # Enable it in config to use --continue or --resume"
save_dir = ""            # defaults to ~/.vibe/logs/session; ~ expanded + resolved
session_prefix = "session"
generate_titles = true   # background LLM titles (off = first-message preview)
```

(PART-CONFIG §1.9; the resume error text is PART-SESSIONS §3.3.) Note that
docs.mistral.ai's `log_interactions` key does not exist in the 2.25.0/2.25.8
source — the field is `session_logging.enabled` (oracle docs-drift ledger, item 2).

The harness log and the session store answer different questions. `vibe.log` is
diagnostics; the conversation evidence lives in the session store. `/log` prints
the path to the current log file and `/log-level [LEVEL]` changes the level for
the session or persists it to `config.toml` — the same levels as the `LOG_LEVEL`
env var (DEBUG, INFO, WARNING, ERROR, CRITICAL) and the `log_level` config key
(PART-CLI; PART-COMMANDS §2).

## The session store: graph-level fields

The source guide's graph-level observability table ports cleanly, because Vibe's
`meta.json` already records the graph fields a coding harness needs. Every field
below is verified (PART-SESSIONS §3.1, live-verified against 2.25.0):

| Field | Question it answers |
|---|---|
| `session_id`, `parent_session_id` | Which session is this, and was it spawned by another? |
| `child_sessions` | What did this session dispatch (subagents, loops)? |
| `loops` | What recurring prompts are scheduled (`ScheduledLoop`: id, interval_seconds, prompt, next_fire_at, created_at), and did they survive resume? |
| `git_commit`, `git_branch` | What workspace state did the session run against? |
| `environment.working_directory`, `origin_directory` | Where does the session reach, and where did it begin? (Both make a moved session findable from either directory.) |
| `config` | Which policy governed the run — session-scoped config snapshot, starting with the pinned `active_model` alias |
| `agent_profile` | Which agent profile ran the session |
| `title`, `title_source` | What is this session called (`"auto"` or `"manual"` via `/rename`)? |
| `start_time`, `end_time`, `total_messages` | How long, and how much conversation? |
| `stats` | Session statistics (field verified; contents not itemized in the oracle — do not write queries against its subfields) |
| `system_prompt`, `tools_available` | What instructions and tool surface were in effect |
| `created_worktree`, `import_provenance`, `username`, `experiments` | Worktree origin, import origin, OS user, experiment variants |

`messages.jsonl` is one JSON object per message; the oracle verifies the
line-per-message shape and the `total_messages` cross-check, but **not** the
per-message field schema (see [Known gaps](#known-gaps)). Do not write jq against
message-internal fields and call it fact; use the hook logger below instead.

A zero-dependency session catalog, built only from verified fields:

```bash
# List sessions: title | branch | pinned model | message count
for d in "$HOME/.vibe/logs/session"/session_*/; do
  jq -r '[.title, .git_branch, .config.active_model, .total_messages] | @tsv' \
    "$d/meta.json"
done

# Find sessions mentioning a topic (titles are auto-generated LLM titles
# or manual /rename titles — PART-SESSIONS §3.4)
grep -l "migration" "$HOME/.vibe/logs/session"/*/meta.json
```

## Finding and resuming sessions

| Mechanism | Scope | Behavior | Citation |
|---|---|---|---|
| `vibe -c` / `--continue` | Per-terminal, then cwd | Uses the per-TTY last-session pointer if it reaches the current cwd; else the most recent session in the cwd; errors otherwise | PART-SESSIONS §3.2 |
| `vibe --resume <SESSION_ID>` | Global | Resolves by ID with no working-directory filter; partial/short IDs supported; multiple matches take the latest | PART-SESSIONS §3.3 |
| `vibe --resume` | Picker | Interactive session picker; in programmatic (`-p`) mode a bare `--resume` is an error — pass an ID | PART-SESSIONS §3.3 |
| `/resume` (alias `/continue`) | In-session picker | Folder-scoped listing sorted by `updated_at`; `D` twice deletes a listed local session (never the active one) | PART-SESSIONS §3.3; PART-COMMANDS §2 |
| `/branch` | Session fork | Forks the conversation into a new resumable session, leaving the current one unchanged; resume the copy with `vibe --resume <id>` — documented in release 2.25.8, not live-run | PART-COMMANDS deltas |

Folder scoping is a session-matches rule, not an encoded path: a session reaches a
directory if either `origin_directory` or `environment.working_directory` equals
the launch directory, so a moved session is offered from both where it began and
where it sits (PART-SESSIONS §3.2). Worktree sessions are directory-scoped the
same way; to carry a session across worktrees, resume explicitly by ID
(PART-WORKTREES; PART-SESSIONS §3.3).

The source guide's community search tools and cross-folder migration recipes are
dropped: they are keyed to another tool's JSONL layout and paths, none of which
exist here. The genre survives in the `grep`/`jq` catalog above, written only from
the PART-SESSIONS §3.1 schema.

## A hook logger: tool-level capture

There is no session-start hook; `post_tool` and `post_agent` are the verified
capture points (PART-HOOKS §1-3.2). A `post_tool` hook fires per tool call *if and
only if the tool body actually ran* (`tool_status` = `success` / `failure` /
`cancelled`); a `post_agent` hook fires once per finished turn. Both receive a
JSON payload on stdin (PART-HOOKS §3.2, live-captured on 2.25.0):

```json
{
  "session_id": "2d9a4db4-3784-86fe-b962-d8b0bc9df71a",
  "transcript_path": "/Users/<user>/.vibe/logs/session/session_20260924_090446_2d9a4db4/messages.jsonl",
  "cwd": "/private/tmp/vibe-hook-test",
  "parent_session_id": null,
  "hook_event_name": "pre_tool",
  "tool_name": "bash",
  "tool_call_id": "chatcmpl-tool-85bc5a9a4488e66c",
  "tool_input": {"command": "echo hello", "timeout": null}
}
```

`post_tool` additionally carries `tool_status`, `tool_output`, `tool_output_text`,
`tool_error`, and `duration_ms` (PART-HOOKS §3.2). Register a logger and it is a
direct port of the source guide's activity logger — append the payload to your
own JSONL:

```toml
# ~/.vibe/hooks.toml (or <project>/.vibe/hooks.toml — project loads first)
[[hooks]]
name = "activity-logger"
type = "post_tool"
command = "$HOME/.vibe/hooks/activity-logger.sh"

[[hooks]]
name = "turn-logger"
type = "post_agent"          # no match/strict allowed on post_agent
command = "$HOME/.vibe/hooks/activity-logger.sh"
```

```bash
#!/usr/bin/env bash
# ~/.vibe/hooks/activity-logger.sh — append the raw hook payload as one JSON line.
# Empty stdout + exit 0 = passthrough (PART-HOOKS §3.3).
mkdir -p "$HOME/.vibe/logs/activity"
cat >> "$HOME/.vibe/logs/activity/$(date +%Y-%m-%d).jsonl"
```

Two properties matter, both verified:

- **`post_tool` misses denied calls by design.** It fires only when the body ran
  (PART-HOOKS §1); a `pre_tool` denial or permission-`never` never reaches it. If
  you need denials too, add a `pre_tool` hook on the same pattern — it sees
  `tool_name` and `tool_input` before execution (PART-HOOKS §3.2).
- **Hooks are fail-open by default, and loggers should stay that way.** A broken
  logger emits a UI warning and the tool call proceeds — you lose a log line, not
  the work. Do not set `strict = true` on a logger: a crashed strict hook *denies
  the tool call* (live-verified on 2.25.7, T2 in
  [`live-checks.md`](../../docs/mechanics/live-checks.md); T3 shows
  the fail-open default letting the tool run). `strict` is for guards, not
  observers (PART-HOOKS §3.3).

Privacy follows from the payload: `tool_input` for file tools carries file
contents (`write_file` logs the full content being written), and
`tool_output_text` carries tool results. If you sync these logs anywhere, redact
first — the same caution the source guide attaches to proxied traffic applies to
your own hook logs.

## Log analysis for quality, not just quantity

Token counts tell you how much you used the agent. The three quality signals below
are ported from the source guide and rebuilt on the logger's JSONL, whose fields
are all payload-verified (PART-HOOKS §3.2):

**Repeated reads of the same file.** If the agent reads the same file three or
more times in a session, the content it needs is probably not where it expects to
find it — move it into an `AGENTS.md` section or a skill (see [Memory
Systems](../core/memory-systems.md)).

```bash
# Files read 3+ times across captured activity
jq -r 'select(.tool_name == "read_file") | .tool_input.file_path' \
  "$HOME/.vibe/logs/activity"/*.jsonl \
  | sort | uniq -c | sort -rn | awk '$1 >= 3'
```

**Failing commands.** A `bash` command that fails repeatedly across sessions
usually means an outdated path or renamed binary in a skill or instruction file.
`tool_input.command` is the verified key for `bash` (live-captured payload,
PART-HOOKS §3.2 and §3.8).

```bash
jq -r 'select(.hook_event_name == "post_tool" and .tool_status == "failure")
       | .tool_input.command' \
  "$HOME/.vibe/logs/activity"/*.jsonl | sort | uniq -c | sort -rn | head
```

**High edit frequency on the same file.** Heavily edited files across sessions
are a proxy for missing context — the file's purpose or the conventions around
it are not documented.

```bash
jq -r 'select(.tool_name == "edit" or .tool_name == "write_file")
       | .tool_input.file_path' \
  "$HOME/.vibe/logs/activity"/*.jsonl | sort | uniq -c | sort -rn | head
```

One caveat, stated once: the oracle verifies `tool_input` as a dict and the
`command` key for `bash`; the `file_path` key for the file tools is from the
installed-package schema dump documented on the [tools
reference](../core/tools-reference.md) page (vibe 2.25.7, 2026-09-24) — check one
captured payload from your own install before building further queries on it.

For each pattern you surface, ask the same question the source guide asks: is
there an instruction, skill, or `AGENTS.md` section that should cover this?

## Sensitive patterns worth auditing

The hook log is an audit trail of what the agent actually did. Patterns worth
flagging in a scheduled audit:

| Pattern | Why it matters | Verified grounding |
|---|---|---|
| `read_file` (or `bash`) on `.env`, keys, credentials | Default `sensitive_patterns` force approval on `.env*` — but approval can be granted, and a `read_file` denylist alone does not protect a file: `bash` can read the same path (live-verified on 2.25.7, T5 and T7 in [`live-checks.md`](../../docs/mechanics/live-checks.md)) | PART-PERMISSIONS §4.3-4.4 |
| Destructive `bash` commands (`rm -rf`, force-push) | Blast radius is your filesystem and remotes; per-tool `denylist` prefixes are the native control | PART-CONFIG §1.3; PART-PERMISSIONS §4.4 |
| Tool calls on paths outside the session workspace | Scope creep; `--add-dir` widens it per session | PART-CLI; PART-TRUST §3.3 |

The cross-tool bypass finding (T5) is the reason to audit rather than assume: a
`[tools.read_file]` denylist denied the read on one turn and the agent read the
same file through `bash` (`cat`) on the next. Audit the whole log, per tool, not
one tool's policy.

## Cost tracking

Verified cost surfaces:

| Surface | What it does | Citation |
|---|---|---|
| `--max-price DOLLARS` | Session cost cap; the session is interrupted if cost exceeds it. **Programmatic mode (`-p`) only** | PART-CLI |
| `--max-tokens N` | Cap on total prompt + completion tokens across the session, same interruption and same `-p`-only scope | PART-CLI |
| `input_price` / `output_price` / `cached_input_price` | Per-million-token floats on each `[[models]]` entry; they feed the `--max-price` cap. `cached_input_price = null` bills cache hits at `input_price` | PART-CONFIG §1.1 |
| `/status` | "Display agent statistics" in-session | PART-COMMANDS §2 |
| `meta.json` `stats` + `config.active_model` | Per-session statistics field and the pinned model that produced them | PART-SESSIONS §3.1, §3.5 |

Actual Mistral token prices are not in the oracle, so this guide states none. The
estimation method, with reader-supplied rates: cost ≈ (input tokens × per-million
input price + output tokens × per-million output price), using prices from the
provider's public pricing page, dated, and the token counts from your provider
usage or the session's `stats`. Treat the result as directional, not accounting.

Budget caps in interactive sessions are not a verified native feature — the caps
are `-p`-mode flags. For interactive budgeting, the honest options are the hook
logger plus an external check, or scheduled review of the session catalog.

## OTel export

[stable] All keys PART-CONFIG §1.8:

```toml
enable_telemetry = true     # master switch; docs describe anonymous usage/error telemetry
enable_otel = false         # OTel trace export — REQUIRES enable_telemetry
otel_endpoint = ""          # OTLP/HTTP base URL; vibe appends /v1/traces;
                            # empty = Mistral's telemetry endpoint
otel_redaction = "default" # "default" | "none" | "strict"
```

> **Blast radius of the empty default:** with `enable_otel = true` and an empty
> `otel_endpoint`, traces go to Mistral's telemetry endpoint, not yours. Point
> `otel_endpoint` at your own collector before enabling it if that matters, and
> pick `otel_redaction = "strict"` when the payloads are sensitive.

What the traces contain — span names and attributes — is not in the oracle; only
the config keys are. The team-aggregation recipes from the source guide (central
collector, dashboards) remain valid generically, but any query keyed to specific
span fields is unverified here until you inspect one export from your own
collector.

## Proxy and TLS observation

Vibe has an in-session `/proxy-setup` command ("Configure proxy and SSL
certificate settings") and an `enable_system_trust_store` config key (loads the
OS trust store into the CLI's SSL context) — PART-COMMANDS §2; PART-CONFIG §1.10.
The source guide's Node-specific proxy mechanics are dropped: they describe
another tool's TLS stack and do not port. The privacy note survives unchanged in
substance: anything that observes the model wire sees the full conversation
context — file contents the agent has read, your code, and any secret it
encountered.

## Known gaps

- **`messages.jsonl` per-message schema** — the oracle verifies the
  line-per-message shape and the `total_messages` cross-check only. Message-level
  field queries (the source guide's audit recipes against vendor message objects)
  do not port as fact; the hook logger is the verified substitute.
- **Unified-harness session store** — `~/.vibe/logs/session/unified/<uuid>/`
  exists on a live install (full-UUID harness sessions), but whether it shares
  the `meta.json`/`messages.jsonl` schema is UNVERIFIED-PUBLIC. Do not write
  tooling against it yet.
- **`meta.json` `stats` contents** — the field is verified; its subfields are not
  itemized in the oracle. Same for the OTel span field names.
- **Token/cost readout** — no verified in-CLI command reports token counts or
  spend; `/status` displays "agent statistics" (verbatim description) but the
  oracle does not itemize what it shows. Mistral token prices are not in the
  oracle; the cost method above deliberately uses reader-supplied rates.
- **`/branch`** — documented in release 2.25.8 source, not live-run; treat as
  released, not as battle-tested.
- **What `enable_telemetry` sends** — the key is verified; "anonymous usage/error
  telemetry" is the docs' description, not an inspected payload.

## See also

- [Hooks and events reference](../core/hooks-events-reference.md) — the full hook
  wire protocol, matchers, and decision contract; this page uses only the logger
  slice
- [Architecture and internals](../core/architecture.md) — where the session
  store sits in the loop
- [Settings reference](../core/settings-reference.md) — every `config.toml` key
  used here, in one place
- [Tools reference](../core/tools-reference.md) — per-tool parameter names
  (schema dump, 2.25.7) for building tool-specific log queries
- [Memory systems](../core/memory-systems.md) — where the quality signals you
  surface should land (instructions, skills)
- [Task management](../workflows/task-management.md) — session resume as a
  continuity mechanism, and `/loop` scheduling
- Planned: the security pages (permission hardening, audit trails) — the T5/T7
  findings cited above will live there in full
- The mechanics oracle: [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md);
  live checks: [`live-checks.md`](../../docs/mechanics/live-checks.md)
