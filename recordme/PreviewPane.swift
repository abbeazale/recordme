import CoreGraphics
import SwiftUI

struct PreviewPane: View {
    let previewImage: CGImage?
    let showCamera: Bool
    let isCameraCapturing: Bool
    let cameraImage: CGImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.controlBackgroundColor)
                    .opacity(0.5)

                if let img = previewImage {
                    ZStack(alignment: .bottomTrailing) {
                        Image(img, scale: 1.0, label: Text("Preview"))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geometry.size.width - 40)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                        if showCamera && isCameraCapturing, let cameraImg = cameraImage {
                            Image(cameraImg, scale: 1.0, label: Text("Camera"))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 160, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                                .padding(16)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "display")
                            .font(.system(size: 64, weight: .thin))
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            Text("Select a source to see preview")
                                .font(.system(.title2, design: .rounded, weight: .medium))
                                .foregroundColor(.primary)

                            Text("Choose from a display or window")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
