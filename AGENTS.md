# AGENTS.md — Lactic & Lactic Studio

> This is the root agent file for the Lactic project.
> It contains domain context, architecture, data model, conventions, and general agent instructions.
>
> Platform-specific instructions live in nested AGENTS.md files within the project structure.
> This file is identical across all Lactic repositories — keep it in sync when updating.

---

## 1. Project Overview

**Lactic** (**L**egs **A**re **C**ausing **T**remendous **I**nternal **C**ramping) is an ecosystem of two iOS apps and a shared backend for gym workout management.

| App              | Target      | Platform    | Description                                                          |
| ---------------- | ----------- | ----------- | -------------------------------------------------------------------- |
| **Lactic**       | Client      | iOS         | Tracks coach-assigned workouts: logs weights, reps, notes, photos    |
| **Lactic Studio**| Coach/Admin | iOS (iPad)  | Creates training programs and assigns them to clients                |
| **Backend**      | Both        | Rails API   | Shared REST API, exercise catalog, auth, storage                     |

**Reference competitor:** CoachPlus (client) / CoachPlus PT (admin).

---

## 2. Architecture

### 2.1 Repositories

| Repo           | Contents                                                              |
| -------------- | --------------------------------------------------------------------- |
| `lactic-ios`   | iOS monorepo — two targets (Lactic + Lactic Studio) + shared packages |
| `lactic-api`   | Ruby on Rails API-only backend                                        |

### 2.2 Tech Stack

| Layer        | Technology                                       |
| ------------ | ------------------------------------------------ |
| iOS          | Swift, SwiftUI, modular Swift Packages           |
| Backend      | Ruby on Rails 8.0+ (API-only)                    |
| Database     | PostgreSQL                                        |
| Auth         | Sign In with Apple + Google Sign-In               |
| Storage      | TBD (S3/CloudFlare R2 for videos/photos)          |
| CI/CD        | GitHub Actions (future; local tests for now)      |

### 2.3 Authentication

- **Sign In with Apple** and **Google Sign-In** as the only methods.
- No email+password auth in v1.
- Backend handles JWT tokens and sessions.
- Two roles: `coach` and `client`. A user is one or the other.

---

## 3. Data Model

### 3.1 Core Hierarchy

```
Coach
 └─ Client (invited via link or email)

Program (reusable template)
 └─ Week
     └─ Workout (day: 1-7, multiple workouts per day allowed)
         └─ WorkoutExercise (order, specific configuration)
              └─ reference → Exercise (global catalog)

ProgramAssignment (coach assigns program to client)
 ├─ start_date
 └─ notes (optional)

WorkoutSession (client performs a workout)
 └─ ExerciseLog
      └─ SetLog (actual weight, actual reps)
```

### 3.2 Entity Details

#### Coach
- `id`, `name`, `email`, `avatar_url`
- Has many `Client` (via invitations)
- Has many `Program`

#### Client
- `id`, `name`, `email`, `avatar_url`
- Belongs to a `Coach`
- Has many `ProgramAssignment`
- Has many `WorkoutSession`

#### Program (template)
- `id`, `coach_id`, `name`, `description`
- Has many `Week` (variable count)
- Reusable: the same program can be assigned to different clients

#### Week
- `id`, `program_id`, `position` (order in sequence)
- Has many `Workout`

#### Workout
- `id`, `week_id`, `name` (e.g. "Chest Workout"), `day` (1-7)
- Has many `WorkoutExercise`
- Can be saved as a **standalone template** (`WorkoutTemplate`)
- Multiple workouts can exist on the same day
- Can be duplicated within the same week or across different weeks

#### WorkoutTemplate
- `id`, `coach_id`, `name`, `source_workout_id`
- Snapshot of a workout to reload elsewhere

