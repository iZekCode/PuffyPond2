# Splash Canvas: how it works

Findings from a static reading of the shipped Splash Canvas web app (Google Arts & Culture, by David Li).
Written 2026-11-02 to guide the PuffyPond paint and canvas look.

Everything here is labelled by evidence type:

- **Observed**: read directly from the shipped files.
- **Inferred**: concluded from observed code, not seen running.
- **Unknown**: not established.

## 1. Scope, method and limits

**Target.** `https://artsandculture.google.com/experiment/splash-canvas/vQFCtQB7FDnYkA`. That page is a wrapper. Its
embedded data (`WebSandboxFrame`) points at the real app: `//gacembed.withgoogle.com/octopus-paint?axl=1`.

**Method.**

1. Fetched the wrapper page and located the embed URL.
2. Fetched the app HTML (it is gzip-encoded, so `curl --compressed` is required).
3. Downloaded `main.js`, `worker/worker.js`, `styles/main.css`, the wasm modules and the textures.
4. Read the code directly: extracted the GLSL strings, the config objects and the pipeline orchestration.

**What was not done.**

- REA's `analyze_javascript_application` on the full tree hit its per-source provider deadline every time it was tried:
  300 s (partial evidence `ev_e73c05ba2844c8a1fa2ada30c43cd24eeb26cecb592bb7f7fff451c409d6359a`) and again at 1,500 s
  (`ev_cc97f54f7dbb51c5069cccf18de21f542984e7d58f00e8fbc587b6b295667c33`). A third try on a copy of `main.js` with the 11,869
  long NCA weight literals blanked out (about 90 KB smaller) also timed out at 420 s
  (`ev_c217dd45d03a96d91355bd2ca0e24dda0bb09ee45842ef5846d21e21e392b2ea`). So raising the timeout does not help; the
  bundle has some construct that REA's semantic pass cannot finish. REA **did** analyse `worker.js` on its own
  (`ev_2e79e5766c65dd395ab06f268610fd40d0b1aa3476b2d8e09e8a0795188b1693`, parent
  `ev_5eaa28281c8cb644644db4c9e42f0ff8cdd6e0a18517087e9c99e45f026ef297`): 1 file, 7,918 AST nodes, 0 parse failures,
  9 retained request relations (consistent with the `fetch` to `/octopus-paint/api/image`). Everything about `main.js` comes
  from direct reading, not REA evidence.
- The static analysis never executed the app: no frame inspection and no network capture. A later pass did run it in the
  built-in browser pane (section 12, "Visual comparison"). That pane refuses `gacembed.withgoogle.com` when navigated to
  directly, but it loads the Arts & Culture wrapper page and its embedded iframe, so the wrapper URL is the way in.
  Claude in Chrome was **not connected** on three attempts, and was not needed.
- `brushmodule.wasm` and `synthmodule.wasm` were disassembled with WABT 1.0.42 (`wasm-validate`, `wasm-objdump`,
  `wasm2wat`), and the full set of exports was recovered by joining the single-letter export names to the names the
  Emscripten glue in `main.js` assigns (section 9.7). The function bodies were **not** read in detail: the code is 294 KB
  and 363 KB of stripped functions, so what each one computes is still inferred from names, signatures and call sites.
  REA's own `inspect_wasm_artifact` could not be used: the running REA server has no `REA_WABT_BIN_DIRECTORY` (it must be set
  in the server's launch environment and the server restarted).
- The dialogue backend (`/octopus-paint/api/image`) was not called. It is Google's private API and calling it would upload
  a painting to their server. Its behaviour is inferred from the worker code and the credits text.

**Files and sizes (observed).**

| File | Bytes | Notes |
|---|---|---|
| `main.js` | 943,574 | minified single bundle, all rendering and simulation |
| `worker/worker.js` | 25,298 | dialogue and speech worker |
| `styles/main.css` | 12,039 | UI chrome only |
| `brushmodule.wasm` | 134,573 | soft-body brushes, drips, fabric solver (inferred) |
| `synthmodule.wasm` | 128,386 | procedural audio (Foley, voices, reverb, pitch shifter) |
| `easel.bin` / `frame.bin` | 197,928 / 66,512 | scene meshes |
| `easel_base/nor/orm.jpg` | 123,127 / 41,477 / 114,368 | easel PBR set (1024×1024 base) |
| `frame_albedo/normal/material.jpg` | 17,025 / 18,740 / 17,025 | frame PBR set |
| `studio.jpg` | 77,485 | studio backdrop |

`audioconfig.json` and `mask.png` returned 404 at `/octopus-paint/47/`; they live somewhere else or under a different
name (unresolved). The SIMD wasm variant is requested as `brushmodulesimd.wasm` (the loader replaces `.wasm` with
`simd.wasm`), which was not probed.

Asset URLs follow `/${APP_NAME}/${VERSION}/${file}` with `APP_NAME = "octopus-paint"` and `VERSION = "47"`.

## 2. What the product is

The project's own credits text (observed, `main.js` localisation strings):

> Splash Canvas is your playground for creating abstract art with the help of AI. Grab an octopus or a squid and drag it
> across the canvas to paint... The painting simulation is a GPU hybrid fluid/CA/particle simulation that incorporates ML
> elements. Character dialogue is generated using Gemini and synthesised with Chirp 3. The painting sounds are
> synthesised using procedural audio models by Christian Heinrichs.

So the "brush" is a physical soft-body character you drag. Paint is not stamped as pixels. It is a field that
**grows and settles on its own** after the brush touches it.

Runtime flags (observed): `SAVE_PAINTING_SNAPSHOTS: false`, `OUTPUT_OSC: false`, `ENABLE_PAUSE: false`,
`SHOW_DEBUG_INFO: false`, `BROWSER_CAN_SHARE: true`, `BROWSER_CAN_DOWNLOAD: true`. The `?axl=1` query parameter switches
the host integration to the Arts & Culture one (share and navigate messages go to the parent frame).

## 3. Architecture overview

Observed ingredients, in the order a stroke goes through them:

