---
title: "Module 06: Hooks and Events"
description: "Learning Path Module 06: register Vibe hooks in hooks.toml, make tool decisions with stdout JSON from pre_tool, post_tool, and post_agent hooks, choose a failure posture with strict, and test a deny guard with three fixtures before running it live. ~75 min, Practitioner track."
tags: [learning-path, hooks, hooks-toml, pre-tool, post-tool, post-agent, strict, fail-open, unified-harness]
---

# Module 06: Hooks and Events

**Time:** ~75 min · **Complexity:** ★★★☆☆ · **Track:** Practitioner

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics on this page are cited inline as (PART-XXX) against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md). Anything the
oracle could not verify from public sources is in [Known gaps](#known-gaps),
never in the body. Structure and pedagogy are adapted from the source guide;
every mechanic is rebuilt from the oracle.

## TL;DR

- A Vibe hook is a shell command registered in a `hooks.toml` file, not a
  prompt file or a config key. Project hooks live in
  `<project>/.vibe/hooks.toml` (trusted roots only), user hooks in
  `~/.vibe/hooks.toml`; the project file loads first and wins on duplicate
  names (PART-HOOKS §1).
- There are exactly three event types: `pre_tool` (before the permission
  prompt; first deny short-circuits the remaining hooks for that call),
  `post_tool` (only if the tool body actually ran), and `post_agent` (once per
  turn; `match` and `strict` are forbidden on it) (PART-HOOKS §1).
- The wire protocol is JSON in, JSON out. The hook receives one JSON object
  on stdin; its decision is a JSON object on stdout with `decision`,
  `reason`, `system_message`, and `hook_specific_output`. **Exit codes carry
  no decision semantics** — there is no "exit 2 blocks" convention here
  (PART-HOOKS §3.2-§3.3).
- Hooks **fail open by default**: a non-zero exit, a timeout, or
  non-conforming stdout produces a warning and the gated action proceeds.
  Fail-closed exists only via `strict = true` on tool hooks — `pre_tool`
  failure then denies, `post_tool` failure clears the output (PART-HOOKS
  §3.3). Decide your failure posture explicitly.
- A `pre_tool` allow can also **rewrite** the call (`hook_specific_output.tool_input`);
  a `post_tool` allow can **append** context (`additional_context`). A
  `post_agent` deny injects a retry user message, capped at 3 retries per
  turn (PART-HOOKS §3.3, §3.7).
- The Unified Harness is a second, separate hook surface with six typed hook
  points — never one list with the CLI's three **[unified-harness]**
  (PART-HOOKS-UNIFIED §6).

*Read if you want machine-enforced policy around tool calls — blocking
destructive commands, rewriting arguments, appending context, or gating turn
endings — and you are willing to test it before relying on it. Skip if the
per-tool permission system already covers your policy: start with
`[tools.<tool>]` `permission`/`allowlist`/`denylist` in `config.toml`
(PART-CONFIG section 1.3; PART-PERMISSIONS section 4), and reach for hooks
only for what it cannot express.*

## Goal

Add one Vibe hook that makes a tool decision from structured input, has an
explicitly chosen failure posture, and can be tested without starting an
interactive session.

Vibe hooks are not Git hooks. Git hooks respond to repository actions such as
`pre-commit`. Vibe hooks respond to the agent loop: tool calls and turn
boundaries (PART-HOOKS §1).

## What You'll Learn

- where Vibe reads hook registration from, and in which order
- the three hook events and exactly when each fires
- what a hook receives on standard input
- how a `pre_tool` hook allows, denies, or rewrites a call
- why the default failure posture is fail-open, and what `strict` changes
- how to test a decision script with fixed fixtures, then verify runtime
  loading separately

---

## The Three Events

A hook is a shell command Vibe launches per event. The command runs in the
session's working directory, in its own process group, receives one JSON
object on stdin, and answers on stdout — capped at 1 MiB (PART-HOOKS §3.1).
Only three event types exist **[stable]**:

| `type` | Fires | Key semantics |
|---|---|---|
| `pre_tool` | Per tool call, **before the user permission prompt** | First `deny` short-circuits the remaining `pre_tool` hooks for that call |
| `post_tool` | Per tool call, **iff the tool body ran** (`tool_status` = `success` / `failure` / `cancelled`) | Does not fire on `pre_tool` denial, user denial, permission `never`, or cancellation before the body started |
| `post_agent` | Once per turn, after the agent finishes with no pending tool calls | `match` and `strict` are forbidden on it — validation error |

(PART-HOOKS §1)

The full lifecycle in one diagram:

```text
Model proposes a bash call
             |
             v
pre_tool hooks run (before the permission prompt)
             |
             v
First deny short-circuits; an allow may rewrite tool_input
             |
             v
Permission gate, then the tool body runs
             |
             v
post_tool hooks run (only because the body ran)
             |
             v
Turn ends with no pending calls -> post_agent hooks run once
```

(PART-HOOKS §1, §3.3)

Keep the decision narrow. A command guard can decide whether a proposed shell
command matches a dangerous pattern. It cannot prove the rest of the session
is safe — the permission system, agent profiles, and trust gate are separate
controls (PART-PERMISSIONS section 4; PART-AGENTS section 8).

---

## Registration: `hooks.toml`

Hook registration lives in dedicated `hooks.toml` files, loaded in this
order (PART-HOOKS §1):

1. `<project>/.vibe/hooks.toml` — loaded first, **only when the folder is
   trusted**
2. `.vibe/hooks.toml` at the root of each `--add-dir` path (trusted
   implicitly), still ahead of the user file
3. `~/.vibe/hooks.toml` — the user file, loaded last

A duplicate `name` across files resolves to the **first** (project) entry;
the later one is recorded as a config issue and skipped (PART-HOOKS §1, §3.6).

Each entry is a `[[hooks]]` table:

| Key | Required | Meaning | Default |
|---|---|---|---|
| `name` | Yes | Unique; the dedupe key across files | — |
| `type` | Yes | `pre_tool` \| `post_tool` \| `post_agent` | — |
| `command` | Yes | Shell command; must not be blank | — |
| `match` | Tool hooks only | fnmatch glob or `re:` regex over tool names | `"*"` (every tool) |
| `timeout` | No | Seconds | `60` |
| `strict` | Tool hooks only | Escalates hook *failure* to deny/clear | `false` |
| `description` | No | Free text | — |

(PART-HOOKS §2). `match` or `strict` on a `post_agent` entry is a validation
error, and the hook is skipped at load (PART-HOOKS §2, §3.6).

---

## The Wire Protocol

### What arrives on stdin

Every invocation carries the session context plus `hook_event_name`, then
event-specific fields (PART-HOOKS §3.2):

| Field | Events | Meaning |
|---|---|---|
| `session_id` | all | Session identifier |
| `transcript_path` | all | Path to the session's `messages.jsonl`; empty string when session logging is disabled |
| `cwd` | all | Session working directory |
| `parent_session_id` | all | Set when the hook runs inside a subagent; `null` otherwise |
| `hook_event_name` | all | `pre_tool` \| `post_tool` \| `post_agent` |
| `tool_name` | `pre_tool`, `post_tool` | Tool being called |
| `tool_call_id` | `pre_tool`, `post_tool` | Call identifier |
| `tool_input` | `pre_tool`, `post_tool` | The call's arguments; on `post_tool`, the **post-rewrite** value |
| `tool_status` | `post_tool` | `success` \| `failure` \| `cancelled` |
| `tool_output` | `post_tool` | Serialized result dict; `null` on failure |
| `tool_output_text` | `post_tool` | The text the model will see; mutable by prior hooks |
| `tool_error` | `post_tool` | Error string or `null` |
| `duration_ms` | `post_tool` | Body duration |

The oracle's live-captured `pre_tool` payload, verbatim (PART-HOOKS §5):

```json
{"session_id":"2d9a4db4-3784-86fe-b962-d8b0bc9df71a","transcript_path":"/Users/<user>/.vibe/logs/session/session_20260924_090446_2d9a4db4/messages.jsonl","cwd":"/private/tmp/vibe-hook-test","parent_session_id":null,"hook_event_name":"pre_tool","tool_name":"bash","tool_call_id":"chatcmpl-tool-85bc5a9a4488e66c","tool_input":{"command":"echo hello","timeout":null}}
```

### What the hook answers on stdout

The decision is **stdout JSON**, not exit codes:

| Exit | Stdout | Result |
|---|---|---|
| `0` | empty | Passthrough — no action |
| `0` | valid JSON object | Structured response applied (below) |
| `0` | non-conforming (free text, broken JSON, JSON scalar/array, schema mismatch) | Hook **failure** |
| non-zero / timeout / spawn failure | — | Hook **failure** |

(PART-HOOKS §3.3)

The structured response schema — every field optional, unknown fields
ignored:

| Field | Type | Effect |
|---|---|---|
| `decision` | `"allow"` (default) \| `"deny"` | The verdict |
| `reason` | string | Denial/rewrite rationale; reaches the model |
| `system_message` | string | UI-only note on the hook end event, every type |
| `hook_specific_output.tool_input` | object | `pre_tool` only: full replacement of the call's arguments |
| `hook_specific_output.additional_context` | string | `post_tool` only: appended to the tool output text |

What each decision does per type:

| Type | `deny` effect | `allow` + `hook_specific_output` |
|---|---|---|
| `pre_tool` | Call marked `skipped`, never executes; `reason` reaches the model wrapped as a `<tool_error>` naming the hook; first deny short-circuits remaining `pre_tool` hooks | `tool_input` **replaces** the model's arguments, is re-validated against the tool's args model immediately (first invalid rewrite aborts the chain with a denial), and composes left-to-right across hooks |
| `post_tool` | `tool_output_text` is **replaced** with `reason` (then `additional_context` appended if present); the chain continues — subsequent hooks see the replacement | `additional_context` is appended to `tool_output_text` with a newline separator |
| `post_agent` | `reason` is injected as a new user message asking the agent to retry | — |

(PART-HOOKS §3.3). `additional_context` on a `pre_tool` hook and `tool_input`
on a `post_tool` hook are ignored with a log warning (PART-HOOKS §3.3).

Do not import Unix conventions from other tools: no exit code blocks a call
here. If you remember an "exit 2 blocks" rule from elsewhere, it does not
transfer — a non-zero exit is simply a hook failure, with the fail-open
consequences below (PART-HOOKS §3.3).

---

## Failure Posture: Fail-Open by Default

This is the safety-critical fact about Vibe hooks: **a failing hook does not
stop anything by default.** Non-zero exit, timeout, or non-conforming stdout
emits a UI warning and the gated action **proceeds** (PART-HOOKS §3.3).

| Failure of | `strict = false` (default) | `strict = true` |
|---|---|---|
| `pre_tool` hook | Warning; the call proceeds | **Deny** the call with the failure reason |
| `post_tool` hook | Warning; output unchanged | **Clear** `tool_output_text` and stop the chain |
| `post_agent` hook | Warning (no `strict` allowed) | — |

(PART-HOOKS §3.3)

Two distinct mechanisms produce fail-closed behavior — do not conflate them:

1. **A structured `deny` from your script.** Valid JSON on stdout, exit 0.
   This is honored in every mode, including `strict = false`. If your script
   cannot validate its input, it can still print a `deny` decision and exit 0.
2. **`strict = true`.** This only governs *failures* — crash, timeout,
   non-conforming stdout. It converts them into a deny (`pre_tool`) or an
   output clear (`post_tool`).

A guard that must block should do both: emit an explicit `deny` for inputs it
understands and rejects, and carry `strict = true` so that its own crash
cannot silently open the gate (PART-HOOKS §3.3).

Timeouts feed the same failure path: the default is 60 seconds per hook, a
timeout kills the whole process tree, and the result routes to failure —
warning by default, deny/clear only under `strict` (PART-HOOKS §3.5).

---

## Matchers

`match` selects calls by **tool name**, case-insensitive, in two forms
(PART-HOOKS §3.4):

| Form | Example | Meaning |
|---|---|---|
| fnmatch glob | `bash`, `write_*`, `*` (the default) | Glob match over the tool name |
| `re:` prefix | `re:serena_.*` | Regex, `re.IGNORECASE`, **full match** — invalid regex never matches |

An alternation over several sources works too, e.g. `re:(linear|serena)_.*`
for all tools from two MCP servers (PART-HOOKS §3.4).

Tool-name conventions for patterns (PART-HOOKS §3.4):

| Tool | Name to match |
|---|---|
| Built-in tools | Bare name: `bash`, `read_file`, `write_file`, ... |
| MCP tools | `{server-alias}_{tool-name}` |
| Connector tools | `connector_{alias}_{tool-name}` |
| Subagent spawns | `task` — every spawn routes through the `task` tool; read `tool_input.agent` to discriminate |

Keep the matcher as narrow as the policy: a `bash` guard matching `"*"` will
parse `tool_input` shapes it was never written for.

---

## `post_agent` and the Retry Loop

A `post_agent` hook runs once per turn, after the agent finishes with no
pending tool calls. Its `deny` does not undo anything — the `reason` is
injected as a new user message so the model retries the turn. The retry
budget is **3 per user turn**: a hook that denies three times in one turn
gets "Failed, retries exhausted (3/3)" and no more retries. The counter
resets on every new user message, and a hook that allows resets its own
counter (PART-HOOKS §3.7). The notices you will see: "Failed, retrying (N
retries remaining)" and "Failed, retries exhausted (3/3)" (PART-HOOKS §4).

