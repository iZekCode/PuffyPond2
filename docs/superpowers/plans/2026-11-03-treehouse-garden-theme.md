# Treehouse Garden Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-theme Puffy Pond as a whimsical treehouse garden: five new cute bug characters on the fist-scheme tool column, garden backdrops and particle effects, a garden tune and silly synthesized sound effects, while the old sea animals and the legacy scheme keep working.

**Architecture:** New `Critter` subclasses (`Spider`, `Ladybug`, `Caterpillar`, `Bee`) are added next to the old ones; `PaintTool.critterKind` switches the fist scheme to them and `CritterKind.legacyBrushes` stays untouched. The spider shares the octopus's limb-brush logic through a new `LimbBrush` helper. The eraser is a normal `Critter` in the fist scheme (no starfish hide/show swap); `Buddy` keeps the starfish only for the legacy scheme. Backdrops, particles and audio are shared by both schemes.

**Tech Stack:** Swift, SceneKit, Metal paint layer, AVAudioEngine procedural synth (`GrooveDSP`), Swift Testing (`PuffyPondTests`). The project uses Xcode synchronized groups, so new files under `PuffyPond/` and `PuffyPondTests/` are picked up without editing the `.pbxproj`.

**Spec:** `docs/superpowers/specs/2026-11-03-treehouse-garden-theme-design.md`

## Global Constraints

- Platforms: iPad (landscape main layout) and Mac; no third-party dependencies.
- No recorded audio: every sound stays synthesized in `GrooveDSP`.
- Do not change paint simulation, `BrushStyle`s, the NCA texture models (`PuffyPond/NCA/octopus.bin`), the fist control scheme, tool order or the six paint colours.
- Do not rename or remove old identifiers (`Octopus`, `octopusSize`, `octopus.bin`, `Starfish`, `CritterKind.legacyBrushes`, the legacy scheme): the sea animals still use them.
- App name stays "Puffy Pond".
- Every new character: friendly face from the `Critter` face rig, a distinct silhouette and colour, and constant idle motion.
- Run tests on macOS: `xcodebuild test -project PuffyPond.xcodeproj -scheme PuffyPond -destination 'platform=macOS'` (add `-only-testing:PuffyPondTests/<Struct>` to run one suite).
- Commit only the files a task names. Never `git add -A` (the working tree has unrelated `.DS_Store` and `tools/nca/targets/` changes).

## Review Focus

- A critter swapped in by a bubble appears at the old one's position, possibly far away: limbs must not fling or go non-finite (spider, caterpillar).
- Touch or mouse eraser (`pointerErases`) in the fist scheme: the caterpillar scrubs, no starfish appears.
- The legacy scheme must behave exactly as before: fist → starfish swap with the `swap` sound, pinch paints with the six sea brushes.
- Sound effects must not clip or go silent, and new ones must be bounded (no endless voices) when fired repeatedly.
- The caterpillar must erase at least as wide a swath as the starfish did, so dotted guides and strokes still clear as easily.

---

### Task 1: Extract `LimbBrush` from `Octopus` (no behaviour change)

**Files:**
- Create: `PuffyPond/LimbBrush.swift`
- Modify: `PuffyPond/Octopus.swift`
- Test: `PuffyPondTests/LimbBrushTests.swift`

**Interfaces:**
- Produces:
  ```swift
  final class LimbBrush {
      init(bundle: TentacleBundle, limbZ: Float)
      func animate(dt: Float, velocity: SIMD2<Float>, head: SIMD3<Float>, body: simd_float4x4,
                   scale: Float, clock: Float, beatPulse: Float, pressing: Bool, hidden: Bool)
      func dabs(towards head: SIMD2<Float>) -> [BrushDab]
  }
  ```
  `animate` holds everything `Octopus.animate` does with the bundle (teleport snap, smoothed velocity, trail, spread, hold timer, `simulate`/`collectTips`/`collectContacts`/`rebuild`); `dabs` holds `Octopus.dabs`'s ooze and contact logic. Move the `trailSpeed`, `oozeDelay`, `oozeGrowth`, `oozeSpeed` constants with them.