1. **Soft-body brush** (character mesh + wasm physics) is dragged by the pointer.
2. **Splat pass**: the brush's contact triangles are rasterised into the paint board (a 2D texture set), writing colour,
   the NCA state, an alpha/liveness channel, a velocity channel and a mask channel.
3. **NCA update** (neural cellular automaton) runs every frame on the recently painted regions and makes the paint grow
   into its stroke texture.
4. **Fluid advection** moves the paint, alpha, mask and velocity along a velocity field. A Jacobi pressure solver
   keeps the velocity field mostly divergence-free, with the paint mask as a divergence source.
5. **Fabric solver** (wasm, desktop only) deforms the canvas under the brush. Its output is a displacement texture.
6. **Render pass** lights the board as a PBR surface (height from paint, Sobel normals, GGX specular), with a
   room backdrop, a lit easel and a frame.
7. **Audio**: a procedural synth driven by brush energy and contact; AI voice lines drive the characters' mouths.

The simulation board is **5×5 world units** (`m0 = f0 = 5`); `boardModelMatrix = translate(-0.5, -0.5, 0) · scale(5, 5, 1)`.
Board resolution comes from the preset (section 11).

## 4. The paint is a neural cellular automaton (NCA)

### 4.1 What was found

**Observed.** There are **9 NCA models** in `t2.ncas`. Each entry has `kernel`, `scale`, and for the last one a
`swizzle`:

| Index | Kernel scale | Notes |
|---|---|---|
| 0 | 4 | |
| 1 | 3 | |
| 2 | 2 | |
| 3 | 4 | |
| 4 | 2 | |
| 5 | 3 | |
| 6 | 6 | |
| 7 | 4 | |
| 8 | 4 | `swizzle: { targetChannel: 7 }` (swaps channel 7 with alpha channel 3 before and after the network) |

Every model checked has `channels: 8` and `hidden_size: 32`. The weights are embedded as GLSL source: `nca_w1` and
`nca_w2` with explicit `mat4` literals, and an `nca()` entry point:

```glsl
void nca(out vec4[2] outputChannels, inout vec4[8] inputChannels) {
    vec4 latents[8];
    nca_w1(latents, inputChannels);
    for (int i = 0; i < 8; ++i) latents[i] = max(latents[i], vec4(0.0));   // ReLU
    nca_w2(outputChannels, latents);
}
```

So each model is a **2-layer perceptron applied per pixel**:

- **Input: 32 values.** Each of 8 state channels is "perceived" with 4 fixed 3×3 kernels (identity, Sobel-x, Sobel-y,
  Laplacian). The kernel weights are `[[-1,0,1],[-2,0,2],[-1,0,1]]` for Sobel-x and its transpose for Sobel-y. The Laplacian
  is `[[1,2,1],[2,-12,2],[1,2,1]]`. The scale factors are `1`, `1/dx`, `1/dy` and `1/(dx·dy)`.
- **Hidden: 32 units** with ReLU.
- **Output: 8 values** (the state update).
- Update rule: `state = clamp(state + dt * delta, -1, 1)`, with state stored as `value * 0.5 + 0.5` in textures.

This is the "self-organising texture" family of NCAs. The different models are different learned textures (veins,
blobs, streaks, and so on).

### 4.2 How the update shader works (observed)

For each pixel, in order:

1. `scale = u_scale * model.scale * (1 + hash(fragCoord).x * 0.5 - 0.25)`: the kernel stride is **jittered ±25 % per
   pixel**. That breaks the grid-aligned look.
2. **Semi-Lagrangian advection of the read position by velocity** (RK2 style): sample the velocity at the pixel, step half,
   sample again, then read the state from `index - halfVelocity * u_velocityScale`. This is how the NCA "flows" with
   the fluid. Only the first NCA instance executed in a frame advects (`u_velocityScale = first ? 1 : 0`).
3. The 3×3 neighbourhood is sampled in all 8 channels at the jittered stride.
4. The 4 kernels are applied and passed to `nca()`.
5. `dt = u_dtScale`, multiplied by that instance's alpha channel (`alpha.g`, `.b`, `.a` for instances 0, 1, 2).
   Only pixels owned by the instance update; the rest copy through.
6. Liveness decays:
   `alpha[ch] = max(0, alpha[ch] - ncaLivenessStep * max(1, |velocity| * ncaLivenessVelocityScale) * u_livenessScale)`.
   `ncaLivenessStep = 0.0025`. Fast-moving paint dies sooner.

Texture precision comes from config: `ncaPrecision: "High"` (desktop) uses `highp`; `"Medium"` (mobile) uses `mediump`.

### 4.3 Instances and lifetimes (observed)

- At most `maxActiveNCAs` models run at once: **3 on desktop, 2 on mobile**. Each holds a slice of the alpha texture
  (`g`, `b`, `a`). The red channel `alpha.x` is shared pigment alpha.
- Starting a stroke with a different preset takes the next instance slot (round robin) and clears its channel.
- Each instance keeps updating for `maxNCAUpdateSteps` frames after its last addition (**200 desktop, 100 mobile**),
  then stops. A stroke is therefore "alive" for a few seconds, then it is final.
- The most recently added instance runs first (list sorted by `stepsSinceLastAddition`).
- The simulation only runs in a bounding window around recent painting (`simulationWindow`, plus a brute-force window),
  expanded by `maxFluidSimulationSteps` (**200 / 110**) frames.

### 4.4 What a stroke deposits (the splat) (observed)

Fragment shader `Su(planeCount)` (the splat program). For every contact fragment of the brush mesh:

- Discard if `boardPosition.z > u_threshold` (threshold is `0.1 * brushScale`): only the part of the body that is actually
  touching the canvas paints.
- Discard with a hash test: `hash42(floor(fragCoord)).x > u_splatProbability`. Splosh uses probability **1**, Splish **0.1**
  (a sparse scatter that the NCA then grows from).
- Plane 0 (the visible colour plane) gets `splatColor * 2 - 1`, packed as `* 0.5 + 0.5`. All the other state planes get
  **random noise** `((hash42(index + 1220*r) * 2 - 1) * 0.2) * 0.5 + 0.5`. That noise seeds the NCA.
