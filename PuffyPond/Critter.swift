import SceneKit
import simd

/// The garden cast: the characters that carry the paint tools. The raw values are written into saved timelapse
/// recordings, so they stay put when a character is removed.
enum CritterKind: Int, CaseIterable, Equatable {
    case snail = 1
    case ladybug = 7, butterfly = 8, mushroom = 9

    /// The cast in tool-column order (butterfly brush, ladybug brush, eraser, blender).
    static let gardenCast: [CritterKind] = [.butterfly, .ladybug, .mushroom, .snail]

    var name: String {
        switch self {
        case .snail: return "Snail"
        case .ladybug: return "Ladybug"
        case .butterfly: return "Butterfly"
        case .mushroom: return "Mushroom"
        }
    }

    /// What kind of brush it is.
    var brush: String {
        switch self {
        case .snail: return "blender"
        case .ladybug: return "bundle brush"
        case .butterfly: return "bundle brush"
        case .mushroom: return "eraser"
        }
    }

    var symbol: String {
        switch self {
        case .snail: return "tornado"
        case .ladybug: return "scribble.variable"
        case .butterfly: return "drop.halffull"
        case .mushroom: return "cloud.fill"
        }
    }

    /// Its own color while it waits in a critter bubble.
    var signatureColor: SIMD3<Float> {
        switch self {
        case .snail: return Paint.colors[2]
        case .ladybug: return Paint.colors[0]
        case .butterfly: return Paint.colors[1]
        case .mushroom: return SIMD3(0.98, 0.53, 0.72)
        }
    }

    func make(color: SIMD3<Float>, at start: SIMD3<Float>) -> Critter {
        switch self {
        case .snail: return Snail(color: color, at: start)
        case .ladybug: return Ladybug(color: color, at: start)
        case .butterfly: return Butterfly(color: color, at: start)
        case .mushroom: return Mushroom(color: color, at: start)
        }
    }
}

/// One paint dab a critter lays this frame.
struct BrushDab {
    var from: SIMD2<Float>
    var to: SIMD2<Float>
    var radius: Float
    var speed: Float
    var style: BrushStyle = .brush
    /// How far the brush moved this frame, when that isn't `to - from` (a leg lying on the canvas).
    var drag: SIMD2<Float>? = nil
}

/// A hand's brush animal: shared body rig (follow spring, lean, squash, presence), face and moods.
/// Subclasses build their bodies, add their own secondary motion in `animate`, and decide how they
/// paint in `dabs` (while the fist is closed).
class Critter {
    let kind: CritterKind
    let root = SCNNode()
    let bodyNode = SCNNode()       // position + appear/disappear scale
    let leanNode = SCNNode()       // tilts toward the motion
    let squashNode = SCNNode()
    let bodyMaterial: SCNMaterial
    let accentMaterial: SCNMaterial

    private(set) var color: SIMD3<Float>
    private(set) var displayedColor: SIMD3<Float>
    /// While rubbing a paint pot, the body previews the new color.
    var colorPreview: (color: SIMD3<Float>, amount: Float)?
    var position: Spring3
    /// Overall size (the little ones sitting in the critter pots are smaller).
    var sizeScale: Float = 1
    var lean = SIMD3<Float>.zero
    var squash = Spring3(SIMD3(1, 1, 1))
    private(set) var presence = Spring1(0)
    private(set) var clock: Float = 0
    /// Where the eyes drift on their own, on top of following the motion (gallery visitors look up).
    var gazeBias = SIMD2<Float>.zero
    /// Turn sideways toward the travel direction (profile animals) instead of facing the camera.
    var turnsToMotion = false
    private var yaw: Float = -0.35
    /// -1 (heading left) … 0 (facing the camera) … 1 (heading right): how far it has turned toward its travel.
    private(set) var side: Float = 0
    private var travelDirection: Float = 1
    private var blinkStart: Float = -10
    private var nextBlink: Float = 2

