import SceneKit
import simd

// MARK: - Springs (everything bouncy is a spring)

struct Spring3 {
    var value: SIMD3<Float>
    var velocity: SIMD3<Float> = .zero

    init(_ value: SIMD3<Float>) { self.value = value }

    mutating func step(to target: SIMD3<Float>, stiffness: Float, damping: Float, dt: Float) {
        var remaining = dt
        while remaining > 0 {
            let h = min(remaining, 1.0 / 120.0)
            let a = (target - value) * stiffness - velocity * damping
            velocity += a * h
            value += velocity * h
            remaining -= h
        }
    }
}

struct Spring1 {
    var value: Float
    var velocity: Float = 0

    init(_ value: Float) { self.value = value }

    mutating func step(to target: Float, stiffness: Float, damping: Float, dt: Float) {
        var remaining = dt
        while remaining > 0 {
            let h = min(remaining, 1.0 / 120.0)
            let a = (target - value) * stiffness - velocity * damping
            velocity += a * h
            value += velocity * h
            remaining -= h
        }
    }
}

func smoothStep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}

func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> { a + (b - a) * t }

// MARK: - Faces

/// How a buddy feels right now. Each mood drives eyes, brows, mouth, cheeks and blush.
enum Mood: Equatable {
    case calm       // pottering along
    case blowing    // concentrating, cheeks puffed, pushing out paint
    case excited    // drawing fast: big sparkly eyes, brows up, wide mouth
    case surprised  // picked a color / bumped a creature: huge eyes, round "O"
    case happy      // finished a line / a creature was born: closed smiling eyes, blush
}

struct Face {
    var eyeScale: Float
    var squint: Float      // 1 = happy closed eyes
    var browLift: Float
    var browTilt: Float    // + angry/determined, - worried
    var mouth: Float       // mouth opening
    var cheeks: Float      // puffed cheeks
    var blush: Float

    static func target(for mood: Mood) -> Face {
        switch mood {
        case .calm: return Face(eyeScale: 1, squint: 0, browLift: 0, browTilt: 0, mouth: 0.9, cheeks: 0, blush: 0.15)
        case .blowing: return Face(eyeScale: 1.08, squint: 0, browLift: -0.4, browTilt: 0.45, mouth: 1.5, cheeks: 1, blush: 0.45)
        case .excited: return Face(eyeScale: 1.28, squint: 0, browLift: 0.8, browTilt: -0.15, mouth: 1.7, cheeks: 0.4, blush: 0.7)
        case .surprised: return Face(eyeScale: 1.45, squint: 0, browLift: 1.2, browTilt: -0.3, mouth: 2.0, cheeks: 0, blush: 0.3)
        case .happy: return Face(eyeScale: 1, squint: 1, browLift: 0.5, browTilt: -0.2, mouth: 1.1, cheeks: 0.2, blush: 0.9)
        }
    }

    static func mix(_ a: Face, _ b: Face, _ t: Float) -> Face {
        Face(eyeScale: a.eyeScale + (b.eyeScale - a.eyeScale) * t,
             squint: a.squint + (b.squint - a.squint) * t,
             browLift: a.browLift + (b.browLift - a.browLift) * t,
             browTilt: a.browTilt + (b.browTilt - a.browTilt) * t,
             mouth: a.mouth + (b.mouth - a.mouth) * t,
             cheeks: a.cheeks + (b.cheeks - a.cheeks) * t,
             blush: a.blush + (b.blush - a.blush) * t)
    }
}

// MARK: - Paint pots (dip a critter in to pick up a color)

final class PaintPot {
    let root = SCNNode()
    let colorIndex: Int
    let color: SIMD3<Float>
    static let radius: Float = 0.2
    private let body = SCNNode()
    private let blob: SCNNode
    private let blobMaterial: SCNMaterial
    private let progressRing: SCNNode
    private let halo: SCNNode
    private var squash = Spring3(SIMD3(1, 1, 1))
    private var lift = Spring1(0)
    private var ringScale = Spring1(0)
    private var clock: Float = 0

