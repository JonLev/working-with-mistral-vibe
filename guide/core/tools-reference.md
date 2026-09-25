---
title: "Tools Reference"
description: "Every built-in Vibe tool: one-line catalog, enable/disable syntax, per-call permission resolution, per-tool parameters and config defaults, and MCP/connector proxy naming"
tags: [tools, permissions, reference, config]
---

# Tools Reference

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

One catalog of every built-in tool the Vibe CLI exposes: what it takes, what it
defaults to, and how each call is permission-checked. Every mechanic is cited
inline against the [mechanics oracle](../../docs/mechanics/verified-mechanics.md);
tool defaults and parameter schemas are cited against the installed-package
schema dump, vibe 2.25.7 (2026-09-24). Live permission behavior is verified on
2.25.0 and anchored to the documented 2.25.8 surface. Structure is adapted
from the source guide's tool catalog; every entry is rebuilt from the oracle,
nothing transliterated.

## TL;DR

- The installed 2.25.7 package ships 26 built-in tool names across eight
  families: 3 file tools, 3 foreground shell tools, 12 managed-shell session
  tools (flag-gated), 1 search tool, and 7 others (`task`, `skill`,
  `ask_user_question`, `exit_plan_mode`, `todo`, `web_fetch`, `web_search`)
  (installed-package schema dump, vibe 2.25.7 (2026-09-24)).
- Read-only and interactive tools default to `permission = "always"`
  (`read_file`, `grep`, `skill`, `ask_user_question`, `exit_plan_mode`,
  `todo`, the session readers); mutating tools default to `"ask"`
  (`write_file`, `edit`, the shell tools, `task`, `web_fetch`, `web_search`)
  (installed-package schema dump, vibe 2.25.7 (2026-09-24)).
- `--enabled-tools` / `--disabled-tools` take exact names, globs (`bash*`),
  or `re:` regex, and are repeatable; in programmatic mode (`-p`),
  `--enabled-tools` is exclusive — it disables all other tools. The
  `config.toml` equivalents are `enabled_tools`, `disabled_tools`, and
  `tool_paths` (PART-CLI; PART-CONFIG section 1.3).
- Every call passes one gate: bypass flag → per-tool resolver → config
  permission → session permission store → prompt. "Approve permanently"
  persists the approved patterns into `[tools.<name>]` in config
  (PART-PERMISSIONS section 4.2).
- Shell commands are parsed with tree-sitter and matched by prefix —
  `command == pattern or startswith(pattern + " ")`. File paths resolve
  scratchpad → denylist → allowlist → sensitive patterns → outside-workspace
  → config permission (PART-PERMISSIONS sections 4.3, 4.4).
- MCP tools publish as `{alias}_{tool}` and connectors as
  `connector_{alias}_{tool}`; both are configured in `[tools.<published
  name>]` exactly like built-ins (PART-MCP section 1.8; PART-CONNECTORS
  section 2.3).

*Read if you configure tool permissions, write allow/deny lists, disable tools
per session or project, or need an exact parameter signature. Skip if you run
the shipped defaults and never touch `[tools.*]` — the quick-reference table
is the whole story for you.*

---

## Quick reference — [stable]

Default permissions and config classes are from the installed-package schema
dump, vibe 2.25.7 (2026-09-24); permission semantics are from
PART-PERMISSIONS. `permission` values: `ask` (prompt unless pre-approved),
`always` (execute), `never` (skip with feedback).