- `alpha = (0.75, 0, 0, 0)` plus `1.0` in the instance's own channel.
- Velocity = brush velocity in board space × `u_velocityScale` (the velocity plane feeds the fluid and the NCA advection).
- `out_mask = u_mask` (preset `mask`: 1 for Splosh, 0 for Splish).

## 5. Brushes (the characters)

### 5.1 The five characters (observed config `t2.brushes`)

| Character | Kind | Mesh | Stiffness | Behaviour |
|---|---|---|---|---|
| **Splosh** (octopus) | NCA | `octopus2embedded.msgpack` | 100 | wild, expressionist; 4 presets (NCA 1, 4, 3, 6); splat colours green `[0,.6,0]`, grey `[.2,.2,.2]`, pink `[1,.2,.5]`, red `[1,.2,.2]`; splatProbability 1; dissipation 0.95; mask 1 |
| **Splish** (octopus, glasses accessory) | NCA | `octopusembedded.msgpack` | 30 | impressionist; 4 presets (NCA 0, 7, 2, 5); splat colours green, blue `[0,.3,.8]`, cyan `[0,1,1]`, `[.4,.8,.5]`; splatProbability 0.1; dissipation 0.9; mask 0; NCA 2 uses `dtScale` 0.7 |
| **Splat** (squid) | Drip | `squidembedded.msgpack` | 100 | flings paint as particle streams; `streamCount: 6`; 2 colour presets (a 6-colour palette and a grey set) |
| **Smudge** (turtle) | Smudge | `turtledown.msgpack` | 30 | picks up and redeposits paint, `eraseProbability 0` |
| **Scrape** (turtle) | Smudge | `turtleup.msgpack` | 30 | same tool with `flip: true` and `eraseProbability 0.05`, erases to empty canvas; not resizable |

Every brush also has: an `accessories` list, `hitSize` (grab collider `[.5,1,1]`, or `[.3,.6,1]` for turtles),
`dockedTransform` (resting spot on the board edge), `poseTransform` (idle pose), `noiseOffset` and `sfxModel` (voice index:
0, 1, 10, 20, 21). `resizable: true` except Scrape.

The brush palette is the top of the UI; each NCA brush has a row of "cards" (the presets), which is how the user picks the
colour and texture combination.

### 5.2 The soft body (observed API, inferred behaviour)

`brushmodule.wasm` exposes functions that `main.js` calls (names seen in the bundle): `brushStep`, `brushTranslate`,
`brushTransform`, `brushSetDamping`, `brushSetVolumeSolverIterations`, `brushAddAccessory`, `brushGetPNMesh`,
`brushGetPaintTriangleIndices` / `...IndexCount`, `brushComputePaintBounds`, `brushGetPaintBounds`,
`brushGetPaintVelocityBounds`, `brushGetMouthPositions` / `...Count`, `brushGetEye`, `brushGetEnergy`,
`brushGetContactFraction`, `brushGetCentroid`, `brushGetRestCentroid`, `brushGetClosestIndex`, `brushGetDripIndices` /
`...IndexCount`, `brushOverrideWorldLookPosition`.

Inferred: a position-based soft-body with a **volume-preservation solver** (`SetVolumeSolverIterations`), damping,
per-brush stiffness, and a contact test against the canvas plane. The wasm exposes which triangles touch (`PaintTriangle`)
and the bounds and velocity of the touching region. `getEnergy` and `getContactFraction` feed audio and the fabric solver.
Eyes, pupils, eyelids and mouth are drawn by a dedicated shader (section 9.5).

The brush is dragged by a spring-like follow (`dragPosition`), with `BrushPan` panning the voice by the on-screen x
position.

### 5.3 Splat of the brush mesh: spline ribbons for drips (observed)

The Drip tool does not splat the mesh. It emits **particle streams** (`dripSplatMesh = new w3(t, 2, 10, 2, false)`) and
draws each segment between two particles as a **cubic Hermite ribbon**:

- Vertex shader `Du` takes left/right position, tangent, colour, size, velocity; `tangentScale = 0.5`.
- `position = cubicSpline(...)`, `normal = perpendicular(tangent)`, `position += a_coordinates.y * normal * radius`.
- Fragment shader `ku`: `height = 1 - |fraction|²`; colour `v_color - brightnessBoost` with alpha `0.5 + height*0.1`; writes
  alpha `1.0` (pigment, no NCA liveness), velocity `v_velocity * 0.2` and mask `height * 0.2`.

### 5.4 Smudge and Scrape: pickup / deposit (observed)

Three passes with a small **pickup texture** (`pickupTextureWidth/Height: 128`):

1. **Pickup pass (`Cu` / `Bu`)**: draws the brush's UV-unwrapped body into the pickup texture. Each texel samples the canvas at
   its board position.
   - `loadedness = previousAlpha.w`; when it is 0 (an unloaded texel), the texel takes the canvas colour and alpha.
   - Loadedness decays per frame by `mix(0.01, 0.1, hash) * speed * 0.4`.
   - If `hash.x > loadedness`: reload from the canvas (new sample). Otherwise keep what the brush carries.
   - If `hash.y < eraseProbability`: wipe (stored alpha 0, colour 0.3 grey). This is Scrape's erase.
2. **Imprint**: `out_imprint = mix(canvasSample, previousSample, step(0.001, loadedness))`.
3. **Deposit (`wu` / `Lu`)**: draws the brush body onto the canvas, writing the carried colour back where the pickup alpha is valid
   (`pickupAlpha.g >= 0.5`), with the same contact threshold.

The result is real smearing: colour is carried, thinned, and left behind, and the random reload gives the broken dry-brush
edge. Velocity in the deposit pass is `boardVelocity * 1024 / 60`.

## 6. Fluid simulation (observed)

Classic stable-fluids on a half-float texture (`textureType: "HalfFloat"`), GPU:

- **Advection (RK2)**, two variants: scalar (`dissipation` multiplier) and with `u_decay` subtraction.
  Velocity is advected by itself.
