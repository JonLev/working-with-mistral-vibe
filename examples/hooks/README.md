# Vibe Hooks — Guard Scripts and Reference

Hooks are shell commands Vibe runs automatically at three points in the tool loop. They gate dangerous tool calls, scrub tool output, and enforce turn-level quality gates. This directory ships working guard scripts plus a sample `hooks.toml`.

Everything here speaks the CLI `hooks.toml` protocol only. The separately-versioned Unified Harness runtime declares its own, different hook surface — see the note at the end.

## The three events

| `type` | When it fires | Can it stop things? |
|---|---|---|
| `pre_tool` | Per tool call, before the user permission prompt | Yes. First deny short-circuits the remaining `pre_tool` hooks for that call; the tool call is skipped. Can also rewrite the tool arguments. |
| `post_tool` | Per tool call, iff the tool body actually ran (`tool_status` `success`/`failure`/`cancelled`) | Partly. Deny replaces the tool output text with the reason; allow + `additional_context` appends to it. Never fires on a `pre_tool` denial or a user denial at the prompt. |
| `post_agent` | Once per turn, after the agent finishes with no pending tool calls | Yes, with retries. Deny injects the reason as a new user message and the model retries the turn — at most 3 retries per user turn, then the gate gives up for that turn. |

There are exactly three events. There is no prompt-submit, session-start, session-end, compact, permission-request, subagent-start, notification, config-change, or file-watcher event. Permission prompts are not hookable. If you are migrating hooks written for a different coding CLI, every hook must be re-mapped to one of these three events, moved to Vibe's native permission config (next section), or pushed out of the agent entirely into git hooks and CI.

Not every guard needs a hook. Vibe already enforces, in `config.toml`:

- `[tools.bash]` `denylist` (auto-denied command prefixes), `denylist_standalone`, `sensitive_patterns` (prefixes that always ask), `permission = "never"`
- `[tools.read_file]` / `[tools.write_file]` / `[tools.edit]` `allowlist`/`denylist` path globs, `sensitive_patterns` (`.env` and friends by default)
- `enabled_tools` / `disabled_tools` (glob or `re:` patterns)

A static rule — "never run `sudo`", "never read `**/secrets/**`" — belongs in that config, not in a hook. Hooks earn their keep on logic the permission model cannot express: content analysis (injection patterns, secrets in output), cross-checking, or running commands.

## Configuration

```toml
# <project>/.vibe/hooks.toml  (loaded only when the project root is trusted)
# ~/.vibe/hooks.toml          (user-level fallback, always loaded)

[[hooks]]
name = "deny-dangerous-bash"        # required, unique — dedupe key across files
type = "pre_tool"                   # required: pre_tool | post_tool | post_agent
command = "bash .vibe/hooks/guard-bash-dangerous.sh"  # required, non-blank
match = "bash"                      # tool hooks only; default "*"
timeout = 60.0                      # seconds; default 60
strict = false                      # tool hooks only; default false
description = "Reject destructive shell commands."  # optional
```

Load order: project file(s) first (trusted root, then `--add-dir` roots), then the user file, declaration order within each. A duplicate `name` across files loses to the project entry and is dropped with a config issue. `match` or `strict` on a `post_agent` hook is a validation error — the whole hook is skipped with a warning.

## Wire protocol

### stdin

Every invocation receives one JSON blob on stdin. Common fields:

```json
{
  "session_id": "2d9a4db4-3784-86fe-b962-d8b0bc9df71a",
  "transcript_path": "/Users/you/.vibe/logs/session/session_20260924_090446_2d9a4db4/messages.jsonl",
  "cwd": "/private/tmp/vibe-hook-test",
  "parent_session_id": null,
  "hook_event_name": "pre_tool"
}
```

Tool hooks add `tool_name`, `tool_call_id`, `tool_input` (post-rewrite on `post_tool`). The `post_tool` payload adds `tool_status`, `tool_output` (serialized result dict, null on failure), `tool_output_text` (the mutable text the model will see), `tool_error`, `duration_ms`. `parent_session_id` is set when the hook runs inside a subagent; `transcript_path` is empty when session logging is disabled.

Tool argument names, verified from live transcripts on 2.25.7: `bash` takes `{command}`, `read_file` `{file_path}`, `write_file` `{file_path, content}`, `edit` `{file_path, old_string, new_string}`. All subagent spawns route through the `task` tool (`{task, agent}`).

### stdout and exit codes

