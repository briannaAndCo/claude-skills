# Time Tracking Rules

## Rounding to the Nearest 15 Minutes

All session durations are rounded to the nearest 15-minute increment.

| Raw Duration | Rounded |
|---|---|
| 0–7 min | 0h 00m → treat as 0h 15m (minimum) |
| 8–22 min | 0h 15m |
| 23–37 min | 0h 30m |
| 38–52 min | 0h 45m |
| 53–67 min | 1h 00m |
| 68–82 min | 1h 15m |
| … | … |

**Minimum loggable time**: 0h 15m. Never log 0h 00m.

## Duration Format

Always express durations as `Xh Ym`:
- `0h 15m` (not `15m` or `0.25h`)
- `1h 00m` (not `1h` or `60m`)
- `2h 30m` (not `2.5h`)

## Calculating Totals

When updating `hours.md` totals or `tasks.md` stream totals:
1. Sum all duration entries
2. Convert to total minutes
3. Round to nearest 15 minutes
4. Express as `Xh Ym`

## Session Boundaries

- **Start time**: Recorded when the user says they're starting work
- **End time**: Recorded when the user signals they are done (e.g., "done", "end session", "wrapping up", "stopping for now")
- If the user forgets to end a session and starts a new one, prompt them to confirm or enter the end time for the previous session before starting the new one
