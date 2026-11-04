import Foundation

/// The child at the easel, a small camera snapshot every so often while they paint, played back fast next to the
/// painting's own timelapse. Kept as JPEG frames in one file beside the painting, on the device only.
nonisolated struct CameraTimelapse: Equatable, Sendable {
    /// JPEG bytes, oldest first.
    var frames: [Data] = []

    static let formatVersion: UInt32 = 1
    private static let magic: [UInt8] = Array("PPCT".utf8)
    /// Playback speed.
    static let framesPerSecond: Double = 10

    var isEmpty: Bool { frames.isEmpty }

    init(frames: [Data] = []) { self.frames = frames }

    /// "PPCT", version, frame count, then each frame as length + bytes (all little-endian UInt32).
    func encoded() -> Data {
        var data = Data(Self.magic)
        func put(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        put(Self.formatVersion)
        put(UInt32(frames.count))
        for frame in frames {
            put(UInt32(frame.count))
            data.append(frame)
        }
        return data
    }

    /// Nil when the bytes are not a camera timelapse (or a newer format).
    init?(data: Data) {
        let bytes = [UInt8](data)
        var at = 0
        func take(_ n: Int) -> ArraySlice<UInt8>? {
            guard n >= 0, at + n <= bytes.count else { return nil }
            defer { at += n }
            return bytes[at..<(at + n)]
        }
        func number() -> UInt32? {
            guard let slice = take(4) else { return nil }
            return slice.reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        }
        guard let magic = take(4), Array(magic) == Self.magic,
              let version = number(), version == Self.formatVersion,
              let count = number() else { return nil }
        var frames: [Data] = []
        for _ in 0..<count {
            guard let length = number(), let frame = take(Int(length)) else { return nil }
            frames.append(Data(frame))
        }
        self.frames = frames
    }
}

/// Decides when to take the next snapshot and keeps the frame count bounded: when the buffer fills up, every other
/// frame is dropped and snapshots come half as often, so a long session still spans start to finish. Pure.
nonisolated struct CameraTimelapseBuffer: Sendable {
    static let maxFrames = 360
    private(set) var interval: Double
    private(set) var frames: [Data] = []
    private var lastShot: Double?

    init(interval: Double = 0.5) { self.interval = interval }

    func isDue(at time: Double) -> Bool {
        guard let lastShot else { return true }
        return time - lastShot >= interval
    }

    mutating func append(_ frame: Data, at time: Double) {
        lastShot = time
        frames.append(frame)
        if frames.count >= Self.maxFrames {
            frames = frames.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
            interval *= 2
        }
    }

    mutating func reset(interval: Double = 0.5) {
        self = CameraTimelapseBuffer(interval: interval)
    }
}
