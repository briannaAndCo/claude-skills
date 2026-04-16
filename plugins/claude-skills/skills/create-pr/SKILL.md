---
name: create-pr
description: This skill should be used when the user asks to "create a PR", "open a PR", "make a pull request", "submit a PR", "raise a PR", or "push a PR". Creates a draft pull request with a clear title, AC mapping, and CI monitoring.
version: 2.1.0
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(gh *), Bash(bash *)
---

# Create PR

Creates a draft pull request, presents it for user approval, then monitors CI checks until they pass or fail.

---

## Step 1: Pre-flight Checks

Run these in parallel:

```bash
git status
```

```bash
git branch --show-current
```

```bash
git log main..HEAD --oneline
```

```bash
gh pr view --json number,title,url,state 2>/dev/null
```

Evaluate:

1. **Not on main/master.** If on main, stop and ask the user which branch to create.
2. **Commits exist ahead of base.** If `git log main..HEAD` is empty, stop — nothing to PR.
3. **Uncommitted changes.** If dirty, ask the user if they want to commit first.
4. **PR already exists.** If `gh pr view` succeeds, skip to **Step 7: Monitor CI**.
5. **Suggest verify.** If the diff is non-trivial (>50 lines changed) and a stream plan with AC exists, ask: "Have you run `/verify`? (y / run it now / skip)". If the user says "run it now", invoke the **verify** skill and return to create-pr after it completes.

---

## Step 2: Gather Context

Run in parallel:

```bash
git diff main..HEAD --stat
```

```bash
git log main..HEAD --oneline
```

```bash
git diff main..HEAD
```

Also:

- **Read the stream plan / acceptance criteria.** Check the branch name for a stream reference (e.g. `stream/<name>`) and read its plan from the **meta repo** (separate from this work repo): `git -C <meta-repo-path> show meta/<project>:streams/<name>/plan.md`. Resolve `<meta-repo-path>` from `~/.claude/projects-registry.json`. If no stream plan exists, check for linked issues via branch name patterns (e.g. `feat/PROJ-123-description`).
- **Detect PR template.** Check these locations in order, use the first found:
  - `.github/PULL_REQUEST_TEMPLATE.md`
  - `.github/pull_request_template.md`
  - `docs/pull_request_template.md`
  - `.github/PULL_REQUEST_TEMPLATE/` (list files, ask user to pick if multiple)

---

## Step 3: Extract Ticket Number and Verify Branch Name

Look for a ticket/issue reference in:

- The branch name (e.g. `Task/24997-description`)
- Commit messages
- Stream plan metadata

**Branch naming convention:** Branches must follow `Task/<ticket-number>-<short-description>` (e.g. `Task/24997-correct-hazardous-weighout-equipment-type`). If the current branch does not follow this pattern and a ticket number is known, rename it before pushing:

```bash
git branch -m Task/<ticket>-<short-description>
```

Include the ticket number in the PR title.

---

## Step 4: Generate Title and Body

### Title

- Format: `type(TICKET): short description` — conventional commit style with ticket number in parens
- Use `fix` for bug fixes, `feat` for features, `refactor`, `test`, `chore` as appropriate
- Plain English — someone scanning a PR list should instantly understand what this does
- Under 70 characters
- Examples: `fix(24997): change hazardous weigh-out calibration from table scale to balance`, `feat(1234): add session expiry to auth middleware`

### Body

Use the detected repo template if available. Otherwise use this format:

```markdown
[AB#TICKET](https://dev.azure.com/bluechew/43b9d627-4b35-4ca4-aa5e-218bbbcd9461/_workitems/edit/TICKET)

## Summary
- 1-3 concise bullet points: what this does and why

## Acceptance criteria
- [ ] Map each AC item from the stream plan to what was implemented
- [ ] Note any AC items deferred or partially done
- (Omit section if no stream plan / AC exists)

## Changes
- High-level summary of impact areas — what parts of the system were touched and why, not a file-by-file list. Think: "what would a reviewer need to know to understand the scope?"

## Test plan
- How to verify this works

## Notes
- Call out anything unusual, non-standard, or surprising
- Workarounds, tech debt, deviations from typical patterns
- Omit this section entirely if nothing notable
```

**Writing style:** Be concise. No filler. Every line should earn its place. Reviewers should be able to skim the PR in 30 seconds and understand the scope and risk.

**Scope check:** If the diff is large (>500 lines changed), note this and suggest splitting if appropriate.

---

## Step 5: Present for User Review

Before creating anything, display the full proposed title and body:

```
── Proposed PR ──────────────────────────
Title: [TICKET-123] Clear description here

Body:
<full markdown body>
─────────────────────────────────────────
```

Ask: **"Look good? Edit anything? (y / edit instructions / n)"**

- If the user approves: proceed to create
- If the user gives edit instructions: revise and re-present
- If the user says no: stop

**Do not create the PR without user approval.**

---

## Step 6: Push and Create

```bash
git push -u origin HEAD
```

```bash
gh pr create --draft --title "<title>" --body "<body>" --base main
```

The `--draft` flag is **mandatory** — never create a non-draft PR.

Display the PR URL to the user.

---

## Step 7: Monitor CI Checks

After creating (or finding an existing) PR:

1. Wait 15 seconds for checks to register, then:

```bash
gh pr checks --watch --fail-fast
```

2. **If checks pass:** Report success. Ask the user if they'd like to mark the PR as ready for review (`gh pr ready`).

3. **If checks fail:**
   - Run `gh pr checks` to identify which failed
   - For each failed check, fetch the log: `gh run view <run-id> --log-failed`
   - Present a summary of failures with actionable context
   - Ask the user if they want to fix the issues now

---

## Important Rules

- ALWAYS use `--draft`. No exceptions.
- NEVER force-push without explicit user approval.
- NEVER create the PR without showing the user the title and body first.
- If the base branch is ambiguous, ask — don't guess.
- **No ticket numbers in code comments.** If any uncommitted changes contain ticket references (e.g. `AB#12345`) in source code comments, flag them and ask the user to remove before pushing.
- **Files to never stage.** When operating in a work repo, never `git add` these paths — they are local-only and must not be committed or gitignored:
  - `CLAUDE.md`, `claude_docs/`, `.worktrees/`, `doc/architecture.md`
  - Git hook files (`.git/hooks/` — already untracked, but never copy them into the tree)
  - If you must use `git add -A` or `git add .`, exclude them: `git add -A -- ':!CLAUDE.md' ':!claude_docs' ':!.worktrees' ':!doc/architecture.md'`
