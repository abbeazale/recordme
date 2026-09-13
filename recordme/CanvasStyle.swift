import CoreGraphics
import Foundation

struct CanvasStyle: Codable, Equatable, Sendable {
    enum Background: String, Codable, CaseIterable, Identifiable {
        case none, midnight, ocean, sunset, paper
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    enum Aspect: String, Codable, CaseIterable, Identifiable {
        case original, landscape, square, portrait
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    var background: Background = .none
    var aspect: Aspect = .original
    var padding = 0.06
    var cornerRadius = 0.025
    var shadow = true

    var isEnabled: Bool { background != .none || aspect != .original }

    func canvasSize(for source: CGSize) -> CGSize {
        let ratio: CGFloat
        switch aspect {
        case .original: ratio = source.width / source.height
        case .landscape: ratio = 16 / 9
        case .square: ratio = 1
        case .portrait: ratio = 9 / 16
        }
        let longest = max(source.width, source.height)
        let width = ratio >= 1 ? longest : longest * ratio
        let height = ratio >= 1 ? longest / ratio : longest
        return CGSize(width: max(2, (width / 2).rounded(.down) * 2),
                      height: max(2, (height / 2).rounded(.down) * 2))
    }
}