| Tool | Family | What it does | Default permission | Config class | Backend |
|---|---|---|---|---|---|
| `read_file` | File | Read a text file, paged with `offset`/`limit` | `always` | `ReadFileConfig` | [stable] |
| `write_file` | File | Create a new file; errors if the file exists | `ask` | `WriteFileConfig` | [stable] |
| `edit` | File | Exact string replacement; requires `read_file` first | `ask` | `EditConfig` | [stable] |
| `bash` | Shell | Execute a shell command, capture stdout/stderr | `ask` | `BashToolConfig` | [stable] |
| `git_bash` | Shell | Shell tool exposed under the name `git_bash` | `ask` | `GitBashToolConfig` | [stable] |
| `powershell` | Shell | Run native Windows PowerShell commands | `ask` | `WindowsShellToolConfig` | [stable] |
| `bash_output` | Shell (managed) | Read output from a live background session | `always` | `BashOutputConfig` | [stable] † |
| `bash_sessions` | Shell (managed) | List, inspect, kill, or reset background sessions | `always` | `BashSessionsConfig` | [stable] † |
| `bash_stdin` | Shell (managed) | Send text, control keys, or raw bytes to a session | `always` | `BashStdinConfig` | [stable] † |
| `bash_log_file` | Shell (managed) | Session log file access (read and append) | `ask` | `BashLogFileConfig` | [stable] † |
| `git_bash_output` | Shell (managed) | `bash_output` for the `git_bash` family | `always` | `BashOutputConfig` | [stable] † |
| `git_bash_sessions` | Shell (managed) | `bash_sessions` for the `git_bash` family | `always` | `BashSessionsConfig` | [stable] † |
| `git_bash_stdin` | Shell (managed) | `bash_stdin` for the `git_bash` family | `always` | `BashStdinConfig` | [stable] † |
| `git_bash_log_file` | Shell (managed) | `bash_log_file` for the `git_bash` family | `ask` | `BashLogFileConfig` | [stable] † |
| `powershell_output` | Shell (managed) | `bash_output` for the `powershell` family | `always` | `BashOutputConfig` | [stable] † |
| `powershell_sessions` | Shell (managed) | `bash_sessions` for the `powershell` family | `always` | `BashSessionsConfig` | [stable] † |
| `powershell_stdin` | Shell (managed) | `bash_stdin` for the `powershell` family | `always` | `BashStdinConfig` | [stable] † |
| `powershell_log_file` | Shell (managed) | `bash_log_file` for the `powershell` family | `ask` | `BashLogFileConfig` | [stable] † |
| `grep` | Search | Regex search over file contents; returns paths, line numbers, lines | `always` | `GrepToolConfig` | [stable] |
| `task` | Subagents | Launch a read-only subagent; text-only result | `ask` | `TaskToolConfig` | [stable] |
| `skill` | Skills | Load a skill by name; returns body, base directory, file listing | `always` | `SkillToolConfig` | [stable] |
| `ask_user_question` | Interaction | Ask the user structured questions with options | `always` | `AskUserQuestionConfig` | [stable] |
| `exit_plan_mode` | Interaction | Signal the plan is ready for implementation | `always` | `ExitPlanModeConfig` | [stable] |
| `todo` | Session | Track tasks; `write` replaces the full list | `always` | `TodoConfig` | [stable] |
| `web_fetch` | Web | Fetch a URL, returned as markdown; read-only | `ask` | `WebFetchConfig` | [stable] |
| `web_search` | Web | Search the web; answers with cited sources | `ask` | `WebSearchConfig` | [stable] |
| `{alias}_{tool}` | MCP | Proxy tools published by MCP servers | `ask` by default | — (remote schema) | [stable] |
| `connector_{alias}_{tool}` | Connectors | Proxy tools published by Mistral connectors | `ask` by default | — (remote schema) | [both] |

† The managed-shell family ships in the experimental-bash module and is gated
by `managed_shell_tools_enabled` (default `false`; also set by the
`managed_shell` GrowthBook experiment) — a [stable] flag gating an
experimental runtime, with the same permission semantics as the foreground
shell tools and a different execution runtime (PART-CONFIG section 1.10;
PART-PERMISSIONS section 4.4).

---

## Enabling and disabling tools — [stable]

| Surface | Syntax | Effect |
|---|---|---|
| `--enabled-tools TOOL` | Exact name, glob (`bash*`), or `re:` regex; repeatable | Enable matching tools. In programmatic mode (`-p`) this is exclusive: all other tools are disabled (PART-CLI) |
| `--disabled-tools TOOL` | Same syntax; repeatable | Disable matching tools, applied after `--enabled-tools` filtering (PART-CLI) |
| `enabled_tools` | `array<string>`, `config.toml` | When non-empty, ONLY matching tools are active (glob or `"re:^..."`); fullmatch semantics (PART-CONFIG section 1.3; PART-MCP section 1.8) |
| `disabled_tools` | `array<string>`, `config.toml` | Applied after `enabled_tools` filtering; concat-merges across config layers (PART-CONFIG sections 1.3, 2.1) |
| `tool_paths` | Dirs (shallow scan) or files | Extra locations to load custom tools from; `~` expanded, resolved (PART-CONFIG section 1.3). Custom tools also load from `~/.vibe/tools/` (PART-CONFIG section 2.4) |

Two consequences worth knowing:

