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
| `error_unauthenticated_401.json` | Live `GET /v1/exercises?limit=2` with no credentials, 2026-08-04 | "fail safely on authentication error" path |
| `error_invalid_key_401.json` | Live `GET /v1/exercises?limit=2` with `X-WorkoutX-Key: wx_invalid_probe_key`, 2026-08-04 | Distinguishes *missing* key from *rejected* key |
| `response_headers_401.txt` | Response headers from the same two calls | Quota/rate-limit header names for `catalog_sync_runs` instrumentation |

## What is deliberately missing

Every **authenticated** fixture. Capturing a successful `/v1/exercises` page, a
single-exercise response, a `/v1/exercises/changes` payload, or GIF response
headers requires a provider API key, which Lactic does not yet hold. Stage 0 is
blocked on that key and on the vendor answers tracked in
`docs/workoutx_vendor_questions.md`.

Do not write speculative "expected shape" fixtures by hand. A fabricated
fixture would make Stage 2 tests pass against a contract nobody has verified,
which is the specific failure Stage 0 exists to prevent.
