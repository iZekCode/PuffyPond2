# Puffy Pond

Paint in the air with your hands. Make a fist and sweep your arm: a little paint character follows each hand and lays real-looking wet oil paint on an easel. Pick a template or paint freely, play with the finished painting on a wobbly sheet, hang it in a walkable 3D treehouse gallery, and look back at a calendar of what you painted and how your arms moved.

## Run it

1. Open `PuffyPond.xcodeproj` in Xcode 26.
2. Signing & Capabilities → pick your team.
3. Choose an **iPad** (landscape is the main layout) or **My Mac** as the run destination, press **⌘R** and allow camera access.
4. Stand or sit about 1 m from the camera so it sees your shoulders and both hands.

No camera (or the simulator)? Every step also works by touch or mouse: see "Without a camera" below.

## The flow

```
Home ──► Start drawing ──► Freeform ─────────────────────────┐
  │                   └──► Templates (daily quest on top,    ▼
  │                        near → far,   progressive unlock)  Get ready (distance check)
  │                                                          ▼
  │                                                          Canvas (fist paints, "Save image")
  │                                                          ▼
  │                                                          Review (push & grab, "Save to gallery")
  │                                                          ▼
  ├──► View gallery ────────────────────────────────────►  3D gallery (paddle to walk) ◄──► 2D grid
  └──► Report (calendar + the day's paintings and movement stats)
```