- Config migrations rewrite old tool names in place: `read` → `read_file` and
  `search_replace` → `edit`; they also add `find` to the bash allowlist.
  Migration ids accumulate in `applied_migrations` (PART-CONFIG section 1.11).
- In `-p` mode, `--enabled-tools` filtering combines with programmatic
  approval semantics: approval-required calls are auto-denied, not
  auto-approved — `--auto-approve` / `--yolo` is the headless way to allow all
  tool calls (PART-CLI, live verification on 2.25.0). Programmatic mode also
  force-disables `ask_user_question` and `exit_plan_mode` so the session can
  never block on user input (PART-TRUST section 3.4).

---

## Permission behavior — [stable]

The per-call resolver is shared by both backends; the unified-harness binding
of the same resolver is [unified-harness] (PART-PERMISSIONS, section 4
preamble).

### The gate, in order (PART-PERMISSIONS section 4.2)

1. `bypass_tool_permissions` (config key, `--auto-approve`, or the
   `auto-approve` agent profile) → execute everything, no per-call checks.
2. The tool's own `resolve_permission(args)` returns a decision or `None`
   ("no opinion").
3. `None` → the tool's config permission from `[tools.<name>]` (default
   `ask`).
4. `always` → execute; `never` → skip with feedback (denylist reason or
   "permanently disabled"); `ask` → execute if the session permission store
   covers the call, else prompt.

### `[tools.<name>]` keys (PART-PERMISSIONS section 4.5; PART-CONFIG section 1.3)

| Key | On every tool | Values / type | Meaning |
|---|---|---|---|
| `permission` | yes | `"ask"` \| `"always"` \| `"never"` | Gate default when the tool has no per-call opinion |
| `allowlist` | yes | Shell tools: command prefixes; file tools: path globs (fnmatch) | Auto-allow; patterns are prefixes (shell) or globs (files) |
| `denylist` | yes | Same shapes | Auto-deny; checked before the allowlist |
| `sensitive_patterns` | yes | Shell: first-token prefixes that always ask; files: path globs that add a per-file required permission | Default `["sudo"]` (shell); the `.env` glob family (file tools) |
| `denylist_standalone` | shell tools only | Command names | Denied only when invoked with no arguments |
| `max_output_bytes` | shell tools only | Integer, default 16000 | stdout/stderr capture cap |
| `default_timeout` | shell tools only | Seconds, default 300 | Default command timeout |

The persisted key names are `allowlist`/`denylist`. docs.mistral.ai's
configuration-reference table lists the bash keys as `allow`/`deny`; no code
path reads `allow`/`deny`, and unknown keys are silently ignored — the docs'
alias claim is not honored by the 2.25.0 source (PART-CONFIG section 1.3).
Agent profiles set the same `[tools.*]` tables per agent (PART-PERMISSIONS
sections 4.1, 4.5); runtime "approve permanently" writes through the same
patch system to the user config layer (PART-CONFIG section 2.3).

### Approval answers and persistence (PART-PERMISSIONS section 4.2)

| Answer | Effect |
|---|---|
| Approve once | This call runs; nothing is remembered |
| Approve for session | The approved patterns become in-memory `PermissionStore` rules; `reset()` drops them between sessions |
| Approve permanently | Additionally persists the session patterns into `[tools.<tool>].allowlist` in config via a JSON-pointer patch `/tools/<tool>/allowlist` |
| Decline | Skip with feedback |
| Cancel turn | Abandon the in-flight turn |

For calls that carry required permissions, "permanently" persists patterns;
shell tools' `" *"` any-args wildcard is stripped before persisting
(`_SESSION_PATTERN_WILDCARD_TOOLS = {"bash", "git_bash", "powershell"}`). For
calls without required permissions, permanent approval sets the tool's
`permission` instead.

### File tools: per-call resolution order (PART-PERMISSIONS section 4.3)

Used by `read_file`, `write_file`, `edit`:

1. Scratchpad path → `always` (the session scratchpad directory is always
   writable).
2. Denylist glob match → `never` (checked first, on the resolved absolute
   path).
3. Allowlist glob match → `always`.
4. `sensitive_patterns` match → adds a `FILE_PATTERN` required permission
   scoped to this exact file — approving one `.env` does not approve others.
5. Outside the workspace (not under cwd + trusted project roots +
   `--add-dir`) → `never` if config says so, else an `OUTSIDE_DIRECTORY`
   required permission.
6. Otherwise → the tool's config permission (default `ask`).