#### Exercise (global catalog)
- `id`, `name`, `muscle_group` (e.g. "Pectoral", "Shoulders", "Quadriceps")
- `video_url` (optional), `thumbnail_url` (optional)
- `is_custom` (true if created by a coach)
- `coach_id` (null for default catalog exercises)
- Catalog is pre-populated with ~150-200 common exercises

#### WorkoutExercise (exercise within a workout context)
- `id`, `workout_id`, `exercise_id`
- `position` (letter: A, B, C, D…)
- `sets` (target set count)
- `reps` (target reps)
- `rest_seconds` (rest time)
- `rir` (Reps In Reserve, optional)
- `weight` (suggested weight, optional)
- `notes` (coach notes, optional)

#### ProgramAssignment
- `id`, `program_id`, `client_id`, `coach_id`
- `start_date`, `notes` (optional)
- `status` (active, completed, paused)

#### WorkoutSession (client logging)
- `id`, `client_id`, `workout_id`, `program_assignment_id`
- `started_at`, `completed_at`
- `notes` (client notes on the entire session)

#### ExerciseLog
- `id`, `workout_session_id`, `workout_exercise_id`
- `notes` (client notes on the exercise)
- `photo_url` (optional execution photo)

#### SetLog
- `id`, `exercise_log_id`
- `position` (1, 2, 3…)
- `weight_kg` (actual weight in kg)
- `reps` (actual reps performed)

### 3.3 Volume Sets

The system automatically calculates **volume sets per muscle group** for each workout.
Example: if a workout has 4 chest exercises with 3 sets each → "Pectoral 12".
This value is computed dynamically by summing the `sets` of `WorkoutExercise` entries grouped by the `muscle_group` of the associated `Exercise`.

---

## 4. Features by App

### 4.1 Lactic (Client)

| Feature                  | Details                                                                   |
| ------------------------ | ------------------------------------------------------------------------- |
| **View program**         | Weeks, days, workouts with exercises and coach parameters                 |
| **Execute workout**      | "Start workout" mode with built-in rest timer                             |
| **Log sets**             | For each exercise: actual weight (kg) and reps, set by set                |
| **Add extra sets**       | Client can add sets beyond the coach's target                             |
| **Notes & execution**    | Personal notes + photo per exercise                                       |
| **View coach notes**     | Coach notes are visible on each exercise                                  |
| **Exercise video**       | Playback of demo video (if available in catalog)                          |
| **Weight history**       | Chart/history of progress per exercise over time                          |
| **Accept coach invite**  | Via link or email                                                         |

### 4.2 Lactic Studio (Coach/Admin)

