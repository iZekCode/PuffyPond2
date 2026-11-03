#include <metal_stdlib>
using namespace metal;

// Wet paint simulated on the GPU.
// paint texture: rgb = pigment color, a = paint thickness (0…1).
// flow texture:  xy = velocity in texels/s (y points down the texture), z = wetness (0…1, up to 3 for
//                runny watercolor that keeps blooming outward), w = bristle relief.

struct PaintStamp {
    float4 segment;   // a.xy, b.xy in world units
    float4 color;     // rgb, kind (0 = paint, 1 = erase)
    float4 brush;     // radius, amount, dryness, seed
    float4 motion;    // brush velocity (texels/s) xy, erase rate, push
    float4 shape;     // nib angle, nib aspect (1 = round), bristles (0…1), watery (0…1)
    float4 extra;     // palette knife, impasto, runs, blend (each 0…1)
    float4 nca;       // neural cellular automaton: 1 = grows a learned texture, seed probability, stroke seed
};

struct PaintParams {
    float4 frame;     // left, top (world), world units per texel, dt
    float4 size;      // width, height, stamp count, clear
    float4 tune;      // dry rate, leveling, velocity damping, gravity
    float4 shade;     // normal strength, cavity darkening, bristle relief, paint body
    float4 canvas;    // weave thread pitch (texels), weave depth under thin paint, per-texel grain height
    float4 nca;       // kernel stride (texels), dt, fire rate, frame number
    float4 ncaShade;  // height strength, color strength, life lost per second, stride jitter
    float4 ncaPatch;  // patch size (world), patch edge low, edge high, per-stroke bias range
    float4 ncaSpeed;  // slow speed (full texture), fast speed (no texture, colour smears), world units/s
};

static float hash21(int2 p) {
    uint h = uint(p.x) * 374761393u + uint(p.y) * 668265263u;
    h = (h ^ (h >> 13)) * 1274126177u;
    h ^= h >> 16;
    return float(h & 0xFFFFu) / 65535.0 * 2.0 - 1.0;
}

