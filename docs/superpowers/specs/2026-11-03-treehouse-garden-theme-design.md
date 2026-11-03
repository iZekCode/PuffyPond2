# Treehouse garden theme: design

> **Amended 2026-11-03 (second cast).** The owner changed the cast to four tools: **butterfly** (liquid oil), **ladybug** (brush, six legs on `LimbBrush`), **mushroom** (eraser, spore puffs) and **snail** (blender). Thick oil was removed (archived in `docs/archive/2026-11-03-thick-oil-tool.md`), and the spider, caterpillar and bee were deleted. Where this document still names them, read it with the cast above; everything else (backdrops, effects, sound approach, legacy scheme kept) stands. New sound effects: `slurp` (blender) and `poof` (eraser) replace `buzz` and `crunch`.

## Intent

Puffy Pond is a painting game for children (and, through the report page, a movement-tracking tool): you make a fist, sweep an arm, and a little paint character lays paint on an easel. Today the five paint characters are sea animals and the world is a blurry studio room and a museum hall, with a pond-like name and sea-flavoured effects and copy.

The owner wants the whole app to feel like a **whimsical treehouse / garden** instead. Five new bug characters replace the sea animals, the backdrops become treehouse and garden scenes, the particle effects become garden things, and the music and sound effects follow. Sound effects should be **silly, trolling-fun cartoon noises**. Every character must be **cute, adorable and animated**: a child should want to keep moving their arm to watch it.

This is a re-skin plus five new characters. The painting itself must feel exactly the same.

## Goals

- Five new characters, one per paint tool, each cute, expressive and constantly moving.
- Treehouse studio backdrop for the canvas page, a treehouse-deck gallery for the 3D gallery.
- Garden effects (petals, leaves, pollen, fireflies) instead of ink bubbles and sea sparkle.
- A garden-flavoured background tune and a new set of silly sound effects.
- All user-facing copy (HUD hints, instructions, README) names the new characters.

## Non-goals

- No change to paint simulation, brush styles, the NCA paint texture, the review "wobbly sheet", templates, the report page, hand tracking or the distance gate.
- No change to the fist control scheme, tool order, or the six paint colours.
- No recorded audio. Every sound stays synthesized in code.
- No new screens or features.

## Anti-goals (a failure even if it technically works)

- A character that is hard to tell apart from the others at a glance in the tool column.
- A character that looks scary or creepy (the spider especially), or whose face is not clearly friendly.
- Sound effects that are unpleasant at volume or that fire so often they become noise.
- Any visible regression in how the paint behaves.

## The five characters

Each replaces one tool and keeps its paint behaviour. All use the existing `Critter` rig and `Mood` faces (eyes, brows, cheeks, blush, blinking, squash, lean). The owner picked the animals and the tool mapping. How each one moves is mine to propose, marked as such.

| Tool | Old | New | Paint behaviour (unchanged) |
|---|---|---|---|
| Brush | Octopus | **Garden spider** | Thin watercolor wash with the NCA texture. Legs lying on the canvas are the brush. |
| Thick oil | Snail | **Snail** (kept) | Wide palette-knife impasto sheet. |
| Liquid oil | Jellyfish | **Ladybug** | Translucent glaze that spreads and runs downhill. |
| Eraser | Starfish | **Hungry caterpillar** | Scrubs paint and the dotted template guide away. |
| Blender | Sponge | **Bee** | Lays no paint, smudges wet paint underneath. |

Movement ideas (my proposal, the owner has not specified them):

- **Spider**: round, fuzzy, chubby body with big friendly eyes. Eight long, slender Verlet legs that reuse `TentacleBundle` (`PuffyPond/Tentacles.swift`) the way `Octopus` does: dangling and jiggling while swimming, lying flat on the canvas as a star while painting, gathering into a trailing bundle when wiping fast. Legs are stiffer and longer than the tentacles. Idle wiggle and a happy little bounce.
- **Snail**: stays as it is, with optional cuteness tweaks (bigger eyes, eyestalk wiggle). Not mechanical.
- **Ladybug**: round red shell with dots. The wing covers open and close in time with the beat (taking over the jellyfish bell pulse), and each flap drops a runny blob of glaze. Tiny wobbling legs.
- **Caterpillar**: big round head with a chewing mouth and a segmented body that trails behind it as a chain, steered by the head. Its mouth opens and closes while erasing and crumbs fly off. This is one long limb in `TentacleBundle` terms, in its "trailing" mode.
- **Bee**: fat fuzzy body with a stinger-less friendly face, blurred buzzing wings, a wiggling bottom while blending. Sound: a soft buzz while it works.

Per-character visuals (palette, sizes, exact shapes) are left to the builder, constrained by: distinct silhouette and signature colour for each, and `CritterKind.signatureColor` still derived from `Paint.colors` where the design needs it.

## Backdrop and effects

