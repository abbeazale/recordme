import Testing
@testable import recordme

struct PreviewFrameThrottlerTests {
    @Test func disabledPreviewNeverEmitsFrames() {
        var throttler = PreviewFrameThrottler(interval: 4)

        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: false))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: false))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: false))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: false))
    }

    @Test func enabledPreviewEmitsEveryInterval() {
        var throttler = PreviewFrameThrottler(interval: 4)

        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(throttler.shouldEmitFrame(isPreviewEnabled: true))
    }

    @Test func resetStartsIntervalAgain() {
        var throttler = PreviewFrameThrottler(interval: 2)

        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(throttler.shouldEmitFrame(isPreviewEnabled: true))
        throttler.reset()
        #expect(!throttler.shouldEmitFrame(isPreviewEnabled: true))
        #expect(throttler.shouldEmitFrame(isPreviewEnabled: true))
    }
}