/// Smooth value noise in -1…1.
static float noise(float2 p) {
    int2 i = int2(floor(p));
    float2 f = p - floor(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i), b = hash21(i + int2(1, 0)), c = hash21(i + int2(0, 1)), d = hash21(i + int2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

/// One simulation step: advect paint along its velocity, level and blend wet paint,
/// let thick paint sag, dry, then apply this frame's brush dabs and starfish scrubs.
/// flow.w holds the bristle relief: the brush texture of the last stroke that passed, which is carried
/// along with the paint but never leveled, so strokes keep their texture instead of puffing up.
kernel void paintStep(texture2d<float, access::sample> paintIn [[texture(0)]],
                      texture2d<float, access::sample> flowIn [[texture(1)]],
                      texture2d<float, access::write> paintOut [[texture(2)]],
                      texture2d<float, access::write> flowOut [[texture(3)]],
                      constant PaintParams &P [[buffer(0)]],
                      constant PaintStamp *stamps [[buffer(1)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uint(P.size.x) || gid.y >= uint(P.size.y)) return;
    if (P.size.w > 0.5) {
        paintOut.write(float4(1, 1, 1, 0), gid);
        flowOut.write(float4(0), gid);
        return;
    }
    constexpr sampler lin(coord::pixel, filter::linear, address::clamp_to_edge);
    const float dt = P.frame.w;
    const float2 pos = float2(gid) + 0.5;

    // Semi-Lagrangian advection: wet paint is carried along by its own flow. Resting paint is read
    // exactly (no resampling), otherwise bilinear filtering would slowly blur every texture away.
    float4 f0 = flowIn.sample(lin, pos);
    float2 shift = f0.xy * saturate(f0.z) * dt;
    float2 from = length(shift) > 0.05 ? pos - shift : pos;
    float4 p = paintIn.sample(lin, from);
    float4 f = flowIn.sample(lin, from);
    float wet = f.z;
    float relief = f.w;

    // Leveling: wet paint relaxes toward its painted neighbours, mixing colors where they meet.
    // Oil paint never creeps out onto bare canvas (strokes would swell); runny watercolor (wetness > 1.2)
    // does, blooming outward until it dries.
    float thickness = p.a;
    float3 color = p.rgb;
    float4 nb[4];
    float runny = 0;
    for (int k = 0; k < 4; k++) {
        float2 o = k == 0 ? float2(1, 0) : k == 1 ? float2(-1, 0) : k == 2 ? float2(0, 1) : float2(0, -1);
        nb[k] = paintIn.sample(lin, from + o);
        float nw = flowIn.sample(lin, from + o).z;
        if (nb[k].a > 0.02) runny = max(runny, nw);
    }
    bool blooming = runny > 1.2;
    float level = clamp(P.tune.y * max(wet, blooming ? runny : 0.0) * dt, 0.0, 0.25);
    if (level > 1e-4 && (p.a > 0.02 || blooming)) {
        float sumA = p.a;
        float3 sumC = p.rgb * p.a;
        for (int k = 0; k < 4; k++) {
            bool painted = nb[k].a > 0.02 || blooming;
            sumA += painted ? nb[k].a : p.a;
            sumC += painted ? nb[k].rgb * nb[k].a : p.rgb * p.a;
        }
        thickness = mix(p.a, sumA * 0.2, level);
        float3 premul = mix(p.rgb * p.a, sumC * 0.2, level);
        // Colours never mix here (only the blender mixes them): paint keeps its own colour, and only bare canvas that the
        // wash blooms onto takes its neighbours'.
        color = p.a > 0.02 ? p.rgb : (thickness > 1e-4 ? premul / thickness : p.rgb);
        if (blooming) wet = max(wet, runny * 0.9);   // the bloom carries on, a little weaker each texel
    }

    // Flow slows down (viscous paint) and stops, thick wet blobs sag downward, and everything dries.
    float2 velocity = f.xy * exp(-P.tune.z * dt);
    velocity.y += P.tune.w * max(thickness - 0.6, 0.0) * wet * dt;
    if (length(velocity) < 2.0) velocity = float2(0);
    wet *= exp(-P.tune.x * dt);
    if (wet < 0.02) { wet = 0; velocity = float2(0); }

    const float2 world = float2(P.frame.x + pos.x * P.frame.z, P.frame.y - pos.y * P.frame.z);
    const int count = int(P.size.z);
    for (int s = 0; s < count; s++) {
        PaintStamp st = stamps[s];
        float2 a = st.segment.xy, b = st.segment.zw;
        float radius = st.brush.x;
        float2 seg = b - a;
        float len2 = dot(seg, seg);
        float t = len2 > 1e-10 ? clamp(dot(world - a, seg) / len2, 0.0, 1.0) : 0.0;
        float2 offset = world - (a + seg * t);
        float dist = length(offset);
        if (dist > radius * 1.4) continue;
        // A flat nib is an ellipse (full width along its edge, thin across it) swept along the segment:
        // measure in nib space, where the ellipse is a circle, so the sweep has clean edges.
        float aspect = max(st.shape.y, 1.0);
        if (aspect > 1.0) {
            float2 nib = float2(cos(st.shape.x), sin(st.shape.x));
            float2 across = float2(-nib.y, nib.x);
            float2 pn = float2(dot(world - a, nib), dot(world - a, across) * aspect);
            float2 sn = float2(dot(seg, nib), dot(seg, across) * aspect);
            float tn = dot(sn, sn) > 1e-10 ? clamp(dot(pn, sn) / dot(sn, sn), 0.0, 1.0) : 0.0;
            dist = length(pn - sn * tn);
            if (dist > radius * 1.4) continue;
        }

        if (st.color.w > 0.5) {
            // Starfish scrub: smear thin and wipe away.
            float k = 1.0 - smoothstep(radius * 0.55, radius, dist);
            thickness *= 1.0 - k * st.motion.z;
            relief *= 1.0 - k * st.motion.z;
            if (thickness < 0.008) { thickness = 0.0; relief = 0.0; }
            wet = max(wet, 0.6 * k);
            continue;
        }

        float seed = st.brush.w;
        float2 seedOffset = float2(seed * 3.1, seed * 7.3);
        float ragged = noise(world * 9.0 + seedOffset) * 0.7 + noise(world * 23.0 + seedOffset) * 0.3;
        float x = dist / (radius * (1.0 + 0.22 * ragged));
        if (x >= 1.15) continue;

        const float bristles = st.shape.z, watery = st.shape.w, knife = st.extra.x;
        const float impasto = st.extra.y, runs = st.extra.z, blender = st.extra.w;
        // Flat top (a brush lays a sheet, not a tube) with paint pushed up into a rim at the edges.
        // A knife leaves a crisper edge and a taller ridge; watercolor fades out softly.
        float edge = mix(mix(0.7, 0.88, knife), 0.35, watery);
        float profile = 1.0 - smoothstep(edge, 1.0, x);
        float rim = (x - 0.9) / 0.1;
        float rimLift = (0.45 + 0.7 * knife) * (1.0 + impasto) * (1.0 - watery) * exp(-rim * rim);

        // Bristle grooves running along the stroke; a fast brush goes dry and streaky.
        float len = sqrt(len2);
        float2 dir = len > 1e-5 ? seg / len : float2(1, 0);
        float u = dot(world, float2(-dir.y, dir.x));
        float along = dot(world, dir);
        float groove = 0.5 * sin(u * 140.0 + seed) + 0.3 * sin(u * 61.0 + seed * 1.7)
                     + 0.45 * noise(float2(u * 260.0, along * 6.0 + seed));
        // A knife drags only a few fine streaks through its sheet.
        groove = mix(groove, 0.4 * noise(float2(u * 90.0, seed)), knife);
        float bristle = mix(1.0, 0.68 + 0.36 * groove, bristles);
        float dry = st.brush.z;
        float streak = max(0.0, bristle - dry * 0.5) / (1.0 - dry * 0.5);
        float deposit = st.brush.y * (profile + rimLift) * streak;

        // An NCA brush gets more smeary the faster it moves: 0 at a slow speed, 1 at a fast one.
        const float fast = st.nca.x > 0.5 ? smoothstep(P.ncaSpeed.x, P.ncaSpeed.y, length(st.motion.xy) * P.frame.z) : 0.0;
        // The brush drags whatever wet paint it passes through, and combs its own bristle marks into it.
        float push = saturate(1.1 - x);
        velocity = mix(velocity, st.motion.xy, push * mix(st.motion.w, 0.95, fast));
        // Runny paint slides downhill (texture y points down) while the brush keeps it wet.
        velocity.y += runs * 160.0 * push;
        wet = max(wet, push);
        float comb = saturate(push * 2.0) * saturate(len * 400.0 + 0.15) * (1.0 - watery) * (1.0 - blender);
        relief = mix(relief, groove * 0.6 * max(bristles, knife) + rimLift, comb);

        if (blender > 0.5) {
            // Blender: no new paint. Mix the paint under it with the paint a few texels around,
            // and soften the bristle marks, so colors smudge into each other.
            float k = push;
            float sumA = 0.0, painted = 0.0;
            float3 sumC = float3(0);
            for (int n = 0; n < 4; n++) {
                float2 o = n == 0 ? float2(4, 0) : n == 1 ? float2(-4, 0) : n == 2 ? float2(0, 4) : float2(0, -4);
                float4 q = paintIn.sample(lin, from + o);
                if (q.a > 0.02) { sumA += q.a; sumC += q.rgb * q.a; painted += 1.0; }
            }
            if (painted > 0.0 && thickness > 0.02) {
                color = mix(color, sumC / sumA, 0.5 * k);
                thickness = mix(thickness, sumA / painted, 0.25 * k);
            }
            relief *= 1.0 - 0.4 * k;
            continue;
        }
        if (fast > 0.01 && thickness > 0.02) {
            // A fast stroke smears its thickness a little (never its colour: only the blender mixes colours).
            float sumA = 0.0, painted = 0.0;
            float3 sumC = float3(0);
            for (int n = 0; n < 4; n++) {
                float2 o = n == 0 ? float2(4, 0) : n == 1 ? float2(-4, 0) : n == 2 ? float2(0, 4) : float2(0, -4);
                float4 q = paintIn.sample(lin, from + o);
                if (q.a > 0.02) { sumA += q.a; sumC += q.rgb * q.a; painted += 1.0; }
            }
            if (painted > 0.0) {
                thickness = mix(thickness, sumA / painted, 0.15 * fast * push);
            }
        }
        if (deposit <= 1e-6) continue;
        // A brush lays a coat of paint, it doesn't build a mound: thickness tops out at a cap.
        // Watercolor is a thin glaze, so washes build up layer by layer.
        float cap = mix(0.55 + 0.1 * ragged, 0.12 + 0.03 * ragged, watery);
        cap = mix(cap, 0.95 + 0.05 * ragged, impasto);
        float add = deposit * max(0.0, cap - thickness);
        // The newest paint covers what is below it: colours never blend (only the blender mixes them), so wherever the
        // brush lays paint the colour is simply the brush's.
        float blend = saturate(deposit * 40.0);
        // Watercolor pigment gathers at the wash's edge and dries darker there.
        float pooled = 1.0 - 0.22 * watery * smoothstep(0.55, 0.95, x);
        float3 pigment = st.color.rgb * (0.96 + 0.04 * ragged) * pooled;
        // Watercolor is a pale tint of its pigment (whatever is below does not show through).
        pigment = mix(pigment, mix(float3(1), pigment, 0.6), watery);
        color = mix(color, pigment, blend);
        thickness += add;
        wet = max(wet, 1.0 + 2.0 * watery);
    }

    paintOut.write(float4(color, thickness), gid);
    flowOut.write(float4(velocity, wet, relief), gid);
}

// MARK: Neural cellular automaton
//
// A trained texture that grows on its own where a brush has touched. Every texel holds 12 state channels
// (ncaA = channels 0…3, ncaB = 4…7, ncaC = 8…11; the first three are the visible colour, centred on 0)
// and a life value (r = how long it keeps growing, g = how much of an NCA texture the texel carries, 0 = none,
// b = which model grows there: every paint colour has its own, trained on its own texture).
// Each step a texel perceives itself and its 8 neighbours with 4 fixed kernels per channel (identity,
// Sobel-x, Sobel-y, Laplacian): 48 values, then a 2-layer perceptron (48 -> 96 ReLU -> 12) says how to change.
// This is the "Self-Organising Textures" model (Distill 2021). tools/nca/train_nca.py trains the weights; the
// weight buffer layout is w1[96][48], b1[96], w2[12][96] with no bias (5856 floats).

constant int kNCAChannels = 12;
constant int kNCAInputs = kNCAChannels * 4;
constant int kNCAHidden = 96;
constant int kNCAB1 = kNCAHidden * kNCAInputs;
constant int kNCAW2 = kNCAB1 + kNCAHidden;
constant float kPaintLift = 0.9;         // < 1 lifts the mid tones of the displayed paint
constant float kNCASaturation = 1.1;    // how much more colourful the displayed texture is than the trained one
constant float kNCAGain = 1.1;          // and how much brighter
constant int kNCAWeightCount = kNCAW2 + kNCAChannels * kNCAHidden;   // one model; the buffer holds one per paint colour

static float hash3(int2 p, uint salt) {
    uint h = uint(p.x) * 374761393u + uint(p.y) * 668265263u + salt * 2246822519u;
    h = (h ^ (h >> 13)) * 1274126177u;
    h ^= h >> 16;
    return float(h & 0xFFFFFFu) / 16777215.0;
}

/// Distance from `world` to a stamp's segment (round brush).
static float stampDistance(float2 world, PaintStamp st) {
    float2 a = st.segment.xy, seg = st.segment.zw - a;
    float len2 = dot(seg, seg);
    float t = len2 > 1e-10 ? clamp(dot(world - a, seg) / len2, 0.0, 1.0) : 0.0;
    return length(world - (a + seg * t));
}

kernel void ncaStep(texture2d<float, access::sample> ncaAIn [[texture(0)]],
                    texture2d<float, access::sample> ncaBIn [[texture(1)]],
                    texture2d<float, access::sample> ncaCIn [[texture(2)]],
                    texture2d<float, access::sample> lifeIn [[texture(3)]],
                    texture2d<float, access::sample> flowIn [[texture(4)]],
                    texture2d<float, access::write> ncaAOut [[texture(5)]],
                    texture2d<float, access::write> ncaBOut [[texture(6)]],
                    texture2d<float, access::write> ncaCOut [[texture(7)]],
                    texture2d<float, access::write> lifeOut [[texture(8)]],
                    constant PaintParams &P [[buffer(0)]],
                    constant PaintStamp *stamps [[buffer(1)]],
                    constant float *W [[buffer(2)]],
                    uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uint(P.size.x) || gid.y >= uint(P.size.y)) return;
    if (P.size.w > 0.5) {
        ncaAOut.write(float4(0), gid);
        ncaBOut.write(float4(0), gid);
        ncaCOut.write(float4(0), gid);
        lifeOut.write(float4(0), gid);
        return;
    }
    constexpr sampler lin(coord::pixel, filter::linear, address::clamp_to_edge);
    const float dt = P.frame.w;
    const float2 pos = float2(gid) + 0.5;

    // The texture rides the paint: read from where the paint's own flow carried it from (same rule as paintStep).
    float4 f0 = flowIn.sample(lin, pos);
    float2 shift = f0.xy * saturate(f0.z) * dt;
    float2 from = length(shift) > 0.05 ? pos - shift : pos;
    float4 state[3] = { ncaAIn.sample(lin, from), ncaBIn.sample(lin, from), ncaCIn.sample(lin, from) };
    constexpr sampler near(coord::pixel, filter::nearest, address::clamp_to_edge);   // a model index must not blend
    float4 life = lifeIn.sample(near, from);
    constant float *Wm = W + int(life.z + 0.5) * kNCAWeightCount;

    if (life.x > 0.01 && life.y > 0.02) {
        // Neighbours are read at the stride (a jitter per texel is optional; 0 = exactly the next texel).
        float stride = P.nca.x * (1.0 + P.ncaShade.w * (hash3(int2(gid), 7u) * 2.0 - 1.0));
        float4 gx[3] = { float4(0), float4(0), float4(0) };
        float4 gy[3] = { float4(0), float4(0), float4(0) };
        float4 gl[3] = { float4(0), float4(0), float4(0) };
        for (int k = 0; k < 9; k++) {
            int dx = k % 3 - 1, dy = k / 3 - 1;
            float4 t[3] = { state[0], state[1], state[2] };
            if (k != 4) {
                float2 q = from + stride * float2(dx, dy);
                t[0] = ncaAIn.sample(lin, q);
                t[1] = ncaBIn.sample(lin, q);
                t[2] = ncaCIn.sample(lin, q);
            }
            float sx = float(dx) * (dy == 0 ? 2.0 : 1.0);
            float sy = float(dy) * (dx == 0 ? 2.0 : 1.0);
            float lp = dx == 0 && dy == 0 ? -12.0 : (dx == 0 || dy == 0 ? 2.0 : 1.0);
            for (int j = 0; j < 3; j++) {
                gx[j] += sx * t[j];
                gy[j] += sy * t[j];
                gl[j] += lp * t[j];
            }
        }
        float perceived[kNCAInputs];
        for (int j = 0; j < 3; j++) {
            for (int c = 0; c < 4; c++) {
                int base = (j * 4 + c) * 4;
                perceived[base + 0] = state[j][c];
                perceived[base + 1] = gx[j][c];
                perceived[base + 2] = gy[j][c];
                perceived[base + 3] = gl[j][c];
            }
        }
        float hidden[kNCAHidden];
        for (int h = 0; h < kNCAHidden; h++) {
            float s = Wm[kNCAB1 + h];
            for (int i = 0; i < kNCAInputs; i++) s += Wm[h * kNCAInputs + i] * perceived[i];
            hidden[h] = max(s, 0.0);
        }
        float delta[kNCAChannels];
        for (int o = 0; o < kNCAChannels; o++) {
            float s = 0.0;
            for (int h = 0; h < kNCAHidden; h++) s += Wm[kNCAW2 + o * kNCAHidden + h] * hidden[h];
            delta[o] = s;
        }
        // Only a share of the texels change each frame (the rule was trained that way). The notebook does not
        // clamp the state (an overflow loss keeps it small); the +-4 only guards half precision against a runaway.
        if (hash3(int2(gid), uint(P.nca.w) * 31u + 3u) < P.nca.z) {
            for (int j = 0; j < 3; j++) {
                float4 d = float4(delta[j * 4], delta[j * 4 + 1], delta[j * 4 + 2], delta[j * 4 + 3]);
                state[j] = clamp(state[j] + P.nca.y * d, -4.0, 4.0);
            }
        }
        life.x = max(0.0, life.x - P.ncaShade.z * dt);
    }

    // Brush dabs: an NCA brush starts the rule from a blank (zero) state; any other paint or an eraser covers the texture.
    const float2 world = float2(P.frame.x + pos.x * P.frame.z, P.frame.y - pos.y * P.frame.z);
    const int count = int(P.size.z);
    for (int s = 0; s < count; s++) {
        PaintStamp st = stamps[s];
        float radius = st.brush.x;
        float dist = stampDistance(world, st);
        if (dist > radius) continue;
        if (st.nca.x > 0.5) {
            // Paint of another colour covers the old colour's texture: colours never blend, the newest one wins.
            if (life.y > 0.02 && dist < radius * 0.8 && int(life.z + 0.5) != int(st.nca.w + 0.5)) life = float4(0.0);
            // Texels that are still growing keep their own pattern; the brush only starts fresh ones. Texels that
            // already carried a texture restart a few at a time, so a brush held in place keeps the texture changing
            // instead of the whole puddle blinking at once.
            const float restart = life.y < 0.02 ? 1.0 : 0.05;
            if (life.x < 0.5 && hash3(int2(gid), uint(P.nca.w) * 17u + 11u) < st.nca.y * restart) {
                // The texture only takes hold in patches (a soft, low-frequency noise field, shifted per stroke,
                // with a per-stroke bias so some strokes carry more of it than others); between them the paint stays plain.
                // A slow brush leaves the full texture; the faster it moves, the less of it takes hold.
                float2 offset = float2(st.nca.z * 3.7, st.nca.z * 1.9);
                float bias = (hash3(int2(int(floor(st.nca.z * 31.0)), 5), 9u) * 2.0 - 1.0) * P.ncaPatch.w;
                float field = noise(world / P.ncaPatch.x + offset) * 0.5 + 0.5 + bias;
                // How fast the brush went decides how smooth the texture stays (0 = full texture … 1 = blended into one colour).
                float speedSmooth = smoothstep(P.ncaSpeed.x, P.ncaSpeed.y, length(st.motion.xy) * P.frame.z);
                float coverage = smoothstep(P.ncaPatch.y, P.ncaPatch.z, field);
                if (coverage > 0.02) {
                    state[0] = float4(0);
                    state[1] = float4(0);
                    state[2] = float4(0);
                    life = float4(1.0, coverage, st.nca.w, speedSmooth);
                }
            }
        } else if (st.color.w > 0.5 ? dist < radius * 0.8 : (st.brush.y > 0.0 && st.extra.w < 0.5 && dist < radius * 0.8)) {
            life = float4(0.0);
        }
    }

    ncaAOut.write(state[0], gid);
    ncaBOut.write(state[1], gid);
    ncaCOut.write(state[2], gid);
    lifeOut.write(life, gid);
}

/// The linen weave under the paint (0…1): warp and weft threads passing over and under each other.
static float weave(float2 p, float pitch) {
    float2 q = p / pitch;
    float2 cell = floor(q), f = q - cell;
    float warp = sin(M_PI_F * f.x), weft = sin(M_PI_F * f.y);
    bool warpOnTop = fmod(cell.x + cell.y, 2.0) < 0.5;
    float top = warpOnTop ? warp * (0.75 + 0.25 * weft) : weft * (0.75 + 0.25 * warp);
    return max(top, (warpOnTop ? weft : warp) * 0.55);
}

/// Surface height at a clamped texel: a low, flat paint body plus the bristle relief and a faint grain.
/// Thin paint follows the canvas weave underneath; a thick coat buries it.
/// How much of an NCA texture a texel shows (0…1). A freshly seeded texel is still blank, so it fades in as it grows.
static float ncaGrown(float4 life, float covered) {
    return life.y * covered * smoothstep(0.0, 0.2, 1.0 - life.x);
}

static float surfaceHeight(texture2d<float, access::read> paint, texture2d<float, access::read> flow,
                           texture2d<float, access::read> nca, texture2d<float, access::read> ncaLife,
                           constant float4 *ncaMeans, int2 c, int2 size, float4 shade, float4 canvas, float ncaHeight) {
    c = clamp(c, int2(0), size - 1);
    float a = paint.read(uint2(c)).a;
    float covered = saturate(a * 20.0);
    float relief = flow.read(uint2(c)).w;
    float thin = covered * (1.0 - smoothstep(0.05, 0.4, a));
    // Per-texel canvas tooth that shows through the paint, a little less where the coat is thick.
    float grain = canvas.z * (hash21(c) * 0.5 + 0.5) * covered * (1.0 - 0.3 * saturate(a / 0.55));
    // A grown NCA texture lifts and lowers the paint where it is brighter or darker than its model's average.
    float4 life = ncaLife.read(uint2(c));
    float meanBrightness = dot(ncaMeans[int(life.z + 0.5)].rgb, float3(1.0 / 3.0));
    float ncaBright = dot(nca.read(uint2(c)).rgb + 0.5, float3(1.0 / 3.0)) - meanBrightness;
    float grown = ncaGrown(life, covered) * (1.0 - smoothstep(0.3, 0.9, life.w));
    return a * shade.w + relief * shade.z * covered + 0.006 * noise(float2(c) * 0.9) * covered
         + weave(float2(c), canvas.x) * canvas.y * thin + grain + ncaBright * grown * ncaHeight;
}

/// Turns the simulation into what the material samples: color + coverage, a per-pixel normal map
/// (so every ridge and bristle groove catches the light) and roughness (wet = glossy).
kernel void paintShade(texture2d<float, access::read> paint [[texture(0)]],
                       texture2d<float, access::read> flow [[texture(1)]],
                       texture2d<float, access::write> albedo [[texture(2)]],
                       texture2d<float, access::write> normalMap [[texture(3)]],
                       texture2d<float, access::write> roughness [[texture(4)]],
                       texture2d<float, access::read> ncaA [[texture(5)]],
                       texture2d<float, access::read> ncaLife [[texture(6)]],
                       texture2d<float, access::write> glow [[texture(7)]],
                       constant PaintParams &P [[buffer(0)]],
                       constant float4 *ncaMeans [[buffer(1)]],
                       uint2 gid [[thread_position_in_grid]]) {
    const int2 size = int2(P.size.xy);
    if (int(gid.x) >= size.x || int(gid.y) >= size.y) return;
    float4 p = paint.read(gid);
    #define h(o) surfaceHeight(paint, flow, ncaA, ncaLife, ncaMeans, int2(gid) + (o), size, P.shade, P.canvas, P.ncaShade.x)
    float hc = h(int2(0));
    float hl = h(int2(-1, 0)), hr = h(int2(1, 0)), hu = h(int2(0, -1)), hd = h(int2(0, 1));
    float htl = h(int2(-1, -1)), htr = h(int2(1, -1)), hbl = h(int2(-1, 1)), hbr = h(int2(1, 1));
    float strength = P.shade.x;
    // Sobel gradient (scaled to match a central difference): smoother than 4 taps, so ridges and grain
    // read as soft relief instead of per-texel noise.
    float gx = ((htl - htr) + 2.0 * (hl - hr) + (hbl - hbr)) * 0.25;
    float gy = ((hbl - htl) + 2.0 * (hd - hu) + (hbr - htr)) * 0.25;
    float3 n = normalize(float3(gx * strength, gy * strength, 1.0));

    // Cavities (grooves, the dip inside a rim) read darker, like real impasto.
    float around = (h(int2(-3, 0)) + h(int2(3, 0)) + h(int2(0, -3)) + h(int2(0, 3))) * 0.25;
    float cavity = 1.0 - saturate((around - hc) * P.shade.y);
    float coverage = smoothstep(0.004, 0.05, p.a);
#undef h

    float wet = saturate(flow.read(gid).z);
    // Pigment colors are sRGB values; the material samples this texture as linear.
    // Where an NCA texture has grown, its own colours replace the flat pigment (each paint colour has a model trained
    // on a texture of that colour).
    float grown = ncaGrown(ncaLife.read(gid), coverage);
    // A slow stroke shows the full texture, a quicker one a coarser and then a finer gradation of it, and a fast one is
    // blended into one smooth colour (the texture's own average): the stroke's speed was stored when it was laid.
    const float smoothness = ncaLife.read(gid).w;
    float3 ncaColor = saturate(ncaA.read(gid).rgb + 0.5);
    if (smoothness > 0.02) {
        const float r = smoothness * 14.0;
        float3 sum = float3(0);
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                int2 q = clamp(int2(gid) + int2(round(float2(i, j) * r)), int2(0), size - 1);
                sum += ncaA.read(uint2(q)).rgb;
            }
        }
        ncaColor = saturate(sum / 9.0 + 0.5);
        const float3 average = ncaMeans[int(ncaLife.read(gid).z + 0.5)].rgb;
        ncaColor = mix(ncaColor, average, 0.9 * smoothstep(0.45, 0.95, smoothness));
    }
    // The grown texture would be duller than the fresh pigment it replaces (it has its own shadows and the studio light
    // flattens it): lift it back so a stroke keeps its colour as the texture grows in.
    ncaColor = saturate(mix(float3(dot(ncaColor, float3(0.299, 0.587, 0.114))), ncaColor, kNCASaturation) * kNCAGain);
    // A mild lift of the mid tones (whites stay white): wet paint reads bright and a dried coat would look dull next to it.
    float3 shown = pow(saturate(mix(p.rgb, ncaColor, grown * P.ncaShade.y) * cavity), kPaintLift);
    float3 linearColor = pow(shown, 2.2);
    albedo.write(float4(linearColor, coverage), gid);
    // The paint's own glow (see PaintLayer.emission) only on a proper coat: a thin wash edge glowing would show as a white outline.
    glow.write(float4(linearColor * smoothstep(0.04, 0.12, p.a), 1), gid);
    normalMap.write(float4(n * 0.5 + 0.5, 1), gid);
    // Bare canvas is fully matte; paint is glossy while wet and keeps a soft sheen when dry (a flat dry coat looks dull).
    roughness.write(float4(float3(mix(1.0, mix(0.04, 0.02, wet), sqrt(coverage))), 1), gid);
}