- **Divergence** of the velocity from central differences, then reduced by a **mask term**:
  `divergence -= length(sobelGradient(mask.a)) * u_maskGradScale`. Edges of the painted mask act as a pressure source, so
  fresh paint spreads outward at its boundary.
- **Pressure** by **Jacobi iterations**: `p = (L + R + T + B - div) / 4`, with `poissonIterations` = **10 desktop, 2 mobile**.
- **Subtract gradient**: `v -= gradient(p)`, clamped to `±u_maxVelocity`; max velocity is effectively unlimited on desktop
  (`999999999`) and `1000` on mobile.
- Mask is advected with a decay of `2/255` per step.
- The velocity of the fluid is dissipated each frame (`this.dissipation`, per preset 0.9 to 0.95).

The fluid moves the colour planes and alpha (when no NCA ran that frame), the mask and the velocity itself. When an NCA
instance ran, the NCA shader already advected its own read, so the planes are not advected twice.

**Inferred**: the fluid is what makes paint swirl when the brush drags it. The NCA is what makes it develop texture.

## 7. Fabric (canvas give) solver (observed + inferred)

Only when `enableFabricSolver` (desktop preset). A wasm `_createFabricSolver(width - 2, height - 2, 50)` on a **16×16 grid**
(14×14 simulated, 50 iterations). Each step receives the brush centroid on the board (clamped 0..1) plus two values:

- Painting with contact fraction > 0.1: strength `scale * 1`, radius `scale * 0.2`; otherwise `0` and `0.2`.
- The solver result (RGBA8, 4 bytes per cell) is uploaded to `displacementTexture`.
- If the brush stops pushing for `bu` steps, `_fabricSolverReset` clears it.

In the final pixel shader the displacement is used as a **parallax offset** (see 8.3). So the canvas visibly depresses and
shifts under the brush.

## 8. Rendering: lighting and the canvas look

### 8.1 Light setup (observed, function `hu`)

```text
lights: [
  { kind: Point, distance: 20, orbitPoint: [0,0,0], rotation xyz [-60, -5, 0], color: 0.8 (grey),
    shadows: { map 512² (256² on mobile), normalBias 0, near 0.1, far 100, fov 25, pcfKernel [1,1] } },
  { kind: Point, distance: 20, orbitPoint: [0,0,0], rotation xyz [30, 50, 0], color: 0.5,
    shadows: { map 512² (256²), near 0.1, far 100, fov 35, pcfKernel [1,1] } }
]
ambient: { kind: Constant, color: 0.2 }
```

Both lights are far away (distance 20), so the light across the board is **almost uniform**: contrast comes from the normal
map, not from a falloff.

**There is no tone mapping, no bloom, no vignette, no exposure setting and no SSAO.** A search of the bundle for those terms
finds nothing. The output is plain linear lighting followed by `pow(c, 1/2.2)`.

### 8.2 BRDF (observed, `shadeSurfaceWithLightWithoutShadow`)

Per light:

```glsl
diffuse  = saturate(dot(L, N));
specular = smoothstep(-0.2, 0.0, dot(L, N)) * D_GGX(roughness, nDotH) * G(roughness, nDotL, nDotV) * F_Schlick(F0, lDotH);
color    = (diffuse * albedo + vec3(specular)) * lightColor;
```

- `D_GGX(alpha, nDotH) = a² / (π * ((nDotH² (a² - 1) + 1)²))` using `alpha = roughness` (not roughness²).
- `G` is a Smith-style term built from `nDotL` and `nDotV`.
- `F_Schlick(F0, lDotH) = (1 - F0) * (1 - lDotH)^5 + F0`.
- Shadows multiply per-light (PCF); total adds `albedo * ao * ambientColor`.
- Output `gammaCorrect = pow(c, 1/2.2)`; texture albedo is decoded with `pow(c, 2.2)`.

### 8.3 The paint surface (observed, `getPaintingColor` and the board fragment shader)

State read from textures: `paint.rgb` (colour plane, packed `*0.5+0.5`), `paint.a` (the NCA height channel), `alpha.r` (pigment
alpha), and `alpha.gba` (NCA liveness).

```glsl
// colour
vec3 color        = texture(paint, uv).rgb * 2.0 - 1.0;
float pigmentAlpha = min(1.0, alpha.x / 0.75);
vec3 albedo       = rybToRgb( mix(color * 0.7 + 0.5, vec3(0.0), 1.0 - pigmentAlpha) );
albedo            = gammaUncorrect(max(albedo, 0.0));

// height
float canvasHeight = hash12(floor(uv * resolution)) * 0.05;               // per-texel canvas tooth
float h = canvasHeight * (1.0 - alpha.r * 0.3) + paint.a + max(0.0, alpha.r - 0.75);

// normal: Sobel of h over the 3x3 neighbourhood
normal = normalize(vec3(gradient.x, gradient.y, 0.6 * u_paintingNormalScale));

// material
float liveness  = max(max(alpha.g, alpha.b), alpha.a);
float pigmentRough = mix(0.3, 0.02, liveness);                             // wet paint is nearly a mirror
float roughness = mix(1.0, pigmentRough, pow(pigmentAlpha, 0.5));         // bare canvas is fully matte
f0 = 0.2;
```

Details:

- **RYB colour model.** `rybToRgb` is an 8-corner trilinear interpolation of the red-yellow-blue cube: white `(1,1,1)`,
  red `(1,0,0)`, blue `(0.163,0.373,0.6)`, yellow `(1,1,0)`, orange `(1,0.5,0)`, green `(0,0.66,0.2)`, purple `(0.5,0,0.5)` and
  black-ish `(0.2,0.094,0)`. Splat colours are in this space, which is why mixing yellow and blue gives green.
- **Normal scale** (`u_paintingNormalScale`) comes from the background config (`normalScale`, 2 for the card
  backgrounds, otherwise the default).
- **Parallax.** With the fabric displacement texture enabled: `displacement = tex.r * -0.01`, and the sample UV is shifted by
  `(localView.xy / localView.z) * displacement` in the tangent frame (cotangent frame built from screen-space derivatives).
