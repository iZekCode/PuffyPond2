import Foundation
import simd

/// Where things sit around the easel, and how a point in the view maps into the world. The camera backs off until
/// the canvas and the pot and bubble columns beside it fit the window.
struct CanvasLayout {
    /// A big canvas (≈ 1.8× wider than before) — lots of room for broad arm strokes.
    static let canvasSize = SIMD2<Float>(6.4, 4.0)
    static let canvasCenter = SIMD2<Float>(0, 0.1)
    static let canvasZ: Float = 0.04            // front face of the canvas
    /// The pot and bubble columns sit just outside the canvas's left and right edges.
    static let shelfX: Float = canvasSize.x * 0.5 + 0.38
    static let shelfSpacing: Float = 0.62
    /// Paint pots: `topPotCount` stand in a row above the canvas's top-right corner, the rest go down the right side,
    /// spread over the canvas height, so the arms have to reach up, out and down for a color.
    static let topPotCount = 2
    static let topPotY: Float = canvasCenter.y + canvasSize.y * 0.5 + 0.36
    static let topPotGap: Float = 0.75
    static let sidePotSpacing: Float = 0.9
    static let potRadius: Float = 0.2
    /// The critter bubbles on the left are bigger, so the little critter inside is easy to see.
    static let bubbleRadius: Float = 0.405
    /// The bubbles' column stands just clear of the canvas's left edge, spaced so the big bubbles don't touch.
    static let bubbleShelfX: Float = canvasSize.x * 0.5 + bubbleRadius + 0.12
    static let bubbleSpacing: Float = 0.95
    static let strokeRadius: Float = 0.085
    static let paintHoverZ: Float = 0.24        // how high the brush animal hovers while painting
    static let brushSizeRange: ClosedRange<Float> = 0.6...2.4
    static let cameraY: Float = 0.1
    static let tanHalfFOV = Float(tan(17.0 * Double.pi / 180))

    private(set) var aspect: Float = 16.0 / 10.0
    private(set) var cameraDistance: Float = 7

    /// Backs the camera off until the canvas and both columns fit a window of this shape, with a little room around them.
    mutating func fit(width: Float, height: Float) {
        guard width > 0, height > 0 else { return }
        aspect = width / height
        let needHalfH = Self.canvasSize.y * 0.5 * 1.04
        let needHalfW = (max(Self.shelfX + Self.potRadius, Self.bubbleShelfX + Self.bubbleRadius) + 0.3) * 1.04   // the columns stand nearer the camera than the canvas
        // The pots above the canvas (and their rub ring) stand at the pots' depth.
        let needPotsH = (Self.topPotY + 0.32 - Self.cameraY) * 1.04
        cameraDistance = max(Self.canvasZ + max(needHalfH / Self.tanHalfFOV, needHalfW / (Self.tanHalfFOV * aspect)),
                             Self.potZ + needPotsH / Self.tanHalfFOV)
    }

    /// Visible half-size of the view at depth z.
    func visibleHalfSize(atZ z: Float) -> SIMD2<Float> {
        let halfH = (cameraDistance - z) * Self.tanHalfFOV
        return SIMD2(halfH * aspect, halfH)
    }

    /// View UV (0…1, y down) → point in the world at depth z.
    func worldPoint(_ uv: SIMD2<Float>, z: Float) -> SIMD3<Float> {
        let h = visibleHalfSize(atZ: z)
        return SIMD3((uv.x * 2 - 1) * h.x, Self.cameraY + (1 - uv.y * 2) * h.y, z)
    }

    /// Stereo pan (-1…1) for a sound at world x.
    func pan(forX x: Float) -> Float {
        max(-1, min(1, x / max(visibleHalfSize(atZ: 0.5).x, 0.1)))
    }

    /// Where an idle buddy drifts, in lazy loops so the buddies always feel alive.
    func idleTarget(slot: Int, clock: Float, z: Float) -> SIMD3<Float> {
        let h = visibleHalfSize(atZ: z)
        let t = clock * 0.35 + Float(slot) * 3.1
        return SIMD3(sin(t) * h.x * 0.6, Self.cameraY - h.y * 0.62 + sin(t * 2.3) * 0.15, z)
    }

