nonisolated enum CameraStatus: Equatable { case starting, running, denied, unavailable }

nonisolated enum Hint: Equatable {
    case starting, raiseHands, roaming, pickingColor, drawing, erasing, readyToHang, tracing, touchMode

    /// The hint bubble for this frame: what the hands are doing first, then what is on the canvas, then the camera.
    static func pick(erasing: Bool, drawing: Bool, rubbing: Bool, hasStrokes: Bool, hasTemplate: Bool,
                     cameraHandsTracking: Bool, cameraStatus: CameraStatus) -> Hint {
        if erasing { return .erasing }
        if drawing { return .drawing }
        if rubbing { return .pickingColor }
        if hasStrokes { return .readyToHang }
        if hasTemplate { return .tracing }
        if cameraHandsTracking { return .roaming }
        switch cameraStatus {
        case .denied, .unavailable: return .touchMode
        case .starting: return .starting
        case .running: return .raiseHands
        }
    }
}

/// "You picked a color" moment for the HUD.
nonisolated struct ColorFlash: Equatable {
    let slot: Int
    let colorIndex: Int
    let id: Int
}
