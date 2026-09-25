---
name: release-notes
description: Generate release notes in three formats from the git history since the last release tag - a CHANGELOG section, a release PR body, and a user-facing announcement - with migration alerts and semantic versioning. Use when preparing a release and the user asks for release notes or a changelog. All commands are plain git; the gh or glab CLI is optional for PR details.
---

# Release notes generator

Generate release notes in three formats from git commits for a production
release.

## Extra instructions

Text after `/release-notes` is the user's extra instructions: an
optional version (for example `v1.5.0`), a range (for example
`from v1.4.0 to HEAD`), or `--preview` (show outputs without writing
files).

## Process

1. **Analyze git history**: scan commits since the last release tag.
2. **Fetch PR details** (optional): titles and descriptions via the
   `gh` CLI (`gh api repos/{owner}/{repo}/pulls/{number}`) or `glab`
   on GitLab - skip cleanly if neither is installed or authenticated.
3. **Categorize changes**: group by type (feat, fix, perf, and so on).
4. **Check migrations**: detect database migration files.
5. **Generate three outputs**: CHANGELOG section, PR body,
   communication message.
6. **Transform language**: convert technical jargon to product language
   for the announcement.

## Commands to run

```bash
# 1. Last release tag (exclude pre-release tags)
LAST_TAG=$(git tag --sort=-v:refname \
  | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | head -n 1)

# 2. Commits since the tag (excluding merges)
git log "$LAST_TAG"..HEAD --oneline --no-merges

# 3. Migration detection - adjust to the project's ORM
git diff "$LAST_TAG"..HEAD --name-only -- prisma/migrations/
git diff "$LAST_TAG"..HEAD --name-only -- migrations/
git diff "$LAST_TAG"..HEAD --name-only -- alembic/versions/

# 4. Statistics
FEATURES=$(git log "$LAST_TAG"..HEAD --oneline --no-merges | grep -c "feat:")
FIXES=$(git log "$LAST_TAG"..HEAD --oneline --no-merges | grep -c "fix:")
```

With no tag found, start from the first commit and say so. With no
commits since the tag, stop: "no changes to release".

## Output formats

### 1. CHANGELOG.md section

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Summary
[1-2 sentence overview of this release]

### New Features
#### [Feature Name] (#PR)
- **Description**: user-facing functionality added
- **Impact**: how it benefits users

### Bug Fixes
- **[Module]**: description (#issue, tracking-ID)

### Technical Improvements
- [Internal improvements, refactoring, performance]

### Database Migrations
[If applicable - list migration files]

### Statistics
- PRs: X | Features: Y | Fixes: Z | Files changed: N
```

### 2. Release PR body

Use the project's release template if one exists (check
`.github/PULL_REQUEST_TEMPLATE/`, `docs/templates/`, or the project's
own convention); otherwise structure it as Summary / Changes / Migrations
/ Test Plan / Rollback.

### 3. Communication announcement

A user-facing announcement (chat message, email): non-technical
language, focused on user impact, readable formatting.

## Migration alert

If migrations are detected, lead the PR body and the announcement with a
plain-text alert:

```text
ATTENTION: DATABASE MIGRATIONS REQUIRED
This release contains 2 migration(s):
  - 20250110_add_user_preferences
  - 20250112_create_audit_log_table
Action required: run the migration command after deployment.
```

If none: state "No database migrations required."

## Tech-to-product transformation

Convert technical commits to user-facing descriptions:

| Technical | Product/user language |
|---|---|
| "Optimize N+1 queries with DataLoader" | "Faster loading times for lists" |
| "Implement AI embeddings with pgvector" | "New intelligent search feature" |
| "Fix permissions scope bug" | "Resolved an access issue for certain users" |
| "Migration webpack to Turbopack" | Internal only - do not communicate |
| "Refactor React hooks architecture" | Internal only - do not communicate |
| "Add rate limiting to API endpoints" | "Improved system stability and security" |

## Commit categories

| Prefix | Category | Include in announcement? |
|---|---|---|
| `feat:` | New features | Yes |
| `fix:` | Bug fixes | Yes (if user-facing) |
| `perf:` | Performance | Yes (simplified) |
| `security:` | Security | Yes |
| `refactor:` | Architecture | No |
| `chore:` | Maintenance | No |
| `docs:` | Documentation | No |
| `test:` | Tests | No |
| `build:` | Build system | No |
| `ci:` | CI/CD | No |

Commits without conventional format go under "Other Changes".

## Semantic versioning

| Change type | Version bump | Example |
|---|---|---|
| Breaking change | MAJOR (X.0.0) | API removed, incompatible change |
| New feature | MINOR (0.X.0) | New functionality, backward-compatible |
| Bug fix / patch | PATCH (0.0.X) | Bug fixes only |

Indicators: `BREAKING CHANGE:` in a commit body means MAJOR; `feat:`
commits mean MINOR; only `fix:` / `perf:` means PATCH.

## Workflow integration

Typical release workflow:

1. Verify all PRs are merged to the release branch.
2. Run `/release-notes` (or specify version/range in the extra
   instructions).
3. Review the generated outputs for accuracy - every claim must trace
   to a commit you listed.
4. Open the release PR with the generated body.
5. Add the generated CHANGELOG section to CHANGELOG.md.
6. After merge, create and push an annotated tag:
   `git tag -a v1.2.3 -m "Release v1.2.3: brief description"` then
   `git push origin v1.2.3`.
7. Post the communication announcement.
8. Monitor the deployment and migrations.

## Tips

- Run from the repository root: git commands depend on it.
- Review before publishing: generated content is a draft, not a
  source of truth.
- Breaking changes: search commit messages for `BREAKING CHANGE:`.
- Linked issues: include issue and ticket numbers for traceability.
- Migrations: test in staging before production.

## Edge cases

| Scenario | Behavior |
|---|---|
| No tags found | Start from the first commit |
| No commits since last tag | Stop: "no changes to release" |
| Multiple tags on the same commit | Use the most recent by date |
| Pre-release tags (v1.0.0-beta.1) | Excluded from "last release" search |
| Commits without conventional format | Categorize as "Other Changes" |
