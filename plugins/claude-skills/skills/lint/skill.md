---
name: lint
description: Runs eslint and prettier on changed files — either staged files (pre-commit) or files changed since the base branch (review mode). Auto-fixes what it can, reports what it cannot.
version: 1.0.0
allowed-tools: Bash(git *), Bash(bash *), Bash(npx *), Read, Grep
---

# Lint

Runs eslint + prettier on changed files.

---

## Modes

### Default — Staged files
Lints files currently staged for commit. Auto-fixes are re-staged.

If `~/.claude/scripts/lint-changed.sh` exists:

```bash
~/.claude/scripts/lint-changed.sh
```

Otherwise, detect and run lint tools from the project:

```bash
# Check for eslint
npx --no-install eslint --fix <staged-files>
# Check for prettier
npx --no-install prettier --write <staged-files>
```

### Diff mode — Changes since base branch
Lints all files changed between the merge-base and HEAD.

Detect the base branch (check for `main`, `master`, or `develop`):

```bash
LINT_BASE=$(git merge-base HEAD <base>) ~/.claude/scripts/lint-changed.sh
```

Or without the script:

```bash
# Get changed files
git diff --name-only $(git merge-base HEAD <base>)...HEAD | grep -E '\.(ts|tsx|js|jsx)$'
# Run lint on them
npx --no-install eslint --fix <files>
npx --no-install prettier --write <files>
```

---

## Flow

1. **Detect mode.** If there are staged files, default to staged mode. If no staged files but on a feature branch, default to diff mode. Ask if ambiguous.

2. **Run lint** in the appropriate mode.

3. **Report results:**
   - **All clean:** "Lint passed — no issues."
   - **Auto-fixed:** "Lint auto-fixed N files. Review changes with `git diff`."
   - **Unfixable issues:** Show error output and suggest fixes.

4. **If unfixable issues exist**, offer to fix them:
   > "N issues couldn't be auto-fixed. Want me to fix them? (y / show details / skip)"

---

## Important Rules

- **Never skip lint errors.** If lint exits non-zero, something still needs fixing.
- **In staged mode, re-stage auto-fixes** so the commit captures formatted code.
- **In diff mode, auto-fixes modify the working tree** — the user decides what to commit.