- **Wet versus dry** is the NCA's own liveness (not a separate "wetness" field): as an NCA instance's liveness decays to
  0, the paint's roughness rises from 0.02 to 0.3.
- The 2D flat render (`renderPainting2DProgram`, used for the saved image and the gallery flat view) uses the same
  function with normal scale 1.

### 8.4 Shadow-catcher (observed)

A small shader writes `(1 - shadow) * 0.1 * edgeFactor` with alpha 0 (a soft contact shadow under the board edges, inset
`0.1` of the uv).

### 8.5 Scene (observed)

- Board: 5×5 units. Easel and frame are static meshes with textured PBR (albedo, normal, ORM maps).
- Background: a photo plane with `fov`, `distance` and `yOffset` per room.
- Rooms (`backgrounds.configs`): `studio` ("in the Splatelier"), `gallery` (museum), `contemporarygallery`, `garden`,
  `landfill`, `fancyhouse`, `dentists`, `yoga`, `retreat`, plus card backgrounds `birthday`, `anniversary` (and `easter` on
  the right date) which use `bg_white.jpg` with a card overlay PNG and `normalScale: 2`. Preloaded: `studio`, `gallery`.
- The user first paints in the studio, then goes to a "gallery" mode where the painting is placed in a room and judged
  ("choose where you think it belongs").

## 9. Everything else

### 9.1 Audio: procedural synth (observed + inferred)

- `synthmodule.wasm` (emscripten C++). Strings show a `PitchShifter`, a `DCReverbMod`, and a `Foley` model class.
- The audio engine (`v4`) creates `5` voices (one per character: `Gr = 5`), a synth with `voiceGain`, reverb config, and a
  canvas convolution reverb pair: `canvasIRLPath: "large_L_4608_12up.wav"`, `canvasIRRPath: "large_R_4608_12up.wav"`,
  `canvasIRLength: 3900`, `canvasWetGain 0.12`, `canvasDryGain 1`, `airGain 0.8`, `voiceGain 1`.
