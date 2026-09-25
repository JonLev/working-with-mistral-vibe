---
title: "Hooks and Events Reference"
description: "The hooks.toml wire protocol: three CLI event types, the stdin/stdout decision contract, matcher syntax, fail-open vs strict, post_agent retries, and the unified-harness six-point hook surface"
tags: [hooks, reference, config, unified-harness]
---

# Hooks and Events Reference

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Hooks are shell commands Vibe runs at fixed points in the agent loop, wired
through `<project>/.vibe/hooks.toml` and `~/.vibe/hooks.toml`. They gate tool
calls, rewrite arguments and results, and retry finished turns. This page is
the full catalog of that surface. Hooks mechanics are live-verified on
2.25.0 (including a live hook run) and anchored to the documented 2.25.8
surface; every mechanic is cited inline against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md) (PART-HOOKS,
PART-HOOKS-UNIFIED, PART-AGENTS).

## TL;DR

- There are exactly three `hooks.toml` event types: `pre_tool`, `post_tool`,
  `post_agent` (PART-HOOKS section 1). The wire protocol runs on both
  backends — the same `hooks.toml` files are loaded by the default backend
  and the experimental harness ([both]; PART-HOOKS section 1 note).
- A hook is a shell command that receives a JSON payload on stdin and
  answers on stdout: exit 0 + empty stdout = passthrough; exit 0 + valid
  JSON = a structured `allow`/`deny` decision; anything else is a hook
  *failure* (PART-HOOKS section 3.3).
- Failure is fail-open by default — a warning, and the gated action
  proceeds. `strict = true` on a tool hook escalates: `pre_tool` failure
  denies the call, `post_tool` failure clears the tool output and stops the
  chain (PART-HOOKS section 3.3).
- There is no blocking exit code. Any non-zero exit is a failure, not a
  deny — a crashing hook blocks nothing unless it is `strict` (PART-HOOKS
  section 3.3).
- `pre_tool` can rewrite the tool arguments; `post_tool` can replace or
  append to the tool result; `post_agent` can deny the turn and inject a
  retry message, at most 3 times per user turn (PART-HOOKS sections 3.3,
  3.7).
- The Unified Harness exposes a separate, typed six-point hook API
  (`pre_agent_turn`, `post_agent_turn`, `pre_llm_call`, `post_llm_call`,
  `pre_tool_call`, `post_tool_call`) — a distinct surface, never merged with
  `hooks.toml` ([unified-harness]; PART-HOOKS-UNIFIED section 6).

*Read if you configure hooks.toml, write hook scripts, gate tool calls, or
need the exact stdin/stdout contract. Skip if you only want the
unified-harness hook points — jump to that section and stop.*

## Quick reference — the three `hooks.toml` events [both]

| Event | Fires when | Matcher | Can block | Can rewrite | Default timeout | Backend |
|---|---|---|---|---|---|---|
| `pre_tool` | Per tool call, before the user permission prompt. First deny short-circuits the remaining `pre_tool` hooks for that call. | `match`, default `*` | Yes — deny marks the call `skipped`, reason wrapped as `<tool_error>` for the LLM | Yes — `tool_input` full replacement | 60 s | [both] |
| `post_tool` | Per tool call, if and only if the tool body actually ran (`tool_status` = `success` / `failure` / `cancelled`) | `match`, default `*` | Yes — deny replaces `tool_output_text` with `reason` | Yes — `additional_context` appended to the result text | 60 s | [both] |
| `post_agent` | Once per turn, after the agent finishes with no pending tool calls | None — `match` and `strict` forbidden | Yes — deny injects `reason` as a new user message, max 3 retries per user turn | No | 60 s | [both] |

`post_tool` does not fire on `pre_tool` denial, user denial at the approval
prompt, permission `NEVER`, or cancellation before the tool body started;
cancellation during the body is shielded so audit hooks still run
(PART-HOOKS section 1).

The six typed hook points of the Unified Harness are a separate surface
([unified-harness], below) — do not merge them into this table.

## `hooks.toml` schema [both]

