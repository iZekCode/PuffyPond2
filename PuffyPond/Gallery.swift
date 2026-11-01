import SwiftUI
import SceneKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Observation
import simd

// MARK: - Saved paintings

struct Painting: Identifiable, Equatable {
    let url: URL
    let record: PaintingRecord
    var id: URL { url }
    var date: Date { record.date }

    /// The JSON file with the record, next to the PNG.
    var sidecarURL: URL { Self.sidecarURL(for: url) }

    static func sidecarURL(for png: URL) -> URL {
        png.deletingPathExtension().appendingPathExtension("json")
    }
}

/// Finished paintings, kept as PNGs on the device (newest first), each with a JSON record beside it.
@Observable
final class Gallery {
    private(set) var paintings: [Painting] = []
    @ObservationIgnored private let folder: URL

    init(folder: URL? = nil) {
        if let folder {
            self.folder = folder
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.folder = base.appendingPathComponent("Gallery", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
        reload()
    }

    private func reload() {
        let keys: [URLResourceKey] = [.creationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
        paintings = files
            .filter { $0.pathExtension == "png" }
            .map { url in
                let sidecar = Painting.sidecarURL(for: url)
                if let data = try? Data(contentsOf: sidecar),
                   let record = try? JSONDecoder().decode(PaintingRecord.self, from: data) {
                    return Painting(url: url, record: record)
                }
                // A PNG from before records existed (or a broken sidecar): keep its date, write an empty record.
                let created = (try? url.resourceValues(forKeys: Set(keys)).creationDate) ?? .distantPast
                let record = PaintingRecord(date: created)
                Self.write(record, to: sidecar)
                return Painting(url: url, record: record)
            }
            .sorted { $0.date > $1.date }
    }

    private static func write(_ record: PaintingRecord, to url: URL) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Hangs a new painting at the front of the gallery.
    @discardableResult
    func add(_ image: CGImage, record: PaintingRecord = PaintingRecord(date: Date())) -> Painting? {
        let url = folder.appendingPathComponent("painting-\(Int(record.date.timeIntervalSince1970 * 1000)).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        Self.write(record, to: Painting.sidecarURL(for: url))
        let painting = Painting(url: url, record: record)
        paintings.append(painting)
        paintings.sort { $0.date > $1.date }
        return painting
    }

    func remove(_ painting: Painting) {
        try? FileManager.default.removeItem(at: painting.url)
        try? FileManager.default.removeItem(at: painting.sidecarURL)
        paintings.removeAll { $0 == painting }
    }

    // MARK: Queries

    /// Paintings made on the given local day, newest first.
    func paintings(on day: Date, calendar: Calendar = .current) -> [Painting] {
        paintings.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// The local days (as start-of-day dates) in the month of `month` that have at least one painting.
    func daysWithPaintings(in month: Date, calendar: Calendar = .current) -> Set<Date> {
        Set(paintings
            .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            .map { calendar.startOfDay(for: $0.date) })
    }

    /// Ids of the templates that have at least one saved painting.
    var savedTemplateIDs: Set<String> {
        Set(paintings.compactMap(\.record.templateID))
    }

    /// Reads a saved PNG, scaled down to fit `maxPixels` on its long side when given. Safe off the main thread.
    nonisolated static func loadImage(at url: URL, maxPixels: Int? = nil) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let maxPixels else { return CGImageSourceCreateImageAtIndex(source, 0, nil) }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: maxPixels,
                                        kCGImageSourceCreateThumbnailWithTransform: true]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func image(of painting: Painting) -> PlatformImage? {
        #if os(macOS)
        return NSImage(contentsOf: painting.url)
        #else
        return UIImage(contentsOfFile: painting.url.path)
        #endif
    }
}

extension PlatformImage {
    var cgImageValue: CGImage? {
        #if os(macOS)
        return cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return cgImage
        #endif
    }
}

// MARK: - The museum hall

/// A quiet museum walk: every painting hangs in a white frame on its own grey partition, the partitions
/// stand in one long row with a lamp over each, and the camera walks along the row on a rail. The brush
/// animals tag along at the bottom and cheer a fresh painting. Open-hand paddle strokes in front of the
/// camera walk to the next or previous painting.
@Observable
final class GalleryHall {
    /// One hand as drawn on top of the page, in view UV (0…1, y down).
    struct Cursor: Equatable, Identifiable {
        var slot: Int
        var position: SIMD2<Float>
        var fist: Bool
        var id: Int { slot }
    }

    /// How sharp a hung painting's texture is; far ones get a thumbnail or nothing, to keep memory down.
    private enum Detail: Int {
        case none, thumbnail, full
    }

    private struct Slot {
        let url: URL
        let center: SIMD3<Float>
        let material: SCNMaterial
        var detail = Detail.none
        /// Bumped on each texture request, so a slow load can't overwrite a newer one.
        var generation = 0
    }

    /// Camera hands on screen, for the small hand indicators.
    private(set) var cursors: [Cursor] = []
    /// Called on a paddle stroke.
    @ObservationIgnored var onPaddle: ((PaddleDetector.Stroke) -> Void)?

    @ObservationIgnored let scene = SCNScene()
    @ObservationIgnored let cameraNode = SCNNode()
    @ObservationIgnored private let row = SCNNode()
    @ObservationIgnored private let rig = SCNNode()
    @ObservationIgnored private var slots: [Slot] = []
    @ObservationIgnored private var visitors: [(critter: Critter, home: SIMD3<Float>)] = []
    @ObservationIgnored private let frameDriver = FrameDriver()
    @ObservationIgnored private let hands = HandInput()
    @ObservationIgnored private var paddle = PaddleDetector()
    @ObservationIgnored private var clock: Float = 0
    @ObservationIgnored private let tanHalfFOV = Float(tan(17.0 * Double.pi / 180))
    @ObservationIgnored private var cameraDistance: Float = 9.2
    @ObservationIgnored private var focused = 0
    // The walk along the rail: from, to, seconds so far, seconds in all.
    @ObservationIgnored private var railX: Float = 0
    @ObservationIgnored private var walkFrom: Float = 0
    @ObservationIgnored private var walkTo: Float = 0
    @ObservationIgnored private var walkTime: Float = 0
    @ObservationIgnored private var walkDuration: Float = 0
    @ObservationIgnored private var bob: Float = 0

    private static let cameraY: Float = 0.15
    private static let visitorZ: Float = 2.6
    /// Distance between neighbouring paintings along the row.
    static let spacing: Float = 6
    static let walkDuration: Float = 1.2
    /// Paintings this close to the one in front of the camera get the full image; up to `thumbnailReach`
    /// a small one; the rest stay blank until the camera comes near.
    static let fullReach = 1
    static let thumbnailReach = 4
    static let thumbnailPixels = 384

    /// The painting keeps the easel canvas's shape.
    static let artSize = SIMD2<Float>(4.2, 4.2 * Playground.canvasSize.y / Playground.canvasSize.x)
    static let artY: Float = 0.55

    init() {
        build()
        frameDriver.onFrame = { [weak self] dt in self?.tick(dt: Float(dt)) }
    }

    func start() { frameDriver.start() }

    func stop() {
        frameDriver.stop()
        hands.reset()
        paddle.reset()
        cursors = []
    }

    func ingest(_ frame: HandFrame) { hands.ingest(frame) }

    /// Keeps the framed painting and the row of visitors in view for any screen shape; the visitors
    /// stand along the bottom edge, cut off a little like people in front of you at a museum.
    func layout(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let aspect = Float(size.width / size.height)
        let needHalfW: Float = 3.1
        let needHalfH: Float = 2.75
        cameraDistance = max(needHalfH / tanHalfFOV, needHalfW / (tanHalfFOV * aspect))
        placeCamera()
        let halfH = (cameraDistance - Self.visitorZ) * tanHalfFOV
        let halfW = halfH * aspect
        let bottom = Self.cameraY - halfH
        let spacing = min(1.05, halfW * 2 / Float(visitors.count))
        for k in visitors.indices {
            let x = (Float(k) - Float(visitors.count - 1) / 2) * spacing
            visitors[k].home = SIMD3(x, bottom + 0.5 + (k % 2 == 0 ? 0 : 0.08), Self.visitorZ)
            visitors[k].critter.gazeBias = SIMD2(-x * 0.12, 0.55)
        }
    }

    /// Hangs these paintings (newest first) along the row, replacing what hung before.
    func hang(_ urls: [URL]) {
        row.childNodes.forEach { $0.removeFromParentNode() }
        slots = urls.enumerated().map { k, url in
            let x = Float(k) * Self.spacing
            let material = Self.canvasMaterial()
            row.addChildNode(Self.partition(at: x, canvas: material))
            return Slot(url: url, center: SIMD3(x, Self.artY, 0), material: material)
        }
        focused = min(focused, max(slots.count - 1, 0))
        loadTextures()
    }

    /// Walks to stand in front of painting `index`; jumps there without walking when not animated.
    func focus(_ index: Int, animated: Bool = true) {
        guard slots.indices.contains(index) else { return }
        let steps = abs(index - focused)
        focused = index
        walkFrom = railX
        walkTo = Float(index) * Self.spacing
        walkTime = 0
        // Longer jumps (from the 2D list) walk a little longer, not proportionally longer.
        walkDuration = animated && steps > 0 ? min(Self.walkDuration + 0.15 * Float(steps - 1), 2.4) : 0
        if walkDuration == 0 { railX = walkTo; bob = 0; placeCamera() }
        loadTextures()
    }

    /// The visitors cheer the painting in front of them, with confetti.
    func cheer() {
        for (k, visitor) in visitors.enumerated() {
            visitor.critter.squash.velocity += SIMD3(-2, 3, 0)
            visitor.critter.react(.happy, for: 1.6 + Float(k) * 0.1)
        }
        guard slots.indices.contains(focused) else { return }
        let art = slots[focused].center
        Toybox.confetti(in: scene, at: SIMD3(art.x, art.y + Self.artSize.y * 0.5, 0.6))
    }

    // MARK: - Textures

    private func wantedDetail(_ index: Int) -> Detail {
        let distance = abs(index - focused)
        if distance <= Self.fullReach { return .full }
        return distance <= Self.thumbnailReach ? .thumbnail : .none
    }

    private func loadTextures() {
        for k in slots.indices {
            let want = wantedDetail(k)
            guard want != slots[k].detail else { continue }
            slots[k].detail = want
            slots[k].generation += 1
            let generation = slots[k].generation
            let url = slots[k].url
            guard want != .none else {
                slots[k].material.diffuse.contents = Self.blankCanvas
                continue
            }
            let maxPixels = want == .thumbnail ? Self.thumbnailPixels : nil
            Task.detached(priority: .userInitiated) {
                let image = Gallery.loadImage(at: url, maxPixels: maxPixels)
                await MainActor.run { [weak self] in
                    guard let self, self.slots.indices.contains(k), self.slots[k].url == url,
                          self.slots[k].generation == generation, let image else { return }
                    self.slots[k].material.diffuse.contents = image
                }
            }
        }
    }

    // MARK: - Scene

    private static let blankCanvas = PlatformColor(white: 0.97, alpha: 1)

    private static func canvasMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.mipFilter = .linear
        material.diffuse.contents = blankCanvas
        return material
    }

    private static let wallMaterial: SCNMaterial = {
        let wall = SCNMaterial()
        wall.lightingModel = .physicallyBased
        wall.diffuse.contents = PlatformColor(red: 0.5, green: 0.5, blue: 0.51, alpha: 1)
        wall.roughness.contents = NSNumber(value: 0.95)
        wall.metalness.contents = NSNumber(value: 0.0)
        return wall
    }()

    private static let frameMaterial: SCNMaterial = {
        let paint = SCNMaterial()
        paint.lightingModel = .physicallyBased
        paint.roughness.contents = NSNumber(value: 0.25)
        paint.metalness.contents = NSNumber(value: 0.0)
        paint.diffuse.contents = PlatformColor(white: 0.97, alpha: 1)
        return paint
    }()

    private static let lampMaterial: SCNMaterial = {
        let lamp = SCNMaterial()
        lamp.lightingModel = .physicallyBased
        lamp.diffuse.contents = PlatformColor(white: 0.12, alpha: 1)
        lamp.metalness.contents = NSNumber(value: 0.6)
        lamp.roughness.contents = NSNumber(value: 0.35)
        return lamp
    }()

    private static let glowMaterial: SCNMaterial = {
        let glow = SCNMaterial()
        glow.lightingModel = .constant
        glow.diffuse.contents = PlatformColor(red: 1, green: 0.95, blue: 0.82, alpha: 1)
        return glow
    }()

    /// One grey partition, floor to ceiling, with a white-framed canvas and a little lamp over it.
    private static func partition(at x: Float, canvas: SCNMaterial) -> SCNNode {
        let node = SCNNode()
        node.simdPosition = SIMD3(x, 0, 0)
        node.addChildNode(Toybox.node(SCNBox(width: 5.2, height: 16, length: 0.3, chamferRadius: 0),
                                      wallMaterial, at: SIMD3(0, 0.5, -0.15)))

        let artwork = SCNNode()
        let size = artSize
        let bar: Float = 0.1
        let depth: Float = 0.12
        func piece(_ w: Float, _ h: Float, at p: SIMD2<Float>) {
            artwork.addChildNode(Toybox.node(SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(depth),
                                                    chamferRadius: 0.012), frameMaterial, at: SIMD3(p.x, p.y, depth / 2)))
        }
        let outer = size + SIMD2(repeating: bar * 2)
        piece(outer.x, bar, at: SIMD2(0, (size.y + bar) / 2))
        piece(outer.x, bar, at: SIMD2(0, -(size.y + bar) / 2))
        piece(bar, size.y, at: SIMD2(-(size.x + bar) / 2, 0))
        piece(bar, size.y, at: SIMD2((size.x + bar) / 2, 0))
        let plane = SCNNode(geometry: SCNPlane(width: CGFloat(size.x), height: CGFloat(size.y)))
        plane.geometry?.materials = [canvas]
        plane.simdPosition = SIMD3(0, 0, 0.03)
        artwork.addChildNode(plane)
        artwork.simdPosition = SIMD3(0, artY, 0)
        node.addChildNode(artwork)

        // A slim picture lamp on an arm above the frame, its bulb glowing.
        let lampY = artY + size.y / 2 + 0.45
        node.addChildNode(Toybox.node(SCNBox(width: 0.06, height: 0.06, length: 0.5, chamferRadius: 0.02),
                                      lampMaterial, at: SIMD3(0, lampY, 0.25)))
        node.addChildNode(Toybox.node(SCNCapsule(capRadius: 0.07, height: 1.4), lampMaterial,
                                      at: SIMD3(0, lampY - 0.05, 0.5)))
        node.childNodes.last?.simdEulerAngles = SIMD3(0, 0, .pi / 2)
        node.addChildNode(Toybox.node(SCNBox(width: 1.2, height: 0.02, length: 0.05, chamferRadius: 0.01),
                                      glowMaterial, at: SIMD3(0, lampY - 0.12, 0.5)))
        return node
    }

    private func build() {
        scene.background.contents = Self.backdrop()
        scene.lightingEnvironment.contents = Studio.environment()
        scene.lightingEnvironment.intensity = 0.8

        let camera = SCNCamera()
        camera.fieldOfView = 34
        camera.zNear = 0.1
        camera.zFar = 50
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = -0.2
        camera.screenSpaceAmbientOcclusionIntensity = 0.5
        camera.screenSpaceAmbientOcclusionRadius = 0.3
        camera.vignettingIntensity = 0.3
        camera.vignettingPower = 0.8
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(row)

        // Track light from the ceiling, walking with the camera: a soft pool on the painting in front,
        // the visitors' shadows on the wall. One shadow-casting light keeps a long row cheap.
        let track = SCNLight()
        track.type = .spot
        track.intensity = 1100
        track.color = PlatformColor(red: 1, green: 0.97, blue: 0.92, alpha: 1)
        track.spotInnerAngle = 25
        track.spotOuterAngle = 80
        track.castsShadow = true
        track.shadowMode = .deferred
        track.shadowRadius = 12
        track.shadowSampleCount = 16
        track.shadowColor = PlatformColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 0.4)
        track.shadowMapSize = CGSize(width: 2048, height: 2048)
        track.zNear = 1
        track.zFar = 30
        let trackNode = SCNNode()
        trackNode.light = track
        trackNode.simdPosition = SIMD3(-1.5, 5.5, 7)
        trackNode.simdLook(at: SIMD3(0, Self.artY - 0.3, 0))
        rig.addChildNode(trackNode)
        scene.rootNode.addChildNode(rig)

        let fill = SCNLight()
        fill.type = .ambient
        fill.intensity = 380
        fill.color = PlatformColor(red: 0.92, green: 0.94, blue: 1, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        scene.rootNode.addChildNode(fillNode)

        // The brush animals, shoulder to shoulder along the bottom, looking up at the painting.
        for kind in CritterKind.legacyBrushes {
            let home = SIMD3<Float>(0, -2, Self.visitorZ)
            let critter = kind.make(color: kind.signatureColor, at: home)
            critter.sizeScale = 1.7
            scene.rootNode.addChildNode(critter.root)
            visitors.append((critter, home))
        }
        layout(size: CGSize(width: 16, height: 10))
    }

    private func placeCamera() {
        cameraNode.simdPosition = SIMD3(railX, Self.cameraY + bob, cameraDistance)
        rig.simdPosition = SIMD3(railX, 0, 0)
    }

    private func tick(dt: Float) {
        clock += dt
        if walkTime < walkDuration {
            walkTime = min(walkTime + dt, walkDuration)
            let t = walkTime / walkDuration
            let eased = t * t * (3 - 2 * t)
            railX = walkFrom + (walkTo - walkFrom) * eased
            // A slight head bob: a few footsteps that fade in and out with the walk.
            bob = abs(sin(t * .pi * 4)) * sin(t * .pi) * 0.06
            placeCamera()
        }

        let states = hands.advance(dt: dt, now: CACurrentMediaTime())
        if let stroke = paddle.feed(states, now: CACurrentMediaTime()) { onPaddle?(stroke) }
        let next = states.filter(\.tracking).map { Cursor(slot: $0.slot, position: $0.position, fist: $0.pose == .fist) }
        if next != cursors { cursors = next }

        let pulse = exp(-(clock * 2).truncatingRemainder(dividingBy: 1) * 6)
        let walk = SIMD3<Float>(railX, 0, 0)
        for (k, visitor) in visitors.enumerated() {
            let t = clock * 0.8 + Float(k) * 1.3
            let sway = SIMD3<Float>(sin(t) * 0.05, sin(t * 1.7) * 0.03, 0)
            visitor.critter.update(dt: dt, target: visitor.home + walk + sway, visible: true, painting: false,
                                   beatPulse: pulse * 0.4)
        }
    }

    /// The rest of the museum, out of focus behind the partition: blue-grey walls hung with paintings,
    /// statues on plinths, a warm stone floor and ceiling light.
    static func backdrop() -> PlatformImage? {
        let w = 1600, h = 1000
        guard let sharp = Toybox.image(width: w, height: h, draw: { ctx in
            func fill(_ r: CGRect, _ c: SIMD4<Float>) {
                ctx.setFillColor(CGColor(red: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: CGFloat(c.w)))
                ctx.fill(r)
            }
            func polygon(_ points: [CGPoint], _ c: SIMD4<Float>) {
                ctx.setFillColor(CGColor(red: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: CGFloat(c.w)))
                ctx.addLines(between: points)
                ctx.closePath()
                ctx.fillPath()
            }
            let W = CGFloat(w), H = CGFloat(h)
            let horizon: CGFloat = 330          // where the far wall meets the floor (y up)
            fill(CGRect(x: 0, y: 0, width: W, height: H), SIMD4(0.55, 0.58, 0.63, 1))          // walls
            // Side walls receding toward the middle, a little darker than the far wall.
            polygon([CGPoint(x: 0, y: 0), CGPoint(x: 420, y: horizon), CGPoint(x: 420, y: 880),
                     CGPoint(x: 0, y: H)], SIMD4(0.5, 0.53, 0.58, 1))
            polygon([CGPoint(x: W, y: 0), CGPoint(x: W - 420, y: horizon), CGPoint(x: W - 420, y: 880),
                     CGPoint(x: W, y: H)], SIMD4(0.48, 0.51, 0.56, 1))
            // Ceiling with a long skylight.
            polygon([CGPoint(x: 0, y: H), CGPoint(x: 420, y: 880), CGPoint(x: W - 420, y: 880),
                     CGPoint(x: W, y: H)], SIMD4(0.72, 0.7, 0.66, 1))
            fill(CGRect(x: 300, y: 920, width: W - 600, height: 40), SIMD4(0.95, 0.94, 0.9, 1))
            // Stone floor and the dark skirting line along the walls.
            polygon([CGPoint(x: 0, y: 0), CGPoint(x: 420, y: horizon), CGPoint(x: W - 420, y: horizon),
                     CGPoint(x: W, y: 0)], SIMD4(0.66, 0.61, 0.55, 1))
            fill(CGRect(x: 420, y: horizon, width: W - 840, height: 12), SIMD4(0.25, 0.25, 0.27, 1))
            polygon([CGPoint(x: 0, y: 40), CGPoint(x: 420, y: horizon + 10), CGPoint(x: 420, y: horizon),
                     CGPoint(x: 0, y: 0)], SIMD4(0.25, 0.25, 0.27, 1))
            polygon([CGPoint(x: W, y: 40), CGPoint(x: W - 420, y: horizon + 10), CGPoint(x: W - 420, y: horizon),
                     CGPoint(x: W, y: 0)], SIMD4(0.25, 0.25, 0.27, 1))
            // Paintings on the side walls: gilt or dark frames, warm canvases.
            let hung: [(CGRect, SIMD4<Float>, SIMD4<Float>)] = [
                (CGRect(x: 10, y: 470, width: 70, height: 130), SIMD4(0.5, 0.35, 0.2, 1), SIMD4(0.45, 0.32, 0.22, 1)),
                (CGRect(x: 160, y: 500, width: 70, height: 110), SIMD4(0.62, 0.5, 0.32, 1), SIMD4(0.8, 0.74, 0.62, 1)),
                (CGRect(x: 300, y: 530, width: 40, height: 70), SIMD4(0.55, 0.42, 0.25, 1), SIMD4(0.6, 0.45, 0.3, 1)),
                (CGRect(x: W - 120, y: 450, width: 100, height: 160), SIMD4(0.12, 0.12, 0.13, 1), SIMD4(0.3, 0.22, 0.16, 1)),
                (CGRect(x: W - 270, y: 500, width: 60, height: 100), SIMD4(0.55, 0.42, 0.25, 1), SIMD4(0.7, 0.6, 0.45, 1)),
            ]
            for (r, frame, art) in hung {
                fill(r, frame)
                fill(r.insetBy(dx: r.width * 0.12, dy: r.width * 0.12), art)
            }
            // Statues on plinths.
            let statues: [(CGFloat, CGFloat, CGFloat)] = [(180, 200, 70), (W - 140, 160, 90), (W - 300, 260, 50)]
            for (x, base, s) in statues {
                fill(CGRect(x: x - s * 0.6, y: base, width: s * 1.2, height: s * 2.4), SIMD4(0.42, 0.44, 0.47, 1))
                let top = base + s * 2.4
                ctx.setFillColor(CGColor(red: 0.86, green: 0.83, blue: 0.77, alpha: 1))
                ctx.fillEllipse(in: CGRect(x: x - s * 0.45, y: top, width: s * 0.9, height: s * 1.5))
                ctx.fillEllipse(in: CGRect(x: x - s * 0.22, y: top + s * 1.35, width: s * 0.44, height: s * 0.5))
            }
        }) else { return nil }
        // Shallow depth of field: everything behind the partition is soft.
        let input = CIImage(cgImage: sharp)
        let blurred = input.clampedToExtent().applyingGaussianBlur(sigma: 9).cropped(to: input.extent)
        return Toybox.platformImage(CIContext().createCGImage(blurred, from: input.extent) ?? sharp)
    }
}

// MARK: - Gallery screen

struct GalleryView: View {
    let gallery: Gallery
    let relay: HandFrameRelay
    let home: () -> Void
    let show2D: () -> Void
    let startDrawing: () -> Void
    @State private var index: Int
    @State private var hall = GalleryHall()
    @State private var confirmingRemoval = false
    @Environment(\.uiScale) private var scale
    private let cheerOnOpen: Bool

    init(gallery: Gallery, relay: HandFrameRelay, startAt index: Int = 0, justHung: Bool = false,
         home: @escaping () -> Void, show2D: @escaping () -> Void, startDrawing: @escaping () -> Void) {
        self.gallery = gallery
        self.relay = relay
        self.home = home
        self.show2D = show2D
        self.startDrawing = startDrawing
        _index = State(initialValue: index)
        cheerOnOpen = justHung
    }

    private var current: Painting? {
        gallery.paintings.indices.contains(index) ? gallery.paintings[index] : nil
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                ZStack {
                    SceneView(scene: hall.scene, pointOfView: hall.cameraNode, options: [.rendersContinuously],
                              antialiasingMode: .multisampling4X)
                    // Small hand markers, so the person sees the camera has their hands.
                    ForEach(hall.cursors) { cursor in
                        HandCursor(fist: cursor.fist)
                            .scaleEffect(0.6)
                            .opacity(0.8)
                            .position(x: CGFloat(cursor.position.x) * proxy.size.width,
                                      y: CGFloat(cursor.position.y) * proxy.size.height)
                    }
                    .allowsHitTesting(false)
                }
                .onAppear { hall.layout(size: proxy.size) }
                .onChange(of: proxy.size) { _, size in hall.layout(size: size) }
            }
            .ignoresSafeArea()
            .gesture(DragGesture(minimumDistance: 30).onEnded { drag in
                if drag.translation.width < -60 { step(1) } else if drag.translation.width > 60 { step(-1) }
            })

            VStack {
                HStack(alignment: .top) {
                    RoundButton(symbol: "house.fill", tint: .blue, action: home)
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Puffy Pond Gallery")
                            .font(.system(size: 26 * scale, weight: .black, design: .rounded))
                        if let current {
                            Text("\(current.date.formatted(.dateTime.month(.wide).day().hour().minute()))"
                                 + (gallery.paintings.count > 1 ? " · \(index + 1) of \(gallery.paintings.count)" : ""))
                                .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.85), in: Capsule())
                    .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
                    Spacer()
                    RoundButton(symbol: "trash.fill", tint: .red) { confirmingRemoval = true }
                        .opacity(current == nil ? 0 : 1)
                }
                Spacer()
                HStack(alignment: .bottom) {
                    PillButton(title: "View gallery in 2D", symbol: "square.grid.2x2.fill", tint: .orange,
                               action: show2D)
                    Spacer()
                    if gallery.paintings.count > 1 {
                        PaddleHint()
                    }
                    Spacer()
                    // Balances the 2D button so the hint stays centered.
                    PillButton(title: "View gallery in 2D", symbol: "square.grid.2x2.fill", tint: .orange) {}
                        .hidden()
                }
            }
            .padding(16 * scale)

            // Page buttons sit at the middle of the two sides, where thumbs rest on a wide screen.
            HStack {
                RoundButton(symbol: "chevron.left", tint: .indigo) { step(-1) }
                    .opacity(index > 0 ? 1 : 0)
                Spacer()
                RoundButton(symbol: "chevron.right", tint: .indigo) { step(1) }
                    .opacity(index < gallery.paintings.count - 1 ? 1 : 0)
            }
            .padding(.horizontal, 16 * scale)

            if gallery.paintings.isEmpty {
                VStack(spacing: 20 * scale) {
                    Text("No paintings yet")
                        .font(.system(size: 34 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
                    HomeButton(title: "Start drawing", symbol: "paintbrush.pointed.fill", tint: .pink,
                               action: startDrawing)
                }
                .padding(32 * scale)
                .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 36 * scale, style: .continuous))
            }
        }
        .confirmationDialog("Take this painting down?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
            Button("Take it down", role: .destructive, action: removeCurrent)
        }
        .onAppear {
            hall.hang(gallery.paintings.map(\.url))
            hall.focus(index, animated: false)
            if cheerOnOpen { hall.cheer() }
            hall.onPaddle = { stroke in step(stroke == .next ? 1 : -1) }
            let hall = hall
            relay.listener = { frame in hall.ingest(frame) }
            hall.start()
        }
        .onDisappear {
            relay.listener = nil
            hall.onPaddle = nil
            hall.stop()
        }
    }

    private func step(_ delta: Int) {
        let next = index + delta
        guard gallery.paintings.indices.contains(next) else { return }
        index = next
        hall.focus(index)
    }

    private func removeCurrent() {
        guard let current else { return }
        gallery.remove(current)
        index = min(index, max(gallery.paintings.count - 1, 0))
        hall.hang(gallery.paintings.map(\.url))
        hall.focus(index, animated: false)
    }
}

/// A rounded pill with an icon and a label, smaller than the home page's buttons.
struct PillButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    @Environment(\.uiScale) private var scale

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 17 * scale, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18 * scale)
                .frame(minHeight: 50 * scale)
                .background(tint.gradient, in: Capsule())
                .overlay(Capsule().stroke(.white, lineWidth: 3))
                .shadow(color: tint.opacity(0.4), radius: 8, y: 4)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Shows how to walk with the hands: an open hand paddling down on either side.
private struct PaddleHint: View {
    @Environment(\.uiScale) private var scale
    @State private var down = false

    var body: some View {
        HStack(spacing: 10 * scale) {
            Text("🖐️")
                .font(.system(size: 24 * scale))
                .offset(y: down ? 6 * scale : -6 * scale)
            Text("Paddle down on the right to walk on, on the left to go back")
                .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.35))
        }
        .padding(.horizontal, 16 * scale)
        .padding(.vertical, 10 * scale)
        .background(.white.opacity(0.85), in: Capsule())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { down = true }
        }
    }
}
