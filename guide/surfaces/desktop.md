---
title: "Vibe Code Desktop App: The Bundled-Harness macOS Client"
description: "The Vibe Code desktop app as verified from public artifacts: an Electron macOS application whose session runtime is the bundled vibe-app-server on mistralai_vibe_local_harness 0.5.1 — the same Session Protocol the CLI reaches via --experimental-harness. Work/Code modes, local/worktree/cloud session locations, the subagent side panel, and the six typed hook points. Oracle facts tagged [desktop-0.12.0]; installed bundle re-inspected at 0.14.0 on 2026-09-25."
tags: [guide, surfaces, desktop, unified-harness]
---

# Vibe Code Desktop App: The Bundled-Harness macOS Client

> **Verified against Vibe Code 0.14.0 on 2026-09-25.** Documented surface: installed desktop app bundle 0.14.0; oracle desktop mechanics 0.12.0; CLI release 2.25.8.
>
> The installed bundle moved past the oracle's anchor between inspections: the
> oracle tagged its desktop facts **[desktop-0.12.0]** from the 0.12.0 bundle on
> 2026-09-24 (PART-WEB section 4.6); `/Applications/Vibe.app` re-inspected on
> 2026-09-25 is version **0.14.0**. Oracle-cited mechanics keep the oracle's
> tag; claims read directly from the installed bundle are marked *bundle
> 0.14.0*. Every claim cites the oracle,
> [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as
> `(PART-XXX)` or the bundle itself.
>
> **TL;DR.** The Vibe Code desktop app is an Electron macOS application whose
> session runtime is a bundled `vibe-app-server` built on
> `mistralai_vibe_local_harness` 0.5.1 — the same Session Protocol the CLI
> reaches only via `--experimental-harness` (oracle backend tags;
> PART-HOOKS-UNIFIED). The verified surface is what the bundle states: Work or
> Code mode chats; Code-home indicators for **local / worktree / cloud** session
> locations; subagent conversations in a side panel; model changes applied
> mid-turn and recorded in session history; provider explanations inside
> provider errors; and credential redaction in diagnostic exports (PART-WEB
> section 4.6). Feature claims come from the bundle's own release notes —
> 0.12.0 via the oracle, 0.14.0 read from the installed bundle — not from
> driving the UI.

**Read if** you want to know what the desktop app is, which session backend it
runs, and what its own release notes claim. **Skip if** you want installable
mechanics — the CLI surface is the sibling chapter [`cli.md`](./cli.md) and the
cloud-session model is [`web.md`](./web.md).

## 1. What the app is

| Fact | Value | Source |
|---|---|---|
| Bundle | `/Applications/Vibe.app`, Electron (asar integrity hash present), macOS `.app` | PART-WEB section 4.6; bundle 0.14.0 |
| Installed version | 0.14.0 (`CFBundleShortVersionString` = `CFBundleVersion` = `0.14.0`) | bundle 0.14.0, re-inspected 2026-09-25; the oracle recorded 0.12.0 (PART-WEB section 4.6) |
| Bundle identifier | `ai.mistral.lechat.desktop` | PART-WEB section 4.6; bundle 0.14.0 |
| URL scheme | `lechat://` | PART-WEB section 4.6; bundle 0.14.0 |
| Session runtime | `vibe-app-server` — a Python 3.12 runtime under `Contents/Resources/bin/vibe-app-server/` | PART-WEB section 4.6; directory present in the 0.14.0 bundle, re-inspected 2026-09-25 |
| Harness | `mistralai_vibe_local_harness` 0.5.1 (dist-info `Version: 0.5.1` in the installed bundle) | bundle 0.14.0, re-inspected 2026-09-25; matches the 0.12.0 bundle (PART-HOOKS-UNIFIED preamble) |
| Release notes | `Contents/Resources/RELEASE_NOTES.md` — "What's New in v0.14.0" | bundle 0.14.0, re-inspected 2026-09-25 |

The app does not need the CLI installed: it ships its own session runtime. The
CLI reaches the same Session Protocol only through `--experimental-harness`
plus the `mistralai_vibe_local_harness` package — the oracle's
**[unified-harness]** backend, whose flag is suppressed from `--help` when
that package is absent (oracle backend tags). So the mechanics that apply
inside a desktop session are the [unified-harness] mechanics
(PART-HOOKS-UNIFIED), not the CLI's default [stable] backend. Whether the app
can also run a non-harness session is stated nowhere public — see
[Known gaps](#known-gaps).

## 2. The session model: modes and locations [desktop-0.12.0]

| Surface | What the v0.12.0 notes state | Citation |
|---|---|---|
| Modes | Work or Code mode chats; `Cmd/Ctrl+N` starts a new chat in the current mode | PART-WEB section 4.6 |
| Session location | Code home and new-session controls show whether a session runs **locally, in a worktree, or in the cloud** | PART-WEB section 4.6 |
| Pinned sessions | Remain visible on their project page | PART-WEB section 4.6 |
| Worktree sessions | Show setup progress | PART-WEB section 4.6 |
| Local session opening | Much faster, especially for projects with many worktrees; model and approval controls appear without waiting for a resume | PART-WEB section 4.6 |

The installed 0.14.0 bundle extends the same model (bundle 0.14.0,
`RELEASE_NOTES.md`):

- Archive and restore local Code sessions; archiving removes them from active
  lists and cleans up managed worktrees when they become idle.
- Local sessions keep their selected thinking level when reopened.
- Custom agents and their prompts work again in local sessions.
- Nested `AGENTS.md` instructions are applied when the agent reads files in
  subdirectories.
- Outside-project approvals apply only to the selected file or folder.

### What "in the cloud" refers to

The release notes do not name the cloud backend. The only cloud-session model
in the verified public surface is Vibe Code Web's, documented at
docs.mistral.ai and tagged **[docs-only]** in the oracle (PART-WEB section
4.3):

| Cloud-session fact | Value | Citation |
|---|---|---|
| Runtime model | Mistral Medium 3.5, regardless of the local model | PART-WEB section 4.3 [docs-only] |
| Limits | 24 h max duration, 3 h inactivity timeout, plan-dependent concurrency | PART-WEB section 4.3 [docs-only] |
| Sandbox | Isolated single-tenant sandbox per session; deleted at session end; branches, commits, and PRs persist in GitHub | PART-WEB section 4.3 [docs-only] |
| Projects | One or more GitHub repos from the same owner; Mistral GitHub App token | PART-WEB section 4.3 [docs-only] |

The CLI reaches those cloud sessions through the `&` prompt prefix (spawn a
new cloud session) and `/teleport` (move the current session there) — both
[stable] CLI mechanics (PART-WEB sections 4.1-4.2). The oracle verifies the
desktop app's cloud indicator only as a release-notes claim: whether the
app's cloud flow is these same Vibe Code Web sessions end-to-end was not
verified, because no GUI automation or account-driven run was performed (see
[Known gaps](#known-gaps)).

## 3. Subagents in the side panel [desktop-0.12.0]

The v0.12.0 note, verbatim: "Open subagent conversations in a side panel
(more polish to come on subagents)" (PART-WEB section 4.6). The parenthetical
is the app's own honesty about the maturity of its subagent UX — read it as a
caveat, not as a settled design.

The installed 0.14.0 bundle describes the next step on the same surface:
"Subagent polish: launches now stay in place in the parent conversation, with
cleaner grouped access to child conversations" (bundle 0.14.0,
`RELEASE_NOTES.md`). On the harness side, the CLI changelog records that
since 2.25.1 "Hooks now run inside subagents on the experimental harness,
instead of being silently skipped" [unified-harness] (PART-HOOKS-UNIFIED) —
the same harness family the app bundles.

For the CLI-side subagent mechanics (the `task` tool, the built-in `explore`
agent, custom agent TOML files), see the sibling CLI chapter and
[Agents and Skills Reference](../core/agents-and-skills-reference.md).

## 4. The harness under the app: six typed hook points [unified-harness]

Divergence to state up front (PART-HOOKS-UNIFIED): the CLI's `hooks.toml`
wire protocol has **three** event types — `pre_tool`, `post_tool`,
`post_agent` ([stable], PART-HOOKS) — while the Session Protocol the desktop
app bundles declares **six** typed hook points:

```python
# /Applications/Vibe.app/Contents/Resources/bin/vibe-app-server/_internal/
#   mistralai_vibe_local_harness/session_protocol.py  (mistralai-vibe-local-harness 0.5.1)
type HarnessHookPoint = Literal[
    "pre_agent_turn",
    "post_agent_turn",
    "pre_llm_call",
    "post_llm_call",
    "pre_tool_call",
    "post_tool_call",
]
```

Per-point decisions (PART-HOOKS-UNIFIED):

| Hook point | Continue | Skip / deny / rewrite |
|---|---|---|
| `pre_agent_turn` | `PreAgentTurnHookContinue(user_content=...)` | `PreAgentTurnHookSkip(reason=[TextContentBlock...])` |
| `pre_llm_call` | `PreLlmCallHookContinue` | `PreLlmCallHookSkip(reason=[...])` |
| `pre_tool_call` | `PreToolCallHookContinue(effective_arguments={...})` (argument rewrite) | `PreToolCallHookSkip(reason=[...])` |
| `post_tool_call` | `PostToolCallHookContinue(tool_result=...)` (result rewrite) | — (continue-only; result replacement) |
| `post_llm_call` | `PostLlmCallHookAccept` | `PostLlmCallHookRetry(feedback=...)` / `PostLlmCallHookReject(reason=[...])` |
| `post_agent_turn` | `PostAgentTurnHookAccept` | `PostAgentTurnHookRetry(feedback=...)` / `PostAgentTurnHookReject(reason=[...])` |

Rules that shape any hook written against this surface (PART-HOOKS-UNIFIED):

- `ToolNameHookMatcher(tool_names=[...])` is allowed only on `pre_tool_call` /
  `post_tool_call`; every other point requires `AlwaysHookMatcher()`.
- Hooks are serializable `HookDefinition`s registered via a
  `CapabilityRegistrationRegistry` binding ID, like provided tools; duplicate
  binding/hook IDs, ambiguous tool-name matchers, and direct-name collisions
  are rejected.

Caveat that belongs with the table: this is the protocol the app's runtime
implements. How a user attaches a hook inside the desktop app — or whether
the UI exposes hook configuration at all — is stated nowhere in the public
surface (see [Known gaps](#known-gaps)). The protocol itself is verified from
the bundled harness source, the desktop-bundled harness 0.5.1, and the
`mistralai-vibe-harness` SDK docs (PART-HOOKS-UNIFIED); the full catalog is in
[Hooks and Events Reference](../core/hooks-events-reference.md).

## 5. Reliability and diagnostics in the notes [desktop-0.12.0]

| Behavior | What the v0.12.0 notes state | Citation |
|---|---|---|
| Model changes mid-turn | Applied reliably and recorded in session history | PART-WEB section 4.6 |
| Provider errors | Include the provider's explanation when one is available | PART-WEB section 4.6 |
| Diagnostic exports | Remove credentials from Azure, AWS, and Google Cloud signed URLs | PART-WEB section 4.6 |
| Configured font size | Properly saved; may switch the user to the recommended 14px depending on pre-existing config | PART-WEB section 4.6 |

The 0.14.0 bundle adds, in the same register (bundle 0.14.0,
`RELEASE_NOTES.md`): background-process launches now appear in the
conversation ("inspection and controls still to come"), and a fix for startup
on macOS 26 and later when the native harness failed to load.

## 6. What the release notes are — and are not

The notes are the entire verified public record of app behavior: a list of
recently shipped fixes and features, plus the subagent-polish caveat quoted
above. No public issue tracker, archived changelog, or roadmap for the app
exists in the verified surface, so nothing beyond these lines is asserted
here. The v0.12.0 notes, as recorded by the oracle (PART-WEB section 4.6):

```markdown
- Open subagent conversations in a side panel (more polish to come on subagents)
- Cmd/Ctrl+N now starts a new chat in the current Work or Code mode. The existing global shortcut now only opens Vibe.
- Model changes made during a running turn are now applied reliably and recorded in session history.
- Opening local sessions is much faster, especially for projects with many worktrees. Model and approval controls appear without waiting for a resume, and new worktree sessions show setup progress.
- Pinned sessions now remain visible on their project page.
- Code home and new-session controls now show more clearly whether a session will run locally, in a worktree, or in the cloud.
- Long code lines and Code sidebar project names no longer get clipped. Split-view scrollbars and answer footers also behave more consistently.
- Provider errors now include the provider's explanation when one is available.
- Configured font size is now properly saved. This might have the effect of switching you to the recommended 14px depending on your pre-existing config.
- Login and onboarding screens now use the animated branding from web sign-in.
- Diagnostic exports now remove credentials from Azure, AWS, and Google Cloud signed URLs.
```

The installed 0.14.0 bundle's notes, verbatim (bundle 0.14.0, re-inspected
2026-09-25):

```markdown
- Archive and restore local Code sessions. Archiving removes them from active lists and cleans up managed worktrees when they become idle.
- Subagent polish: launches now stay in place in the parent conversation, with cleaner grouped access to child conversations.
- Background process launches now appear in the conversation, with inspection and controls still to come.
- Local sessions now keep their selected thinking level when reopened.
- Custom agents and their prompts now work again in local sessions.
- Fixed startup on macOS 26 and later when the native harness failed to load.
- Nested `AGENTS.md` instructions are now applied when the agent reads files in subdirectories.
- Outside-project approvals now apply only to the selected file or folder.
```

Read both as a fixes list, not as a feature catalog: each line names
something that changed recently. The gap between 0.12.0 and 0.14.0 — the
0.13.x notes are not in the installed bundle — is unaccounted for on any
public surface.

## Known gaps

- **This chapter documents a moving target.** The oracle's desktop facts are
  tagged [desktop-0.12.0] (verified 2026-09-24); the installed bundle was
  already 0.14.0 on re-inspection one day later (2026-09-25). Re-inspect the
  bundle each release before relying on any line here.
- **No GUI automation was performed.** Everything here comes from bundle
  metadata (`Info.plist`, dist-info) and the bundle's own release notes. The
  oracle records the same limit: desktop session-location indicators and
  modes beyond what the notes state were not verified (oracle, Needs public
  verification — web/connectors/plugins pass).
- **Unverified surfaces, stated as unverified:** the settings surface, config
  sharing with the CLI, plan/account gating, the update mechanism, and
  availability outside macOS. None is documented in the verified public
  surface; this chapter asserts nothing about them.
- **Config/trust and skills/session surfaces were not inspected for the
  desktop app** by the oracle's dedicated passes (oracle, Needs public
  verification — config/trust/permissions pass; skills/commands/sessions
  pass). Whether the app honors `~/.vibe/config.toml`,
  `trusted_folders.toml`, or the skills registry is unknown from public
  sources.
- **Hook configuration in the app is unverified.** The six typed points are
  the protocol (PART-HOOKS-UNIFIED); whether the app UI exposes hook
  attachment is stated nowhere public, and the harness-side loading
  differences between the desktop's 0.5.1 and the CLI's in-repo app-server
  code were not diffed (oracle, Needs public verification — hooks/agents
  pass).
- **The app's cloud flow is unverified end-to-end.** The cloud indicator is a
  release-notes claim (PART-WEB section 4.6); confirming that the app's
  cloud sessions are the Vibe Code Web sessions of PART-WEB section 4.3
  would require an account-driven run, which was not performed.
- **0.13.x release notes are absent** from the installed bundle and from the
  oracle; behavior that changed in those versions is invisible here.

## See also

- [`cli.md`](./cli.md) — the sibling CLI chapter: `--experimental-harness`,
  the three-event `hooks.toml` protocol, and the installable surface
- [`web.md`](./web.md) — the sibling Vibe Code Web chapter: the cloud-session
  model this app's cloud indicator refers to
- [Hooks and Events Reference](../core/hooks-events-reference.md) — the six
  typed harness hook points and the CLI's `hooks.toml` protocol, side by side
- [How the Vibe CLI Works](../core/architecture.md) — the two CLI session
  backends and where the unified harness sits
- [Agents and Skills Reference](../core/agents-and-skills-reference.md) —
  subagents and custom agents on the CLI surface
- [Data Privacy in Vibe](../security/data-privacy.md) — what leaves your
  machine, adjacent to the export-redaction note above
- The mechanics oracle:
  [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md) —
  PART-WEB section 4.6 (desktop bundle), PART-HOOKS-UNIFIED (six hook points)