    init(colorIndex: Int, at position: SIMD3<Float>) {
        self.colorIndex = colorIndex
        color = Paint.colors[colorIndex]
        root.simdPosition = position
        root.addChildNode(body)

        let jarMaterial = Toybox.balloon(SIMD3(0.97, 0.97, 1.0), wobble: 0, roughness: 0.15)
        let jar = Toybox.node(SCNCylinder(radius: 0.17, height: 0.16), jarMaterial, at: SIMD3(0, -0.06, 0))
        body.addChildNode(jar)
        let rim = Toybox.node(SCNTorus(ringRadius: 0.17, pipeRadius: 0.025), jarMaterial, at: SIMD3(0, 0.02, 0))
        body.addChildNode(rim)

        // A wobbly dome of paint bulging out of the jar.
        blobMaterial = Toybox.balloon(color, wobble: 0.01, speed: 5, roughness: 0.18)
        blob = Toybox.node(SCNSphere(radius: 0.16), blobMaterial, at: SIMD3(0, 0.03, 0), scale: SIMD3(1, 0.62, 1))
        body.addChildNode(blob)
        let drip = Toybox.node(SCNSphere(radius: 0.035), blobMaterial, at: SIMD3(0.09, -0.04, 0.15),
                               scale: SIMD3(0.8, 1.4, 0.6))
        body.addChildNode(drip)

        // Fills up while you rub a critter in the pot.
        let ringMaterial = SCNMaterial()
        ringMaterial.lightingModel = .constant
        ringMaterial.diffuse.contents = Paint.platform(color)
        progressRing = SCNNode(geometry: SCNTorus(ringRadius: 0.27, pipeRadius: 0.022))
        progressRing.geometry?.materials = [ringMaterial]
        progressRing.simdEulerAngles = SIMD3(Float.pi / 2, 0, 0)
        progressRing.simdScale = SIMD3(repeating: 0.001)
        root.addChildNode(progressRing)

        // Shows which pot is a critter's current color.
        let haloMaterial = SCNMaterial()
        haloMaterial.lightingModel = .constant
        haloMaterial.diffuse.contents = Paint.platform(SIMD3(1, 1, 1))
        halo = SCNNode(geometry: SCNTorus(ringRadius: 0.21, pipeRadius: 0.014))
        halo.geometry?.materials = [haloMaterial]
        halo.simdPosition = SIMD3(0, -0.15, 0)
        root.addChildNode(halo)
    }

    func bounce(_ strength: Float = 1) {
        squash.velocity += SIMD3(3, -5, 3) * strength
    }

    /// - Parameters:
    ///   - rubProgress: 0…1 while a critter is being dipped here.
    ///   - selectedCount: how many critters currently wear this color.
    func update(dt: Float, beatPulse: Float, rubProgress: Float, selectedCount: Int) {
        clock += dt
        let jiggle = rubProgress > 0 ? sin(clock * 30) * 0.05 * rubProgress : 0
        squash.step(to: SIMD3(1 + beatPulse * 0.05 + jiggle, 1 - beatPulse * 0.07 - jiggle, 1 + jiggle),
                    stiffness: 260, damping: 9, dt: dt)
        lift.step(to: selectedCount > 0 ? 0.08 : 0, stiffness: 120, damping: 12, dt: dt)
        ringScale.step(to: rubProgress > 0 ? 0.35 + rubProgress * 0.65 : 0, stiffness: 300, damping: 18, dt: dt)
        blob.simdScale = SIMD3(squash.value.x, 0.62 * squash.value.y + rubProgress * 0.15, squash.value.z)
        Toybox.setWobble(blobMaterial, 0.01 + rubProgress * 0.02 + beatPulse * 0.006)
        progressRing.simdScale = SIMD3(repeating: max(ringScale.value, 0.001))
        progressRing.simdEulerAngles = SIMD3(Float.pi / 2, clock * 3, 0)
        halo.isHidden = selectedCount == 0
        halo.simdScale = SIMD3(repeating: 1 + Float(selectedCount - 1) * 0.15 + sin(clock * 4) * 0.04)
        halo.simdEulerAngles = SIMD3(0.25, clock, 0)
        body.simdPosition = SIMD3(0, lift.value, 0)
    }
}