This is the mechanism behind turn-ending quality gates — and the reason a
buggy `post_agent` hook can quietly burn three retries every turn.

---

## A Second Surface: the Unified Harness

**[unified-harness]** The Unified Harness runtime declares its own, separate
hook API — six typed hook points, distinct from the CLI's three
`hooks.toml` events. They are two surfaces; never merge them into one list
(PART-HOOKS-UNIFIED §6):

| Hook point | Continue | Skip / Deny / Retry |
|---|---|---|
| `pre_agent_turn` | `PreAgentTurnHookContinue(user_content=...)` | `PreAgentTurnHookSkip(reason=[...])` |
| `pre_llm_call` | `PreLlmCallHookContinue` | `PreLlmCallHookSkip(reason=[...])` |
| `pre_tool_call` | `PreToolCallHookContinue(effective_arguments={...})` | `PreToolCallHookSkip(reason=[...])` |
| `post_tool_call` | `PostToolCallHookContinue(tool_result=...)` | — (continue-only; result replacement) |
| `post_llm_call` | `PostLlmCallHookAccept` | `PostLlmCallHookRetry(feedback=...)` / `PostLlmCallHookReject(reason=[...])` |
| `post_agent_turn` | `PostAgentTurnHookAccept` | `PostAgentTurnHookRetry(feedback=...)` / `PostAgentTurnHookReject(reason=[...])` |

