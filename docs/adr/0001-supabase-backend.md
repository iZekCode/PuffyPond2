# ADR 0001: Supabase backend decisions

- Status: accepted
- Date: 2026-11-04
- Backlog: [supabase-rebuild-backlog.md](../supabase-rebuild-backlog.md)
- Data model: [supabase-erd.md](../supabase-erd.md)

## Context

Puffy Pond is a children's rehabilitation-style painting app. Today everything stays on the device (`Application Support/Gallery/`, one PNG and one JSON sidecar per painting) with no network and no accounts. The rebuild adds a Supabase backend. Because the users are children and the movement stats are health-adjacent, the decisions below set what leaves the device, who owns it, and who can act on it.

## Decisions

### 1. Platform: iPad only, landscape, full screen

`UIRequiresFullScreen = YES`, no Mac, Catalyst, Stage Manager or split view. This removes live window resizing from `CanvasLayout` and `EaselScene`.

### 2. Auth: anonymous first, upgrade to Sign in with Apple

After consent (decision 4) the app signs in anonymously, so a child can paint without any account screen. The anonymous user is later upgraded with `linkIdentity` (Sign in with Apple), which keeps the same `user_id`, so no data migration is needed. The upgrade button sits behind the parental gate. Sign in with Apple needs no separate review, only the paid Apple Developer account that TestFlight needs anyway. Google sign-in is not offered, so guideline 4.8 is satisfied by Sign in with Apple alone.

Consequence: if the app is deleted or the iPad is replaced before the account is linked, the anonymous user and its data are orphaned. The upgrade prompt must be visible enough to prevent this.

### 3. Data owner: one account is one child

`profiles` is 1:1 with `auth.users`. Row level security is `user_id = auth.uid()` everywhere. No child-profile switching and no parent-with-many-children model in v1.

### 4. Consent and parental gate: consent first, plus a gate for sensitive actions

A consent screen (privacy policy link, parent confirmation) is shown before the first launch flow. No anonymous user is created before consent. The app stores the consent locally and in `profiles` (`consented_at`, `consent_version`); a new `consent_version` asks again. A separate parental gate protects: linking Sign in with Apple, deleting the account, and any link out of the app.

### 5. What is uploaded

- Painting PNG: yes.
- Session stats (ROM, heatmap, grip cycles, hand dominance, as one JSON document): yes.
- Timelapse recording: no in v1. It stays on the device. `paintings.recording_path` is reserved and null, and a `recordings/` path is reserved in Storage. Before uploading, measure size (average and p95), use a compact binary format, upload lazily on Wi-Fi, and cap the size per recording.
- Raw camera frames: never.

A painting restored from the server without a recording opens like a legacy painting: interactive immediately, no Replay.

### 6. Source of truth: local first, sync in the background

The UI reads and writes only the local store. A sync engine pushes through an outbox with retry and backoff, and pulls on a new device or after reinstall.

- Painting ids are UUIDs created on the client, so retries are idempotent. Upload the PNG first, then insert the row.
- Conflicts: last write wins (one account, one child, paintings are close to immutable).
- Deletes are tombstones (`deleted_at`) so they propagate and relock templates correctly.
- Uploads use a background `URLSession`.

### 7. Daily quest: computed on the client, same for every child

`quest(for date)` picks from the fixed pool by a stable hash of the local date (never Swift's per-launch randomized `Hasher`), and is never the same as the previous day's pick. A `questPoolVersion` guards the pool: entries are only appended, or the version is bumped when the pool changes. No `daily_quest` table, no server involvement. The `QuestSource` protocol allows a server source later.

### 8. Templates: fixed, authored, ported from the existing app

The nine abstract templates and the ten-quest pool already exist in `Templates/Core` and are ported. Template difficulty and reach are authored on purpose to widen range of motion, so they are not generated. A `TemplateSource` seam is kept in Core so a generated source (Image Playground plus Vision contours, in free mode) can be added after v1 without touching the pages.

## Consequences

- Backend scope is small: `profiles`, `paintings`, `painting_stats`, one private Storage bucket, and a `delete-account` edge function.
- Account deletion must also remove Storage objects, which do not cascade from the database. This is required by App Store guideline 5.1.1(v) and applies to anonymous accounts too.
- Privacy policy and consent text must name the uploaded movement stats.
- Onboarding gains one screen (consent) and the app gains one reusable parental gate, about half a day of work.
- If the app is later placed in the Kids Category, guideline 1.3 limits third-party analytics and ads and expects a parental gate for outbound links.

## Rejected alternatives

- Online-first: fails offline and makes every save wait for the network.
- Parent account with many child profiles: more RLS and UI than 12 days allow, and no current need.
- Server-generated daily quest: adds a table, a function and an offline cache for no gain, since a date hash already gives every child the same quest.
- Uploading the timelapse in v1: size is unmeasured and the timing data is more sensitive than the final painting.
- Generating templates with an on-device model: not deterministic across devices, cannot guarantee therapeutic difficulty, and needs Apple Intelligence capable devices.
