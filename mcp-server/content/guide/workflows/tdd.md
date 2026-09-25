---
title: "Test-Driven Development with Vibe"
description: "Red-green-refactor with explicit prompting: how to run TDD cycles with an agentic CLI that defaults to implementation-first"
tags: [workflow, tdd, testing]
---

# Test-Driven Development with Vibe

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

## TL;DR

```text
Red → Green → Refactor

But you MUST prompt the agent explicitly:
"Write a FAILING test for [feature]. Do NOT write implementation yet."
```

Left to its defaults, an agent writes implementation first and tests second. TDD requires the inverse order, so the cycle only happens if you prompt for it, gate it, or encode it in `AGENTS.md`. Everything on this page runs on the stable backend **[stable]** unless tagged otherwise.

*Read if you want the agent to drive red-green-refactor cycles instead of writing code-then-tests. Skip if you already have a TDD prompt discipline and only need the harness mechanics — jump to [Integration with Vibe features](#integration-with-vibe-features).*

---

## The Problem

Without explicit instruction, the agent will:

1. Write implementation code
2. Then write tests that pass against that implementation

This defeats TDD's purpose: tests should drive design, not validate existing code. The fix is prompt-driven methodology — the cycle itself is tool-agnostic; what Vibe adds is enforcement surface (`AGENTS.md` rules, hooks, the read-only `plan` agent, headless verification runs).

---

## Setup

### AGENTS.md configuration

Put the TDD rules in your project's `AGENTS.md`. Project files load for every session in a trusted project root, and project instructions take priority over user-level `~/.vibe/AGENTS.md` instructions, with closer directories overriding more distant ones (PART-AGENTSMD).

```markdown
## Testing Conventions

### TDD Workflow
- Always write failing tests BEFORE implementation
- Use AAA pattern: Arrange-Act-Assert
- One assertion per test when possible
- Test names describe behavior: "should_return_empty_when_no_items"

### Test-First Rules
- When I ask for a feature, write tests first
- Tests should FAIL initially (no implementation exists)
- Only after tests are written, implement minimal code to pass

### Task Tracking
- Maintain TASKS.md in the repo root
- Before starting a feature, add a RED/GREEN/REFACTOR entry per cycle
- Update the entry as each phase completes; never mark a phase done without its verification command passing
```

The `TASKS.md` rule is a file-based convention, not a built-in feature: Vibe has no persistent todo store in the verified surface, so tracking lives in a plain file the agent reads and updates like any other (PART-AGENTSMD). `AGENTS.md` should stay hand-written and minimal — see [memory systems](../core/memory-systems.md) and the [memory module](../learning-path/03-memory.md).

### Hook for auto-run tests (optional)

A `post_tool` hook can run the test suite after every file edit and hand the result back to the agent. Create `.vibe/hooks/test-on-edit.sh`:

```bash
#!/bin/bash
# Runs after file edits; appends the test tail to the tool result the agent sees.
# stdout MUST be a JSON object (or empty for passthrough) — see PART-HOOKS §3.3.
out=$(npm test --watchAll=false 2>&1 | tail -20)
python3 - "$out" <<'PY'
import json, sys
print(json.dumps({
    "decision": "allow",
    "hook_specific_output": {"additional_context": "test-on-edit hook output:\n" + sys.argv[1]},
}))
PY
```

Then register it in `<project>/.vibe/hooks.toml`:

```toml
[[hooks]]
name = "test-on-edit"
type = "post_tool"
match = "write_file"   # fnmatch glob; add a second hook with match = "edit"
command = "./.vibe/hooks/test-on-edit.sh"
description = "Run the test suite after edits and surface failures to the agent."
```

Wire contract (PART-HOOKS §3.3): the hook receives a JSON payload on stdin (session fields plus `tool_name`, `tool_input`, `tool_status`, `tool_output_text`), and its stdout decides the effect. Exit 0 with empty stdout is passthrough; exit 0 with a JSON object is a structured response. For `post_tool`, `hook_specific_output.additional_context` is appended to the tool output the model sees — that is the channel for "tests now fail: 3 errors". `post_tool` fires if and only if the tool body actually ran (status success/failure/cancelled); it does not fire on a `pre_tool` denial, a user denial at the approval prompt, or a permission `never` skip (PART-HOOKS §1). Failures fail open by default — a crashed hook lets the edit through with a warning; set `strict = true` to escalate a hook failure to clearing the tool output (PART-HOOKS §3.3). Project `hooks.toml` files load only in trusted roots; the user file is `~/.vibe/hooks.toml` (PART-HOOKS §1). Full hook reference: [hooks-events-reference.md](../core/hooks-events-reference.md).

---

## The Red-Green-Refactor Cycle

### Phase 1: Red (write a failing test)

Prompt:

> *Write a failing test for [feature description]. Do NOT write the implementation yet. The test should fail because the function doesn't exist.*

Example:

> *Write a failing test for a function that calculates the total price of items in a cart, applying a 10% discount if the total exceeds $100. Do NOT implement the function yet.*

Expected agent behavior:

- Creates the test file with test cases
- Tests reference a function that doesn't exist
- Running the suite fails with "function not defined" or the language's equivalent

Verify yourself, or make the agent show you the run:

```bash
npm test  # Should fail with "calculateCartTotal is not defined"
```

### Phase 2: Green (minimal implementation)

Prompt:

> *Now implement the minimum code to make these tests pass. Only write enough code to pass the current tests, nothing more.*

Expected agent behavior:

- Creates the implementation
- Writes the minimal code that satisfies the tests
- Avoids speculative generality

Verification:

```bash
npm test  # Should pass
```

### Phase 3: Refactor (clean up)

Prompt:

> *Refactor the implementation to improve code quality. Tests must stay green after refactoring. Focus on: [readability / performance / removing duplication].*

Expected agent behavior:

- Improves code without changing behavior
- Re-runs the tests after each change to confirm they stay green
- Reports what changed and why

---

## Integration with Vibe features

### Task tracking: a file, not a store

There is no persistent todo store in the verified surface, so track TDD phases in `TASKS.md` (or a test-list file) and let an `AGENTS.md` rule drive it (PART-AGENTSMD):

```text
User: "Implement user authentication with TDD"

Agent opens: I'll track this in TASKS.md per the project rules.
TASKS.md after the first cycle:
- [x] RED: failing tests for login
- [x] GREEN: implement login to pass tests
- [ ] REFACTOR: clean up login implementation
- [ ] RED: failing tests for logout
- [ ] GREEN: implement logout
- [ ] REFACTOR: clean up
```

The agent updates the file with ordinary `edit`/`write_file` calls; the next session picks the state up by reading it. This survives sessions precisely because it is a checked-in file, not harness state.

### Planning with the plan agent

Use the read-only `plan` agent to design the test strategy before any code exists (PART-AGENTS §7):

```bash
vibe --agent plan
```

Then:

> *I need to implement a shopping cart with TDD. Plan the test cases before we write any code.*

The `plan` agent is hard read-only, not prompt-read-only: `write_file` and `edit` are set to permission `never`, with an allowlist limited to `$VIBE_HOME/plans/*` (PART-PERMISSIONS §4.1). It explores the codebase and proposes a test plan; it cannot slip into implementation even if the prompt is sloppy. Shift+Tab cycles `ask → plan → accept-edits → auto-approve` interactively; `default_agent` (default `accept-edits`) governs when nothing is passed (PART-AGENTS §7, §10).

### Hooks: enforce the cycle mechanically

The `post_tool` hook above is the green-phase guard. The mirror-image `pre_tool` hook guards the red phase: match `write_file`, inspect `tool_input`, and deny with a reason when the file being written is an implementation file while the tracked tests are still red. A `pre_tool` deny short-circuits the call — the tool never executes and the agent receives the reason as a `tool_error` (PART-HOOKS §3.3). Guard-script shape:

```python
import json, sys
payload = json.load(sys.stdin)
path = payload.get("tool_input", {}).get("path", "")
if "src/" in path and open("TASKS.md").read().count("[ ] RED"):
    print(json.dumps({
        "decision": "deny",
        "reason": "RED phase incomplete: write the failing test first (see AGENTS.md).",
    }))
    sys.exit(0)
# Passthrough: empty stdout, exit 0.
```

### Subagents: separate the test writer from the implementer

Delegate test writing to a scoped subagent through the `task` tool (PART-AGENTS §9):

> *Use the task tool with a test-writer subagent to create comprehensive tests for the UserService class, covering all edge cases. Then I'll implement to pass those tests.*

Verified mechanics to design around: `task` takes `{task, agent}` and can only spawn profiles with `agent_type = "subagent"`; subagents cannot spawn further subagents (depth limit 1); the parent receives a text-only result (`response`, `turns_used`, `completed`) and must summarize it — no files, no message objects cross the boundary (PART-AGENTS §9). The built-in `explore` subagent is read-only (`grep`, `read_file`, `skill` only) and auto-approved; custom subagents come from `~/.vibe/agents/NAME.toml` or `.vibe/agents/NAME.toml` with `agent_type = "subagent"`, and spawning anything beyond the allowlist prompts for approval (PART-AGENTS §8-9; PART-PERMISSIONS §4.2).

### Headless verification: the independent evaluator run

The strongest version of the cycle ends with a separate run that only verifies. Programmatic mode (PART-CLI):

```bash
vibe --trust -p "Read PLAN and TASKS.md, run the full test suite, and report exactly which acceptance criteria pass. Do not fix anything." --max-turns 8 --output json
```

Semantics to rely on, not guess at (PART-TRUST §3.3-3.4): `--trust` grants session-only trust (nothing is written to `trusted_folders.toml`); in `-p` mode every approval-requiring tool call is auto-DENIED unless `--auto-approve`/`--yolo` is passed or the agent/permission config allows it — so a verify-only run cannot edit files even if the prompt asks it to. Budget the run with `--max-turns`, `--max-price`, `--max-tokens`, and consume results with `--output json` (message/effect/notice entries at end of run) or `--output streaming` (newline-delimited JSON per message) (PART-CLI). Note that `npm test` is not in the default bash read-only allowlist: interactively it prompts once (approving permanently persists to `[tools.bash].allowlist`), and headlessly it is denied unless allowlisted in `config.toml` or run with `--auto-approve` (PART-PERMISSIONS §4.2, §4.4).

---

## Anti-Patterns

### The verification gap

The verification gap is the failure mode where the agent reports a feature complete before the verification suite confirms it. Three observable symptoms: the agent prints a success message before any test command runs; tests run but failing output is discarded or not read; only unit tests pass when the acceptance criteria specified end-to-end behavior.

The fix is a three-layer verification stack that must all pass before any feature is marked done:

1. **Lint**: syntax and style checks (fastest, catches obvious errors before tests run)
2. **Unit and integration tests**: functional correctness of individual components
3. **End-to-end tests**: the behavioral contract as seen by a user or external caller

Each layer catches a different class of failure. Unit tests can pass while component boundaries break; end-to-end tests surface state propagation and lifecycle issues unit tests cannot see. Skipping any layer leaves a gap.

The independent-evaluator principle: the agent that writes the code must not be the same invocation that certifies it done. This is not model distrust — it is about how context biases evaluation. An agent that just spent an hour building a feature interprets ambiguous output charitably. A `post_tool` hook reading the exit code, or a second `-p` run that only runs the suite, does not. Public harness-design writeups report the same shape: a bare run declared a feature complete with nothing working, while adding an independent evaluator to the same harness produced a functional result over a much longer run.

The WIP=1 rule connects here: only one feature `active` in `TASKS.md` at a time means a verification gap, when it happens, affects one feature, not several.

### What NOT to do

| Anti-Pattern | Why it's wrong | Correct approach |
|---|---|---|
| "Write tests for this feature" | Agent implements first | "Write FAILING tests for behavior that doesn't exist yet" |
| "Add tests and implementation" | Loses test-first benefit | Split into two prompts (red, then green) |
| "Make sure tests pass" | Encourages implementation-first | "Write tests, then implement minimally" |
| Skipping the refactor phase | Accumulates technical debt | Always refactor after green |
| Multiple features per cycle | Loses focus, muddies verification | One feature per red-green-refactor cycle |

### Common mistakes

**Mistake**: asking the agent to "test" existing code.

```text
# Wrong
"Write tests for the existing calculateTotal function"

# Right
"Write tests for calculateTotal behavior, assuming the function doesn't exist.
Then we'll verify the existing implementation passes."
```

**Mistake**: combining red and green phases.

```text
# Wrong
"Implement calculateTotal with tests"

# Right
"Write failing tests for calculateTotal. Stop there."
[after tests are written and shown failing]
"Now implement to pass those tests."
```

---

## Advanced Patterns

### Property-based testing

> *Write property-based tests for the sort function. Properties to test: output length equals input length; all input elements exist in the output; the output is ordered. Use fast-check or a similar library for this stack.*

### Mutation testing

> *The tests pass. Now run mutation testing to find weak spots, and identify tests that don't catch mutations.*

### TDD with legacy code

> *I need to refactor legacyFunction. First, write characterization tests that capture current behavior, including the bugs. Then we'll refactor with confidence.*

---

## Example Session

### Request

> *Implement a URL shortener service with TDD.*

### Phase 1: Red

> *Let's use TDD. First, write failing tests for: (1) shortening a URL returns a short code; (2) retrieving a short code returns the original URL; (3) invalid URLs are rejected; (4) expired links return an error. Do NOT implement anything yet.*

Sample agent behavior (open/during/close discipline): the agent states what it will do first ("I'll add four failing tests in `tests/shortener.test.ts` and register the cycle in `TASKS.md`"), works, then closes with the evidence — the test file path, the exact failing command it ran, and the failure output — instead of asserting the tests fail.

### Phase 2: Green

> *Tests are written and failing. Now implement the minimum code to make them pass. Use an in-memory store for now.*

The agent implements, re-runs the suite, and reports the passing run verbatim (command and output) before asking about the refactor phase.

### Phase 3: Refactor

> *Tests pass. Now refactor: extract URL validation into a separate function, add proper error types, improve variable names. Run the tests after each change and show me they stay green.*

The agent makes one change at a time, shows the green run after each, and closes with a summary of what was cleaned up and what it deliberately left alone.

---

## Known gaps

- No persistent todo store exists in the verified surface; TDD phase tracking is a file convention (`TASKS.md` + `AGENTS.md` rule), not harness state (PART-AGENTSMD). A `/todo` command exists only as a release-2.25.8 delta gated on the experimental unified harness **[unified-harness]** — do not rely on it on the stable surface (PART-COMMANDS; PART-DELTAS).
- The `post_tool` hook cannot distinguish "edit that should trigger tests" from "edit to the test file itself" beyond what your `match` glob and guard script encode; `match` is fnmatch on the tool name only (`write_file`, `edit`), and payload filtering happens inside your script (PART-HOOKS §3.3-3.4).
- The `plan` agent can only persist files under `$VIBE_HOME/plans/*`; a test plan destined for the repo must be moved there by a writable agent or by you (PART-AGENTS §7).
- Subagent results are text-only: a test-writer subagent returns a summary, not the test files — have it write files itself and report paths (PART-AGENTS §9).

## See also

- [methodologies.md](../core/methodologies.md): TDD among the 15 structured methodologies, with Vibe fit assessments
- [hooks-events-reference.md](../core/hooks-events-reference.md): the full `hooks.toml` wire protocol
- [agents-and-skills-reference.md](../core/agents-and-skills-reference.md): agent profiles, subagent TOML, `task` tool
- [tools-reference.md](../core/tools-reference.md): tool permission resolution used by the step gates
- [agent-harness.md](../core/agent-harness.md): the harness layer this workflow runs inside
- [rpi.md](rpi.md): research-plan-implement gates that pair well with a test-gated implement phase
- [spec-first.md](spec-first.md): writing the spec before the cycle starts
