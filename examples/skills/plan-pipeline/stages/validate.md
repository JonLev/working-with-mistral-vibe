# Stage 4: Validate - 2-layer validation

Independently validate the plan produced by the start stage. No code is
written. Run `/clear` after this stage before running execute.

Validation is separate from planning by design: a validator that did not
write the plan is not anchored to its assumptions.

## Prerequisite

A committed plan file must exist at `docs/plans/plan-{name}.md`. If
multiple plans exist, list them and ask the user which to validate.

## Layer 1: structural validation

Run immediately. Check the plan document for:

### Format and completeness

- [ ] All required sections present (Summary, Decisions, Architecture,
  Tasks, Test Plan, Out of Scope)
- [ ] Each task has: description, files affected, acceptance criteria,
  layer assignment

### Dependency chain

- [ ] No circular dependencies between tasks
- [ ] Tasks in higher layers only depend on tasks in lower layers
- [ ] All stated dependencies exist in the plan

### File existence

- [ ] Every file listed for modification actually exists in the codebase
- [ ] New files are in appropriate directories per project conventions

### ADR consistency

- [ ] Plan decisions align with ADRs created during the start stage
- [ ] No contradiction with existing ADRs in `docs/adr/`

### AGENTS.md compliance

- [ ] Plan respects every AGENTS.md file on the path from the plan's
  files up to the repository root (project files win over the user-level
  `~/.vibe/AGENTS.md`; closer directories win over more distant ones)
- [ ] No first-principles violations (no workarounds, no
  backward-compat shims)

### Test coverage

- [ ] Every new function/component has a corresponding test task
- [ ] TDD-marked tasks have the failing test written before the
  implementation task

Record all Layer 1 issues with severity (BLOCKER / WARNING / INFO) before
proceeding to Layer 2.

## Layer 2: specialist review

Select review angles by applying trigger rules to the plan content. No
user input is needed; triggers are objective.

**Review angle pool:**

| Angle | Trigger |
|---|---|
| Security | Auth, payments, PII, RBAC, new public APIs |
| DB migration | New tables, columns, indexes, or migration files |
| Performance | New queries, resolvers, routes, or added dependencies |
| Design system | New UI components or visual styling changes |
| UX | New pages, forms, modals, or interaction patterns |
| Cross-platform | Changes touching both web and mobile, or shared packages |
| Integration | New external services, libraries, or telemetry config |

Run each triggered review against the plan and relevant ADRs, in a fresh
context where practical. Two mechanisms, in order of preference:

1. **Inline, per angle, re-deriving from the plan file.** Re-read the
   plan section by section and ask, per angle, "what does this plan get
   wrong in my domain?" Record findings with the angle as the reporting
   source.
2. **Independent programmatic runs.** One bounded run per angle, each
   given the plan file and targeted questions:

   ```bash
   vibe --trust -p "Read docs/plans/plan-<name>.md and review it as a
   security specialist: list concrete findings with severity, location,
   risk, and a suggested fix. Do not edit anything." \
     --max-turns 8 --output json
   ```

   Budget each run with `--max-turns`, `--max-price`, or `--max-tokens`
   and consume results from the JSON output. Approval-requiring tool
   calls are auto-denied in this mode, so these runs are read-only by
   construction unless you deliberately pass `--auto-approve` or grant
   the agent permissions - a reviewer does not need either.

Each review must return structured findings:

```text
FINDING: [BLOCKER|WARNING|INFO]
Location: [plan section or file reference]
Issue: [concrete description]
Risk: [what breaks if this isn't addressed]
Suggestion: [specific fix or alternative]
```

On CLI releases where the `task` tool can spawn custom subagents
(agent_type = "subagent" profiles), a subagent reviewer is a third
mechanism - fresh context, depth 1, text-only result. On 2.25.7 with the
unified harness this does not yet work for custom subagents; do not build
the stage around it.

## Auto-fix phase

Merge Layer 1 structural issues and Layer 2 specialist findings into a
single issue list. Every issue must be resolved. No skipping.

**Triage each issue:**

### Bucket A: auto-resolve

- Issue matches an existing ADR decision: cite the ADR, mark resolved.
- Issue matches a confirmed pattern in PATTERNS.md: cite the pattern,
  mark resolved.
- Issue resolvable from first principles in the AGENTS.md rules: apply
  the rule, mark resolved.

### Bucket B: needs human input

- Novel architectural question not covered by existing decisions.
- Conflicting ADRs with no clear precedent.
- Blocker with no obvious resolution.

For Bucket B items: present the issue, explain why it cannot be
auto-resolved, propose options, and wait for a decision. Record the
decision in the plan's `## Decisions` section and create a new ADR if it
is architecturally significant.

Apply all fixes in one batch once all issues are triaged. Update the
plan file. Commit the updated plan.

## Issue persistence

Record every issue in `docs/plans/metrics/{name}.json` under
`validation.issues`:

```json
{
  "id": "S-001",
  "layer": 1,
  "severity": "WARNING",
  "category": "test-coverage",
  "description": "No test task for the new webhook handler",
  "reporting_angle": "structural",
  "triage": "A",
  "resolution_source": "first-principles",
  "resolution": "Added test task in Layer 2 of the plan"
}
```

## Auto-transition

If all issues are auto-resolved (Bucket A only): propose starting the
execute stage.

If any human input was required (Bucket B): ask "All issues resolved.
Ready to execute?" before proceeding.

## Example output

```text
Layer 1: structural validation...
  OK format complete
  OK dependencies valid
  WARNING S-001: missing test task for webhook handler
  OK AGENTS.md compliant

Layer 2: specialist review...
  -> security (auth changes detected)
  -> db-migration (new users table)
  -> performance (new query in /api/users)
  security: BLOCKER B-001: JWT expiry not validated on refresh endpoint
  db-migration: WARNING B-002: migration lacks rollback strategy

Auto-fix phase:
  S-001 -> auto-resolved (first principles: test coverage rule)
  B-001 -> NEEDS INPUT (no existing ADR for JWT refresh strategy)
  B-002 -> auto-resolved (ADR-0003: migration rollback pattern)

[User input requested for B-001]
Decision recorded. ADR-0011 created.

All 3 issues resolved. Plan updated.
-> Proposing the execute stage
```

## When to use

Always run before the execute stage. The cost of validation is negligible
against the cost of discovering issues mid-execution.

## Pipeline position

```text
ceo-review    -> product direction locked
eng-review    -> architecture locked
start         -> produce implementation plan
validate      -> validate before execution      <- you are here
execute       -> execute to merged PR
```