- Audio runs in an **AudioWorklet** (with a `ScriptProcessorNode` fallback; flag `forceScriptProcessorNode: false`).
- Painting sound: per-frame parameters `model` (the brush's `sfxModel` index), `energy` (`brush.getEnergy() * scale²`),
  `contactFraction`, `centroid` (normalised board x, y). A Foley model turns those into sound. A debug sender over
  WebSocket `ws://localhost:12000` exists but only when `OUTPUT_OSC` is on (it is off).
- Voice panning follows the brush's on-screen position: `atan2` of the brush offset from the camera.

### 9.2 Dialogue (observed, inferred)

- A dedicated **Web Worker** (`worker.js`) owns the dialogue loop. It posts to `/octopus-paint/api/image` as `FormData`:
  `painting` = the current painting image, `context` = JSON of
  `{ history, hash, state: { mode: "Studio" | "Gallery" }, paintingVersion, timestamp, sampleRateHz }`.
- `history` is a list of `Text` (character, text) and `PaintingChange` (version) items, capped at 100 entries.
  Errors seen: `InvalidHash` (history is truncated and retried), `InvalidInput` (the version is rejected).
- The server returns the line (text and synthesised speech). The worker emits `Subtitle` and `EndSubtitle` messages that the main
  thread turns into speech bubbles and `ResponseSuccess`.
- Timing: lockouts of about 6 s between requests (`_e = 6`), retry with back-off, and hint messages (for example "resize")
  before the first request.
- **Lip sync is by signal**: the audio processor posts `{ voiceId, amplitude, f0 }` per frame, and the brush mouth
  openness is `min(2, sqrt(amplitude) * 1000)`.
- Per the credits text: text from **Gemini**, speech from **Chirp 3**. Both are presumably behind that endpoint; the
  bundle does not call them directly. The backend request and response schema was not captured.

### 9.3 Scale and interaction (observed)

- Brushes are resizable (`scale`); a size change scales the brush, its splat threshold `0.1 * scale`, the NCA kernel scale
  `scale² * globalScale`, and the fabric strength.
- Touch and mouse (`touchstart` handlers exist; no `pointerdown`, no motion or camera input).
- Frame pacing: a `frameThrottler` skips frames to protect the frame rate; dt clamps to `[1, 100] ms`.

### 9.4 Export and sharing (observed)

- A 1920×1080 canvas capture renders the scene with a corner badge (`goo.gle/splash-canvas`, drawn at 315 px wide).
- The host can share (title + image) or download; the app reports `BROWSER_CAN_SHARE` and `BROWSER_CAN_DOWNLOAD`.
- Localisation is a per-language string table (`vt` is the table; `en-US` shown), with right-to-left support.

### 9.5 Eye shader (observed)

A separate fragment shader draws each character's eyes: a pupil cylinder along the look direction, eyelids by angle around
a rest centre (top and bottom angles animate), a back-lid mask, an indent of the normal around the lids, and a specular
highlight. Roughness is `0.05`, F0 `0.05`.

### 9.6 UI (observed)

Plain HTML/CSS (Material Icons, Roboto, Google Sans). Circle buttons are 40 px, the info overlay is a black
80 % veil, and the layout switches at 499.5 px width or height.

### 9.7 The two WebAssembly modules (observed from WABT, inferred behaviour)

Both modules validate (`wasm-validate`), are Emscripten builds, import only 3 host functions from module `a`, and start with
a 337-page memory (about 21 MB), growable to 32,768 pages (2 GB). Exports are minified to single letters, but the Emscripten
glue in `main.js` assigns each to a readable `_name`, so the names below are exact (observed), joined by export letter.

| | `brushmodule.wasm` | `synthmodule.wasm` |
|---|---|---|
| Functions | 356 | 4,427 |
| Code section | 294 KB | 363 KB |
| Data segments | 29 (8.4 KB) | 9 (18.8 KB) |
| Exports | 59 (53 named by the glue) | 40 (36 named by the glue) |
| Language and libs | C++; **nlohmann::json 3.12** with MessagePack, BSON, UBJSON and BJData readers | C++; a Pure Data "Heavy" style context for the Foley sounds |

**`brushmodule.wasm` exports with signatures** (`i32` is a pointer or int, `f32` a float):

- Creation: `createBrush(meshPtr, meshLen, meshFmt, skelPtr, skelLen, skelFmt, subdivisions, unskinnedStiffness) -> brush`,
  `createBrushVisualMesh`, `createDripper(streamCount)`, `createFabricSolver(w, h, f32 iterations) -> solver`.
  The brush meshes are the `.msgpack` files; they are parsed **inside** the wasm (hence the JSON/MessagePack library).
- Simulation: `brushStep(brush, targetPos xyz, targetRot quaternion xyzw, scale, mouthScale xyz, 3 more floats)`: 14 floats.
  The call site passes the drag target position, the drag rotation, the scale, a 3-vector of mouth scale, and three
  offsets (the last two are -0.2 when "Posing" and -0.1 when "Watching"). So the soft body is **pulled toward a
  dragged target transform** every step, after `brushSetDamping(brush, f32)` and `brushSetVolumeSolverIterations(brush, 2)`.
  The brush stops stepping once it has been nearly static for several frames.
- Readback pointers (all `brush -> ptr`): `meshGetPositions`, `meshGetNormals`, `meshGetVelocities`,
  `meshGetRestPositions`, `meshGetUVs`, `meshGetTriangleIndices`, `meshGetPointCount`, `meshGetTriangleIndexCount`,
  `brushGetPNMesh`, plus `brushGetCentroid`, `brushGetRestCentroid`, `brushGetEnergy -> f32`,
  `brushGetContactFraction(brush, f32) -> f32`, `brushGetClosestIndex(brush, x, y, z)`, `brushComputePaintBounds`,
  `brushGetPaintBounds`, `brushGetPaintVelocityBounds`, `brushGetPaintTriangleIndices` / `...IndexCount`,
  `brushGetDripIndices` / `...IndexCount`, `brushGetMouthPositions` / `...Count`, `brushGetEye(brush, i)` and the eye getters
  (`eyeGetAttachPosition`, `eyeGetRestCenter`, `eyeGetScale`), `brushAddAccessory(... 9 args)`, `brushTranslate`, `brushTransform`.
  The JS side copies positions, normals and velocities into WebGL buffers every active frame (`DYNAMIC_DRAW`).
- Drips: `dripperStep(dripper, dt, positionsPtr, colorsPtr, sizeScalesPtr, sizeOffsetsPtr)`, and a stream API
  (`streamGetParticlePositions`, `...Colors`, `...Sizes`, `...Tangents`, `...Velocities`, `...ActiveParticleCount`,
  `...MaxParticleCount`, `...NextSpawnIndex`). Each stream is a particle chain the JS renders as the spline ribbon of section 5.3.
  Particle size on the JS side is `0.015 * (1 + noise) * scale` with a `-0.01` size offset.
- Fabric: `fabricSolverStep(solver, x, y, strength, radius)`, `fabricSolverReset`, `fabricSolverGetTextureData`.
- `generateNoise(ptr, 32, 4, 3, 1/32, 100, 0.4)`: fills a **32x32x32 RGBA8 3D noise texture** (131,072 bytes), uploaded as
  `TEXTURE_3D` with repeat wrapping. Its use (probably brush skin or colour noise) was not traced.

**`synthmodule.wasm` is a source-filter voice synthesiser plus a sound-effects engine** (inferred from the export names):

- Voices: `createSynth(...)`, `synthGetVoice`, `voiceAddExcitationFrame(voice, f32 pitch?, frame)`, `voiceAddSpectralFrame`,
  `voiceSetGain`, `voiceSetSpectrumOffset`, `synthStep`, `synthGetBuffer`, `synthSetOnlyNoise`,
  `synthHasEnoughExcitationFrames`, `synthHasEnoughSpectralFrames`, `createExcitationFrame` with
  `excitationFrameGetPeriodic` / `...GetAperiodic`, and `createSpectralFrame` with `spectralFrameGetSpectrogram`.
  "Periodic and aperiodic excitation plus a spectrogram per frame" is the structure of a WORLD-style speech vocoder.
  **Inference:** the character voices are not played back as audio files. The dialogue pipeline delivers vocoder frames
  (pitch, excitation, spectrogram) that this wasm renders, which lets each character get its own pitch and timbre, and it
  gives the worker a signal to read lip-sync from. This agrees with the worker sending a `sampleRateHz` in its request and with the
  audio processor posting `{voiceId, amplitude, f0}` every frame. It was not observed on the wire.
- Effects: `createFoleyContext`, `createPitchShifterContext`, `createDCReverbContext`, `createReverbContext`,
  `createIRFilter`, `createParallelIRFilter` with `irFilterGenerate` / `...Zero` / `...GetOutput` / `...IsZeroed` (partitioned
  convolution against the `large_L/R_4608_12up.wav` impulse responses), and `heavyContextProcess` /
  `heavySendMessage(ctx, nameHash, f32, f32)`.
- Foley parameter names found in the data (observed): `in_isPainting`, `in_gain_strokes`, `in_gain_scrapes`, `in_gain_whoosh`,
  `in_gain_bublets`, `in_gain_fartlets`, plus `choristerReverb`, `dry-gain`, `wet-gain`. So the painting sound is built from
  five layers (strokes, scrapes, whooshes, bubblets, fartlets) that are gated and gained by the brush's energy and contact.
- `synthBenchmarkSpectrumGeneration` is a debug export; `createSynth` takes two `f64` values (very likely sample rate and a
  block size or similar) and 5 pointers or ints.

## 10. Why it looks the way it does

1. **Texture comes from an automaton, not a stamp.** Learned NCAs grow a coherent stroke texture, then settle. That is
   why every character has a different recognisable "hand".
2. **Stochastic everything.** Splat probability, jittered kernel stride, random initial state, random reload when smudging:
   each is a hash per pixel. No two strokes look the same, and edges are never clean.
3. **Real motion.** The fluid solver and the velocity field make paint run, swirl and spread, and the mask-gradient term makes
   paint expand at its edge.
4. **Height-driven lighting.** The canvas is lit as a bump-mapped surface: `0.05` hash grain under the paint, paint height on
   top, Sobel normals at `z = 0.6`.
5. **Wet means glossy.** Roughness falls to `0.02` while the NCA is alive, then rises to `0.3` when it settles. Bare canvas
   is fully rough.
6. **Flat, even, uncorrected light.** Two far lights at 0.8 and 0.5 plus 0.2 ambient, no tone map, no bloom.

## 11. Performance presets (observed)

| | Desktop | Mobile (Android UA) |
|---|---|---|
| Board size | 1024 | 512 |
| NCA precision | High | Medium |
| `globalScale` | 1 | 0.5 |
| `maxActiveNCAs` | 3 | 2 |
| `maxNCAUpdateSteps` | 200 | 100 |
| `maxFluidSimulationSteps` | 200 | 110 |
| `ncaLivenessStep` | 0.0025 | 0.0025 |
| `ncaLivenessVelocityScale` | 1 | 2 |
| `poissonIterations` | 10 | 2 |
| `maxVelocity` | effectively unlimited | 1000 |
| Fabric solver | on | off |
| Shadow map | 512² | 256² |

Textures are `RGBA32F` when `ncaPrecision` is High, otherwise `RGBA8`; the velocity texture is `RGBA16F`.
Requires WebGL2 with float render targets (`EXT_color_buffer_float` / half-float).

## 12. PuffyPond: how it compares and what was ported

PuffyPond already had a Metal wet-paint simulation (`PuffyPond/PaintShaders.metal`, `PaintLayer.swift`): a paint texture
(rgb pigment, a = thickness) and a flow texture (velocity, wetness, bristle relief), a semi-Lagrangian advection step,
leveling, bristle grooves, stamps for each brush animal, and a normal-map shade pass.

| Topic | Splash Canvas | PuffyPond |
|---|---|---|
| Stroke texture | learned NCA | procedural bristle grooves, ragged edges, rim lift |
| Motion | full pressure-projected fluid | advection of paint by its own flow, leveling |
| Wetness | NCA liveness | `flow.z` wetness that decays |
| Smudge | per-texel pickup/deposit with random reload | blender (4-tap mix) |
| Canvas | hash grain + paint height, parallax, fabric solver | linen weave texture under thin paint |
| Lights | two far point lights + ambient, no post | spot + ambient + environment map, HDR, exposure, bloom, vignette, SSAO |
| Colour | RYB | sRGB |

### Ported (commit `c6a9d54`, merged as `30ca07e`)

- **Sobel normals** in `paintShade` (scaled to match the old central difference so `normalStrength` still means the same
  thing).
- **Per-texel canvas grain**: `grain = canvas.z * (hash21(c)*0.5+0.5) * covered * (1 - 0.3*saturate(a/0.55))`, with
  `grainHeight = 0.02` in `PaintLayer.swift` (the `canvas.z` slot).
- **Roughness**: `mix(1.0, mix(0.3, 0.02, wet), sqrt(coverage))` instead of a flat `mix(0.55, 0.12, wet)`.
- **Lighting in `Playground.swift`**: key spot `1050 → 820`, ambient `260 → 280`, environment `1.1 → 0.9`. Measured on the iPad
  simulator, the canvas went from top 252 (clipped) / bottom 215 to top 237 / bottom 196 (RGB red channel). This was tuned to
  stop the canvas blowing out, using the Splash light budget as a guide. It was not compared against Splash visually.

### Deliberately not ported

- **RYB colour mixing.** It would change every brush and template colour in the app.
- **`max(0, alpha - 0.75)` height bonus.** PuffyPond's thickness model uses different caps (about 0.55 normal, about 0.95
  impasto).