Matchers are typed too: `ToolNameHookMatcher(tool_names=[...])` is allowed
only on `pre_tool_call`/`post_tool_call`; every other point requires
`AlwaysHookMatcher()` (PART-HOOKS-UNIFIED §6). One verified crossover: as of
2.25.1, `hooks.toml` hooks now run inside subagents on the experimental
harness instead of being silently skipped **[unified-harness]** (PART-HOOKS
§1, §6).

---

## Exercises

Work in a scratch directory you can delete afterwards.

### Exercise 1: Build a `pre_tool` deny guard

The guard blocks shell commands containing `rm -rf` and passes everything
else through.

```bash
mkdir -p /tmp/vibe-hook-lab/.vibe/hooks
cd /tmp/vibe-hook-lab
```

Register it — `strict = true`, because a guard whose own crash opens the
gate is not a guard:

```toml
# /tmp/vibe-hook-lab/.vibe/hooks.toml
[[hooks]]
name = "deny-rm-rf"
type = "pre_tool"
match = "bash"
command = "python3 ./.vibe/hooks/guard-bash.py"
timeout = 10
strict = true
description = "Reject rm -rf shell commands."
```

The script (PART-HOOKS §3.3, §3.8):

```python
#!/usr/bin/env python3
# /tmp/vibe-hook-lab/.vibe/hooks/guard-bash.py
import json
import sys

payload = json.load(sys.stdin)  # malformed stdin crashes -> hook failure
command = payload.get("tool_input", {}).get("command", "")

if "rm -rf" in command:
    print(json.dumps({
        "decision": "deny",
        "reason": "rm -rf is blocked by policy.",
    }))
# else: empty stdout, exit 0 -> passthrough
```