- [ ] **Step 1: Write the characterization test.** In `LimbBrushTests.swift` add `@MainActor struct LimbBrushTests` with a helper `settle(_ c: Critter, frames: Int, target: SIMD3<Float>, painting: Bool)` that calls `c.update(dt: 1.0/60, target: target, visible: true, painting: painting, beatPulse: 0)` in a loop. Test `octopusLaysItsLimbsFlatWhilePressing`: make `Octopus(color: Paint.colors[0], at: .zero)`, settle 180 frames at `SIMD3(0, 0, Playground.paintHoverZ)` with `painting: true`, then `let dabs = octopus.dabs(from: .zero, to: .zero, radius: 0.085, speed: 0)`; expect `!dabs.isEmpty`, `dabs.allSatisfy { $0.style.nca == 1 }`, and `dabs.count == N`.
- [ ] **Step 2: Run it against the unmodified code and pin N.** Run `-only-testing:PuffyPondTests/LimbBrushTests`. Expected: the first run fails only on `dabs.count == N` with the real count; write that count in as N and re-run to PASS.
- [ ] **Step 3: Implement `LimbBrush` and make `Octopus` delegate to it.** Octopus keeps its init, body and `flare`; `animate`/`dabs` become one-line calls.
- [ ] **Step 4: Run the suite.** Expected: PASS with the same N.
- [ ] **Step 5: Commit** `git add PuffyPond/LimbBrush.swift PuffyPond/Octopus.swift PuffyPondTests/LimbBrushTests.swift && git commit -m "refactor: share limb brush logic between critters"`

### Task 2: Garden spider (brush)

**Files:**
- Create: `PuffyPond/Spider.swift`
- Modify: `PuffyPond/Critter.swift` (new `case spider`; `name` "Spider", `brush` "bundle brush", `symbol` "scribble.variable", `signatureColor` `Paint.colors[0]`, `make` → `Spider`; add `var usesSizeSlider: Bool { false }` to `Critter`), `PuffyPond/Octopus.swift` (override `usesSizeSlider` → true), `PuffyPond/Canvas/PaintTool.swift` (`.brush` → `.spider`), `PuffyPond/Playground.swift` (line ~117 `buddyKinds = [.spider, .spider]` for the fist scheme; lines ~383-386 use `buddy.critter.usesSizeSlider` instead of `is Octopus`, rename `bigOctopus` to `bigBrush`)
- Test: `PuffyPondTests/GardenCastTests.swift`

**Interfaces:**
- Consumes: `LimbBrush`, `TentacleBundle(shape:roots:start:)` from `Tentacles.swift`.
- Produces: `final class Spider: Critter { init(color: SIMD3<Float>, at start: SIMD3<Float>) }`, `Critter.usesSizeSlider: Bool`.

