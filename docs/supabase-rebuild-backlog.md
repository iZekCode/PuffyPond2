# Supabase rebuild: backlog and chunking

Plan for rebuilding Puffy Pond from scratch with a Supabase backend. This document orders the work into chunks and marks what can run in parallel and what must run in sequence.

## Scope and decisions

- **Platform:** iPad only, landscape, full screen only (`UIRequiresFullScreen = YES`). No Mac, Catalyst, Stage Manager or split view.
- **Backend:** Supabase for auth, Postgres (paintings, session stats, daily quest) and Storage (painting PNGs).
- **Engine unchanged in kind:** Metal wet-paint simulation, SceneKit stages, Vision hand and body pose, all on device.
- **Local first:** every page must work against a local gallery store, so feature work never waits on the network. Supabase sync is layered on top.
- **Privacy:** the camera feed never leaves the device. Only derived movement stats are uploaded. The app is for children and the stats are health-adjacent, so row level security is strict and the Storage bucket is private.
- **Code layout:** keep the existing feature grouping, each feature split into `Core/` (pure logic, unit tested), `Shell/` (SceneKit, Metal, camera, audio, files, network) and `Views/` (SwiftUI).

This reverses the current README promise of "No network, no accounts". Wave 0 decides how.

## Legend

- **SEQ**: must run after the chunks it depends on, and usually blocks others.
- **PAR**: can run in parallel with other PAR chunks in the same wave, once its dependencies are done.
- **Needs**: the chunks that must be finished first.

## Wave 0: Foundations (all SEQ)

| ID | Chunk | Mode | Needs | Done when |
|---|---|---|---|---|
| 0.1 | Product decisions and ADR | SEQ | none | ADR records: auth model (Sign in with Apple, anonymous-first or not), parental consent approach for a children's app, what is synced (PNG, stats, timelapse or not), local-first sync policy, what is never uploaded |
| 0.2 | Project skeleton | SEQ | 0.1 | iPad-only Xcode project, landscape lock, `UIRequiresFullScreen`, feature folders, test target, CI, `supabase init` with local stack, `supabase-swift` via SPM |
| 0.3 | Contracts | SEQ | 0.2 | Draft DB schema, domain types (`Painting`, `SessionStats`, `TemplateID`), and repository protocols (`GalleryRepository`, `StatsRepository`, `QuestSource`). This is the seam that lets Wave 1 run in parallel |

## Wave 1: Four parallel lanes

Chunks inside a lane are SEQ unless noted. The lanes are PAR with each other.

### Lane A: Backend

| ID | Chunk | Needs |
|---|---|---|
| A1 | Migrations: `profiles`, `paintings`, `painting_stats`, `daily_quest` | 0.3 |
| A2 | Row level security policies | A1 |
| A3 | Storage bucket `paintings` (private) and its policies | A1 |
| A4 | pgTAP tests for RLS and Storage access | A2, A3 |
| A5 | Edge function or cron for the daily quest (optional; the client can roll it locally from a seeded pool) | A1 |

### Lane B: Input

| ID | Chunk | Mode | Needs |
|---|---|---|---|
| B1 | `HandTracker`, `HandPose`, `OneEuroFilter` (camera plus Vision, open/fist with hysteresis, smoothing) | PAR | 0.2 |
| B2 | `DistanceGate`, `SwipeDetector`, `HandFrameRelay` | PAR | 0.2 |
| B3 | Touch and Apple Pencil fallback input | PAR | 0.2 |

### Lane C: Paint engine

| ID | Chunk | Needs |
|---|---|---|
| C1 | `PaintLayer` and Metal shaders (dabs, advection, leveling, mixing, drips, drying, normal map) | 0.2 |
| C2 | Pure rules: `BrushStyle`, `StrokeBook`, `StrokePath`, `CanvasLayout` (fixed per-device fit, no live resize), `PotRub`, `Paint`, `PaintTool` | 0.3 |
| C3 | `EaselScene`, `Studio`, `Toybox`, photo booth | C1, C2 |
| C4 | Performance gate: frame budget measured on a non-Pro iPad before any feature is stacked on the engine | C3 |

