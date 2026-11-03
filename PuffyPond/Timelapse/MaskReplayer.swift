import CoreGraphics
import SceneKit

/// The timelapse as a reveal: the saved paint image shows through a mask that fills in along the recorded strokes.
/// It always ends identical to the saved painting. Blender dabs and erases are ignored: the saved paint already has
/// their result.
final class MaskReplayer: ReplayRenderer {
    let node = SCNNode()
    let mask = RevealMask()

    private let events: [(time: Double, dab: RecordedDab)]
    private let maskProperty = SCNMaterialProperty()
    private var next = 0

    init(finalPaint: CGImage, recording: StrokeRecording, timeline: ReplayTimeline) {
        events = recording.events.compactMap { event in
            guard case .dab(let dab) = event, dab.style.blend <= 0.5 else { return nil }
            return (timeline.replayTime(forRecorded: dab.t), dab)
        }

        let material = SCNMaterial()
        material.diffuse.contents = finalPaint
        material.lightingModel = .lambert
        material.isDoubleSided = true
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        material.diffuse.mipFilter = .linear
        material.transparencyMode = .aOne
        material.blendMode = .alpha
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = false
        // The picture shows only where the mask is white.
        material.shaderModifiers = [.fragment: """
            #pragma arguments
            sampler2D reveal;
            #pragma body
            _output.color *= texture2D(reveal, _surface.diffuseTexcoord).r;
            """]
        maskProperty.contents = mask.image
        material.setValue(maskProperty, forKey: "reveal")

        let plane = SCNPlane(width: CGFloat(SheetSolver.size.x), height: CGFloat(SheetSolver.size.y))
        plane.materials = [material]
        node.geometry = plane
        node.renderingOrder = 5
    }

    func advance(to replayTime: Double) {
        var changed = false
        while next < events.count, events[next].time <= replayTime {
            mask.reveal(events[next].dab)
            next += 1
            changed = true
        }
        if changed { maskProperty.contents = mask.image }
    }

    func reset() {
        next = 0
        mask.clear()
        maskProperty.contents = mask.image
    }
}
