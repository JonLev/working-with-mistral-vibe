---
name: ci-status
description: Show the current CI pipeline status for the active branch on GitLab CI or GitHub Actions - recent commits, pipeline state, and a tracking URL, using glab or gh when installed with a URL fallback. Use when the user asks for pipeline or CI status. Not for pushing (ci-pipeline) or running tests (ci-tests).
---

# Pipeline status

Quick snapshot of the CI pipeline on the current branch.

## Extra instructions

Text after `/ci-status` is the user's extra instructions: an optional MR
or PR number. With a number, also show that merge request or pull
request's status.

## Process

```bash
BRANCH=$(git branch --show-current)
echo "Branch: $BRANCH"

git log -3 --oneline
```

## GitLab CI

```bash
if command -v glab >/dev/null; then
  glab ci status --branch "$BRANCH"
else
  REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
  if [ -n "$REMOTE" ]; then
    WEB_URL=$(echo "$REMOTE" | sed 's/git@gitlab\.com:/https:\/\/gitlab.com\//' \
                                | sed 's/\.git$//')
    echo "Pipeline: $WEB_URL/-/pipelines?ref=$BRANCH"
  fi
fi

# MR number from extra instructions
if [ -n "$MR_NUMBER" ] && command -v glab >/dev/null; then
  glab mr view "$MR_NUMBER"
fi
```

## GitHub Actions

```bash
if command -v gh >/dev/null; then
  gh run list --branch "$BRANCH" --limit 5
else
  REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
  if [ -n "$REMOTE" ]; then
    WEB_URL=$(echo "$REMOTE" | sed 's/git@github\.com:/https:\/\/github.com\//' \
                                | sed 's/\.git$//')
    echo "Actions: $WEB_URL/actions?query=branch%3A$BRANCH"
  fi
fi

# PR number from extra instructions
if [ -n "$PR_NUMBER" ] && command -v gh >/dev/null; then
  gh pr checks "$PR_NUMBER"
fi
```

Detect the platform from the origin remote URL (gitlab.com vs
github.com) and run only the matching block. If neither CLI is
installed, the URL fallback is the deliverable - say that live status is
unavailable.

## Expected output

```text
Branch: feat/add-payment-retry

Last commits:
  a1b2c3d feat(payments): add retry logic with exponential backoff
  e4f5g6h test(payments): add coverage on retry scenarios
  i7j8k9l chore: update lockfile

Pipeline: running
  lint          30s   passed
  typecheck     45s   passed
  test          ...   running
  deploy              waiting

URL: https://gitlab.com/org/my-app/-/pipelines?ref=feat/add-payment-retry
```

Report what the CLI actually returned; do not invent job states.
