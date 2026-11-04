import SceneKit
import simd

/// The arrow lying on the canvas that bobs along the dotted outline to show where the brush goes next.
final class GuideArrow {
    let node = SCNNode()
    private let z: Float
    private var position = SIMD2<Float>.zero
    private var heading: Float = 0
    private var targetPosition = SIMD2<Float>.zero
    private var targetHeading: Float = 0
    private var placed = false

    init(z: Float) {
        self.z = z

        let plane = SCNPlane(width: 0.62, height: 0.62)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = Toybox.platformImage(Self.image())
        material.transparencyMode = .aOne
        material.writesToDepthBuffer = false
        material.isDoubleSided = true
        plane.materials = [material]

        let arrow = SCNNode(geometry: plane)
        arrow.castsShadow = false
        arrow.renderingOrder = 100
        // Bobs forward along its heading, so it is clear which way to go.
        let forward = SCNAction.moveBy(x: 0.16, y: 0, z: 0, duration: 0.45)
        forward.timingMode = .easeInEaseOut
        let back = forward.reversed()
        back.timingMode = .easeInEaseOut
        arrow.runAction(.repeatForever(.sequence([forward, back])))

        node.addChildNode(arrow)
        node.simdPosition = SIMD3(0, 0, z)
        node.opacity = 0
        node.runAction(.fadeIn(duration: 0.4))
    }

    /// Where to sit and which way to point (radians, 0 = right, counter-clockwise). It glides there in `update`.
    func move(to point: SIMD2<Float>, heading newHeading: Float) {
        targetPosition = point
        targetHeading = newHeading
        if !placed {
            placed = true
            position = point
            heading = newHeading
        }
    }

    func update(dt: Float) {
        let k = min(1, dt * 10)
        position += (targetPosition - position) * k
        var delta = targetHeading - heading
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        heading += delta * k
        node.simdPosition = SIMD3(position.x, position.y, z)
        node.simdEulerAngles = SIMD3(0, 0, heading)
    }

    /// The outline is finished: the arrow has nothing left to point at.
    func hide() {
        node.runAction(.fadeOut(duration: 0.3))
    }

    func fadeAway() {
        node.runAction(.sequence([.fadeOut(duration: 0.3), .removeFromParentNode()]))
    }

    /// A chunky orange arrow with a white edge, pointing right.
    private static func image() -> CGImage? {
        let side = 192
        return Toybox.image(width: side, height: side) { ctx in
            let u = CGFloat(side)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0.10 * u, y: 0.36 * u))
            path.addLine(to: CGPoint(x: 0.55 * u, y: 0.36 * u))
            path.addLine(to: CGPoint(x: 0.55 * u, y: 0.16 * u))
            path.addLine(to: CGPoint(x: 0.92 * u, y: 0.50 * u))
            path.addLine(to: CGPoint(x: 0.55 * u, y: 0.84 * u))
            path.addLine(to: CGPoint(x: 0.55 * u, y: 0.64 * u))
            path.addLine(to: CGPoint(x: 0.10 * u, y: 0.64 * u))
            path.closeSubpath()
            ctx.setLineJoin(.round)
            ctx.addPath(path)
            ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.setLineWidth(0.09 * u)
            ctx.strokePath()
            ctx.addPath(path)
            ctx.setFillColor(CGColor(red: 1, green: 0.55, blue: 0.2, alpha: 1))
            ctx.fillPath()
        }
    }
}
