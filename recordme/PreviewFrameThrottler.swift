struct PreviewFrameThrottler {
    private final class Storage {
        var frameCount: UInt = 0
    }

    private let interval: UInt
    private let storage = Storage()

    init(interval: UInt) {
        self.interval = max(interval, 1)
    }

    func shouldEmitFrame(isPreviewEnabled: Bool) -> Bool {
        guard isPreviewEnabled else { return false }

        storage.frameCount &+= 1
        return storage.frameCount.isMultiple(of: interval)
    }

    func reset() {
        storage.frameCount = 0
    }
}
