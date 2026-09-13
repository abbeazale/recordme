import AppKit
import CoreMedia

enum CursorCaptureSource {
    case display(CGRect)
    case window(CGWindowID, CGRect)

    var bounds: CGRect {
        switch self {
        case .display(let bounds): return bounds
        case .window(let id, let fallback):
            guard let windows = CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]],
                  let value = windows.first?[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: value) else { return fallback }
            return bounds
        }
    }
}

@MainActor
final class CursorCapture {
    private var timer: Timer?
    private var events: [CursorEvent] = []
    private var wasPressed = false

    func start(source: CursorCaptureSource, outputSize: CGSize) {
        stop()
        events = []
        wasPressed = NSEvent.pressedMouseButtons & 1 != 0
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.timer != nil else { return }
                let pressed = NSEvent.pressedMouseButtons & 1 != 0
                defer { self.wasPressed = pressed }
                guard pressed && !self.wasPressed, self.events.count < 50_000,
                      let point = CGEvent(source: nil)?.location else { return }
                let bounds = source.bounds
                guard bounds.width > 0, bounds.height > 0, bounds.contains(point) else { return }
                let scale = min(outputSize.width / bounds.width, outputSize.height / bounds.height)
                let x = ((outputSize.width - bounds.width * scale) / 2 + (point.x - bounds.minX) * scale) / outputSize.width
                let y = ((outputSize.height - bounds.height * scale) / 2 + (point.y - bounds.minY) * scale) / outputSize.height
                self.events.append(CursorEvent(time: CMClockGetTime(CMClockGetHostTimeClock()).seconds, x: x, y: y))
            }
        }
    }

    func finish(firstVideoTime: Double?) -> CursorRecording {
        stop()
        defer { events = [] }
        guard let firstVideoTime else { return CursorRecording() }
        return CursorRecording(events: events.compactMap { event in
            let time = event.time - firstVideoTime
            guard time >= 0 else { return nil }
            return CursorEvent(time: time, x: event.x, y: event.y)
        })
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
