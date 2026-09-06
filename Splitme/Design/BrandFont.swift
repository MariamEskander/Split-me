import SwiftUI
import UIKit

/// Poppins for headings, Inter for body — with a system fallback so the app is
/// never blocked on the font files being present. See `Fonts/README.md`.
enum BrandFont {
    private static func isAvailable(_ name: String) -> Bool {
        UIFont(name: name, size: 12) != nil
    }

    static func heading(_ size: CGFloat, weight: Font.Weight) -> Font {
        let face = weight >= .bold ? "Poppins-SemiBold" : "Poppins-SemiBold"
        if isAvailable(face) { return .custom(face, size: size) }
        return .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat, weight: Font.Weight) -> Font {
        let face = weight >= .medium ? "Inter-Medium" : "Inter-Regular"
        if isAvailable(face) { return .custom(face, size: size) }
        if isAvailable("Inter-Regular") { return .custom("Inter-Regular", size: size) }
        return .system(size: size, weight: weight, design: .rounded)
    }
}

extension Font.Weight: @retroactive Comparable {
    private var rank: Int {
        switch self {
        case .ultraLight: return 0
        case .thin: return 1
        case .light: return 2
        case .regular: return 3
        case .medium: return 4
        case .semibold: return 5
        case .bold: return 6
        case .heavy: return 7
        case .black: return 8
        default: return 3
        }
    }

    public static func < (lhs: Font.Weight, rhs: Font.Weight) -> Bool {
        lhs.rank < rhs.rank
    }
}
