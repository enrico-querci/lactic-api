# AGENTS.md — Lactic & Lactic Studio

> Root project context for every Lactic repository.
>
> It documents the product, current implementation, architecture, deployments,
> conventions, and cross-repository rules. Platform-specific instructions may
> live in nested `AGENTS.md` files.
>
> Keep this file byte-for-byte identical across all Lactic repositories.
> `CLAUDE.md` should be a relative symlink to this file.

---

## 1. Project Overview

**Lactic** (**L**egs **A**re **C**ausing **T**remendous **I**nternal **C**ramping)
is a workout-management ecosystem for coaches and their clients.

| Product | Audience | Platform | Purpose | Current state |
| --- | --- | --- | --- | --- |
| **Lactic** | Client | iOS | Follow assigned programs and log workouts | Product target |
| **Lactic Studio** | Coach/Admin | iOS/iPadOS | Manage clients and create training programs | Product target |
| **Lactic Web** | Coach and client | Web | Browser access to both role-specific experiences | Implemented and deployed |
| **Lactic API** | All clients | Rails API | Shared auth, business logic, persistence, email, and REST API | Implemented and deployed |

**Reference competitor:** CoachPlus (client) / CoachPlus PT (admin).

### 1.1 Current milestone

The latest completed milestone is secure client invitation onboarding:

- Coaches can create, list, resend, and revoke invitations from the web client.
- Resend delivers invitations from the verified `yellowtulip.it` domain.
- Invitation links open the web route `/invite/[token]`.
- Invited users authenticate with Google or Apple; the verified provider email
  must match the invitation email.
- The backend, not the browser, determines whether a new account is a coach or
  client.
- Both backend and frontend changes are merged, deployed, and online.

---

## 2. Architecture

### 2.1 Repositories

| Repository | Contents |
| --- | --- |
| `lactic-ios` | iOS monorepo: Lactic, Lactic Studio, and shared Swift packages |
| `lactic-api` | Ruby on Rails API-only backend |
| `lactic-web` | Next.js web portal with coach and client routes |

### 2.2 Technology stack

| Layer | Technology |
| --- | --- |
| iOS | Swift 6.x, SwiftUI, modular Swift Packages |
| Web | Next.js 16.1.6, React 19.2.3, TypeScript 5, Tailwind CSS 4 |
| Backend | Ruby 3.4.3, Rails 8.1.3.1, API-only |
| Database | PostgreSQL hosted on Railway |
| Serialization | Blueprinter |
| Authentication | Google Sign-In and Sign in with Apple; JWT access and refresh tokens |
| Transactional email | Resend HTTPS API through Action Mailer |
| Backend hosting | Railway, Dockerfile deployment |
| Frontend hosting | Vercel with Git integration |
| Storage | TBD; likely S3-compatible storage such as Cloudflare R2 |
| CI/CD | GitHub Actions, Railway Git deployment, and Vercel Git deployment |

### 2.3 Authentication and authorization

- Google and Apple are the only production sign-in methods in v1.
- There is no email/password signup in v1.
- The web UI currently implements Google Sign-In. The API also supports Apple.
- The API issues short-lived JWT access tokens and refresh tokens.
- A user has exactly one role: `coach` or `client`.
- Existing users sign in normally using their linked provider identity.
- An unknown client must present a valid invitation token during social sign-in.
- An unknown coach can be created only when the verified email is listed in the
  server-side `COACH_EMAILS` allowlist.
- Never trust a role supplied by a browser or mobile client when creating an
  account.
- Invitation acceptance requires the normalized social-provider email to equal
  the normalized invited email.
- Development/test may use `/api/v1/auth/dev_login`; that route does not exist
  in production.

### 2.4 Production infrastructure

#### Backend

- Public API: `https://lactic-api-production.up.railway.app`
- Health check: `https://lactic-api-production.up.railway.app/up`
- Railway API project: `67b6a3e9-e4d7-4aa7-b501-376f4c9cbcfb`
- Railway production environment: `9645ae12-7b8f-4c5b-8a46-950428c3c822`
- Railway API service: `5289c1bd-e10a-403f-a677-14030dabf298`
- GitHub repository: `enrico-querci/lactic-api`
- Merges to `main` trigger a Railway deployment.
- The production Docker entrypoint runs `bin/rails db:prepare` before starting
  the Rails server, so pending migrations are applied during deployment.

#### Database

- Railway database project: `2233428f-e904-4d09-ba81-6bc4d1474d49`
- Railway production environment: `5ce33fd0-5342-414a-a17a-93496eb0f1c0`
- Railway PostgreSQL service: `426d350b-0c96-48f5-bb70-3e8b27151bbf`
- The API receives its connection string through `DATABASE_URL`.

#### Frontend

