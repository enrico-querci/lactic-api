# WorkoutX provider fixtures

Sanitized WorkoutX API responses for use in tests. Added during **Stage 0**
(provider verification gate) of `docs/exercise_catalog_v1_plan.md`.

## Rules

- **Never** commit a real API key here, or anywhere else in this repository.
  The only key-shaped string in these fixtures is the deliberately invalid
  placeholder `wx_invalid_probe_key`.
- Volatile headers (`date`, `etag`, `x-railway-request-id`, `x-hikari-trace`,
  `x-railway-edge`) are stripped so fixtures stay stable across runs.
- Capture new fixtures with `bin/rails workoutx:probe` (see
  `lib/tasks/workoutx_probe.rake`), which redacts the key before writing.

## What is here

| File | Provenance | Stage 2 use |
| --- | --- | --- |
| `exercises_sample.json` | Live authenticated `GET /v1/exercises`, free plan, 2026-08-05. First three records | **The importer contract.** Real field names, casing, types, and ID format |
| `error_unauthenticated_401.json` | Live `GET /v1/exercises?limit=2` with no credentials, 2026-08-04 | "fail safely on authentication error" path |
| `error_invalid_key_401.json` | Live `GET /v1/exercises?limit=2` with `X-WorkoutX-Key: wx_invalid_probe_key`, 2026-08-04 | Distinguishes *missing* key from *rejected* key |
| `response_headers_401.txt` | Response headers from the same two calls | Quota/rate-limit header names for `catalog_sync_runs` instrumentation |

`exercises_sample.json` holds the bare records only. The live list response
wraps them: `{ "total": 1327, "count": 10, "data": [...] }`. Stage 2 must parse
that envelope, not a bare array.

Things the sample proves that the vendor documentation gets wrong:

- `id` is a **zero-padded, non-sequential string** (`"0001"`), not an integer.
  Never cast it, or `"0001"` collides with `"1"`.
- `equipment` is a **single string**, not a collection.
- `movement_tags` is present on the **free** plan despite being documented as
  Ultra-only.
- There is **no** `updatedAt` or equivalent timestamp on any record.
- `description` is templated from the other fields, not authored prose.

## What is deliberately missing

- **No provider GIF or extracted frame.** Whether Lactic may store provider
  media is an open licensing question
  (`docs/exercise_catalog_v1_stage0_report.md` §1.3). Committing one would
  pre-empt the answer.
- **No `/v1/exercises/changes` payload.** That endpoint returns `403` on the
  free plan; capturing it requires the top tier.
- **No paid-tier GIF metadata.** Free-plan GIFs are 360×360 and heavily
  watermarked, so they do not characterise production media.

Do not write speculative "expected shape" fixtures by hand. A fabricated
fixture would make Stage 2 tests pass against a contract nobody has verified,
which is the specific failure Stage 0 exists to prevent.
