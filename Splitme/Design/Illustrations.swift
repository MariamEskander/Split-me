import SwiftUI

/// The brand's illustration set, shipped as artwork in `Assets.xcassets`.
///
/// Each piece is trimmed to its own bounds, so size and padding are decided
/// here rather than baked into the files.
enum BrandArt: String, CaseIterable {
    /// The receipt — what the app is for. Used on every "nothing here yet" state.
    case receipt = "art-receipt"
    /// The high-five — shown once a bill is fully assigned and nobody is guessing.
    case highFive = "art-highfive"
    /// The SETTLED stamp. Not currently placed: the bills list shows its
    /// status in words so the list never stacks up artwork.
    case settled = "badge-settled"

    case billsDontBreakFriends = "sticker-bills-dont-break-friends"
    case fairIsFun = "sticker-fair-is-fun"
    case teamTrip = "sticker-team-trip"
    case youOweMePizza = "sticker-you-owe-me-pizza"
    case splitHappens = "sticker-split-happens"

    /// Everything that can be scattered across the launch screen: the
    /// artwork, minus the logo (the lockup already carries it) and minus the
    /// high-five (which is earned on the Shares tab, not given away up front).
    static let scatterable: [BrandArt] = [
        .receipt, .settled, .fairIsFun, .teamTrip,
        .splitHappens, .youOweMePizza, .billsDontBreakFriends
    ]
}

/// Draws one piece of brand artwork at a given width, aspect preserved.
struct BrandArtView: View {
    var art: BrandArt
    var width: CGFloat
    /// Stickers read as physical objects, so a slight tilt suits them.
    var tilt: Double = 0

    var body: some View {
        Image(art.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .rotationEffect(.degrees(tilt))
            .accessibilityHidden(true)
    }
}

// MARK: - Launch screen artwork

/// The launch screen's lower field: the brand's own illustrations scattered
/// small, rather than drawn-in-code stand-ins. The logo is left out because the
/// lockup above already carries it, and the high-five is left out because it is
/// something the Shares tab awards once a bill is fully assigned.
struct ScatteredArtField: View {
    /// Drives the staggered entry.
    var appeared: Bool = true
    /// Drives the slow, endless drift once everything has arrived.
    var floating: Bool = false

    private struct Piece {
        let art: BrandArt
        /// Fractions of the field.
        let x, y: CGFloat
        let width: CGFloat
        let tilt: Double
        let opacity: Double
    }

    /// Sizes stay small and opacities sit below full so nothing competes with
    /// the wordmark; the pieces nearest the lockup are the faintest.
    private let pieces: [Piece] = [
        Piece(art: .receipt,               x: 0.15, y: 0.30, width: 52, tilt: -9,  opacity: 0.72),
        Piece(art: .fairIsFun,             x: 0.80, y: 0.28, width: 56, tilt:  7,  opacity: 0.72),
        Piece(art: .settled,               x: 0.45, y: 0.46, width: 74, tilt: -4,  opacity: 0.85),
        Piece(art: .teamTrip,              x: 0.13, y: 0.58, width: 50, tilt:  9,  opacity: 0.85),
        Piece(art: .splitHappens,          x: 0.79, y: 0.55, width: 62, tilt: -7,  opacity: 0.88),
        Piece(art: .youOweMePizza,         x: 0.33, y: 0.74, width: 58, tilt:  6,  opacity: 0.90),
        Piece(art: .billsDontBreakFriends, x: 0.80, y: 0.86, width: 48, tilt: -11, opacity: 0.88),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(pieces.enumerated()), id: \.offset) { index, piece in
                BrandArtView(art: piece.art, width: piece.width, tilt: piece.tilt)
                    // Entry: each sticker springs in slightly after the last, so
                    // the field assembles rather than appearing all at once.
                    .opacity(appeared ? piece.opacity : 0)
                    .scaleEffect(appeared ? 1 : 0.45)
                    .rotationEffect(.degrees(appeared ? 0 : -10))
                    .animation(.spring(response: 0.55, dampingFraction: 0.62)
                        .delay(0.34 + Double(index) * 0.07), value: appeared)
                    // Drift: a separate, endless animation on a different
                    // property, each piece out of phase with its neighbours.
                    .offset(y: floating ? -5 : 5)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.22), value: floating)
                    .position(x: geo.size.width * piece.x,
                              y: geo.size.height * piece.y)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Splash") { SplashView() }

#Preview("Artwork") {
    ScrollView {
        VStack(spacing: 28) {
            ForEach(BrandArt.allCases, id: \.rawValue) { art in
                BrandArtView(art: art, width: 200)
            }
        }
        .padding(24)
    }
    .background(Theme.canvas)
    .preferredColorScheme(.dark)
}
