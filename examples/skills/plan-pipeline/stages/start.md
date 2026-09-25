# Stage 3: Start - 5-phase planning

Analyze the request and produce a complete implementation plan through
structured phases. No code is written. Every significant decision is
recorded. Run `/clear` after this stage before running validate.

## Phase 1: PRD and design analysis

### Step 1.1: PRD analysis

Skip if no PRD exists (refactor, infra change, bug fix).

Read all PRD files and `docs/INFORMATION_ARCHITECTURE.md` if present. Scan
the codebase to understand current implementation status.

Surface findings in three buckets:

- **Missing requirements**: acceptance criteria that are absent or
  incomplete.
- **Ambiguous requirements**: items with multiple valid interpretations.
- **Compliance concerns**: security, data privacy, API contract
  implications.

For each finding: present options with concrete pros and cons, discuss
with the user, and record every decision in the plan file under a
`## Decisions` section before moving on. Do not proceed past unresolved
ambiguities.

### Step 1.2: Design analysis

Skip if no UI changes are in scope.

Read: `DESIGN_SYSTEM.md`, existing UX ADRs, UX rules from the AGENTS.md
files on the path to the changed files.

Produce specs for:

- **Screen inventory**: new/modified screens, route placement, component
  reuse audit.
- **State catalog**: empty, loading, populated, error, and partial states
  for every interactive element.
- **Interaction specs**: user flows (happy path plus alternates),
  focus/keyboard behavior.
- **Animation specs**: map each interaction to existing keyframes or
  specify new ones; include `prefers-reduced-motion` fallbacks.
- **Responsive behavior**: breakpoints, web/mobile divergence decisions.
- **Accessibility**: WAI-ARIA pattern selection, live regions, error
  visibility.

Create design ADRs for significant UX decisions (choice of interaction
pattern, new animation convention, platform divergence). Record minor
layout choices directly in the plan file.

## Phase 2: Technical analysis

Research the codebase inline, in this session: read the modules the
feature touches, then check the decision record.

- Existing ADRs in `docs/adr/`: if three or more ADRs confirm a decision,
  auto-resolve without asking.
- `PATTERNS.md`: apply confirmed patterns directly.

When research returns open questions: present architecture decisions with
two or three options each, concrete pros and cons, and a recommendation.
Ask for user input on each unresolved decision.

For each significant decision:

1. Create `docs/adr/ADR-XXXX.md` using standard Nygard format (Context /
   Decision / Status / Consequences).
2. Update `docs/adr/PATTERNS.md` with the new observation.

## Phase 3: Scope assessment

Apply the trigger rules below to determine which research angles are
needed. Present the proposed research list with a justification for each
inclusion and wait for approval before Phase 4.

**Research angle pool:**

| Angle | Trigger |
|---|---|
| Code exploration | Always |
| Architecture | Changes touch two or more architectural layers |
| Database | Any DB schema change |
| Security | Auth, payments, PII, RBAC, rate limiting |
| Test landscape | Non-trivial feature (not just a bug fix) |
| Cross-platform | Web and mobile parity required |
| Design system | UI changes in scope |
| Dependencies | New packages being added |
| DevOps | Docker, env vars, CI/CD changes |
| Integrations | New services, libraries, telemetry config |

## Phase 4: Research and plan creation

Answer each approved research angle by reading the codebase and any
referenced documentation. Record findings as evidence in the plan file,
with file paths and line references, not as assertions.

**Plan file structure** (`docs/plans/plan-{name}.md`):

```markdown
# Plan: {feature-name}
Created: {date} | Branch: {branch-name}

## Summary
One paragraph: what this implements and why.

## Decisions
Decisions recorded during Phase 1 (PRD analysis).

## Architecture
ADRs created, patterns applied, architectural choices made.

## Tasks
Ordered task list with layers (1 = foundation, 2 = depends on 1, etc.)

### Layer 1
- [ ] Task A: description, files affected, acceptance criteria
- [ ] Task B: description, files affected, acceptance criteria

### Layer 2
- [ ] Task C (depends on A): description, files affected, acceptance criteria

## Test Plan
How each task will be verified. TDD tasks marked explicitly.

## Integration Verification
Smoke test commands to run post-execution (if backend/services in scope).

## Out of Scope
What this plan explicitly does not address.
```

Commit: plan file plus ADR files.

## Phase 5: Finalize metrics

Record timestamps, phase durations, and research-angle counts in
`docs/plans/metrics/{name}.json`. Commit.

## Auto-transition

If Phase 1 produced no unresolved ambiguities and Phase 2 produced no
unresolved decisions: propose starting the validate stage without asking.

If any human discussion occurred: ask "Ready to validate this plan?"
before proceeding.

## When to use

Use for any non-trivial feature: anything touching more than two files,
involving architecture decisions, or where a planning mistake would be
expensive to undo. For simple changes (typos, trivial refactors), plan
inline instead.

## Pipeline position

```text
ceo-review    -> product direction locked
eng-review    -> architecture locked
start         -> produce implementation plan   <- you are here
validate      -> validate before execution
execute       -> execute to merged PR
```
