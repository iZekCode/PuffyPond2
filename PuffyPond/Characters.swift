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
    case calm       // swimming along
    case blowing    // concentrating, cheeks puffed, pushing out ink
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

// MARK: - Starfish (the eraser)

final class Starfish {
    let root = SCNNode()
    private let spinNode = SCNNode()
    private let squashNode = SCNNode()
    private let eyes: [Toybox.Eye]
    private var arms: [SCNNode] = []
    var position: Spring3
    private var spin: Float = 0
    private var presence = Spring1(0)
    private var squash = Spring3(SIMD3(1, 1, 1))
    private var clock: Float = 0
    private var blinkStart: Float = -10
    private var surprised: Float = 0

    var speed: Float { simd_length(position.velocity) }
    /// Overall size (the little one sitting in the eraser bubble is smaller).
    var sizeScale: Float = 1
    static let eraseRadius: Float = 0.26

    init(at start: SIMD3<Float>) {
        position = Spring3(start)
        let pink = SIMD3<Float>(1.0, 0.45, 0.48)
        let material = Toybox.balloon(pink, wobble: 0.005, speed: 5)
        let dotMaterial = Toybox.balloon(SIMD3(1.0, 0.82, 0.7), wobble: 0, roughness: 0.4)

        root.addChildNode(squashNode)
        squashNode.addChildNode(spinNode)

        let center = Toybox.node(SCNSphere(radius: 0.12), material, scale: SIMD3(1, 1, 0.55))
        spinNode.addChildNode(center)
        for k in 0..<5 {
            let angle = Float(k) * 2 * Float.pi / 5 + Float.pi / 2
            let dir = SIMD2<Float>(cos(angle), sin(angle))
            let arm = SCNNode()
            arm.simdPosition = SIMD3(dir.x * 0.15, dir.y * 0.15, 0)
            arm.simdEulerAngles = SIMD3(0, 0, angle - Float.pi / 2)
            let capsule = Toybox.node(SCNCapsule(capRadius: 0.065, height: 0.3), material, scale: SIMD3(1, 1, 0.55))
            arm.addChildNode(capsule)
            for d in 0..<2 {
                let dotNode = Toybox.node(SCNSphere(radius: 0.017), dotMaterial,
                                          at: SIMD3(0, -0.02 + Float(d) * 0.08, 0.034))
                arm.addChildNode(dotNode)
            }
            spinNode.addChildNode(arm)
            arms.append(arm)
        }

        // The face stays upright while the arms spin.
        var eyes: [Toybox.Eye] = []
        for side: Float in [-1, 1] {
            let eye = Toybox.eye(radius: 0.055)
            eye.root.simdPosition = SIMD3(side * 0.05, 0.025, 0.07)
            squashNode.addChildNode(eye.root)
            eyes.append(eye)
        }
        self.eyes = eyes
        let mouth = Toybox.lips(radius: 0.018, color: SIMD3(0.75, 0.15, 0.3))
        mouth.simdPosition = SIMD3(0, -0.05, 0.075)
        squashNode.addChildNode(mouth)

        root.simdPosition = start
        root.simdScale = SIMD3(repeating: 0.001)
        root.isHidden = true
    }

    /// Jumps into the hand at the octopus's spot.
    func appear(at point: SIMD3<Float>) {
        position = Spring3(point)
        squash.velocity += SIMD3(4, -4, 0)
    }

    func scrubbed() {
        surprised = 0.35
    }

