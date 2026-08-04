# Exercise Catalog V1 — Stage 0 Provider Verification Report

Stage: **0 — Provider Verification Gate** (`docs/exercise_catalog_v1_plan.md` §5).

Date: 2026-08-04.

## Verdict: NOT PASSED — do not begin Stage 1

The gate did its job. Stage 0 did not fail for want of an API key; it failed
because publicly verifiable evidence shows that **two approved product
decisions may be incompatible with how WorkoutX actually meters its service**,
and because the vendor's terms grant none of the three permissions that
acceptance criterion #1 requires.

Stage 1 is a schema stage feeding a Stage 7 **destructive production reset**.
Building that schema around a provider that may be unable to satisfy decision #1
is the specific outcome this gate exists to prevent.

Nothing in this report changes an approved decision. Section 6 lists the
decisions now in question and the owner choices in front of them.

---

## 1. Blocking findings

### 1.1 A unique-GIF quota exists, and may cap below the catalog size

Decision #1 makes an animated GIF for **every** provider exercise a hard v1
requirement.

Evidence gathered:

| # | Evidence | Strength |
| --- | --- | --- |
| 1 | A live unauthenticated request to `GET https://api.workoutxapp.com/v1/exercises` returned `access-control-expose-headers` including `X-Unique-GIF-Limit`, `X-Unique-GIF-Used`, `X-Unique-GIF-Remaining` | **Direct** — captured in `test/fixtures/files/workoutx/response_headers_401.txt` |
| 2 | The pricing page describes the Basic plan as including "500 unique exercise GIFs", against an advertised catalog of "1,400+ exercises" | Vendor published |
| 3 | A vendor blog post states "All plans include access to the full exercise metadata; GIF library limits vary by plan" | Vendor published |

**What this proves:** WorkoutX meters unique GIF access as a dimension distinct
from the monthly request quota. Metadata access and GIF access are licensed
separately.

**What this does NOT prove:** the Ultra tier's actual `X-Unique-GIF-Limit`
value. Only the *header names* were observed; no live values were seen, because
that requires an authenticated request. The 500 figure is documented for
**Basic only**. Ultra may well be uncapped.

**Why it blocks:** if Ultra's unique-GIF limit is below the catalog size, then
"a real animated GIF demonstration for every provider exercise" is not
purchasable at any advertised tier, and WorkoutX fails provider selection
outright. This single number decides whether the rest of the plan is viable. It
cannot be obtained without a key or a vendor answer.

### 1.2 Proxy-without-rehosting collides with the monthly request quota

Decision #7 says Lactic does **not** rehost GIFs: Rails authenticates upstream
and streams each animation through a Lactic endpoint.

That makes every client animation view an upstream provider request. Against an
Ultra quota of 35,000 requests/month, a modest amount of coach catalog browsing
consumes the budget — and Stage 4 explicitly serves animations to clients too.
The unique-GIF meter may compound this, depending on whether re-fetching an
already-seen GIF re-counts.

The natural mitigation is to rehost or durably cache GIFs on Lactic
infrastructure. **The terms do not permit that**, and do not forbid it either —
see §1.3. So the mitigation for a quota problem is itself blocked on a vendor
answer.

### 1.3 The terms grant none of the three permissions criterion #1 requires

Acceptance criterion #1: *"Commercial proxy delivery and local
metadata/translation storage are allowed."*

Reviewed `https://workoutxapp.com/terms.html`:

| Permission required by the plan | Terms position |
| --- | --- |
| Persist provider metadata in Lactic's PostgreSQL | **Silent** |
| Store machine-translated Italian derivatives | **Silent** |
| Stream GIFs to authenticated users via a server-side proxy | **Silent** |
| Cache or rehost media, and for how long | **Silent** |
| Attribution in-product | **Silent** |
| Retention of stored metadata after termination | **Silent** |

The only adjacent prohibitions found are "Redistribute the exercise dataset as a
standalone product" and "Share, resell, or redistribute API access without
written permission". Lactic's intended use is arguably neither.