    private(set) var mood: Mood = .calm
    private var reaction: (mood: Mood, until: Float)?
    private(set) var face = Face.target(for: .calm)
    private var eyes: [Toybox.Eye] = []
    private var browSigns: [Float] = []
    private var brows: [SCNNode] = []
    private var cheekNodes: [SCNNode] = []
    private var mouthNode: SCNNode?

    var speed: Float { simd_length(position.velocity) }
    /// The displayed size right now (presence × size), for rigs that build world-space meshes.
    var currentScale: Float { max(presence.value, 0.001) * sizeScale }

    init(kind: CritterKind, color: SIMD3<Float>, at start: SIMD3<Float>, accentLift: Float = 0.1) {
        self.kind = kind
        self.color = color
        displayedColor = color
        position = Spring3(start)
        bodyMaterial = Toybox.balloon(color, wobble: 0.004, speed: 6)
        accentMaterial = Toybox.balloon(color, wobble: 0.003, speed: 8)
        self.accentLift = accentLift
        root.addChildNode(bodyNode)
        bodyNode.addChildNode(leanNode)
        leanNode.addChildNode(squashNode)
        bodyNode.simdPosition = start
        bodyNode.simdScale = SIMD3(repeating: 0.001)
    }

    private let accentLift: Float

    // MARK: Face

    struct EyeSpot {
        var position: SIMD3<Float>
        var yaw: Float          // which way the eye looks (0 = toward the camera)
        var browSign: Float     // mirrors the brow tilt for left/right eyes
    }

    /// Googly eyes with brows, blushing cheeks and pouty lips.
    func addFace(eyes spots: [EyeSpot], eyeRadius: Float, mouth: SIMD3<Float>, mouthYaw: Float = 0,
                 mouthRadius: Float, cheeks: [SIMD3<Float>], parent: SCNNode? = nil) {
        let host = parent ?? squashNode
        let browMaterial = Toybox.balloon(SIMD3(0.15, 0.1, 0.12), wobble: 0, roughness: 0.4)
        for spot in spots {
            let facing = SCNNode()
            facing.simdPosition = spot.position
            facing.simdEulerAngles = SIMD3(0, spot.yaw, 0)
            host.addChildNode(facing)
            let eye = Toybox.eye(radius: eyeRadius)
            facing.addChildNode(eye.root)
            eyes.append(eye)
            let brow = Toybox.node(SCNCapsule(capRadius: CGFloat(eyeRadius * 0.18), height: CGFloat(eyeRadius * 1.1)),
                                   browMaterial)
            facing.addChildNode(brow)
            brows.append(brow)
            browSigns.append(spot.browSign)
        }
        let blush = Toybox.blush()
        for p in cheeks {
            let cheek = SCNNode(geometry: SCNSphere(radius: CGFloat(eyeRadius * 0.5)))
            cheek.geometry?.materials = [blush]
            cheek.simdScale = SIMD3(1.3, 0.75, 0.3)
            cheek.simdPosition = p
            host.addChildNode(cheek)
            cheekNodes.append(cheek)
        }
        let lips = Toybox.lips(radius: mouthRadius, color: SIMD3(1.0, 0.45, 0.55))
        lips.simdPosition = mouth
        lips.simdEulerAngles = SIMD3(0, mouthYaw, 0)
        host.addChildNode(lips)
        mouthNode = lips
    }

    // MARK: Reactions

    func setColor(_ newColor: SIMD3<Float>) {
        color = newColor
        squash.velocity += SIMD3(3, -3, 0)   // shiver of delight
        flare(0.6)
    }

    /// Big gulp when it starts a new line.
    func gulp() {
        squash.velocity += SIMD3(-3, 4, 0)
        flare(1)
        react(.excited, for: 0.45)
    }

    /// A short-lived emotion that overrides the current activity mood.
    func react(_ mood: Mood, for seconds: Float) {
        reaction = (mood, clock + seconds)
        if mood == .surprised { flare(0.8) }
    }

