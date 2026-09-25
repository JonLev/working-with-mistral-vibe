---
name: commit
description: Generate a conventional commit message for the staged changes, from the actual diff, and commit after confirmation. Use when the user is ready to commit staged changes and wants the message derived from evidence rather than memory. Not for unstaged work - stage first.
---

# Conventional commit

Generate a conventional commit message for the staged changes.

## Extra instructions

Text after `/commit` is the user's extra instructions: an optional
message seed or a flag such as `--amend` (amend the previous commit
instead of creating a new one).

## Instructions

1. Run `git diff --cached` and read the full staged diff - the message is
   derived from the diff, not from memory of the work.
2. Analyze the nature of the changes.
3. Generate a commit message following the format below.
4. Ask for confirmation before executing
   `git commit -m "<message>"` (or `git commit --amend` when requested).
   Committing is a shared-state action: show the message and the file
   list first.

If nothing is staged, stop and say so - suggest `git add` for the
intended files rather than staging or committing anything unasked.

## Commit format

```text
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### Types

- `feat`: new feature
- `fix`: bug fix
- `docs`: documentation only
- `style`: formatting, missing semicolons, and similar
- `refactor`: code change that neither fixes a bug nor adds a feature
- `perf`: performance improvement
- `test`: adding missing tests
- `chore`: maintenance tasks

### Rules

- Subject: imperative mood, no period, max 50 chars.
- Body: explain WHAT and WHY, not HOW.
- Footer: breaking changes, issue references.

## Examples

```text
feat(auth): add password reset functionality

Implement password reset flow with email verification.
Users can now request a reset link and set a new password.

Closes #123
```

```text
fix(api): prevent race condition in order processing

Add mutex lock to ensure orders are processed sequentially.
This fixes duplicate charge issues reported by users.

Fixes #456
```

```text
refactor(cart): extract pricing logic to separate module

No functional changes. Improves testability and
separates concerns for future discount feature.
```

## Evidence discipline

- Quote the type and scope back to the diff hunks that justify them.
- If the staged diff contains unrelated changes, say so and propose
  splitting the commit rather than smuggling them in.
- Never claim a test status in the message that was not shown in this
  session.
