import Foundation
import Testing
@testable import PuffyPond

struct CameraTimelapseTests {
    @Test func survivesASaveAndLoad() {
        let timelapse = CameraTimelapse(frames: [Data([1, 2, 3]), Data(), Data(repeating: 7, count: 500)])
        #expect(CameraTimelapse(data: timelapse.encoded()) == timelapse)
    }

    @Test func rejectsOtherFiles() {
        #expect(CameraTimelapse(data: Data("hello".utf8)) == nil)
        var cut = CameraTimelapse(frames: [Data(repeating: 1, count: 20)]).encoded()
        cut.removeLast(5)
        #expect(CameraTimelapse(data: cut) == nil)
    }

    @Test func snapshotsComeEveryInterval() {
        var buffer = CameraTimelapseBuffer(interval: 0.5)
        #expect(buffer.isDue(at: 10))
        buffer.append(Data([0]), at: 10)
        #expect(!buffer.isDue(at: 10.3))
        #expect(buffer.isDue(at: 10.5))
    }

    @Test func longSessionsStayBoundedAndSpanTheWholeTime() {
        var buffer = CameraTimelapseBuffer(interval: 0.5)
        var time = 0.0
        for k in 0..<2000 {
            if buffer.isDue(at: time) { buffer.append(Data([UInt8(k % 256)]), at: time) }
            time += 0.1
        }
        #expect(buffer.frames.count < CameraTimelapseBuffer.maxFrames)
        #expect(buffer.interval > 0.5)
        #expect(buffer.frames.first == Data([0]))   // the start is still there
    }
}
