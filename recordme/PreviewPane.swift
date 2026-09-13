import CoreGraphics
import SwiftUI

/// The hero region: shows the live capture preview, or a native empty state when
/// no source is selected yet. An optional camera overlay floats in the corner.
struct PreviewPane: View {
    let previewImage: CGImage?

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

}