### Shell tools: per-call resolution order (PART-PERMISSIONS section 4.4)

1. Parse the command string with tree-sitter-bash into individual commands
   (heredoc redirects become `<redirect>` tokens, so `python3 << EOF` is not
   misread as bare `python3` and standalone-denied).
2. Guardrails: denylist prefix → `never`; `denylist_standalone` with no
   arguments → `never`; `find` with `-exec`/`-execdir`/`-ok`/`-okdir` →
   always asks, with an exact-command permission that the allowlist cannot
   satisfy.
3. Outside-workdir scan: path-like arguments of path-touching commands
   (`cd`, `chmod`, `chown`, `cp`, `mkdir`, `mv`, `rm`, `touch`, plus the
   read-only commands) that resolve outside the workspace add
   `OUTSIDE_DIRECTORY` permissions — this runs even for allowlisted commands,
   so `grep root /etc/passwd` is never silently auto-allowed. Scratchpad
   paths are exempt.
4. Unconditional allow when there is no sensitive first token AND (config
   permission is `always`, OR every command part is allowlisted AND no
   outside dirs).
5. Otherwise ask, with per-part permissions: sensitive parts (default first
   token `sudo`) get an exact-command permission — `sudo` always asks, even
   with arity approval; non-allowlisted parts get a command-plus-arity session
   pattern (`" *"`-suffixed, so "approve `git status` with any args" matches
   future calls); plus the outside-directory permissions from step 3.

Command matching is prefix equality: `command == pattern or
command.startswith(pattern + " ")`. `PermissionStore` rules match with
fnmatch, where a pattern ending in `" *"` also matches without trailing
arguments (PART-PERMISSIONS section 4.4).

---

## Per-tool reference

### File tools: `read_file`, `write_file`, `edit`

**[stable]** Parameters (installed-package schema dump, vibe 2.25.7
(2026-09-24)):

| Tool | Parameter | Required | Description |
|---|---|---|---|
| `read_file` | `file_path` | yes | Absolute path to the file to read |
| `read_file` | `offset` | no | Line number to start reading from (1-indexed) |
| `read_file` | `limit` | no | Maximum number of lines to read |
| `write_file` | `file_path` | yes | Absolute path to the file to write (must be absolute, not relative) |
| `write_file` | `content` | yes | Content to write to the file |
| `edit` | `file_path` | yes | Absolute path to the file to modify |
| `edit` | `old_string` | yes | The text to replace |
| `edit` | `new_string` | yes | The replacement text (must differ from `old_string`) |
| `edit` | `replace_all` | no | Replace all occurrences (default `false`) |

Config defaults beyond the shared keys (installed-package schema dump, vibe
2.25.7 (2026-09-24)):

| Tool | Key | Default |
|---|---|---|
| `read_file` | `max_read_bytes` | 51200 |
| `write_file` | `max_write_bytes` | 64000 |
| `write_file` | `create_parent_dirs` | `true` |
| `read_file`, `write_file`, `edit` | `sensitive_patterns` | `**/.env`, `**/.env.*`, `**/.env~`, `**/.envrc`, `**/.envrc.*`, `**/.envrc~` |

Behavior the tool prompts themselves state (installed-package schema dump,
vibe 2.25.7 (2026-09-24)):

- `edit` requires a `read_file` of the target first; never include any part
  of the line-number prefix in `old_string`/`new_string`; if `old_string` is
  not found or matches multiple locations, provide more context or use
  `replace_all`; on a failed edit, re-read the file before retrying.
- `write_file` errors if the file already exists — use `edit` to modify
  existing files, prefer editing over creating, and do not proactively create
  documentation or README files.
- `read_file` wants absolute paths and paging via `offset`/`limit` for large
  files, `grep` for targeted content, and refuses binary or model weight
  files (`.bin`, `.safetensors`, `.pt`, `.gguf`).

All three resolve per call through the file-tool chain above
(PART-PERMISSIONS section 4.3).

### Foreground shell tools: `bash`, `git_bash`, `powershell`

**[stable]** Parameters (installed-package schema dump, vibe 2.25.7
(2026-09-24)):