**Silence is not permission.** Criterion #1 requires that these uses *are
allowed*; the terms establish that for none of them. This is not a technical
blocker that a key would clear — it requires written confirmation from WorkoutX.

The termination clause is the sharpest edge: *"Upon termination, your API keys
are revoked and access ceases immediately."* It is silent on locally stored
metadata. If lapsing the subscription obliges Lactic to purge stored exercises,
then **every program built on provider exercises breaks** — after Stage 7 has
already destroyed the legacy catalog. That risk must be resolved in writing
before the destructive migration, not after.

---

## 2. Non-blocking findings that change planning

### 2.1 The Free tier cannot validate production GIF quality

Decision #4 uses WorkoutX Free for the integration spike. A vendor blog post
states the free plan serves GIFs at **180px with a subtle watermark**.

So the spike can validate *wiring* — auth, shapes, pagination, error handling —
but cannot answer §5's "Are paid-plan GIFs free of watermarks?" or characterise
production dimensions and file sizes. Those measurements need a paid tier.
Budget for that, or accept them as unverified until after purchase.

### 2.2 The vendor's own published numbers contradict each other

| Source | Ultra monthly quota | Pro rate limit |
| --- | --- | --- |
| `workoutxapp.com/docs.html` | 35,000 | 300/min |
| `workoutxapp.com/` (pricing) | 35,000 | 300/min |
| Vendor blog (`ai-workout-generator-api.html`) | **50,000** | **200/min** |

§5 requires plan capabilities to be rechecked immediately before purchase, and
the acceptance criteria require any plan discrepancy to be resolved before
Stage 1. It is not resolved. Treat the *lowest* published figure as the planning
number until the vendor confirms.

### 2.3 "Ultra" means two different products — a live purchasing hazard

WorkoutX also sells through RapidAPI. The tier names there are **shifted by one
position** against the direct site:

| Price | Direct site (`workoutxapp.com`) | RapidAPI listing |
| --- | --- | --- |
| $0 | **Free** — 500/mo, 30/min | **Basic** — 500/mo, 1000/hr |
| $9.99 | **Basic** — 3,000/mo, 150/min | **Pro** — 3,000/mo, 120/min |
| $15.99 | **Pro** — 10,000/mo, 300/min | **Ultra** — 10,000/mo, 120/min |
| $24.99 | **Ultra** — 35,000/mo, 600/min | **Mega** — 30,000/mo, 120/min |

Decision #4 names "WorkoutX Ultra" as the expected production plan, chosen
specifically because it includes `/v1/exercises/changes`. **Buying the plan
called "Ultra" on RapidAPI would deliver the $15.99 tier, which is the direct
site's "Pro" — and `/changes` is Ultra-gated, so it would not be included.** The
plan's own naming would lead a buyer to the wrong product.

Two further discrepancies from the same listing:

- The $24.99 tier is **30,000** requests/month on RapidAPI versus **35,000** on
  the direct site. A third distinct figure for the same price point.
- RapidAPI adds a **bandwidth platform fee**: 10,240 MB/month included, then
  **$0.001 per additional MB**. This is a metering dimension the direct site
  does not mention, and it lands squarely on the Stage 4 proxy — GIF bytes *are*
  the bandwidth. It is a further argument for purchasing direct rather than
  through RapidAPI, and a reason to size GIF payloads before committing.

The RapidAPI listing states no unique-GIF limit at all, so it did not close
§1.1's open number. **Purchase direct, and specify the tier by price and
quota, never by name.**

### 2.4 Provider maturity signals

- `https://docs.workoutx.io` — the documentation URL returned **by the API's own
  401 error body** — does not resolve (`ENOTFOUND`).
- The API is served by `server: railway-hikari` behind `x-railway-edge`; the
  Body Scan API's documented base URL is a raw
  `*.up.railway.app` hostname.

