---
name: create-project
description: This skill should be used when the user asks to "create a project", "new project", "init project", "set up a project", "start a new project", "bootstrap project", or "initialize project". Creates a new project by setting up a git repo (or using an existing one) with an orphan meta branch containing structured planning files.
version: 1.1.0
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(mkdir *), Bash(ls *), Bash(cat *), Bash(jq *), Bash(bash *)
---

# Create Project

Creates a new project — a git repo with an orphan `meta/<project-slug>` branch containing planning and tracking files. Code lives on main/feature branches; planning state lives on its own meta branch. Each project gets its own isolated meta branch, so multiple projects can coexist on the same repo.

---

## Flow

### 1. Gather Information

Ask the user for:

1. **Repo path** (required) — where the project lives on disk. Can be an existing repo or a new directory.
2. **Project name** (required) — human-readable name. Derive kebab-case slug from this for internal use.
3. **Objective** (required) — one paragraph describing the project goal.
4. **Initial streams** (optional) — list of streams to scaffold. For each stream ask:
   - Stream name (kebab-case)
   - Brief description
   - Blocked by (other stream names, if any)
5. **GitHub repo URL** (optional) — remote URL for syncing the meta branch.

Ask these conversationally — don't dump a form. Start with repo path and name, then objective, then offer to add streams.

### 2. Initialize Git

If no git repo exists at the given path:

```bash
mkdir -p <repo-path>
git init <repo-path>
```

If a repo already exists, use it as-is.

### 3. Check for Existing Meta Branches

```bash
cd <repo-path>
git branch --list 'meta/*'
```

If existing `meta/*` branches are found, list them to the user:

> "This repo already has projects on meta branches:
> - meta/claude-workflow (from project 'claude-workflow')
>
> Creating a new project alongside them. Proceed?"

**Wait for confirmation.**

### 4. Create the Orphan Meta Branch

The meta branch is named `meta/<project-slug>` where `<project-slug>` is the kebab-case project name.

```bash
cd <repo-path>
ORIGINAL_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
git checkout --orphan meta/<project-slug>
git rm -rf --cached . 2>/dev/null || true
```

### 5. Write Planning Files

Use the **Write tool** (not Bash) to create all planning files in the repo root on the meta branch.

#### `plan.md`

Use the Write tool to create `<repo-path>/plan.md`:

```markdown
# Plan: <project-name>

## Objective
<objective paragraph>

## Streams

| Stream | Status | Type | Blocked By | Notes |
|--------|--------|------|------------|-------|
```

If initial streams were provided, populate the table:
- Streams with no blockers get status `unblocked`
- Streams with blockers get status `blocked`
- Default type is `feature` unless the user specifies otherwise
- Valid types: `feature` | `bug` | `refactor` | `research` | `ops` | `docs`

#### `project.json`

Use the Write tool to create `<repo-path>/project.json` — a machine-readable manifest for scripts:

```json
{
  "name": "<project-name>",
  "created": "<YYYY-MM-DD>",
  "repo": "<repo-url or empty string>",
  "objective": "<objective paragraph>",
  "streams": {}
}
```

If initial streams were provided, populate the `streams` object. See [references/file-formats.md](references/file-formats.md) for the schema.

#### `session.md`

Use the Write tool to create `<repo-path>/session.md`:

```markdown
# Sessions: <project-name>
```

#### `tasks.md`

Use the Write tool to create `<repo-path>/tasks.md`:

```markdown
# Tasks: <project-name>

| Date | Stream | Task | Duration |
|------|--------|------|----------|

## Totals by Stream

| Stream | Total Hours |
|--------|-------------|

**Project Total**: 0h 00m
```

#### Stream files (if initial streams provided)

For each stream, use the Write tool to create:

- `<repo-path>/streams/<stream-name>/plan.md` — stream plan with objective, placeholder AC, empty tasks
- `<repo-path>/streams/<stream-name>/session.md` — empty session log
- `<repo-path>/streams/<stream-name>/hours.md` — empty hours log with 0h total

See [references/file-formats.md](references/file-formats.md) for exact templates.

### 6. Commit and Return

```bash
cd <repo-path>
git add plan.md session.md tasks.md project.json
git add streams/ 2>/dev/null || true
git commit -m "meta: initialize project — <project-name>"
```

Return to original branch or create main. **If this is a new repo** (no original branch), create an initial commit on main so that git worktrees can be created later when streams are opened:

```bash
if [ -n "$ORIGINAL_BRANCH" ]; then
  git checkout "$ORIGINAL_BRANCH"
else
  git checkout --orphan main
  git rm -rf --cached . 2>/dev/null || true
  touch .gitkeep
  echo '.worktrees' > .gitignore
  git add .gitkeep .gitignore
  git commit -m "chore: initial commit"
fi
```

### 7. Configure Remote (if provided)

If the user provided a GitHub repo URL:

```bash
git remote get-url origin 2>/dev/null || git remote add origin <repo-url>
git push -u origin meta/<project-slug>
```

Use the **Edit tool** to add the repo URL to `plan.md` after the project name header:

```markdown
# Plan: <project-name>
> Repository: <repo-url>
```

### 8. Register in Projects Registry

Use the **Read tool** to check if `~/.claude/projects-registry.json` exists. Then use the **Write tool** to create or update it:

```json
{
  "projects": [
    { "path": "<absolute-repo-path>", "name": "<project-name>", "metaBranch": "meta/<project-slug>" }
  ],
  "scanPaths": ["~/projects", "~/repos"]
}
```

If the file exists, read it first, append to the `projects` array (avoid duplicates by path + name), and write back. Note: the same repo path can appear multiple times with different project names and meta branches.

### 9. Confirm

Tell the user:
- Project created at `<repo-path>`
- Meta branch `meta/<project-slug>` initialized with planning files
- Number of streams created (if any)
- Remote configured (if applicable)
- Registered in projects registry

---

## Important Notes

- **Never commit planning files to main or feature branches.** They live exclusively on `meta/<project-slug>`.
- **Never commit code to the meta branch.** It contains only planning/tracking files.
- After returning to main/feature branch, the planning files won't be visible in the working tree — this is correct.
- **Each project gets its own meta branch** — `meta/<project-slug>`. Multiple projects can coexist on the same repo.
- If the repo already has a `meta/<project-slug>` branch with the same slug, warn the user and ask before overwriting.
- The meta branch is an orphan — it shares no history with code branches.
- **Legacy `meta` branches** (without a project slug) should be migrated to `meta/<project-slug>` format. See the migration note below.
- Stream CLAUDE.md files are NOT created at project init. They are generated dynamically when a stream is opened.
- **Use the Write tool for creating files, Edit tool for modifying files, and Read tool for reading files.** Only use Bash for git commands and directory creation.

---

## File Format Reference

See [references/file-formats.md](references/file-formats.md) for exact file templates.