| Tool | Parameter | Required | Description |
|---|---|---|---|
| `bash` | `command` | yes | The shell command to execute |
| `bash` | `timeout` | no | Override the default command timeout |
| `git_bash` | `command` | yes | Git Bash command to run |
| `git_bash` | `timeout` | no | Backward-compatible timeout override in seconds |
| `git_bash` | `timeout_seconds` | no | Foreground wait time before the command is killed |
| `git_bash` | `cwd` | no | Working directory override |
| `git_bash` | `env` | no | Environment variable overrides |
| `git_bash` | `shell` | no | Shell executable override |
| `powershell` | `command` | yes | PowerShell command to run |
| `powershell` | `timeout` | no | Backward-compatible timeout override in seconds |
| `powershell` | `timeout_seconds` | no | Foreground wait time before the command is killed |
| `powershell` | `cwd` | no | Working directory override |
| `powershell` | `env` | no | Environment variable overrides |
| `powershell` | `shell` | no | Shell executable override |

Shared config defaults (identical across `bash`, `git_bash`, `powershell`;
installed-package schema dump, vibe 2.25.7 (2026-09-24); permission semantics
PART-PERMISSIONS section 4.4):

| Key | Default | Meaning |
|---|---|---|
| `permission` | `ask` | Gate default |
| `allowlist` | 43-command list below | Auto-allowed command prefixes |
| `denylist` | 14-entry list below | Auto-denied command prefixes |
| `denylist_standalone` | 11-entry list below | Denied when invoked with no arguments |
| `sensitive_patterns` | `["sudo"]` | First-token prefixes that always ask |
| `max_output_bytes` | 16000 | stdout/stderr capture cap |
| `default_timeout` | 300 | Default timeout, seconds |
| `max_timeout_seconds` | 600.0 | Hard ceiling for timeout overrides |
| `max_inline_bytes` | 30000 | Byte cap in the tool config (see Known gaps) |

```text
allowlist:      cd, echo, git diff, git log, git status, tree, whoami, basename,
                cat, comm, cut, date, diff, dirname, du, file, find, fmt, fold,
                grep, head, join, less, ls, md5sum, more, nl, od, paste, pwd,
                readlink, sha1sum, sha256sum, shasum, sort, stat, sum, tac,
                tail, tr, uname, uniq, wc, which
denylist:       gdb, pdb, passwd, nano, vim, vi, emacs, bash -i, sh -i, zsh -i,
                fish -i, dash -i, screen, tmux
denylist_standalone: python, python3, ipython, bash, sh, nohup, vi, vim,
                emacs, nano, su
sensitive_patterns: sudo
```

The `git_bash` prompt states the contract bluntly: "The shell tool is named
`git_bash` — there is no `bash` tool, and calling `bash` fails."
(installed-package schema dump, vibe 2.25.7 (2026-09-24)). Which of the three
shell tools is exposed on which platform is not covered by the sources read —
see Known gaps.

### Managed-shell family: background sessions — [stable] flag, experimental runtime

`managed_shell_tools_enabled` (default `false`, also set by the
`managed_shell` GrowthBook experiment) swaps the shell tool's implementation
for `experimental_bash.py` and exposes the session tools — same permission
semantics, different execution runtime (PART-CONFIG section 1.10;
PART-PERMISSIONS section 4.4). The experimental variant gains these
parameters (installed-package schema dump, vibe 2.25.7 (2026-09-24)):

| Parameter | Required | Description |
|---|---|---|
| `command` | yes | Shell command to run |
| `timeout` | no | Backward-compatible hard timeout override in seconds |
| `background` | no | Return immediately with a live session |
| `timeout_seconds` | no | Foreground wait time before soft or hard timeout handling |
| `hard_timeout` | no | Kill the process group when `timeout_seconds` expires |
| `cwd` | no | Working directory override |
| `env` | no | Environment variable overrides |
| `shell` | no | Shell executable override |

The four session tools per shell (12 published names total — see the quick
reference) and their parameters (installed-package schema dump, vibe 2.25.7
(2026-09-24); the `git_bash_*` and `powershell_*` variants share the same
config classes and parameter sets):