Note what it does **not** do: no exit code tricks, no self-naming in the
reason (the UI prefixes the hook name on hook notices automatically —
PART-HOOKS §4).

### Exercise 2: Run the three fixtures

Test the script directly, before any Vibe session:

```bash
printf '%s\n' '{"session_id":"s1","transcript_path":"","cwd":"/tmp/vibe-hook-lab","parent_session_id":null,"hook_event_name":"pre_tool","tool_name":"bash","tool_call_id":"t1","tool_input":{"command":"echo hello"}}' \
  | python3 .vibe/hooks/guard-bash.py; echo "exit=$?"

printf '%s\n' '{"session_id":"s1","transcript_path":"","cwd":"/tmp/vibe-hook-lab","parent_session_id":null,"hook_event_name":"pre_tool","tool_name":"bash","tool_call_id":"t2","tool_input":{"command":"rm -rf /tmp/scratch"}}' \
  | python3 .vibe/hooks/guard-bash.py; echo "exit=$?"

printf '%s\n' '{bad json' \
  | python3 .vibe/hooks/guard-bash.py; echo "exit=$?"
```

Expected results:

| Fixture | Local result (script level) | Runtime effect (`strict = false`) | Runtime effect (`strict = true`) |
|---|---|---|---|
| pass (`echo hello`) | exit `0`, no stdout | Passthrough; permission flow continues | Same |
| deny (`rm -rf ...`) | exit `0`, `{"decision": "deny", "reason": ...}` | Call skipped; reason reaches the model as a `<tool_error>` naming the hook | Same |
| malformed | non-zero exit, traceback on stderr | **Hook failure → warning; the call proceeds** | **Hook failure → deny** |

