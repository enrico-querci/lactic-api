# Exercise Catalog V1 — Stage 0 Provider Verification Report

Stage: **0 — Provider Verification Gate** (`docs/exercise_catalog_v1_plan.md` §5).

Date: 2026-08-04. Updated 2026-08-05 with live measurements from a free-plan
API key.

## Verdict: NOT PASSED — do not begin Stage 1

A free-plan API key was supplied on 2026-08-05 and the full measurement suite
was run. The technical picture is now largely known, and much of it is good:
field completeness is 100%, the data maps cleanly onto the Stage 1 model, and
pagination and IDs behave sanely.

The gate still does not pass, for two reasons that measurement made **worse**,
not better:

1. **Decision #7 is now proven unworkable as written.** Every GIF fetch costs a
   full monthly request, and repeat fetches of the same GIF cost again (§1.2).
   Streaming animations on demand without caching makes quota consumption scale
   with UI interactions.
2. **The vendor's terms grant none of the three permissions acceptance
   criterion #1 requires** (§1.3) — and the fix for problem 1 is caching, which
   is one of the things the terms do not grant.

One decisive number is still unobtainable without a paid key: whether the
purchased tier's unique-GIF cap covers all 1327 exercises (§1.1).

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
| 1 | `GET https://api.workoutxapp.com/v1/exercises` returns `access-control-expose-headers` including `X-Unique-GIF-Limit`, `X-Unique-GIF-Used`, `X-Unique-GIF-Remaining` | **Direct** — captured in `test/fixtures/files/workoutx/response_headers_401.txt` |
| 2 | The pricing page describes the Basic plan as including "500 unique exercise GIFs", against an advertised catalog of "1,400+ exercises" | Vendor published |
| 3 | A vendor blog post states "All plans include access to the full exercise metadata; GIF library limits vary by plan" | Vendor published |
| 4 | On an **authenticated free-plan request**, all three `X-Unique-GIF-*` headers are **absent** while `X-Quota-*` and `X-RateLimit-*` are present | **Direct** — measured 2026-08-05 |

**What this proves:** WorkoutX has a unique-GIF metering dimension in its CORS
contract, but does **not** apply it to the free plan. Combined with evidence 2
and 3, the cap is a **paid-tier** mechanism.

**What this does NOT prove:** the top tier's actual `X-Unique-GIF-Limit` value.
That still requires a paid key or a vendor answer. The 500 figure is documented
for **Basic only**.

**Catalog size, now measured:** the API reports `total: 1327`, not the
advertised "1,400+". So the relevant comparison is *"is the paid tier's
unique-GIF limit ≥ 1327?"* — and Basic's published 500 is well below it.

**Why it blocks:** if the purchased tier's unique-GIF limit is below 1327, then
"a real animated GIF demonstration for every provider exercise" is not
purchasable, and WorkoutX fails provider selection outright. This single number
decides whether the rest of the plan is viable.

### 1.2 Proxy-without-rehosting collides with the request quota — now measured

Decision #7 says Lactic does **not** rehost GIFs: Rails authenticates upstream
and streams each animation through a Lactic endpoint. This was previously a
suspicion. It is now measured, and it is worse than assumed.

Three facts, established 2026-08-05:

1. **`gifUrl` points at the API host itself** — `https://api.workoutxapp.com/v1/gifs/0001.gif`,
   not a CDN.
2. **It requires the API key.** The same URL without the key returns `401`. (This
   does at least confirm the Stage 4 proxy is genuinely necessary, and that no
   credential appears in the URL — the key travels as a header.)
3. **Every GIF fetch decrements the monthly request quota by exactly 1 — and
   re-fetching the same GIF decrements it again.**

Measured directly by reading `X-Quota-Remaining` around interleaved calls:

| Call | `X-Quota-Remaining` |
| --- | --- |
| metadata | 485 |
| **GIF `0001.gif`** | **484** |
| metadata | 483 |
| **GIF `0001.gif` again (identical URL)** | **482** |
| metadata | 481 |

There is one flat request counter. A GIF costs the same as a metadata call, and
there is **no deduplication for a repeat fetch of the same animation**.

**Scope caveat:** this was measured on the **free** plan, whose page size is
capped at 10 records. Nothing observed distinguishes "one request = one HTTP
call" from "one request = one billing unit that may be sized differently on a
paid tier" — and the vendor's own rate limits are quoted inconsistently across
channels (30/min direct vs 1000/hour on RapidAPI for nominally similar tiers).
Paid-tier metering is **assumed identical but unverified**. Treat the ratio as
established for free and probable for paid; confirm it before purchase. The
architectural consequence below holds under any of these interpretations,
because none of them make a repeat view free.

