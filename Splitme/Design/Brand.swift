import SwiftUI

/// The Billy mark, as supplied by the brand: two interlocking lobes with
/// gloss and gradient modelling that would be pointless to approximate in code.
///
/// Two variants ship in `Assets.xcassets`:
///   `brand-logo`       teal + navy — for light grounds and the app icon
///   `brand-logo-light` teal + white — for the navy grounds inside the app,
///                      where the navy lobe would otherwise disappear
struct BrandLogo: View {
    /// Width; the mark is slightly taller than it is wide.
    var size: CGFloat = 96
    var onDarkGround: Bool = true

    var body: some View {
        Image(onDarkGround ? "brand-logo-light" : "brand-logo")
            .resizable()
            .scaledToFit()
            .frame(width: size)
            .accessibilityLabel("Billy")
    }
}

/// Mark + wordmark + tagline — the stacked lockup from the kit.
///
/// `appeared` drives a staggered entry: the mark springs in first, the wordmark
/// follows, the tagline last, so the eye lands on the logo rather than on three
/// things arriving at once.
struct BrandLockup: View {
    var markSize: CGFloat = 96
    var showTagline: Bool = true
    var onNavy: Bool = true
    var appeared: Bool = true

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // A teal bloom that swells behind the mark as it lands.
                Circle()
                    .fill(Brand.teal.opacity(0.30))
                    .frame(width: markSize * 1.5, height: markSize * 1.5)
                    .blur(radius: markSize * 0.35)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.9), value: appeared)

                BrandLogo(size: markSize, onDarkGround: onNavy)
                    .scaleEffect(appeared ? 1 : 0.66)
                    .rotationEffect(.degrees(appeared ? 0 : -22))
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.72, dampingFraction: 0.6), value: appeared)
            }

            VStack(spacing: 10) {
                Text(verbatim: "Billy")
                    .font(BrandFont.heading(markSize * 0.44, weight: .semibold))
                    .foregroundStyle(onNavy ? Brand.white : Brand.navy)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.16), value: appeared)

                if showTagline {
                    Text("SPLIT. SETTLE. DONE.")
                        .font(BrandFont.heading(markSize * 0.115, weight: .semibold))
                        // The letters settle outward into place.
                        .latinTracking(appeared ? markSize * 0.042 : markSize * 0.012)
                        .foregroundStyle(Brand.teal)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.65).delay(0.30), value: appeared)
                }
            }
        }
    }
}

/// The launch state. iOS paints the brand navy first (launch-screen colour), so
/// only the lockup and the artwork animate in — no flash, no visible hand-off.
struct SplashView: View {
    @State private var appeared = false
    @State private var floating = false

    var body: some View {
        ZStack {
            Brand.navy.ignoresSafeArea()

            // The brand's illustrations and the teal swell along the bottom
            // edge, as on the kit's splash.
            VStack {
                Spacer()
                ZStack(alignment: .bottom) {
                    BottomSwell()
                        .offset(y: appeared ? 0 : 90)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.85, dampingFraction: 0.85), value: appeared)
                    ScatteredArtField(appeared: appeared, floating: floating)
                        .padding(.bottom, 26)
                }
                .frame(height: 400)
            }
            .ignoresSafeArea()

            BrandLockup(appeared: appeared)
                .offset(y: -40)
        }
        .onAppear {
            appeared = true
            floating = true
        }
    }
}

/// The two overlapping teal crescents that close the launch screen.
private struct BottomSwell: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .bottomLeading) {
                Ellipse()
                    .fill(Brand.teal.opacity(0.22))
                    .frame(width: w * 1.6, height: w * 0.62)
                    .offset(x: -w * 0.6, y: w * 0.30)
                Ellipse()
                    .fill(Brand.teal.opacity(0.42))
                    .frame(width: w * 1.3, height: w * 0.50)
                    .offset(x: -w * 0.2, y: w * 0.36)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}
