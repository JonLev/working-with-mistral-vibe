---
name: git-worktree-remove
description: Safely remove one worktree with branch cleanup - safety checks first (protected branches, uncommitted changes, merge status), then clean removal of the worktree directory, its branch, and the remote branch with explicit confirmation at each destructive step. Use when the user asks to remove a specific worktree. Destructive skill - never skip the merge-status and dirty-state warnings.
---

# Worktree remove

Safely remove a single worktree with branch cleanup, merge verification,
and database teardown reminders.

Safety checks first, then clean removal of worktree, branch, and remote
resources. Every destructive step is confirmed.

## Extra instructions

Text after `/git-worktree-remove` is the user's extra instructions: the
worktree name to remove, plus optional flags:

- `--force`: skip the uncommitted-changes warning (still blocked for
  protected branches).
- `--keep-branch`: remove the worktree but keep the local branch.
- `--keep-remote`: do not delete the remote branch.

## Identify the target

Vibe worktrees for this repository live under
`$VIBE_HOME/worktrees/<repo-name>-<repo-hash>/` (default `~/.vibe`).
Resolve the name against `git worktree list`; if the name is ambiguous
or does not exist, list the worktrees and ask.

Also check the claim record under
`$HOME/.vibe/worktrees/.claims/<repo-dir>/<name>/`: if a session marker
shows the worktree is in use, stop and report it rather than removing
an active session's checkout.

## Safety checks

### Protected branches

```bash
PROTECTED_BRANCHES="main master develop staging production"
BRANCH=$(git -C "$WORKTREE" rev-parse --abbrev-ref HEAD)

if echo "$PROTECTED_BRANCHES" | grep -qw "$BRANCH"; then
  echo "BLOCKED: cannot remove a worktree for protected branch '$BRANCH'"
  exit 1
fi
```

### Uncommitted changes

```bash
if [ -n "$(git -C "$WORKTREE" status --porcelain)" ]; then
  echo "WARNING: worktree has uncommitted changes:"
  git -C "$WORKTREE" status --short
  echo "Options: commit first, pass --force, or cancel."
fi
```

With uncommitted changes and no `--force`, stop and let the user decide.
Uncommitted work cannot be recovered after removal.

### Merge status

```bash
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's@^refs/remotes/origin/@@')
MAIN_BRANCH=${MAIN_BRANCH:-main}

if git merge-base --is-ancestor "$BRANCH" "$MAIN_BRANCH" 2>/dev/null; then
  echo "Branch '$BRANCH' is merged into $MAIN_BRANCH. Safe to delete."
else
  echo "WARNING: branch '$BRANCH' is NOT merged into $MAIN_BRANCH."
  echo "Deleting it may lose work."
fi
```

## Removal steps

With confirmation for each destructive step:

```bash
# 1. Remove the worktree (add --force only after explicit confirmation
#    when it is dirty)
git worktree remove "$WORKTREE"

# 2. Delete the local branch
git branch -d "$BRANCH"            # merged
git branch -D "$BRANCH"           # unmerged, only on explicit confirmation

# 3. Delete the remote branch (only on explicit confirmation)
git push origin --delete "$BRANCH"

# 4. Prune stale references
git worktree prune
```

## Database branch cleanup

A worktree created for schema work may own a database branch. Remind the
user with the concrete command when a provider is detected:

```bash
if [ -f "$WORKTREE/.env" ] && grep -q "neon" "$WORKTREE/.env"; then
  echo "DB cleanup: neonctl branches delete $BRANCH_SLUG"
elif [ -f "$WORKTREE/.pscale.yml" ]; then
  DB_NAME=$(grep "database:" "$WORKTREE/.pscale.yml" | awk "{print \$2}")
  echo "DB cleanup: pscale branch delete $DB_NAME $BRANCH_SLUG"
fi
```

## Report format

```text
Removed worktree: auth
  Worktree directory: deleted
  Local branch auth: deleted (was merged)
  Remote branch origin/auth: deleted (confirmed)
  References: pruned

DB reminder: neonctl branches delete feat-auth
```

With warnings:

```text
Removed worktree: experimental
  Local branch experimental: deleted (was NOT merged - forced, confirmed)
  No remote branch found.
  References: pruned

WARNING: branch was not merged. Last commit:
  a1b2c3d "WIP: experimental auth flow"
```

## Common mistakes

- Removing a worktree for a protected branch: always blocked.
- Deleting an unmerged branch without checking: verify merge status
  first; unmerged branches need explicit confirmation.
- Skipping the dirty-state check: uncommitted work is unrecoverable.
- Using `rm -rf` instead of `git worktree remove`: leaves stale
  references in `.git/worktrees/`. Always use git.
- Forgetting the database branch: it outlives the worktree and keeps
  costing resources.
