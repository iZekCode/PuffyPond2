# Timelapse replay: design

## Intent

A child finishes a painting and today sees only the end result: a still photo on a wobbly sheet. The owner wants the review page to first **replay how the child painted it**, stroke by stroke, as a short timelapse with music, and then let the child play with the finished painting (grab, push, splash) as they can today. The same replay-then-play experience should be available for every finished painting in the gallery.

The music matters as much as the picture: every stroke should be heard. The timelapse should feel like the painting is being *played* like an instrument, so a child watches and listens to their own work.

Why now: the garden theme just landed (butterfly, ladybug, mushroom, snail brush characters with their own sounds), the review page already has the elastic sheet and hand input, and the pieces to make a satisfying "watch what you made" moment exist. Nothing records the strokes yet, so the work starts with recording.

## Goals

- Record what the child paints during a canvas session (paint dabs and erases, with timing, brush animal and colour).
- On the review page, after "Save image", play the recording as a timelapse: an empty canvas that fills with paint stroke by stroke, with a musical note per stroke.
- When the timelapse ends, the paint sheet becomes interactive exactly as it is today (fist to grab, two fists to stretch, open hand to splash, touch/mouse drag), and a **Replay** button appears next to "Keep drawing" and "Save to gallery".
- Hanging a painting in the gallery stores its recording. Opening any such painting from the gallery shows the same page: timelapse first, then interactive, with **Replay** and **Back**.
- Replay always ends on exactly the saved painting.

## Non-goals

- No video file export, no sharing, no screen recording.
- No change to how painting feels or looks while drawing, to the paint simulation, brush styles, control scheme, hand tracking or the saved PNG.
- No timelapse for paintings saved before this feature: they have no recording. They open interactive straight away, without a Replay button.
- No interaction while the timelapse is playing (see "Flow").
- No recorded audio samples. Every sound stays synthesized in code, like the rest of the app.
- No editing of the recording (trim, speed, undo).

## Anti-goals (a failure even if it technically works)

- Recording that costs frames while the child is painting. Arm sweeps must stay smooth.
- A replay whose final frame differs visibly from the saved painting, or a visible pop when the sheet becomes interactive.
- Notes that sound wrong, harsh or like random noise, or that pile up into a wall of sound on a busy stroke.
- A timelapse that drags (a ten-minute session replayed at length) or flashes by unreadable.
- A recording that bloats storage so that the gallery grows noticeably heavy.
- The gallery's paddle-walk gestures and the new "open a painting" gesture fighting each other.

## Flow (decided with the owner)

Review page, after "Save image":

1. The timelapse starts by itself. The canvas is bare; paint appears stroke by stroke with music. Buttons are hidden or dimmed; a small **Skip** button jumps to the end.
2. When it ends (or on Skip), the sheet "wakes up": a small wobble and a short sound. Grab, push and splash become live.
3. Buttons appear: **Replay**, **Keep drawing**, **Save to gallery**.
4. **Replay** locks interaction again, clears the sheet, and runs step 1 again.

Interaction happens only *after* the timelapse, never during it. Reason: during replay the paint is being laid by the simulation; pushing the sheet at the same time would fight it. The owner asked which order is better; this is the answer we settled on.

Gallery: paintings in the 3D gallery stay static pictures (cheap). Picking one opens the same page as review in "viewing" mode: timelapse, then interactive, buttons **Replay** and **Back** (no Save, no Keep drawing). Review and gallery share one page, with two entry points. A painting without a recording skips the timelapse and has no Replay button.

## Music (my proposal, accepted by the owner in chat)

- Each stroke plays notes while it is laid. Notes come from a **pentatonic scale**, so every note fits any other.
- **Pitch follows height**: the higher on the canvas, the higher the note (the live `blip` already does this).
- **Timbre follows the brush animal** (butterfly, ladybug, snail, and the legacy brushes). The mushroom eraser makes a soft downward "poof"/slurp sweep.
- **Stroke speed sets how dense the notes are**; there is a cap on notes per beat per stroke so busy moments do not turn to noise.
- Notes are **quantized to the beat grid** of the background tune, so the result sounds like a song, not random blips. The review page already switches to the silly tune (`Tune.silly`); the timelapse plays over it.
- Stereo pan follows horizontal position, as the live sounds do.

Left to the builder: the exact scale and octave range, note density numbers, how quantization is hooked into `GrooveDSP`'s step clock, and how timbre is added to the effect system (a new effect with a parameter versus several effects).

## Timelapse length

Fit to roughly **15 to 20 seconds** whatever the real session length. Dead time (nothing painted) is cut out. A very short session is not slowed down below real time. The mapping from real time to replay time is a pure function and should be unit-tested.