    /// Secondary-motion kick (legs splay, wings flutter…).
    func flare(_ amount: Float) {}

    // MARK: Per frame

    func update(dt: Float, target: SIMD3<Float>, visible: Bool, painting: Bool, beatPulse: Float) {
        clock += dt
        presence.step(to: visible ? 1 : 0, stiffness: 160, damping: 14, dt: dt)
        move(dt: dt, target: target, painting: painting)
        let v = position.velocity

        let leanGoal = SIMD3(max(-0.45, min(0.45, -v.y * 0.1)),
                             max(-0.35, min(0.35, v.x * 0.1)),
                             max(-0.5, min(0.5, -v.x * 0.13))) * leanAmount
        lean += (leanGoal - lean) * min(1, dt * 8)
        if facesMotion { turnToTravel(velocity: v, dt: dt) }
        if turnsToMotion, abs(v.x) > 0.25 {
            let goal: Float = v.x > 0 ? -0.35 : -Float.pi + 0.35
            yaw += (goal - yaw) * min(1, dt * 7)
        }

        if let r = reaction, clock > r.until { reaction = nil }
        let activityMood: Mood = painting ? (speed > 1.8 ? .excited : .blowing) : .calm
        mood = reaction?.mood ?? activityMood
        face = Face.mix(face, Face.target(for: mood), min(1, dt * 12))

        let stretch = 1 + smoothStep(0.05, 3, speed) * 0.1
        let beat = beatPulse * 0.07
        let puff = face.cheeks * (0.08 + 0.04 * sin(clock * 16))
        squash.step(to: SIMD3(1 / stretch + beat + puff * 0.5, stretch - beat * 0.8, 1 + puff),
                    stiffness: 220, damping: 9, dt: dt)

        var shown = color
        if let preview = colorPreview { shown = mix(color, preview.color, preview.amount) }
        displayedColor += (shown - displayedColor) * min(1, dt * 10)
        bodyMaterial.diffuse.contents = Paint.platform(displayedColor)
        accentMaterial.diffuse.contents = Paint.platform(displayedColor * (1 - accentLift) + SIMD3(repeating: accentLift))

        if clock - blinkStart > nextBlink {
            blinkStart = clock
            nextBlink = Float.random(in: 2...5)
        }
        let lid = Toybox.blinkScale(clock - blinkStart) * (1 - face.squint * 0.8)
        let gaze = SIMD2(max(-0.8, min(0.8, v.x * 0.3)) * (turnsToMotion ? 0 : 1) + (turnsToMotion ? 0.6 : 0),
                         max(-0.8, min(0.8, v.y * 0.3)) + (mood == .surprised ? 0.4 : 0)) + gazeBias
        for (i, eye) in eyes.enumerated() {
            eye.root.simdScale = SIMD3(face.eyeScale, lid * face.eyeScale, 1)
            eye.pupil.isHidden = face.squint > 0.6
            Toybox.look(eye, toward: gaze)
            let r = eye.radius
            brows[i].simdPosition = SIMD3(0, r * (1.25 + face.browLift * 0.35) * face.eyeScale, r * 0.45)
            brows[i].simdEulerAngles = SIMD3(0, 0, Float.pi / 2 + browSigns[i] * face.browTilt)
        }
        for cheek in cheekNodes { cheek.opacity = CGFloat(face.blush) }
        if let mouthNode {
            let chomp = painting ? 0.15 * sin(clock * 14) : 0
            let m = face.mouth + chomp
            mouthNode.simdScale = SIMD3(m, m, 1)
        }

        let scale = currentScale * (painting ? 1.08 : 1)
        bodyNode.simdPosition = position.value + SIMD3(0, bob, 0)
        bodyNode.simdScale = SIMD3(repeating: scale)
        if facesMotion {
            leanNode.simdOrientation = headingOrientation * Self.orientation(euler: lean)
        } else {
            leanNode.simdEulerAngles = lean + SIMD3(0, turnsToMotion ? yaw : 0, 0)
        }
        squashNode.simdScale = squash.value
        let hidden = presence.value < 0.01 && !visible
        root.isHidden = hidden
        animate(dt: dt, painting: painting, beatPulse: beatPulse, scale: scale, hidden: hidden)
    }