// MARK: - Critter pots (rub one to pick up that paint tool)

/// A glass bubble with the tool's little critter inside. Rub your critter in it to pick up that paint tool.
final class CritterPot {
    let root = SCNNode()
    let target: PotTarget
    let resident: Critter
    private let bubble: SCNNode
    private let progressRing: SCNNode
    private let halo: SCNNode
    private var squash = Spring3(SIMD3(1, 1, 1))
    private var ringScale = Spring1(0)
    private var clock: Float = 0

    init(tool: PaintTool, at position: SIMD3<Float>) {
        target = .tool(tool)
        root.simdPosition = position
        // Thin clear glass: a faint tint with a shiny highlight, so the resident shows through.
        let glass = SCNMaterial()
        glass.lightingModel = .blinn
        glass.diffuse.contents = PlatformColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 0.12)
        glass.specular.contents = PlatformColor.white
        glass.shininess = 0.9
        glass.transparencyMode = .aOne
        glass.writesToDepthBuffer = false
        bubble = Toybox.node(SCNSphere(radius: CGFloat(PaintPot.radius)), glass)
        root.addChildNode(bubble)
        // A little lavender stand so the bubble reads against the white canvas.
        let stand = Toybox.balloon(SIMD3(0.55, 0.5, 0.9), wobble: 0, roughness: 0.25)
        root.addChildNode(Toybox.node(SCNTorus(ringRadius: 0.14, pipeRadius: 0.035), stand, at: SIMD3(0, -0.19, 0)))

        let ringMaterial = SCNMaterial()
        ringMaterial.lightingModel = .constant
        ringMaterial.diffuse.contents = PlatformColor.white
        progressRing = SCNNode(geometry: SCNTorus(ringRadius: 0.27, pipeRadius: 0.022))
        progressRing.geometry?.materials = [ringMaterial]
        progressRing.simdEulerAngles = SIMD3(Float.pi / 2, 0, 0)
        progressRing.simdScale = SIMD3(repeating: 0.001)
        root.addChildNode(progressRing)

        halo = SCNNode(geometry: SCNTorus(ringRadius: 0.22, pipeRadius: 0.014))
        halo.geometry?.materials = [ringMaterial]
        halo.simdPosition = SIMD3(0, -0.17, 0)
        root.addChildNode(halo)