- [ ] **Step 1: Write failing tests** in `GardenCastTests.swift` (`@MainActor struct GardenCastTests`, same `settle` helper as Task 1): `brushToolIsTheSpider` (`PaintTool.brush.critterKind == .spider`); `spiderIsBuiltByKind` (`CritterKind.spider.make(...)` `is Spider`, `.kind == .spider`); `spiderLaysLegsFlatWhilePressing` (settle 180 pressing frames, `dabs` non-empty, all `style.nca == 1`); `spiderSurvivesATeleport` (settle 30 frames at the origin, then 30 at `SIMD3(3, 0, 0.4)`; every dab's `from`/`to` has finite components); `spiderUsesTheSizeSlider` (`Spider(...).usesSizeSlider`).
- [ ] **Step 2: Run** `-only-testing:PuffyPondTests/GardenCastTests`. Expected: FAIL to compile (`Spider` undefined).
- [ ] **Step 3: Implement `Spider`.** Fuzzy round abdomen (sphere r≈0.13) plus smaller head (r≈0.09), big friendly eyes (`eyeRadius` ≈0.065) via `addFace`, cheeks, eight legs through a `TentacleBundle` + `LimbBrush(limbZ: Octopus.limbZ)`. Starting `TentacleBundle.Shape` (tune by eye): `segments 9, segmentLength 0.045, rootRadius 0.014, tipRadius 0.005, startAngle 0.9, curl 0.9, sway 0.35, stiffness 0.16, gravity 1.0`. Idle motion: slow body sway and an occasional leg tap through `animate`. Wire `Critter.swift`, `PaintTool.swift`, `Playground.swift` as listed.
- [ ] **Step 4: Run** the suite, then `-only-testing:PuffyPondTests/ControlSchemeTests`. Expected: PASS.
- [ ] **Step 5: Build and look.** Run the app on My Mac, use the mouse (hold a button to paint): the spider paints a watercolour wash with its legs lying flat; the size slider still scales it. Screenshot the result.
- [ ] **Step 6: Commit** the files listed above.

### Task 3: Ladybug (liquid oil)

**Files:**
- Create: `PuffyPond/Ladybug.swift`
- Modify: `PuffyPond/Critter.swift` (`case ladybug`, "Ladybug", brush "watercolor", symbol "drop.halffull", `signatureColor` `Paint.colors[5]`, `make`), `PuffyPond/Canvas/PaintTool.swift` (`.liquidOil` → `.ladybug`)
- Test: `PuffyPondTests/GardenCastTests.swift`

**Interfaces:**
- Produces: `final class Ladybug: Critter { init(color: SIMD3<Float>, at start: SIMD3<Float>); private(set) var wingOpen: Float }` (0 closed … ~1 open, may overshoot to 1.2).

- [ ] **Step 1: Write failing tests:** `liquidOilIsTheLadybug`; `ladybugWingsFlapWithTheBeat` (10 frames at `beatPulse: 1`, 10 at 0, repeat 3 times while recording `wingOpen`; expect `max - min > 0.3` and every value in `0...1.2`).
- [ ] **Step 2: Run, expect FAIL** (`Ladybug` undefined).
- [ ] **Step 3: Implement `Ladybug`.** Round shell using `bodyMaterial` (follows the paint colour) with fixed dark dots, black head with `addFace`, two shell halves on pivots that open and close in time with `beatPulse` (a `Spring1`) and flutter faster while painting, tiny wobbling legs, small glaze drips (`Toybox.burst`, low count) on each wing opening while painting. It does not override `dabs` (the liquid-oil tool paints in `PaintTool.dabs`).
- [ ] **Step 4: Run the suite, expect PASS. Look at it in the app** (rub the liquid-oil bubble or use `Playground(controlScheme:)` default) and screenshot.
- [ ] **Step 5: Commit.**

### Task 4: Bee (blender)

**Files:**
- Create: `PuffyPond/Bee.swift`
- Modify: `PuffyPond/Critter.swift` (`case bee`, "Bee", brush "blender", symbol "tornado", `signatureColor` `SIMD3(1.0, 0.86, 0.38)`, `make`), `PuffyPond/Canvas/PaintTool.swift` (`.blender` → `.bee`)
- Test: `PuffyPondTests/GardenCastTests.swift`

**Interfaces:**
- Produces: `final class Bee: Critter { init(color: SIMD3<Float>, at start: SIMD3<Float>); private(set) var wiggle: Float }` (0 idle … 1 blending, a spring like `Sponge.squeeze`); `override var blowsInk: Bool { false }`.

- [ ] **Step 1: Write failing tests:** `blenderToolIsTheBee`; `beeWigglesOnlyWhileBlending` (60 painting frames → `wiggle > 0.8`; then 60 idle → `wiggle < 0.1`).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `Bee`.** Fat fuzzy striped body, friendly face with no stinger, two blurred wings that buzz constantly (fast scale/rotation flicker), bottom wiggle scaled by `wiggle`, hovers with a slightly bigger `bob`.
- [ ] **Step 4: Run the suite, expect PASS. Look at it in the app** and screenshot.
- [ ] **Step 5: Commit.**

### Task 5: Caterpillar (eraser) and the eraser plumbing

**Files:**
- Create: `PuffyPond/Caterpillar.swift`
- Modify: `PuffyPond/Critter.swift` (`case caterpillar`, "Caterpillar", brush "eraser", symbol "leaf.fill", `signatureColor` `Paint.colors[4]`, `make`; add `var eraseRadius: Float { Starfish.eraseRadius }` and `func scrubbed() {}` to `Critter`), `PuffyPond/Canvas/PaintTool.swift` (`.eraser` → `.caterpillar`), `PuffyPond/Characters.swift` (`Buddy`), `PuffyPond/Playground.swift`
- Test: `PuffyPondTests/GardenCastTests.swift`

**Interfaces:**
- Produces: `final class Caterpillar: Critter { static let eraseRadius: Float; private(set) var chomp: Float; override func scrubbed() }`; `Buddy.init(slot:colorIndex:kind:start:tool:erasesWithStarfish: Bool = true)`; `Buddy.eraseRadius: Float`; `Buddy.scrubbed()`.

- [ ] **Step 1: Write failing tests:** `legacyEraserStillSwapsToTheStarfish` (`Buddy(slot: 0, colorIndex: 0, kind: .octopus, start: .zero)`: `setMode(.erase) == true`, `showsStarfish`, `eraseRadius == Starfish.eraseRadius`); `gardenEraserIsTheCaterpillar` (`Buddy(..., kind: .spider, erasesWithStarfish: false)`: `equip(.eraser)` returns the old `Spider`, `critter is Caterpillar`, `!showsStarfish`, `setMode(.erase) == false`, `eraseRadius == Caterpillar.eraseRadius`); `eraserBubbleHoldsNoStarfishInTheGardenScheme` (`CritterPot(tool: .eraser, at: .zero).starfish == nil`); `scrubbedOpensTheMouth` (`chomp > 0` after `scrubbed()` plus 5 updates); `caterpillarSurvivesATeleport` (as the spider test, run `update` and check `bodyNode.simdPosition` is finite); `caterpillarErasesAtLeastAsWideAsTheStarfish` (`Caterpillar.eraseRadius >= Starfish.eraseRadius`); `pointerEraserEquipsTheCaterpillar` (`Playground(controlScheme: .fist)`, set `pointerErases = true`, run one frame update, expect the pointer's buddy `critter is Caterpillar` and `!showsStarfish`; make `buddies` `private(set)` instead of `private` if the test needs it).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement `Caterpillar`.** Big round head with a chewing mouth and a segmented body (about 6 segments, spheres) following the head through a short lagging chain; body arches while moving, mouth opens and closes while `painting` is true (the Playground passes true while erasing); `scrubbed()` kicks `chomp` and sprays a few leaf crumbs. `eraseRadius` = `Starfish.eraseRadius` (0.26).
- [ ] **Step 4: Implement `Buddy` changes.** `erasesWithStarfish` stored; `updateStarfish` wanted = `erasesWithStarfish && (mode == .erase || tool == .eraser)`; `eraseRadius`/`scrubbed()` forward to the starfish when `showsStarfish`, else to `critter`. `toolPosition`/`toolSpeed` already pick the right rig.
- [ ] **Step 5: Implement `Playground` changes.** Create buddies with `erasesWithStarfish: controlScheme == .legacy`. In `erase(with:)` replace `buddy.starfish.position.value`, `Starfish.eraseRadius`, `buddy.starfish.scrubbed()` with `buddy.toolPosition`, `buddy.eraseRadius`, `buddy.scrubbed()`. In the update loop pass `painting: (mode == .paint || mode == .erase) && !buddy.showsStarfish` to `buddy.critter.update`. Make `pointerErases` equip `.eraser` on the pointer's buddy while on (and restore its previous tool when off) in the fist scheme, using the swap code in the `.tool` pot case (remove the old critter node, add the new one); the pointer's slot is where the pointer `HandState` is built (~line 360). The legacy scheme keeps `tool = pointerErases ? .eraser : buddy.tool` as is.
- [ ] **Step 6: Run the whole suite**, expect PASS (including `legacySchemeUnchanged`). In the app: rub the eraser bubble and scrub over paint and over a template's dotted guide; both vanish; no starfish appears; the mouse eraser button shows the caterpillar.
- [ ] **Step 7: Commit.**

### Task 6: Garden cast list, gallery visitors, pots

**Files:**
- Modify: `PuffyPond/Critter.swift` (add `static let gardenCast: [CritterKind] = [.spider, .snail, .ladybug, .caterpillar, .bee]`), `PuffyPond/Gallery.swift` (line ~450: loop over `CritterKind.gardenCast`)
- Test: `PuffyPondTests/GardenCastTests.swift`

**Interfaces:**
- Consumes: Tasks 2-5.
- Produces: `CritterKind.gardenCast`.

- [ ] **Step 1: Write failing tests:** `gardenCastIsTheToolColumn` (`Set(CritterKind.gardenCast) == Set(PaintTool.allCases.compactMap(\.critterKind))`, `count == 5`); `gardenCastLooksDistinct` (signature colours pairwise different); `everyGardenCritterBuilds` (for each kind, `make` returns a critter with `.kind == kind` and survives 60 `update`s in both painting and idle states).
- [ ] **Step 2: Run, expect FAIL** (`gardenCast` undefined).
- [ ] **Step 3: Implement.** Add `gardenCast`, switch the gallery visitors to it. Check `Gallery.layout` still spaces five visitors evenly.
- [ ] **Step 4: Run the suite, expect PASS. Open the 3D gallery in the app** (needs one saved painting) and confirm five bugs look up at it.
- [ ] **Step 5: Commit.**

### Task 7: Garden particles

**Files:**
- Modify: `PuffyPond/Effects.swift`, `PuffyPond/Critter.swift` (`addFace` calls `Effects.petals()` instead of `Effects.inkBubbles()`), `PuffyPond/Playground.swift` and `PuffyPond/Gallery.swift` (attach fireflies to the scene)
- Test: `PuffyPondTests/GardenSceneTests.swift`

**Interfaces:**
- Produces: `Effects.petals() -> SCNParticleSystem` (rename of `inkBubbles()` with a petal image), `Effects.fireflies() -> SCNParticleSystem` (slow, glowing, drifting specks), petal/leaf CGImage makers replacing `makeBubble()`.

- [ ] **Step 1: Write failing tests:** `petalsHaveAnImage` (`Effects.petals().particleImage != nil`); `firefliesAreAlive` (`Effects.fireflies().birthRate > 0`, `particleLifeSpan > 1`).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Petal/leaf image drawn with CoreGraphics like `makeStar()`; `colorSplash` adds a petal burst; `sparkles` become warm yellow-green pollen specks; pop shards stay. Fireflies hang near the easel in `Playground` and above the deck in `Gallery`.
- [ ] **Step 4: Run the suite, expect PASS. Check in the app:** painting emits petals tinted by the colour; picking a colour splashes petals.
- [ ] **Step 5: Commit.**

### Task 8: Treehouse backdrops

**Files:**
- Modify: `PuffyPond/Studio.swift` (`Studio.backdrop()`; retune light helpers at ~199 if needed), `PuffyPond/Gallery.swift` (`Gallery.backdrop()`, `wallMaterial` ~325, light colours), `PuffyPond/Pages/HomeView.swift` (`PageBackground`), `PuffyPond/Playground.swift` (`scene.background.intensity` ~153 if needed)
- Test: `PuffyPondTests/GardenSceneTests.swift`

**Interfaces:**
- Keeps: `static func backdrop() -> PlatformImage?` on both, same output size.

- [ ] **Step 1: Write failing tests** (macOS pixel reads, mirroring how `PaintMatteTests` reads pixels): `studioBackdropHasLeafLight` (non-nil; at least 10% of pixels are green-dominant, `g > r + 0.03 && g > b + 0.03`); `galleryBackdropIsGreenNotMuseumGrey` (non-nil; at least 15% green-dominant pixels, and mean green > mean blue). Tune the thresholds to the finished art but keep them above what the current cream room and blue-grey museum score.
- [ ] **Step 2: Run, expect FAIL** (the current room and museum have almost no green-dominant pixels).
- [ ] **Step 3: Implement.** Studio: blurred treehouse interior with warm wood planks, dappled leaf-shaped light through a window, string lights, foliage. Gallery: blurred deck among branches and canopy with sky glow; `wallMaterial` becomes warm wood; keep the camera, partitions and layout. Home/Report pages' `PageBackground` moves from pond blue to soft leaf greens and sky. Keep everything procedural.
- [ ] **Step 4: Run the suite, expect PASS. Look at each page in the app** (Home, canvas, 3D gallery, 2D grid, review, report) and screenshot; the paint colours on the canvas must still read true (check that the canvas, not only the room, is unaffected).
- [ ] **Step 5: Commit.**

### Task 9: Silly sound effects

**Files:**
- Modify: `PuffyPond/GrooveDSP.swift` (`Sfx`, `playEffect`, offline render helper), `PuffyPond/Playground.swift`, `PuffyPond/Review/*` or `PuffyPond/Pages/ReviewView.swift` only if a call site needs it
- Test: `PuffyPondTests/GardenSoundTests.swift`

**Interfaces:**
- Produces: `Sfx: CaseIterable`, new cases `bonk`, `splorp`, `chicken`, `buzz`, `crunch`; `GrooveDSP.renderOffline(frames: Int) -> (left: [Float], right: [Float])` (internal, runs `render` into a temporary stereo `AudioBufferList`).
- Trigger points: `crunch` replaces `squeak` when the erasing rig is the caterpillar (the starfish keeps `squeak`); `buzz` (`a` = speed 0…1) while the bee blends, at most every 0.25 s; `bonk` replaces `swap` when a tool bubble completes; `splorp` at the start of a liquid-oil stroke; `chicken` replaces the `pick` ding on 1 of 12 colour pickups.

- [ ] **Step 1: Write failing tests.** `GardenSoundTests`: for every `Sfx.allCases`, `let d = GrooveDSP(sampleRate: 48_000); d.play(SfxEvent(kind: k, a: 0.5, b: 0)); let (l, r) = d.renderOffline(frames: 48_000)`; expect all samples finite and `0.02 < peak < 1.0`. Add `repeatedEffectsStayBounded`: play each new effect (`bonk`, `splorp`, `chicken`, `buzz`, `crunch`) 20 times in one go, render 1 s: all samples finite and peak < 1.0 (add a soft clip in `render` if the sum overshoots).
- [ ] **Step 2: Run, expect FAIL** (no `CaseIterable`, no `renderOffline`).
- [ ] **Step 3: Implement.** Add the helper and the five sounds (rubber-chicken squawk = two detuned saws with a fast pitch warble; bonk = low sine with a quick pitch drop plus a woodblock click; splorp = filtered noise plus a sliding sine; buzz = detuned square at ~220 Hz with fast vibrato, short; crunch = three short band-passed noise bursts). Wire the trigger points. Keep each effect under ~0.6 s and peak ≤ 0.35 per voice.
- [ ] **Step 4: Run the suite, expect PASS. Listen:** exercise each trigger in the app; confirm none is painful at normal volume.
- [ ] **Step 5: Commit.**

### Task 10: Garden background tune

**Files:**
- Modify: `PuffyPond/GrooveDSP.swift` (`playStep`, the `roots`/`triads`/`bassSteps`/`melody` tables, `bpm`, doc comments)
- Test: `PuffyPondTests/GardenSoundTests.swift`

**Interfaces:**
- Keeps `Tune.groove` as the case name (now the garden tune) and `Tune.silly` unchanged; `GrooveDSP.beat` semantics unchanged.

- [ ] **Step 1: Write failing tests:** `gardenTuneIsAudibleAndBounded` (render 8 bars at energy 0 and at energy 1: finite, `0.05 < peak < 0.95`); `beatClockAdvances` (after 4 s at 48 kHz, `beat` ≈ `4 * bpm / 60` ± 0.1); `sillyTuneStillPlays` (`setTune(.silly)`, render 4 bars: peak > 0.05). Add `gardenTuneUsesTheGardenTempo` (`GrooveDSP.bpm == 104`). The first three guard behaviour that must survive; the tempo test is the one that fails first.
- [ ] **Step 2: Run, expect FAIL** on the tempo test only.
- [ ] **Step 3: Implement.** Replace the four-on-the-floor kick/clap/saw-lead groove with: soft woodblock-and-shaker rhythm, plucked ukulele chords (short triangle plus a touch of FM), pizzicato bass, a xylophone-like lead (sine plus a fast-decaying FM partial) over a bouncy G–C–D–Em loop, at about 104 BPM. Energy still swells layers. Leave `playSillyStep` as it is.
- [ ] **Step 4: Run the suite, expect PASS. Listen** for a few minutes at idle and while painting; check it is cheerful, not grating, and that animations on the beat still look right.
- [ ] **Step 5: Commit.**

### Task 11: Copy and docs

**Files:**
- Modify: `PuffyPond/HUDView.swift` (fist-scheme strings only: ~87-90, ~199-203, ~299-302; leave the legacy strings at ~97-100 and ~314-317), `README.md` (tool table ~53-57, legacy note ~65, file table ~104-105), `PuffyPond/Playground.swift` (any remaining player-facing sea wording)

- [ ] **Step 1: Edit the copy.** Fist hints: "Caterpillar munch! Keep your fist closed to eat the paint away", "… follow the dotted line · the caterpillar nibbles it away"; slider label "How big the brush spider is"; the tool row detail "Snail thick oil, ladybug liquid oil, spider brush, caterpillar eraser, bee blender."; the eraser row title "Caterpillar = eraser" with matching detail and symbol. README table: Snail / Ladybug / Spider / Caterpillar / Bee, plus one line saying the old sea animals remain in the legacy scheme; add the new files to the file table.
- [ ] **Step 2: Verify.** Run `grep -n -i -E 'starfish|jelly|octopus|sponge|sea' PuffyPond/HUDView.swift PuffyPond/Pages/*.swift README.md`. Expected: remaining hits only in legacy-scheme text and the legacy note.
- [ ] **Step 3: Commit.**

### Task 12: Final verification

- [ ] **Step 1: Full test run** with the macOS command above. Expected: all suites PASS.
- [ ] **Step 2: Build both platforms.** `xcodebuild build -project PuffyPond.xcodeproj -scheme PuffyPond -destination 'platform=macOS'` and with `-destination 'generic/platform=iOS Simulator'`. Expected: BUILD SUCCEEDED, no new warnings in the new files.
- [ ] **Step 3: Play through on My Mac with the mouse.** Home → freeform → paint with each of the five tools → swap tools by rubbing bubbles → erase paint and a template guide with the caterpillar → save → review page → 3D gallery → 2D grid → report. Confirm no sea animal, bubble or museum is visible in the fist scheme, the frame rate stays smooth with two critters, and the sounds fire.
- [ ] **Step 4: Legacy scheme check.** Start with `Playground(controlScheme: .legacy)`: pinch paints with the six sea brushes, fist swaps to the starfish with its sound.
- [ ] **Step 5: Report** what was verified and what was not (camera/hand tracking cannot be exercised without a camera and a person).
