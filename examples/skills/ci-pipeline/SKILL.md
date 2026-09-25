---
name: ci-pipeline
description: Push the current branch and return the pipeline tracking URL for GitLab CI or GitHub Actions, with safety checks against protected branches and uncommitted changes. Use when the user asks to push and trigger the pipeline, or just "push". Not for running tests first - that is what ci-all does.
---

# Push and trigger pipeline

Pushes the current branch and returns the pipeline tracking link.

## Extra instructions

Text after `/ci-pipeline` is the user's extra instructions. The source
allowed flags such as `--force` or `--draft`; do not honor a force
request without explicitly confirming blast radius, and prefer
`--force-with-lease` if it is genuinely required.

## Process

```bash
BRANCH=$(git branch --show-current)

# 1. Safety check: never push directly to a protected branch
if echo "$BRANCH" | grep -qE "^(main|master|production)$"; then
  echo "BLOCKED: direct push to $BRANCH is not allowed."
  echo "Create a feature or fix branch first."
  exit 1
fi

# 2. Safety check: uncommitted changes
UNCOMMITTED=$(git status --porcelain | wc -l | tr -d " ")
if [ "$UNCOMMITTED" -gt 0 ]; then
  echo "$UNCOMMITTED uncommitted file(s):"
  git status --short
  echo ""
  echo "Commit first (git add + git commit), then re-run."
  exit 0
fi

# 3. Push
echo "Pushing -> origin/$BRANCH"
git push origin "$BRANCH" 2>&1
```

Pushing is a shared-state action: state the branch before running it.
Never force-push to a shared branch.

## Pipeline URL

```bash
REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
WEB_URL=$(echo "$REMOTE" | sed 's/git@gitlab\.com:/https:\/\/gitlab.com\//' \
                        | sed 's/git@github\.com:/https:\/\/github.com\//' \
                        | sed 's/\.git$//')
```

GitLab CI:

```bash
echo "Push OK"
echo "Pipeline: $WEB_URL/-/pipelines?ref=$BRANCH"
# Live status via glab, if installed
command -v glab >/dev/null && sleep 3 && glab ci status --branch "$BRANCH" || true
```

GitHub Actions:

```bash
echo "Push OK"
echo "Actions: $WEB_URL/actions?query=branch%3A$BRANCH"
# Live status via gh, if installed
command -v gh >/dev/null && sleep 5 && gh run list --branch "$BRANCH" --limit 3 || true
```

If neither CLI is installed, the URL is the deliverable.

## Expected output

```text
Pushing -> origin/feat/add-payment-retry

Enumerating objects: 12, done.
[git push output]

Push OK
Pipeline: https://gitlab.com/org/my-app/-/pipelines?ref=feat/add-payment-retry

Pipeline status (after 3s):
  lint       running
  test       waiting
  deploy     waiting
```

## Common mistakes

- Pushing with uncommitted changes: the pipeline tests a different tree
  than the local one. Commit first.
- Pushing to main/master/production: blocked on purpose; branch first.
- Trusting the URL without the push output: show both.