| Tool | Parameter | Required | Description |
|---|---|---|---|
| `bash_output` | `session_id` | yes | The session to read |
| `bash_output` | `cursor` | no | Byte offset returned by `next_cursor` |
| `bash_output` | `wait_seconds` | no | How long to wait for new output |
| `bash_output` | `max_bytes` | no | Maximum output bytes read before inline decoding |
| `bash_sessions` | `action` | no | `list` sessions; `inspect`/`kill` one (need `session_id`); `reset` stops every session in the family |
| `bash_sessions` | `session_id` | no | Required for `inspect` and `kill`; ignored for `list` and `reset` |
| `bash_sessions` | `clear_logs` | no | With `reset`: also delete stored logs |
| `bash_sessions` | `max_bytes` | no | Maximum output bytes read before inline decoding |
| `bash_stdin` | `session_id` | yes | The session to write to |
| `bash_stdin` | `text` | no | UTF-8 text to send exactly as provided; include `\n` for Enter |
| `bash_stdin` | `control` | no | Named control sequences, e.g. `ctrl_c`, `ctrl_d`, `esc`, `tab`, `enter`, `backspace`, arrow keys |
| `bash_stdin` | `bytes_base64` | no | Raw bytes to send, base64-encoded |
| `bash_log_file` | `action` | yes | Log file operation (values not documented — see Known gaps) |
| `bash_log_file` | `session_id` | no | Owning session |
| `bash_log_file` | `relative_path` | no | Log file path |
| `bash_log_file` | `offset` | no | Byte offset to start reading |
| `bash_log_file` | `max_bytes` | no | Maximum file bytes read before inline decoding |
| `bash_log_file` | `content` | no | Content to append |

The readers (`*_output`, `*_sessions`, `*_stdin`) default to
`permission = "always"`; `*_log_file` defaults to `ask`
(installed-package schema dump, vibe 2.25.7 (2026-09-24)).

### `grep`

**[stable]** Parameters and config (installed-package schema dump, vibe
2.25.7 (2026-09-24)):

| Parameter | Required | Description |
|---|---|---|
| `pattern` | yes | Regex pattern to search for in file contents |
| `path` | no | File or directory to search; defaults to the current working directory |
| `max_matches` | no | Override the default maximum number of matches (default 100) |
| `use_default_ignore` | no | Whether to respect `.gitignore` and `.ignore` files |

| Config key | Default |
|---|---|
| `permission` | `always` |
| `max_output_bytes` | 64000 |
| `default_max_matches` | 100 |
| `default_timeout` | 60 |
| `exclude_patterns` | `.venv/`, `venv/`, `.env/`, `env/`, `node_modules/`, `.git/`, `__pycache__/`, `.pytest_cache/`, `.mypy_cache/`, `.tox/`, `.nox/`, `.coverage/`, `htmlcov/`, `dist/`, `build/`, `.idea/`, `.vscode/`, `*.egg-info`, `*.pyc`, `*.pyo`, `*.pyd`, `.DS_Store`, `Thumbs.db` |
| `codeignore_file` | `.vibeignore` |

The prompt directs the model to return matching file paths, line numbers, and
lines, and to narrow scope with `path` rather than searching sequentially.

### `task` — subagents

**[stable]** Parameters (installed-package schema dump, vibe 2.25.7
(2026-09-24); PART-AGENTS section 9):

| Parameter | Required | Description |
|---|---|---|
| `task` | yes | The task for the agent to perform (self-contained text) |
| `agent` | no | The subagent profile to use; default `"explore"` |

The parent receives a `TaskResult` with `response` (accumulated assistant
text — text-only, no message objects, no files), `turns_used`, and
`completed`. Security constraints raise `ToolError` with exact texts
(PART-AGENTS section 9):

| Condition | Error text |
|---|---|
| Active profile is itself a subagent | `Agent depth limit of 1 reached. Complete the task in the current subagent.` |
| Requested agent is not a subagent profile | `Agent '<n>' is a <type> agent. Only subagents can be used with the task tool. This is a security constraint to prevent recursive spawning.` |
| Unknown agent name | `Unknown agent: <name>` |

Permission: `ask` with `allowlist = ["explore"]` — the built-in `explore`
subagent is auto-approved; any other subagent requires approval unless
allowlisted (fnmatch patterns over the agent name; denylist wins over
allowlist). Configurable via `[tools.task]` (PART-AGENTS section 9;
PART-PERMISSIONS section 4.5).

Runtime shape (PART-AGENTS section 9): each call creates a child session
(fresh session id, `is_subagent`, `parent_session_id` set) that inherits the
parent's permission store, is logged under `<parent session dir>/agents/`
with the agent name as prefix, and is persisted and resumable. The child's
prompt is the task text, prefixed with the parent's scratchpad directory when
one exists. The parent model summarizes the returned text — per the tool
prompt: "The subagent runs read-only and returns a final message — summarize
it to the user yourself."

### `skill`