- Production URL: `https://lactic-web.vercel.app`
- Vercel project: `prj_B7j9JXLQak7sH3EY0ZAGaqzjLI77`
- Vercel team: `team_rrjKNHw6fKRQhVt1Ol5lXhZp`
- GitHub repository: `enrico-querci/lactic-web`
- Merges to `main` trigger a Vercel production deployment.
- Pull requests receive Vercel preview deployments and deployment checks.

#### Email

- Provider: Resend.
- Sending domain: `yellowtulip.it` (verified).
- Expected sender: `Lactic <noreply@yellowtulip.it>`.
- Railway production variables include `RESEND_API_KEY`, `MAIL_FROM`,
  `FRONTEND_URL`, and `COACH_EMAILS`.
- Never write secret values in source, documentation, logs, issues, or commits.
  Document variable names only.

### 2.5 Last verified production state

Verified on **2026-08-04**:

| Component | Source commit | Deployment | Result |
| --- | --- | --- | --- |
| API | `5236941c98abf53a50f36033fc0f3aed4685705b` | Railway `5e04defe-b90d-4fbc-a7b3-067105b4eb8e` | `SUCCESS`; `/up` returned HTTP 200 |
| Web | `e7848ad6e9251e96ff351eea1e364204297e042d` | Vercel `dpl_2vNuhEJaa5tzX1myWLtQTbXL93Pm` | `READY`; production alias verified |

Merged pull requests:

- API: `enrico-querci/lactic-api#20`
- Web: `enrico-querci/lactic-web#1`

---

## 3. Data Model

### 3.1 Core hierarchy

```text
Coach (User with role=coach)
 ├─ ClientInvitation
 ├─ Client (User with role=client)
 └─ Program (reusable template)
     └─ Week
         └─ Workout (day 1-7; multiple workouts per day allowed)
             └─ WorkoutExercise
                  └─ Exercise (global or coach-owned catalog entry)

ProgramAssignment
 ├─ Program
 ├─ Coach
 └─ Client

WorkoutSession
 └─ ExerciseLog
      └─ SetLog
```

### 3.2 Entity details

#### User / Coach

- `id`, `name`, `email`, `avatar_url`, `role`, provider identity fields.
- Has many clients, invitations, programs, exercises, templates, and
  assignments as appropriate.
- First-time coach access is controlled by `COACH_EMAILS`.

#### User / Client

- `id`, `name`, `email`, `avatar_url`, `role`, `coach_id`.
- Belongs to a coach after accepting an invitation.
- Has many program assignments and workout sessions.

#### ClientInvitation

- `id`, `coach_id`, `email`, `token_digest`.
- `expires_at`, `sent_at`, `accepted_at`, `revoked_at`.
- Stores only a digest; the raw token is shown only when created or regenerated.
- Secure, expiring, revocable, and single-use.
- Pending invitations can be resent or revoked by their coach.
- Acceptance requires matching social identity, links the client to the coach,
  and records `accepted_at`.

#### Program

- `id`, `coach_id`, `name`, `description`.
- Reusable template with an ordered, variable number of weeks.
- The same program can be assigned to multiple clients with different dates.

#### Week

- `id`, `program_id`, `position`.
- Contains ordered workouts.

#### Workout

- `id`, `week_id`, `name`, `day`.
- Multiple workouts may exist on the same day.
- Can be duplicated within or across weeks.
- Can be snapshotted as a standalone `WorkoutTemplate`.

#### WorkoutTemplate

- `id`, `coach_id`, `name`, `source_workout_id`.
- Reusable snapshot that can be applied elsewhere.

#### Exercise

- `id`, `name`, `muscle_group`, optional `video_url` and `thumbnail_url`.
- `is_custom` and optional `coach_id` distinguish global from coach-owned
  exercises.
- The target catalog contains approximately 150-200 common exercises.

#### WorkoutExercise

- `id`, `workout_id`, `exercise_id`, `position`.
- Target configuration: `sets`, `reps`, `rest_seconds`, optional `rir`,
  suggested `weight`, and coach `notes`.

#### ProgramAssignment

- `id`, `program_id`, `client_id`, `coach_id`.
- `start_date`, optional `notes`, and `status` (`active`, `completed`, `paused`).

#### WorkoutSession

- `id`, `client_id`, `workout_id`, `program_assignment_id`.
- `started_at`, `completed_at`, and client notes.

#### ExerciseLog

- `id`, `workout_session_id`, `workout_exercise_id`.
- Client notes and optional execution photo URL.

#### SetLog

- `id`, `exercise_log_id`, `position`, `weight_kg`, and performed `reps`.

### 3.3 Computed values

- **Volume sets per muscle group:** sum configured sets across workout exercises,
  grouped through the associated exercise's `muscle_group`.
