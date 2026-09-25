---
name: ci-all
description: Full pre-PR pipeline in one pass - run local tests, run the type check, push the current branch, and return the pipeline tracking URL (GitLab CI or GitHub Actions). Use when the user asks to run everything before opening a PR, or says "ci" or "full check". Skip the tests only when the extra instructions say so.
---

# Full CI before PR

Runs everything in order: local tests, type check, push, pipeline URL.

One `/ci-all` replaces: manual tests, git push, and copying the pipeline
URL. All steps run in this session with ordinary bash.

## Extra instructions

Text after `/ci-all` is the user's extra instructions. Recognized flags:

- `--skip-tests`: skip step 1 (doc-only change, tests already run).
- `--e2e`: also run the E2E suite if the project has one configured.

Anything else is a note to pass through to the relevant step.

## Stack detection

| Stack | Detection | Test command | Type check |
|---|---|---|---|
| Python + uv | `uv.lock` | `uv run pytest --tb=short -q` | mypy (optional) |
| Node + pnpm | `pnpm-lock.yaml` | `pnpm vitest run` | `pnpm tsc --noEmit` |
| Node + npm | `package-lock.json` | `npm test` | `npx tsc --noEmit` |
| Rust | `Cargo.toml` | `cargo test --quiet` | `cargo clippy` |

## Step 1: local tests (blocking)

Run the test command for the detected stack. On failure: stop, print the
failing tests with assertion output, and do not push. The pipeline must
not be triggered by a branch that already fails locally.

If `--skip-tests` is passed, go straight to step 2 and say so.

## Step 2: type check

Run the type check for the stack (`mypy`, `tsc --noEmit`, or
`cargo clippy`). On failure: stop and print the errors. Do not push.

## Step 3: push

```bash
BRANCH=$(git branch --show-current)

# Only push if there are commits the remote does not have
AHEAD=$(git rev-list --count "origin/$BRANCH"..HEAD 2>/dev/null || echo 1)
if [ "$AHEAD" = "0" ]; then
  echo "Branch already up to date on origin."
else
  git push origin "$BRANCH"
fi
```

Pushing is a shared-state action: state the branch and what is being
pushed before running it. Never force-push.

## Step 4: pipeline URL

Derive the web URL from the origin remote:

```bash
REMOTE=$(git remote get-url origin)
WEB_URL=$(echo "$REMOTE" | sed 's/git@gitlab\.com:/https:\/\/gitlab.com\//' \
                        | sed 's/git@github\.com:/https:\/\/github.com\//' \
                        | sed 's/\.git$//')
```

GitLab CI:

```bash
echo "Pipeline: $WEB_URL/-/pipelines?ref=$BRANCH"
# Live status, if the glab CLI is installed
command -v glab >/dev/null && sleep 3 && glab ci status --branch "$BRANCH" || true
```

GitHub Actions:

```bash
echo "Actions: $WEB_URL/actions?query=branch%3A$BRANCH"
# Live status, if the gh CLI is installed
command -v gh >/dev/null && sleep 5 && gh run list --branch "$BRANCH" --limit 3 || true
```

If neither CLI is installed, the URL is the deliverable - say that live
status is unavailable rather than pretending to check it.

## Expected output

```text
CI: my-app (Node/vitest)
------------------------
1. Local tests:   PASS - 47 passed in 8.2s
2. Type check:    PASS - no errors
3. Push:          OK - origin/feat/my-feature
4. Pipeline:      https://gitlab.com/org/my-app/-/pipelines?ref=feat/my-feature

Next step: open a PR.
```

If tests fail:

```text
CI: my-api (Python/pytest)
--------------------------
1. Local tests:   FAIL - 2 failed

FAILED tests/test_orders.py::TestOrderService::test_refund_validation
AssertionError: expected 400, got 500

-> Fix tests before pushing. Pipeline not triggered.
```

Never claim a step passed without showing its real output.
