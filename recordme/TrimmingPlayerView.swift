import AVKit
import SwiftUI

/// SwiftUI bridge for AVPlayerView's native QuickTime-style trim controls.
struct TrimmingPlayerView: NSViewRepresentable {
    @ObservedObject var model: VideoEditorModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = model.player
        view.controlsStyle = .default
        view.showsFrameSteppingButtons = true
        view.showsSharingServiceButton = false
        view.showsFullScreenToggleButton = true
        model.attachPlayerView(view)
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== model.player {
            view.player = model.player
        }
    }

    static func dismantleNSView(_ view: AVPlayerView, coordinator: Coordinator) {
        coordinator.model.detachPlayerView(view)
        view.player = nil
    }

    final class Coordinator {
        let model: VideoEditorModel

        init(model: VideoEditorModel) {
            self.model = model
        }
    }
}
