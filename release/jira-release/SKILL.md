---
name: jira-release
description: Full release lifecycle automation. Use when the user runs /release with a version (e.g. /release 1.2.0). Detects repo topology (branches, open PRs), decides automatically whether to create a release candidate into test, a direct release into main/master, or promote an existing RC — then handles Jira lookup, branch creation, changelog, version bump, commit, push, and PR creation in one flow.
disable-model-invocation: true
---

# Release Skill

Automates the full Gitflow release lifecycle in one intelligent command.

**Invocation:** `/release <version>` — e.g. `/release 1.2.0`

---

## Phase 0 — Environment & Config

### 0.1 Validate version argument

`$ARGUMENTS` is the version. Strip any leading `v` and validate it matches `X.Y.Z`.
Work with bare semver internally (`1.2.0`), prefix with `v` only for branch names, tags, PR titles, and Jira.

If the argument is missing or malformed, stop immediately:
> "Please provide a valid semver version. Usage: `/release 1.2.0`"

### 0.2 Check working tree

```bash
git status --short
```

If there are uncommitted changes (staged or unstaged), stop:
> "Your working tree has uncommitted changes. Please commit or stash them before releasing."

Untracked files are fine — do not block on those.

### 0.3 Resolve Jira config from CLAUDE.md

Read the repo's `CLAUDE.md` (and `~/.claude/CLAUDE.md` as fallback). Look for:
- `JIRA_PROJECT_KEY` (e.g. `OSD`, `BLU`)
- `JIRA_BASE_URL` (e.g. `https://yourcompany.atlassian.net`)

If not found in either file, ask the user:
> "I couldn't find Jira config in CLAUDE.md. What is your Jira project key (e.g. OSD) and base URL (e.g. https://yourcompany.atlassian.net)?"

Use whatever they provide for this session — do not write to any file unless the user explicitly asks you to save it.

---

## Phase 1 — Topology Discovery

Run all of these in parallel:

```bash
# 1. List all remote branches
git fetch --prune --quiet
git branch -r --format='%(refname:short)' | sed 's|origin/||'

# 2. List open PRs targeting test/main/master from a release branch
gh pr list \
  --state open \
  --json number,title,headRefName,baseRefName,url,createdAt \
  --jq '[.[] | select(.headRefName | startswith("release/"))]'

# 3. List recently merged PRs (last 7 days) targeting test
gh pr list \
  --state merged \
  --json number,title,headRefName,baseRefName,url,mergedAt \
  --jq '[.[] | select(.headRefName | startswith("release/")) | select(.baseRefName == "test")]' \
  | head -20

# 4. Check if release branch already exists
git branch -r | grep "origin/release/v$VERSION" || echo "not_found"
```

From this data, resolve:
- `HAS_TEST` — does `test` branch exist on remote?
- `HAS_MAIN` — does `main` branch exist?
- `HAS_MASTER` — does `master` branch exist? (use if `main` absent)
- `PROD_BRANCH` — `main` if exists, else `master`
- `OPEN_RC_PR` — any open PR from `release/v$VERSION` → `test`
- `MERGED_RC_PR` — any recently merged PR from `release/v$VERSION` → `test`
- `RELEASE_BRANCH_EXISTS` — whether `release/v$VERSION` already exists remotely

---

## Phase 2 — Intent Detection

Based on topology, determine the scenario. **Only one path fires.**

### Scenario A — Promote existing RC
**Condition:** `MERGED_RC_PR` exists (RC was merged into test)

→ A release branch was already merged into test. Likely ready for production.

Ask the user:
> "I found a merged RC PR for v$VERSION into test (#PR_NUMBER, merged RELATIVE_TIME ago).
>
> What would you like to do?
> 1. **Promote to $PROD_BRANCH** — open a production PR from `release/v$VERSION` → `$PROD_BRANCH`
> 2. **Create a new RC** — cut a fresh release branch from develop and start over
> 3. **Abort**"

Proceed based on their choice (→ Phase 4 for promote, → Phase 3 for new RC).

