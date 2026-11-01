# App Flow Update Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Puffy Pond from a single easel screen into a guided app: Home → choose freeform or a template → distance check with a skeleton → canvas → review & save → walkable 3D gallery, plus a Report page with a calendar and per-day movement stats (highest ROM, heatmap, hand dominance). The AI diffusion "Magic" mode is removed.

**Branch:** `feat/app-flow-update`

**Architecture:** One root `AppRouter` (`@Observable`) owns the current `Route` and swaps full-screen SwiftUI pages in `ContentView`. `Playground`, `HandTracker` and `Gallery` stay single long-lived objects owned by `ContentView`, exactly like today. The camera keeps running on every page that needs hands (instruction, canvas, 3D gallery). `Playground.isAway` stays the switch that stops the easel from reacting while another page is up. Saved paintings get a JSON sidecar next to the PNG with the template used and the movement stats of that drawing session; the Report page reads only those sidecars.

**Tech Stack:** Swift 6 / SwiftUI / SceneKit (existing), Vision (`VNDetectHumanHandPoseRequest` existing, plus `VNDetectHumanBodyPoseRequest` new), Swift Testing. No new packages; the `ml-stable-diffusion` package is removed.

**Spec:** the sketch + request in this conversation (2026-11-01).

## Flow

```
Home ──► Start drawing ──► Mode picker ──► Freeform ─────────────────┐
  │                              └──► Templates page ── pick 1 ──────┤
  │                                   (daily quest on top,           ▼
  │                                    easy → hard list,       Instruction page
  │                                    progressive unlock)    (skeleton, ~1 m, auto-next)
  │                                                                  ▼
  │                                                            Canvas page
  │                                                         (fist paints, 5 tools, "Save image")
  │                                                                  ▼
  │                                                            Review page
  │                                                    (push & grab sheet, "Save to gallery")
  │                                                                  ▼
  ├──► View gallery ───────────────────────────────────────► 3D Gallery (paddle to walk)
  │                                                          ├─ "View in 2D" (bottom-left) ─► 2D grid
  │                                                          └─ "Home"
  └──► Report ──► calendar (left, marked days) + day detail (right)
```

## Assumptions (confirm before Task 4+)

| # | Question | Assumption used in this plan |
|---|---|---|
| A1 | Template tray bubbles on the canvas (fish/turtle/duck) | Removed. The template is chosen before the canvas and shown when the canvas opens. Fist still wipes the dotted guide. |
| A2 | Template content ("hewan, karakter, apapun") | Ship 9 templates: 3 easy, 3 medium, 3 hard, as SVG path strings in the existing `TemplateKind` format. Existing fish/duck/turtle become easy/easy/medium. New outlines are a content task (Task 4, step 1). |
| A3 | Progressive unlock rule | Templates are one ordered list. Template *n+1* unlocks once at least one painting made with template *n* is saved to the gallery. The first easy one is always unlocked. |
| A4 | Daily quest | **Decided:** truly random, not taken from the templates list. A separate quest pool (`QuestCatalog`, own outlines/subjects). On the first visit of a day one quest is rolled with `SystemRandomNumberGenerator` and stored for that day (`UserDefaults`, key = local date), so it doesn't re-roll every time the page opens; it avoids yesterday's quest. A saved quest painting does not unlock templates; it marks "quest done" for that day. |
| A5 | Distance check | Body pose shoulder width in the camera frame is the distance proxy. "OK" = shoulders inside the skeleton band (calibrated to ~1 m on iPad front camera) and both shoulders visible for 1.5 s continuously, then auto-advance. A "Skip" button stays for touch/no-camera mode. |
| A6 | ROM | Per arm, from 2D body pose + hand pose (front camera, ~1 m). See "ROM metrics" below. Headline "Highest ROM" on Report = shoulder abduction; the others are shown as secondary rows. All are 2D camera estimates, not clinical. |
| A7 | Heatmap | Where the drawing hand(s) were on the canvas while making a fist (painting): 32×20 grid of time spent, both hands together, shown over a faint canvas frame. Day view sums all sessions that day. |
| A8 | Hand dominance | Share of fist (painting) time by the left vs right hand, e.g. "Right 68% · Left 32%". Left/right = the person's hands (mirrored front camera taken into account), not screen sides. |
| A11 | Canvas controls | **Decided:** no pinch. Open hand = move the character only (no paint). Fist = paint. Five characters: thick oil (impasto), liquid oil (runny/glaze), regular brush line, eraser, blender (smudges/mixes wet paint). The current pinch + six brush animals + starfish-on-fist mechanic is kept in code behind `ControlScheme.legacy` (not deleted), default `.fist`. |
| A12 | Review page gestures | **Decided:** InterARTive-style push and grab, applied to the whole painting as one elastic sheet (not per stroke). Fist = grab, two fists = stretch/twist, open palm moving = push (ripples). Release → springs back to the original. Purely for play; the saved image is always the undeformed original. |
| A9 | Paddle gesture in 3D gallery | One paddle stroke = an open hand sweeping downward and back across ≥ 25% of the frame height within 0.8 s. A stroke on the right side → next painting, left side → previous painting. Swipe and on-screen arrows stay as fallback. |
| A10 | Review page "back" | Review has "Save to gallery" and "Keep drawing" (returns to the same canvas, paint untouched). Leaving the canvas to Home without saving asks to confirm. |

