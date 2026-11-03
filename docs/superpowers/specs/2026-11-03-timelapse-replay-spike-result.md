# Timelapse replay: faithful renderer spike result

**Decision: not adopted. The reveal-mask renderer (`MaskReplayer`) stays the timelapse renderer.**

## What was tried

A `PaintLayerReplayer` that laid the recorded dabs again through a `PaintLayer` of its own (never the easel's), under studio-like lights that only touched it (light category mask), stepping the simulation at the original 1/60 s frame time and taking as many steps per displayed frame as the replay's speed-up needed, then settling 180 frames after the last dab. It was wired in behind a launch argument and measured with a synthetic recording: one dab per 1/60 s along a smooth path, six colours, the NCA texture models in use.

## Measurements

Apple M5 Mac, debug build, run from the test host, full-resolution layer (2048 px across). Time spent inside `advance(to:)` per displayed frame, over the whole 18 s replay (1086 frames):

| Recorded session | Steps per displayed frame | Average | Worst |
|---|---|---|---|
| 30 seconds | about 1.7 | 19.9 ms | 2060 ms (first frame) |
| 5 minutes | about 17 | 192.6 ms | 2246 ms (first frame) |

A 60 fps frame has 16.7 ms. One simulation step costs about 11 ms on this machine, so the cost grows with how much the replay is sped up. Only a session shorter than about 25 seconds fits the budget, and the first frame hitches by about 2 s (pipeline and texture setup). An iPad is not likely to be faster than an M5. Memory was not measured: the replay layer needs a second set of full-resolution textures next to the easel's.

## Why the gate fails

The spec's gate is about 60 fps on the slowest device the owner uses **and** the owner's eye saying it looks close. The frame rate fails for the sessions that matter most (the long ones the speed-up exists for), so the owner's visual judgement was not needed. Making it faster means fewer or coarser simulation steps (a lower resolution layer, a step cap, or a larger step size), all of which change how the paint looks and settle, which is what the faithful renderer was supposed to avoid.

## Options if the faithful look is wanted later

- Render the replay ahead of time into a short sequence of frames when the painting is saved (costs time and storage at save).
- Replay at a fraction of the resolution and accept the look difference, with a crossfade at the end.
- Keep the reveal mask and lift its look: draw each revealed region with a short fade-in so strokes seem to be laid rather than switched on.

The prototype was about 100 lines and was discarded; the numbers above come from a throwaway benchmark test.

## Follow-up: adopted at a small resolution

The owner wanted the timelapse literally in order (a colour must not look blended before the blender reached it), which the reveal mask cannot show, so the faithful renderer was rebuilt with a small paint layer. Resolution now depends on how much the replay is sped up (`PaintLayerReplayer.resolution(forSpeedUp:)`): 768 texels across up to 2x, 512 up to 5x, 384 up to 14x, 256 beyond. Measured on the same M5 Mac (debug build), average time per displayed frame:

| Recorded session | 384 across | 512 across | 768 across |
|---|---|---|---|
| 30 seconds | 1.2 ms | 1.9 ms | 3.1 ms |
| 5 minutes | 9.9 ms | 14.8 ms | 28.5 ms |

Occasional single frames take 60 to 220 ms (GPU queue stalls). The thresholds leave margin for slower iPads, so they are cautious; the tables above are the only measurements. Lighting was fitted against a copy of the photo booth so the replayed paint matches the saved photo's brightness within about 1.5% (`PaintLayerReplayerTests`). The reveal-mask renderer stays as the fallback when the paint layer cannot run, and Skip no longer lays the remaining strokes: the saved painting fades in over the replay as it stands.
