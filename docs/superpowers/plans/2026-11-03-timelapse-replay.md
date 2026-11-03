# Timelapse Replay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record every stroke of a painting session, replay it as a short musical timelapse on the review page, then hand the finished painting to the existing grab/push sheet; hanging a painting stores the recording so the gallery can open the same replay-then-play page.

**Architecture:** A `TimelapseRecorder` in `Playground` logs each `PaintLayer.stamp`/`erase` call into a compact `StrokeRecording`. Pure types turn a recording into a replay clock (`ReplayTimeline`) and a list of beat-quantized notes (`NoteComposer`). `ReviewStage` gains a `timelapse` phase before its existing interactive phase; the picture comes from a `ReplayRenderer`. The first renderer is a cheap reveal mask over the final paint (ships working end to end); a faithful offscreen `PaintLayer` renderer is then tried behind a pass/fail gate. The review page is reused for gallery viewing through a new route.

**Tech Stack:** Swift, SwiftUI, SceneKit, Metal (`PaintLayer`), AVAudioEngine synth (`GrooveDSP`), Compression framework (zlib), Swift Testing (`PuffyPondTests`).

**Spec:** `docs/superpowers/specs/2026-11-03-timelapse-replay-design.md`

## Global Constraints

- Platforms: iPad and Mac, no third-party dependencies. New files under `PuffyPond/` and `PuffyPondTests/` are picked up automatically (Xcode synchronized groups); do not edit the `.pbxproj`.
- No recorded audio: every sound is synthesized in `GrooveDSP`.
- Do not change how painting looks or feels while drawing: no change to the paint simulation, `BrushStyle` values, control scheme, hand tracking or the saved PNG.
- Interaction (grab, push, splash) is live only after the timelapse, never during it.
- Timelapse length: `ReplayTimeline.targetSeconds = 18`; idle gaps longer than 1.5 s are collapsed to 0.25 s; a session shorter than the target plays at real time.
- Music: C major pentatonic (the review page's `Tune.silly` is in C), pitch follows height, timbre follows the brush animal, notes land on the tune's 16th-note grid (`60 / GrooveDSP.bpm / 4` s), at most 3 notes per step across all strokes, at most one note per stroke per step.
- Recording size: at most `StrokeRecording.maxEvents = 24_000` events per painting (thinned evenly beyond that), about 1 MB compressed.
- The replay never touches the live `Playground.paintLayer`: "Keep drawing" must find the easel untouched.
- The recording keeps growing across "Keep drawing" and is cleared only by `Playground.clearCanvas` (which `begin` calls).
- Old paintings (no recording) open interactive straight away, with no Replay button.
- Extra files saved with a painting must never be plain `.png` files in the gallery folder (`Gallery.reload` treats every `.png` as a painting).
- Run tests on macOS: `xcodebuild test -project PuffyPond.xcodeproj -scheme PuffyPond -destination 'platform=macOS'` (add `-only-testing:PuffyPondTests/<Struct>` for one suite). Build iOS with `xcodebuild build -project PuffyPond.xcodeproj -scheme PuffyPond -destination 'generic/platform=iOS Simulator'`.
- Commit only the files a task names. Never `git add -A` (the working tree has an unrelated `tools/nca/targets/`).

## Review Focus

- Save, "Keep drawing", then Save again: the second recording must contain both sittings, and the first review's snapshot must not change under it. (Task 3)
- A painting with a single dab, only erases, or no events at all: no division by zero, no stuck page; it goes straight to the interactive phase. (Tasks 1, 6, 8)
- A missing, truncated or corrupt recording file, or one from a future format version: treated as "no recording", never a crash. (Tasks 2, 5)
- Leaving the page mid-timelapse (Keep drawing, Back, backgrounding) or pressing Skip or Replay repeatedly: no notes sound after leaving, nothing is released twice. (Tasks 6, 8)
- The gallery folder now holds non-painting files: they must not appear as paintings, and removing a painting must remove its extras but not the shared canvas image. (Task 5)

---

### Task 1: ReplayTimeline

**Files:**
- Create: `PuffyPond/Timelapse/ReplayTimeline.swift`
- Test: `PuffyPondTests/ReplayTimelineTests.swift`

**Interfaces:**
- Produces:
```swift
struct ReplayTimeline: Equatable {
    static let targetSeconds = 18.0
    static let idleGap = 1.5
    static let idleReplacement = 0.25
    /// `eventTimes`: recorded seconds since the recording started, ascending.
    init(eventTimes: [Double])
    /// Replay seconds; 0 when there are fewer than two events or all events share one time.
    var duration: Double { get }
    func replayTime(forRecorded t: Double) -> Double     // clamped to 0...duration, never NaN
    func recordedTime(forReplay t: Double) -> Double     // inverse; inside a collapsed gap it moves linearly across the gap
}
```

- [ ] **Step 1: Write the failing tests** in `ReplayTimelineTests.swift` (`import Testing`, `@testable import PuffyPond`):
  - `emptyAndSingleEventHaveNoDuration`: `ReplayTimeline(eventTimes: []).duration == 0`; `[3.0]` also 0; `replayTime(forRecorded: 3)` is `0` and finite. (Review Focus)
  - `shortSessionPlaysAtRealTime`: events every 0.1 s from 0 to 6 → `duration` within 1e-9 of 6.
  - `longSessionFitsTheTarget`: events every 0.1 s from 0 to 300 → `duration` within 1e-9 of 18.
  - `idleGapIsCollapsed`: times `[0, 1, 2, 32, 33]` → `duration == 3.25` and `replayTime(forRecorded: 32) == 2.25`.
  - `mappingIsMonotonicAndInvertible`: for times `[0, 0.4, 0.9, 5, 5.2, 400, 400.5, 900]`, `replayTime` is non-decreasing over a sweep of recorded times, and `recordedTime(forReplay: replayTime(forRecorded: t))` is within 1e-6 of `t` for each event time.
- [ ] **Step 2: Run** `-only-testing:PuffyPondTests/ReplayTimelineTests`. Expected: FAIL (type not defined).
- [ ] **Step 3: Implement `ReplayTimeline`.** Build the "active time" axis (each gap above `idleGap` counts as `idleReplacement`), let `speed = max(1, activeTotal / targetSeconds)`, `duration = activeTotal / speed`. Store the event times and cumulative active time for lookup.
- [ ] **Step 4: Run the suite.** Expected: PASS.
- [ ] **Step 5: Commit** `git add PuffyPond/Timelapse/ReplayTimeline.swift PuffyPondTests/ReplayTimelineTests.swift && git commit -m "feat: replay timeline mapping"`.

---

### Task 2: StrokeRecording and its file format

**Files:**
- Create: `PuffyPond/Timelapse/StrokeRecording.swift`
- Modify: `PuffyPond/PaintLayer.swift` (make `BrushStyle` `Equatable`)
- Test: `PuffyPondTests/StrokeRecordingTests.swift`

**Interfaces:**
- Consumes: `BrushStyle`, `CritterKind` (`Int` raw values).
- Produces:
```swift
struct RecordedDab: Equatable {   // one PaintLayer.stamp call
    var t: Double                 // seconds since the recording began
    var from: SIMD2<Float>, to: SIMD2<Float>
    var radius: Float, speed: Float
    var color: SIMD3<Float>
    var seed: Float, strokeSeed: Float
    var style: BrushStyle
    var drag: SIMD2<Float>?
    var ncaModel: Int
    var brush: CritterKind
}
struct RecordedErase: Equatable { var t: Double; var center: SIMD2<Float>; var radius: Float; var dt: Float }
enum RecordedEvent: Equatable { case dab(RecordedDab), erase(RecordedErase); var t: Double { get } }
struct StrokeRecording: Equatable {
    static let formatVersion = 1
    static let maxEvents = 24_000
    private(set) var events: [RecordedEvent]
    init(events: [RecordedEvent] = [])
    var isEmpty: Bool { get }
    /// Appends; when the count passes `2 * maxEvents`, thins in place to `maxEvents`.
    mutating func append(_ event: RecordedEvent)
    /// Drops dabs evenly (never erases, never the first or last dab of a stroke, where a stroke is a run of dabs sharing `strokeSeed`). A dropped dab's `from` is carried into the next kept dab of that stroke so the painted path stays connected.
    func thinned(toAtMost limit: Int) -> StrokeRecording
    func encoded() -> Data        // version byte + zlib-compressed fixed-size records
    init?(data: Data)             // nil for a wrong version, truncation or corrupt data
}
```

- [ ] **Step 1: Write the failing tests** in `StrokeRecordingTests.swift`:
  - `roundTripKeepsEveryField`: a recording with dabs varying every field (including `drag == nil` and `style.amount == nil`) and an erase; `StrokeRecording(data: r.encoded()) == r`.
  - `badDataIsRejected` (Review Focus): `Data()`, `r.encoded().dropLast(10)`, a copy with the first byte set to `99`, and 200 bytes of `0xAB` all give `nil`.
  - `thinningKeepsEndsAndStaysConnected`: 100 chained dabs of one stroke (`dab[i].to == dab[i+1].from`) thinned to 40 → count ≤ 40, first `from` and last `to` unchanged, every consecutive remaining pair connected.
  - `thinningKeepsAllErases`: 10 erases among 100 dabs thinned to 40 → all 10 erases remain.
  - `appendThinsPastTheCap`: appending `2 * maxEvents + 1` dabs leaves `events.count <= maxEvents`.
  - `encodedSizeStaysNearBudget`: `maxEvents` smoothly moving dabs with one style and colour encode to under `1_000_000` bytes (if this fails, delta-encode positions before compressing).
- [ ] **Step 2: Run** `-only-testing:PuffyPondTests/StrokeRecordingTests`. Expected: FAIL.
- [ ] **Step 3: Implement the types.** Encode `style.amount == nil` as `NaN`. Compress the payload with `(data as NSData).compressed(using: .zlib)`; decoding must bounds-check every read and return nil on any failure.
- [ ] **Step 4: Run the suite.** Expected: PASS.
- [ ] **Step 5: Commit** the two new files plus `PuffyPond/PaintLayer.swift` with `feat: stroke recording format`.

---

### Task 3: Record strokes in the easel

**Files:**
- Create: `PuffyPond/Timelapse/TimelapseRecorder.swift`
- Modify: `PuffyPond/Playground.swift` (`lay`, its two callers, `erase(with:now:)`, `clearCanvas`, a `timelapseRecording()` accessor), `PuffyPond/App/AppRouter.swift` (`ReviewDraft.recording`), `PuffyPond/ContentView.swift` (`saveImage`)
- Test: `PuffyPondTests/TimelapseRecorderTests.swift`

**Interfaces:**
- Consumes: `StrokeRecording`, `BrushDab`.
- Produces:
```swift
final class TimelapseRecorder {
    init(clock: @escaping () -> Double = CACurrentMediaTime)
    /// Same arguments `Playground.lay` gives `PaintLayer.stamp`; dab k gets `seed + Float(k) * 5.1`, `strokeSeed = seed`.
    func record(dabs: [BrushDab], color: SIMD3<Float>, ncaModel: Int, seed: Float, brush: CritterKind)
    func recordErase(at center: SIMD2<Float>, radius: Float, dt: Float)
    func reset()
    func snapshot() -> StrokeRecording?   // value copy; nil when nothing was recorded
}
// Playground
func timelapseRecording() -> StrokeRecording?
// ReviewDraft gains: let recording: StrokeRecording?   (init argument after `stats`)
```
The first event after `reset()` is at `t = 0`.

- [ ] **Step 1: Write the failing tests** in `TimelapseRecorderTests.swift` using an injected clock:
  - `firstEventIsTimeZero`: clock returns 100 then 102.5 → recorded `t` values `0` and `2.5`.
  - `dabSeedsMatchWhatLayGivesTheLayer`: three dabs with `seed: 10` → recorded `seed` values `10, 15.1, 20.2` (within 1e-4) and `strokeSeed == 10` for all.
  - `snapshotIsAValueCopy` (Review Focus): take a snapshot, record more, the first snapshot's event count is unchanged and a later snapshot contains both sittings.
  - `resetStartsFresh`: after `reset()`, `snapshot() == nil` and the next event is `t == 0`.
- [ ] **Step 2: Run** `-only-testing:PuffyPondTests/TimelapseRecorderTests`. Expected: FAIL.
- [ ] **Step 3: Implement `TimelapseRecorder`** on top of `StrokeRecording.append`; no work beyond building the struct and appending (it runs every frame of painting).
- [ ] **Step 4: Hook it into `Playground`.** Add `@ObservationIgnored private let timelapse = TimelapseRecorder()`; give `lay` a `brush: CritterKind` parameter (both callers pass `buddy.critter.kind`) and call `timelapse.record` before the `paintLayer.stamp` loop; call `timelapse.recordErase` next to `paintLayer.erase` in `erase(with:now:)`; call `timelapse.reset()` in `clearCanvas()`. Add `ReviewDraft.recording` and pass `playground.timelapseRecording()` in `saveImage`. `begin` and "Keep drawing" must not reset it other than through `clearCanvas`.
- [ ] **Step 5: Run the full suite and build iOS.** Expected: PASS, BUILD SUCCEEDED. Then run the app, paint for a few seconds, and confirm drawing is as smooth as before (no new hitches).
- [ ] **Step 6: Commit** the files named above with `feat: record strokes for the timelapse`.

---

### Task 4: Notes and the note sound

**Files:**
- Create: `PuffyPond/Timelapse/NoteComposer.swift`
- Modify: `PuffyPond/GrooveDSP.swift` (`Sfx.note`, `SfxEvent.c`, the effect, `GrooveEngine.playNote`)
- Test: `PuffyPondTests/NoteComposerTests.swift`, `PuffyPondTests/GardenSoundTests.swift`

**Interfaces:**
- Consumes: `StrokeRecording`, `ReplayTimeline`, `Playground.canvasSize` (canvas centre is `(0, 0.1)`), `GrooveDSP.bpm`.
- Produces:
```swift
enum NoteTimbre: Int, CaseIterable { case bell, pluck, marimba, xylophone
    init(brush: CritterKind)   // butterfly→bell, ladybug→pluck, snail & sponge→marimba, everything else→xylophone
}
struct ReplayNote: Equatable {
    enum Voice: Equatable { case note(NoteTimbre), poof }
    var time: Double     // replay seconds, on the step grid (or half a step after it for grace notes)
    var pitch: Float     // 0…1 position along the scale; Sfx.note's `a`
    var pan: Float       // -1…1
    var voice: Voice
}
enum NoteComposer {
    static let stepSeconds: Double          // 60 / GrooveDSP.bpm / 4
    static let maxNotesPerStep = 3
    static let fastSpeed: Float = 2.5       // world units/s
    static func compose(_ recording: StrokeRecording, timeline: ReplayTimeline) -> [ReplayNote]   // sorted by time
}
// SfxEvent gains `var c: Float = 0`; Sfx gains `.note` (a = scale position 0…1, b = pan, c = NoteTimbre.rawValue).
// GrooveEngine: func playNote(timbre: NoteTimbre, pitch: Float, pan: Float)
```
Rules: bucket events by replay step; per step and stroke (`strokeSeed`) emit one note at the step start, pitch = mean of `(y - 0.1) / canvasSize.y + 0.5` clamped to 0…1, pan = mean `x / (canvasSize.x / 2)` clamped to -1…1, voice from the stroke's `brush`; if the mean `speed` in that step exceeds `fastSpeed`, add a grace note half a step later one scale degree up (`+ 1/9`, clamped). Dabs with `style.blend > 0.5` make no note. Erases give at most one `.poof` per step (pan from the erase centre). If a step has more than `maxNotesPerStep` notes, keep the strokes with the longest path in that step (a `.poof` counts as one note).

- [ ] **Step 1: Write the failing composer tests** in `NoteComposerTests.swift` (build recordings with small helper dabs):
  - `oneNotePerStrokePerStep`: two dabs of one stroke inside one step → one note.
  - `pitchFollowsHeight`: a dab at `y = 2.1` → pitch `1`; at `y = -1.9` → pitch `0`.
  - `notesLandOnTheStepGrid`: every note's `time / stepSeconds` is an integer or an integer plus 0.5.
  - `globalCapKeepsTheBusiestStrokes`: six strokes with different path lengths in one step → exactly 3 notes, from the three longest.
  - `fastStrokeAddsAGraceNote`: a stroke with `speed 4` gives a second note at `+ stepSeconds / 2`, pitch higher by `1/9`.
  - `blenderMakesNoNotes`; `eraseGivesOnePoofPerStep`; `timbreFollowsTheBrush` (butterfly→bell, ladybug→pluck); `emptyRecordingGivesNoNotes`.
- [ ] **Step 2: Write the failing sound tests** in `GardenSoundTests.swift`: `Sfx.allCases` already runs `everySoundEffectIsAudible`, so `.note` must satisfy it with `a: 0.5, c: 0`; add `.note` to the list in `repeatedEffectsStayBounded`; add `everyNoteTimbreIsAudible` playing each `NoteTimbre` with `c = Float(timbre.rawValue)` (peak above 0.002, finite) and a 20-repeat bounded check (peak below 1.0).
- [ ] **Step 3: Run** both suites. Expected: FAIL (types and effect missing).
- [ ] **Step 4: Implement `NoteComposer` and the types** as specified above.
- [ ] **Step 5: Implement the effect in `GrooveDSP.playEffect`:** a `noteScale` of ten C-major-pentatonic MIDI values `[72, 74, 76, 79, 81, 84, 86, 88, 91, 93]` indexed by `a` like `.blip` does; four voicings by `c` (bell: sine plus soft FM partial; pluck: triangle with a low-pass; marimba: sine an octave lower with a short click; xylophone: sine plus FM like the tune's lead). Peaks at or below 0.14; decays 0.2–0.5 s. Add `GrooveEngine.playNote`. Fix any exhaustive `switch` over `Sfx` the compiler flags.
- [ ] **Step 6: Run both suites and the full suite.** Expected: PASS.
- [ ] **Step 7: Commit** `NoteComposer.swift`, `GrooveDSP.swift` and the two test files with `feat: timelapse note composer and note sound`.

---

### Task 5: Store the recording with the painting

**Files:**
- Modify: `PuffyPond/Gallery.swift` (`Painting`, `Gallery`), `PuffyPond/Stats/SessionStats.swift` (`PaintingRecord`), `PuffyPond/ContentView.swift` (`save`)
- Test: `PuffyPondTests/PaintingStoreTests.swift`

**Interfaces:**
- Consumes: `StrokeRecording.encoded()/init?(data:)`, `CanvasPhotos`.
- Produces:
```swift
// PaintingRecord gains `var timelapseVersion: Int?` (nil = no recording; init argument defaults to nil; old JSON still decodes)
// Painting gains:
var paintURL: URL { get }        // painting-<ms>.paint   (PNG bytes, paint on a clear background)
var timelapseURL: URL { get }    // painting-<ms>.timelapse
// Gallery:
@discardableResult
func add(_ photos: CanvasPhotos, recording: StrokeRecording?, record: PaintingRecord) -> Painting?
nonisolated static func recording(of painting: Painting) -> StrokeRecording?   // nil: missing, empty or unreadable
nonisolated static func photos(of painting: Painting) -> CanvasPhotos?         // nil: PNG unreadable
```
The shared bare canvas is stored once as `canvas.bare` (PNG bytes) in the gallery folder, written by the first `add` that finds none. `add` sets `timelapseVersion = StrokeRecording.formatVersion` on the stored record only when the recording is non-empty. `photos(of:)` for a painting with no `.paint` file (made before this feature) returns `whole` = the PNG, `paint` = the PNG, and `canvas` = a plain white image of the same size. The existing `add(_ image:record:)` stays.

- [ ] **Step 1: Write the failing tests** (reuse the file's `makeFolder`/`makeImage` helpers):
  - `addStoresPaintLayerAndRecording`: after `add(photos, recording:, record:)`, `Gallery.photos(of:)` returns images of the same pixel size, `Gallery.recording(of:) == recording`, `record.timelapseVersion == 1`.
  - `extraFilesAreNotPaintings` (Review Focus): a new `Gallery(folder:)` over that folder lists exactly one painting.
  - `removeDeletesTheExtras` (Review Focus): after `remove`, the folder holds only `canvas.bare`.
  - `canvasIsStoredOnce`: two adds → one `canvas.bare`.
  - `emptyRecordingStoresNone`: `recording: nil` and an empty recording both leave `timelapseVersion == nil` and no `.timelapse` file, while `photos(of:)` still works.
  - `oldRecordsStillDecode`: sidecar JSON without `timelapseVersion` decodes with `nil`.
  - `legacyPaintingHasNoRecording`: a bare PNG painting gives `recording(of:) == nil` and `photos(of:)` with `paint` the size of the PNG.
  - `corruptRecordingIsIgnored` (Review Focus): garbage written to the `.timelapse` file gives `recording(of:) == nil`.
- [ ] **Step 2: Run** `-only-testing:PuffyPondTests/PaintingStoreTests`. Expected: FAIL.
- [ ] **Step 3: Implement** the properties and methods above. `remove` deletes `.paint` and `.timelapse` too.
- [ ] **Step 4: In `ContentView.save`,** call the new `add(draft.photos, recording: draft.recording, record:)`.
- [ ] **Step 5: Run the full suite and build both platforms.** Expected: PASS.
- [ ] **Step 6: Commit** `Gallery.swift`, `SessionStats.swift`, `ContentView.swift`, `PaintingStoreTests.swift` with `feat: store the timelapse with each painting`.

---

### Task 6: TimelapseConductor

**Files:**
- Create: `PuffyPond/Timelapse/TimelapseConductor.swift`
- Test: `PuffyPondTests/TimelapseConductorTests.swift`

**Interfaces:**
- Consumes: `ReplayTimeline`, `ReplayNote`, `GrooveDSP.bpm`.
- Produces:
```swift
final class TimelapseConductor {
    enum Phase: Equatable { case waitingForBeat, playing, finished }
    init(timeline: ReplayTimeline, notes: [ReplayNote])
    private(set) var phase: Phase          // starts as .finished until start(beat:)
    private(set) var replayTime: Double
    /// Begins (or restarts) the replay. An empty or zero-length timeline finishes at once.
    func start(beat: Double)
    /// Moves time on by `dt`. Waiting ends when `floor(beat * 4)` passes its start value (so replay steps line up with the tune's 16th notes) or after 0.3 s without the beat moving (audio not running). Returns the notes whose time passed this frame, each exactly once.
    func advance(dt: Double, beat: Double) -> [ReplayNote]
    func skip()      // finishes without returning notes
    func cancel()    // finishes; later advance calls return nothing
}
```
`phase` becomes `.finished` when `replayTime >= timeline.duration`.

- [ ] **Step 1: Write the failing tests** (build a timeline from event times and a few notes):
  - `notesFireOnceAndInOrder`: advancing in uneven `dt` slices returns every note exactly once, in time order, and finishes after `duration`.
  - `startWaitsForTheNextSixteenth`: with beat `10.0` fixed and `dt = 0.05` it stays `.waitingForBeat` until a beat of `10.25` is supplied, then `.playing`; with the beat never moving it starts after 0.3 s.
  - `emptyTimelineFinishesImmediately` (Review Focus): `start` on a zero-duration timeline is `.finished` and `advance` returns `[]`.
  - `skipFinishesWithoutNotes` and `skipTwiceIsHarmless` (Review Focus).
  - `cancelStopsLaterNotes` (Review Focus): after `cancel()`, `advance` returns `[]`.
  - `restartPlaysAgain`: finish, `start` again, the same notes come again.
- [ ] **Step 2: Run** `-only-testing:PuffyPondTests/TimelapseConductorTests`. Expected: FAIL.
- [ ] **Step 3: Implement `TimelapseConductor`** (pure; no audio or SceneKit).
- [ ] **Step 4: Run the suite.** Expected: PASS.
- [ ] **Step 5: Commit** both files with `feat: timelapse conductor`.

---

### Task 7: ReplayRenderer and the reveal-mask replayer

**Files:**
- Create: `PuffyPond/Timelapse/ReplayRenderer.swift` (protocol), `PuffyPond/Timelapse/RevealMask.swift`, `PuffyPond/Timelapse/MaskReplayer.swift`
- Test: `PuffyPondTests/RevealMaskTests.swift`

**Interfaces:**
- Consumes: `StrokeRecording`, `ReplayTimeline`, `SheetSolver.size`, `Playground.canvasSize`.
- Produces:
```swift
protocol ReplayRenderer: AnyObject {
    /// Added to the review scene; laid out in sheet space (centred on 0,0, `SheetSolver.size` wide), in front of the bare canvas.
    var node: SCNNode { get }
    /// Shows the painting as it was `replayTime` replay seconds in. Later calls only move forward until `reset()`.
    func advance(to replayTime: Double)
    func reset()
}
struct RevealMask {   // pure bitmap, 640 x 400
    init()
    mutating func reveal(_ dab: RecordedDab)   // a round-capped line from→to, width 2 * radius, canvas world → pixels
    mutating func clear()
    func coverage(atWorld p: SIMD2<Float>) -> Float   // 0…1
    var image: CGImage { get }
}
final class MaskReplayer: ReplayRenderer {
    init(finalPaint: CGImage, recording: StrokeRecording, timeline: ReplayTimeline)
}
```
The mask replayer shows the saved paint image through the growing mask, so it always ends identical to the saved painting. Dabs with `style.blend > 0.5` and all erases are ignored.

- [ ] **Step 1: Write the failing tests** in `RevealMaskTests.swift`: `revealsUnderADab` (coverage at the dab's midpoint above 0.9); `leavesOtherPlacesAlone` (coverage far from the dab is 0); `clearHidesEverything`; `canvasCornersMapToPixels` (dabs at the four canvas corners reveal the matching corner pixels of `image`).
- [ ] **Step 2: Run** `-only-testing:PuffyPondTests/RevealMaskTests`. Expected: FAIL.
- [ ] **Step 3: Implement `RevealMask`** with a CGContext bitmap (8-bit grey, soft round edges). Implement `MaskReplayer`: a plane textured with `finalPaint` whose transparency comes from `RevealMask.image`; `advance(to:)` reveals every event whose `timeline.replayTime(forRecorded:)` is at or before the target, never twice, and re-uploads the mask only when something changed; `reset()` clears it.
- [ ] **Step 4: Run the suite and build both platforms.** Expected: PASS, BUILD SUCCEEDED.
- [ ] **Step 5: Commit** the four new files with `feat: reveal-mask timelapse renderer`.

---

### Task 8: Timelapse phase on the review page

**Files:**
- Modify: `PuffyPond/Review/ReviewStage.swift`, `PuffyPond/Pages/ReviewView.swift`, `PuffyPond/ContentView.swift` (review page call)
- Test: `PuffyPondTests/ReviewStagePhaseTests.swift`

**Interfaces:**
- Consumes: `TimelapseConductor`, `NoteComposer`, `ReplayRenderer`, `MaskReplayer`, `GrooveEngine.playNote`, `ReviewDraft.recording`.
- Produces:
```swift
// ReviewStage
enum Phase: Equatable { case timelapse, interactive }
private(set) var phase: Phase                 // observable
private(set) var canReplay: Bool              // true when a non-empty recording was given
func show(_ photos: CanvasPhotos, recording: StrokeRecording?, audio: GrooveEngine)   // replaces show(_:audio:)
func skipTimelapse()                          // no-op unless .timelapse
func replay()                                 // no-op unless .interactive and canReplay
func advanceTimelapse(dt: Double)             // what the frame tick calls; internal so tests can drive it
var makeRenderer: (CanvasPhotos, StrokeRecording, ReplayTimeline) -> ReplayRenderer   // default: MaskReplayer
// ReviewView
enum ReviewMode { case fresh, viewing }
init(photos: CanvasPhotos, recording: StrokeRecording?, title: String, date: Date, mode: ReviewMode,
     audio: GrooveEngine, relay: HandFrameRelay,
     keepDrawing: @escaping () -> Void, save: @escaping () -> Void, back: @escaping () -> Void)
```
Behaviour: `show` goes to `.timelapse` when the recording has a positive-duration timeline, otherwise `.interactive` at once. In `.timelapse` the sheet is hidden, the replay node is in the scene, no hand or touch reaches the solver, and notes are played through `audio` as the conductor returns them (`.note` → `playNote`, `.poof` → `play(.poof)`); hover-and-hold still works for the Skip button. When the conductor finishes (or on skip): fade the replay node out and the sheet in over 0.35 s, add a ripple at the centre, play `.wobble`, set `.interactive`. `replay()` resets the solver, hides the sheet, resets the renderer and restarts the conductor. `stop()` cancels the conductor and releases the renderer. Buttons by phase: timelapse → **Skip**; interactive in `.fresh` → **Replay** (if `canReplay`), **Keep drawing**, **Save to gallery**; interactive in `.viewing` → **Replay** (if `canReplay`), **Back**. The hint line and title text follow the phase. `ContentView` builds `.fresh` from the draft (`title` = `draft.choice?.title ?? "Freeform"`, `date` = now).

- [ ] **Step 1: Write the failing tests** in `ReviewStagePhaseTests.swift` (a `GrooveEngine()` that is never started works as a silent audio; make 4×4 images for `CanvasPhotos`):
  - `recordingStartsTheTimelapse`: `show` with a 5-second recording → `.timelapse`, `canReplay == true`.
  - `noRecordingIsInteractiveAtOnce`: `nil` → `.interactive`, `canReplay == false`; `replay()` leaves it `.interactive`.
  - `emptyAndSingleEventRecordingsAreInteractive` (Review Focus): an empty recording and a one-dab recording both go straight to `.interactive`.
  - `timelapseEndsByItself`: `advanceTimelapse(dt: 1)` repeatedly until past the duration → `.interactive`.
  - `skipFinishesAndIsIdempotent` (Review Focus): `skipTimelapse()` twice → `.interactive`, no crash.
  - `replayRestarts`: after finishing, `replay()` → `.timelapse`; replaying again before it ends changes nothing.
  - `leavingStopsTheNotes` (Review Focus): `stop()` mid-timelapse then `advanceTimelapse` plays no more notes (use a stub renderer from `makeRenderer` that counts `advance` calls, which must stay constant).
- [ ] **Step 2: Run** `-only-testing:PuffyPondTests/ReviewStagePhaseTests`. Expected: FAIL.
- [ ] **Step 3: Implement the stage changes** per the behaviour above. Compose notes once in `show` (`NoteComposer.compose` with the same `ReplayTimeline` as the renderer), and read the beat from `audio.beat`. Add the replay node under the scene root in front of the canvas (`z` between `canvasDepth` and the sheet).
- [ ] **Step 4: Implement the page changes** in `ReviewView`: the new initializer, phase-dependent buttons (ids `keep`, `save`, `replay`, `skip`, `back`, with their frames registered for hand hover-and-hold exactly like the two existing buttons), and the hint and title. Update the `ContentView` call.
- [ ] **Step 5: Run the full suite and build both platforms.** Expected: PASS.
- [ ] **Step 6: Run the app** and paint a short picture with a few colours and some erasing, press Save image: the timelapse plays with notes, the sheet wakes up with a wobble, Replay plays it again, grab and push work afterwards, Keep drawing returns to an untouched easel, Save to gallery still hangs the painting.
- [ ] **Step 7: Commit** `ReviewStage.swift`, `ReviewView.swift`, `ContentView.swift`, `ReviewStagePhaseTests.swift` with `feat: timelapse phase on the review page`.

---

### Task 9: Shared hover-and-hold

**Files:**
- Create: `PuffyPond/Input/HoverDwell.swift`
- Modify: `PuffyPond/Review/ReviewStage.swift` (use it; move `HoverTarget` out of the class), `PuffyPond/Gallery.swift` (`GalleryHall` gets targets, dwell and a press callback)
- Test: `PuffyPondTests/HoverDwellTests.swift`

**Interfaces:**
- Produces:
```swift
struct HoverTarget: Equatable { var id: String; var frame: CGRect }   // view UV; was ReviewStage.HoverTarget
struct HoverDwell {
    static let duration = 1.0
    private(set) var progress: (id: String, value: Double)?
    /// `hoveredID`: the target an open hand is over, or nil. Returns the id when a full hold completes; it fires once and stays latched until the hand leaves that target.
    mutating func update(hoveredID: String?, dt: Double) -> String?
}
// GalleryHall gains: var targets: [HoverTarget]; private(set) var dwell: (id: String, progress: Double)?; var onPress: ((String) -> Void)?
```
In `GalleryHall`, only open hands over a target count; the paddle gestures keep working unchanged.

- [ ] **Step 1: Write the failing tests** in `HoverDwellTests.swift`: `firesAfterOneSecond` (ten `0.1` updates on `"a"` return `"a"` on the tenth, nil before); `firesOnlyOnce` (staying on `"a"` returns nil after firing); `leavingResets` (0.9 s on `"a"`, a `nil` update, then 0.9 s again → no fire); `switchingTargetsRestarts`; `relatchesAfterLeaving` (fire, leave, hold again → fires again); `progressReportsTheFraction`.
- [ ] **Step 2: Run** `-only-testing:PuffyPondTests/HoverDwellTests`. Expected: FAIL.
- [ ] **Step 3: Implement `HoverDwell`**, make `ReviewStage.updateDwell` use it (behaviour unchanged: `ReviewStagePhaseTests` and manual hover on the review buttons must still work), and add the same hovering to `GalleryHall.tick`.
- [ ] **Step 4: Run the full suite and build both platforms.** Expected: PASS.
- [ ] **Step 5: Commit** the new file, `ReviewStage.swift`, `Gallery.swift`, `HoverDwellTests.swift` with `refactor: share hover-and-hold between pages`.

---

### Task 10: Open a painting from the gallery

**Files:**
- Modify: `PuffyPond/App/AppRouter.swift`, `PuffyPond/ContentView.swift`, `PuffyPond/Gallery.swift` (`GalleryView`), `PuffyPond/Pages/Gallery2DView.swift`, `PuffyPond/Pages/ReviewView.swift` (make `DwellButton` non-private for reuse)
- Create: `PuffyPond/Pages/PaintingViewerPage.swift`
- Test: `PuffyPondTests/AppRouterTests.swift`

**Interfaces:**
- Consumes: `Gallery.photos(of:)`, `Gallery.recording(of:)`, `ReviewView(mode: .viewing)`, `HoverTarget`.
- Produces:
```swift
enum ViewOrigin: Equatable {
    case gallery3D(index: Int)
    case gallery2D
    var route: Route { get }      // .gallery3D(start: index, justHung: false) or .gallery2D
}
// Route gains: case viewPainting(Painting, origin: ViewOrigin)
struct PaintingViewerPage: View { init(painting: Painting, origin: ViewOrigin, router: AppRouter, audio: GrooveEngine, relay: HandFrameRelay) }
```
`PaintingViewerPage` loads the photos and recording off the main thread (`Task.detached`, like the 2D thumbnails), shows a progress view meanwhile, then shows `ReviewView(mode: .viewing)` whose `back` calls `router.go(origin.route)`. If the photos cannot be read it goes back at once. `GalleryView` gets a `watch: (Painting) -> Void` closure and a **Watch** button (replacing the hidden balance pill at bottom right, with the hover ring so hands can hold on it); `ContentView` passes the closure that routes to `.viewPainting(painting, origin: .gallery3D(index:))`. In `Gallery2DView`, tapping a thumbnail routes to `.viewPainting(painting, origin: .gallery2D)` (this replaces the old walk to the 3D gallery on tap; the "3D" pill still goes there). The report page is unchanged.

- [ ] **Step 1: Write the failing test** in `AppRouterTests.swift`: `viewOriginReturnsToWhereItStarted`: `ViewOrigin.gallery3D(index: 4).route == .gallery3D(start: 4, justHung: false)` and `ViewOrigin.gallery2D.route == .gallery2D`.
- [ ] **Step 2: Run** `-only-testing:PuffyPondTests/AppRouterTests`. Expected: FAIL.
- [ ] **Step 3: Implement** the route, origin, viewer page, the gallery Watch button and the 2D tap.
- [ ] **Step 4: Run the full suite and build both platforms.** Expected: PASS.
- [ ] **Step 5: Run the app:** hang a new painting, open it from the 3D gallery (button, and with a hand held on the button), watch the timelapse, play with the sheet, Back lands on the same painting in 3D; open one from the 2D grid, Back lands on the 2D grid; open a painting made before this feature: no timelapse, no Replay, still interactive.
- [ ] **Step 6: Commit** the files named above with `feat: watch a painting's timelapse from the gallery`.

---

### Task 11: Faithful renderer spike and gate

**Files:**
- Create: `PuffyPond/Timelapse/PaintLayerReplayer.swift`, `docs/superpowers/specs/2026-11-03-timelapse-replay-spike-result.md`
- Modify: `PuffyPond/Review/ReviewStage.swift` (default `makeRenderer`, studio lights while the replay plays)
- Test (only if adopted): `PuffyPondTests/PaintLayerReplayerTests.swift`

**Interfaces:**
- Consumes: `ReplayRenderer`, `PaintLayer(center:size:z:pixelsAcross:)`, `PaintLayer.stamp/erase/update(dt:)`, `Playground.canvasSize`.
- Produces: `final class PaintLayerReplayer: ReplayRenderer { init(recording: StrokeRecording, timeline: ReplayTimeline, resolution: Int) }` with its own `PaintLayer`, its `node` scaled and moved from easel world space (centre `(0, 0.1)`, size `canvasSize`) into sheet space.

This is the spike the spec calls for. The decision gate is: it holds about 60 fps on the slowest device the owner actually uses (iPad and Mac) for a long recording, and the owner judges by eye that it looks close to the original painting. Same colours, strokes and order is enough; pixel equality is not required.

- [ ] **Step 1: Build `PaintLayerReplayer`.** Re-issue recorded events through its own `PaintLayer` in recorded order, stepping the simulation at the original frame time (1/60 s) and several steps per displayed frame to compress time; skip idle gaps with a bounded settle. Give the review scene studio-like lights while it plays (look at `Playground`'s `studioLights`) and drop them when the sheet takes over. Use a lower `resolution` than the live layer if memory is tight.
- [ ] **Step 2: Wire it in behind a debug switch** (a launch argument or a `#if DEBUG` toggle on `ReviewStage.makeRenderer`), keeping `MaskReplayer` the default.
- [ ] **Step 3: Measure** on each device the owner uses: record a long session (5 minutes of continuous painting with several brushes and some erasing), replay it, log frame times for the whole replay, and note the lowest sustained frame rate and the memory used. Compare the replay's last frame with the saved painting by eye.
- [ ] **Step 4: Ask the owner to look** at the replay next to the original painting and judge "close enough".
- [ ] **Step 5: Write the result** in `docs/superpowers/specs/2026-11-03-timelapse-replay-spike-result.md`: devices, frame rates, memory, the owner's verdict, and the decision.
- [ ] **Step 6a: If it passes,** make `PaintLayerReplayer` the default `makeRenderer`, keep `MaskReplayer` as the fallback for devices where `PaintLayer` cannot start, and add `PaintLayerReplayerTests`: across random frame lengths every recorded event is issued exactly once and in order, and `reset()` followed by a replay issues them again.
- [ ] **Step 6b: If it fails,** leave `MaskReplayer` as the default, remove the debug switch, and record in the result file why (frame rate, memory or look).
- [ ] **Step 7: Run the full suite and build both platforms.** Expected: PASS.
- [ ] **Step 8: Commit** the files you touched with `feat: faithful timelapse renderer` (6a) or `docs: timelapse renderer spike result` (6b).

---

### Task 12: Whole-flow check

**Files:** none (verification only).

- [ ] **Step 1: Run the full suite on macOS and build for iOS Simulator.** Expected: all tests PASS, BUILD SUCCEEDED, no new warnings in new files.
- [ ] **Step 2: Walk the owner's flow on a device:** paint with each brush animal and the eraser, Save image → timelapse with a note per stroke and a poof for erasing, Skip works, sheet wakes, grab, push and stretch work, Replay replays, Keep drawing returns to the same easel and a second Save image replays both sittings, Save to gallery, then watch it again from the 3D and the 2D gallery.
- [ ] **Step 3: Check the edges:** a painting with one tiny stroke; a session left idle for a minute in the middle (no long pause in the replay); a very long session (the timelapse is still about 18 s and the saved files stay small, check the size of the `.timelapse` file); muting the sound mutes the notes; leaving the page mid-timelapse is silent.
- [ ] **Step 4: Report** what was run and what was not (any device not available).
