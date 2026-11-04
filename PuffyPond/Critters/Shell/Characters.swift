import SceneKit
import simd

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
