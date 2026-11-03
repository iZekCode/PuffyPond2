import SceneKit
import simd

/// Brush: a ladybug, drawn the way a real one looks from above: a round domed shell with a dark seam and black
/// spots, a black shield behind a small black head with white cheek patches, and six short legs (three a side).
/// While painting the legs lie flat on the canvas and are the brush, exactly like the octopus's tentacles (see
/// `LimbBrush`). The shell lifts at the back with the beat. It faces the camera at rest and turns sideways,
/// head first, when it travels (`Critter.facesMotion`). The shell takes the paint colour (red, orange or yellow).
final class Ladybug: Critter {
    private let legs: TentacleBundle
    private let limbs: LimbBrush
    private var wings: [SCNNode] = []
    private var antennae: [SCNNode] = []
    private var wingSpring = Spring1(0)
    /// 0 = shell closed … 1 = fully lifted (a touch more while it flutters).
    private(set) var wingOpen: Float = 0

    /// The shell: one round dome (a little wider than long), split down the middle by a thin dark seam.
    private static let shellRadii = SIMD3<Float>(0.165, 0.125, 0.17)

    /// The three legs of one side, front to back: where each leaves the body and which way it points.
    private static let legRoots: [(local: SIMD3<Float>, outward: SIMD3<Float>)] = {
        var roots: [(local: SIMD3<Float>, outward: SIMD3<Float>)] = []
        for side: Float in [-1, 1] {
            for (z, out) in [(0.1, 0.8), (-0.02, 0.0), (-0.14, -0.8)] as [(Float, Float)] {
                roots.append((SIMD3(side * 0.1, -0.06, z), SIMD3(side, 0, out)))
            }
        }
        return roots
    }()

    init(color: SIMD3<Float>, at start: SIMD3<Float>) {
        let black = Toybox.balloon(SIMD3(0.07, 0.06, 0.08), wobble: 0.002, roughness: 0.3)
        let cream = Toybox.balloon(SIMD3(1.0, 0.95, 0.82), wobble: 0, roughness: 0.35)

        // Very short, stubby, fairly stiff legs.
        var shape = TentacleBundle.Shape()
        shape.segments = 7
        shape.segmentLength = 0.025
        shape.rootRadius = 0.013
        shape.tipRadius = 0.006
        shape.startAngle = 0.8
        shape.curl = 0.7
        shape.sway = 0.3
        shape.stiffness = 0.2
        shape.gravity = 1.0
        shape.ripple = 0.05
        legs = TentacleBundle(shape: shape, roots: Self.legRoots, start: start)
        limbs = LimbBrush(bundle: legs, limbZ: Octopus.limbZ)
        super.init(kind: .ladybug, color: color, at: start, accentLift: 0.3)
        // Lying flat, each leg points where it leaves the body: (side, front/back) → (canvas x, canvas y).
        legs.setSpokes(Self.legRoots.map { SIMD2($0.outward.x, $0.outward.z) })
        legs.material = black
        root.addChildNode(legs.node)

        // Dark underside, seen where the shell lifts.
        squashNode.addChildNode(Toybox.node(SCNSphere(radius: 0.13), black, at: SIMD3(0, -0.03, -0.04),
                                            scale: SIMD3(0.95, 0.65, 1.2)))

        // The round shell (hinged at the front, so the back lifts a little), its seam and its black spots.
        let hinge = SCNNode()
        hinge.simdPosition = SIMD3(0, 0.05, 0.12)
        let shell = SCNNode()
        shell.simdPosition = SIMD3(0, -0.05, -0.15)
        shell.addChildNode(Toybox.node(SCNSphere(radius: 0.15), bodyMaterial, scale: Self.shellRadii / 0.15))
        shell.addChildNode(Toybox.node(SCNSphere(radius: 0.15), black,
                                       scale: SIMD3(0.012 / 0.15, Self.shellRadii.y * 1.01 / 0.15, Self.shellRadii.z * 1.01 / 0.15)))
        let spots: [(dir: SIMD3<Float>, radius: Float)] = [
            (SIMD3(0.5, 0.75, 0.5), 0.036), (SIMD3(0.8, 0.5, -0.1), 0.038), (SIMD3(0.45, 0.6, -0.65), 0.032),
        ]
        for side in [Float(-1), 1] {
            for (dir, radius) in spots {
                shell.addChildNode(Self.decal(radius: radius, on: Self.shellRadii,
                                              direction: simd_normalize(SIMD3(dir.x * side, dir.y, dir.z)), material: black))
            }
        }
        hinge.addChildNode(shell)
        squashNode.addChildNode(hinge)
        wings.append(hinge)

        // The shield behind the head, with a white patch on each front corner, and the small head in front of it.
        let shieldRadii = SIMD3<Float>(0.135, 0.07, 0.085)
        let shield = SCNNode()
        shield.simdPosition = SIMD3(0, 0.03, 0.15)
        shield.addChildNode(Toybox.node(SCNSphere(radius: 0.1), black, scale: shieldRadii / 0.1))
        for side in [Float(-1), 1] {
            shield.addChildNode(Self.decal(radius: 0.03, on: shieldRadii,
                                           direction: simd_normalize(SIMD3(0.62 * side, 0.35, 0.7)), material: cream))
        }
        squashNode.addChildNode(shield)
        let head = SCNNode()
        head.simdPosition = SIMD3(0, -0.015, 0.2)
        head.addChildNode(Toybox.node(SCNSphere(radius: 0.085), black, scale: SIMD3(1.1, 0.95, 0.9)))
        squashNode.addChildNode(head)

        // Antennae with a ball on the end.
        for side in [Float(-1), 1] {
            let pivot = SCNNode()
            pivot.simdPosition = SIMD3(side * 0.035, 0.05, 0.25)
            pivot.addChildNode(Toybox.node(SCNCapsule(capRadius: 0.006, height: 0.1), black, at: SIMD3(0, 0.05, 0)))
            pivot.addChildNode(Toybox.node(SCNSphere(radius: 0.015), black, at: SIMD3(0, 0.105, 0)))
            pivot.simdEulerAngles = SIMD3(0.8, 0, -side * 0.35)
            squashNode.addChildNode(pivot)
            antennae.append(pivot)
        }

        // Big googly eyes on the black head.
        addFace(eyes: [EyeSpot(position: SIMD3(-0.042, 0.02, 0.065), yaw: -0.25, browSign: -1),
                       EyeSpot(position: SIMD3(0.042, 0.02, 0.065), yaw: 0.25, browSign: 1)],
                eyeRadius: 0.045, mouth: SIMD3(0, -0.04, 0.075), mouthRadius: 0.016, cheeks: [], parent: head)
    }

