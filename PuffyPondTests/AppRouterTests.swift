import QuartzCore
import Testing
@testable import PuffyPond

@MainActor
struct AppRouterTests {
    @Test func launchesOnHome() {
        #expect(AppRouter().route == .home)
    }

    @Test func goChangesRouteAndHomeReturns() {
        let router = AppRouter()
        router.go(.canvas(nil))
        #expect(router.route == .canvas(nil))
        router.home()
        #expect(router.route == .home)
    }

    @Test func onlyCanvasRoutesAreCanvas() {
        #expect(Route.canvas(nil).isCanvas)
        #expect(Route.canvas(TemplateChoice(templateID: "fish", isDailyQuest: false)).isCanvas)
        #expect(!Route.home.isCanvas)
        #expect(!Route.instruction(nil).isCanvas)
        #expect(!Route.gallery3D(start: 0, justHung: false).isCanvas)
    }
}

@MainActor
struct HandInputResetTests {
    /// Leaving the canvas mid-stroke must drop the hands, so no buddy keeps painting from a frozen cursor.
    @Test func resetDropsTrackedHands() {
        let input = HandInput()
        let hand = HandObservation(joints: Array(repeating: SIMD2<Float>(0.5, 0.5), count: HandJoint.allCases.count),
                                   confidence: 1)
        input.ingest(HandFrame(hands: [hand], imageAspect: 4.0 / 3.0))
        #expect(!input.advance(dt: 1.0 / 60, now: CACurrentMediaTime()).isEmpty)
        input.reset()
        #expect(input.advance(dt: 1.0 / 60, now: CACurrentMediaTime()).isEmpty)
    }
}
