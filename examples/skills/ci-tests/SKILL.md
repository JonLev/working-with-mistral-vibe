---
name: ci-tests
description: Run the test suite for the current repository, auto-detecting the stack - Python (pytest via uv), Node (vitest via pnpm, npm test, or jest), or Rust (cargo test). Use when the user asks to run tests, the test suite, or a specific test file or folder. Not for linting or type checking alone, and not for pushing or checking remote pipelines.
---

# Run tests

Detects the stack and runs tests with the right command, in this session,
with ordinary bash.

## Extra instructions

Text after `/ci-tests` is the user's extra instructions: an optional
target file or folder (for example `tests/test_orders.py` or
`src/components/`). With no target, run the full suite.

## Stack detection

```bash
if [ -f "uv.lock" ]; then
  STACK="python"
elif [ -f "pnpm-lock.yaml" ]; then
  STACK="node-pnpm"
elif [ -f "package-lock.json" ]; then
  STACK="node-npm"
elif [ -f "Cargo.toml" ]; then
  STACK="rust"
else
  STACK="unknown"
fi
```

## Commands by stack

### Python (uv + pytest)

```bash
# All tests
uv run pytest --tb=short -q

# With coverage
uv run pytest --cov=src --cov-report=term-missing -q

# Specific file or folder (from extra instructions)
uv run pytest "$TARGET" -v
```

### Node (pnpm + vitest)

```bash
# All tests
pnpm vitest run

# With coverage
pnpm vitest run --coverage

# Specific file (from extra instructions)
pnpm vitest run "$TARGET"
```

### Node (npm)

```bash
npm test -- --passWithNoTests "$TARGET"
```

### Rust (cargo)

```bash
cargo test --quiet 2>&1
# Specific target: cargo test --quiet "$TARGET"
```

Unknown stack: report which managers you looked for and ask the user for
the test command. Do not guess a runner.

## Approval note

Test commands are not in the default bash read-only allowlist, so the
first run prompts for approval in an interactive session. Approving
permanently persists the command prefix to `[tools.bash].allowlist` in
config, so later runs are silent. In a headless `-p` run the command is
auto-denied unless the agent/permission config allows it - add the test
command to the allowlist in `config.toml` for automation.

## Expected output

```text
Tests: my-api (Python/pytest)
--------------------------------
uv run pytest --tb=short -q
[pytest output]
PASS: 42 passed in 3.1s -> ready to push
```

On failure, show the failing tests with their assertion output and stop:

```text
FAIL: 2 failed

FAILED tests/test_billing.py::TestInvoice::test_promo_expired
AssertionError: expected discount=0, got discount=10

-> Fix before pushing.
```

Never report a pass without showing the real tail of the test output.