One `[[hooks]]` table per hook (PART-HOOKS section 2):

| Field | Required | Constraints |
|---|---|---|
| `name` | yes | Unique; the dedupe key across all files |
| `type` | yes | `pre_tool` \| `post_tool` \| `post_agent` |
| `command` | yes | Shell command; must not be blank |
| `match` | tool hooks only | fnmatch glob or `re:` regex; default `*`; validation error on `post_agent` |
| `timeout` | no | Seconds; default 60 for all hooks |
| `strict` | no | Bool, default `false`; tool hooks only; validation error on `post_agent` |
| `description` | no | Free text |

The exact model (PART-HOOKS section 2):

```python
# vibe/core/hooks/models.py
_DEFAULT_HOOK_TIMEOUT = 60.0

class HookConfig(BaseModel):
    name: str
    type: HookType
    command: str
    match: str | None = None
    timeout: float | None = None       # set to _DEFAULT_HOOK_TIMEOUT (60.0) by validator
    strict: bool = False
    description: str | None = None
```

Validators (PART-HOOKS section 2):

- `match` on a `post_agent` hook → error "match is only valid for tool
  hooks (pre_tool / post_tool)".
- `strict` on a `post_agent` hook → error "strict is only valid for tool
  hooks (pre_tool / post_tool)".
- `command` / `match` must not be blank.
- Unknown extra keys in a hook table are tolerated: `load_hooks_from_fs`
  parses with strict off, so a typo'd key parses and then does nothing.

## File locations, load order, and precedence [both]

1. `<project>/.vibe/hooks.toml` — loaded first, **only when the folder is
   trusted**.
2. Each `--add-dir` path contributes its own root-level
   `.vibe/hooks.toml` as an additional project root (trusted implicitly),
   ahead of the user file.
3. `~/.vibe/hooks.toml` — loaded last.

Duplicate `name` across files: the first occurrence (project) wins; the
later one is recorded as a config issue ("Duplicate hook name") and skipped.
Config-load errors (invalid TOML, validation failures) surface as warnings
and the offending hook is skipped — fail-open on config too. Hooks of the
same type fire sequentially in load order; declaration order within each
file (PART-HOOKS sections 1, 3.6).

## Matcher syntax [both]

One `match` field per hook, case-insensitive, two forms (PART-HOOKS section
3.4):

| Form | Example | Semantics |
|---|---|---|
| fnmatch glob (default `*`) | `bash`, `write_file`, `serena_*` | Glob, lowercased on both sides |
| `re:` regex | `re:(linear\|serena)_.*` | `re.IGNORECASE`, requires `fullmatch`; an invalid regex never matches |

Omitting `match` means `*` — every tool. Tool-name conventions for matchers
(PART-HOOKS section 3.4):

| Tool source | Published name | Example |
|---|---|---|
| Built-in tools | bare name | `bash`, `read_file` |
| MCP tools | `{server-alias}_{tool-name}` — alias from `mcp.json`/config or derived from the URL | `serena_search` |
| Connector tools | `connector_{alias}_{tool-name}` | `connector_Google_Drive_search_files` |
| Subagents | all spawns route through `task`; match `task` and read `tool_input.agent` to discriminate | `task` |

## Decision semantics — the stdout contract [both]

A hook answers through stdout only (PART-HOOKS section 3.3):

| Exit | Stdout | Behavior |
|---|---|---|
| 0 | empty | Passthrough — no action |
| 0 | valid JSON object | Structured response (below) |
| 0 | non-empty but non-conforming (free text, broken JSON, JSON scalar/array, schema mismatch) | Hook failure; parse error is the message. Warning by default; escalated under `strict = true` |
| non-zero / timeout / spawn failure | — | Hook failure. Reason taken from stderr, then stdout, then exit code |

The structured response (PART-HOOKS section 3.3):

```python
# vibe/core/hooks/models.py
class HookSpecificOutput(BaseModel):
    model_config = ConfigDict(extra="ignore")
    tool_input: dict[str, Any] | None = None          # pre_tool only
    additional_context: str | None = None             # post_tool only

class HookStructuredResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    decision: Literal["allow", "deny"] = "allow"
    reason: str | None = None
    system_message: str | None = None
    hook_specific_output: HookSpecificOutput = HookSpecificOutput()
```

