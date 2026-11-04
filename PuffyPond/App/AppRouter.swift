import CoreGraphics
import Foundation
import Observation
import SwiftUI

/// The template a drawing session starts from; `isDailyQuest` when it was picked as the day's quest.
struct TemplateChoice: Equatable, Hashable {
    let templateID: String
    let isDailyQuest: Bool
}

/// The finished painting photographed three ways: whole (what goes in the gallery), the bare canvas,
/// and the paint alone on a clear background. The review page keeps the canvas still and plays with the paint.
struct CanvasPhotos {
    let whole: CGImage
    let canvas: CGImage
    let paint: CGImage
}

/// A finished painting waiting on the review page, before it goes to the gallery.
struct ReviewDraft: Equatable {
    let id = UUID()
    let photos: CanvasPhotos
    let choice: TemplateChoice?
    /// Movement stats of the session; nil when it was drawn by touch or mouse.
    let stats: SessionStats?
    /// What was painted, for the timelapse; nil when nothing was recorded.
    let recording: StrokeRecording?
    /// The child painting, from the camera; nil when the camera was off.
    var camera: CameraTimelapse? = nil

    var image: CGImage { photos.whole }

    static func == (lhs: ReviewDraft, rhs: ReviewDraft) -> Bool { lhs.id == rhs.id }
}

/// Where a painting was opened from, so the viewing page can go back there.
enum ViewOrigin: Equatable {
    case gallery3D(index: Int)
    case gallery2D

    var route: Route {
        switch self {
        case .gallery3D(let index): .gallery3D(start: index, justHung: false)
        case .gallery2D: .gallery2D
        }
    }
}

/// Every full-screen page of the app.
enum Route: Equatable {
    case home
    case modePicker
    case templates
    case instruction(TemplateChoice?)
    case canvas(TemplateChoice?)
    case review(ReviewDraft)
    case gallery3D(start: Int, justHung: Bool)
    case gallery2D
    /// A saved painting: its timelapse, then the sheet to play with.
    case viewPainting(Painting, origin: ViewOrigin)
    case report

    /// The easel is live (hands paint) only on the canvas page.
    var isCanvas: Bool {
        if case .canvas = self { return true }
        return false
    }
}

/// Owns the current page; `ContentView` swaps pages when it changes.
@Observable
final class AppRouter {
    private(set) var route: Route = .home

    func go(_ next: Route) {
        withAnimation(.easeInOut(duration: 0.35)) { route = next }
    }

    func home() { go(.home) }
}