- **Canvas page**: replace `Studio.backdrop()` (`PuffyPond/Studio.swift`), currently an out-of-focus warm wall, window light, wooden floor and plant, with a blurred treehouse interior: warm wood, dappled sunlight through leaves, string lights, foliage. The easel and its lighting stay; retune `scene.background.intensity` and the key/fill lights if the new image needs it.
- **3D gallery**: replace the museum hall (`Gallery.backdrop()`, partitions and wall material in `PuffyPond/Gallery.swift`) with a treehouse deck among branches. Paintings hang on wooden or bark-like partitions. The walkable layout, camera path and paddle gestures are unchanged.
- **Effects** (`PuffyPond/Effects.swift`): `inkBubbles()` becomes petals, leaves, pollen specks or fireflies tinted by the current colour; the colour-pickup `sparkles` and the pop shards keep their behaviour but get garden-flavoured imagery.
- **Review and 2D gallery pages** stay visually as they are unless a hard-coded sea or museum look shows up.

## Sound

All audio stays synthesized by `PuffyPond/GrooveDSP.swift` (no audio files, no licensing).

- **Background music**: the `groove` tune is replaced with a garden feel (plucked, ukulele-like and xylophone-like voices on the existing square/triangle/FM/noise voices, bouncy). The `silly` kazoo oom-pah tune used on the review page stays.
- **Sound effects**: keep the existing silly ones (`honk`, `quack`, whistle up and down, `boing`, `splat`, `sproing`, `wobble`). Rename or retire sea-specific ones (`squeak` was the starfish, `gurgle`/`blip`/`bloop` are bubble-like, `swap` was fish and starfish). Add new silly cartoon sounds: for example rubber squeak, "bonk", "splorp", rubber chicken, bee buzz, a crunch for the caterpillar. The tone is trolling, goofy and surprising, but short and not fatiguing. Exact list and when each fires is left to the builder; hooks are the existing `Sfx` events and the new character actions.

## Constraints

- Platforms: iPad (main, landscape) and Mac, SceneKit, Metal paint layer, no third-party dependencies.
- Performance: the canvas runs at camera frame rate with two characters and a tracked pair of hands. New characters must not cost noticeably more than the old ones (the octopus is the heaviest).
- The NCA paint texture is tied to the **brush style**, not to the octopus body: `BrushStyle.octopus` and `PuffyPond/NCA/octopus.bin` (six per-colour models) are used by whatever the brush character is. Reusing them means no retraining. Do not rename or remove the old identifiers (`Octopus`, `octopusSize`, `octopus.bin`, ...): the old characters still use them. The spider needs its own size setting or shares `octopusSize`; builder's call.
- `PaintTool.critterKind` currently has no critter for the eraser (the starfish is not a `CritterKind`); the caterpillar needs to become one. Today each hand's `Buddy` (`Characters.swift`) carries a separate `Starfish` rig: when the mode becomes erase, the hand's animal is hidden, the starfish is shown, and `Sfx.swap` plays (`Playground.swift`, `setMode`). Erasing then reads the starfish's position and `Starfish.eraseRadius`. The legacy scheme must keep this. Proposal for the fist scheme: the caterpillar is a normal `Critter` that the hand becomes when the eraser bubble is rubbed, like the other four tools, so no hide/show swap is needed there, and `erase(with:)` uses the caterpillar's position and its own erase radius. The `swap` sound still plays when a bubble is rubbed.

## Decisions I made (flag if you disagree)

1. **App name stays "Puffy Pond".** It is a pond name on a garden theme. Renaming touches the Xcode project, bundle strings and README; say the word and it goes in.
2. **The old sea-animal characters stay in the code and keep working** (owner's instruction): octopus, jellyfish, sponge, starfish, pufferfish, seahorse, frog, and the legacy control scheme that uses them (`CritterKind.legacyBrushes`). The five garden characters are **added next to them**, not swapped in by renaming or deleting. The fist scheme's tool column switches to the garden characters (`PaintTool.critterKind`). Whether a switch to bring the sea animals back is exposed in the UI is left open; for now they are only reachable through the legacy scheme. Backdrops, effects and music are shared by both schemes (my call), so the legacy scheme shows sea animals in a garden world.
3. **Spider reuses the existing NCA models** instead of retraining new ones.
4. **Gallery visitors become the five new bugs**, not the old animals.
5. **Silly sound** means cartoon synth noises, not memes or recordings.

## Left to the builder

- Exact shapes, palettes, face placement and animation constants for every character.
- Exact backdrop art (drawn procedurally like the current ones).
- The tune's melody and the full list of new sound effects and trigger points.
- File and type renames, as long as `PuffyPondTests` still pass and the app builds for iPad and Mac.
- Order of work. Suggested: backdrops and effects first (small, visible), then characters one at a time, then sound.

## Definition of done

- Running the app, a person sees five distinct, cute, animated garden characters in the tool column and as their hand characters, each painting exactly as the old one did.
- No sea animal, bubble or museum visible in the fist scheme.
- Copy in the HUD and README matches.
- New sounds play, and the BGM is garden-themed.
