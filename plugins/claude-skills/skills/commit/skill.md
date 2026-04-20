---
name: commit
description: Safe commit workflow — surveys working tree for local noise, stages only intended files, runs lint if available, and creates a clean commit. Never uses git add -A.
version: 1.0.0
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(bash *), Bash(npx *)
---

# Commit

Creates a clean commit with staging hygiene and lint validation. Prevents accidental inclusion of local dev files.

---

## Step 1: Survey the Working Tree

Run in parallel:

```bash
git status --short
```

```bash
git diff --name-only
```

```bash
git diff --cached --name-only
```

```bash
git log -5 --oneline
```

Classify every modified/untracked file into two buckets:

### Intentional changes
Files that are part of the current work.

### Local noise — DO NOT STAGE
Files that are local dev modifications. Common patterns to watch for:

- Environment config files with local server URLs or credentials
- Lock files (`package-lock.json`, `yarn.lock`) unless dependency changes are intentional
- IDE config (`.vscode/`, `.idea/`)
- `.env` files, key files, credentials
- Untracked local scripts or test data

If anything is already staged that looks like local noise, **warn the user** and suggest unstaging it.

---

## Step 2: Present Staging Plan

Show the user what will be staged:

```
── Staging Plan ─────────────────────────
Will stage:
  M  src/components/Widget.tsx
  A  src/components/Widget.test.tsx

Will NOT stage (local noise):
  M  .env.local

Already staged:
  (none)
─────────────────────────────────────────
```

Ask: **"Stage these files? (y / edit list / show diff)"**

- If "show diff" — run `git diff <file>` for each file
- If "edit list" — let the user add/remove files
- If approved — proceed

**Never use `git add .` or `git add -A`.** Always stage specific files by path.

---

## Step 3: Stage Files

```bash
git add <file1> <file2> ...
```

---

## Step 4: Run Lint

If `~/.claude/scripts/lint-changed.sh` exists, run it:

```bash
~/.claude/scripts/lint-changed.sh
```

Otherwise, check if the project has lint configured and run it:
- Look for `eslint` in package.json → `npx eslint --fix <staged-files>`
- Look for `prettier` in package.json → `npx prettier --write <staged-files>`

If no lint tooling is available, skip this step.

- **If lint passes:** proceed to commit
- **If lint fails with unfixable issues:** show errors, ask the user to fix before committing

---

## Step 5: Draft Commit Message

Check recent commit history for style:

```bash
git log -10 --oneline
```

Draft a concise commit message that:
- Describes **what changed and why**
- Matches the repo's existing commit style
- Subject line under 72 chars, optional body for context

Present the draft: **"Commit with this message? (y / edit)"**

---

## Step 6: Create the Commit

```bash
git commit -m "<message>"
```

Show the result:

```bash
git log -1 --oneline
```

---

## Step 7: Post-Commit

- If unstaged local files remain, confirm: "Unstaged local files remain — this is expected."
- If a PR is open for this branch, suggest pushing to update it.

---

## Important Rules

- **NEVER use `git add .` or `git add -A`.** Always stage specific files by name.
- **NEVER stage credentials, keys, or `.env` files.**
- **Always show the staging plan** before staging — the user must approve.
- **Always run lint** if available. If lint fails, the commit does not happen.
- **Match existing commit style** — check recent history.