Until Lane B lands, C1 to C3 use a fake point-stream input.

### Lane D: Independent pieces (all PAR)

| ID | Chunk | Needs |
|---|---|---|
| D1 | Audio: `GrooveDSP`, sound effects, beat clock | 0.2 |
| D2 | Templates: `TemplateCatalog`, `OutlineArt`, `DailyQuest` (pure, against `QuestSource`) | 0.3 |
| D3 | Treehouse garden theme and shared visual tokens | 0.2 |
| D4 | `AppRouter`, `Route`, Home page | 0.2 |

## Wave 2: Backend bridge

| ID | Chunk | Mode | Needs |
|---|---|---|---|
| E1 | Auth: Sign in with Apple, session in Keychain, restore on launch | SEQ | A1, 0.2 |
| E2 | `LocalGalleryStore`: file-based implementation of `GalleryRepository` and `StatsRepository` | PAR with E1, E3 | 0.3 |
| E3 | `SupabaseGalleryRepository` and `SupabaseStatsRepository`: Storage upload plus row insert | PAR with E2 | A2, A3, E1 |
| E4 | Sync engine: offline queue, retry, last-write-wins, deletion propagation (deleting a painting relocks its template), uploads through a background `URLSession` | SEQ | E2, E3 |

E2 is deliberately early so that Wave 3 never depends on the network.

## Wave 3: Feature pages

| ID | Chunk | Mode | Needs |
|---|---|---|---|
| F1 | `Critter` base: body rig, face nodes, springs, moods (`CritterKind`, `Springs`, `Face`, `BuddyMode`, `LimbBundle`) | SEQ | C3 |
| F2 | Ladybug (and `LimbBrush`) | PAR | F1 |
| F3 | Butterfly | PAR | F1 |
| F4 | Mushroom | PAR | F1 |
| F5 | Snail | PAR | F1 |
| G1 | Get ready page (skeleton outline, distance ring, Skip) | PAR | B2, D4 |
| G2 | Review page: `SheetSolver`, `SheetGestures`, `ReviewStage` | PAR | B1, C1, E2 |
| G3 | Gallery: 3D treehouse hall plus 2D grid | PAR | D3, E2 |
| G4 | Report: calendar, `DayReport`, heatmap, hand dominance | PAR | E2 |
| H1 | Canvas page: pots and bubbles, `Playground`, `SessionRecorder`, Save flow, eye/HUD | SEQ | B1, B3, C4, D1, D2, F2 to F5, E2 |

## Wave 4: Final layers

| ID | Chunk | Mode | Needs |
|---|---|---|---|
| I1 | Timelapse: `StrokeRecording`, replayers, renderer. Decide first whether recordings are uploaded to Storage | SEQ | H1 |
| I2 | NCA model: training tools and `nca.bin` packaging | PAR with I1 | 0.2 |
| I3 | Hardening: RLS audit, account and data deletion, privacy review for children, iPad model by iPadOS version test matrix, observability, TestFlight | SEQ | everything else |

## Critical path

```
0.1 -> 0.2 -> 0.3 -> A1 -> A2/A3 -> E1 -> E3 -> E4 -> (Supabase-backed Gallery and Report) -> I3
```

The engine path (Lane B, Lane C, F1 to F5, H1) is not on the critical path, so it can run fully in parallel with the backend path. It only needs `LocalGalleryStore` (E2) to finish the Canvas page.

## Risks

- **0.1 is the biggest risk.** A wrong call on consent, auth or what gets uploaded forces schema and RLS rework.
- **Metal performance on older iPads** (C4). Measure before building on top of the engine.
- **Screen size variance.** Full screen only removes resizing, but iPad models differ in aspect ratio, so test `CanvasLayout` on at least two or three sizes.
- **Pose stats are 2D estimates** from the front camera, not clinical measurements. Keep that wording in any user-facing privacy or data text.

## Suggested split into sessions

Lanes A, B, C and D are independent enough for separate sessions or worktrees once Wave 0 is merged. Lanes that write the same files should not run together: A is backend files only, B is `Input/`, C is `Canvas/`, D touches `Audio/`, `Templates/`, `App/` and `Home/`.
