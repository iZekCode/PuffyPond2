import Testing
@testable import PuffyPond

struct DistanceGateTests {
    private let good: Float = 0.17

    @Test func farThenNearReportsDirection() {
        var gate = DistanceGate()
        #expect(gate.update(shoulderWidth: 0.08, centerX: 0.5, at: 0) == .tooFar)
        #expect(gate.update(shoulderWidth: 0.30, centerX: 0.5, at: 0.1) == .tooClose)
        #expect(gate.update(shoulderWidth: good, centerX: 0.5, at: 0.2) == .holding(progress: 0))
    }

    @Test func offCenterIsReportedOnceTheDistanceIsRight() {
        var gate = DistanceGate()
        #expect(gate.update(shoulderWidth: good, centerX: 0.9, at: 0) == .offCenter)
        #expect(gate.update(shoulderWidth: good, centerX: 0.5, at: 0.1) == .holding(progress: 0))
    }

    @Test func noShouldersMeansNoPerson() {
        var gate = DistanceGate()
        #expect(gate.update(shoulderWidth: nil, centerX: nil, at: 0) == .noPerson)
    }

    @Test func readyAfterHoldOnly() {
        var gate = DistanceGate()
        var state = gate.update(shoulderWidth: good, centerX: 0.5, at: 0)
        for step in 1...14 {
            state = gate.update(shoulderWidth: good, centerX: 0.5, at: Double(step) * 0.1)
            #expect(state != .ready, "ready too early at \(Double(step) * 0.1) s")
        }
        guard case let .holding(progress) = state else {
            Issue.record("expected holding, got \(state)")
            return
        }
        #expect(abs(progress - 1.4 / DistanceGate.holdDuration) < 0.001)
        #expect(gate.update(shoulderWidth: good, centerX: 0.5, at: 1.5) == .ready)
    }

    @Test func leavingTheBandRestartsTheHold() {
        var gate = DistanceGate()
        _ = gate.update(shoulderWidth: good, centerX: 0.5, at: 0)
        _ = gate.update(shoulderWidth: good, centerX: 0.5, at: 1.0)
        #expect(gate.update(shoulderWidth: 0.30, centerX: 0.5, at: 1.1) == .tooClose)
        #expect(gate.update(shoulderWidth: good, centerX: 0.5, at: 1.2) == .holding(progress: 0))
        #expect(gate.update(shoulderWidth: good, centerX: 0.5, at: 1.6) != .ready)
    }

    @Test func briefDropoutDoesNotReset() {
        var gate = DistanceGate()
        _ = gate.update(shoulderWidth: good, centerX: 0.5, at: 0)
        _ = gate.update(shoulderWidth: good, centerX: 0.5, at: 1.0)
        // 0.25 s with nobody detected: the hold carries on.
        _ = gate.update(shoulderWidth: nil, centerX: nil, at: 1.1)
        _ = gate.update(shoulderWidth: nil, centerX: nil, at: 1.25)
        #expect(gate.update(shoulderWidth: good, centerX: 0.5, at: 1.5) == .ready)
    }

    @Test func longDropoutResets() {
        var gate = DistanceGate()
        _ = gate.update(shoulderWidth: good, centerX: 0.5, at: 0)
        _ = gate.update(shoulderWidth: good, centerX: 0.5, at: 1.0)
        #expect(gate.update(shoulderWidth: nil, centerX: nil, at: 1.5) == .noPerson)
        #expect(gate.update(shoulderWidth: good, centerX: 0.5, at: 1.6) == .holding(progress: 0))
    }
}
