---
name: git-worktree-status
description: Report the state of this repository's worktrees - which worktrees exist under $VIBE_HOME/worktrees, their branches, commits ahead or behind, clean or dirty state, disk usage, and claim records. Use when the user asks what worktrees exist or where a piece of parallel work stands. Not for creating a worktree (git-worktree) or removing one (git-worktree-remove).
---

# Worktree status

Report the state of this repository's worktrees. Non-blocking feedback
on parallel work without interrupting any session.

## Extra instructions

Text after `/git-worktree-status` is the user's extra instructions: an
optional worktree name to restrict the report to. With no name, report
all worktrees for this repository.

## Worktree discovery

Vibe's worktrees for this repository live under
`$VIBE_HOME/worktrees/<repo-name>-<repo-hash>/` (default `$VIBE_HOME` is
`~/.vibe`). Plain git lists them from the main checkout:

```bash
# All worktrees known to this repository (includes the main checkout)
git worktree list --porcelain

# Only Vibe-managed ones, if you need the exact directory:
ls "$HOME/.vibe/worktrees/" 2>/dev/null
```

Work with the `git worktree list` output: each non-main entry has a path
and a branch.

## Per-worktree report

For each worktree:

```bash
# Branch and position
BRANCH=$(git -C "$WORKTREE" rev-parse --abbrev-ref HEAD)
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's@^refs/remotes/origin/@@')
MAIN_BRANCH=${MAIN_BRANCH:-main}
AHEAD=$(git rev-list --count "$MAIN_BRANCH".."$BRANCH")
BEHIND=$(git rev-list --count "$BRANCH".."$MAIN_BRANCH")

# Clean or dirty
if [ -z "$(git -C "$WORKTREE" status --porcelain)" ]; then
  echo "clean"
else
  echo "dirty:"
  git -C "$WORKTREE" status --short
fi

# Last commit
git -C "$WORKTREE" log -1 --format="%h %s (%cr)"

# Disk usage (excluding dependencies)
du -sh -I node_modules "$WORKTREE" 2>/dev/null | cut -f1
```

Also check the session-side state Vibe records:

```bash
# Claim records: branch, starting commit, ownership
ls "$HOME/.vibe/worktrees/.claims/" 2>/dev/null
```

If a claim record exists for a worktree, a session may still be using
it - a per-session marker guards concurrent use. Do not recommend
removing a worktree while its claim record shows an active session.

## Report format

```text
Worktrees for my-app (main branch: main)

1. ~/.vibe/worktrees/my-app-1a2b3c4/auth
   Branch: auth - 3 ahead, 0 behind main
   State: clean
   Last commit: a1b2c3d "feat: token validation" (2 hours ago)
   Disk: 2.3 MB (excl. node_modules)

2. ~/.vibe/worktrees/my-app-1a2b3c4/fix-payment-retry
   Branch: fix-payment-retry - 1 ahead, 4 behind main
   State: dirty - 2 modified, 1 untracked
   Last commit: e4f5g6h "WIP: retry loop" (3 days ago)
   Disk: 4.2 MB (excl. node_modules)

Notes:
- Worktree 2 is behind main and dirty; it needs a rebase or a decision.
- Behind and dirty worktrees are candidates for git-worktree-remove.
```

## Interpretation guidance

| Observation | Meaning |
|---|---|
| Ahead of main, clean | Likely finished work - review, PR, or merge it |
| Behind main, clean | Safe to rebase or remove |
| Behind main, dirty | Needs a human decision - work may be lost |
| Matches main exactly | Unused - safe to remove |
| Claim record with active session | Leave it alone |

Report facts from the git output; do not invent states. Sessions started
in a worktree are directory-scoped, so an active session's status is
visible to the user inside that session, not here - say so when asked.