**[stable]** One parameter: `name` — the skill name from `available_skills`
(installed-package schema dump, vibe 2.25.7 (2026-09-24)). Permission is
`always` — loading a skill never prompts (PART-SKILLS section 1.4).

The result is a `<skill_content name="...">` envelope carrying the skill body,
the skill's base directory ("Relative paths in this skill are relative to
this base directory."), and a sampled `<skill_files>` listing of the skill
directory: max 10 files listed, walk capped at 200 entries, skipping `.git`,
`node_modules`, `__pycache__`, `.venv`, `venv`, cache dirs, `dist`, `build`;
`SKILL.md` itself is excluded from the listing. A skill already loaded
returns: "Skill `&lt;name&gt;` is already loaded earlier in this conversation.
Reuse those instructions." (PART-SKILLS section 1.4).

### `ask_user_question`

**[stable]** Parameters (installed-package schema dump, vibe 2.25.7
(2026-09-24)):

| Parameter | Required | Description |
|---|---|---|
| `questions` | yes | Questions to ask (1-4 recommended); displayed as tabs if multiple |
| `footerNote` | no | Subtle note displayed at the bottom of the question widget |

Prompt contract: provide 1-4 questions, each with a header, question text,
and 2-4 options; an "Other" free-text option is added automatically
(installed-package schema dump, vibe 2.25.7 (2026-09-24)). Permission is
`always` in interactive use, but programmatic mode (`-p`) force-disables the
tool — headless sessions never block on user input (PART-TRUST section 3.4).

### `exit_plan_mode`

**[stable]** No parameters in the schema dump (installed-package schema
dump, vibe 2.25.7 (2026-09-24)). Permission is `always`, but every built-in
primary agent profile (`ask`, `plan`, `accept-edits`, `auto-approve`) carries
`disabled_tools: ["exit_plan_mode"]`, and programmatic mode force-disables it
(PART-PERMISSIONS section 4.1; PART-TRUST section 3.4). The prompt states
the contract: call only after the plan is finalized, never before, and not
when the user wants to keep planning.

### `todo`

**[stable]** Parameters (installed-package schema dump, vibe 2.25.7
(2026-09-24)):

| Parameter | Required | Description |
|---|---|---|
| `action` | yes | `'read'` to view the current list, or `'write'` to replace it |
| `todos` | no | Required on `action='write'`: the full todo list, which replaces the previous one |

`max_todos` defaults to 100. The prompt adds the discipline: keep one task
`in_progress` at a time, mark items completed, and include every item you
want to keep in each `write` (installed-package schema dump, vibe 2.25.7
(2026-09-24)).

### `web_fetch` and `web_search`

**[stable]** Parameters and config (installed-package schema dump, vibe
2.25.7 (2026-09-24)):

| Tool | Parameter | Required | Description |
|---|---|---|---|
| `web_fetch` | `url` | yes | The URL to fetch content from |
| `web_fetch` | `timeout` | no | Optional timeout in seconds (max 120) |
| `web_search` | `query` | yes | The search query |

| Tool | Config key | Default |
|---|---|---|
| `web_fetch` | `permission` | `ask` |
| `web_fetch` | `default_timeout` | 30 |
| `web_fetch` | `max_timeout` | 120 |
| `web_fetch` | `max_content_bytes` | 120000 |
| `web_fetch` | `user_agent` | `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36` |
| `web_search` | `permission` | `ask` |
| `web_search` | `timeout` | 120 |
| `web_search` | `model` | `mistral-vibe-cli-with-tools` |

`web_fetch` is read-only and returns fetched content as markdown;
`web_search` returns answers with cited sources, for recent events, updated
docs, and version checks (tool prompts, installed-package schema dump, vibe
2.25.7 (2026-09-24)). What backs `web_search` beyond the configured model name
is not covered by either source — see Known gaps.

---

## MCP and connector tools

**[stable]** naming; **[both]** connector default-enable (PART-CONNECTORS
section 2.4).

| Source | Published name | Example | Configured as |
|---|---|---|---|
| MCP server | `{alias}_{tool}` | `serena_list` | `[tools.serena_list]` — keyed by the full published name |
| Connector | `connector_{alias}_{tool}` | `connector_linear_delete_issue` | `[tools.connector_linear_delete_issue]` |

- MCP aliases come from the config entry's name; if a usable alias is absent,
  one is derived from the URL host (dots become underscores, port appended:
  `host_3000`). Tool descriptions are prefixed `[alias]` plus a space and may append a
  `Hint:` line from the server's `prompt` field (PART-MCP section 1.7;
  PART-CONFIG section 1.4).