    func update(dt: Float, target: SIMD3<Float>, visible: Bool, beatPulse: Float) {
        clock += dt
        presence.step(to: visible ? 1 : 0, stiffness: 170, damping: 13, dt: dt)
        position.step(to: target, stiffness: 110, damping: 20, dt: dt)
        spin += dt * (0.8 + speed * 5)
        spinNode.simdEulerAngles = SIMD3(0, 0, -spin)
        for (k, arm) in arms.enumerated() {
            let flap = sin(clock * 9 + Float(k)) * 0.12 * smoothStep(0.1, 2, speed)
            arm.simdScale = SIMD3(1, 1 + flap, 1)
        }
        let beat = beatPulse * 0.08
        squash.step(to: SIMD3(1 + beat, 1 - beat, 1), stiffness: 240, damping: 10, dt: dt)
        surprised = max(0, surprised - dt)

        if clock - blinkStart > 3.5 { blinkStart = clock }
        let lid = surprised > 0 ? 1.25 : Toybox.blinkScale(clock - blinkStart)
        let v = position.velocity
        for eye in eyes {
            eye.root.simdScale = SIMD3(surprised > 0 ? 1.2 : 1, lid, 1)
            Toybox.look(eye, toward: SIMD2(v.x, v.y) * 0.4)
        }

        root.simdPosition = position.value
        squashNode.simdScale = squash.value
        root.simdScale = SIMD3(repeating: max(presence.value * sizeScale, 0.001))
        root.isHidden = presence.value < 0.01 && !visible
    }
}

// MARK: - Paint pots (dip an octopus in to pick up a color)

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

        // Fills up while you rub an octopus in the pot.
        let ringMaterial = SCNMaterial()
        ringMaterial.lightingModel = .constant
        ringMaterial.diffuse.contents = Paint.platform(color)
        progressRing = SCNNode(geometry: SCNTorus(ringRadius: 0.27, pipeRadius: 0.022))
        progressRing.geometry?.materials = [ringMaterial]
        progressRing.simdEulerAngles = SIMD3(Float.pi / 2, 0, 0)
        progressRing.simdScale = SIMD3(repeating: 0.001)
        root.addChildNode(progressRing)

        // Shows which pot is an octopus's current color.
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
    ///   - rubProgress: 0…1 while an octopus is being dipped here.
    ///   - selectedCount: how many octopuses currently wear this color.
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

// MARK: - Critter pots (rub one to become that brush animal)

/// A glass bubble with a little brush animal inside. Rub your critter in it to turn into that animal
/// (legacy controls), or to pick up that paint tool (fist controls; the eraser bubble holds a starfish).
final class CritterPot {
    let root = SCNNode()
    /// `.critter(kind)` or `.tool(tool)`.
    let target: PotTarget
    let resident: Critter?
    let starfish: Starfish?
    private let bubble: SCNNode
    private let progressRing: SCNNode
    private let halo: SCNNode
    private var squash = Spring3(SIMD3(1, 1, 1))
    private var ringScale = Spring1(0)
    private var clock: Float = 0

    convenience init(kind: CritterKind, at position: SIMD3<Float>) {
        self.init(target: .critter(kind), kind: kind, at: position)
    }

    convenience init(tool: PaintTool, at position: SIMD3<Float>) {
        self.init(target: .tool(tool), kind: tool.critterKind, at: position)
    }

    private init(target: PotTarget, kind: CritterKind?, at position: SIMD3<Float>) {
        self.target = target
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

        // The little resident swims around inside the bubble (added to the scene by the playground).
        if let kind {
            let critter = kind.make(color: kind.signatureColor, at: position)
            critter.sizeScale = 0.5
            resident = critter
            starfish = nil
        } else {
            let star = Starfish(at: position)
            star.sizeScale = 0.55
            resident = nil
            starfish = star
        }
    }

    /// The resident's scene node.
    var residentRoot: SCNNode { resident?.root ?? starfish!.root }

    private var signatureColor: SIMD3<Float> {
        resident.map { $0.kind.signatureColor } ?? SIMD3(1, 1, 1)
    }

    func bounce(_ strength: Float = 1) {
        squash.velocity += SIMD3(3, -5, 3) * strength
        resident?.react(.surprised, for: 0.5)
        starfish?.scrubbed()
    }