| Page | What happens |
|---|---|
| **Home** | Start drawing, View gallery or Report. |
| **Freeform or template** | A blank canvas, or pick a dotted outline to trace. |
| **Templates** | The **daily quest** sits on top: a random subject rolled once per day from its own pool (rocket, house, flower, …). Below it, nine abstract shapes to trace, so kids decide what they become (pebble, bean, puddle · bumpy, wiggle, peanut · reach, sprawl, zigzag). No level labels are shown, but the order still goes from simple blobs to big shapes that stretch into every corner (the last three), to widen the range of motion. A template unlocks once a painting of the one before it is in the gallery, so deleting that painting locks it again. |
| **Get ready** | A skeleton outline shows where to stand. Step back until your shoulders fit the band (about 1 m) and hold still while the ring fills; the canvas opens by itself. **Skip** is always there. |
| **Canvas** | Paint with your fists (see below). The chosen template shows as a dotted guide. **Save image** takes you to the review; the house button goes Home (it asks first if the painting isn't saved). |
| **Review** | The bare canvas stays put; the paint floats above it on an elastic see-through sheet. Fist = grab a small patch of paint and pull it along while the rest stays put, two fists = two patches pulled apart (slide whistle), a moving open palm = push ripples with a splat (sometimes a duck). Let go and the paint jiggles back. A silly kazoo-and-tuba tune plays here. The play never changes the saved picture. **Save to gallery** or **Keep drawing** (back to the same canvas). |
| **3D gallery** | A treehouse deck among the branches with your paintings on wooden partitions, newest first, and the five garden critters visiting. Paddle with an open hand: sweep down on the right side to walk to the next painting, on the left to go back. Arrows and swipes work too. **View gallery in 2D** (bottom left) shows a grid grouped by day; tap one to walk to it. |
| **Report** | A month calendar on the left: days with paintings get a dot, a star when the daily quest was done. The selected day on the right: its paintings, **Highest ROM** (shoulder abduction, left and right), elbow extension, reach height and area, grip cycles, a lean flag, a **heatmap** of where you painted on the canvas, and **hand dominance** (share of painting time per hand). |

The movement stats are 2D estimates from the front camera (Vision body and hand pose), not clinical measurements. They are recorded only on the canvas page and only from camera hands; a painting made by touch or mouse shows "No movement data". Left and right are always the person's own sides.

## Painting on the canvas

| Move | What happens |
|---|---|
| Open hand | Your hand's paint character swims along with you. No paint. |
| **Fist** | Paint with the character's tool. Keep the fist closed and sweep your arm; open the hand to stop. A loosening fist keeps painting for a moment, so strokes don't break. |
| Rub a **paint pot** | Pots stand in a column on the right. Swipe your character back and forth through one until the ring fills: new color. |
| Rub a **tool bubble** | Bubbles in a column on the left hold the five paint characters. Rub one to switch to its tool. |

| Tool | Character | How it paints |
|---|---|---|
| Thick oil | Snail | Heavy impasto: a wide knife-like sheet, piled high with ridged edges. |
| Liquid oil | Ladybug | Thinned oil: a translucent glaze that spreads and runs downhill while wet. |
| Brush | Garden spider | Eight long legs lie on the canvas and wipe a thin watercolor wash with a grown-in texture. |
| Eraser | Hungry caterpillar | Scrubs paint away and wipes the template's dotted guide. |
| Blender | Bee | Lays no paint; smudges and mixes the wet paint underneath. |

The paint is simulated: flat wet strokes with bristle grooves and ragged edges, it levels out, blends with wet neighbours, thick blobs sag a little, and it dries over time.

The buttons down the left side: Home, eraser for touch (iPad only), music, camera preview, help card, clear canvas.

### Legacy controls

The original controls and their sea animals are still in the code: pinch to paint with six brush animals (octopus, snail, pufferfish, seahorse, jellyfish, frog), fist turns into the starfish, and template bubbles on the easel tray (they now swim in the garden world). Start the playground with `Playground(controlScheme: .legacy)` in `ContentView` to use them.

## Without a camera

| Step | Touch / mouse |
|---|---|
| Home, mode, templates, report, 2D gallery | Tap / click. |
| Get ready | Tap **Skip**. |
| Canvas | Drag to paint with the current tool; drag through a pot or bubble to change color or tool. To erase: the eraser button on iPad, ⌥-drag or right-drag on Mac. |
| Review | Drag the sheet to grab and pull it. |
| 3D gallery | Arrow buttons, or swipe left/right. |

## Your data

Everything stays on the device in `Application Support/Gallery/`: one PNG per painting plus a JSON sidecar with the template it was made from and the movement stats of that session. Paintings saved before sidecars existed get an empty one on first launch and still show everywhere. Unlocks and the report are worked out from these files; nothing else is stored except today's daily quest (`UserDefaults`). No network, no accounts.

## Under the hood

| File | Role |
|---|---|
| `ContentView.swift` | Owns the long-lived `Playground`, `HandTracker` and `Gallery` and swaps the full-screen page for the current route |
| `App/AppRouter.swift` | The routes (`Route`) and the router that moves between pages |
| `Pages/HomeView.swift`, `ModePickerView.swift`, `TemplatesView.swift` | Home, freeform-or-template choice, template list with the daily quest and unlocks |
| `Pages/InstructionView.swift` | Get ready page: skeleton outline and distance ring |
| `Pages/ReviewView.swift`, `Review/ReviewStage.swift` | Review page and its 3D stage (orthographic camera, sheet mesh rebuilt every frame) |
| `Review/SheetSolver.swift`, `Review/SheetGestures.swift` | The paint as one elastic grid that always springs back to rest; hands → grab, stretch, push (a fist drags a small patch in small steps, so the rest stays put and the grid hardly bunches) |
| `Gallery.swift` | Saved paintings with their records, the 3D museum hall, and the gallery screen |
| `Pages/Gallery2DView.swift` | Flat grid of every painting grouped by day |
| `Pages/ReportView.swift`, `Stats/DayReport.swift` | Report page; one day's paintings and their merged stats |
| `Stats/SessionRecorder.swift`, `Stats/SessionStats.swift` | Records painting time, heatmap, grip cycles and ROM during a canvas session; the saved stats |
| `Templates/TemplateCatalog.swift`, `Templates/DailyQuest.swift` | Template order and unlocks; the daily quest pool and the roll of the day |
| `Template.swift` | Outline art (SVG-style paths), the nine abstract templates and the dotted guide on the canvas |
| `Input/DistanceGate.swift` | Shoulder width in the camera image → too close / too far / good, with the hold timer |
| `Input/PaddleDetector.swift` | Open hand sweeping down → walk on or back in the 3D gallery |
| `Input/HandFrameRelay.swift` | Passes camera hand frames to the review page and the 3D gallery |
| `HandTracker.swift` | Camera + Vision hand pose (2 hands) and body pose (only while a page needs it), on device |
| `HandInput.swift`, `OneEuroFilter.swift` | Palm tracking, open/pinch/fist with hysteresis, smoothing + prediction |
| `Canvas/ControlScheme.swift`, `Canvas/PaintTool.swift` | Fist vs legacy controls; the five tools and the dabs each one lays |
| `Playground.swift` | The easel: world, buddies, painting, erasing, pots and bubbles, stats recording |
| `Critter.swift`, `Characters.swift`, `Tentacles.swift` | Character base (springs, faces, moods), starfish rig (legacy eraser), pots, bubbles, buddies, springy limbs, the shared limb brush |
| `Spider.swift`, `Snail.swift`, `Ladybug.swift`, `Caterpillar.swift`, `Bee.swift` | The five garden paint characters; `LimbBrush.swift` is the leg brush the spider shares with the octopus |
| `Octopus.swift`, `Jellyfish.swift`, `Sponge.swift`, `Pufferfish.swift`, `Seahorse.swift`, `Frog.swift` | The legacy sea brush animals |
| `Strokes.swift` | Stroke paths (what's been drawn, for erasing) and geometry helpers |
| `PaintLayer.swift`, `PaintShaders.metal` | Wet paint simulated on the GPU (Metal compute): dabs, advection, leveling, mixing, drips, drying, normal map |
| `Studio.swift`, `Toybox.swift`, `Effects.swift` | Treehouse backdrop, linen and easel textures; glossy materials; petals and fireflies |
| `GrooveDSP.swift` | Live-synthesized music (a bouncy garden tune, plus a silly tune for the review page), sound effects and beat clock |
| `HUDView.swift`, `Platform.swift` | Canvas overlay and Mac/iOS differences (mouse, views, camera preview) |

Tests live in `PuffyPondTests/` (Swift Testing): run them on **My Mac** with **⌘U**.

## Tuning

- Distance check band: shoulder-width limits in `DistanceGate` (estimated for the iPad front camera at about 1 m).
- Paddle stroke length, time and cooldown: constants at the top of `PaddleDetector`.
- Review sheet feel: `SheetSolver.Parameters` (stiffness, damping), palm radius and push speed in `SheetGestures`.
- Hands don't reach the edges: `HandInput.reachMin/reachMax`. Fist detection and hysteresis: `HandInput` / `PoseFilter`.
- Tool feel: `PaintTool.dabs` and the `BrushStyle` each tool uses. Color pick speed: `rubPots` in `Playground`.
- Paint feel: constants at the top of `PaintLayer` (dry rate, leveling, drag damping, gravity, normal strength).
- Studio look: lights and camera in `Playground.buildWorld`; linen weave `Studio.weaveTileSize`.
- Tempo/melody: top of `GrooveDSP` (`sillyMelody` for the review tune).