(PART-HOOKS §3.3). These fixtures verify the script's local input/output
contract only. They do not verify that Vibe loaded your `hooks.toml` — that
is Exercise 3.

### Exercise 3: Run it live in programmatic mode

First the deny probe:

```bash
cd /tmp/vibe-hook-lab && vibe --trust -p "Use the bash tool to run: rm -rf /tmp/scratch" --max-turns 2 --output json
```

Expected observations, each verified in the oracle's live run (PART-HOOKS
§5):

- Hook notices in the JSON output: `hook_run_started`, `hook_started`,
  `hook_completed` ("Denied tool 'bash'"), `hook_run_completed` —
  `detail.kind` values you can grep for (PART-HOOKS §4).
- The bash call is marked `skipped`; the deny reason reaches the model
  wrapped as `<tool_error>Tool 'bash' was denied by hook 'deny-rm-rf': rm -rf
  is blocked by policy.</tool_error>` (PART-HOOKS §3.3).
- No `post_tool` notice for the denied call — the tool body never ran
  (PART-HOOKS §1).
- A `post_agent` run at the end of the turn, if you have one registered in
  `~/.vibe/hooks.toml` (PART-HOOKS §5).

The model's report should read like:

> The command was blocked: the `bash` tool was denied by a hook
> (`deny-rm-rf`), so the `rm -rf` never ran. If you want the hook removed or
> the command run another way, tell me how to proceed.

