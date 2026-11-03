import CoreGraphics
import SceneKit
import Testing
import simd
@testable import PuffyPond

@MainActor
struct ReviewStagePhaseTests {
    private final class StubRenderer: ReplayRenderer {
        let node = SCNNode()
        private(set) var advances = 0
        private(set) var resets = 0
        func advance(to replayTime: Double) { advances += 1 }
        func reset() { resets += 1 }
    }

    private func image(side: Int = 4) -> CGImage {
        CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            .makeImage()!
    }

    private func photos() -> CanvasPhotos { CanvasPhotos(whole: image(), canvas: image(), paint: image()) }

    private func recording(seconds: Int) -> StrokeRecording {
        StrokeRecording(events: (0...seconds).map { second in
            .dab(RecordedDab(t: Double(second), from: .zero, to: SIMD2(0.1, 0), radius: 0.1, speed: 1,
                             color: SIMD3(1, 0, 0), seed: 0, strokeSeed: 0, style: .brush, drag: nil, ncaModel: 0,
                             brush: .butterfly))
        })
    }

    private func stage(with recording: StrokeRecording?, renderer: StubRenderer = StubRenderer()) -> ReviewStage {
        let stage = ReviewStage()
        stage.makeRenderer = { _, _, _ in renderer }
        stage.show(photos(), recording: recording, audio: GrooveEngine())
        return stage
    }

    /// Runs the page's clock until the timelapse is over (or gives up).
    private func runOut(_ stage: ReviewStage) {
        var guardCount = 0
        while stage.phase == .timelapse, guardCount < 100 {
            stage.advanceTimelapse(dt: 1)
            guardCount += 1
        }
    }

    @Test func recordingStartsTheTimelapse() {
        let stage = stage(with: recording(seconds: 4))
        #expect(stage.phase == .timelapse)
        #expect(stage.canReplay)
    }

    @Test func noRecordingIsInteractiveAtOnce() {
        let stage = stage(with: nil)
        #expect(stage.phase == .interactive)
        #expect(!stage.canReplay)
        stage.replay()
        #expect(stage.phase == .interactive)
    }

    @Test func emptyAndSingleEventRecordingsAreInteractive() {
        for recording in [StrokeRecording(), self.recording(seconds: 0)] {
            let stage = stage(with: recording)
            #expect(stage.phase == .interactive)
            #expect(!stage.canReplay)
        }
    }

    @Test func timelapseEndsByItself() {
        let stage = stage(with: recording(seconds: 4))
        runOut(stage)
        #expect(stage.phase == .interactive)
    }

    @Test func skipFinishesAndIsIdempotent() {
        let stage = stage(with: recording(seconds: 4))
        stage.skipTimelapse()
        stage.skipTimelapse()
        #expect(stage.phase == .interactive)
    }

    @Test func replayRestarts() {
        let renderer = StubRenderer()
        let stage = stage(with: recording(seconds: 4), renderer: renderer)
        runOut(stage)
        let resetsBefore = renderer.resets
        stage.replay()
        #expect(stage.phase == .timelapse)
        stage.replay()
        #expect(stage.phase == .timelapse)
        #expect(renderer.resets == resetsBefore + 1)
    }

    @Test func leavingStopsTheTimelapse() {
        let renderer = StubRenderer()
        let stage = stage(with: recording(seconds: 4), renderer: renderer)
        stage.advanceTimelapse(dt: 1)
        stage.stop()
        let advances = renderer.advances
        stage.advanceTimelapse(dt: 1)
        stage.advanceTimelapse(dt: 1)
        #expect(renderer.advances == advances)
    }
}
