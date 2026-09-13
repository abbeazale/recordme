import CoreGraphics
import Foundation

struct ExportSettings: Codable, Equatable, Sendable {
    enum Resolution: String, Codable, CaseIterable, Identifiable {
        case source, fullHD, hd
        var id: Self { self }
        var title: String {
            switch self {
            case .source: return "Source size"
            case .fullHD: return "1080p"
            case .hd: return "720p"
            }
        }
        var longestEdge: CGFloat? {
            switch self {
            case .source: return nil
            case .fullHD: return 1920
            case .hd: return 1280
            }
        }
    }
    enum Quality: String, Codable, CaseIterable, Identifiable {
        case compact, balanced, high
        var id: Self { self }
        var title: String { rawValue.capitalized }
        var bitsPerPixel: Double {
            switch self {
            case .compact: return 0.05
            case .balanced: return 0.1
            case .high: return 0.2
            }
        }
    }
    enum FrameRate: Int, Codable, CaseIterable, Identifiable {
        case film = 24, standard = 30, smooth = 60
        var id: Self { self }
    }
    var resolution: Resolution = .source
    var quality: Quality = .balanced
    var frameRate: FrameRate = .standard

    func renderSize(for canvas: CGSize) -> CGSize {
        let scale = min(1, (resolution.longestEdge ?? max(canvas.width, canvas.height)) / max(canvas.width, canvas.height))
        return CGSize(width: max(2, floor(canvas.width * scale / 2) * 2),
                      height: max(2, floor(canvas.height * scale / 2) * 2))
    }

    func bitRate(for size: CGSize) -> Int {
        Int(min(60_000_000, max(250_000, size.width * size.height * Double(frameRate.rawValue) * quality.bitsPerPixel)))
    }
}
