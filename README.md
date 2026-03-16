# claude-skills

A collection of custom [Claude Code](https://claude.ai/claude-code) skills by briannaAndCo.

## Install

```
claude plugin marketplace add briannaAndCo/claude-skills
claude plugin install claude-skills@briannaandco-skills
```

## Structure

```
claude-skills/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace manifest
└── plugins/
    └── claude-skills/
        ├── .claude-plugin/
        │   └── plugin.json       # Plugin metadata
        └── skills/
            └── <skill-name>/
                └── SKILL.md      # Skill definition
```

## Skills

| Skill | Description |
|-------|-------------|
| `project-manager` | Manage projects and streams with session logging and time tracking |

## Adding a Skill

1. Create a directory under `plugins/claude-skills/skills/`
2. Add a `SKILL.md`:

```yaml
---
name: your-skill-name
description: This skill should be used when the user asks to "...", mentions "...", or discusses ...
version: 1.0.0
---

# Your Skill Title
```
