---
title: "Spec-First Development"
description: "Define the spec in AGENTS.md (or a spec file it references) before implementation, and verify against it"
tags: [workflow, architecture, config]
---

# Spec-First Development

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

## TL;DR

```text
1. Write the spec into AGENTS.md (or a spec file it references)
2. The agent loads AGENTS.md automatically at session start
3. Implementation follows the spec
4. Verify the result against the spec — in a separate run
```

`AGENTS.md` is your spec's home. Treat it as a contract: one well-structured iteration equals eight unstructured ones. Everything on this page runs on the stable backend **[stable]** unless tagged otherwise.

*Read if you want requirements, boundaries, and acceptance criteria fixed before the agent writes code. Skip if the change is a typo fix — write the two-line prompt instead.*

---

## The Pattern

Spec-first development inverts the typical agentic-coding flow:

```text
Traditional:        Spec-first:
───────────        ──────────
Prompt → Code       Spec → Prompt → Code → Verify
  │                   │               │       │
  └─ Hope it's       └── Contract    └── Follows spec
     what you want        defined          └── Check against spec
```

The spec becomes the source of truth that constrains what the agent builds, documents decisions for the team, and makes completeness verifiable.

For larger initiatives, split the chain into three documents, each gated by a human before the next is written:

```text
intent.md → spec.md → plan.md
   │            │          │
 PM gate    Tech gate   Approval before
(the "why")  (the "what")  code (the "how")
```

`intent.md` states the problem in plain language before any technical framing exists. `spec.md` is the technical spec this page covers. `plan.md` is the file-by-file implementation plan approved before code. On Vibe the natural port: `intent.md` and `spec.md` live as repo files referenced from `AGENTS.md`, and `plan.md` can be drafted by the read-only `plan` agent, which can persist files only under `~/.vibe/plans/*` (PART-AGENTS §7). The gates are human review, not tooling — the harness loads documents; you approve them.

---

## Task granularity: sizing work for agents

Before writing the spec, verify the task is the right size. Agents work best with **vertical slices**: thin, end-to-end units that implement exactly one complete user behavior ("password reset via email", not "authentication system").

**Rule of thumb**: one agent session = one vertical slice. If the task description requires "and" between two user behaviors, split it.

### PRD quality checklist

Run this before handing any task to an agent:

| Dimension | Question to ask | Red flag |
|---|---|---|
| **Problem clarity** | Is the problem statement unambiguous? | "Improve performance" |
| **Testable criteria** | Can completion be verified automatically? | "Works well" |
| **Scope boundaries** | What is explicitly OUT of scope? | Nothing listed as excluded |
| **Observable done** | What does "done" look like to a user? | Internal-only description |
| **Requirements clarity** | No implementation details in the spec? | "Use Redis for caching" |
| **Terminology** | Same terms used throughout? | "user" and "account" mixed |

A task that fails 2+ dimensions needs rework before an agent touches it.

```text
Too big, ambiguous:
"Add user authentication to the app"

One vertical slice:
"Users can log in with email + password.
- POST /auth/login returns JWT on success, 401 on failure
- Invalid credentials show 'Email or password incorrect' (not which is wrong)
- Session expires after 24h
- Out of scope: OAuth, password reset, remember me"
```

### Feature list: machine-readable scope control

A feature list is a JSON file that tracks scope and completion per feature across sessions. Unlike a PRD, which describes intent, it is the agent's operational contract: read at session start, updated at session end, persisted across handoffs.

Each entry: `description` (what to build), `verify` (a shell command that exits 0 on success — this forces the definition of done to be executable), and `status` (one-way state machine `not_started` → `active` → `blocked` → `passing`). When a feature reaches `passing`, an `evidence` field records what proved it. The WIP=1 rule: only one feature `active` at a time.

```json
{
  "features": [
    {
      "id": "feat-001",
      "name": "Document Import",
      "description": "Allow users to import PDF and TXT files from local filesystem",
      "verify": "npm test -- --grep 'document import'",
      "status": "passing",
      "evidence": "npm test: 12 passed, 0 failed (2026-05-01 14:22)"
    },
    {
      "id": "feat-002",
      "name": "Document Chunking",
      "description": "Split imported documents into ~500-character chunks with metadata",
      "verify": "npm test -- --grep 'chunking'",
      "status": "not_started",
      "evidence": "",
      "dependencies": ["feat-001"]
    }
  ]
}
```

