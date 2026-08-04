# Exercise Catalog V1 — Implementation and Handoff Plan

Status: approved product direction; implementation has not started.

Last updated: 2026-08-04.

This is the canonical cross-repository plan for rebuilding the exercise catalog
used by Lactic Studio, Lactic Web, and future Lactic mobile applications. Read
the root `AGENTS.md` in each affected repository before making changes.

## 1. Objective

Replace the manually seeded exercise catalog with an automatically synchronized
catalog that:

- requires no routine manual exercise creation or maintenance;
- contains a real animated GIF demonstration for every provider exercise;
- supports English and Italian;
- is searchable and assignable by coaches in Lactic Studio/Web;
- can be consumed through the Lactic API by future mobile clients;
- preserves coach-owned custom exercises;
- does not expose third-party API credentials to browsers or mobile binaries.

The existing catalog and current product data may be reset. There is no
requirement to match old seeded exercises to new provider exercises or preserve
legacy exercise IDs. Resolve and document the exact production deletion scope
before executing the destructive migration.

## 2. Approved Product Decisions

1. Animated demonstrations are a hard v1 requirement. A start image plus an end
   image is not sufficient.
2. The required initial animation format is GIF, not video.
3. WorkoutX is the selected provider, subject to the provider verification gate
   in section 5.
4. Use WorkoutX Free only for an integration spike. The expected production
   plan is WorkoutX Ultra because it includes the incremental dataset changes
   endpoint. Pricing and plan capabilities must be rechecked immediately before
   purchase.
5. Lactic stores normalized exercise metadata in PostgreSQL. Web and mobile
   clients query only the Lactic API for exercise metadata.
6. English provider content is stored locally. Italian machine translations are
   generated during synchronization and stored locally; translation is never
   performed during a user request.
7. Lactic does not initially rehost WorkoutX GIFs. Rails authenticates to
   WorkoutX and streams animations through a Lactic endpoint.
8. Never expose `WORKOUTX_API_KEY` in Next.js public configuration, browser
   JavaScript, URLs, logs, or a mobile application binary.
9. The media domain model must use the generic kind `animation`; do not couple
   the database or API contract to a property named `gif_url`.
10. Coach-owned custom exercises remain supported and are never overwritten by
    a provider sync.
11. Work proceeds one stage at a time. Complete and review the acceptance
    criteria for one stage before beginning the next stage.

## 3. Why WorkoutX

WorkoutX currently advertises more than 1,400 exercises with GIF animations,
stable IDs, instructions, target and secondary muscles, equipment, difficulty,
mechanics, force, and related metadata.

Useful official references:

- Documentation: <https://www.workoutxapp.com/docs.html>
- Terms: <https://workoutxapp.com/terms.html>
- Product and pricing: <https://workoutxapp.com/>

Alternatives were rejected for v1 for the following reasons:

- Free Exercise DB: strong open-data foundation, but it supplies two static
  JPEGs rather than animations.
- ExerciseGymGifsDB: GIF ownership and commercial reuse rights are not clear
  enough for a product.
- ExerciseDB/AscendAPI: technically attractive free GIF API, but commercial
  display, caching, media provenance, and durable usage rights were not stated
  clearly enough in the material reviewed.
- MuscleWiki: primarily video, paid multilingual access, and restrictive media
  caching/storage rules.
- wger: open and structured, but animation and Italian coverage do not satisfy
  the v1 requirements.

WorkoutX does not currently provide Italian. Lactic owns the Italian
translation layer.

## 4. Target Architecture

```text
Scheduled catalog job
        |
        | WorkoutX API key (server only)
        v
WorkoutX metadata API -----> Provider adapter and validation
                                      |
                                      v
                             Lactic PostgreSQL
                              |             |
                              |             +-- English/Italian translations
                              +-- normalized catalog and provider media reference

Web / iOS client
        |
        | Lactic JWT
        v
Lactic API -----------------> localized metadata response
        |
        +--------------------> authenticated animation endpoint
                                      |
                                      | WorkoutX API key (server only)
                                      v
                                  WorkoutX GIF
                                      |
                                      v
                              streamed to the client
```

Clients must not call WorkoutX directly. A live request to the documented GIF
endpoint returned HTTP `401` without a provider API key on 2026-08-04. Supplying
that key from a browser or mobile application would disclose it.

Do not redirect a client to a WorkoutX URL containing the key as a query
parameter. Rails must make the upstream request itself and stream the response.

## 5. Provider Verification Gate — Stage 0

