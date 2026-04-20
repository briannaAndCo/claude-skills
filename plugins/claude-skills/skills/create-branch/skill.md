---
name: create-branch
description: Creates a feature branch following team naming conventions — optional type prefix, date stamp, kebab-case description. Syncs from base branch before branching.
version: 1.0.0
allowed-tools: Read, Bash(git *)
---

# Create Branch

Creates a new branch following team naming conventions, starting from the correct base branch.

---

## Step 1: Determine Branch Type and Base

Ask the user (or infer from context):

> **What type of change?**
> 1. **Task / Feature** — new feature or planned work
> 2. **Bugfix** — fix for a known bug
> 3. **Hotfix** — urgent production fix

Determine the base branch:
- Check if the repo uses `main` or `develop` as the default integration branch
- Hotfixes typically branch from the production branch (`main` or `master`)
- Everything else branches from the integration branch

---

## Step 2: Get Ticket Reference (Optional)

Ask:

> **Do you have a ticket/issue number?** (Enter number, or press Enter to skip)

---

## Step 3: Build Branch Name

Get a short description from the user (or derive from context):

> **Short description** (kebab-case, 3-5 words):

Format options (adapt to the repo's existing branch naming convention by checking `git branch -r`):
- With type prefix: `Task/<ticket>-<kebab-description>`
- Date-based: `<MMDDYY>-<kebab-description>`
- Simple: `<type>/<kebab-description>`

Check existing remote branches to match the repo's style:

```bash
git branch -r --list 'origin/*' | head -20
```

Present: **"Create branch `<name>` from `<base>`? (y / edit)"**

---

## Step 4: Sync Base and Create Branch

```bash
git fetch origin <base>
git checkout <base>
git pull origin <base>
git checkout -b <branch-name>
```

---

## Step 5: Confirm

```bash
git branch --show-current
git log -1 --oneline
```

Report: "Created branch `<name>` from `<base>`. Ready to start working."

---

## Important Rules

- **Always sync the base branch** before creating the new branch.
- **Match the repo's existing branch naming convention** — check remote branches first.
- **Description is kebab-case** — lowercase, hyphens, no special characters.