    /// How high a buddy hovers. Painting, the animal comes down close to the canvas so its legs can lie on it; a
    /// bigger brush animal hovers higher, so its body stays clear of the canvas. `brushSize` is nil for animals
    /// without the size slider.
    static func buddyZ(painting: Bool, brushSize: Float?) -> Float {
        guard painting else { return 0.42 }
        return canvasZ + (paintHoverZ - canvasZ) * max(brushSize ?? 1, 1)
    }

    /// How far the pots and bubbles stand in front of the canvas.
    static let potZ: Float = 0.3

    /// Where paint pot `k` of `count` stands (x, y): the first `topPotCount` in a row above the top-right corner
    /// (the last of them straight above the side column), the rest down the right side.
    static func potPosition(_ k: Int, of count: Int) -> SIMD2<Float> {
        let top = min(topPotCount, count)
        if k < top {
            return SIMD2(shelfX - Float(top - 1 - k) * topPotGap, topPotY)
        }
        let side = count - top
        let i = k - top
        return SIMD2(shelfX, canvasCenter.y - 0.1 + (Float(side - 1) / 2 - Float(i)) * sidePotSpacing)
    }

    /// Height of bubble `k` of `count` in the left column, centred on the canvas.
    static func bubbleY(_ k: Int, of count: Int) -> Float {
        canvasCenter.y + (Float(count - 1) / 2 - Float(k)) * bubbleSpacing
    }

    /// Height of slot `k` in a column of `count` pots or bubbles, centred on the canvas.
    static func columnY(_ k: Int, of count: Int) -> Float {
        canvasCenter.y + (Float(count - 1) / 2 - Float(k)) * shelfSpacing
    }

    /// Whether `p` (canvas plane) is on the pot or bubble standing at `center`.
    static func touches(_ p: SIMD2<Float>, potAt center: SIMD3<Float>, radius: Float = CanvasLayout.potRadius) -> Bool {
        simd_distance(p, SIMD2(center.x, center.y + 0.04)) < radius + 0.14
    }

    /// Where a brush at `p` lays paint, clamped inside the canvas edge; nil when it is off the canvas.
    /// Only a little slack sideways: reaching for a pot or bubble beside the canvas shouldn't paint.
    static func brushPoint(_ p: SIMD2<Float>) -> SIMD2<Float>? {
        let half = canvasSize * 0.5 - SIMD2(repeating: strokeRadius)
        guard abs(p.x - canvasCenter.x) <= half.x + 0.05, abs(p.y - canvasCenter.y) <= half.y + 0.12 else { return nil }
        return simd_clamp(p, canvasCenter - half, canvasCenter + half)
    }

    /// Whether `p` is on the canvas itself (the eraser also roams the shelf and the floor).
    static func isOnCanvas(_ p: SIMD2<Float>) -> Bool {
        abs(p.x - canvasCenter.x) <= canvasSize.x / 2 && abs(p.y - canvasCenter.y) <= canvasSize.y / 2
    }

    /// A world point → canvas (0…1, y down), nil when it's off the canvas.
    static func canvasUV(_ p: SIMD3<Float>) -> SIMD2<Float>? {
        let uv = SIMD2((p.x - canvasCenter.x + canvasSize.x * 0.5) / canvasSize.x,
                       (canvasCenter.y + canvasSize.y * 0.5 - p.y) / canvasSize.y)
        guard uv.x >= 0, uv.x <= 1, uv.y >= 0, uv.y <= 1 else { return nil }
        return uv
    }

    /// Height on the canvas, 0 at the bottom edge and 1 at the top, for the pitch of a paint blip.
    static func blipHeight(_ p: SIMD2<Float>) -> Float {
        (p.y - canvasCenter.y) / canvasSize.y + 0.5
    }
}
