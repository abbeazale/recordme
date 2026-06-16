import CoreGraphics
import SwiftUI

/// The hero region: shows the live capture preview, or a native empty state when
/// no source is selected yet. An optional camera overlay floats in the corner.
struct PreviewPane: View {
    let previewImage: CGImage?
    let showCamera: Bool
    let isCameraCapturing: Bool
    let cameraImage: CGImage?

    var body: some View {
        ZStack {
            if let previewImage {
                ZStack(alignment: .bottomTrailing) {
                    Image(previewImage, scale: 1.0, label: Text("Preview"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.stageRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppMetrics.stageRadius, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)

                    cameraOverlay
                }
            } else {
                ContentUnavailableView {
                    Label("No Source Selected", systemImage: "display")
                } description: {
                    Text("Choose a display or window above to see a live preview.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    @ViewBuilder
    private var cameraOverlay: some View {
        if showCamera, isCameraCapturing, let cameraImage {
            Image(cameraImage, scale: 1.0, label: Text("Camera"))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 168, height: 126)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 4)
                .padding(18)
                .transition(.scale.combined(with: .opacity))
        }
    }
}
