import SceneKit
import simd

// MARK: - Waiting characters (rub your buddy over one to become it)

/// One of the four characters floating along the bottom of the canvas. No bubble: just the character, fast asleep
/// (still, eyes closed, muted) until a buddy comes near, and a progress ring around it while a buddy rubs over it.
final class CharacterPerch {
    let root = SCNNode()
    let tool: PaintTool
    let resident: Critter
    private let progressRing: SCNNode
    private var ringScale = Spring1(0)
    private var awake = Spring1(0)
    private var squash = Spring3(SIMD3(1, 1, 1))
    private var clock: Float = 0

    init(tool: PaintTool, at position: SIMD3<Float>) {
        self.tool = tool
        root.simdPosition = position

        let ringMaterial = SCNMaterial()
        ringMaterial.lightingModel = .constant
        ringMaterial.diffuse.contents = PlatformColor.white
        let radius = CanvasLayout.characterRadius
        progressRing = SCNNode(geometry: SCNTorus(ringRadius: CGFloat(radius), pipeRadius: 0.024))
        progressRing.geometry?.materials = [ringMaterial]
        progressRing.simdEulerAngles = SIMD3(Float.pi / 2, 0, 0)
        progressRing.simdScale = SIMD3(repeating: 0.001)
        root.addChildNode(progressRing)

        resident = tool.critterKind.make(color: tool.color, at: position)
        resident.sizeScale = CanvasLayout.characterScale
    }

    /// The resident's scene node (the playground adds it to the scene).
    var residentRoot: SCNNode { resident.root }

    func bounce(_ strength: Float = 1) {
        squash.velocity += SIMD3(3, -5, 3) * strength
        resident.react(.surprised, for: 0.5)
    }

    /// - Parameters:
    ///   - rubProgress: 0…1 while a buddy is rubbing over this character.
    ///   - buddyDistance: how far the nearest buddy is (canvas plane); it wakes up when one comes close.
    func update(dt: Float, beatPulse: Float, rubProgress: Float, buddyDistance: Float) {
        clock += dt
        awake.step(to: buddyDistance < CanvasLayout.characterWakeRadius || rubProgress > 0 ? 1 : 0,
                   stiffness: 50, damping: 11, dt: dt)
        resident.sleepiness = 1 - min(max(awake.value, 0), 1)
        ringScale.step(to: rubProgress > 0 ? 0.35 + rubProgress * 0.65 : 0, stiffness: 300, damping: 18, dt: dt)
        progressRing.simdScale = SIMD3(repeating: max(ringScale.value, 0.001))
        progressRing.simdEulerAngles = SIMD3(Float.pi / 2, clock * 3, 0)

        squash.step(to: SIMD3(1, 1, 1), stiffness: 260, damping: 9, dt: dt)
        let c = root.simdPosition
        let wake = 1 - resident.sleepiness
        let drift = SIMD3(sin(clock * 0.9 + Float(tool.rawValue)) * 0.04 * wake, sin(clock * 1.3 + Float(tool.rawValue)) * 0.03 * wake, 0.02)
        resident.update(dt: dt, target: c + drift, visible: true, painting: false, beatPulse: beatPulse)
    }
}

// MARK: - A hand's buddy

final class Buddy {
    let slot: Int
    private(set) var critter: Critter
    private(set) var mode: BuddyMode = .idle
    private(set) var tool: PaintTool
    var rubbingTool: PaintTool?
    var rubAmount: Float = 0

    init(slot: Int, tool: PaintTool, start: SIMD3<Float>) {
        self.slot = slot
        self.tool = tool
        critter = tool.critterKind.make(color: tool.color, at: start)
    }

    func setMode(_ newMode: BuddyMode) {
        mode = newMode
    }

    var toolPosition: SIMD3<Float> { critter.position.value }

    var toolSpeed: Float { critter.speed }

    /// Its character's one colour.
    var color: SIMD3<Float> { tool.color }
    var colorIndex: Int { tool.colorIndex }

    /// Turns into another character right where it is. Returns the old one (to remove from the scene).
    func equip(_ newTool: PaintTool) -> Critter? {
        guard newTool != tool else { return nil }
        tool = newTool
        let old = critter
        critter = newTool.critterKind.make(color: newTool.color, at: old.position.value)
        critter.react(.surprised, for: 0.6)
        return old
    }
}
