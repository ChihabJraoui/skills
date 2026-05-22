# skills

A collection of [Claude Code](https://claude.com/claude-code) agent skills I build and use day to day, shared publicly in case they're useful to you too.

Skills extend Claude Code with reusable, model-invocable workflows. Each one lives in its own folder with a `SKILL.md` that tells Claude when and how to use it.

## What's here

| Skill | What it does |
|-------|--------------|
| [`productivity/update-changelog`](productivity/update-changelog) | Generate or update `CHANGELOG.md` from your git history |
| [`release/jira-release`](release/jira-release) | Full Gitflow release lifecycle in one command: `/release <version>` — RC vs. direct-release detection, Jira lookup, changelog, version bump, and PR creation |

## Using these skills

Clone the repo, then symlink the skills into your Claude skills directory (`~/.claude/skills/`):

```bash
git clone https://github.com/<your-username>/skills.git
cd skills
./link-skills.sh
```

`link-skills.sh` symlinks every `SKILL.md` folder it finds into `~/.claude/skills/`,
so the skills become available the next time you start Claude Code. The script is
idempotent (safe to re-run) and never overwrites a real (non-symlink) entry already
in your skills directory.

Prefer not to symlink? Just copy the skill folder you want into `~/.claude/skills/`
manually — each folder is self-contained.

Custom skills directory:

```bash
CLAUDE_SKILLS_DIR=/some/other/path ./link-skills.sh
```

## Notes

- **`jira-release`** is configuration-driven: it reads `JIRA_PROJECT_KEY` and
  `JIRA_BASE_URL` from your project's `CLAUDE.md` (or asks for them at runtime).
  Nothing is hardcoded — point it at your own Jira instance.
- These skills follow [Gitflow](https://nvie.com/posts/a-successful-git-branching-model/)
  and [Conventional Commits](https://www.conventionalcommits.org/) conventions. Adapt
  them to your own workflow as needed.

## License

Use them, fork them, adapt them. No warranty — these are tools I built for my own
workflow and share as-is.