- **Estimated duration:** derived from configured sets, repetitions, and rest
  periods; exact product formula may evolve.

---

## 4. Product Features

### 4.1 Lactic client experience

| Feature | Description |
| --- | --- |
| View program | Browse assigned programs, weeks, days, workouts, and parameters |
| Execute workout | Guided workout mode with rest timer |
| Log sets | Store actual weight and repetitions per set |
| Add extra sets | Record sets beyond the coach's target |
| Notes and execution | Personal workout/exercise notes and photos |
| Coach guidance | Read coach notes and watch exercise videos |
| Progress | Review session and exercise weight history |
| Onboarding | Accept a coach invitation through social sign-in |

### 4.2 Lactic Studio coach/admin experience

| Feature | Description |
| --- | --- |
| Manage clients | List clients, inspect progress, remove links, and manage invitations |
| Create programs | Build weeks, days, workouts, and configured exercises |
| Exercise catalog | Search global exercises and create coach-owned exercises |
| Reuse workouts | Duplicate workouts and apply saved workout templates |
| Assign programs | Assign a program with start date and notes |
| Review progress | Inspect sessions, actual weights, and repetitions |
| Planning metrics | Volume sets and estimated workout duration |

### 4.3 Implemented web portal

The Next.js application already contains both role-specific views.

#### Coach routes and capabilities

- `/coach/clients`: client list plus create/resend/revoke invitation CRUD.
- `/coach/clients/[id]`: individual client and progress.
- `/coach/programs/**`: program list, details, builder, weeks, workouts, and
  workout-exercise configuration.
- `/coach/exercises/**`: exercise catalog and custom exercise creation.
- `/coach/templates`: workout templates.
- `/coach/assignments/**`: program assignments.

#### Client routes and capabilities

- `/client/programs/**`: assigned programs and details.
- `/client/workouts/[id]`: workout execution and set logging.
- `/client/history/**`: workout-session history and details.
- `/client/exercises/[id]`: exercise details and progress history.

#### Shared onboarding and auth

- `/login`: Google Sign-In and development login support.
- `/invite/[token]`: validates invitation metadata, carries the token through
  Google authentication, and completes onboarding.
- Role guards route coaches to `/coach` and clients to `/client`.
- The API client refreshes expired access tokens using the stored refresh token.

---

## 5. Key Flows

### 5.1 Coach creates and assigns a program

1. Coach creates a program.
2. Adds ordered weeks.
3. Adds one or more workouts to days 1-7.
4. Adds exercises with sets, reps, rest, RIR, weight, and notes.
5. Optionally duplicates workouts or applies a saved template.
6. Assigns the program to one or more clients with a start date and notes.

### 5.2 Client executes a workout

1. Client opens an active program and current week.
2. Selects the day's workout.
3. Reviews coach parameters and notes.
4. Starts the session.
5. Records weight and repetitions for each set.
6. Optionally adds sets, notes, and photos.
7. Uses the rest timer between sets.
8. Completes the session and makes it available in history.

### 5.3 Coach invites a client

1. Coach opens `/coach/clients` and submits the client's email.
2. API creates a secure invitation, stores only its digest, and sends an email
   through Resend.
3. Email links to `${FRONTEND_URL}/invite/<raw-token>`.
4. Coach may resend a pending invitation (rotating the token and expiry) or
   revoke it.
5. Client opens the link and signs in with Google or Apple.
6. Frontend sends the invitation token alongside the provider ID token.
7. API verifies token state, expiry, revocation, single-use status, and exact
   normalized email match.
8. API creates or links the client, assigns the coach, marks the invitation
   accepted, and returns JWT tokens.
9. Frontend routes the client into the client experience.

### 5.4 First-time coach onboarding

1. Add the normalized email to the Railway `COACH_EMAILS` variable.
2. User signs in through Google or Apple.
3. API verifies provider identity and the server-side allowlist.
4. API creates a `coach` user. No browser-supplied role is consulted.

---

## 6. Development Conventions

### 6.1 iOS (`lactic-ios`)

- Swift 6.x and SwiftUI.
- Recommended architecture: MVVM with coordinators or TCA.
- Shared packages:
  - `LacticKit`: models, networking, API client, persistence.
  - `LacticUI`: shared UI components.
  - `LacticCore`: utilities, extensions, constants.
- PascalCase types and camelCase members.
- Minimum target: iOS 26+.
- Lactic targets iPhone; Lactic Studio targets iPad first.

### 6.2 Rails (`lactic-api`)

- Ruby 3.4.3 and Rails 8.1.x API-only.
- REST JSON endpoints are versioned under `/api/v1/`.
- Follow conventional Rails snake_case naming.
- PostgreSQL via Active Record.
- Blueprinter serializers.
- Minitest test suite with fixtures.
- JWT access and refresh tokens.
- Use service objects for flows such as authentication and invitation acceptance.
- Local API default: `http://localhost:3000`.

