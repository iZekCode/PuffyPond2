import CoreImage
import CoreVideo
import Foundation
import ImageIO
import os

/// Takes the camera snapshots for the camera timelapse. The camera queue offers every frame; while recording, one
/// every `interval` is shrunk and kept as a JPEG. Everything stays in memory until the painting is saved.
nonisolated final class CameraTimelapseRecorder: @unchecked Sendable {
    /// Long side of a kept frame, in pixels: small, it is a keepsake, not a video.
    static let maxSide: CGFloat = 360

    private let state = OSAllocatedUnfairLock(initialState: (recording: false, buffer: CameraTimelapseBuffer()))
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    /// On while the canvas page shows; off on every other page (the frames so far are kept).
    var isRecording: Bool {
        get { state.withLock { $0.recording } }
        set { state.withLock { $0.recording = newValue } }
    }

    /// A new drawing session: forget the frames so far.
    func reset() { state.withLock { $0.buffer.reset() } }

    /// What was recorded so far; nil when nothing was.
    func snapshot() -> CameraTimelapse? {
        let frames = state.withLock { $0.buffer.frames }
        return frames.isEmpty ? nil : CameraTimelapse(frames: frames)
    }

    /// Called on the camera queue with every frame (upright and mirrored like the preview).
    func offer(_ pixelBuffer: CVPixelBuffer, at time: Double) {
        let due = state.withLock { $0.recording && $0.buffer.isDue(at: time) }
        guard due else { return }
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        let side = max(image.extent.width, image.extent.height)
        if side > Self.maxSide {
            let s = Self.maxSide / side
            image = image.transformed(by: CGAffineTransform(scaleX: s, y: s))
        }
        guard let jpeg = context.jpegRepresentation(of: image, colorSpace: colorSpace,
                                                    options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.6])
        else { return }
        state.withLock { $0.buffer.append(jpeg, at: time) }
    }
}
