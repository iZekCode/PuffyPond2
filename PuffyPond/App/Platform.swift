import SwiftUI
import SceneKit
import AVFoundation
import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// Everything that differs between Mac and iPhone/iPad lives here.

enum Platform {
    #if os(macOS)
    private static var awakeActivity: NSObjectProtocol?
    #endif

    /// Nobody touches the device while playing with hands — keep the display awake.
    static func keepAwake() {
        #if os(macOS)
        if awakeActivity == nil {
            awakeActivity = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .userInitiated], reason: "Bermain dengan gerakan tangan")
        }
        #else
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    static func openCameraSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    /// iPad is a landscape-only, finger-sized screen; everything else (Mac, iPhone) keeps the base sizes.
    static var isPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    static func configure(_ connection: AVCaptureConnection?) {
        guard let connection else { return }
        // The iPad's angle comes from its rotation coordinator instead (see PreviewView).
        if !isPad, connection.isVideoRotationAngleSupported(HandTracker.rotationAngle) {
            connection.videoRotationAngle = HandTracker.rotationAngle
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = HandTracker.mirrored
        }
    }
}

extension EnvironmentValues {
    /// How much bigger than the base sizes controls and text are drawn (1.2 on iPad).
    @Entry var uiScale: CGFloat = 1
}

extension View {
    @ViewBuilder
    func immersive() -> some View {
        #if os(iOS)
        self.statusBarHidden().persistentSystemOverlays(.hidden)
        #else
        self
        #endif
    }
}

/// Calls back once per screen refresh with the elapsed time.
final class FrameDriver: NSObject {
    var onFrame: ((Double) -> Void)?
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    func start() {
        guard link == nil else { return }
        #if os(macOS)
        guard let link = NSScreen.main?.displayLink(target: self, selector: #selector(tick(_:))) else { return }
        #else
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        #endif
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        lastTimestamp = 0
    }

    @objc private func tick(_ link: CADisplayLink) {
        let dt = lastTimestamp == 0 ? 1.0 / 60 : link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        onFrame?(min(dt, 1.0 / 20))
    }
}

// MARK: - 3D view

private func configure(_ view: SCNView, playground: Playground) {
    view.scene = playground.scene
    view.pointOfView = playground.cameraNode
    view.antialiasingMode = .multisampling4X
    view.rendersContinuously = true
    view.preferredFramesPerSecond = 60
    view.isPlaying = true
    view.allowsCameraControl = false
}

#if os(macOS)

struct PlaygroundView: NSViewRepresentable {
    let playground: Playground

    func makeNSView(context: Context) -> PlaygroundSCNView {
        let view = PlaygroundSCNView(frame: .zero, options: nil)
        view.playground = playground
        configure(view, playground: playground)
        return view
    }

    func updateNSView(_ nsView: PlaygroundSCNView, context: Context) {}
}

/// Mouse drag paints with the left buddy.
final class PlaygroundSCNView: SCNView {
    weak var playground: Playground?

    override var acceptsFirstResponder: Bool { true }

    override func layout() {
        super.layout()
        playground?.layout(size: bounds.size)
    }

    private func normalized(_ event: NSEvent) -> SIMD2<Float> {
        let p = convert(event.locationInWindow, from: nil)
        let w = max(bounds.width, 1)
        let h = max(bounds.height, 1)
        let y = isFlipped ? p.y / h : 1 - p.y / h
        return SIMD2(Float(p.x / w), Float(y))
    }

    override func mouseDown(with event: NSEvent) {
        playground?.pointerBegan(normalized(event))
    }

    override func mouseDragged(with event: NSEvent) { playground?.pointerMoved(normalized(event)) }
    override func mouseUp(with event: NSEvent) { playground?.pointerEnded() }
}

/// Shows the tracker's shared camera layer. Only one host holds it at a time: the newest one takes it.
struct CameraPreview: NSViewRepresentable {
    let previewLayer: CameraPreviewLayer

    final class PreviewView: NSView {
        let previewLayer: CameraPreviewLayer

        init(previewLayer: CameraPreviewLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero)
            wantsLayer = true
            layer?.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func layout() {
            super.layout()
            guard previewLayer.superlayer === layer else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = bounds
            CATransaction.commit()
            Platform.configure(previewLayer.connection)
        }
    }

    func makeNSView(context: Context) -> PreviewView {
        PreviewView(previewLayer: previewLayer)
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {}
}

#else

struct PlaygroundView: UIViewRepresentable {
    let playground: Playground

    func makeUIView(context: Context) -> PlaygroundSCNView {
        let view = PlaygroundSCNView(frame: .zero, options: nil)
        view.playground = playground
        view.isMultipleTouchEnabled = false
        configure(view, playground: playground)
        return view
    }

    func updateUIView(_ uiView: PlaygroundSCNView, context: Context) {}
}

/// One finger paints with the left buddy.
final class PlaygroundSCNView: SCNView {
    weak var playground: Playground?

    override func layoutSubviews() {
        super.layoutSubviews()
        playground?.layout(size: bounds.size)
    }

    private func normalized(_ touches: Set<UITouch>) -> SIMD2<Float>? {
        guard let touch = touches.first else { return nil }
        let p = touch.location(in: self)
        return SIMD2(Float(p.x / max(bounds.width, 1)), Float(p.y / max(bounds.height, 1)))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let uv = normalized(touches) { playground?.pointerBegan(uv) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let uv = normalized(touches) { playground?.pointerMoved(uv) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { playground?.pointerEnded() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { playground?.pointerEnded() }
}

/// Shows the tracker's shared camera layer. Only one host holds it at a time: the newest one takes it.
struct CameraPreview: UIViewRepresentable {
    let previewLayer: CameraPreviewLayer

    final class PreviewView: UIView {
        let previewLayer: CameraPreviewLayer

        init(previewLayer: CameraPreviewLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero)
            layer.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard previewLayer.superlayer === layer else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = bounds
            CATransaction.commit()
            Platform.configure(previewLayer.connection)
            previewLayer.followDeviceRotation()
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        PreviewView(previewLayer: previewLayer)
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

#endif