    /// A flat disc lying on the surface of an egg-shaped part (semi-axes `radii`, centred on the node) in `direction`.
    private static func decal(radius: Float, on radii: SIMD3<Float>, direction d: SIMD3<Float>,
                              material: SCNMaterial) -> SCNNode {
        let normal = simd_normalize(d / radii)
        let node = Toybox.node(SCNSphere(radius: CGFloat(radius)), material, at: d * radii * 0.995,
                               scale: SIMD3(1, 1, 0.3))
        node.simdOrientation = simd_quatf(from: SIMD3(0, 0, 1), to: normal)
        return node
    }

    override var facesMotion: Bool { true }

    override var usesSizeSlider: Bool { true }
    override var holdProgress: Float? { limbs.holdProgress }

    override func flare(_ amount: Float) {
        legs.flare(amount, body: leanNode.simdWorldTransform)
    }

    override func animate(dt: Float, painting: Bool, beatPulse: Float, scale: Float, hidden: Bool) {
        // Open on every beat; while painting the covers also flutter.
        let flutter = painting ? 0.35 + 0.3 * sin(clock * 22) : 0
        wingSpring.step(to: max(beatPulse, flutter), stiffness: 160, damping: 18, dt: dt)
        wingOpen = min(max(wingSpring.value, 0), 1.2)
        for hinge in wings {
            hinge.simdEulerAngles = SIMD3(wingOpen * 0.3, 0, 0)
        }
        for (k, antenna) in antennae.enumerated() {
            let side: Float = k == 0 ? -1 : 1
            antenna.simdEulerAngles = SIMD3(0.8 + sin(clock * 3 + Float(k)) * 0.15, 0,
                                            -side * 0.35 + sin(clock * 2.3 + Float(k) * 2) * 0.2)
        }
        limbs.animate(dt: dt, velocity: SIMD2(position.velocity.x, position.velocity.y), head: bodyNode.simdPosition,
                      body: leanNode.simdWorldTransform, scale: scale, clock: clock, beatPulse: beatPulse,
                      pressing: painting && !hidden, hidden: hidden)
    }

    /// The round body paints too, along the path it travels, so a quick drag still leaves paint when the short legs
    /// have no time to reach the canvas; the legs add their strokes on top.
    override func dabs(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float, speed: Float) -> [BrushDab] {
        let body = BrushDab(from: a, to: b, radius: radius * Self.bodyBrush * sizeScale, speed: speed, style: .octopus)
        return [body] + limbs.dabs(towards: b)
    }

    /// The body's brush is this many times the stroke radius (at size 1): about as wide as the shell.
    static let bodyBrush: Float = 1.7
}