        // The little resident drifts around inside the bubble (added to the scene by the playground).
        resident = tool.critterKind.make(color: tool.critterKind.signatureColor, at: position)
        resident.sizeScale = 0.5
    }

    /// The resident's scene node.
    var residentRoot: SCNNode { resident.root }

    func bounce(_ strength: Float = 1) {
        squash.velocity += SIMD3(3, -5, 3) * strength
        resident.react(.surprised, for: 0.5)
    }

    /// - Parameters:
    ///   - rubProgress: 0…1 while a buddy is rubbing this bubble.
    ///   - selectedCount: how many buddies hold this tool right now.
    ///   - color: the paint of a buddy that holds this tool, if any (otherwise the critter's own color).
    func update(dt: Float, beatPulse: Float, rubProgress: Float, selectedCount: Int, color: SIMD3<Float>?) {
        clock += dt
        let jiggle = rubProgress > 0 ? sin(clock * 30) * 0.05 * rubProgress : 0
        squash.step(to: SIMD3(1 + beatPulse * 0.04 + jiggle, 1 - beatPulse * 0.05 - jiggle, 1 + jiggle),
                    stiffness: 260, damping: 9, dt: dt)
        bubble.simdScale = squash.value
        ringScale.step(to: rubProgress > 0 ? 0.35 + rubProgress * 0.65 : 0, stiffness: 300, damping: 18, dt: dt)
        progressRing.simdScale = SIMD3(repeating: max(ringScale.value, 0.001))
        progressRing.simdEulerAngles = SIMD3(Float.pi / 2, clock * 3, 0)
        halo.isHidden = selectedCount == 0
        halo.simdScale = SIMD3(repeating: 1 + Float(max(selectedCount - 1, 0)) * 0.15 + sin(clock * 4) * 0.04)
        halo.simdEulerAngles = SIMD3(0.25, clock, 0)

        let c = root.simdPosition
        let drift = SIMD3(sin(clock * 0.9) * 0.04, sin(clock * 1.3) * 0.03 - 0.02, 0.02)
        let shown = color ?? resident.kind.signatureColor
        if simd_distance(shown, resident.color) > 0.01 { resident.setColor(shown) }
        resident.update(dt: dt, target: c + drift, visible: true, painting: false, beatPulse: beatPulse)
    }
}

// MARK: - A hand's buddy

enum BuddyMode: Equatable {
    case idle, roam, paint, erase

    /// What a hand's buddy does for this pose (idle = no hand): an open hand moves it, a fist paints with its tool.
    static func mode(for pose: HandPose?, tool: PaintTool) -> BuddyMode {
        guard let pose else { return .idle }
        switch pose {
        case .open: return .roam
        case .fist: return tool == .eraser ? .erase : .paint
        }
    }
}

/// What a buddy is rubbing: a paint pot (new color) or a tool bubble (new paint tool).
enum PotTarget: Equatable {
    case color(Int)
    case tool(PaintTool)
}

final class Buddy {
    let slot: Int
    private(set) var critter: Critter
    private(set) var mode: BuddyMode = .idle
    private(set) var colorIndex: Int
    private(set) var tool: PaintTool = .brush
    var rubbingPot: PotTarget?
    var rubAmount: Float = 0

    init(slot: Int, colorIndex: Int, kind: CritterKind, start: SIMD3<Float>, tool: PaintTool = .brush) {
        self.tool = tool
        self.slot = slot
        self.colorIndex = colorIndex
        critter = kind.make(color: Paint.colors[colorIndex % Paint.colors.count], at: start)
    }

    func setMode(_ newMode: BuddyMode) {
        mode = newMode
    }

    var toolPosition: SIMD3<Float> { critter.position.value }

    var toolSpeed: Float { critter.speed }

    /// How much paint the tool wipes away around itself.
    var eraseRadius: Float { critter.eraseRadius }

    /// The tool just wiped some paint away.
    func scrubbed() { critter.scrubbed() }

    /// Picks up another paint tool. Returns the brush animal it replaced, if any (to remove from the scene).
    func equip(_ newTool: PaintTool) -> Critter? {
        tool = newTool
        var old: Critter?
        let kind = newTool.critterKind
        if kind != critter.kind {
            // A brush animal only has its own colours: bring along the current one if it fits, else its first.
            if let palette = Paint.palette(for: kind), !palette.contains(colorIndex) { colorIndex = palette[0] }
            old = become(kind)
        }
        return old
    }

    func pick(_ index: Int) {
        colorIndex = index
        critter.colorPreview = nil
        critter.setColor(Paint.colors[index])
        critter.react(.surprised, for: 0.35)
    }

    /// Turn into another brush animal right where we are. Returns the old one (to remove from the scene).
    func become(_ kind: CritterKind) -> Critter {
        let old = critter
        critter = kind.make(color: color, at: old.position.value)
        critter.react(.surprised, for: 0.6)
        return old
    }

    var color: SIMD3<Float> { Paint.colors[colorIndex % Paint.colors.count] }
}
