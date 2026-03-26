# File Formats

All planning files live on the `meta` orphan branch of the project's git repo.

## Project Level

### `project.json` — Machine-Readable Manifest

Scripts read this file directly — no markdown parsing needed. Created by `create-project`, updated by any skill that changes project or stream state.

```json
{
  "name": "project-name",
  "created": "2026-03-26",
  "repo": "git@github.com:org/repo.git",
  "objective": "One paragraph describing the project goal",
  "streams": {
    "stream-name-1": {
      "status": "unblocked",
      "type": "feature",
      "blockedBy": [],
      "description": "Brief description"
    },
    "stream-name-2": {
      "status": "blocked",
      "type": "bug",
      "blockedBy": ["stream-name-1"],
      "description": "Brief description"
    }
  }
}
```

**Stream types:** `feature` | `bug` | `refactor` | `research` | `ops` | `docs`

**Keeping in sync:** Any skill that updates `plan.md` streams table MUST also update `project.json`. The scripts directory provides `pm-sync-json.sh` to regenerate `project.json` from `plan.md` if they drift.

---

### `plan.md` — Master Plan

```markdown
# Plan: <project-name>
> Repository: <repo-url>

## Objective
<one paragraph describing the project goal>

## Streams

| Stream | Status | Type | Blocked By | Notes |
|--------|--------|------|------------|-------|
| stream-name-1 | unblocked | feature | — | Brief description |
| stream-name-2 | blocked | bug | stream-name-1 | Brief description |
| stream-name-3 | planned | research | — | Brief description |

## Notes
<any additional context>
```

The `> Repository:` line is optional — only present if a remote URL was provided.

Valid statuses: `planned` | `unblocked` | `in-progress` | `blocked` | `complete` | `on-hold`

Valid types: `feature` | `bug` | `refactor` | `research` | `ops` | `docs`

---

### `session.md` — Project Session Log

```markdown
# Sessions: <project-name>

## 2026-03-16

### Session 10:00 – 11:30 (1h 30m)
- **Streams**: stream-name-1
- **Summary**: <what was done>

### Session 14:00 – 15:15 (1h 15m)
- **Streams**: stream-name-2
- **Summary**: <what was done>
```

---

### `tasks.md` — Project Task Log

```markdown
# Tasks: <project-name>

| Date | Stream | Task | Duration |
|------|--------|------|----------|
| 2026-03-16 | stream-name-1 | Set up auth scaffolding | 1h 30m |
| 2026-03-16 | stream-name-2 | Reviewed API design | 1h 15m |

## Totals by Stream

| Stream | Total Hours |
|--------|-------------|
| stream-name-1 | 1h 30m |
| stream-name-2 | 1h 15m |

**Project Total**: 2h 45m
```

---

## Stream Level

### `streams/<stream-name>/plan.md` — Stream Plan

```markdown
# Plan: <stream-name>
> Type: <feature|bug|refactor|research|ops|docs>

## Objective
<what this stream delivers>

## Tasks
- [ ] Task one
- [ ] Task two
- [x] Completed task

## Acceptance Criteria
- Criterion one
- Criterion two

## Notes
<any context, links, decisions>
```

The `> Type:` line tells scripts and the tmux status bar which color/icon to use without keyword guessing. Defaults to `feature` if omitted.

---

### `streams/<stream-name>/session.md` — Stream Session Log

```markdown
# Sessions: <stream-name>

## 2026-03-16

### Session 10:00 – 11:30 (1h 30m)
<notes on what was worked on>

### Session 14:00 – 14:45 (0h 45m)
<notes on what was worked on>
```

---

### `streams/<stream-name>/hours.md` — Stream Hours Log

```markdown
# Hours: <stream-name>

| Date | Duration | Notes |
|------|----------|-------|
| 2026-03-16 | 1h 30m | Set up auth scaffolding |
| 2026-03-16 | 0h 45m | Reviewed middleware |

**Total**: 2h 15m
```

When appending entries, always recalculate and update the **Total** line.