| Feature                    | Details                                                                 |
| -------------------------- | ----------------------------------------------------------------------- |
| **Manage clients**         | Client list, invite new ones (link or email)                            |
| **Create program**         | Add weeks, days, workouts, exercises with all parameters                |
| **Exercise catalog**       | Search/filter exercises, add custom ones with video upload              |
| **Configure exercise**     | Sets, Reps, Rest, RIR, Suggested Weight, Notes                         |
| **Duplicate workout**      | Within the same week or across different weeks                          |
| **Save workout template**  | Save any workout as a reusable template                                 |
| **Assign program**         | Assign to a client with start date + optional notes                     |
| **View client progress**   | See training logs, weights, actual reps                                 |
| **Volume sets**            | Automatic set count per muscle group per workout                        |
| **Estimated duration**     | Automatically calculated (like the competitor's "29-38 min")            |

---

## 5. Key Flows

### 5.1 Coach creates and assigns a program

1. Coach opens Lactic Studio → Creates new Program (name, description)
2. Adds Weeks (1, 2, …N)
3. For each week, adds Workouts on days (1-7)
4. For each workout, adds exercises from catalog with sets/reps/rest/rir/notes
5. Can duplicate workouts across days/weeks or load from template
6. Saves the program
7. Assigns it to one or more clients (start date + notes)

### 5.2 Client executes a workout

1. Client opens Lactic → Sees active program, current week
2. Selects the day's workout
3. Sees exercises with coach parameters and notes
4. Taps "Start workout"
5. For each exercise: enters weight and reps per set
6. Can add extra sets, personal notes, photos
7. Rest timer starts automatically between sets
8. On completion, the session is saved to history

### 5.3 Coach → Client invitation

1. Coach generates an invite link or enters client's email
2. Client receives link/email → opens Lactic → accepts invite
3. From that point on, the client is linked to the coach and receives assigned programs

---

## 6. Development Conventions

### 6.1 iOS (lactic-ios)

- **Language:** Swift 6.x
- **UI:** SwiftUI
- **Architecture:** TBD (recommended: MVVM with coordinators or TCA)
- **Modularization:** Domain-separated Swift Packages
  - `LacticKit` — models, networking, API client, persistence
  - `LacticUI` — reusable UI components shared between both apps
  - `LacticCore` — utilities, extensions, shared constants
- **Naming:** PascalCase for types, camelCase for properties/methods
- **Minimum target:** iOS 26+
- **Devices:** Lactic → iPhone, Lactic Studio → iPad (iPhone support planned later)

### 6.2 Rails (lactic-api)

- **Ruby:** 3.3+, **Rails:** 8.0+ (API-only)
- **Database:** PostgreSQL
- **API:** RESTful, JSON, versioned (`/api/v1/`)
- **Naming:** snake_case for everything (Ruby convention)
- **Auth:** JWT with refresh tokens
- **Testing:** Minitest or RSpec (TBD)
- **Serialization:** TBD (jbuilder, blueprinter, or alba)

### 6.3 Git

- **Branch model:** `main` (production), `develop` (integration), `feature/*`, `fix/*`
- **Commits:** English messages, conventional format (e.g. `feat: add workout duplication`)
- **PRs:** Required for every feature, even as a solo developer (good practice for history)

---

## 7. Architectural Decision Records (ADR)

| # | Decision                                                 | Rationale                                                    |
|---|----------------------------------------------------------|--------------------------------------------------------------|
| 1 | Rails API-only (no server-side views)                    | Maximum flexibility for iOS client today and web tomorrow    |
| 2 | iOS monorepo with two targets                            | Share code (models, networking, UI) between both apps        |
| 3 | Program as a reusable template                           | Same program can be assigned to N clients with different dates|
| 4 | WorkoutTemplate as a separate entity                     | Allows saving/reloading workouts independently               |
| 5 | Sign In with Apple + Google only (no email+password)     | v1 simplicity, less auth complexity                          |
| 6 | Reps only (no Time mode), RIR only (no RPE, no TUT)     | Reduced v1 scope, extensible in the future                   |
| 7 | Pre-populated exercise catalog + coach custom exercises  | Immediate UX for the coach, with flexibility to customize    |

---

## 8. Future Scope (not v1)

- Time-based mode (plank, cardio)
- RPE and TUT
- Coach ↔ client messaging/chat
- Email+password auth
- Android app (Kotlin/Jetpack Compose)
- Web frontend for Lactic Studio
- Push notifications
- Advanced analytics / progress charts
- Supersets / linked exercises

---

## 9. Agent Instructions

### 9.1 General

- Write **code and comments in English** (variable names, classes, commits, technical docs).
- Follow the conventions in section 6.
- If a request touches both iOS and Rails, address both sides.
- When modifying or extending the data model, also update this file to keep documentation in sync.
- Be direct and practical. Less boilerplate, more substance.
- When multiple valid approaches exist, recommend the simplest one for v1 and briefly mention alternatives.
- If a request is ambiguous, ask before proceeding.
- When generating code, produce complete, working files — not partial snippets.

### 9.2 Developer Context

The lead (and sole) developer is an experienced iOS developer with limited Rails knowledge. Adapt explanations accordingly: be concise on the iOS side and more didactic on the Rails side.