- **F0 = 0.2.** SceneKit's PBR material does not expose F0.
- **NCA, fluid pressure projection, fabric solver, soft-body brushes, Gemini dialogue.** Not attempted.

### Known risks of the port

- Wet paint at roughness 0.02, plus the existing `clearCoat = 0.55` on the paint material, may look mirror-like. Lower the clear coat first if so. (Checked on one stroke in the simulator: it did not look mirror-like. See "Visual comparison".)
- `grainHeight` is estimated from the ratio of Splash's grain to its paint height, not measured.
- The lights are also used by the photo booth for "Save image". `PaintMatte` calibrates the backdrop level itself, so saved
  images should follow, but this was not tested.
- Only one stroke was drawn in the simulator after the change (see "Visual comparison"). Paint colour against the darker canvas, other brushes and the photo-booth save have not been looked at.

### Visual comparison (observed, 2026-11-02)

First side-by-side look, after the port. Splash Canvas was run in the built-in browser pane through the wrapper URL
(section 1) and one stroke was painted with the default octopus. PuffyPond was built from `main` (Debug, scratchpad
DerivedData) and run on the iPad Pro 13-inch (M5) simulator, Freeform mode, camera step skipped, with one orange stroke
drawn by a scripted touch path. This is a judgement from screenshots, not measured pixel values.

| | Splash Canvas | PuffyPond |
|---|---|---|
| Bare canvas | near-white, even, fine grain | grey-beige linen, clearly darker and warmer, coarser and more visible weave |
| Shadows | soft cast shadows from the characters | no comparable cast shadows seen |
| Wet paint | pale gel-like blotch, sharp ridges, strong glossy highlights | bristle grooves, rough rim, moderate highlights; reads as thick paint, not mirror-like |
| Fine detail | smooth | some fine speckle on the stroke, probably the per-texel grain |

Findings:

- The remaining canvas gap is mostly **base colour and weave scale**, not light level. The lighting change above
  (key spot 820, ambient 280) cannot make the canvas read white. If the Splash look is the goal, the next change is the
  canvas albedo and weave contrast, not the lights.
- The clear-coat risk did not show on this stroke. Leave `clearCoat = 0.55` unless other colours or brushes show it.
- The speckle should be checked at a closer zoom before `grainHeight = 0.02` is treated as final.

Follow-up, same day (branch `feat/splash-white-canvas`): the canvas and light were changed to close that gap.

