# File Formats

## Project Level

### `plan.md` — Master Plan

```markdown
# Plan: <project-name>

## Objective
<one paragraph describing the project goal>

## Streams

| Stream | Status | Blocked By | Notes |
|--------|--------|------------|-------|
| stream-name-1 | unblocked | — | Brief description |
| stream-name-2 | blocked | stream-name-1 | Brief description |
| stream-name-3 | planned | — | Brief description |

## Notes
<any additional context>
```

Valid statuses: `planned` | `unblocked` | `in-progress` | `blocked` | `complete` | `on-hold`

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