Before schema or UI implementation, obtain a WorkoutX API key and validate a
small representative sample. Do not buy or deploy a production plan until these
questions are answered from current terms or in writing by WorkoutX:

- May Lactic commercially display GIFs to authenticated web and mobile users
  through a server-side streaming proxy?
- May Lactic persist the complete metadata needed by its application?
- May Lactic persist machine-translated Italian derivatives of names,
  descriptions, and instructions?
- What browser/device caching headers may the Lactic proxy return?
- Does every exercise available to the production plan have a GIF?
- Are paid-plan GIFs free of watermarks?
- Does each GIF request count against the monthly request quota, a separate
  unique-GIF quota, or both?
- Is attribution required in the application?
- What happens to stored metadata and existing program references if the
  subscription ends?

Also measure:

- actual exercise count;
- percentage with non-empty instructions, muscles, equipment, and GIF;
- GIF status, MIME type, dimensions, median and upper-percentile file sizes;
- stable-ID behavior;
- pagination behavior and quota headers;
- error and timeout behavior;
- response shape of the Ultra `/v1/exercises/changes` endpoint.

Create a checked-in fixture containing a few sanitized API responses. Never put
the API key in a fixture, cassette, source file, or test output.

### Stage 0 acceptance criteria

- Commercial proxy delivery and local metadata/translation storage are allowed.
- A representative GIF can be streamed without exposing the provider key.
- The provider sample maps cleanly to the proposed domain model.
- Rate limits and expected production cost are documented.
- Any field or plan discrepancy is resolved before Stage 1.

Stop and report the result before continuing.

## 6. Proposed Backend Domain Model — Stage 1

The names below are the intended shape, not a requirement to reproduce every
column literally. Prefer conventional Rails names and database constraints.

### `exercises`

- `id`: stable Lactic primary key.
- `coach_id`: set only for a coach-owned custom exercise.
- `is_custom`: distinguishes custom content from provider catalog content.
- `source`: for example `workoutx`; null for custom exercises.
- `source_uid`: stable provider identifier; null for custom exercises.
- `category`, `difficulty`, `mechanic`, `force`.
- `prescription_type`: initially `repetitions`; reserved for future timed or
  distance-based exercises.
- `active`: provider record is still available.
- `assignable`: record passes Lactic quality and product gates.
- `content_checksum`: detects provider content changes.
- `source_updated_at`, `last_synced_at`.

Required constraints should include:

- unique provider identity on `[source, source_uid]` when not custom;
- custom exercises require a coach;
- provider exercises must not have a coach;
- only active, assignable catalog exercises appear in a new assignment picker.

### `exercise_translations`

- `exercise_id`.
- `locale`: initially `en` or `it`.
- `name`.
- `description` if present upstream.
- `instructions`: JSON array or another ordered representation.
- `translation_source`: `provider`, `machine`, or `human`.
- `source_checksum`: checksum of the English content that was translated.
- `reviewed_at`: optional marker for future human review.
- timestamps.

Use a unique constraint on `[exercise_id, locale]`. A human-reviewed Italian
translation must not be overwritten automatically unless explicitly requested.

### Muscles and equipment

The current singular `exercises.muscle_group` is insufficient.

- `muscles` with a normalized stable key.
- `exercise_muscles` with a role such as `primary` or `secondary`.
- `equipment` with a normalized stable key.
- join table between exercises and equipment.

For v1 planning metrics, count sets against one primary muscle to avoid double
counting. Secondary muscles are available for display and search.

### `exercise_media`

- `exercise_id`.
- `kind`: initially `animation`; leave room for `image` and `video`.
- `mime_type`: initially `image/gif`.
- `provider_url` or provider media identifier.
- `position`.
- optional width, height, byte size, checksum, attribution, and license fields.
- timestamps.

Do not return the provider URL to clients. Serialize a Lactic animation endpoint.

### `catalog_sync_runs`

Record source, start/end times, status, counts for fetched/created/updated/
deactivated/rejected items, and a redacted error summary. Never log secrets or
full upstream headers.

### Stage 1 acceptance criteria

- Migrations, models, constraints, fixtures, and model tests pass.
- Custom exercise validations still work.
- Provider and custom records coexist without ambiguous ownership.
- Locale fallback rules are covered by tests.
- No production data is deleted during this stage.

Stop and report the result before continuing.

## 7. English Importer and Synchronization — Stage 2

Implement a provider boundary such as:

```text
Catalog::Providers::WorkoutX
Catalog::Sync
Catalog::NormalizeExercise
```

The rest of the Rails application must not depend on WorkoutX field names.

