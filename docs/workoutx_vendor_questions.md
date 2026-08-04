# WorkoutX — vendor questions (drafted, NOT sent)

Prepared during Stage 0 of `docs/exercise_catalog_v1_plan.md`.

**Status: unsent.** This message must be sent by the Lactic owner. An agent must
not send it, and must not accept a summary of a reply as sufficient — §5
requires answers "from current terms or in writing by WorkoutX", so keep the
actual reply and record its date and sender.

**Where to send:** the contact address on `https://workoutxapp.com/`. If the
vendor only offers a support form or Discord, prefer email so there is a
durable, quotable record; a chat screenshot is weaker evidence for a
licensing question that gates a destructive migration.

**Why these are blocking:** questions 1–3 and 9 decide whether the intended
architecture is licensable at all. Question 5 decides whether the hard v1
requirement (an animation for every exercise) is achievable on any tier.
Question 10 could remove an entire implementation stage. See
`docs/exercise_catalog_v1_stage0_report.md` §1 and §2.5.

---

## Suggested subject

`Licensing and quota questions before purchasing an Ultra plan`

## Draft body

> Hello,
>
> I am building a coaching product (web and iOS) and am evaluating the WorkoutX
> Exercise API as the exercise catalog. I expect to subscribe to the Ultra plan
> for the dataset sync endpoint, but before purchasing I need to confirm a few
> licensing and quota points that your published terms do not currently address.
>
> **Licensing**
>
> 1. May I display your exercise GIFs commercially to authenticated users of my
>    web and mobile applications, where the images are delivered through my own
>    server acting as an authenticated proxy? My API key would stay server-side
>    and never be exposed to a browser or mobile binary.
>
> 2. May I store the exercise metadata I need (names, descriptions,
>    instructions, target and secondary muscles, equipment, category,
>    difficulty, mechanic, force) in my own database, refreshed from your API,
>    rather than calling your API on every page view?
>
> 3. May I generate and store machine-translated Italian versions of the names,
>    descriptions, and instructions? Your `lang` parameter does not currently
>    offer Italian and my product requires it.
>
> 4. May I cache the GIF bytes on my own infrastructure — either in a cache or
>    rehosted in my own object storage — and if so, is there a maximum retention
>    period? Relatedly, what `Cache-Control` lifetime may my server send to
>    browsers and mobile clients for a proxied GIF?
>
>    This one matters a lot to me commercially. Since each GIF fetch appears to
>    consume a request from my monthly quota even when it is the same image
>    served repeatedly, serving animations without any caching would make my
>    quota usage scale with how often my users open a screen rather than with
>    how large your catalog is. If caching is permitted, a much smaller plan
>    likely suffices; if it is not, I need to understand the real cost of
>    serving a few hundred active users.
>
> 5. Is in-application attribution to WorkoutX required? If so, what wording and
>    placement do you expect?
>
> **GIF availability and quota**
>
> 6. Your API reports `total: 1327` exercises. Does every one of those have a
>    GIF on the top tier? Your pricing page describes the Basic plan as
>    including "500 unique exercise GIFs", and your API exposes
>    `X-Unique-GIF-Limit`, `X-Unique-GIF-Used`, and `X-Unique-GIF-Remaining`
>    headers — though none of them appear on free-plan responses. **What is the
>    exact `X-Unique-GIF-Limit` value on each paid tier?** I need to be certain
>    there is no cap below 1327.
>
> 7. On the free plan I measured that each GIF fetch decrements
>    `X-Quota-Remaining` by 1, and that re-fetching the same GIF decrements it
>    again. Is that also true on the paid tiers, or is GIF traffic metered
>    differently there? Specifically: does a repeat fetch of an
>    already-retrieved GIF count against the monthly quota again, and does the
>    unique-GIF meter reset monthly or is it a lifetime cap for the
>    subscription?
>
>    Relatedly, `X-Quota-Reset` came back as `null` on my free-plan responses.
>    When does the monthly quota reset — on the calendar month, or on the
>    subscription anniversary?
>
> 8. What resolution are GIFs on the paid tiers, and are they free of
>    watermarks? On the free plan I am receiving 360×360 images with "WorkoutX
>    API" tiled across the frame. I would like to know exactly what the paid
>    tiers deliver before purchasing, since watermarked images are not usable in
>    my product.
>
> **Continuity**
>
> 9. If my subscription ends, your terms say API keys are revoked immediately.
>    What happens to metadata I have already stored? May I continue to display
>    exercises that my users' saved training programs already reference, or am I
>    required to delete stored content? This matters a great deal to me: my
>    users' programs will reference your exercise records, and those programs
>    must not break.
>
> **Feature request**
>
> 10. Are there plans to add Italian (`it`) to the `lang` parameter? You already
>     support en, de, es, fr, zh-SG, and zh-HK. If Italian is on your roadmap I
>     would rather consume it from you than maintain my own translation layer.
>
> **Plan naming**
>
> 11. Your RapidAPI listing uses different tier names from your own site: the
>     $15.99 tier is called "Ultra" on RapidAPI but "Pro" on workoutxapp.com,
>     and the $24.99 tier is "Mega" on RapidAPI but "Ultra" on your site. The
>     $24.99 quota also differs (30,000 on RapidAPI, 35,000 on your site). Could
>     you confirm which tier — by price and monthly quota — includes
>     `/v1/exercises/changes`? I want to be certain I purchase the right one.
>
> **One documentation note:** the 401 response from
> `https://api.workoutxapp.com/v1/exercises` points to
> `https://docs.workoutx.io`, which does not currently resolve. You may want to
> update that error body to point at `https://workoutxapp.com/docs.html`.
>
> Thank you,
> Enrico

---

## Recording the reply

When the answer arrives, record it in
`docs/exercise_catalog_v1_stage0_report.md` §3, replacing each status with the
vendor's own wording plus the date and sender. Then re-evaluate the Stage 0
acceptance criteria. Stage 1 stays blocked until:

- questions 1, 2, and 3 are answered affirmatively (criterion #1); and
- question 6 confirms full-catalog GIF coverage on the purchased plan
  (decision #1); and
- question 9 confirms stored metadata survives subscription end, or the owner
  explicitly accepts that risk before the Stage 7 destructive reset.

If question 1, 2, or 3 comes back negative, the provider selection itself fails
and the plan returns to §3 alternatives — do not attempt to work around a
licensing refusal in code.
