---
title: "Vibe Code Web"
description: "The cloud surface: three bridges from the CLI (/teleport, &, /remote-project), the cloud session model (entities, lifecycle, limits, sandbox), prerequisites, the CLI/VS Code/Web comparison, and the Slack integration — with every claim tagged [stable] or [docs-only]."
tags: [guide, surfaces, web, cloud-sessions, cli]
---

# Vibe Code Web

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8; Vibe Code Web claims are docs-verified on 2026-09-24 and tagged [docs-only].
>
> Every command, flag, config key, and file path here cites the mechanics oracle,
> [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as
> `(PART-XXX section N)`. CLI-side mechanics are source-verified against
> vibe 2.25.0; release-2.25.8 changes are marked "documented in release 2.25.8
> (source)" (PART-DELTAS). No live verification of the cloud side was possible,
> so every claim about Vibe Code Web itself is **[docs-only]** — documented on
> docs.mistral.ai pages fetched 2026-09-24 (HTTP 200) and tagged as such.

Two evidence tiers run through this page — CLI-side mechanics are
source-verified, cloud-side behavior is docs-only — and every section states
which.

> **TL;DR.** Vibe Code Web runs sessions in a per-session cloud sandbox instead
> of on your machine. Three bridges exist from the CLI: `/teleport` moves the
> **current** session to the cloud (PART-WEB section 4.1), `& <prompt>` spawns a
> **new** cloud session and prints the web URL (PART-WEB section 4.2;
> PART-SESSIONS section 6.3), and `/remote-project` binds the repository to a
> Vibe Code Web project, stored in `~/.vibe/projects.toml` (PART-WEB section
> 4.1). Teleport is one-way — the docs state a session cannot be pulled back to
> the local CLI (PART-WEB section 4.1). Cloud sessions run Mistral Medium 3.5
> regardless of the local model, capped at 24 h per session, 3 h inactivity, and
> 30 s per command; the sandbox is deleted at session end while branches,
> commits, and PRs persist in GitHub (PART-WEB section 4.3, [docs-only]).

**Read if** you want sessions that outlive your terminal, or you want to hand a
task to a cloud sandbox straight from the CLI. **Skip if** you never leave local
execution — the local surface is [Vibe CLI](./cli.md), and headless CI runs are
[Automation](../ops/automation.md).

## 1. Three bridges from the CLI

The CLI talks to Vibe Code Web through exactly three mechanisms — two slash
commands and one input prefix. All three are **[stable]** mechanics, verified
from the 2.25.0 source (PART-WEB sections 4.1-4.2; PART-SESSIONS section 6.3;
PART-COMMANDS).

| Bridge | What it does | Availability | Citation |
|---|---|---|---|
| `/teleport` | Moves the **current** session to Vibe Code Web | Vibe Code enabled and **not** under `--experimental-harness` | PART-WEB section 4.1; PART-COMMANDS |
| `& <prompt>` | Spawns a **new** cloud session with that prompt; the CLI prints the web URL | Only when the `/teleport` command is available | PART-WEB section 4.2; PART-SESSIONS section 6.3 |
| `/remote-project` | Binds this repository to a Vibe Code Web project, stored in `~/.vibe/projects.toml` | Vibe Code enabled | PART-WEB section 4.1 |

```text
vibe
& fix the failing auth tests        # spawns a NEW cloud session; CLI prints the web URL
/teleport                           # moves the CURRENT session to the cloud
```

(PART-WEB section 4.2; the transcript layout is the oracle's own.)

### 1.1 `/teleport` — move the current session

The `/teleport` flow, from the 2.25.0 source (PART-WEB section 4.1):

1. Checks that the session runs inside a Git repository.
2. May require a push first (`TeleportPushRequiredEvent`).
3. Resolves the Vibe Code Web project for the repository (project picker;
   `open_projects(for_teleport=True, ...)`).
4. Uploads the session via the cloud-session client, with messages and diffs
   zstandard-compressed before they are sent to the cloud session workflow.

**Harness divergence:** `/teleport` is additionally unavailable under
`--experimental-harness` — the unified harness does not teleport (PART-WEB
section 4.1; PART-COMMANDS). If your sessions run on the experimental harness,
`/teleport` is not offered at all.

### 1.2 `/remote-project` — bind the repository

`/remote-project` opens the project picker to bind this repository to a Vibe
Code Web project; the binding is stored in `~/.vibe/projects.toml` via
`VibeProjectsStore` (PART-WEB section 4.1).

### 1.3 The `&` prefix — spawn a new cloud session

Input classification order in the chat input: `&…` → Teleport (only if the
`/teleport` command is available), `/…` → slash command, `/…` skill prompt,
`!…` → bash, else a plain prompt (PART-WEB section 4.2). The `&` form is the
prefix form of `/teleport` — it is classified `Teleport(target=rest)` and sends
the prompt to a Vibe Code Web sandbox; the CLI returns a link to the cloud
session (PART-SESSIONS section 6.3). The prompt widget shows `&` as the prompt
char (PART-WEB section 4.2).

None of these queue: `/teleport`, `/remote-project`, and `&`-prefixed input are
rejected while the agent is busy and must be retried when idle (PART-COMMANDS;
PART-SESSIONS section 6.3).

### 1.4 Gating keys, and the 2.25.8 delta

In 2.25.0, "Vibe Code enabled" is config-driven: `vibe_code_enabled` (default
`true`, marked "Internal" in the schema), plus `vibe_code_api_key_env_var`
(default `MISTRAL_API_KEY`) and `vibe_code_sessions_base_url` (default
`https://chat.mistral.ai`) (PART-WEB section 4.1).

Per-claim version pins, because the surface moved between releases:

| Claim | Pin | Citation |
|---|---|---|
| `/teleport` and `/remote-project` gating on `vibe_code_enabled` | Source-verified at 2.25.0 | PART-WEB section 4.1; PART-COMMANDS |
| `--experimental-harness` excludes `/teleport` | Source-verified at 2.25.0 | PART-WEB section 4.1 |
| `vibe_code_enabled` / `vibe_code_api_key_env_var` appear removed in the release source; teleport/remote-project no longer gated by `vibe_code_enabled` there | Documented in release 2.25.8 (source), not live-verified | PART-DELTAS; PART-COMMANDS |

## 2. Teleport is one-way

Teleport moves a session to the cloud, not both ways. The docs state that you
cannot pull a session back to the local CLI, and list return teleport as a
planned follow-up (PART-WEB section 4.1). That is the full extent of the
verified statement: no return mechanism exists today, and no further roadmap is
asserted here.

The practical consequence: teleport only when the session's remaining work
belongs in the cloud. Your local copy of the session stays on disk, but the
live thread continues in the web session.

## 3. The cloud session model [docs-only]

Everything in this section is **[docs-only]** — documented on docs.mistral.ai
(fetched 2026-09-24, HTTP 200), with no live verification possible
(PART-WEB section 4.3).

### 3.1 Entities

| Entity | What it is | Citation |
|---|---|---|
| Project | One or more GitHub repositories from the same owner, named | PART-WEB section 4.3 |
| Repository | Cloned into the sandbox; Mistral GitHub App user token; commits attributed to you | PART-WEB section 4.3 |
| Session | One agent run; spawned from the web, from the CLI `&`, or via `/teleport` | PART-WEB section 4.3 |

Sessions are personal — visible only to their creator (PART-WEB section 4.3).

### 3.2 Lifecycle and states

A session's user lifecycle is Spawn → Run → Follow → Review, on a per-session
isolated single-tenant sandbox; the sandbox phases are Start / Clone / Run /
Review / End (PART-WEB section 4.3).

| State kind | States | Citation |
|---|---|---|
| Active | Active / Waiting for input / Idle / Stopped | PART-WEB section 4.3 |
| End | Completed / Timed out / Error | PART-WEB section 4.3 |

Persistence rules (PART-WEB section 4.3):

- The sandbox is deleted at session end.
- Branches, commits, and PRs persist in GitHub.
- Past sessions are inspectable but not resumable after deprovisioning.
- A pushed PR does not end the session.

### 3.3 Limits

| Limit | Value | Citation |
|---|---|---|
| Max session duration | 24 h | PART-WEB section 4.3 |
| Inactivity timeout | 3 h | PART-WEB section 4.3 |
| Per-command timeout | 30 s | PART-WEB section 4.3 |
| Concurrency | Plan-dependent | PART-WEB section 4.3 |
| Sessions per day | Free: 2; paid: 100 | PART-WEB section 4.3 |
| Model | Mistral Medium 3.5, regardless of the local model; non-Mistral local sessions default to Medium 3.5 in the cloud | PART-WEB section 4.3 |

### 3.4 Sandbox

| Property | Behavior | Citation |
|---|---|---|
| Image | Default Linux image: POSIX shell, Git, GitHub App credentials, common runtimes | PART-WEB section 4.3 |
| Credentials | GitHub App user token plus a small set of managed variables | PART-WEB section 4.3 |
| Commits | Attributed to you | PART-WEB section 4.3 |
| Tooling | The agent installs missing tooling at session time | PART-WEB section 4.3 |
| Network | Outbound-only managed internet; no inbound exposure | PART-WEB section 4.3 |
| Customization | No custom sandbox configuration yet | PART-WEB section 4.3 |
| Your machine | The sandbox has no access to it | PART-WEB section 4.3 |

## 4. Prerequisites

The docs list the same prerequisites for both CLI entry points (PART-WEB
section 4.2, [docs-only]):

| Prerequisite | Citation |
|---|---|
| Pro, Team, or Enterprise API key | PART-WEB section 4.2 |
| The Mistral GitHub App installed on the repository | PART-WEB section 4.2 |
| The local session on a Mistral model | PART-WEB section 4.2 |
| Run from inside a Git repository | PART-WEB section 4.2 |

## 5. Surfaces compared [docs-only]

| | CLI | VS Code extension | Vibe Code Web |
|---|---|---|---|
| Extension | — | "Mistral Vibe for VS Code", marketplace `mistralai.mistral-vibe-code`, VS Code >= 1.94.0 | — |
| What ships | The `vibe` binary | The agent, built in — no CLI install required; webview chat panel | Remote sandbox, no local install |
| Non-interactive mode | `vibe --prompt` | None | — |
| Context | Terminal | Editor context via ACP | The GitHub repository |
| Shared with CLI | — | Config and sessions | — |

All rows in this table are [docs-only] (PART-WEB section 4.4). Vibe implements
the Agent Client Protocol and is published in the ACP registry
([github.com/agentclientprotocol/registry/tree/main/mistral-vibe](https://github.com/agentclientprotocol/registry/tree/main/mistral-vibe)),
so it runs in other ACP-compatible clients including JetBrains IDEs (PART-WEB
section 4.4). Custom agents, skills, MCP servers, and connectors work on all
three surfaces (PART-WEB section 4.4).

For the local surfaces in depth, see [Vibe CLI](./cli.md) and
[Vibe Code Desktop](./desktop.md).

## 6. Slack integration [docs-only]

The docs page "Vibe Code Web for Slack: Quickstart" describes a fourth entry
point (PART-WEB section 4.5, [docs-only]):

- An org admin connects Slack at `admin.mistral.ai/organization/connectors` —
  one Slack workspace per Mistral organization, via an OAuth flow.
- The "Mistral Vibe" app then appears in the Slack workspace; the Slack MCP
  connector is usable via Vibe Work (`chat.mistral.ai/connections`).
- Starting work: `@Vibe <task>` in a Slack thread. The app reads the thread
  context, maps it to a project and repository (asking if ambiguous), creates a
  Vibe Code Web session, and posts the link back to the thread. The result is a
  GitHub branch or PR.
- Caveat, verbatim from the docs page itself: the start-sessions-from-Slack
  feature is in "progressive rollout. It will be available soon."
- The docs caution against pasting secrets into Slack.

## Known gaps

- **No live verification of any cloud-side behavior.** The oracle states this
  explicitly: no Mistral account with Vibe Code Web access was available, so
  every claim about the web surface is [docs-only] (PART-WEB section 4.3). This
  page inherits that limitation.
- **Quota enforcement, sandbox image contents, and the Slack rollout status are
  docs-only.** The 2/100 sessions-per-day numbers, the default image's
  contents, and whether start-from-Slack is actually available to your
  workspace have not been observed.
- **Planned follow-ups, asserted no further.** The docs list — Slack and
  GitHub-event triggers, teleport back to the CLI, approvals, cancel,
  interrupt, and steering, notifications and a rich diff UI, and custom sandbox
  config/secrets/env vars — is reproduced as documentation of intent, not a
  roadmap we assert beyond that list (PART-WEB sections 4.1, 4.3, 4.5).
- **The 2.25.8 config-key removal is source-diff only.** `vibe_code_enabled`
  and `vibe_code_api_key_env_var` appearing removed is documented in release
  2.25.8 source, not live-executed against the installed 2.25.0 build
  (PART-DELTAS).

## See also

- [Vibe CLI](./cli.md) — the local surface whose commands (`/teleport`,
  `/remote-project`, `&`) bridge to the cloud
- [Vibe Code Desktop](./desktop.md) — the desktop app surface
- [Automation](../ops/automation.md) — headless `-p` runs and `/loop`, the
  local counterparts to handing work to a cloud session
- The mechanics oracle:
  [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md) —
  PART-WEB is this page's source; PART-SESSIONS section 6.3 covers the `&`
  prefix