Store `feature_list.json` in the project root. The read-at-start / write-at-end behavior is an `AGENTS.md` rule, not harness state — Vibe has no persistent task store in the verified surface, so the file is the state (PART-AGENTSMD):

```markdown
## Feature List Rules
- Read feature_list.json at session start before proposing work
- Pick the first not_started feature whose dependencies are all passing; set it active
- Before ending a session, update status and evidence, and commit the file
- Only one feature may be active at a time
```

Pair it with a `docs/handoffs/` convention (one file per session: what happened, what was tried, what's open) so the next session gets both operational state and narrative context.

---

## Where the spec lives: AGENTS.md

`AGENTS.md` is the instruction file Vibe loads automatically (PART-AGENTSMD). Verified loading rules you are relying on when you make it your spec's home:

- `~/.vibe/AGENTS.md` (user level) always loads.
- Project `AGENTS.md` files load when the project root is trusted — the loader walks up from each open project root to its trust root, inclusive. `--add-dir` roots count as project roots.
- `AGENTS.md` in subdirectories loads lazily, only when a file below it is read — usable as scoped specs.
- Priority: project over user, closer directory over distant, each file applying to its own directory and descendants. `AGENTS.md` content overrides default behavior.

Keep it hand-written and minimal: no auto-generation, no directory trees, no speculative rules. The evidence-backed writing guidance is baked into the [memory module](../learning-path/03-memory.md); the full mechanism is in [memory-systems.md](../core/memory-systems.md).

### Spec templates

For anything beyond a few rules, keep `AGENTS.md` small and put the spec in a file it references (the agent reads it with `read_file` like any project file). Three templates:

**Feature spec** (`docs/specs/<feature>.md`):

```markdown
## Feature: [Name]

### Description
[2-3 sentences explaining the feature purpose]

### Capabilities
- MUST: [Required functionality]
- MUST: [Another requirement]
- SHOULD: [Nice to have]
- MUST NOT: [Explicit exclusions]

### Tech Stack
- Required: [lib1, lib2, lib3]
- Forbidden: [lib4, lib5]

### Acceptance Criteria
- [ ] Criterion 1: [Specific, testable condition]
- [ ] Criterion 2: [Another condition]
- [ ] Criterion 3: [Edge case handling]
```

**Architecture spec**:

```markdown
## Architecture: [Component Name]

### Purpose
[Why this component exists]

### Boundaries
- Owns: [Responsibilities]
- Delegates: [What other components handle]
- Does NOT: [Explicit non-responsibilities]

### Dependencies
- Upstream: [Components that call this]
- Downstream: [Components this calls]

### Constraints
- Performance: [Response time, throughput]
- Security: [Auth requirements, data handling]
```

**API spec**:

````markdown
## API: [Endpoint Name]

### Endpoint
`POST /api/v1/[resource]`

### Request
```json
{
  "field1": "string (required, max 255 chars)",
  "field2": "number (optional, default: 0)"
}
```

### Response
```json
{
  "id": "uuid",
  "created_at": "ISO 8601 timestamp"
}
```

### Error Codes
| Code | Meaning | Response Body |
|---|---|---|
| 400 | Validation failed | `{ "errors": [...] }` |
| 401 | Not authenticated | `{ "message": "..." }` |
| 404 | Resource not found | `{ "message": "..." }` |
````

### Modular spec design

Past roughly 200 lines, a single spec file causes context pollution, merge friction, and slow maintenance. Split by domain: `docs/specs/auth.md`, `docs/specs/api.md`, `docs/specs/billing.md`, each referenced from `AGENTS.md`:

```markdown
## Detailed Specs
- Authentication: docs/specs/auth.md
- API contracts: docs/specs/api.md
- Testing requirements: docs/specs/testing.md
```

`AGENTS.md` has no include syntax — these are plain paths, read on demand. For rules that should apply only inside one subtree, use a subdirectory `AGENTS.md`: it loads lazily exactly when a file below it is read (PART-AGENTSMD). Maintenance rules: keep `AGENTS.md` under ~100 lines, domain files under ~150, review quarterly.

---

## Step-by-Step Workflow

### Step 1: Write the spec

Add the spec to `AGENTS.md` (or a referenced spec file) before any implementation request:

```markdown
## Feature: User Authentication

### Capabilities
- MUST: Email/password login
- MUST: JWT token generation
- MUST: Password hashing with bcrypt
- SHOULD: Remember me functionality
- MUST NOT: Store plain text passwords

### Tech Stack
- Required: bcrypt, jsonwebtoken
- Forbidden: passport.js (too heavy for this use case)

### Acceptance Criteria
- [ ] User can login with valid credentials
- [ ] Invalid credentials return 401
- [ ] Token expires after 24h (or 7d with remember me)
- [ ] Passwords hashed with cost factor 12
```

### Step 2: Reference the spec in the prompt

> *Implement the User Authentication feature as specified in AGENTS.md. Follow the acceptance criteria exactly.*

The agent has the spec in context from session start (PART-AGENTSMD); nothing needs to be pasted.

### Step 3: Verify against the spec

> *Review the implementation against the User Authentication spec. Check off each acceptance criterion that's satisfied, with the command or file that proves it. List any gaps.*

For an unambiguous, hands-off check, run it headless — the verify-only run cannot edit files because approval-requiring calls are auto-denied in `-p` mode (PART-TRUST §3.4):

```bash
vibe --trust -p "Read AGENTS.md and the auth spec, verify the implementation against every acceptance criterion, and list gaps with evidence. Do not modify anything." --max-turns 10 --output json
```

`--trust` is session-only (nothing persisted to `trusted_folders.toml`); `--max-turns`/`--max-price`/`--max-tokens` bound the run; `--output json` returns machine-readable entries (PART-CLI; PART-TRUST §3.3).

### Step 4: Update the spec if requirements change

> *Update the User Authentication spec to add: MUST rate limiting (5 attempts per minute). Then implement the rate limiting.*

Spec changes go through the file, not chat memory — chat context does not survive sessions; `AGENTS.md` does.

---

## Operational boundaries

Define explicitly what the agent should do automatically, ask about, or never touch. Three tiers map directly onto Vibe's permission model:

| Tier | Meaning | Vibe mapping |
|---|---|---|
| **Always** | Execute without asking | `[tools.bash] allowlist` entries in `config.toml`; `permission = "always"` for a tool |
| **Ask first** | Confirm before proceeding | The default: bash `permission = "ask"`; the default agent `accept-edits` auto-approves only file edits and prompts for the rest |
| **Never** | Block | `denylist` / `permission = "never"` in config, or a `pre_tool` hook that denies with a reason |

**Always → allowlist.** Bash command matching is prefix equality (`command == pattern or command.startswith(pattern + " ")`), so allowlist the exact commands you mean (PART-PERMISSIONS §4.4):

```toml
# config.toml
[tools.bash]
allowlist = ["npm test", "npx prettier", "npx tsc"]
```

**Never → hook.** A `pre_tool` hook with `match = "bash"` sees `tool_input.command` on stdin and can deny before execution; the reason reaches the agent as a `tool_error` (PART-HOOKS §3.3):

```python
import json, sys
payload = json.load(sys.stdin)
command = payload.get("tool_input", {}).get("command", "")
if "git push origin main" in command:
    print(json.dumps({
        "decision": "deny",
        "reason": "Direct push to main is blocked by the push-guard hook. Use feature branches.",
    }))
    sys.exit(0)
# Passthrough: empty stdout, exit 0.
```

Boundaries template for `AGENTS.md`:

```markdown
## Boundaries

### Always
- Run tests after code changes
- Format code with Prettier
- Fix linting errors

### Ask First
- Modify database schemas
- Add new dependencies
- Change API contracts

### Never
- Push to the production branch
- Commit secrets or API keys
- Delete data without backup
```

Decision framework per action: can it cause data loss → ask first or never; reversible with git → maybe always; affects other developers → ask first; security risk → never; part of the standard workflow → always. Review quarterly: promote actions that never caused issues, demote the ones that did.

### Command specs

Document executable commands with expected outputs and error handling — the spec covers not just features but how to verify them:

```markdown
## Commands

#### Command: `pnpm test`
**When**: Before every commit, after code changes
**Expected Output**: All tests pass (exit 0); coverage ≥80%
**Error Handling**: If tests fail, fix them — don't skip
**Flags**: `--coverage` (report), `--watch` (dev mode)

#### Command: `pnpm db:migrate`
**When**: After pulling schema changes
**Never**: Run in production manually — CI only
```

---

## SDD vs TDD vs BDD

The distinction that matters is which artifact governs:

| Methodology | Governing artifact | When it runs | Human role | Regen possible? |
|---|---|---|---|---|
| TDD | Test suite | After code exists | Write tests first, then code | No: tests document what was built |
| BDD | Gherkin scenarios | After code exists | Write scenarios, then automate | Partial: scenarios can drive codegen |
| SDD | Spec file | Before code exists | Write spec, approve contract | Yes: code is a derivable output of the spec |

The practical implication of the SDD row: if the spec governs, code is in principle regenerable from it. The corollary is the open problem — keeping spec and code synchronized over time. Mitigations that work today: version the spec in git before any implementation commit, and make every intentional departure an explicit spec update (Step 4 above). No widely-adopted tool solves automated spec-code sync at production scale; Vibe's surface is no exception.

---

## When to Use

### Use spec-first

| Scenario | Why |
|---|---|
| New features | Define before building |
| API design | Contract must be explicit |
| Architecture decisions | Document constraints |
| Team collaboration | Shared understanding |
| Complex requirements | Reduce ambiguity |

### Skip spec-first

| Scenario | Why |
|---|---|
| Quick fixes | Overhead not worth it |
| Exploration | Don't know what you want yet |
| Prototyping | Requirements will change |
| Single-line changes | Obvious intent |

---

## Anti-Patterns

### Vague specs

```markdown
# Wrong
## Feature: User Management
- Handle users

# Right
## Feature: User Management
### Capabilities
- MUST: Create user with email, password, name
- MUST: Update user profile (name, avatar)
- MUST: Soft delete (mark inactive, don't remove data)
- MUST NOT: Allow duplicate emails
```

### Spec after code

```text
# Wrong workflow
1. Ask the agent to implement the feature
2. Write a spec documenting what was built

# Right workflow
1. Write a spec defining what should be built
2. Ask the agent to implement from the spec
```

### Ignoring forbidden

The `Forbidden` and `MUST NOT` lines are load-bearing: they are what stops the agent from "helpfully" adding the heavy dependency or the endpoint you didn't ask for. An exclusion list that's empty is a spec with no edges.

### Treating AGENTS.md as generated documentation

`AGENTS.md` written by the agent ("here's everything I noticed about the repo") is not a spec — it's noise with a contract's name on it. Hand-write it, keep it minimal, and delete rules that stop earning their tokens (see the [memory module](../learning-path/03-memory.md)).

---

## Known gaps

- No spec-sync mechanism: nothing in the verified surface keeps spec and code aligned over time. Spec drift is a git-and-discipline problem (PART-AGENTSMD gives loading, not synchronization).
- No include/import syntax in `AGENTS.md`: referenced spec files are plain paths the agent must choose to read — put the read obligation in an `AGENTS.md` rule (PART-AGENTSMD).
- No built-in spec framework, PRD tooling, or spec slash commands. User-invocable skills (`.vibe/skills/` with `SKILL.md` frontmatter, invoked `/skill-name` with the rest of the line as extra instructions) are the only user-defined slash-command mechanism — a spec-template skill is the closest port (PART-SKILLS §1.1-1.3).
- Project `AGENTS.md`, `.vibe/config.toml`, and spec-adjacent project config load only from trusted roots; in an untrusted directory the session runs with project config ignored and a stderr warning (PART-TRUST §3.5).
- Headless verification runs cannot ask questions: in `-p` mode every approval-requiring or user-input callback is auto-denied, so a verify run fails closed rather than pausing (PART-TRUST §3.4).

## See also

- [memory-systems.md](../core/memory-systems.md): `AGENTS.md` hierarchy and the rest of the memory surface
- [learning-path/03-memory.md](../learning-path/03-memory.md): evidence-backed `AGENTS.md` writing practice
- [settings-reference.md](../core/settings-reference.md): `config.toml` keys used for the boundaries tier
- [hooks-events-reference.md](../core/hooks-events-reference.md): `hooks.toml` and the deny contract used for "never"
- [agents-and-skills-reference.md](../core/agents-and-skills-reference.md): the `plan` agent and skills used to port spec workflows
- [tdd.md](tdd.md): test-first execution once the spec exists
- [rpi.md](rpi.md): gate-based research and planning for features whose feasibility is unknown
- [methodologies.md](../core/methodologies.md): SDD, TDD, BDD among the 15 methodologies
