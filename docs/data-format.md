# sport-life data format (v1)

One JSON file used for both **import** and **export**. Export writes everything; import is
idempotent — records are matched by `id`, so re-importing the same file changes nothing.

```json
{
  "format": "sport-life",
  "version": 1,
  "exportedAt": "2026-10-07T19:00:00+00:00",
  "exercises": [ Exercise ],
  "workouts":  [ Workout ]
}
```

## Exercise

| field | type | meaning |
|---|---|---|
| `id` | string | stable id (slug or UUID) |
| `name` | string | display name; renaming changes it for all history |
| `aliases` | string[] | other names: search matches them; merged exercises' names land here |
| `metrics` | string[] | which values a set has: `weight`, `reps`, `duration`, `intensity`, `distance`, `speed` |
| `units` | object | per metric, e.g. `{"weight": "kg", "duration": "min"}` |
| `lessIsBetter` | bool | lower primary value = progress (assist machines) |
| `weightIsAdded` | bool | `weight` is extra load on top of bodyweight; `0` = bodyweight only |
| `handles` | int | `weight` is per handle/stack (`2` for "(2x4,8)") |
| `note` | string? | free text |

## Workout

| field | type | meaning |
|---|---|---|
| `id` | string | stable id |
| `date` | `YYYY-MM-DD` | training day |
| `startedAt` / `finishedAt` | ISO datetime? | present for workouts logged live in the app |
| `label` | string? | optional name; never used to identify a program |
| `note` | string? | free text |
| `entries` | Entry[] | in the order performed |

## Entry (one exercise within a workout)

| field | type | meaning |
|---|---|---|
| `exercise` | string | exercise `id` |
| `variant` | string? | attachment / program, e.g. `малый гриф`, `Fat` |
| `hint` | `"up"` \| `"down"` \| null | "try harder / lighter next time" |
| `note` | string? | free text |
| `sets` | Set[] | in order |
| `originalName` | string? | name the exercise was logged under, when it differs from the exercise's current name (set by merges; enables un-merge) |
| `source` | string? | original text (Markdown import only); kept for traceability |

## Set

Only the keys listed in the exercise's `metrics` are used, plus:

- `drop: true` — this set continues the previous one with a lighter weight (a split set:
  `1 х 6 по 27 + 1 х 6 по 18`).
- `done: false` — planned but not performed (only in exports of an unfinished workout).

```json
{"reps": 12, "weight": 27.3}
{"reps": 6, "weight": 18, "drop": true}
{"duration": 5, "intensity": 8}
```

Numbers are plain JSON numbers (decimal point); the app displays them with the locale's
decimal separator.
