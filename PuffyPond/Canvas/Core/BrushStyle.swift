/// How one dab behaves: every brush animal paints with its own style.
struct BrushStyle: Equatable {
    var amount: Float?          // paint laid per dab; nil = from motion (moving coats, holding still pools)
    var push: Float = 0.55      // how hard it drags the wet paint it passes through
    var bristles: Float = 1     // 0 = smooth blob, 1 = full bristle grooves
    var nibAngle: Float = 0     // flat-nib edge direction (radians, world)
    var nibAspect: Float = 1    // 1 = round brush, > 1 = flat nib: thick across the edge, thin along it
    var watery: Float = 0       // 0 = oil paint, 1 = runny watercolor wash that blooms outward
    var knife: Float = 0        // 1 = palette knife: a flat sheet with paint ridged up at its edges
    var impasto: Float = 0      // 1 = thick oil: paint piles much higher, with taller ridges
    var runs: Float = 0         // 1 = liquid oil: the wet paint under the brush slides downhill
    var blend: Float = 0        // 1 = blender: lays nothing, smudges and mixes the paint under it
    var nca: Float = 0          // 1 = the paint grows a learned texture after the brush passes (see PaintLayer.ncaWeights)
    var ncaSeed: Float = 1      // chance each texel under the brush starts growing

    static let brush = BrushStyle()
    /// The ladybug and butterfly: a thin watercolor wash that grows its own texture.
    static let wash = BrushStyle(push: 0.4, bristles: 0, watery: 0.9, nca: 1)
    static let blend = BrushStyle(amount: 0, push: 0.9, bristles: 0, blend: 1)
}
