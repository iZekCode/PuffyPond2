import Testing
@testable import PuffyPond

@MainActor
struct HintTests {
    private func pick(erasing: Bool = false, drawing: Bool = false, rubbing: Bool = false, hasStrokes: Bool = false,
                      hasTemplate: Bool = false, hands: Bool = false, camera: CameraStatus = .running) -> Hint {
        Hint.pick(erasing: erasing, drawing: drawing, rubbing: rubbing, hasStrokes: hasStrokes,
                  hasTemplate: hasTemplate, cameraHandsTracking: hands, cameraStatus: camera)
    }

    @Test func whatTheHandsDoComesFirst() {
        #expect(pick(erasing: true, drawing: true, rubbing: true, hasStrokes: true) == .erasing)
        #expect(pick(drawing: true, rubbing: true, hasStrokes: true) == .drawing)
        #expect(pick(rubbing: true, hasStrokes: true) == .pickingColor)
    }

    @Test func thenWhatIsOnTheCanvas() {
        #expect(pick(hasStrokes: true, hasTemplate: true, hands: true) == .readyToHang)
        #expect(pick(hasTemplate: true, hands: true) == .tracing)
        #expect(pick(hands: true) == .roaming)
    }

    @Test func thenTheCamera() {
        #expect(pick(camera: .running) == .raiseHands)
        #expect(pick(camera: .starting) == .starting)
        #expect(pick(camera: .denied) == .touchMode)
        #expect(pick(camera: .unavailable) == .touchMode)
    }

    @Test func frameTimeIsClamped() {
        #expect(abs(FrameTiming.clampedDT(0) - 1 / 240) < 1e-7)
        #expect(abs(FrameTiming.clampedDT(1) - 1 / 20) < 1e-7)
        #expect(abs(FrameTiming.clampedDT(1 / 60) - 1 / 60) < 1e-7)
    }

    @Test func beatPulsePeaksOnTheBeat() {
        #expect(FrameTiming.beatPulse(beat: 3) == 1)
        #expect(FrameTiming.beatPulse(beat: 3.5) < FrameTiming.beatPulse(beat: 3.1))
    }

    @Test func energyEasesTowardMovement() {
        let next = FrameTiming.energy(0, movement: 3, dt: 0.1)
        #expect(next > 0 && next < 1)
        #expect(FrameTiming.energy(0.5, movement: 30, dt: 10) == 1)
    }
}
