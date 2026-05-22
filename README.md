# skills

My personal collection of [Claude Code](https://claude.com/claude-code) agent skills — the source of truth for skills I develop and use day to day.

## Layout

Skills are grouped into category folders, one skill per folder (each folder holds a `SKILL.md`):

```
productivity/
  update-changelog/     # Generate CHANGELOG.md from git history
release/
  jira-release/         # Full Gitflow release lifecycle: /release <version>
```

## Installing / syncing

This repo is the source of truth. To use the skills locally, symlink each one into
your Claude skills directory (`~/.claude/skills/`):

```bash
./link-skills.sh
```

The script symlinks every `SKILL.md` folder it finds into `~/.claude/skills/`, so
edits here take effect live — no copy step, no drift. It's idempotent (safe to
re-run) and never clobbers a real (non-symlink) entry already in the target dir.

Custom target directory:

```bash
CLAUDE_SKILLS_DIR=/some/other/path ./link-skills.sh
```

> Symlinks are a local install detail — they don't survive `git clone` as live
> links. On a new machine, clone the repo and re-run `./link-skills.sh`.

## Adding a new skill

1. Create `category/skill-name/SKILL.md` (use the `skill-creator` or
   `superpowers:writing-skills` skill to scaffold it).
2. Run `./link-skills.sh` to link it into `~/.claude/skills/`.
3. Commit and push.
