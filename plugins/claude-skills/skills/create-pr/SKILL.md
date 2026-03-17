---
name: create-pr
description: This skill should be used when the user asks to "create a PR", "open a PR", "make a pull request", "submit a PR", "raise a PR", or "push a PR". Creates a well-structured pull request using Conventional Commits title format and a standard body template.
version: 1.0.0
---

# Create PR

Creates a pull request with a Conventional Commits title and a structured body covering why, what, type, testing, and checklist. Conditionally includes screenshots and breaking change sections based on the diff.

---

## Step 1: Gather Context

Run these in parallel:

```bash
git status
```

```bash
git log main..HEAD --oneline
```

```bash
git diff main..HEAD
```

```bash
cat ~/.claude-projects-config 2>/dev/null || echo '{}'
```

Also read the active stream's `plan.md` if in a project context — it provides the objective and acceptance criteria useful for the PR description.

If the branch is already tracking a remote, check if it's up to date:

```bash
git status -sb
```

---

## Step 2: Analyze the Diff

From the diff, determine:

1. **Change type** — which Conventional Commits type fits best:
   - `feat` — new user-facing feature
   - `fix` — bug fix
   - `refactor` — code change with no behavior change
   - `test` — adding or updating tests
   - `chore` — dependencies, tooling, config
   - `ci` — CI/CD workflows
   - `docs` — documentation only
   - `perf` — performance improvement

2. **Scope** — optional, kebab-case area of the codebase (e.g. `db`, `auth`, `ui`, `types`)

3. **Breaking change** — does the diff contain any of:
   - Removed or renamed exports
   - Changed function signatures
   - Renamed database columns or tables
   - Removed API endpoints or changed response shapes

4. **Has UI changes** — does the diff touch any component, screen, or style file?

5. **Short description** — imperative mood, lowercase, no period. E.g. "add pagination to notes query"

---

## Step 3: Construct the Title

Format: `<type>(<scope>): <description>`

- Include scope only when it meaningfully narrows the change
- Append `!` before the colon for breaking changes: `feat(db)!: rename entries table to notes`
- Keep under 72 characters

Examples:
```
feat(db): add notes schema and WAL pragmas
test(db): add integration tests for notes CRUD
refactor(types): rename Entry to Note, content to text
ci: add GitHub Actions test workflow on PR
```

---

## Step 4: Build the PR Body

Use this template, deleting sections that don't apply:

```markdown
## Why
<!-- What problem does this solve? What's the motivation? Link to issue/ticket if applicable. -->


## What changed
<!-- Concrete summary of what was added, removed, or modified. -->


## Type of change
- [ ] feat — new feature
- [ ] fix — bug fix
- [ ] refactor — no behavior change
- [ ] test — tests only
- [ ] chore — tooling / dependencies
- [ ] ci — CI/CD
- [ ] docs — documentation
- [ ] perf — performance

## How to test
<!-- Step-by-step instructions to verify this works. -->
1.

## Checklist
- [ ] Tests pass locally
- [ ] No unintended files included
- [ ] Self-reviewed the diff

<!-- CONDITIONAL: include only if breaking changes exist -->
## Breaking changes
<!-- What breaks, and how should callers migrate? -->

<!-- CONDITIONAL: include only if UI files changed -->
## Screenshots
<!-- Before / after screenshots for any visual changes -->
```

**Rules for filling in the body:**
- **Why**: derive from the stream objective, commit messages, or the nature of the diff. Be specific — "foundation for all other streams" is better than "made some changes"
- **What changed**: bullet points listing the concrete changes (files, types, behaviors) — not just filenames
- **Type of change**: check all that apply
- **How to test**: include the actual commands (e.g. `npm test`) plus any manual steps
- **Checklist**: check items that are genuinely satisfied based on the diff
- **Breaking changes**: include and fill in only if a breaking change was detected in Step 2
- **Screenshots**: include only if UI files were changed — otherwise remove the section entirely

---

## Step 5: Push and Create the PR

If the branch has no remote tracking branch yet:

```bash
git push -u origin <branch-name>
```

Then create the PR:

```bash
gh pr create \
  --title "<title>" \
  --body "<body>" \
  --base main \
  --draft
```

Return the PR URL to the user.

---

## Step 6: Confirm

Show the user:
- The PR title
- The PR URL
- A one-line summary of what was included/excluded from the body (e.g. "no breaking changes section, no screenshots")