| Exit | Stdout | Behavior |
|---|---|---|
| 0 | empty | Passthrough. |
| 0 | valid JSON object | Structured response, below. |
| 0 | non-JSON text, broken JSON, or a schema mismatch | Hook FAILURE — warning by default, escalated under `strict = true`. |
| non-zero, timeout, spawn failure | anything | Hook FAILURE. |

The structured response:

```json
{
  "decision": "deny",
  "reason": "Text shown to the model",
  "system_message": "UI-only note on the hook event",
  "hook_specific_output": {
    "tool_input": {},
    "additional_context": ""
  }
}
```

Effects by event:

- `pre_tool` deny — the call is skipped; the model sees `<tool_error>Tool 'X' was denied by hook 'Y': {reason}</tool_error>`. First deny short-circuits the chain.
- `pre_tool` allow + `hook_specific_output.tool_input` — full replacement of the tool arguments, re-validated immediately; an invalid rewrite becomes a denial attributed to that hook. Rewrites compose left-to-right.
- `post_tool` deny — `tool_output_text` is replaced with the reason (then `additional_context` is appended if both are present). The model sees the replacement.
- `post_tool` allow + `hook_specific_output.additional_context` — appended to `tool_output_text` with a newline separator. This is the only context-injection mechanism in the CLI hook system.
- `post_agent` deny — the reason is injected as a user message; the model retries. Max 3 retries per user turn; the counter resets on the next user message.

Unknown JSON fields are ignored. `additional_context` on a `pre_tool` hook and `tool_input` on a `post_tool` hook are ignored with a log warning. Stdout is capped at 1 MiB.

### Fail-open by default; strict escalates

Any hook failure — non-zero exit, timeout (whole process tree killed), unparseable stdout — emits a UI warning and lets the gated action proceed. That is the right default for advice and logging, and the wrong one for guards.

Rule of thumb: a hook that exists to block dangerous actions sets `strict = true`. Then a `pre_tool` failure denies the call and a `post_tool` failure clears the output text. A crashed guard must not fail open. Advisory hooks (nudges, loggers) stay fail-open. `post_agent` hooks cannot be strict — failures there are always just warnings.

### Matchers

`match` is an fnmatch glob (case-insensitive) or, prefixed with `re:`, a full-match regex (invalid regex never matches). Omit it to match every tool. Tool-name conventions:

- Built-in tools: bare name — `bash`, `read_file`, `write_file`, `edit`, `task`, ...
- MCP tools: `{server-alias}_{tool-name}` — e.g. a server aliased `linear` publishing `search_issues` matches `linear_search_issues`
- Connector tools: `connector_{alias}_{tool-name}` — e.g. `connector_Google_Drive_search_files`
- Subagent spawns: everything routes through `task`; match `task` and read `tool_input.agent` to discriminate

### Execution environment

The hook command runs via the shell in the session cwd, in its own process group. There is no project-directory environment variable — the payload's `cwd` field is the project pointer. Hooks of the same type fire sequentially in load order; `pre_tool` chains gate execution and are buffered, `post_tool`/`post_agent` stream. Hook state flows only through the threaded invocation: a `pre_tool` rewrite is what the next hook and the permission prompt see; a `post_tool` replacement is what the model receives.

## The examples

| Script | Event | Registers as | Purpose |
|---|---|---|---|
| [bash/guard-bash-dangerous.sh](bash/guard-bash-dangerous.sh) | `pre_tool` | `match = "bash"`, `strict = true` | Deny destructive shell commands: `rm -rf` on roots, disk writes, force pushes, credential files. |
| [bash/guard-secrets-in-command.sh](bash/guard-secrets-in-command.sh) | `pre_tool` | `match = "bash"`, `strict = true` | Deny commands carrying hardcoded secrets. |
| [bash/guard-protected-paths.sh](bash/guard-protected-paths.sh) | `pre_tool` | `match = "re:^(read_file\|write_file\|edit)$"`, `strict = true` | Deny file tools touching env files, keys, credentials; deny variable expansion in paths. |
| [bash/guard-prompt-injection.sh](bash/guard-prompt-injection.sh) | `pre_tool` | `match = "*"` (default), `strict = true` | Deny tool calls whose text carries injection patterns: role override, jailbreak framing, fake delimiters, ANSI escapes, encoded payloads. |
| [bash/guard-output-secrets.sh](bash/guard-output-secrets.sh) | `post_tool` | `match = "*"`, `strict = true` | Replace tool outputs containing leaked secrets — the model never sees them. |
| [bash/hint-run-checks.sh](bash/hint-run-checks.sh) | `post_tool` | `match = "re:^(write_file\|edit)$"`, fail-open | Append a reminder to run the sibling test file. |
| [bash/log-tool-calls.sh](bash/log-tool-calls.sh) | `post_tool` | `match = "*"`, fail-open | Append every tool call to a JSONL activity log. |
| [bash/gate-verification.sh](bash/gate-verification.sh) | `post_agent` | no `match`/`strict` allowed | Run lint + tests after each turn; deny (retry) when they fail. |
| [bash/pre-commit-secrets.sh](bash/pre-commit-secrets.sh) | none — plain git hook | `.git/hooks/pre-commit` | Block secrets from entering commits. Runs outside Vibe. |