Neither is disqualifying. Both indicate a small, young vendor. Lactic would be
taking a single-vendor dependency for a hard v1 requirement, immediately after
destroying its own catalog. Weigh that against §3 of the plan, where cheaper
alternatives were rejected largely on *media rights clarity* — a criterion
WorkoutX also does not currently satisfy (§1.3).

### 2.5 Italian may be obtainable upstream — potentially deleting Stage 3

The API already ships a `lang` parameter supporting `en`, `de`, `es`, `fr`,
`zh-SG`, `zh-HK`. Italian is absent, which matches the plan's assumption that
Lactic owns the Italian layer.

But the localization *mechanism* already exists upstream. If WorkoutX will add
Italian, **Stage 3 disappears entirely** — no translation adapter, no Google
Cloud Translation contract, no glossary, no checksum-driven retranslation, no
per-locale provenance. That is the single largest scope reduction available in
this plan, and it costs one question. It is included in the vendor email.

### 2.6 A 1,400-exercise catalog will contain exercises v1 cannot express

ADR #6 fixes v1 to reps-only prescriptions. The provider exposes `met` and
`caloriesPerMinute`, which strongly implies the dataset includes timed and
cardio movements (planks, treadmill work). The legacy hand-seeded catalog could
simply omit those; an automatically synchronized 1,400-record catalog cannot.

Stage 1 already has the right mitigation — the `assignable` flag plus
`prescription_type` — but Stage 2 will need an explicit rule for classifying
which provider exercises are assignable under a reps-only product. Flagging now
so it is designed in, not discovered during import.

---

## 3. §5 vendor questions — current status

None of these can be closed by an agent. All require the vendor in writing.
Drafted for sending in `docs/workoutx_vendor_questions.md`.

| # | Question | Status |
| --- | --- | --- |
| 1 | Commercial GIF display via server-side proxy? | **Silent in terms** → written confirmation required |
| 2 | Persist required metadata locally? | **Silent in terms** → written confirmation required |
| 3 | Persist machine-translated Italian derivatives? | **Silent in terms** → written confirmation required |
| 4 | Permitted browser/device caching headers? | **Silent in terms** → written confirmation required |
| 5 | Does every exercise on the production plan have a GIF? | **Contradicted** — "1,400+ with GIFs" vs Basic's "500 unique GIFs" and a live unique-GIF meter |
| 6 | Are paid-plan GIFs watermark-free? | **Free tier is watermarked**; paid tiers unconfirmed |
| 7 | Do GIF requests count against monthly quota, a unique-GIF quota, or both? | **Partially answered** — a separate unique-GIF meter provably exists; interaction with the monthly quota unknown |
| 8 | Is in-app attribution required? | **Silent in terms** → written confirmation required |
| 9 | What happens to stored metadata and program references if the subscription ends? | **Partially answered** — keys revoked immediately; stored-data obligation unstated |

## 4. §5 measurements — what could and could not be done

| Measurement | Status |
| --- | --- |
| Error behaviour (401 unauthenticated vs 401 invalid key) | **Measured.** Distinct bodies; both fixtured |
| Quota header names | **Measured.** Nine headers enumerated via CORS expose list |
| Auth mechanism | **Measured.** `X-WorkoutX-Key` header or `?api-key=` query param; no endpoint is anonymously readable (`/exercises`, `/exercises/bodyPartList` both 401) |
| Upstream latency floor | **Measured.** ~0.6 s to a 401 from this network |
| Actual exercise count | Blocked — needs key |
| Field completeness percentages | Blocked — needs key |
| GIF status, MIME, dimensions, size percentiles | Blocked — needs key (and a paid tier to be representative) |
| Stable-ID behaviour | Blocked — needs key |
| Pagination envelope | Blocked — needs key |
| `/v1/exercises/changes` response shape | Blocked — needs key **and** an Ultra subscription |

Everything blocked above is automated in `lib/tasks/workoutx_probe.rake`. One
command produces the full measurement set once a key exists:

```bash
WORKOUTX_API_KEY=... bin/rails workoutx:probe
```

