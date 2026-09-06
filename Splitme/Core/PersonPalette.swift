import SwiftUI

/// Per-person hues. The first two are the brand's own teal and coral; the rest
/// extend outward while staying legible on the navy canvas — the stock system
/// colours (blue, indigo, purple) all collapse into the navy ground at avatar
/// size, which is why none of them appear here.
enum PersonPalette {
    static let colors: [Color] = [
        Brand.teal,             // 00D4C4
        Brand.coral,            // FF6B6B
        Color(hex: 0xA7F0E6),   // mint
        Color(hex: 0xFFC85C),   // amber
        Color(hex: 0x7AA5FF),   // periwinkle
        Color(hex: 0xFF9AD5),   // orchid
        Color(hex: 0x7BE495),   // lime
        Color(hex: 0xFFA07A),   // peach
        Color(hex: 0x67E8F9),   // ice
        Color(hex: 0xC4B5FD),   // lilac
    ]

    static func color(for index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }

    static func gradient(for index: Int) -> LinearGradient {
        let base = color(for: index)
        return LinearGradient(colors: [base, base.opacity(0.7)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }
}