## ROM metrics (what a front camera at ~1 m can measure)

Vision body pose gives neck, shoulders, elbows, wrists, hips (+ face, knees). Hand pose gives 21 hand joints. The camera sees the person head-on, so only movement **in the frontal plane** (parallel to the screen) is measured well. Movement toward/away from the screen is foreshortened.

| Metric | How | Reliability | Use |
|---|---|---|---|
| **Shoulder abduction** (arm raised out to the side) | angle between upper arm (shoulder → elbow) and trunk (shoulder → hip on the same side; fallback: perpendicular to the shoulder line if hips aren't visible) | Good — fully in the frontal plane | **Headline "Highest ROM"**, L/R |
| **Elbow extension** (how straight the arm gets) | angle shoulder–elbow–wrist | OK when reaching sideways/up, under-reads when reaching toward the screen | secondary, L/R |
| **Reach height** | highest wrist point relative to the shoulder, in shoulder-widths (above shoulder = positive) | Good, simple to understand ("hand went 0.8 shoulder-widths above the shoulder") | secondary, L/R |
| **Reach area** (workspace) | area of the convex hull of wrist positions, in shoulder-widths² | Good | secondary, L/R (pairs with the heatmap) |
| **Wrist radial/ulnar deviation** | angle forearm (elbow → wrist) vs hand (wrist → middle MCP) | Fair, only when the palm faces the camera | optional, later |
| **Hand open/close** (grip) | finger extension from hand pose; count fist ↔ open cycles and max hand spread (thumb tip ↔ little tip / hand size) | Good — the canvas already uses fist/open | secondary: "N grip cycles" |
| **Trunk lean** (compensation) | tilt of the shoulder line / neck–root line | Good | flag only: "leaned to reach" when > 15° |

Not measurable with this setup: shoulder flexion/extension (forward raise), rotation, wrist flexion/extension, pronation/supination — all happen toward the camera.

Each angle sample is used only when both joints have confidence ≥ 0.5, and the session max is taken over a 0.3 s median filter so a single bad frame can't create a fake record.

## Global Constraints

- iOS 17 / macOS 14 deployment targets unchanged. iPad landscape is the primary layout (keep the recent landscape work); Mac must still build and run.
- Existing saved PNGs must keep showing in the gallery after the update (they get a sidecar with `template = nil`, stats = nil on first launch).
- Stats are recorded only while on the canvas page and only from camera hands (touch/mouse drawing records nothing, Report shows "no movement data").
- No network, no accounts. All data stays in `Application Support/Gallery/`.
- Each task leaves the app building and runnable on iPad and Mac.

## Review Focus

1. **Navigation while the camera is running.** Leaving the canvas mid-stroke must finish or drop the stroke and stop recording stats. Pinned in Task 2 and Task 6b.
2. **Unlock state is derived, never stored.** Unlocks are computed from saved painting sidecars, so removing a painting can re-lock a template. Decide and pin in Task 4 (`unlockFollowsSavedPaintings`).
3. **Old paintings without sidecars.** Pinned in Task 3 (`legacyPngGetsEmptyRecord`).
4. **Mirrored camera vs left/right hand.** Pinned in Task 6b (`dominanceUsesPersonSides`).
5. **Fist hysteresis on the canvas.** A loose fist must not drop paint mid-stroke; open hand must never paint. Pinned in Task 6a.
6. **Body pose cost.** Body pose runs only while the instruction page or canvas page is open (ROM), not in the gallery. Check frame time on iPad in Task 5.

---

## Task 1: Remove AI Magic mode

**Files:** delete `PuffyPond/Magic/*`, `PuffyPondTests/Magic*Tests.swift`, `PuffyPondTests/TestImages.swift` (if only Magic uses it), `tools/magic/`. Move `docs/superpowers/plans/2026-11-01-ai-magic-*.md` to `docs/archive/` (done while planning). Modify `PuffyPond.xcodeproj/project.pbxproj`, `Playground.swift`, `HUDView.swift`, `ContentView.swift`.

- [ ] Remove `magic`, `magicOverlay`, `blankPhoto`, `setUpMagic`, and every `magic?.…` call in `Playground.swift` (lines ~39–130, 412, 481, 500, 550, 630).
- [ ] Remove `MagicButton` and the `magicStore` parameter from `HUDView`; remove `magicStore` from `ContentView`.
- [ ] Remove the `ml-stable-diffusion` `XCRemoteSwiftPackageReference`, its product dependency and the Magic file references from `project.pbxproj` (open in Xcode to verify, `Package.resolved` updates).
- [ ] Build for iPad simulator and Mac. Run remaining tests.
- [ ] Commit: `refactor: remove the AI magic mode`.

## Task 2: Navigation shell and Home page

**Files:** create `PuffyPond/App/AppRouter.swift`, `PuffyPond/Pages/HomeView.swift`; modify `ContentView.swift`.

- [ ] `enum Route: Equatable { case home, modePicker, templates, instruction(TemplateChoice?), canvas(TemplateChoice?), review(ReviewDraft), gallery3D(start: Int, justHung: Bool), gallery2D, report }`. `TemplateChoice` = template id + `isDailyQuest`.
- [ ] `AppRouter` (`@Observable`): `route`, `go(_:)` with a 0.35 s cross-fade, `home()`.
- [ ] `ContentView` becomes a `switch router.route`. `PlaygroundView` stays alive underneath (only shown/active on `.canvas`) so SceneKit isn't rebuilt each time; `playground.isAway = route != .canvas`.
- [ ] `HomeView`: title, three big rounded buttons — **Start drawing**, **View gallery**, **Report** — reusing the HUD's rounded style. Usable by touch (the hands are not in the camera yet on Home).
- [ ] App launches on Home. Commit: `feat: add the home page and app routing`.

## Task 3: Painting records (sidecar metadata)

**Files:** modify `Gallery.swift` (split into `Gallery/PaintingStore.swift` + `Gallery/GalleryHall.swift` if it helps), create `PuffyPond/Stats/SessionStats.swift`; test `PuffyPondTests/PaintingStoreTests.swift`.

- [ ] `struct SessionStats: Codable` — `duration`, `romDegrees: [Side: Double]` (max), `heatmap: [UInt16]` (32×20) , `pinchSeconds: [Side: Double]`.
- [ ] `struct PaintingRecord: Codable` — `date`, `templateID: String?`, `isDailyQuest: Bool`, `stats: SessionStats?`. Saved as `painting-<ms>.json` next to `painting-<ms>.png`.
- [ ] `Painting` gains `record`. `Gallery.add(_ image:, record:)`; `remove` deletes both files; `reload` builds an empty record for a PNG without sidecar.
- [ ] Queries for later tasks: `paintings(on day: Date)`, `daysWithPaintings(in month:)`, `savedTemplateIDs`.
- [ ] Tests: `legacyPngGetsEmptyRecord`, `addWritesSidecar`, `removeDeletesBoth`, `paintingsGroupByLocalDay`.
- [ ] Commit: `feat: store template and session stats with each painting`.

## Task 4: Templates — catalog, unlock, daily quest, pages

**Files:** modify `Template.swift`; create `PuffyPond/Templates/TemplateCatalog.swift`, `PuffyPond/Pages/ModePickerView.swift`, `PuffyPond/Pages/TemplatesView.swift`; test `PuffyPondTests/TemplateCatalogTests.swift`.

- [ ] Content: add 6 new outlines (A2) as SVG paths + eye points + suggested color. `TemplateKind` gets `id`, `title`, `difficulty: .easy/.medium/.hard`; `TemplateCatalog.ordered` is the unlock order (easy → hard).
- [ ] `TemplateCatalog.isUnlocked(_:saved:)` (A3).
- [ ] `QuestCatalog` (separate pool, ~10 quest outlines/subjects, own content) + `DailyQuestStore.quest(for date:)` (A4): rolls randomly once per local day, persists the roll, never repeats yesterday. Random generator injected for tests.
- [ ] Tests: `firstEasyAlwaysUnlocked`, `unlockFollowsSavedPaintings`, `unlockIsProgressiveNotSkipping`, `dailyQuestStableWithinDay`, `dailyQuestRerollsNextDay`, `dailyQuestNeverRepeatsYesterday`.
- [ ] `ModePickerView`: two cards — **Freeform** → `.instruction(nil)`, **Choose template** → `.templates`. Back to Home.
- [ ] `TemplatesView` (as in the sketch): daily quest card on top (badge "Daily quest", done-check if a quest painting was saved today), then sections Easy / Medium / Hard with icon tiles (reuse `TemplatePot.iconImage` drawing). Locked tiles greyed with a lock and "Save a painting of <previous> to unlock". Tap unlocked → `.instruction(choice)`.
- [ ] Commit: `feat: add template picker with progressive unlock and daily quest`.

## Task 5: Instruction page — distance check with skeleton

**Files:** modify `HandTracker.swift` (body pose), create `PuffyPond/Pages/InstructionView.swift`, `PuffyPond/Input/DistanceGate.swift`; test `PuffyPondTests/DistanceGateTests.swift`.

- [ ] `HandTracker`: optional `VNDetectHumanBodyPoseRequest` in the same frame handler, toggled by `bodyPoseEnabled`. New `BodyFrame` (shoulders, elbows, wrists, neck, normalized image points + confidence) delivered via `onBody`.
- [ ] `DistanceGate` (pure, testable): input shoulder width + center + timestamps → `.noPerson / .tooClose / .tooFar / .offCenter / .holding(progress) / .ready`. Band constants calibrated on a real iPad at 1 m (record the measured shoulder width in a comment).
- [ ] Tests: `farThenNearReportsDirection`, `readyAfterHoldOnly`, `briefDropoutDoesNotReset` (≤ 0.3 s).
- [ ] `InstructionView`: live camera preview (mirrored) with a fixed target skeleton/silhouette outline; live detected shoulders/arms drawn on top; outline turns green when in band; text hint ("Step back a little", "Come closer", "Stand in the middle"); progress ring; auto `router.go(.canvas(choice))` on `.ready`. Skip button.
- [ ] Commit: `feat: add the distance check instruction page`.

## Task 6a: Canvas controls — fist paints, five characters

**Files:** modify `HandInput.swift`, `Playground.swift`, `Critter.swift`, `Characters.swift`, `PaintLayer.swift` / `PaintShaders.metal` (blender), `HUDView.swift`; create `PuffyPond/Canvas/ControlScheme.swift`, `PuffyPond/Canvas/PaintTool.swift`; test `PuffyPondTests/ControlSchemeTests.swift`.

- [ ] `enum ControlScheme { case fist, legacy }` on `Playground` (default `.fist`). `legacy` = today's behaviour untouched (pinch paints, six brush animals, fist = starfish eraser, clap inflates). All new behaviour sits behind `.fist`; no legacy code is deleted.
- [ ] Mapping in `.fist`: `HandPose.open` → character follows the hand, no paint; `HandPose.fist` → paint with the hand's current tool. Pinch is ignored (treated as open). Clap-to-inflate is off in `.fist` (saving goes through Save image). Tune fist hysteresis so a loose fist doesn't flicker mid-stroke (enter ≤ 0 extended fingers for 2 frames, exit ≥ 2 extended for 3 frames).
- [ ] `enum PaintTool { thickOil, liquidOil, brush, eraser, blender }`, one character each (reuse/restyle existing rigs: thick oil ← snail/knife `BrushStyle`, liquid oil ← jellyfish/watery, brush ← seahorse or octopus bristles, eraser ← starfish, blender = new character).
  - Thick oil: heavy impasto dabs, high paint height, slow drying, ridged edges.
  - Liquid oil: thin, translucent, runs/drips more, spreads (leveling up).
  - Brush: normal-width bristle line, the everyday stroke.
  - Eraser: existing starfish erase path (also wipes the template dots).
  - Blender: no new paint; smears and mixes wet paint under it (new `BrushStyle.blend` in the compute shader using the existing advection + color mixing, zero deposit).
- [ ] Tool switching: the existing "rub a bubble" mechanic with five tool bubbles (left column), colors from the paint pots (right column) as today. Eraser and blender ignore color.
- [ ] Tests (pure parts): `openHandNeverPaints`, `fistPaintsWithCurrentTool`, `pinchIsTreatedAsOpen`, `legacySchemeUnchanged`.
- [ ] Update the HUD hint texts and the guide card for the new controls.
- [ ] Commit: `feat: paint with a fist and five paint characters (legacy controls kept)`.

## Task 6b: Canvas page flow + session recording

**Files:** modify `Playground.swift`, `HUDView.swift`; create `PuffyPond/Stats/SessionRecorder.swift`; test `PuffyPondTests/SessionRecorderTests.swift`.

- [ ] `Playground.begin(template: TemplateKind?)`: clears the canvas, shows the chosen outline (existing `showTemplate`), resets recorder. Remove the tray template pots (A1) and `PotTarget.template` (in `.fist` scheme; legacy keeps them).
- [ ] `SessionRecorder` (pure): fed each tick with hand states (pose, canvas position, side) and body/hand frames → accumulates fist (painting) seconds per side, heatmap cells, grip cycles, and the ROM metrics from the "ROM metrics" section per side (A6–A8). `finish() -> SessionStats`.
- [ ] Tests: `dominanceUsesPersonSides`, `heatmapCountsOnlyFistOnCanvas`, `romTakesMaxAngle`, `romAngleOfHorizontalArmIs90`, `lowConfidenceJointsIgnored`, `singleFrameSpikeIgnored`, `gripCycleCountsFistOpenPairs`.
- [ ] HUD: replace the pink "frame" button with a labeled **Save image** button; add a **Home** button (confirm if there's paint). Remove gallery button from canvas HUD (gallery is reached from Home / after save).
- [ ] Save image → `playground.finishPainting()` (no longer clears the canvas immediately) → `router.go(.review(draft))` where `ReviewDraft` = image + template choice + stats.
- [ ] Commit: `feat: start the canvas from a template and record movement stats`.

## Task 7: Review page with push & grab (whole painting)

**Files:** create `PuffyPond/Pages/ReviewView.swift`, `PuffyPond/Review/SheetSolver.swift`, `PuffyPond/Review/SheetGestures.swift`, `PuffyPond/Review/ReviewStage.swift` (SceneKit); test `PuffyPondTests/SheetSolverTests.swift`, `PuffyPondTests/SheetGesturesTests.swift`.

Ported from InterARTive (`Deformation/DeformationSolver.swift`, `Deformation/Manipulation.swift`, `Deformation/RippleField.swift`, docs/ARCHITECTURE.md §6–7), changed from "per stroke" to "one sheet":

- [ ] `SheetSolver`: the painting is a grid of nodes (≈ 48×30, matching the 6.4:4 aspect), state = rest + displacement, fixed 240 Hz substeps. Rest spring (≈ 1 Hz, damping ratio ≈ 0.6, saturating pull `k·d/(1+|d|/sat)`), Laplacian smoothing of displacement over grid neighbours (keeps the sheet coherent, never tears), speed clamp, sleep when settled. Same "removing the input is the release" rule.
- [ ] `SheetGestures` (pure state machine, from InterARTive's interaction states): IDLE → GRABBING (1 fist) → STRETCHING (2 fists) → RELEASING; PUSHING (open palm moving, no grabs).
  - Grab (fist): weights by **2D distance on the sheet** `exp(−(d/σ)²)` (σ ≈ 25% of the sheet width) instead of arc length; target = start + delta·w; heavy follow (lag + swing), like InterARTive's fist grab.
  - Stretch (two fists): similarity transform between the starting and current hand pair (scale clamped 0.3–3.5, rotation = twist), weights by projection onto the hand-pair segment with falloff outside it.
  - Push (open palm, speed > threshold): radial repel + drag of nodes inside the palm radius, plus ring ripples.
  - Tracking lost mid-grab = release (sheet can never get stuck deformed).
- [ ] `ReviewStage`: SceneKit plane with the grid as custom `SCNGeometry`, the photo as texture, vertex positions updated each frame from the solver, ripple wobble in a shader modifier (≤ 16 ring waves, ~2 s fade). Light gloss so the sheet reads as "wet canvas".
- [ ] Hands on screen as small cursors (open/fist icon) so the person sees what they're grabbing. Sound cues from `GrooveDSP` (boing on release, splash on push).
- [ ] Tests: `releasedSheetReturnsToRest`, `grabMovesNearNodesMoreThanFar`, `stretchScalesBetweenHands`, `pushOnlyAffectsNodesInRadius`, `trackingLossReleases`.
- [ ] Shows the painting (template name / "Freeform", date) on the deformable sheet.
- [ ] **Save to gallery** → `gallery.add(image, record:)`, `playground.clearCanvas()`, `router.go(.gallery3D(start: 0, justHung: true))` (keeps today's cheer animation).
- [ ] **Keep drawing** → back to `.canvas` with paint untouched (A10).
- [ ] Buttons are touch + "hover-and-hold" with an open hand (1 s dwell ring), since fists are busy grabbing.
- [ ] Saved PNG = the original photo, never the deformed sheet.
- [ ] Commit: `feat: add the review page with push and grab`.

## Task 8: Walkable 3D gallery, paddle gesture, 2D list

**Files:** modify `Gallery.swift` (`GalleryHall`, `GalleryView`); create `PuffyPond/Input/PaddleDetector.swift`, `PuffyPond/Pages/Gallery2DView.swift`; test `PuffyPondTests/PaddleDetectorTests.swift`.

- [ ] `GalleryHall`: build a corridor/room with **all** paintings hung along the walls (alternating left/right or one long wall), frames + spotlights; camera on a rail. `focus(index:)` animates the camera walk (ease, ~1.2 s, slight head bob) to stand in front of painting `index`. Load textures lazily (thumbnail size for far ones) to keep memory down.
- [ ] `PaddleDetector` (pure): per hand, open-hand vertical sweep (A9) → `.next` / `.previous`, with a 0.6 s cooldown. Tests: `downSweepOnRightIsNext`, `slowDriftIsIgnored`, `cooldownBlocksDoubleTrigger`.
- [ ] `GalleryView`: hand tracking on while open (`playground` stays away; feed `HandInput` into the detector), small paddle hint + mini hand indicator. Swipe and arrows remain. Bottom-left **View gallery in 2D** → `.gallery2D`. Top-left **Home**. Keep delete with confirm. Empty state: "No paintings yet" + Start drawing.
- [ ] `Gallery2DView`: grid of thumbnails, newest first, grouped by date; tap → `.gallery3D(start: i)`; Home / back to 3D.
- [ ] Commit: `feat: walkable 3D gallery with paddle gesture and 2D list`.

## Task 9: Report page

**Files:** create `PuffyPond/Pages/ReportView.swift`, `PuffyPond/Stats/DayReport.swift`; test `PuffyPondTests/DayReportTests.swift`.

- [ ] `DayReport` (pure) from the records of one local day: count, list of paintings, highest ROM per side, summed heatmap, dominance % (by summed pinch seconds). Tests: `emptyDayHasNoStats`, `mergesSessions`, `legacyPaintingsCountButAddNoStats`.
- [ ] Left half: month calendar (custom grid, month navigation), today ringed, days with paintings get a colored dot (extra star if the daily quest was done). Tap selects a day; default today.
- [ ] Right half: selected date title; "N paintings" + horizontal thumbnail strip (tap → 3D gallery at that painting); **Highest ROM** (left / right in degrees); **Heatmap** (grid rendered as a soft color image over a canvas frame); **Hand dominance** (two-color bar + percentages). "No drawing this day" empty state.
- [ ] Home button. Commit: `feat: add the report page with calendar and daily stats`.

## Task 10: Polish and docs

- [ ] Run on iPad (landscape) end-to-end: Home → template → distance → draw → save → gallery paddle → 2D → Home → Report.
- [ ] Mac pass: build, mouse fallback for every gesture-only step.
- [ ] Update `README.md` (new flow, remove Magic and template-bubble rows, new files table).
- [ ] Commit: `docs: describe the new app flow`.

## Parallelism

After Task 1–3 land: Task 4, Task 5, Task 6a and Task 8 (hall + paddle part) touch separate files and can run in parallel; the sheet solver/gestures of Task 7 (pure, no UI) can also start then. Task 6b needs 3 + 5 + 6a. The Review page UI (rest of Task 7) needs 6b. Task 9 needs 3 + 6b.