The task reads the key from the environment only, redacts it from anything it
writes, and refuses to run rather than proceeding keyless. It uses only the
standard library — Stage 0 adds no gem.

## 5. Field mapping against the Stage 1 domain model

Criterion #3 asks whether the provider sample maps cleanly to the proposed
model. Assessed against the **documented** field list; no live sample exists.

| Provider field | Stage 1 destination | Notes |
| --- | --- | --- |
| `id` | `exercises.source_uid` | Clean |
| `name`, `description`, `instructions` | `exercise_translations` (`locale: en`) | Clean; `instructions` ordering must be preserved |
| `target` | `exercise_muscles` role `primary` | Natural fit for the "count sets against one primary muscle" rule |
| `secondaryMuscles` | `exercise_muscles` role `secondary` | Clean |
| `bodyPart` | *unmapped* | A **third** muscle-ish axis, coarser than `target`. Stage 1 has two roles, not a grouping level. Needs a decision: discard, or add a coarse grouping used for filter UI |
| `equipment` | `equipment` + join | Provider field appears **singular**; the plan proposes a join table implying many-to-many. Confirm cardinality before building the join |
| `difficulty`, `mechanic`, `force`, `category` | Direct columns | Clean; taxonomy values need normalizing to stable keys |
| `gifUrl` | `exercise_media` (`kind: animation`, `mime_type: image/gif`) | Clean, and decision #9 holds — nothing named `gif_url` reaches the schema or API contract |
| **(absent)** | `exercises.source_updated_at` | **No documented upstream timestamp.** Nothing to populate it from |
| `movement_tags` | — | **Ultra-only.** Field availability varies by plan; schema and importer must tolerate absence |
| `isUnilateral`, `recommendedSets`, `recommendedReps` | *unmapped* | Genuinely useful — could seed coach defaults in the program builder. Consider for Stage 1 |
| `popularityRank` | *unmapped* | Useful as a catalog sort order for a 1,400-record picker |
| `caloriesPerMinute`, `met` | *unmapped* | Imply timed/cardio content — see §2.6 |
| `joint_focus`, `intensity_level` | *unmapped* | Defer |

Two structural observations:

1. **No change-tracking timestamp.** `source_updated_at` has no upstream source,
   so `content_checksum` becomes the *only* change-detection mechanism for full
   syncs. That is workable — it is why the plan specifies a checksum — but the
   column should be dropped or documented as null-until-provider-supplies-one
   rather than silently left empty.
2. **Mixed field casing.** `caloriesPerMinute` and `popularityRank` are
   camelCase while `joint_focus`, `intensity_level`, and `movement_tags` are
   snake_case. This is a loosely-versioned contract with no evident schema
   discipline beyond the `/v1` prefix. It strengthens the case for the Stage 2
   `Catalog::Providers::WorkoutX` boundary — but it also means the boundary
   should validate defensively rather than trust documented shapes.

**Verdict on criterion #3: partially met.** The core exercise/translation/media
shape maps cleanly. The `bodyPart` third axis, the equipment cardinality, and
the missing timestamp are unresolved and would each change the Stage 1
migration.

## 6. Owner decisions required

Stage 0 cannot be closed by an agent. Three things need a human:

**A. Obtain a Free API key.** Registration at `https://workoutxapp.com/`
requires no credit card. I cannot create accounts, so this is yours. Once you
have it, run the probe above and paste the output back — that clears every
blocked measurement in §4 except the Ultra-only and paid-tier ones.

**B. Send the vendor questions.** `docs/workoutx_vendor_questions.md` is ready
to send. I have not sent it and will not without your say-so. Questions 1–3 and
9 are the ones that decide whether this architecture is licensable at all;
question 5 decides whether decision #1 is achievable; the Italian question in
§2.5 could delete an entire stage.

**C. Decide the path, given that §1.3 may not resolve favourably.** The plan
rejected the alternatives in §3 largely on media-rights clarity — and WorkoutX
currently offers no more clarity than they do; it simply has better GIFs. Worth
reconsidering explicitly:

| Option | Consequence |
| --- | --- |
| Wait for vendor answers, then proceed | Cleanest. Stage 1 stays blocked meanwhile |
| **Buy Basic ($9.99) as a calibration probe** | The cheapest experiment that discriminates. Basic is the *only* tier whose unique-GIF number is published (500). If its `X-Unique-GIF-Limit` header reads exactly 500, the header is a real per-plan cap and §1.1 becomes urgent; if it reads something else, the published numbers are unreliable in a new way. Also reveals whether paid GIFs are watermarked. Answers §1.1 by inference for ~$10 without waiting on email |
| Buy Ultra ($24.99) now and measure | Resolves §1.1 directly, but spends more before the licensing questions in §1.3 are answered — and those can invalidate the purchase entirely |
| Rehost GIFs on Lactic storage (revisit decision #7) | Fixes the §1.2 quota problem and reduces vendor-outage exposure — but needs explicit vendor permission, which the terms do not grant |
| Re-evaluate a rejected alternative | Free Exercise DB has unambiguous open-data rights but static JPEGs, which decision #1 forbids. Reopening that means reopening decision #1 |

**Recommendation:** do A and B together now — they are free, parallel, and
between them resolve every blocking finding. If the vendor is slow to reply,
the $9.99 Basic calibration probe is the cheapest way to force §1.1 without
waiting. Do not buy the top tier until questions 1–3 come back, since a
licensing refusal would make the purchase worthless.

Hold Stage 1 until questions 1–3 and question 6 are answered.

## 7. Deliverables from this stage

| Path | Purpose |
| --- | --- |
| `docs/exercise_catalog_v1_stage0_report.md` | This report |
| `docs/workoutx_vendor_questions.md` | Vendor email, drafted and unsent |
| `lib/tasks/workoutx_probe.rake` | Measurement harness; stdlib only, key-redacting |
| `test/fixtures/files/workoutx/README.md` | Fixture provenance and rules |
| `test/fixtures/files/workoutx/error_unauthenticated_401.json` | Live 401, no credentials |
| `test/fixtures/files/workoutx/error_invalid_key_401.json` | Live 401, rejected key |
| `test/fixtures/files/workoutx/response_headers_401.txt` | Metering header evidence for §1.1 |

Not done, deliberately: no migration, no model, no provider adapter, no Gemfile
change, no `app/services/catalog/` code, no production or Railway change, no
secret stored anywhere. No authenticated fixture was fabricated — a hand-written
"expected shape" would let Stage 2 tests pass against a contract nobody has
verified, which is precisely the failure this gate exists to catch.

### Validation

| Check | Result |
| --- | --- |
| `RUBOCOP_CACHE_ROOT=tmp/rubocop bin/rubocop` | Pass — 137 files, no offenses |
| `bin/rails zeitwerk:check` | Pass — "All is good!" |
| `bin/brakeman --no-pager` | Pass — 0 errors, 0 security warnings |
| `bin/bundler-audit` | Pass — no vulnerabilities |
| `bin/rails test` | **Not run locally** — see below |
| Secret scan of all new files | Clean — only the deliberate `wx_invalid_probe_key` placeholder |
| `bin/rails workoutx:probe` without a key | Aborts with guidance; does not proceed keyless |

`bin/rails test` could not be executed in this environment: no local PostgreSQL
server and no Docker (`connection to server on socket "/tmp/.s.PGSQL.5432"
failed`). This is pre-existing and unrelated to Stage 0 — the identical failure
occurs on a stashed, clean working tree. CI's `test` job provisions PostgreSQL
and passes on PR #21.

Stage 0 adds no Ruby that the suite exercises: the rake task is not loaded by
tests, and the new fixtures live under `test/fixtures/files/` (the
`file_fixture` path), so they are inert rather than being loaded as Active
Record fixtures. The count of Active Record fixture files is unchanged at 12.
CI remains the authoritative check.

The plan document is unchanged. Per handoff protocol §6 it should be updated
only when an approved decision *changes*, and that is the owner's call from §6
above.
