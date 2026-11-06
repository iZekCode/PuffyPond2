import Foundation
import simd

/// Where things sit in the scene, and how a point in the view maps into the world. The canvas fills the whole
/// window; the four characters float in a row along its bottom edge.
struct CanvasLayout {
    /// A big canvas — lots of room for broad arm strokes.
    static let canvasSize = SIMD2<Float>(6.4, 4.0)
    static let canvasCenter = SIMD2<Float>(0, 0.1)
    static let canvasZ: Float = 0.04            // front face of the canvas
    static let strokeRadius: Float = 0.085
    static let paintHoverZ: Float = 0.24        // how high the brush animal hovers while painting
    static let brushSizeRange: ClosedRange<Float> = 0.6...2.4
    static let cameraY: Float = 0.1
    static let tanHalfFOV = Float(tan(17.0 * Double.pi / 180))

    /// Every character is this many times its original size.
    static let characterScale: Float = 1.0
    /// How far the waiting characters float in front of the canvas.
    static let characterZ: Float = 0.3
    /// Rubbing a buddy this close to a waiting character picks it.
    static let characterRadius: Float = 0.3
    /// A waiting character wakes up when a buddy comes this close (and sleeps again when it leaves).
    static let characterWakeRadius: Float = 0.9
    /// Height of the waiting characters' centres above the bottom edge of the window. Less than half a character, so
    /// the lower part of each one hides below the edge.
    static let characterBottomMargin: Float = 0.1
    static let characterMaxSpacing: Float = 1.0

    private(set) var aspect: Float = 16.0 / 10.0
    private(set) var cameraDistance: Float = 7

    /// Pulls the camera in until the canvas just covers the window (whichever side is tighter), so the whole view
    /// is canvas, edge to edge.
    mutating func fit(width: Float, height: Float) {
        guard width > 0, height > 0 else { return }
        aspect = width / height
        let halfH = Self.canvasSize.y * 0.5
        let halfW = Self.canvasSize.x * 0.5
        cameraDistance = Self.canvasZ + min(halfH / Self.tanHalfFOV, halfW / (Self.tanHalfFOV * aspect))
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
        return SIMD3(sin(t) * h.x * 0.6, Self.cameraY - h.y * 0.3 + sin(t * 2.3) * 0.15, z)
    }

    /// How high a buddy hovers. Painting, the animal comes down close to the canvas so its legs can lie on it; a
    /// bigger brush animal hovers higher, so its body stays clear of the canvas. `brushSize` is nil for animals
    /// without the size slider.
    static func buddyZ(painting: Bool, brushSize: Float?) -> Float {
        guard painting else { return 0.42 }
        return canvasZ + (paintHoverZ - canvasZ) * max(brushSize ?? 1, 1)
    }

    /// Where the waiting characters float (x, y at `characterZ`), left to right in a row along the bottom edge.
    func characterSlots(count: Int) -> [SIMD2<Float>] {
        let h = visibleHalfSize(atZ: Self.characterZ)
        let spacing = max(0, min(Self.characterMaxSpacing, (h.x - Self.characterRadius) * 2 / Float(max(count - 1, 1))))
        let y = Self.cameraY - h.y + Self.characterBottomMargin
        return (0..<count).map { SIMD2((Float($0) - Float(count - 1) / 2) * spacing, y) }
    }

    /// Whether `p` (canvas plane) is on the character standing at `center`.
    static func touches(_ p: SIMD2<Float>, characterAt center: SIMD3<Float>) -> Bool {
        simd_distance(p, SIMD2(center.x, center.y)) < characterRadius
    }

    /// Where a brush at `p` lays paint, clamped inside the canvas edge; nil when it is off the canvas.
    /// Only a little slack beyond the edge.
    static func brushPoint(_ p: SIMD2<Float>) -> SIMD2<Float>? {
        let half = canvasSize * 0.5 - SIMD2(repeating: strokeRadius)
        guard abs(p.x - canvasCenter.x) <= half.x + 0.05, abs(p.y - canvasCenter.y) <= half.y + 0.12 else { return nil }
        return simd_clamp(p, canvasCenter - half, canvasCenter + half)
    }

    /// Whether `p` is on the canvas itself .
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