Relevant validation commands:

```bash
bin/rails test
RUBOCOP_CACHE_ROOT=tmp/rubocop bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
bin/rails zeitwerk:check
```

### 6.3 Web (`lactic-web`)

- Next.js App Router with TypeScript and React.
- Tailwind CSS for styling.
- Keep role-specific pages under `app/coach` and `app/client`.
- Keep typed API calls under `lib/api/endpoints`.
- Shared authentication state lives in `lib/auth/context.tsx`.
- Local web default: `http://localhost:3001`.
- Configure `NEXT_PUBLIC_API_URL` and `NEXT_PUBLIC_GOOGLE_CLIENT_ID` in
  `.env.local` and Vercel.

Relevant validation commands:

```bash
npm run lint
npm run build
```

### 6.4 Git and CI

- `main` is the production branch.
- Use short-lived `feature/*`, `fix/*`, or `codex/*` branches.
- Use conventional English commit messages.
- Open a pull request for every feature or fix.
- Do not merge with failed or incomplete checks.
- API GitHub Actions run on pull requests and pushes to `main`:
  - `test`: PostgreSQL-backed Rails test suite.
  - `lint`: RuboCop.
  - `scan_ruby`: Brakeman and bundler-audit.
- The invitation milestone's final backend run passed all three jobs, including
  225 Rails tests.
- Vercel supplies frontend preview/deployment checks. Run lint and a production
  build locally before opening or merging a frontend PR.

---

## 7. Architectural Decision Records

| # | Decision | Rationale |
| --- | --- | --- |
| 1 | Rails API-only backend | Supports iOS and web clients without coupling presentation to Rails |
| 2 | iOS monorepo with two targets | Maximizes shared models, networking, and UI code |
| 3 | Program is a reusable template | One program can be assigned to many clients independently |
| 4 | WorkoutTemplate is separate | Workouts can be saved and reused outside one program/week |
| 5 | Google and Apple only in v1 | Avoids password storage, reset, and verification complexity |
| 6 | Reps-only mode and RIR-only intensity in v1 | Keeps the first release focused and extensible |
| 7 | Global exercise catalog plus coach-owned exercises | Provides immediate utility while allowing customization |
| 8 | One web portal with role guards | Shares infrastructure while preserving distinct coach/client navigation |
| 9 | Server-controlled account roles | Prevents clients from promoting themselves through request parameters |
| 10 | Secure invitation required for unknown clients | Establishes coach ownership and verified identity before onboarding |
| 11 | Resend over HTTPS | Railway hobby deployments may restrict SMTP; HTTPS delivery is reliable |
| 12 | Railway for Rails/PostgreSQL and Vercel for Next.js | Fits each runtime's strengths and preserves simple Git-based deployment |

---

## 8. Future Scope

- Time-based exercises such as planks and cardio.
- RPE and time under tension.
- Coach/client chat.
- Push notifications.
- Android application.
- Advanced analytics and progress charts.
- Supersets and linked exercises.
- Photo/video object storage and upload pipeline.
- Apple Sign-In UI in the web portal.
- Optional email/password authentication only if product requirements change.

---

## 9. Agent Instructions

### 9.1 General

- Write code, comments, commits, and technical documentation in English.
- Follow the conventions for the repository being changed.
- If work spans Rails, web, or iOS, implement and verify every affected side.
- When modifying the data model or a major flow, update this file and copy the
  same result to every Lactic repository.
- Keep each root `CLAUDE.md` as a relative symlink to `AGENTS.md`.
- Never commit secrets. Use environment-variable names and placeholders only.
- Preserve the invitation security invariants: hashed token, expiry,
  revocation, single use, social-email match, coach ownership, and
  server-controlled role assignment.
- Prefer the simplest v1 implementation and briefly note meaningful
  alternatives.
- Ask before proceeding only when an ambiguity materially changes the product,
  data model, security model, or external side effects.
- Produce complete working files rather than partial snippets.

### 9.2 Deployment work

- Use the explicit production project/environment/service IDs in section 2.4;
  do not rely on whichever project happens to be linked locally.
- A queued or building deployment is not a success. Wait for Railway `SUCCESS`
  or Vercel `READY` before reporting completion.
- After backend deployment, verify `/up` returns HTTP 200.
- After frontend deployment, verify the production alias points to the expected
  commit and returns HTTP 200 on a real route.
- Never print or retrieve secret values unless the user explicitly needs a
  narrowly scoped secret operation.

### 9.3 Developer context

The lead and sole developer is an experienced iOS developer with limited Rails
experience. Be concise on iOS topics and slightly more explanatory for Rails,
PostgreSQL, web deployment, and backend security decisions.