    /// - Parameters:
    ///   - rubProgress: 0…1 while a buddy is rubbing this bubble.
    ///   - selectedCount: how many buddies are this animal right now.
    ///   - color: the paint of a buddy that's this animal, if any (otherwise the animal's own color).
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
        let swim = SIMD3(sin(clock * 0.9) * 0.04, sin(clock * 1.3) * 0.03 - 0.02, 0.02)
        if let resident {
            let shown = color ?? signatureColor
            if simd_distance(shown, resident.color) > 0.01 { resident.setColor(shown) }
            resident.update(dt: dt, target: c + swim, visible: true, painting: false, beatPulse: beatPulse)
        }
        starfish?.update(dt: dt, target: c + swim, visible: true, beatPulse: beatPulse)
    }
}

// MARK: - A hand's buddy: brush animal ↔ starfish

enum BuddyMode: Equatable { case idle, swim, paint, erase }

/// What a buddy is rubbing: a paint pot (new color), a critter bubble (new brush animal),
/// a tool bubble (new paint tool) or a template bubble.
enum PotTarget: Equatable {
    case color(Int)
    case critter(CritterKind)
    case tool(PaintTool)
    case template(TemplateKind)
}

final class Buddy {
    let slot: Int
    private(set) var critter: Critter
    let starfish: Starfish
    private(set) var mode: BuddyMode = .idle
    private(set) var colorIndex: Int
    /// The paint tool in the fist controls (the legacy controls never pick the eraser, so it stays a brush).
    private(set) var tool: PaintTool = .brush
    /// The starfish is out instead of the brush animal: erasing, or holding the eraser tool.
    private(set) var showsStarfish = false
    var rubbingPot: PotTarget?
    var rubAmount: Float = 0

    /// The legacy scheme erases with the starfish; the garden scheme's eraser is a normal critter (the mushroom).
    let erasesWithStarfish: Bool

    init(slot: Int, colorIndex: Int, kind: CritterKind, start: SIMD3<Float>, tool: PaintTool = .brush,
         erasesWithStarfish: Bool = true) {
        self.erasesWithStarfish = erasesWithStarfish
        self.tool = tool
        self.slot = slot
        self.colorIndex = colorIndex
        critter = kind.make(color: Paint.colors[colorIndex % Paint.colors.count], at: start)
        starfish = Starfish(at: start)
    }

    /// Returns true when the buddy swapped between its animal and the starfish.
    @discardableResult
    func setMode(_ newMode: BuddyMode) -> Bool {
        guard newMode != mode else { return false }
        mode = newMode
        return updateStarfish()
    }

    /// Brings the starfish out (or back in) right where the other one was. True when it swapped.
    @discardableResult
    private func updateStarfish() -> Bool {
        let wanted = erasesWithStarfish && (mode == .erase || tool == .eraser)
        guard wanted != showsStarfish else { return false }
        if wanted {
            starfish.appear(at: critter.position.value)
        } else {
            critter.position = Spring3(starfish.position.value)
        }
        showsStarfish = wanted
        return true
    }

    var toolPosition: SIMD3<Float> {
        showsStarfish ? starfish.position.value : critter.position.value
    }

    var toolSpeed: Float { showsStarfish ? starfish.speed : critter.speed }

    /// How much paint the tool wipes away around itself.
    var eraseRadius: Float { showsStarfish ? Starfish.eraseRadius : critter.eraseRadius }

    /// The tool just wiped some paint away.
    func scrubbed() {
        if showsStarfish { starfish.scrubbed() } else { critter.scrubbed() }
    }

    /// Picks up another paint tool. Returns the brush animal it replaced, if any (to remove from the scene).
    func equip(_ newTool: PaintTool) -> Critter? {
        tool = newTool
        var old: Critter?
        if let kind = newTool.critterKind, kind != critter.kind {
            // A brush animal only has its own colours: bring along the current one if it fits, else its first.
            if let palette = Paint.palette(for: kind), !palette.contains(colorIndex) { colorIndex = palette[0] }
            old = become(kind)
            if showsStarfish { critter.position = Spring3(starfish.position.value) }
        }
        updateStarfish()
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