Effects by event (PART-HOOKS section 3.3):

| Event | `decision: "deny"` | `decision: "allow"` + `hook_specific_output` |
|---|---|---|
| `pre_tool` | Reason wrapped for the LLM as `<tool_error>Tool 'X' was denied by hook 'Y': {reason}</tool_error>`; call marked `skipped`, never executes; first deny short-circuits the chain | `tool_input` (object) = full replacement of the model's arguments (`HookToolInputRewrite`) |
| `post_tool` | `tool_output_text` replaced with `reason` (then `additional_context` appended if also present); pipeline continues, subsequent hooks see the replacement | `additional_context` (string) appended to `tool_output_text` with a `\n` separator |
| `post_agent` | `reason` injected as a new user message (`injected=True`) asking the agent to retry (max 3 per turn) | — |

`system_message` is a UI-only note on the hook end event, in every type; it
does not reach the LLM (PART-HOOKS section 3.3).

Argument rewrite composition (PART-HOOKS section 3.3): rewrites compose
left-to-right — hook N receives `tool_input` as rewritten by hooks 1..N−1.
The rewritten arguments are re-validated against the tool's args model
immediately; the first invalid rewrite aborts the chain and synthesizes a
denial attributed to that hook. Rewritten args are what the permission
prompt displays, what the tool runs with, and what subsequent LLM turns
see.

Unknown JSON fields are tolerated at every level (`extra="ignore"`), and
fields not meaningful for the current hook type are silently ignored. An
absent or `null` `reason` is a valid denial (empty reason string).

**No blocking exit code.** The contract has no special exit code that
blocks a tool call — every non-zero exit routes to the failure path, and
failure is fail-open by default. A hook that crashes instead of printing
JSON does not gate anything; only a printed `{"decision": "deny"}` does
(PART-HOOKS section 3.3).

## Payload fields per event [both]

Every invocation carries the session context on stdin as one UTF-8 JSON
blob, plus `hook_event_name` and the event's fields (PART-HOOKS section
3.2):

```python
# vibe/core/hooks/models.py
class HookSessionContext(BaseModel):
    session_id: str
    transcript_path: str
    cwd: str
    parent_session_id: str | None = None

class PostAgentInvocation(HookSessionContext):
    hook_event_name: Literal["post_agent"] = "post_agent"

class PreToolInvocation(HookSessionContext):
    hook_event_name: Literal["pre_tool"] = "pre_tool"
    tool_name: str
    tool_call_id: str
    tool_input: dict[str, Any]

class PostToolInvocation(HookSessionContext):
    hook_event_name: Literal["post_tool"] = "post_tool"
    tool_name: str
    tool_call_id: str
    tool_input: dict[str, Any]          # post-rewrite
    tool_status: str                    # "success" | "failure" | "cancelled"
    tool_output: dict[str, Any] | None   # serialized result dict; null on failure
    tool_output_text: str                # running text the LLM will see; mutable by prior hooks
    tool_error: str | None
    duration_ms: float
```

Three payload facts worth memorizing (PART-HOOKS section 3.2):

- `transcript_path` is an empty string when session logging is disabled.
- `parent_session_id` is set when the hook runs inside a subagent;
  subagents inherit the parent's hook config, so the same `hooks.toml` files
  load in the child (PART-AGENTS section 9).
- `post_tool`'s `tool_input` is the post-rewrite value — after any
  `pre_tool` rewrite, not what the model originally sent.

Live-captured `pre_tool` payload, verbatim (PART-HOOKS section 5):

```json
{"session_id":"2d9a4db4-3784-86fe-b962-d8b0bc9df71a","transcript_path":"/Users/<user>/.vibe/logs/session/session_20260924_090446_2d9a4db4/messages.jsonl","cwd":"/private/tmp/vibe-hook-test","parent_session_id":null,"hook_event_name":"pre_tool","tool_name":"bash","tool_call_id":"chatcmpl-tool-85bc5a9a4488e66c","tool_input":{"command":"echo hello","timeout":null}}
```

