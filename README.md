# claude-skills

A collection of custom [Claude Code](https://claude.ai/claude-code) skills.

## Structure

```
claude-skills/
├── .claude-plugin/
│   └── plugin.json     # Plugin metadata
└── skills/
    └── <skill-name>/
        └── SKILL.md    # Skill definition
```

## Adding a Skill

1. Create a new directory under `skills/` with your skill name
2. Add a `SKILL.md` file with the following frontmatter:

```yaml
---
name: your-skill-name
description: This skill should be used when the user asks to "...", mentions "...", or discusses ...
version: 1.0.0
---

# Your Skill Title

Describe what this skill does and how Claude should use it.
```

## Using This Plugin

Install via Claude Code:

```
/install-plugin https://github.com/briannaAndCo/claude-skills
```
