# Lactic API

Rails API for the Lactic client and coach applications.

## Client invitations

New clients join through an email invitation and then verify their identity
with Google or Apple. There is no password signup. Existing accounts can sign
in normally; an unknown client email must present a valid invitation token.

Coach signup is open: any Google or Apple identity with no pending client
invitation becomes a coach automatically, on the free plan (see "Billing"
below). The frontend cannot select or promote its own role either way.

## Billing

Lactic Studio subscriptions run through RevenueCat's Web Billing product
(Stripe underneath — this app is the merchant of record). A coach's client
limit comes from `User#client_limit`: the `COACH_EMAILS` allowlist grants an
unlimited comp regardless of billing state; otherwise it's the active
`CoachSubscription`'s limit, or the free plan's limit of 3 with no
subscription row at all. See `app/services/billing/` and `AGENTS.md` §5.5 for
the full purchase → webhook → sync flow.

### Production environment

Configure these variables on the Railway API service:

```text
COACH_EMAILS=info@yellowtulip.it
FRONTEND_URL=https://lactic-web.vercel.app
RESEND_API_KEY=re_...
MAIL_FROM=Lactic <noreply@yellowtulip.it>
SENTRY_DSN=https://...
REVENUECAT_SECRET_API_KEY=sk_...
REVENUECAT_PROJECT_ID=proj_...
REVENUECAT_WEBHOOK_SIGNING_SECRET=whsec_...
```

`COACH_EMAILS` accepts a comma-separated list, and also acts as an unlimited
comp list for Lactic Studio billing — a listed coach is never capped by their
plan. The domain used by `MAIL_FROM` must be verified in Resend before
invitations can be delivered. `SENTRY_DSN` is optional — error tracking
(`config/initializers/sentry.rb`) is inert without it, which is also how
local development and the test suite run.

The three `REVENUECAT_*` variables wire up Lactic Studio's subscription
billing (see `app/services/billing/`): `REVENUECAT_SECRET_API_KEY` must be a
RevenueCat **v2** API key (v1 keys are not accepted by the v2 endpoints this
app calls). All three are optional in the sense that the app boots and every
coach reads as Free without them — `Billing::RevenueCat::Client#configured?`
gates every call, matching the presence-gated pattern already used for Resend
and Sentry.

## Local development

Requirements: Ruby 3.4.3 and PostgreSQL.

```bash
bundle install
bin/rails db:prepare
bin/rails test
bin/rails server
```

Development invitation emails use Action Mailer's test delivery method. The
acceptance URL is written to the Rails development log.