The importer should:

1. Fetch a page or incremental changes using server-side credentials.
2. Validate required fields and the presence of a GIF reference.
3. Normalize taxonomy and trim unsafe/invalid content.
4. Compute a deterministic English content checksum.
5. Upsert using `[source, source_uid]`.
6. Upsert the English translation and media reference.
7. Quarantine malformed rows instead of partially importing them.
8. Record counters and errors in `catalog_sync_runs`.
9. Mark missing provider records inactive only after a successful authoritative
   full reconciliation; never hard-delete records during an ordinary sync.
10. Never modify custom exercises.

Add retry with bounded exponential backoff for timeouts and transient `429`/5xx
responses. Fail safely on authentication, schema, or quota errors.

Use a scheduled Railway job or an equivalent Rails task for production sync.
Do not configure the schedule or production credential until the importer is
verified locally with fixtures and the provider spike.

### Stage 2 acceptance criteria

- Initial import and idempotent repeat import pass.
- Changed upstream records update without changing Lactic IDs.
- Malformed records are rejected and reported.
- Custom records remain untouched.
- Sync tests use fixtures/stubs rather than the live provider.

Stop and report the result before continuing.

## 8. Italian Translation Pipeline — Stage 3

The default recommendation is Google Cloud Translation, subject to a fresh
pricing and terms check before configuration. Hide the implementation behind a
translation adapter so another provider can replace it.

Rules:

- translate during catalog synchronization, never during API reads;
- translate name, description, and each ordered instruction;
- maintain a fitness glossary for common muscle and equipment terminology;
- regenerate Italian only when the English checksum changes;
- preserve human-reviewed translations;
- store translation provenance and source checksum;
- fall back to English if Italian is unavailable or a translation fails;
- batch requests within provider limits and record costs/counts without content
  or secrets that should not be logged.

### Stage 3 acceptance criteria

- Italian is generated and persisted for a representative fixture set.
- Repeating an unchanged sync incurs no translation call.
- Changed English regenerates unreviewed Italian.
- Reviewed Italian is protected.
- English fallback is deterministic and tested.

Stop and report the result before continuing.

## 9. Authenticated GIF Proxy — Stage 4

Add a Lactic endpoint along the lines of:

```http
GET /api/v1/exercises/:id/animation
Authorization: Bearer <lactic-access-token>
```

Exact routing may remain role-specific if that fits the existing authorization
structure, but avoid duplicating the upstream fetch implementation.

The endpoint must:

- require a valid Lactic user;
- authorize access to the exercise;
- resolve only approved provider media records;
- add `WORKOUTX_API_KEY` server-side;
- enforce connect/read timeouts and a maximum response size;
- accept only the expected successful status and GIF content type;
- stream bytes without buffering an unbounded response;
- never expose the provider key or authenticated upstream URL;
- translate provider failures into a stable Lactic error/placeholder behavior;
- use conservative client caching allowed by the provider agreement;
- include request instrumentation without logging secrets.

For the web application, a normal `<img src>` cannot attach the current JWT
authorization header. The initial implementation should fetch the animation as
an authenticated blob and create an object URL, with cleanup on unmount. A later
alternative is a short-lived, narrowly scoped signed Lactic media URL.

iOS can request the same endpoint with `URLSession` and the Lactic bearer token.

Do not load every GIF in a catalog grid. Lists should use lazy loading or a
lightweight placeholder and fetch animation only for a visible/selected preview.

### Stage 4 acceptance criteria

- An authenticated coach/client can render a real animation.
- An unauthenticated request is rejected.
- The WorkoutX key is absent from client responses, redirects, logs, and bundles.
- Timeout, invalid content type, oversized response, `401`, `429`, and upstream
  5xx cases are tested.
- The frontend cleans up blob URLs and does not eagerly fetch the whole catalog.

Stop and report the result before continuing.

## 10. Localized Exercise API — Stage 5

Update coach and client exercise endpoints to return the Lactic domain contract,
not provider fields. Resolve locale from the authenticated user preference when
available, otherwise `Accept-Language`, with English fallback.

Expected capabilities:

- pagination;
- localized name, description, and instructions;
- search across English and Italian regardless of response locale;
- primary/secondary muscle filters;
- equipment, category, difficulty, and custom/catalog filters;
- `animation_url` pointing to Lactic, not WorkoutX;
- active/assignable catalog filtering;
- coach-owned custom exercises visible only to their coach and associated use
  cases.

Avoid returning hundreds of full instruction arrays in a list response if a
summary representation plus detail endpoint is sufficient.