## Handler execution [both]

The handler is a shell command, and only a shell command. The exact
`HookConfig` model above has a single `command` field — there are no
`http`, `mcp_tool`, `prompt`, or `agent` handler types in this surface
(PART-HOOKS sections 2, 3.1). The source guide's richer handler catalog
does not carry over; any wrapper around a remote endpoint is a script you
write and invoke via `command`.

Execution details (PART-HOOKS sections 3.1, 3.5, 3.6):

| Property | Behavior |
|---|---|
| Process | `create_subprocess_shell(..., start_new_session=True)` — its own process group; a timeout kill takes the whole tree |
| Working directory | `cwd` = session cwd |
| Input | Invocation JSON on stdin, one UTF-8 blob |
| Output | stdout capped at 1 MiB; anything beyond the cap is drained and discarded |
| Timeout | 60 s default, per-hook `timeout` override; on timeout the tree is killed and the result routes to the failure path |
| Ordering | Same-type hooks run sequentially in load order per call; tool calls within one LLM turn run concurrently, each with its own serial hook chain |
| Streaming | `pre_tool` events are buffered (they gate execution); `post_tool` / `post_agent` events stream |
| Isolation | Hooks never see or influence each other's exit status; state flows only through the threaded invocation (`tool_input` after rewrite, `tool_output_text` after replacement/append) |

Hook activity surfaces on the UI/JSON wire as typed notices —
`hook_run_started` ("Running hooks"), `hook_started` ("Running hook
{name}"), `hook_completed` (content such as "Denied tool 'bash'",
"Replaced tool result (N chars)", "Appended N chars to tool result",
"Failed, retrying (N retries remaining)"), `hook_run_completed`
(PART-HOOKS section 4).

## `post_agent` deny retries — max 3 per user turn [both]

`_MAX_RETRIES = 3` per hook per user turn (PART-HOOKS section 3.7). A
`post_agent` deny emits the reason as an injected user message so the
model retries the turn; a hook that denies three times in one user turn
gets "Failed, retries exhausted (3/3)" and no more retries for that turn.
The counter resets on every new user message, and a hook that allows
resets its own counter.

## Fail-open vs `strict = true` [both]

| Mode | On hook failure (non-zero exit, timeout, spawn failure, non-conforming stdout) |
|---|---|
| `strict = false` (default) | UI warning; the gated action proceeds |
| `strict = true` (tool hooks only) | `pre_tool` → deny the tool call with the failure reason; `post_tool` → clear `tool_output_text` (empty string) and stop the chain |

A `strict` hook turns every crash, timeout, and typo in your guard script
into a hard gate — set it only on hooks whose failure mode you have tested
(PART-HOOKS section 3.3).

## Unified-harness hook points [unified-harness]

A separate surface: the Unified Harness Session Protocol declares six
typed hook points, registered as serializable `HookDefinition`s via a
`CapabilityRegistrationRegistry` binding ID, like provided tools
(PART-HOOKS-UNIFIED section 6). This is the desktop-bundled harness API
(verified from the public source, the desktop-bundled harness 0.5.1, and the
public `mistralai-vibe-harness` 0.1.4 package, 2026-09-24) — not `hooks.toml`
entries, and not exercisable locally.

| Hook point | Continue | Skip / Deny / Retry |
|---|---|---|
| `pre_agent_turn` | `PreAgentTurnHookContinue(user_content=...)` | `PreAgentTurnHookSkip(reason=[TextContentBlock...])` |
| `pre_llm_call` | `PreLlmCallHookContinue` | `PreLlmCallHookSkip(reason=[...])` |
| `pre_tool_call` | `PreToolCallHookContinue(effective_arguments={...})` — rewrite | `PreToolCallHookSkip(reason=[...])` |
| `post_tool_call` | `PostToolCallHookContinue(tool_result=...)` — result rewrite | — (continue-only; result replacement) |
| `post_llm_call` | `PostLlmCallHookAccept` | `PostLlmCallHookRetry(feedback=...)` / `PostLlmCallHookReject(reason=[...])` |
| `post_agent_turn` | `PostAgentTurnHookAccept` | `PostAgentTurnHookRetry(feedback=...)` / `PostAgentTurnHookReject(reason=[...])` |