## What gets recorded

Per canvas session, everything needed to lay the same paint again:

- Each paint dab as given to `PaintLayer.stamp` (segment, radius, colour, speed, seed, brush style, drag, stroke seed, NCA model) and each `PaintLayer.erase`, with a timestamp.
- The brush animal and tool behind each dab, so replay can choose a timbre.
- The log is cleared whenever the canvas is cleared (`Playground.clearCanvas`, new session via `begin`) and keeps growing across "Keep drawing", so a painting finished in two sittings replays both.

Hanging a painting stores, next to the existing PNG and JSON record: the compressed recording and the paint-only image (the paint on a clear background, already produced by `photographCanvas`). The paint-only image is needed so the gallery can show the elastic sheet; the bare canvas image is identical for every painting and may be stored once. `PaintingRecord` gains an optional flag for "has a recording" that old records decode without.

Careful: `Gallery.reload` treats every `.png` in the folder as a painting. Any extra images must not live in that folder as plain `.png` files, or they would appear as paintings. `Gallery.remove` must delete the extra files too.

Size is a constraint: sessions up to ten minutes should stay around a megabyte or less once compressed (compact encoding such as half-precision positions, plus zlib via the Compression framework). Cap the recorded session length if needed.

## How the replay is drawn (my call, with a fallback)

The faithful option is to feed the recorded dabs through an offscreen `PaintLayer` and show it, running several simulation steps per displayed frame to compress time. The paint simulation (flow, NCA texture, settling) depends on frame timing, so a compressed replay may not match the original exactly. **The first task of the plan is a spike** to check that this runs at 60 fps on the target devices and looks close to the original.

Fallback if the spike fails: reveal the final paint image along the recorded stroke paths in time order (a growing mask). It is cheap, always ends identical to the saved painting, but overpainted and erased areas look less true to how it was made.

Either way, when the replay ends the sheet's texture is the saved paint-only image, swapped in with a short crossfade so there is no pop.

## Constraints from the codebase

- `ReviewView` / `ReviewStage` (`PuffyPond/Pages/ReviewView.swift`, `PuffyPond/Review/ReviewStage.swift`) already own the sheet, hand cursors, dwell buttons and touch input. The timelapse is a new phase of that page, not a new page. Gallery viewing adds a route (for example `.replay(Painting)`) that builds the same page from stored files.
- `ReviewDraft` / `CanvasPhotos` carry whole, canvas and paint images; they gain the recording.
- Recording hooks live where dabs and erases are issued (`Playground.lay`, `Playground.erase`), not inside the Metal layer.
- Existing tests are XCTest in `PuffyPondTests/`. Recording encode/decode, the real-to-replay time mapping and the note quantizer should be pure and tested; the audio and rendering are checked by running the app.

## Calls made after the builder check (mine, not the owner's: check these)

- **Spike bar.** The faithful replay passes if it holds about 60 fps on the slowest device the owner actually uses (the app runs on iPad and Mac) and the owner judges by eye that it looks close to the original. No numeric image diff. Otherwise fall back to the growing mask. Because compressing time changes the simulation's look (it depends on dt and frame count), "close" means the same colours, strokes and order, not pixel equality.
- **Look during the timelapse.** The replay shows the lit, relief paint (studio lights added to the review scene while it plays). At the end it crossfades to the flat matte sheet used today. A slight change of look at that crossfade is accepted; a hard pop is not.
- **Second layer.** The replay uses its own `PaintLayer`, never the live `Playground.paintLayer`, because "Keep drawing" must find the easel untouched. If memory is tight it may run at a lower resolution than the live one.
- **Where a painting can be opened.** Both the 3D gallery and the 2D gallery (`Gallery2DView`) open the viewing page. The report page does not. The route carries where it came from, and Back returns there (3D at the same painting, or the 2D grid).
- **Size cap.** Soft target about 1 MB per painting, not a hard limit. A session longer than ten minutes, or one over budget, is thinned (dropping intermediate dabs evenly across the whole session). The replay still starts bare and still ends on the saved painting.
- **Note limit.** A global limit across all strokes at the same moment, besides the per-stroke cap. When over the limit, drop notes rather than stack dense chords.

## Left to the builder

- Encoding format and file layout, exact compression.
- How the gallery picks a painting (tap or click; with hands, probably hover-and-hold as on the review buttons), as long as it does not clash with the paddle-walk gestures.
- Button layout, the look of Skip and Replay, the wake-up wobble and sound.
- Whether the sheet reads the live replay texture or a copy while playing.
- Music tuning numbers and the instrument sounds.