    // MARK: Heading (3/4 view from above while moving)

    /// How a critter that `facesMotion` stands at rest and when it travels: the angle (radians) of its turn about
    /// `axis` when idle, heading right and heading left. The default is to face the camera and turn the head about
    /// 60° toward the direction of travel.
    struct Heading {
        var idle: Float = 0
        var right: Float = 1.1
        var left: Float = -1.1
        /// Turn about the vertical axis (a standing animal), or roll about the viewing axis (a flat one, like the
        /// butterfly, whose wings face the camera).
        var axis: SIMD3<Float> = SIMD3(0, 1, 0)
        /// How far the top tips toward the camera at rest and at full turn, so it is seen a little from above
        /// when it waits and from above and the side when it travels.
        var restPitch: Float = 0.3
        var pitch: Float = 0.55
    }

    /// Turns to the side, seen from above, while it travels, and faces the camera again when it stops.
    var facesMotion: Bool { false }
    var heading: Heading { Heading() }

    /// The turn for the current `side` (the pitch comes first, about the screen's x axis, then the turn).
    private var headingOrientation: simd_quatf {
        let h = heading
        let angle = side >= 0 ? h.idle + (h.right - h.idle) * side : h.idle + (h.left - h.idle) * -side
        let tip = h.restPitch + (h.pitch - h.restPitch) * abs(side)
        return simd_quatf(angle: tip, axis: SIMD3(1, 0, 0)) * simd_quatf(angle: angle, axis: h.axis)
    }

    private func turnToTravel(velocity v: SIMD3<Float>, dt: Float) {
        if abs(v.x) > 0.2 { travelDirection = v.x > 0 ? 1 : -1 }
        let moving = smoothStep(0.15, 0.6, simd_length(SIMD2(v.x, v.y)))
        side += (travelDirection * moving - side) * min(1, dt * 6)
    }

    private static func orientation(euler e: SIMD3<Float>) -> simd_quatf {
        simd_quatf(angle: e.z, axis: SIMD3(0, 0, 1)) * simd_quatf(angle: e.y, axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: e.x, axis: SIMD3(1, 0, 0))
    }

    // MARK: Overridable behavior

    var followStiffness: Float { 95 }
    var followDamping: Float { 19.5 }
    var leanAmount: Float { 1 }
    /// How long a held-still brush has been pressing, as 0…1 (nil when it isn't held still): drives a sound.
    var holdProgress: Float? { nil }
    /// Whether the brush-size slider scales this critter (the limb brush: the ladybug).
    var usesSizeSlider: Bool { false }
    /// How much paint this critter wipes away around itself while its tool is the eraser (world units).
    var eraseRadius: Float { 0.26 }
    var bob: Float { sin(clock * 2.2) * 0.02 }

    /// How the critter travels toward the hand (a spring by default).
    func move(dt: Float, target: SIMD3<Float>, painting: Bool) {
        position.step(to: target, stiffness: followStiffness, damping: followDamping, dt: dt)
    }

    /// Called every frame the critter wipes away some paint (it munches, scrubs...).
    func scrubbed() {}

    /// Secondary motion, after the body transforms are set for this frame.
    func animate(dt: Float, painting: Bool, beatPulse: Float, scale: Float, hidden: Bool) {}

    /// Paint for this frame's brush segment a → b (the critter's own path across the canvas).
    func dabs(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float, speed: Float) -> [BrushDab] {
        [BrushDab(from: a, to: b, radius: radius, speed: speed)]
    }
}