Matcher rules differ from `hooks.toml`: `ToolNameHookMatcher(tool_names=[...])`
is allowed only on `pre_tool_call` / `post_tool_call`; every other point
requires `AlwaysHookMatcher()`. Duplicate binding/hook IDs, ambiguous
tool-name matchers, and direct-name collisions are rejected (PART-HOOKS-UNIFIED
section 6).

The two surfaces connect in one place: the CLI `hooks.toml` protocol runs
on both backends, and as of 2.25.1 "hooks now run inside subagents on the
experimental harness, instead of being silently skipped" — a
[unified-harness] fix; on the legacy backend (2.25.0) CLI hooks already ran
in subagents (PART-HOOKS section 1 note; PART-AGENTS section 9). Subagent
hook payloads carry `parent_session_id` in both cases (PART-AGENTS section
9).

## Worked example [both]

The full example from the oracle (PART-HOOKS section 3.8):

```toml
# <project>/.vibe/hooks.toml
[[hooks]]
name = "deny-rm-rf"
type = "pre_tool"
match = "bash"
command = "python ./.vibe/hooks/guard-bash.py"
strict = true
description = "Reject rm -rf and other destructive shell commands."

[[hooks]]
name = "audit-mcp"
type = "pre_tool"
match = "re:(linear|serena)_.*"      # all tools from two MCP servers
command = "./.vibe/hooks/audit.sh"

[[hooks]]
name = "subagent-policy"
type = "pre_tool"
match = "task"                        # all subagent spawns; read tool_input.agent
command = "./.vibe/hooks/check-subagent.sh"

[[hooks]]
name = "append-lint-hint"
type = "post_tool"
match = "write_file"
command = "./.vibe/hooks/lint-hint.sh"   # prints hook_specific_output.additional_context

[[hooks]]
name = "quality-gate"
type = "post_agent"                    # no match/strict allowed
command = "./.vibe/hooks/quality-gate.sh"  # deny + reason → retry user message (max 3)
```

Guard script shape (PART-HOOKS section 3.8):

```python
import json, sys
payload = json.load(sys.stdin)
command = payload.get("tool_input", {}).get("command", "")
if "rm -rf" in command:
    print(json.dumps({
        "decision": "deny",
        "reason": "rm -rf is blocked by the deny-rm-rf hook.",
    }))
    sys.exit(0)
# Passthrough: empty stdout, exit 0.
```

The live test in the oracle ran exactly this shape: a project `pre_tool`
hook denied a `bash` call before any permission prompt, the deny reason
reached the model as a `<tool_error>`-tagged result with status `skipped`,
the `post_tool` hook did not fire for the denied call, and the user-global
`post_agent` hook ran after the turn alongside the project hook —
confirming both the firing conditions and project + user loading in one
session (PART-HOOKS section 5).

## Gotchas