Install:

```bash
cp -r examples/hooks/bash/ .vibe/hooks/
cp examples/hooks/hooks.toml.example .vibe/hooks.toml
# edit command paths to match, then start vibe in the project
# (the project root must be trusted, or the project file is not loaded)
```

All guard scripts need `jq`. They fail closed: a missing `jq` or an unparseable payload prints a deny rather than a guess — but keep `strict = true` on them anyway so a timeout also denies instead of passing through.

### Testing a guard outside Vibe

The wire protocol is plain stdin/stdout, so a fixture pipeline is enough:

```bash
# passthrough
printf '%s' '{"hook_event_name":"pre_tool","tool_name":"bash","tool_input":{"command":"ls -la"}}' \
  | bash .vibe/hooks/guard-bash-dangerous.sh
# no output, exit 0

# denial
printf '%s' '{"hook_event_name":"pre_tool","tool_name":"bash","tool_input":{"command":"rm -rf /"}}' \
  | bash .vibe/hooks/guard-bash-dangerous.sh
# {"decision":"deny","reason":"Recursive delete of a root target (/, /*, ~ or $HOME) detected. Refusing to run: rm -rf /"}
# exit 0 — the DECISION is the deny, not the exit code

# malformed payload
printf 'not json' | bash .vibe/hooks/guard-bash-dangerous.sh
# {"decision":"deny","reason":"guard-bash-dangerous: could not parse the hook payload as JSON."}
```

Every deny guard in this directory fails closed on malformed input, so the malformed case produces a deny, never a crash. In a live session the same guards also fire on subagent tool calls (hooks are inherited by subagent loops; the payload carries `parent_session_id`).

## What was cut from the source material, and where it went

These examples are adapted from a guide written for a different coding CLI whose hook system has roughly thirty events. The scripts that survived are the ones that map onto the three Vibe events; everything else was dropped for a reason:

- Prompt-submit routing/suggestion hooks — no prompt-submit event exists, and no hook can inject text into the prompt path. `additional_context` is honored only on `post_tool`. Not portable.
- Session-start scanners (config-integrity hash checks, instruction-file injection scans) — no session-start event. The config-file integrity job moved to the audit script in [../scripts/](../scripts/); instruction-file review belongs in code review, not in a hook.
- Session-end analytics and AI-generated session titles — no session-end event, and Vibe generates session titles itself.
- Stop/subagent-stop cleanup and notification hooks — no stop or subagent-stop events. The quality-gate use of the Stop event maps to `post_agent`; the notification use has no equivalent.
- Permission-request automation — permission prompts are not hookable; use the native permission config instead (`permission`, `allowlist`, `denylist`).
- Compact-related hooks — no compact events.
- Rate-limiting/velocity hooks — workable in principle as `pre_tool` on `task`, but the source's implementation assumed per-session counters an external process cannot see; cut rather than faked.
- PowerShell variants — the protocol is shell-agnostic; one implementation per guard is enough.
- A BM25 skill-routing hook — its entire mechanism (a prompt-submit hook that injects a skill suggestion into the prompt path) has no Vibe equivalent. Skills are routed by their `description` frontmatter at load time; the model invokes them through the `skill` tool. Not portable as a hook.

The pre-commit secret scanner survived unchanged in spirit because it never depended on the other product's events in the first place: it is a git hook, and Vibe is not in its path.

## Unified Harness note

The CLI `hooks.toml` protocol above is one surface. The separately-versioned Unified Harness Session Protocol declares six typed hook points — `pre_agent_turn`, `post_agent_turn`, `pre_llm_call`, `post_llm_call`, `pre_tool_call`, `post_tool_call` — with their own decision types and matchers. That is a different runtime surface, not an extended event list for `hooks.toml`: never merge the two lists or assume a `hooks.toml` entry fires as one of the six points. The three-event CLI system is what `hooks.toml` speaks, on both backends.
