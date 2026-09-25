---
name: git-worktree-clean
description: Batch-clean this repository's stale worktrees under $VIBE_HOME/worktrees - classify each as merged, unmerged, or protected, auto-remove only the merged ones, review the rest interactively, and report reclaimed space. Use when the user asks to clean up old or stale worktrees. Removing unmerged work with uncommitted changes is a destructive action - always preview first and confirm.
---

# Worktree cleanup

Batch cleanup of stale worktrees. Safely removes merged branches'
worktrees, reports disk usage, and handles unmerged worktrees
interactively.

Vibe already auto-removes a worktree on session exit when it created it
and it has no uncommitted changes, no untracked files, and no commits
beyond the starting commit - and programmatic worktree runs never
auto-clean. This skill covers everything that outlives that rule.

## Extra instructions

Text after `/git-worktree-clean` is the user's extra instructions:

- `--dry-run`: preview what would be cleaned, no changes.
- `--all`: also review unmerged worktrees, one by one.

No flags means: remove merged worktrees only (safe by default).

## Worktree discovery

```bash
# Main branch
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's@^refs/remotes/origin/@@')
MAIN_BRANCH=${MAIN_BRANCH:-main}

# Protected branches (never clean)
PROTECTED="main master develop staging production"

# All worktrees except the main checkout
git worktree list --porcelain
```

## Classification

For each worktree:

```bash
BRANCH=$(git -C "$WORKTREE" rev-parse --abbrev-ref HEAD)

if echo "$PROTECTED" | grep -qw "$BRANCH"; then
  echo "PROTECTED: $BRANCH (skipped)"
elif git merge-base --is-ancestor "$BRANCH" "$MAIN_BRANCH" 2>/dev/null; then
  echo "MERGED: $BRANCH -> safe to remove"
else
  echo "UNMERGED: $BRANCH -> requires review"
fi

# Disk usage per worktree
du -sh -I node_modules "$WORKTREE" 2>/dev/null | cut -f1
```

Also check `$HOME/.vibe/worktrees/.claims/<repo-dir>/` for the claim
records: a worktree with an active per-session claim may be in use -
skip it and say so.

## Dry run

With `--dry-run`, print the classification, what would be removed, what
would be kept, and the total reclaimable space. No changes.

```text
Dry run - no changes made

Would remove (3 merged):
  ~/.vibe/worktrees/my-app-1a2b3c4/auth - 2.3 MB
  ~/.vibe/worktrees/my-app-1a2b3c4/fix-login-bug - 1.1 MB
  ~/.vibe/worktrees/my-app-1a2b3c4/deps-update - 0.8 MB

Would keep (1 unmerged):
  ~/.vibe/worktrees/my-app-1a2b3c4/experimental - 4.2 MB

Potential savings: 4.2 MB
```

## Auto mode (default)

Only merged worktrees. Confirm the list with the user before executing -
removal is destructive even when the branch is merged.

```bash
for WORKTREE in $MERGED_LIST; do
  BRANCH=$(git -C "$WORKTREE" rev-parse --abbrev-ref HEAD)

  git worktree remove "$WORKTREE"
  git branch -d "$BRANCH" 2>/dev/null
  git push origin --delete "$BRANCH" 2>/dev/null

  echo "Removed: $WORKTREE ($BRANCH)"
done

git worktree prune
```

Deleting the remote branch is a shared-state action: only do it when the
user confirmed it, and say for each branch whether the local delete, the
remote delete, or both happened.

## Interactive review (--all)

For each unmerged worktree, present the facts and ask:

```text
Unmerged: ~/.vibe/worktrees/my-app-1a2b3c4/experimental
  Branch: experimental (4 commits ahead of main)
  Last commit: a1b2c3d "WIP: new auth flow" (3 days ago)
  State: dirty - 2 modified files
  Size: 4.2 MB

[r]emove  [k]eep  [s]kip remaining
```

Work with one decision at a time; never batch-remove unmerged work.

## Report format

```text
=== Worktree cleanup report ===

Removed (merged):
  auth - 2.3 MB
  fix-login-bug - 1.1 MB

Kept (unmerged):
  experimental - 4.2 MB
    Last commit: a1b2c3d "WIP: new auth flow" (3 days ago)

Kept (protected): develop

Space reclaimed: 3.4 MB
Worktrees remaining: 2
References pruned: yes

Database branches to clean:
  neonctl branches delete auth
  neonctl branches delete fix-login-bug
```

Worktree cleanup does not delete database branches - list them with
their commands when the project uses a branching provider.

## Common mistakes

- Removing a worktree with an active session claim. Check
  `$HOME/.vibe/worktrees/.claims/` first.
- Batch-removing unmerged worktrees. Unmerged means possible lost work;
  review each one.
- Using `rm -rf` instead of `git worktree remove`: leaves stale
  references in `.git/worktrees/`. Use git, then `git worktree prune`.
- Forgetting the database branches: they outlive the worktree and keep
  costing resources.
- Never running cleanup: stale worktrees accumulate disk space. A
  weekly `/git-worktree-clean --dry-run` is cheap.