Then the pass probe:

```bash
cd /tmp/vibe-hook-lab && vibe --trust -p "Use the bash tool to run: echo hello" --max-turns 2 --output json
```

Expected: the hook runs (a `hook_started`/`hook_completed` pair), prints
nothing, exits 0, and the command executes — passthrough is indistinguishable
from no hook, so the notices are your evidence the hook ran (PART-HOOKS §4-§5).

Record the Vibe version, the `hooks.toml` path, the command, the results,
and the untested scope. If you did not run a live probe, record runtime
loading as `UNKNOWN` — never infer it from the fixture tests.

### Exercise 4: Prove your failure posture

Fail-open is a claim until you have watched it happen. Crash the hook on
purpose: add `raise SystemExit(1)` as the first line of `guard-bash.py`, set
`strict = false` in `hooks.toml`, and rerun the pass probe.

Expected: a hook failure warning in the output and the `echo hello` call
**still executes** — fail-open, the default (PART-HOOKS §3.3).

Now set `strict = true` and rerun. Expected: the call is denied — a
`pre_tool` failure under `strict` denies the tool call with the failure
reason (PART-HOOKS §3.3). Remove the crash line when done.

---

## DO / DON'T

| DO | DON'T |
|---|---|
| Decide your failure posture explicitly: `strict = true` on anything that guards, fail-open only where a warning suffices | Assume hooks fail closed — the default is fail-open, and a crashed guard changes nothing |
| Return decisions as stdout JSON with exit `0` | Use exit codes as decisions — they carry no decision semantics |
| Keep `match` as narrow as the policy | Put `match` or `strict` on a `post_agent` hook — validation error, hook skipped |
| Test pass, deny, and malformed fixtures before every live run | Trust the fixture tests as proof of runtime loading — they are different claims |
| Set a `timeout` and keep hooks fast; avoid network calls in a gating hook | Repeat the hook name in `reason`/`system_message` — the UI prefixes it automatically |
| Version-control `.vibe/hooks.toml` and its scripts with the project | Enable a hook you found somewhere without reading it — it executes local code with your permissions |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Hook never fires | Project root untrusted — `<project>/.vibe/hooks.toml` loads only from trusted roots | Trust the folder (the oracle's live run used `vibe --trust`) (PART-HOOKS §1, §5) |
| `post_tool` hook never fires | The tool body never ran: `pre_tool` denial, user denial, permission `never`, or cancellation before the body started | Expected behavior — audit with `pre_tool` instead (PART-HOOKS §1) |
| Hook "failed" but the call ran anyway | Default fail-open: non-zero exit, timeout, or non-conforming stdout | Fix the script, or set `strict = true` if failure must gate (PART-HOOKS §3.3) |
| Deny reached the model but `post_tool` also fired | It did not fire for the denied call — you are seeing a different tool call's event | Match on `tool_call_id`, not position in the output (PART-HOOKS §3.2) |
| Rewrite silently aborted the call | Rewritten `tool_input` failed re-validation — the first invalid rewrite aborts the chain with a denial attributed to that hook | Fix the rewrite payload to satisfy the tool's args model (PART-HOOKS §3.3) |
| `post_agent` hook rejected at load | `match` or `strict` present — "only valid for tool hooks" | Remove them (PART-HOOKS §2) |
| Hook silently skipped at load | Duplicate `name` across files — the project entry wins, the later one is dropped as a config issue | Rename one of them (PART-HOOKS §1, §3.6) |
| Every turn loses three retries | A `post_agent` hook denying repeatedly — "Failed, retries exhausted (3/3)" | Fix the gate's condition; the counter resets only on a new user message (PART-HOOKS §3.7) |

## Validation: You're Ready If

- You can distinguish Vibe hooks from Git hooks, and name the three event
  types and when each fires
- You can register a hook in `hooks.toml` with the right keys and say what
  the default of every optional key is
- Your hook reads JSON from stdin and answers a `decision` on stdout — and
  you can say why no exit code blocks a call
- You can explain the two fail-closed mechanisms: a structured `deny` versus
  `strict = true`, and which failures each one covers
- Your three fixtures match the table, and your live probe matched the
  declared decisions
- Your proof separates script-level fixture tests from runtime loading, and
  anything untested is recorded as `UNKNOWN`

## Known gaps

- **Live-run note (2026-09-24, vibe 2.25.7): the fail-open warning is not visible in `--output json`.** Exercise 4's crashed-guard run with `strict = false` behaved as claimed where it matters — the `echo hello` call still executed (fail-open confirmed by the completed effect and the command's output) — but the expected "hook failure warning in the output" does not appear in programmatic JSON output: the only hook entries are the generic `hook_run_started` / `hook_run_completed` info notices ("Running hooks" / "Hooks completed"), with no failure notice, level, or hook name. The same crashed guard under `strict = true` is plainly visible (`hook_completed`: "Denied tool 'bash' (strict)" naming `deny-rm-rf`, call `skipped`). A headless wrapper parsing the JSON therefore cannot detect a fail-open guard crash; if a crashed guard must be observable from a pipeline, make it `strict` or check its side effects yourself.
- **Hooks inside subagents on the default backend**: `parent_session_id` is
  set when a hook runs inside a subagent (PART-HOOKS §3.2), and the 2.25.1
  changelog confirms hooks run inside subagents on the *experimental
  harness* **[unified-harness]** (PART-HOOKS §1, §6) — but no live subagent
  hook run on the default backend was captured by the oracle. Treat
  subagent-side hook behavior on the default backend as unverified until you
  run it yourself.