### Stage 5 acceptance criteria

- English/Italian localization and fallback pass request tests.
- Search works with both languages.
- Pagination and all selected filters are tested.
- Existing program/workout serializers use the new stable exercise contract.

Stop and report the result before continuing.

## 11. Lactic Studio Web UI — Stage 6

Affected repository: `lactic-web`.

Replace hard-coded single-muscle filters and the current flat exercise list with
a paginated/lazy catalog suitable for more than 1,400 records.

V1 coach experience should include:

- localized search;
- filters for primary muscle, equipment, category, and difficulty;
- a clear distinction between catalog and coach-owned custom exercises;
- selected exercise detail/preview with animated GIF;
- loading, empty, provider-animation failure, and retry states;
- accessible controls and reduced unnecessary animation loading;
- existing create/edit/delete behavior for custom exercises;
- exercise selection within the program builder.

Run `pnpm lint` and `pnpm build` before handing off this stage.

### Stage 6 acceptance criteria

- Catalog and custom exercise flows work for a coach.
- Exercise selection still creates valid workout exercises.
- Animation is loaded on demand through Lactic authentication.
- Italian and English UI/API content render correctly.
- Lint and production build pass.

Stop and report the result before continuing.

## 12. Reset, Deployment, and Verification — Stage 7

The owner has approved starting fresh instead of preserving legacy exercise
data. Before executing any production reset:

1. Inspect foreign-key dependencies and report exactly which tables/records will
   be deleted.
2. Take or verify a recoverable database backup/snapshot.
3. Confirm that the target is the explicit Railway production project,
   environment, and service from `AGENTS.md`.
4. Prefer a dedicated, idempotent Rails task over ad hoc SQL.
5. Seed/import the provider catalog and verify counts before enabling the new UI.

Deploy API first, then web. Follow the deployment verification rules in
`AGENTS.md`: Railway must reach `SUCCESS`, `/up` must return HTTP 200, Vercel must
reach `READY`, and a real production route must return HTTP 200.

Required final checks include:

- provider sync success and recorded counts;
- no secret in API JSON, frontend bundle, source maps, or logs;
- authenticated animation playback in production;
- English and Italian exercise responses;
- coach custom exercise CRUD;
- program builder assignment using a provider exercise;
- client retrieval of an assigned exercise;
- acceptable GIF latency and quota behavior;
- documented rollback procedure.

## 13. Environment Variables

Expected names only; never commit values:

- `WORKOUTX_API_KEY`
- translation-provider credentials selected in Stage 3
- optional catalog-sync scheduling/authentication variables

Store backend-only secrets in Railway. No WorkoutX or translation secret belongs
in Vercel `NEXT_PUBLIC_*` variables.

## 14. Current Implementation Touchpoints

Backend currently uses a flat model and must be migrated:

- `db/schema.rb`: `exercises` currently has `name`, `muscle_group`,
  `thumbnail_url`, `video_url`, `is_custom`, and `coach_id`.
- `app/models/exercise.rb`: validates one name and muscle group and owns
  `workout_exercises` with dependent destruction.
- `app/controllers/api/v1/coach/exercises_controller.rb`: filters one
  `muscle_group` and searches the single English `name`.
- `app/controllers/api/v1/client/exercises_controller.rb`.
- `app/blueprints/exercise_blueprint.rb`: exposes the current flat fields.
- `db/seeds.rb`: contains the legacy seeded catalog.
- `workout_exercises.exercise_id`: must point to the new stable Lactic exercise
  IDs after the approved reset.

Frontend touchpoints are under the coach exercise routes and the program-builder
exercise picker in `lactic-web`. Locate the exact files again before editing;
the frontend may evolve independently of this document.

## 15. Handoff Protocol

An agent taking over should:

1. Read this entire document and the relevant root/nested `AGENTS.md` files.
2. Check both repositories' status and create clean `codex/*` branches from the
   latest `main`; do not stack feature work on documentation branches.
3. State which numbered stage is being executed.
4. Do only that stage and its tests.
5. Report decisions, discrepancies, migrations, test output, and unresolved
   risks before beginning the next stage.
6. Update this document when an approved decision changes.
7. Update the identical cross-repository `AGENTS.md` files only as functionality
   becomes implemented, not merely planned.
8. Never commit secrets or destructive production commands with unresolved
   targets.

The immediate next action is **Stage 0: Provider Verification Gate**. No schema,
importer, translation, UI, reset, or deployment work should begin until Stage 0
has been reviewed.
