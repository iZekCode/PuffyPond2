import SceneKit

/// Draws the timelapse of one painting on the review page's canvas.
protocol ReplayRenderer: AnyObject {
    /// Added to the review scene, laid out in sheet space (centred on 0,0, `SheetSolver.size` wide), in front of
    /// the bare canvas.
    var node: SCNNode { get }
    /// Shows the painting as it was `replayTime` replay seconds in. Later calls only move forward until `reset()`.
    func advance(to replayTime: Double)
    func reset()
    /// Called once with the review scene when the renderer is added to it (lighting environment and the like).
    func prepare(scene: SCNScene)
}

extension ReplayRenderer {
    func prepare(scene: SCNScene) {}
}