- `Studio.swift`: canvas albedo `(0.84, 0.83, 0.80)` x ~0.9 became `(0.95, 0.95, 0.93)` x ~0.96, with the weave's
  share of the tone cut from 0.07 to 0.015; weave normal strength 2.4 became 0.8; `weaveTileSize` 0.4 became 0.2 (a
  finer weave; the paint shader reads the same constant). A first pass (normal 1.4, tile 0.25) still showed the weave
  a little more than Splash's fine grain, so it was cut again. The weave is now about one pixel per thread, so it reads
  as grain rather than a pattern.
- `Playground.swift`: the key spot is now neutral white, with a wide cone (inner 70, outer 110) and no distance falloff,
  so it lights the canvas almost evenly like Splash's far lights; the fill is neutral instead of cool. A first pass at
  key intensity 540 was still too bright and leaned from the left, so the key now sits at the top centre
  (`keyPosition` `(0, 7, 6)` aiming at the origin), with key 300 (tuned by hand; 820 washed the canvas to flat white
  and lost the weave), fill 220, environment 0.7 and exposure offset -0.5. These are named constants
  (`keyIntensity`, `fillIntensity`, `environmentIntensity`, `exposureOffset`, `keyPosition`, `keyTarget`,
  `keyInnerAngle`, `keyOuterAngle`) at the top of the world-building section, so they can be tuned in one place.
- Result on the simulator (one stroke, judged by eye): the canvas reads off-white with a soft, slight gradient and a
  fine weave, close to the Splash screenshot, and the orange paint still shows its ridges. The raking warm light that
  made ridges pop is gone; the normal map carries them now.
- Still untested: thin paint over the new weave, other colours and brushes, the photo-booth "Save image" output, and
  numeric brightness. The key intensity of 540 was found by one trial, not tuned.

Not covered: other colours and brushes, light paint on the canvas, the photo-booth "Save image" output, and any
numeric comparison of canvas brightness.

Testing notes: simulator screenshots lag the last action by one capture, so take a second screenshot before judging a
tap. The app is landscape-only on a portrait iPad frame; tap coordinates were the screenshot coordinates scaled by
0.688 (1032 pt wide device over 1500 px). The Splash experiment ignored the swatch click and only one stroke painted,
so Splash colour behaviour was not compared.

## 13. If PuffyPond wants the actual Splash look

In rough order of payoff against cost:

1. **Done**: lighting and canvas shading (above).
2. **Per-texel pickup and deposit** (section 5.4) for the Smudge and blend tools: `loadedness`, stochastic reload from the canvas,
   and a 128² carried-colour texture. Maps onto the existing blender in `paintStep`.
3. **Mask-gradient pressure** (section 6): add a divergence term from the paint-thickness edge to spread fresh paint at its rim.
4. **NCA brushes** (section 4): the real "grows into a texture" behaviour. This needs trained models (do not reuse the
   embedded weights; see section 14). Architecture to train: 8 channels, 4 perception kernels (identity, Sobel-x, Sobel-y,
   Laplacian), hidden 32 with ReLU, output 8, stochastic per-pixel update, kernel stride jitter, training on a target texture.
   Run it in a Metal compute kernel next to `paintStep`.
5. **Fabric parallax** (section 7) for canvas give under the brush.

## 14. Licensing and reuse

The weights, meshes (`*.msgpack`, `*.bin`), textures, audio impulse responses and characters are Google Arts & Culture and
David Li's work. This document describes **techniques** and shader math. Do not copy the weights, assets, characters or
dialogue. Train your own NCA models and make your own assets.

## 15. Open questions

- The visual match of the new PuffyPond lighting against Splash Canvas: compared once on one stroke each (section 12,
  "Visual comparison"). Colour, other brushes, the photo-booth save and brightness numbers are still open.
- The exact camera field of view and the room `fov` constants (`u5`, `u1`), and the camera position per room.
- Brush soft-body internals (wasm): the API is now known (section 9.7), but not the constraint types, what the three extra
  `brushStep` floats do, or how `unskinnedStiffness` and `volumeSensitivity` map to the solver. The function bodies are not read.
- Why REA cannot finish `main.js` (it times out at 300 s, 420 s on a weight-stripped copy, and 1,500 s). Likely a pathological
  construct in the minified bundle; not identified.
- Whether the voice pipeline really delivers vocoder frames (section 9.7). Needs the response schema of `/api/image`.
- What the 32x32x32 noise texture is used for.
- The dialogue backend: request cost, prompt, model choice and caching. Whether speech comes back as audio or text.
- The exact `audioconfig.json` location and the full set of Foley model parameters.
- `mask.png` usage (a 404 at the guessed path).
- Whether a `simd` wasm variant (`brushmodulesimd.wasm`) differs in behaviour (it is selected by capability detection).
- Training data and method for the 9 NCA models (not in the bundle).

## 16. Reproducing this analysis

```bash
# wrapper page and embed URL
curl -sL -A "Mozilla/5.0" "https://artsandculture.google.com/experiment/splash-canvas/vQFCtQB7FDnYkA" -o page.html
grep -o 'gacembed[^"]*' page.html

# app files (the HTML is gzipped)
curl -sL --compressed -A "Mozilla/5.0" "https://gacembed.withgoogle.com/octopus-paint?axl=1" -o index.html
curl -sL --compressed https://gacembed.withgoogle.com/octopus-paint/47/main.js -o main.js
curl -sL --compressed https://gacembed.withgoogle.com/octopus-paint/47/worker/worker.js -o worker.js

# shaders: extract GLSL template strings (contain "void main()")
python3 - <<'PY'
import re
s = open('main.js', encoding='utf8').read()
print(len(re.findall(r'`[^`]*void main\(\)[^`]*`', s)))   # 42 shader strings
PY
```

Key landmarks in `main.js` (byte offsets for version 47): the paint material functions around 541,000 to 546,000;
the light config `hu` near 570,100; the fluid solver shaders 434,000 to 442,000; the splat and pickup shaders
613,000 to 622,000; the NCA update generator near 609,400; the preset objects `Fc`, `Sc` and `t2` near 933,000.
