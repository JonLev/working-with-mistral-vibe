---
title: "Production Safety Rules"
description: "Six non-negotiable rules for teams running Vibe against production systems, each enforced through verified mechanics: config deny rules, strict hooks, AGENTS.md policy, and headless CI bounds."
tags: [security, guide, production, cli]
---

# Production Safety Rules

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics cite the oracle, [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as `(PART-XXX)`. Claims marked *live-verified on 2.25.7* were executed against the installed CLI; their transcripts (T1-T8) are in [`docs/mechanics/live-checks.md`](../../docs/mechanics/live-checks.md). Everything else is source-verified at release 2.25.8. Backend tags `[stable]` / `[unified-harness]` / `[both]` mark backend-dependent mechanics; `[docs-only]` marks doc-resting claims the oracle could not live-verify.

> **TL;DR.** Six rules — port stability, database safety, feature completeness, infrastructure lock, dependency safety, pattern following — each enforceable through three verified layers: `[tools.*]` deny rules in project `.vibe/config.toml` (deterministic, checked first), `strict = true` hooks in `.vibe/hooks.toml` (your logic, fail-closed), and `AGENTS.md` policy (model-followed, not a gate). In headless (`-p`) mode the default is deny — approval-required calls are never silently approved — and `--max-turns` / `--max-price` / `--max-tokens` bound the run.

**Read if** your team points Vibe at production code, databases, or infrastructure. **Skip if** you are learning or prototyping alone — the built-in approval prompts are enough friction, and these rules will mostly slow you down.

## The enforcement stack [stable]

Every rule below is an instance of one stack. Learn it once:

| Option | Lives in | Enforced by | If you get it wrong |
|---|---|---|---|
| **A — deny rules** | `.vibe/config.toml`, `[tools.*]` `denylist` / `permission = "never"` | The harness, per call | A wrong glob leaves the file silently unprotected |
| **B — strict hooks** | `.vibe/hooks.toml`, `pre_tool` with `strict = true`, or `post_agent` | The harness plus your script | Omit `strict = true` and a broken guard still lets the tool run (live-verified on 2.25.7, T3) |
| **C — AGENTS.md policy** | Repo `AGENTS.md`, checked in | The model | Nothing — it is policy, not a gate; pair it with A or B for anything critical |

Facts that decide which option a rule needs:

- File tools (`read_file`, `write_file`, `edit`), per call: scratchpad → **denylist** → allowlist → `sensitive_patterns` → outside-workspace check → config `permission`. The denylist is a path glob (fnmatch on the resolved path) checked **first** — deny always wins over allow (PART-PERMISSIONS section 4.3).
- Bash, per parsed command part: **denylist prefix match** → `denylist_standalone` (bare interpreters) → `find -exec` always-ask → outside-directory scan (runs even for allowlisted commands) → unconditional allow → ask. Matching is prefix equality (`command == pattern` or `command.startswith(pattern + " ")`) — lists cannot match text *inside* a command; content rules need a hook (PART-PERMISSIONS section 4.4).
- Keys: `[tools.bash]` takes `permission` (`"ask"` / `"always"` / `"never"`), `allowlist`, `denylist`, `denylist_standalone`, `sensitive_patterns`; every tool takes `permission`, `allowlist`, `denylist`, `sensitive_patterns` (PART-CONFIG section 1.3). Use these names: the docs' `allow` / `deny` spelling is read by no code path and is silently ignored — a wrong key means your guard never loads (PART-CONFIG section 1.3, docs-drift ledger).
- The default agent is `accept-edits`: file edits auto-approve out of the box (PART-PERMISSIONS section 4.1). Without an explicit deny rule, nothing stops an edit to `docker-compose.yml`. The default `sensitive_patterns` do cover `**/.env*`-style files (PART-CONFIG section 1.3) — they prompt even under `accept-edits`, and headless that means denied (live-verified on 2.25.7, T7).

### The canonical guard [both]

One hook shape serves every Option B below. A `pre_tool` hook fires per tool call **before** the permission prompt, reads a JSON payload from stdin, and denies by printing a JSON decision with exit 0; the first deny short-circuits, and the reason reaches the model as a tool error, so it learns why the call was blocked (PART-HOOKS sections 1, 3.3; live-verified on 2.25.7, T1).

```toml
# <project>/.vibe/hooks.toml
[[hooks]]
name = "deny-rm-rf"
type = "pre_tool"
match = "bash"
command = "python ./.vibe/hooks/guard-bash.py"
strict = true
```

```python
# ./.vibe/hooks/guard-bash.py — guard shape from PART-HOOKS section 3.8
import json, sys
payload = json.load(sys.stdin)
command = payload.get("tool_input", {}).get("command", "")
if "rm -rf" in command:
    print(json.dumps({"decision": "deny",
                      "reason": "rm -rf is blocked by the deny-rm-rf hook."}))
    sys.exit(0)
# Passthrough: empty stdout, exit 0.
```

`strict = true` is the whole ballgame, live on 2.25.7: with it, a guard that crashes or times out denies the call — the UI names the cause, `Denied tool 'bash' (strict)` (T2). Without it, the same crashed guard is a warning and the command runs anyway (T3). A fail-open hook means a broken guard still lets the tool run; security hooks set `strict = true`. Note also that a non-zero exit is a hook *failure*, not a deny — the deny contract is stdout JSON with exit 0 (PART-HOOKS section 3.3).

## Rule 1: Port stability

**The problem.** Changing service ports breaks local setups, compose files, deployed configs, and every teammate's environment at once. Reported incident: a backend port moved from 3000 to 8080 during a refactor; the team lost a day reconfiguring, and staging failed silently because the proxy still pointed at 3000.

**The rule. Never modify backend/frontend ports without explicit team permission.** Adding a new service or changing a test-env port is fine — new ports do not break existing ones. A port conflict on one machine is resolved locally (`.env.local`, which matches `**/.env.*` in the default `sensitive_patterns`, so editing it still prompts — PART-PERMISSIONS section 4.3).

**A — deny rules.** Path globs, resolved against the absolute path, hard `NEVER` (PART-PERMISSIONS section 4.3; PART-CONFIG section 1.3):

```toml
# .vibe/config.toml
[tools.edit]
denylist = ["**/docker-compose.yml", "**/docker-compose.*.yml", "**/vite.config.*", "**/.env.example"]
[tools.write_file]
denylist = ["**/docker-compose.yml", "**/vite.config.*"]
```

Cover the bash side too. A `[tools.read_file]` denylist does not protect a file: live on 2.25.7, a denied `read_file` was bypassed on the next turn by `bash` running `cat secret.txt` — `cat` is in the default read-only allowlist and the denylist is per-tool (T5). The same per-tool logic means `sed`, `tee`, and shell redirection rewrite files without passing the file-tool chain. Either deny the command (`[tools.bash] denylist = ["sed"]` blocks every `sed ...` invocation, prefix match, PART-PERMISSIONS section 4.4) or add the Option B guard.

**B — strict hook.** The canonical guard with a condition of your choice — e.g. deny any bash command that pairs a protected filename with a rewrite (`sed`, `tee`, `>`).

**C — AGENTS.md.**

```markdown
## Port configuration
Ports are locked: frontend (Vite) 5173, backend (Express) 3000, database 5432.
To change a port: open an RFC under docs/rfcs/, get team approval, update all
environments in one change, notify the team 48h ahead.
```

Project `AGENTS.md` is injected as instructions that the prompt says override default behavior; project beats user, closer directory beats distant (PART-AGENTSMD). It is policy the model follows, not a gate the harness enforces.

## Rule 2: Database safety

**The problem.** Destructive operations against production are data loss. Reported incidents: `DELETE FROM users WHERE id = 123` missing the `WHERE` deleted all users; `DROP TABLE sessions` during "cleanup" dropped a production table; a migration ran with no rollback and no backup.

**The rule. Always create a backup before a destructive operation** — `DROP`, `TRUNCATE`, `DELETE FROM`, `ALTER ... DROP`, and migrations that cannot roll back.

**A — deny rules.** Content patterns like `DROP TABLE` cannot be expressed in a bash denylist: matching is prefix equality on parsed command parts, and `psql -c "DROP TABLE sessions"` starts with `psql` (PART-PERMISSIONS section 4.4). What lists can do is deny the CLI outright — which blocks legitimate runs too; that is the point, the deny forces the operation through a human. The shipped defaults already deny interactive debuggers and shells (`gdb`, `pdb`, `bash -i`, bare `python` via `denylist_standalone` — PART-PERMISSIONS section 4.4).

```toml
[tools.bash]
denylist = ["psql", "mysql", "prisma migrate"]
```

**B — strict hook.** The one thing lists cannot do — content matching (canonical guard, `strict = true`):

```python
if re.search(r"(DROP\s+TABLE|TRUNCATE|DELETE\s+FROM|ALTER\s+TABLE.*DROP)", command, re.I):
    print(json.dumps({"decision": "deny",
                      "reason": "Destructive database operation. Create and verify "
                                "a backup, then ask a human to run it."}))
    sys.exit(0)
```

**C — AGENTS.md.**

```markdown
## Database operations
Never run DROP / TRUNCATE / DELETE FROM / ALTER...DROP without a backup.
Protocol: announce in the ops channel; run ./scripts/backup-db.sh; verify the
backup is non-empty; execute in staging first; wait 24h; execute in production
with an on-call engineer present.
```

If you expose a database through an MCP server, the read-only-user principle survives unchanged: point the server at a read-only credential via its `env` block (PART-CONFIG section 1.4). The credential is the boundary; Vibe's gate sits in front of the tool, not the database.

## Rule 3: Feature completeness

**The problem.** Under context pressure, an agent "finishes" features by deleting functionality, adding `TODO` comments for core logic, or stubbing with `throw new Error("Not implemented")`. Reported incidents: payment validation "fixed" by removing the validation; a feature "completed" with `// TODO: Add actual logic here`.

**The rule. Never ship a half-implemented feature.** If it cannot be finished properly, remove it entirely and file the issue. Acceptance is a passing run, not a review of the diff — see [Verification before completion](#verification-before-completion) and the verification-gap pattern in [TDD](../workflows/tdd.md).

**A — deny rules.** Not applicable, honestly: denylists match paths and command prefixes, not file contents. No `[tools.*]` key expresses "no `TODO` in core logic". Options B and C carry this rule.

**B — a `post_agent` quality gate.** `post_agent` fires once per turn after the agent responds; a deny injects the reason as a user message and the model retries — capped at 3 retries per user turn, so a gate cannot loop forever (PART-HOOKS sections 1, 3.7). The hook runs as a shell command in the session cwd (PART-HOOKS section 3.1), so it can inspect the working tree itself:

```toml
[[hooks]]
name = "no-half-features"
type = "post_agent"
command = "./.vibe/hooks/feature-gate.sh"
```

```sh
#!/bin/sh
# post_agent takes no match/strict (PART-HOOKS section 2)
if git diff -- '*.ts' '*.tsx' '*.py' ':!*test*' | grep -Eq '^\+.*(TODO.*implement|Not implemented)'; then
  echo '{"decision":"deny","reason":"Working diff adds TODO-implement or Not-implemented placeholders. Finish the feature or remove it."}'
fi
exit 0
```

**C — AGENTS.md.**

```markdown
## Feature standards — non-negotiable
1. No TODOs in core functionality (future enhancements excepted).
2. No mock implementations in production code paths.
3. Every async call handled, every input validated, every API call has a timeout.
4. Cannot finish properly? Delete the feature, document why, file the issue.
```

## Rule 4: Infrastructure lock

**The problem.** The model edits infrastructure files without modeling production implications: compose volumes, `.env.example` templates, Terraform, Kubernetes manifests, CI pipelines, schemas. The blast radius is downtime, not a failing test.

**The rule. Infrastructure modifications require explicit team permission.**

**A — deny rules.** The `**/dir/**` directory-glob form is the one the oracle's own example uses (`denylist = ["**/secrets/**"]`, PART-CONFIG section 1.3). Prefix matching makes subcommand-level bash denies expressible: `terraform apply` blocks `terraform apply` and `terraform apply -auto-approve`, and leaves `terraform plan` alone (PART-PERMISSIONS section 4.4). Unlisted, approval-required commands prompt interactively — and are denied headless (live-verified on 2.25.7, T4):

```toml
[tools.edit]
denylist = ["**/Dockerfile", "**/docker-compose*.yml", "**/.env.example",
            "**/terraform/**", "**/kubernetes/**", "**/.github/workflows/**"]
[tools.write_file]
denylist = ["**/Dockerfile", "**/terraform/**", "**/kubernetes/**", "**/.github/workflows/**"]
[tools.bash]
denylist = ["terraform apply", "terraform destroy", "kubectl apply", "kubectl delete",
            "helm upgrade", "helm install"]
```

For runs that should write nothing at all, `permission = "never"` is the blanket version — the built-in `plan` agent disables write tools exactly this way (PART-PERMISSIONS section 4.1).

**B — strict hook.** The canonical guard for anything content-level: deny a bash command pairing an apply/destroy runner with production-looking targets, or extend the Rule 1 guard to protect infra paths from `sed`/`tee` rewrites.

**C — AGENTS.md.**

```markdown
## Infrastructure changes
Do not modify Dockerfiles, compose files, terraform/, kubernetes/, CI workflows,
or the database schema. If an infrastructure change is needed, say so, draft an
RFC under docs/rfcs/, and wait for approval before touching the files.
```

## Rule 5: Dependency safety

**The problem.** Unapproved dependencies add bundle weight, vulnerabilities, license exposure, and maintenance burden. Reported incidents: `moment` added where `date-fns` existed; `lodash` added to a `ramda` codebase; a GPL library pulled into a proprietary product.

**The rule. No new dependencies without explicit approval.**

**A — deny rules.** Prefix equality has a consequence worth stating plainly: `"npm install"` matches the bare command too, so reinstalls of the existing lockfile are blocked alongside new packages. There is no list-based way to say "bare `npm install` allowed, `npm install <pkg>` denied" — `denylist` matches the prefix and `denylist_standalone` is the inverse (denies the bare form only), so neither expresses it (PART-PERMISSIONS section 4.4). Pick one: blanket deny (the team installs manually), or the hook:

```toml
[tools.bash]
denylist = ["npm install", "pnpm add", "yarn add", "pip install", "poetry add", "uv add"]
```

**B — strict hook.** Bare `npm install` passes (no argument after the verb); `npm install lodash` is denied (canonical guard shape, `strict = true`, PART-HOOKS sections 3.3, 3.8):

```python
if re.match(r"(npm|pnpm|yarn) (install|i|add) \S", command):
    print(json.dumps({"decision": "deny",
                      "reason": "New dependency installs need team approval. Propose "
                                "it with alternatives, size impact, and license."}))
    sys.exit(0)
```

**C — AGENTS.md.**

```markdown
## Dependency policy — immutable stack
Do not add dependencies. First check whether an existing one covers the need
(dates: date-fns; HTTP: axios; state: zustand). If one is genuinely required,
name the package, the reason, the alternatives, and the license impact, and
wait for approval. Running the install is a human action.
```

## Rule 6: Pattern following

**The problem.** The model introduces patterns inconsistent with the codebase — class components in a hooks codebase, `fetch` where `axios` is standard — usually because the convention lives in a thousand small examples rather than one obvious rule.

**The rule. Conform to existing codebase conventions. Check before implementing.**

**A — deny rules.** Not applicable: conventions are not paths or command prefixes. The nearest config lever is surface narrowing — `enabled_tools` / `disabled_tools` restrict which tools exist at all (PART-CONFIG section 1.3) — which changes capability, not style.

**B — a `post_tool` advisory.** A `post_tool` hook fires iff the tool body actually ran; on `allow`, its `hook_specific_output.additional_context` is appended to the text the model sees on that same turn — an advisory with real visibility, though not a block (PART-HOOKS sections 1, 3.3). Argument field names are in the [tools reference](../core/tools-reference.md):

```toml
[[hooks]]
name = "pattern-advisory"
type = "post_tool"
match = "re:(write_file|edit)"
command = "python ./.vibe/hooks/pattern-hint.py"
```

```python
# ./.vibe/hooks/pattern-hint.py
import json, sys
payload = json.load(sys.stdin)
try:
    content = open(payload["tool_input"]["file_path"]).read()
except (OSError, KeyError):
    sys.exit(0)
if "extends Component" in content or "fetch(" in content:
    print(json.dumps({"decision": "allow", "hook_specific_output": {"additional_context":
        "Advisory: function components (not classes); axios (not fetch)."}}))
sys.exit(0)
```

**C — AGENTS.md.** The load-bearing option: state the stack once, concretely, and pair it with an explicit analysis instruction — *"Before writing code, grep how this codebase makes HTTP requests and follow that pattern exactly."* (Instruction-following is prompt behavior, not a verified mechanic; the verified part is that project `AGENTS.md` is injected with priority over user instructions, PART-AGENTSMD.)

```markdown
## Conventions — do not deviate
- React function components + hooks; state via zustand; HTTP via axios.
- Tests: Vitest (not Jest); E2E: Playwright (not Cypress).
- Group by feature under src/features/, not by type.
- Before creating a component, grep src/shared/components for an existing
  one; reuse it or ask.
```

## Verification before completion

The discipline survives the port unchanged because it is about teams and attention, not any CLI: **as agent reliability rises, human review quality falls.** Rare errors slip past reviewers who have stopped expecting them; "it worked the last 50 times" is exactly the blind spot the 51st failure needs. Reported incidents: a payment bypass discovered at transaction #201 after 200 clean ones; a security check skipped because "the agent always gets auth right". (Observation due to the Alan engineering team, Feb 2026 — a publicly published engineering post-mortem, not a Vibe mechanic. [Source](https://www.linkedin.com/pulse/le-principe-de-la-tour-eiffel-et-ralph-wiggum-maxime-le-bras-psmxe/).)

**The rule: automated verification, not human vigilance.** Never accept "it looks right" — the acceptance criterion is the run.

| Anti-pattern | Better approach |
|---|---|
| Manual review of every agent output | Tests, type checks, lints in CI; selective human review |
| Trust because "it worked last time" | Verification contracts that fail fast |
| Human as the sole error detector | Guardrails that block merge on failure |
| Spot-checking high-frequency output | Comprehensive automated validation every time |
| Lowering the bar under time pressure | The bar is the automation; emergencies raise error rates, not standards |

The Vibe-side counterpart: "done" and "tested" are earned by showing the run — the same evidence discipline this page's banner applies to itself. The agent-side failure mode (declaring success without verifying) is the verification-gap pattern in [TDD](../workflows/tdd.md); the CI recipes below make the machine read the results.

## Headless runs and CI safety [stable]

`vibe -p [TEXT]` runs headless: send prompt, output response, exit (PART-CLI). Its default posture is the single most important fact for pipelines: **approval-required tool calls are auto-DENIED, not auto-approved.** The session never prompts; every callback the runtime would raise is denied, and `ask_user_question` / `exit_plan_mode` are force-disabled (PART-TRUST section 3.4; PART-CLI). Live on 2.25.7: an unlisted, approval-required command failed with `tool_denied` and never ran (T4); the built-in `.env` protection denied a headless read of a canary file (T7). `--auto-approve` / `--yolo` is the deliberate opt-out that approves everything — a scoped, reviewable exception, never a default. (A run asked to commit needs it or an allowlist entry: `git commit` is not allowlisted, so headless it is denied — T8 note.)

The verified CI recipe — hard bounds, machine-readable output, non-interactive trust:

```bash
vibe --trust -p "Run the migration checklist against the staging branch" \
  --max-turns 20 --max-price 5.00 --max-tokens 500000 --output json
```

| Flag | What it bounds | Notes |
|---|---|---|
| `--max-turns N` | Assistant turns | `-p` only; session interrupted when exceeded (PART-CLI) |
| `--max-price DOLLARS` | Session cost | Same — a runaway loop stops itself |
| `--max-tokens N` | Total prompt + completion tokens | Same |
| `--output json` | All messages at end, machine-readable | `streaming` emits newline-delimited JSON per message (PART-CLI) |
| `--trust` | Trusts the working directory for this invocation only | Never persisted to `trusted_folders.toml` (PART-TRUST section 3.3) |
| `--enabled-tools TOOL` | Disables every non-matching tool | Exact names, globs, or `re:` regex (PART-CLI) |

Budgets apply **only** in `-p` mode (PART-CLI) — an unattended interactive session has no verified cap; see [Known gaps](#known-gaps). `--agent` and `default_agent` both apply headlessly, so pin the posture explicitly. Without `--trust`, an untrusted cwd prints the warning and the project `.vibe/` rules contribute nothing — the run proceeds with defaults only (PART-TRUST section 3.4; live-verified on 2.25.7, T6).

## Distributing the rules across a team

Commit `.vibe/config.toml`, `.vibe/hooks.toml`, and `AGENTS.md` to the repository. Project config, hooks, and repo `AGENTS.md` load **only when the folder is trusted**; untrusted roots contribute nothing, while user-level `~/.vibe` always loads (PART-TRUST section 3.5; PART-AGENTSMD). Live on 2.25.7: in an untrusted cwd the project allowlist was ignored and the approval-required command was denied, with the warning naming the fix (T6). Each teammate's first run in a fresh clone gets the trust prompt (offered when the cwd is undecided and has trustable files such as an `AGENTS.md` or a `.vibe/` dir; decisions are trust-repo, trust-cwd, session-only, or decline — PART-TRUST section 3.2).

Team rules beat personal ones where they collide: project hooks load first and a duplicate hook `name` loses to the project entry (PART-HOOKS section 1); project `AGENTS.md` takes priority over `~/.vibe/AGENTS.md` (PART-AGENTSMD). Personal `~/.vibe/config.toml` can still be *stricter* — layers merge, and deny rules are checked before allowlists. Keep personal overrides out of the repo (gitignore them); the durable policy is what is checked in.

## Quick reference

| Rule | Severity | Breaking it causes |
|---|---|---|
| 1. Port stability | Critical | Team downtime, deployment failures |
| 2. Database safety | Critical | Data loss, customer impact |
| 3. Feature completeness | High | Production bugs, tech debt |
| 4. Infrastructure lock | High | Downtime, security exposure |
| 5. Dependency safety | Medium | Bundle bloat, license and vulnerability exposure |
| 6. Pattern following | Low | Code inconsistency, maintenance burden |

| Method | Enforced by | Best for |
|---|---|---|
| `[tools.*]` denylist / `permission = "never"` | Harness — deterministic, checked first | Path- and prefix-shaped rules (1, 4, 5) |
| `pre_tool` hook, `strict = true` | Harness + your script | Content-level rules lists cannot express (2, 4, 5) |
| `post_agent` deny gate | Harness + your script, 3 retries per turn | Turn-level quality gates (3) |
| `post_tool` advisory | Appended to what the model sees, same turn | Convention hints (6) |
| `AGENTS.md` | The model — no harness enforcement | Policy, protocols, conventions (every Option C) |
| Git hooks / CI gates | Ordinary engineering outside Vibe's gate | The last net before merge |

## Known gaps

- **`AGENTS.md` compliance is unmeasured.** The oracle verifies injection and priority semantics, not how reliably any model follows the instructions. The source guide's "~70% respected" figure is not portable to Vibe — there is no data. Treat Option C as policy; pair critical rules with A or B.
- **Write-side bash bypass is inferred, not separately tested.** The read-side bypass (`read_file` denylist defeated via `cat`) is live-verified on 2.25.7 (T5); that `sed`/`tee`/redirection bypass file-tool denylists the same way follows from the per-tool resolution order (PART-PERMISSIONS sections 4.3-4.4) but was not exercised as its own live check.
- **No OS sandbox.** Deny rules and hooks gate *tool calls*; there is no container or syscall filter ([Architecture](../core/architecture.md), section 5). Hooks are also code you ship: a `pre_tool` guard runs arbitrary shell in the project cwd (PART-HOOKS section 3.1) — which is why hook files, like config, load only from trusted roots (PART-TRUST section 3.5).
- **No verified stall detection.** Budget flags bound `-p` runs only (PART-CLI). Whether an unattended interactive session can hang silently, and any heartbeat pattern for it, is outside the verified surface.
- **`smart-approve` (2.25.8, [unified-harness])** — a classifier agent between `accept-edits` and `auto-approve`; its exact behavior needs public verification (PART-DELTAS). Do not build CI policy on it.
- **Prefix matching is the config ceiling.** Bash denylists cannot match command *content* and file denylists cannot match file *content* (PART-PERMISSIONS sections 4.3-4.4). Every content-level rule here routes through a hook for that reason; if a hook cannot express it either, it is an `AGENTS.md` rule or nothing.

## See also

- [Architecture and internals](../core/architecture.md) — the permission chain, trust model, and programmatic mode these rules build on (sections 5-6)
- [Tools reference](../core/tools-reference.md) — per-tool `[tools.*]` keys and argument field names
- [Settings reference](../core/settings-reference.md) — the full `config.toml` key surface and trusted-folder gating
- [Hooks and events reference](../core/hooks-events-reference.md) — hook schema, payloads, and the fail-open vs `strict` contract
- [Production reliability](../workflows/production-reliability.md) — escalation, circuit breakers, and structured handoff for agents operating production systems
- [TDD](../workflows/tdd.md) — the verification-gap pattern behind the completion discipline
- The mechanics oracle: [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md); live security transcripts: [`live-checks.md`](../../docs/mechanics/live-checks.md)