Related unknown: `X-Quota-Reset` returned **`null`**, so the reset cadence is
unconfirmed. If the monthly quota does not reset on the calendar month, the
"35,000/month" planning figure is unreliable in a way that compounds the
per-view cost. Added to the vendor questions.

**Why this is severe:** Stage 4 specifies that the web client fetch each
animation "as an authenticated blob and create an object URL, with cleanup on
unmount." Under a flat per-request meter with no repeat discount, that makes
quota consumption proportional to **UI interactions**, not to catalog size. The
same client re-opening the same exercise five times costs five requests. Browser
HTTP caching cannot help, because each mount re-fetches through an authenticated
XHR.

Catalog metadata is cheap by comparison: 1327 exercises at 100 records/page is
~14 requests for a full sync. The entire quota risk is animation traffic.

The natural mitigation is to cache or rehost GIFs on Lactic infrastructure —
which is exactly what decision #7 forbids and what the terms are silent on
(§1.3). So the mitigation for a now-proven quota problem is itself blocked on a
vendor answer.

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

### 2.1 Free-tier GIFs are heavily watermarked and unusable in product

Decision #4 uses WorkoutX Free for the integration spike. A vendor blog post
describes the free plan as serving GIFs at "180px" with "a subtle watermark".
Both claims are wrong, measured 2026-08-05:

- Actual dimensions are **360×360**, not 180px.
- The watermark is **not subtle**. "WorkoutX API" is tiled diagonally across the
  entire frame — roughly six repetitions per image, in large grey type directly
  over the figure. The image is unusable in a shipped product.

The underlying artwork is good — a clean anatomical illustration with the target
muscle highlighted in red — which is presumably why the plan chose this vendor.
But the free tier demonstrates *availability*, not the product experience.

Consequences for the plan:

- The Stage 4 proxy and the Stage 6 UI can be built and demoed against free-tier
  GIFs, but **nothing user-facing can ship on them**.
- §5's "Are paid-plan GIFs free of watermarks?" remains open and is now a
  purchase-gating question rather than a detail: if the paid tiers are also
  watermarked, decision #1 fails on quality even if the quota questions resolve.

No provider GIF or extracted frame is committed to this repository. Whether
Lactic may store provider media at all is precisely the open question in §1.3.

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
| 5 | Does every exercise on the production plan have a GIF? | **Partly answered** — 100% of the free-plan sample has a working `gifUrl`, and the catalog is 1327 records. But Basic publishes a 500-unique-GIF cap, so *paid-tier* coverage is still unconfirmed |
| 6 | Are paid-plan GIFs watermark-free? | **Free tier is heavily watermarked** (§2.1, measured); paid tiers unconfirmed. Now purchase-gating |
| 7 | Do GIF requests count against monthly quota, a unique-GIF quota, or both? | **Answered for the free plan** — each GIF costs exactly 1 monthly request, repeat fetches included, and no unique-GIF meter is applied (§1.2). Paid-tier behaviour may differ, since that is where the unique-GIF cap lives |
| 8 | Is in-app attribution required? | **Silent in terms** → written confirmation required |
| 9 | What happens to stored metadata and program references if the subscription ends? | **Partially answered** — keys revoked immediately; stored-data obligation unstated |

## 4. §5 measurements — what could and could not be done

Run against a **free-plan key** on 2026-08-05 via `bin/rails workoutx:probe`.

| Measurement | Result |
| --- | --- |
| Actual exercise count | **1327** (`total` in the list envelope) — below the advertised "1,400+" |
| Field completeness | **100%** across all 13 checked fields in a 10-record sample: `id`, `name`, `bodyPart`, `target`, `equipment`, `difficulty`, `mechanic`, `force`, `gifUrl`, `category`, `description`, `instructions`, `secondaryMuscles` |
| GIF status / MIME | 8/8 HTTP 200, all `image/gif` |
| GIF dimensions | 360×360, uniform across the sample |
| GIF size | median **395 KB**, p90 **693 KB**, max **693 KB** |
| GIF requires key | Yes — same URL anonymously returns `401` |
| GIF quota cost | **1 request each, repeats included** (see §1.2) |
| Stable-ID behaviour | Zero-padded **strings**: `"0001"`, `"0002"`, `"0003"`, `"0006"`… Non-sequential with gaps; the 404 body states "Exercise IDs are not sequential" |
| Pagination envelope | `{ "total", "count", "data" }`; `limit`/`offset`; pages disjoint; ordering stable across identical requests |
| Free-plan page cap | `limit=25` returned `count: 10` — the documented 10-record cap is enforced |
| Quota headers | `X-Quota-Limit: 500`, `X-Quota-Remaining` decrements per request, `X-Quota-Reset: null` |
| Rate limit headers | `X-RateLimit-Limit: 30`, `X-RateLimit-Remaining` decrements per request |
| Unique-GIF headers | **Absent** on the free plan (see §1.1) |
| Error behaviour | Unauthenticated `401`, invalid key `401` with a distinct body, unknown id `404` with a helpful message. All fixtured |
| Upstream latency | ~0.6 s to a 401; GIF fetches completed well inside a 30 s timeout |
| `/v1/exercises/changes` | **HTTP 403** on free — empirically confirms the endpoint is gated to the top tier |