### Scenario B — Resume open RC
**Condition:** `OPEN_RC_PR` exists (RC PR is open, not yet merged into test)

→ A release is already in progress.

Ask the user:
> "There's already an open RC PR for v$VERSION → test (#PR_NUMBER).
>
> What would you like to do?
> 1. **Open the PR** — I'll give you the link to the existing PR
> 2. **Promote now** — skip test and open a PR directly to $PROD_BRANCH from this branch
> 3. **Start fresh** — close this PR and create a new release branch
> 4. **Abort**"

### Scenario C — Create release candidate
**Condition:** `HAS_TEST = true` AND no existing RC for this version

→ Standard test-first flow. Create RC branch and open PR into `test`.

Proceed directly to Phase 3 → PR targets `test`.

### Scenario D — Direct release
**Condition:** `HAS_TEST = false` AND (`HAS_MAIN = true` OR `HAS_MASTER = true`)

→ No test branch. Release goes straight to `$PROD_BRANCH`.

Inform the user:
> "No `test` branch found on remote. I'll create a direct release PR into `$PROD_BRANCH`."

Proceed directly to Phase 3 → PR targets `$PROD_BRANCH`.

### Scenario E — Ambiguous / missing branches
**Condition:** Neither `test`, `main`, nor `master` found

→ Stop and ask:
> "I couldn't find `test`, `main`, or `master` branches. What branch should I target for this release?"

Use their answer as `TARGET_BRANCH`.

---

## Phase 3 — Build the Release

*(Skip to Phase 4 if Scenario A-promote was chosen)*

### 3.1 Fetch Jira tickets

Search for tickets linked to fix version `v$VERSION`:

```jql
project = "$JIRA_PROJECT_KEY"
AND fixVersion = "v$VERSION"
AND issuetype in (Story, Task, Bug)
ORDER BY issuetype ASC, priority DESC
```

If no results, try a broader fallback:
```jql
project = "$JIRA_PROJECT_KEY"
AND fixVersion = "v$VERSION"
```

Try to group and categories the results into the following categories:
- Added: New features, functionality, or modules.
- Changed: Changes in existing functionality.
- Deprecated: Soon-to-be-removed features.
- Removed: Features removed from the software.
- Fixed: Bug fixes or resolved issues.
- Security: Patches for vulnerabilities.

If still no results, tell the user and ask:
> "No Jira tickets found for fix version `v$VERSION`. Continue without ticket references, or enter a different fix version name?"

### 3.2 Sync develop with target branch

Before creating the release branch, ensure `develop` includes all changes from the target branch (hotfixes, prior releases, etc.):

```bash
git checkout develop
git pull origin develop
git merge --no-ff origin/$TARGET_BRANCH -m "chore: sync $TARGET_BRANCH with develop"
git push origin develop
```

Where `$TARGET_BRANCH` is `test` for an RC, or `$PROD_BRANCH` (e.g. `main`) for a direct release.

If merge conflicts occur, stop and report them clearly. Do not auto-resolve.

### 3.3 Create or checkout release branch

If `RELEASE_BRANCH_EXISTS`:
```bash
git checkout release/v$VERSION
git pull origin release/v$VERSION
```

Otherwise:
```bash
git checkout develop
git pull origin develop
git checkout -b release/v$VERSION
```

If `develop` doesn't exist, ask which branch to cut from.

### 3.4 Update CHANGELOG.md

Read the existing `CHANGELOG.md` if present. Find the `## [Unreleased]` section if it exists — use its contents as a base. Otherwise build from Jira tickets.

Insert a new entry below the `# Changelog` header:

```markdown
## [v$VERSION] - YYYY-MM-DD

### Added
- **PROJ-123**: Summary of ticket

### Change
- **PROJ-125**: Summary of ticket

...
```

Rules:
- Date: today in `YYYY-MM-DD`
- Skip any section with no items
- If `## [Unreleased]` existed, remove or empty it after extracting its contents
- If `CHANGELOG.md` doesn't exist, create it with a standard header first