| Gotcha | What actually happens |
|---|---|
| Fail-open default | A broken hook (crash, timeout, bad JSON) emits a UI warning and the gated action proceeds. Do not assume a failing guard script blocks anything (PART-HOOKS section 3.3). |
| No blocking exit code | Exit codes carry no semantics: any non-zero exit is a failure, never a deny. Decisions come only from printed JSON (PART-HOOKS section 3.3). |
| `post_tool` silence on denials | `post_tool` fires only if the tool body ran. On a `pre_tool` deny, a user denial, permission `NEVER`, or pre-body cancellation it never fires — audit pipelines lose those calls unless they also hook `pre_tool` (PART-HOOKS section 1). |
| Duplicate names | The project entry wins; the user-file hook with the same `name` is dropped with a config issue. Renaming is the only way to run both (PART-HOOKS sections 1, 3.6). |
| Tolerated unknown keys | A typo'd field in a hook table parses and does nothing. Same for unknown JSON fields in a hook's printed response (`extra="ignore"`) (PART-HOOKS sections 2, 3.3). |
| Mismatched `hook_specific_output` | `additional_context` on a `pre_tool` hook and `tool_input` on a `post_tool` hook are ignored with a log warning (PART-HOOKS section 3.3). |
| Self-naming in messages | The UI prefixes the hook name automatically ("Running hook {name}"); repeating the hook's own name in `reason` or `system_message` doubles it (PART-HOOKS section 4). |
| No path placeholders | There is no project-dir placeholder variable for hook commands. Handlers run with `cwd` = session cwd — reference scripts relative to it or by absolute path (PART-HOOKS section 3.1). |
| Trust gating | `<project>/.vibe/hooks.toml` loads only when the folder is trusted; in an untrusted cwd your project hooks silently do not exist (PART-HOOKS section 1). |
| Post-rewrite input | `post_tool` sees rewritten `tool_input`, and the permission prompt displays rewritten args — audit logs record what ran, not what the model first sent (PART-HOOKS section 3.3). |
| Timeout blast | On timeout the whole process group is killed; a hook that spawns workers must expect the tree to die with it (PART-HOOKS section 3.5). |

## Known gaps

- **No non-command handler types — and no oracle coverage of any roadmap
  for them.** The exact `HookConfig` model carries a single `command`
  field (PART-HOOKS section 2), so `http` / `mcp_tool` / `prompt` /
  `agent` handlers do not exist in the verified surface (2.25.0 baseline,
  2.25.8 documented surface). Whether a later release adds them is not
  covered; this page does not predict it.
- **Event types beyond the three.** The verified enum has exactly
  `pre_tool`, `post_tool`, `post_agent` (PART-HOOKS section 1, 2.25.0
  baseline). No session-start, session-stop, or notification hook types are
  recorded in the oracle; if 2.25.8+ added any, this page does not cover
  them.
- **Unified-harness points not exercisable locally.** The six-point table
  rests on public-source verification only (the public
  `mistralai-vibe-harness` 0.1.4 package and the desktop-bundled harness
  0.5.1); the oracle could not run it. How an end user registers a
  `HookDefinition` outside the desktop bundle / harness SDK, and the full
  per-point payload schemas beyond the decision types, are not recorded.
- **Hook process environment.** The oracle records stdin payload, stdout
  cap, cwd, and process group, but not which environment variables a hook
  process receives beyond the inherited environment. Scripts relying on
  injected variables are unverified.
- **Concurrency limits.** Hook chains run in parallel across concurrent
  tool calls (PART-HOOKS section 3.6), but the oracle records no cap on
  concurrent hook subprocesses. Hooks that saturate a shared resource
  (lock files, an external API) should assume no built-in throttling
  exists — unverified either way.
- **Live baseline vs documented surface.** All PART-HOOKS mechanics were
  live-verified on 2.25.0; the documented surface is 2.25.8. Any behavior
  that changed between the two is visible only in the release notes, and
  the oracle records one such delta (the 2.25.1 subagent-hooks fix,
  [unified-harness]).

## See also

- [Tools reference](tools-reference.md) — the tool surface hooks match
  against, including MCP and connector published names
- [Settings reference](settings-reference.md) — config.toml and the
  trust model that gates project hook loading
- [Agents and skills reference](agents-and-skills-reference.md) — the
  `task` subagent surface the `match = "task"` pattern intercepts
- [Plugins](plugins.md) — MCP servers and connectors, the tool sources
  behind `{alias}_{tool}` matcher names
- [Skill design patterns](skill-design-patterns.md) — pattern 8 (runtime
  prompt logging) builds on this wire protocol
- [Agent harness](agent-harness.md) — where hooks sit in the four-layer
  model
- [Architecture](architecture.md) — the session store behind
  `transcript_path`
- [Memory systems](memory-systems.md) — hook-driven durable writes
- [Glossary](glossary.md)
- [Style guide](../style-guide.md)
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md) —
  PART-HOOKS, PART-HOOKS-UNIFIED, PART-AGENTS section 9