Still unmeasured, and requiring a **paid** key:

- the paid-tier `X-Unique-GIF-Limit` value (§1.1 — the decisive number);
- whether paid-tier GIFs are watermark-free (§2.1);
- paid-tier GIF dimensions and file sizes;
- the `/v1/exercises/changes` response shape.

Re-run at any time with:

```bash
WORKOUTX_API_KEY=... bin/rails workoutx:probe
```

The task reads the key from the environment only, redacts it from anything it
writes, and refuses to run rather than proceeding keyless. It uses only the
standard library — Stage 0 adds no gem. Add `CHANGES=1` to also probe the
top-tier sync endpoint.

## 5. Field mapping against the Stage 1 domain model

Criterion #3 asks whether the provider sample maps cleanly to the proposed
model. Now assessed against a **live 10-record sample**, fixtured at
`test/fixtures/files/workoutx/exercises_list_response.json`.

| Provider field | Live example | Stage 1 destination | Notes |
| --- | --- | --- | --- |
| `id` | `"0001"` | `exercises.source_uid` | **Zero-padded string, non-sequential.** Must be a string column — never cast to integer, or `"0001"` collides with `"1"` |
| `name` | `"3/4 Sit-up"` | `exercise_translations` | Clean |
| `instructions` | 5-element array | `exercise_translations` | Clean, ordered, prose sentences. Genuinely worth translating |
| `description` | see below | `exercise_translations` | **Auto-generated boilerplate**, not editorial prose — see observation 2 |
| `target` | `"Abs"` | `exercise_muscles` role `primary` | Fits the "count sets against one primary muscle" rule |
| `secondaryMuscles` | `["Hip Flexors", "Lower Back"]` | `exercise_muscles` role `secondary` | Clean array |
| `bodyPart` | `"Waist"` | *unmapped* | **Confirmed a third, coarser axis** (`Waist` contains `Abs`). Stage 1 has two roles, no grouping level. Decide: discard, or add a region grouping for filter UI |
| `equipment` | `"Body Weight"` | `equipment` + join | **Confirmed singular string.** The plan's join table implies many-to-many; the provider supplies exactly one. A join table is still defensible for custom exercises, but do not build it expecting provider fan-out |
| `difficulty`, `mechanic`, `force`, `category` | `"beginner"`, `"isolation"`, `"push"`, `"strength"` | Direct columns | Already lowercase and stable-looking. Muscle/equipment values are Title Case and need normalizing to stable keys |
| `gifUrl` | `.../v1/gifs/0001.gif` | `exercise_media` | Clean, and decision #9 holds. Note the URL is trivially derivable from `id`, so storing a media identifier rather than a full URL is viable |
| **(absent)** | — | `exercises.source_updated_at` | **Confirmed: no upstream timestamp of any kind** |
| `movement_tags` | `["beginner-friendly", …]` | *unmapped* | **Present on the free plan**, contradicting the docs' "Ultra only". Do not gate schema on plan tier without checking |
| `isUnilateral`, `recommendedSets`, `recommendedReps` | `false`, `"3"`, `"10-15"` | *unmapped* | Useful — could seed program-builder defaults. Note both rep fields are **strings**, and `"10-15"` is a range, not a number |
| `popularityRank` | `5` | *unmapped* | Useful default sort for a 1327-record picker |
| `met`, `caloriesPerMinute` | `3.5`, `4.3` | *unmapped* | Present on every record — see §2.6 |
| `joint_focus`, `intensity_level` | `"lumbar_spine"`, `"gentle"` | *unmapped* | Also present on free. Defer |

Three structural observations:

1. **No change-tracking timestamp — confirmed empirically.** `source_updated_at`
   has no upstream source, so `content_checksum` becomes the *only*
   change-detection mechanism. That is workable, and it is why the plan
   specifies a checksum — but the column should be dropped from the Stage 1
   migration rather than added and left permanently null.

2. **`description` is templated, not authored.** The live value reads: *"3/4
   Sit-up is a beginner single-joint isolation pushing exercise targeting the
   Abs in the Waist region. Performed using bodyweight, it falls under the
   strength category. Secondary muscles engaged include Hip Flexors and Lower
   Back."* That is mechanically generated from `difficulty`, `mechanic`, `force`,
   `target`, `bodyPart`, `equipment`, and `category`.

   This materially changes Stage 3. Paying to machine-translate 1327 generated
   sentences is waste — the same text can be produced in Italian from a
   translated taxonomy (a few dozen terms) plus one sentence template, at
   effectively zero marginal cost and with better consistency. **Translate
   `name` and `instructions`; generate `description`.** That also shrinks the
   translation bill enough to affect the Stage 3 provider choice.

3. **Mixed field casing.** `caloriesPerMinute` and `popularityRank` are
   camelCase while `joint_focus`, `intensity_level`, and `movement_tags` are
   snake_case — and `movement_tags` appears despite being documented as
   Ultra-only. This is a loosely-versioned contract. It strengthens the case for
   the Stage 2 `Catalog::Providers::WorkoutX` boundary, and means that boundary
   should validate defensively rather than trust documented shapes.

**Verdict on criterion #3: substantially met.** Field completeness is 100% on
the sample and the core exercise/translation/media shape maps cleanly. Three
items still need a decision before the Stage 1 migration: the `bodyPart` third
axis, the equipment cardinality, and dropping `source_updated_at`.

## 6. Owner decisions required

Stage 0 cannot be closed by an agent. Three things need a human:

**A. ~~Obtain a Free API key.~~ Done — 2026-08-05.** The free-plan key was
supplied and the probe run; §4 holds the results. **Rotate that key**: it was
pasted into a chat transcript, which is a durable log. It is free-tier, so the
blast radius is small, but regenerate it from the WorkoutX dashboard. When a
production key is issued, it belongs in Railway variables only, never in chat,
source, or a fixture.

**B. Send the vendor questions.** `docs/workoutx_vendor_questions.md` is ready
to send. I have not sent it and will not without your say-so. Questions 1–3 and
9 decide whether this architecture is licensable at all; question 6 decides
whether decision #1 is achievable; the Italian question in §2.5 could delete an
entire stage.

Measurement has raised the stakes on question 4 (caching). It is no longer a
detail: §1.2 proves that without server-side caching, the Stage 4 proxy burns a
request per animation view. If WorkoutX will not permit caching, **decision #7
must change or the provider must change.**

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

**Recommendation:** send the vendor email now (B) — it is free and it is the
only thing that can unblock §1.3, which measurement cannot touch. If the reply
is slow, the $9.99 Basic calibration probe answers §1.1 and §2.1 together: it
is the one tier with a published unique-GIF number, so its
`X-Unique-GIF-Limit` header either corroborates the published figures or
discredits them, and it reveals whether paid GIFs are watermarked. Do not buy
the top tier until questions 1–3 come back — a licensing refusal would make the
purchase worthless.

Hold Stage 1 until questions 1–4 and question 6 are answered.

One realistic outcome worth naming in advance: if the vendor permits caching
(question 4), then decision #7 should be amended to allow a server-side media
cache, §1.2 dissolves, and the plan proceeds. If the vendor refuses caching but
permits everything else, the architecture still works but the top tier's quota
becomes a real operating constraint that Stage 4 must be designed around
(aggressive client-side reuse, no catalog-grid animation, possibly a
static-thumbnail fallback). Only a refusal on questions 1–3 kills the provider
outright.

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
| `test/fixtures/files/workoutx/exercises_list_response.json` | **Three real exercise records** from a live authenticated call. The Stage 2 importer contract |

No provider GIF is committed. The animations are the subject of the unresolved
licensing questions in §1.3, so storing one in git would pre-empt the answer.

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
| Secret scan of all committed files | Clean — the only key-shaped string is the deliberate `wx_invalid_probe_key` placeholder |
| `bin/rails workoutx:probe` without a key | Aborts with guidance; does not proceed keyless |
| `bin/rails workoutx:probe` with a real key | Ran successfully against the free plan; results in §4 |
| Probe-written fixture re-scanned | Clean — `gifUrl` values carry no credential; the key travels as a header |

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