- MCP tools take permissions exactly like built-ins, and the global
  `enabled_tools`/`disabled_tools` apply to them too — glob (`mcp_*`), `re:`
  regex, fullmatch semantics (PART-MCP section 1.8).
- Server-level disable is two-tier: `disabled = true` hides all of a server's
  tools; `disabled_tools` hides named tools (unprefixed names). Disabling is
  "discovered but hidden", not disconnected. Connectors use the same two-level
  mechanism (PART-MCP section 1.9; PART-CONFIG section 1.7).
- Connectors require `enable_connectors = true` (the default) plus a
  configured Mistral provider with a resolvable API key; without both, no
  connector registry is created. A discovered connector stays disabled until
  an explicit `[[connectors]]` entry exists on the legacy backend, while the
  unified harness enables ready connectors by default in memory
  (PART-CONNECTORS sections 2.2, 2.4).

---

## Known gaps

- **Which shell tool on which platform.** The package contains `bash`,
  `git_bash`, and `powershell` classes, and the `git_bash` prompt asserts
  "there is no `bash` tool" in its context — but neither the oracle nor the
  dump states which tool is exposed on which platform. Treat the quick
  reference as the inventory, not the per-OS manifest.
- **Windows default lists disagree between sources.** The oracle (2.25.0
  source) says the Windows variants carry `dir`/`findstr`-style allowlist
  entries and `cmd`/`powershell` standalone denies (PART-PERMISSIONS section
  4.4); the installed 2.25.7 dump shows `powershell` configured with the
  POSIX allowlist and POSIX `denylist_standalone`. Unresolved; the dump is
  the newer baseline but the oracle is the anchor of record.
- **`web_search`'s backing service.** The dump shows only `timeout = 120` and
  `model = "mistral-vibe-cli-with-tools"`; what serves that model and how
  citations are produced are not covered by either source.
- **`ask_user_question` UI details.** Beyond the prompt contract (1-4
  questions, headers, 2-4 options, automatic "Other", tabs for multiple
  questions, `footerNote`), widget rendering and interaction details are not
  covered.
- **`bash_log_file` action values.** The dump lists the parameters
  (`action`, `session_id`, `relative_path`, `offset`, `max_bytes`,
  `content`) without describing the accepted `action` values or their
  effects; the oracle does not cover this tool.
- **`max_inline_bytes` semantics.** The key exists on the shell and
  session-tool configs (default 30000 in the dump); what "inline" handling
  means precisely is not described in either source.
- **Custom tool format.** `tool_paths` and `~/.vibe/tools/` are verified as
  load locations (PART-CONFIG sections 1.3, 2.4), but the schema of a custom
  tool file is not covered by the oracle ranges read for this page.
- **`grep` engine.** The dump exposes defaults (100 matches, 60s timeout,
  `.vibeignore` as `codeignore_file`, the exclude list) but not the search
  implementation or exactly how `.vibeignore` interacts with
  `use_default_ignore` and the built-in excludes.
- **`exit_plan_mode` session effects.** What the call changes in the session
  beyond the prompt contract is outside the oracle ranges read here; see the
  agents and skills reference for plan-mode coverage.
- **Stable `bash` and background execution.** The schema dump shows
  background/session parameters only on the experimental variants; whether
  the stable `Bash` tool can run anything in the background is not stated
  anywhere in the sources read.

## See also

- [Settings reference](settings-reference.md) — the full `config.toml`
  surface, layering, and where `[tools.*]` edits persist
- [Hooks and events reference](hooks-events-reference.md) — `pre_tool` /
  `post_tool` hooks that observe every tool call
- [Agents and skills reference](agents-and-skills-reference.md) — agent
  profiles that override tool permissions, and the `explore` subagent
- [Plugins](plugins.md) — plugins as a tool source on the unified harness
- [Agent harness](agent-harness.md) — where the tool gate sits in the loop
- [Architecture](architecture.md) — the session store and child sessions
- [Context engineering](context-engineering.md) — output caps as a budget
- [Skill design patterns](skill-design-patterns.md) — the `skill` envelope
  and `task` fan-out in practice
- [Methodologies](methodologies.md), [Loop-graph engineering](loop-graph-engineering.md), [Memory systems](memory-systems.md), [Glossary](glossary.md)
- [Style guide](../style-guide.md)
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md)