- **Unified Harness six-point API**: documented from public source and the
  desktop-bundled harness, but not exercisable against the
  live CLI in the oracle's test setup (PART-HOOKS-UNIFIED §6). Treat the
  point names and decision types as documented-only until you run them.
- **Interactive-mode rendering of hook notices**: the oracle's evidence for
  the `hook_run_started`/`hook_started`/`hook_completed`/`hook_run_completed`
  notices is a `--output json` transcript (PART-HOOKS §4-§5); how the same
  notices render in the interactive TUI was not captured.
- **No verified hookless-run escape hatch**: the verified CLI surface has no
  flag for disabling hooks for a single run. To probe without project hooks,
  use a directory without a `.vibe/hooks.toml` — and remember your
  `~/.vibe/hooks.toml` still loads (PART-HOOKS §1).
- **`HookConfigIssue` visibility**: duplicate names and validation failures
  are recorded as config issues and surface "as warnings" (PART-HOOKS §3.6);
  the exact UI or log surface where those warnings appear was not captured
  in the live transcript.

## See also

- [Hooks and events reference](../core/hooks-events-reference.md) — the full
  event tables, payload and decision schemas, matcher catalog, and gotchas
- [Settings reference](../core/settings-reference.md) — the `config.toml`
  layer, including the per-tool permission keys that should be your first
  line of policy
- [Memory systems](../core/memory-systems.md) — the `post_agent` hook as the
  verified cross-session durable-write pattern
- [Agents and skills reference](../core/agents-and-skills-reference.md) —
  the `task` tool that subagent spawns (and their hooks) route through
- [Agent harness](../core/agent-harness.md) — where hooks sit in the session
  model
- [Module 04: Agents & Specialization](04-agents.md) — the sibling
  specialization mechanism
- [Style guide](../style-guide.md)
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md)