### 3.5 Bump version in package.json

```bash
npm version $VERSION
```

If no `package.json` exists, skip silently.
If `package.json` exists but `npm` isn't available, update the `version` field manually with Write tool.

### 3.6 Commit and push

Stage only release-related files:

```bash
git add CHANGELOG.md
git add package.json package-lock.json 2>/dev/null || true
git commit -m "chore(release): v$VERSION"
git push origin release/v$VERSION
```

### 3.7 Create Pull Request

**Determine PR metadata from `TARGET_BRANCH`:**

| Target | PR Title | Label | Is RC? |
|---|---|---|---|
| `test` | `release(test): v$VERSION` | `release-candidate` | yes |
| `main` / `master` | `release: v$VERSION` | `release` | no |

Build the PR body from the template files in the same directory as this skill:
- RC (target is `test`) → read `./templates/pr-rc-body.md`
- Direct / Production (target is `main` or `master`) → read `./templates/pr-release-body.md`

Substitute these placeholders:
- `{{VERSION}}` → version string
- `{{CHANGELOG}}` → the full changelog entry written in 3.4
- `{{TICKETS}}` → formatted ticket list (key + summary + Jira URL)
- `{{PROD_BRANCH}}` → the production branch name

```bash
gh pr create \
  --title "COMPUTED_TITLE" \
  --body "COMPUTED_BODY" \
  --base "$TARGET_BRANCH" \
  --head "release/v$VERSION" \
  --label "COMPUTED_LABEL"
```

Print the PR URL prominently.

---

## Phase 4 — Promote RC to Production

*(Only reached from Scenario A-promote or Scenario B option 2)*

### 4.1 Verify release branch exists

```bash
git fetch origin
git branch -r | grep "origin/release/v$VERSION"
```

If not found, stop:
> "Branch `release/v$VERSION` doesn't exist on remote. Run `/release $VERSION` first to create it."

### 4.2 Confirm with user

Show:
> "Promoting `release/v$VERSION` → `$PROD_BRANCH`.
>
> This will:
> - Sync the release branch with `test` (pick up any last-minute fixes)
> - Open a production PR
> - Mark the Jira version as released
> - Transition tickets to Done
>
> Confirm? (yes/no)"

### 4.3 Sync release branch with test

```bash
git checkout release/v$VERSION
git pull origin release/v$VERSION
git merge origin/test --no-edit
git push origin release/v$VERSION
```

If merge conflicts occur, stop and report them clearly. Do not auto-resolve.

### 4.4 Create production PR

Read changelog entry for `v$VERSION` from `CHANGELOG.md`.

```bash
gh pr create \
  --title "release: v$VERSION" \
  --body "$(PROMOTE_BODY)" \
  --base "$PROD_BRANCH" \
  --head "release/v$VERSION" \
  --label "release"
```

Use `./templates/pr-release-body.md` for the body.

---

## Phase 5 — Summary

Always end with a clean, structured summary:

**For new RC (Scenario C/D):**
```
✅ Release candidate v$VERSION created

  Branch   : release/v$VERSION
  PR       : <url>
  Target   : $TARGET_BRANCH
  Tickets  : PROJ-123, PROJ-124 (N items)
  Jira     : Tickets transitioned → In Release

  Next steps:
  → Merge the PR into $TARGET_BRANCH
  → Validate in $TARGET_BRANCH environment
  → Run /release $VERSION again to promote to $PROD_BRANCH
```

**For promote (Scenario A/B-promote):**
```
✅ Release v$VERSION promoted to production

  PR       : <url>
  Target   : $PROD_BRANCH
  Jira     : Version marked as released, N tickets → Done
  Tag      : v$VERSION (created / pending merge)
```

**For direct release (Scenario D):**
```
✅ Release v$VERSION created

  Branch   : release/v$VERSION
  PR       : <url>
  Target   : $PROD_BRANCH (direct — no test branch)
  Tickets  : N items
  Jira     : Version marked as released, tickets → Done
```