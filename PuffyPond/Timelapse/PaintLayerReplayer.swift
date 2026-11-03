import SceneKit
import simd

/// The literal timelapse: the recorded dabs are laid again, in order, on a paint layer of its own (never the
/// easel's), so every colour is what the paint looked like at that moment: a stroke is not blended until the
/// blender actually passes over it. The simulation runs at the original frame time and takes as many steps per
/// displayed frame as the replay's speed-up needs, on a small layer to keep that affordable.
final class PaintLayerReplayer: ReplayRenderer {
    /// The easel's frame time, which the paint simulation was tuned and recorded at.
    private static let frameTime = 1.0 / 60
    /// Frames simulated after the last dab so wet paint settles before the sheet takes over.
    private static let settleFrames = 120
    /// The easel is photographed through a tone-mapped HDR camera with a lowered exposure; the review scene is not, so
    /// the same lights come out brighter. This scale brings the replay's paint to the saved photo's brightness
    /// (fitted on four paint colours against a copy of the photo booth, see `PaintLayerReplayerTests`).
    private static let lightScale: CGFloat = 0.7
    /// Lights and paint share this category so the review scene's own lights leave the replay alone.
    private static let category = 2

    let node = SCNNode()

    private let layer: PaintLayer
    private let events: [RecordedEvent]
    private let timeline: ReplayTimeline
    private var next = 0
    private var recordedCursor = 0.0
    private var settled = false

    /// How many texels across the replay's paint layer is, by how much the replay is sped up: a long session takes
    /// many simulation steps per displayed frame, so it gets a smaller layer. (Measured on an M5 Mac: a layer 768
    /// across costs about 3 ms per frame for a 30 s session; 384 across about 10 ms for a 5 minute one.)
    static func resolution(forSpeedUp speedUp: Double) -> Int {
        switch speedUp {
        case ...2: 768
        case ...5: 512
        case ...14: 384
        default: 256
        }
    }

    /// Nil when the paint layer cannot run (no Metal): the caller shows a simpler replay instead.
    init?(recording: StrokeRecording, timeline: ReplayTimeline) {
        events = recording.events
        self.timeline = timeline
        // The layer sits where the easel's does; the wrapper moves the canvas centre to the sheet's origin.
        layer = PaintLayer(center: SIMD2(0, 0.1), size: Playground.canvasSize, z: 0,
                           pixelsAcross: Self.resolution(forSpeedUp: timeline.speedUp))
        guard layer.isAvailable else { return nil }
        let canvas = SCNNode()
        canvas.simdPosition = SIMD3(0, -0.1, 0)
        canvas.addChildNode(layer.node)

        let key = SCNLight()
        key.type = .spot
        key.intensity = Playground.keyIntensity * Self.lightScale
        key.spotInnerAngle = Playground.keyInnerAngle
        key.spotOuterAngle = Playground.keyOuterAngle
        key.attenuationStartDistance = 4
        key.attenuationEndDistance = 40
        key.attenuationFalloffExponent = 0
        key.categoryBitMask = Self.category
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.simdPosition = Playground.keyPosition
        keyNode.simdLook(at: Playground.keyTarget)
        canvas.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .ambient
        fill.intensity = Playground.fillIntensity * Self.lightScale
        fill.categoryBitMask = Self.category
        let fillNode = SCNNode()
        fillNode.light = fill
        canvas.addChildNode(fillNode)

        node.addChildNode(canvas)
        node.enumerateHierarchy { child, _ in child.categoryBitMask = Self.category }
    }

    func prepare(scene: SCNScene) {
        scene.lightingEnvironment.contents = Studio.environment()
        scene.lightingEnvironment.intensity = Playground.environmentIntensity * Self.lightScale
    }

    func advance(to replayTime: Double) {
        guard !events.isEmpty else { return }
        let target = timeline.recordedTime(forReplay: replayTime)
        while recordedCursor <= target {
            let frameEnd = recordedCursor + Self.frameTime
            while next < events.count, events[next].t < frameEnd {
                issue(events[next])
                next += 1
            }
            layer.update(dt: Float(Self.frameTime))
            recordedCursor = frameEnd
        }
        if replayTime >= timeline.duration, !settled {
            settled = true
            for _ in 0..<Self.settleFrames { layer.update(dt: Float(Self.frameTime)) }
        }
    }

    func reset() {
        layer.clear()
        next = 0
        recordedCursor = 0
        settled = false
    }

    private func issue(_ event: RecordedEvent) {
        switch event {
        case .dab(let d):
            layer.stamp(from: d.from, to: d.to, radius: d.radius, color: d.color, speed: d.speed, seed: d.seed,
                        style: d.style, drag: d.drag, strokeSeed: d.strokeSeed, ncaModel: d.ncaModel)
        case .erase(let e):
            layer.erase(at: e.center, radius: e.radius, dt: e.dt)
        }
    }
}
