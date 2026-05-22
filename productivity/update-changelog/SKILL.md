---
name: update-changelog
description: Update or create CHANGELOG.md with recent git changes. Use when the user asks to update the changelog, document recent changes, or prepare release notes.
allowed-tools: Bash(git log:*), Bash(git diff:*), Bash(git tag:*), Read, Write
---

Update the project CHANGELOG.md with recent changes.

## Steps

1. **Gather git history** — run these to understand recent work:
```
   git log --oneline --no-merges -30
   git tag --sort=-creatordate | head -5
```

2. **Determine scope** — find the last changelog entry or latest tag to know what's "new":
   - If `CHANGELOG.md` exists: read it and identify the last recorded version/date
   - If no tags exist, use all commits not yet in the changelog

3. **Categorize commits** into:
   - `### Added` — new features
   - `### Changed` — modifications to existing behavior
   - `### Fixed` — bug fixes
   - `### Removed` — deleted features
   - `### Security` — vulnerability fixes
   - `### Deprecated` — soon-to-be removed features

   Skip chore/ci/docs commits unless significant.

4. **Determine version**:
   - If `$ARGUMENTS` is provided, use it as the version (e.g. `/update-changelog 1.2.0`)
   - Otherwise infer from the latest git tag or use `[Unreleased]`

5. **If `CHANGELOG.md` exists** — prepend the new entry below the `# Changelog` header, keeping all existing entries intact.

6. **If `CHANGELOG.md` does not exist** — create it with this structure:
```markdown
   # Changelog

   All notable changes to this project will be documented in this file.
   The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

   ## [VERSION] - YYYY-MM-DD

   ### Added
   - ...

   ### Changed
   - ...

   ### Fixed
   - ...
```

7. **Write the file** and confirm what was added.

## Rules
- Follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format
- Date format: `YYYY-MM-DD`
- Be concise — one line per change, written for humans not machines
- Do not include commit hashes in the output
- If nothing meaningful changed, say so and don't write an empty section
```

---

**Usage:**
```
/update-changelog           # uses [Unreleased] as version
/update-changelog 1.3.0     # tags the entry with that version