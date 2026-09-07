import SwiftUI

// MARK: - Colour construction

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A token that resolves per appearance. Splitme is designed dark-first, so
    /// the dark value is the intended one and the light value is the adaptation.
    static func adaptive(dark: UInt32, light: UInt32, opacity: Double = 1) -> Color {
        Color(UIColor { trait in
            let hex = trait.userInterfaceStyle == .light ? light : dark
            return UIColor(Color(hex: hex, opacity: opacity))
        })
    }
}

// MARK: - Tokens

/// Split Me's brand palette.
///
///  #00D4C4 teal    — primary action, the mark's leading half
///  #1A1F6B navy    — the brand ground; here it is the *raised* surface, with
///                    the canvas sitting deeper so cards read as lifted
///  #A7F0E6 mint    — highlights and the mark's trailing half
///  #FF6B6B coral   — warnings, discounts, anything that needs to interrupt
///  #FFFFFF white   — primary text on navy
enum Brand {
    static let teal  = Color(hex: 0x00D4C4)
    static let navy  = Color(hex: 0x1A1F6B)
    static let mint  = Color(hex: 0xA7F0E6)
    static let coral = Color(hex: 0xFF6B6B)
    static let white = Color(hex: 0xFFFFFF)
}

enum Theme {

    // Surfaces — the navy is stepped down twice below the brand value so that
    // #1A1F6B itself can be used for lifted elements without going flat.
    static let canvas        = Color.adaptive(dark: 0x0B0E33, light: 0xF3F6FA)
    static let surface       = Color.adaptive(dark: 0x141a52, light: 0xFFFFFF)
    static let surfaceRaised = Color.adaptive(dark: 0x1A1F6B, light: 0xFFFFFF)
    static let surfaceSunken = Color.adaptive(dark: 0x080A28, light: 0xE7ECF4)

    static let hairline       = Color.adaptive(dark: 0xA7F0E6, light: 0x1A1F6B, opacity: 0.12)
    static let hairlineStrong = Color.adaptive(dark: 0xA7F0E6, light: 0x1A1F6B, opacity: 0.24)

    // Text — secondary and tertiary are navy-tinted rather than neutral grey,
    // so nothing looks washed out against the ground.
    static let textPrimary   = Color.adaptive(dark: 0xFFFFFF, light: 0x11154A)
    static let textSecondary = Color.adaptive(dark: 0x9FA8DC, light: 0x5A6284)
    static let textTertiary  = Color.adaptive(dark: 0x6C77B5, light: 0x8B93AE)

    // Brand
    static let accent         = Color.adaptive(dark: 0x00D4C4, light: 0x00A89C)
    static let accentSoft     = Color.adaptive(dark: 0x00D4C4, light: 0x00A89C, opacity: 0.18)
    static let accentTrailing = Color.adaptive(dark: 0xA7F0E6, light: 0x00D4C4)
    /// Text and icons that sit *on* the accent. Teal is bright: white on it is
    /// barely 1.9:1, so the brand navy carries the label instead.
    static let onAccent       = Color.adaptive(dark: 0x081046, light: 0xFFFFFF)

    static let positive = Color.adaptive(dark: 0x00D4C4, light: 0x00897E)
    static let warning  = Color.adaptive(dark: 0xFFB454, light: 0xB87400)
    static let negative = Color.adaptive(dark: 0xFF6B6B, light: 0xD94242)
    static let coral    = Color.adaptive(dark: 0xFF6B6B, light: 0xE04F4F)

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [Brand.teal, Color(hex: 0x00B5C9)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// A soft teal bloom used behind the hero total.
    static var heroGradient: LinearGradient {
        LinearGradient(colors: [Brand.teal.opacity(0.22), Brand.mint.opacity(0.07), .clear],
                       startPoint: .topLeading, endPoint: .bottom)
    }

    // MARK: Typography

    /// Rounded, monospaced-digit numerals: money should never jitter as it
    /// recalculates, and rounded reads friendlier than SF's default figures.
    static func number(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    /// Semibold and above is a heading (Poppins); everything lighter is body
    /// text (Inter). Both fall back to SF Rounded when the files are absent.
    static func label(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        weight >= .semibold ? BrandFont.heading(size, weight: weight)
                            : BrandFont.body(size, weight: weight)
    }

    // MARK: Metrics

    static let corner: CGFloat = 18
    static let cornerSmall: CGFloat = 12
    static let gutter: CGFloat = 16
}

// MARK: - Card

struct CardBackground: ViewModifier {
    var raised: Bool = false
    var corner: CGFloat = Theme.corner
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(raised ? Theme.surfaceRaised : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func card(raised: Bool = false, corner: CGFloat = Theme.corner,
              padding: CGFloat = 16) -> some View {
        modifier(CardBackground(raised: raised, corner: corner, padding: padding))
    }

    /// Standard row treatment inside a `List` whose own chrome is hidden.
    func plainListRow(insets: EdgeInsets = EdgeInsets(top: 5, leading: Theme.gutter,
                                                      bottom: 5, trailing: Theme.gutter)) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(insets)
    }

    /// Applies the dark canvas behind a scrolling container, gives every screen
    /// a Done button above the keyboard, and dismisses on a drag.
    ///
    /// `.immediately` rather than `.interactively`: the interactive variant
    /// drags the keyboard with your finger and can end up not dismissing at
    /// all, which reads as broken.
    func splitmeCanvas() -> some View {
        self
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.canvas.ignoresSafeArea())
            .keyboardDismissBar()
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(16, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .padding(.vertical, 15)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(
                Capsule().fill(Theme.brandGradient)
            )
            .overlay(
                Capsule().strokeBorder(Brand.mint.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Theme.accent.opacity(configuration.isPressed ? 0.14 : 0.38),
                    radius: configuration.isPressed ? 6 : 16, y: 6)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(15, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, 13)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 20)
            .background(Capsule().fill(Theme.surfaceRaised))
            .overlay(Capsule().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Segmented pills

/// Replaces `.pickerStyle(.segmented)`, whose grey chrome fights the dark canvas.
struct SegmentedPills<Value: Hashable & Identifiable>: View {
    var options: [Value]
    /// Returns a key, not a string: `Text(someString)` is never localized.
    var title: (Value) -> LocalizedStringKey
    @Binding var selection: Value

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(Theme.label(14, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.onAccent : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Theme.brandGradient)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.surfaceSunken))
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

/// Letter-spacing is a Latin typographic device. Applied to Arabic it breaks
/// the cursive joins, so "السعر" renders as "ا لسعر". This applies it only when
/// the layout is left-to-right.
private struct LatinTracking: ViewModifier {
    @Environment(\.layoutDirection) private var direction
    var amount: CGFloat

    func body(content: Content) -> some View {
        content.tracking(direction == .leftToRight ? amount : 0)
    }
}

extension View {
    func latinTracking(_ amount: CGFloat) -> some View {
        modifier(LatinTracking(amount: amount))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    var title: LocalizedStringKey
    /// Already-formatted data, such as a total — never looked up.
    var trailing: String?

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.label(12, weight: .semibold))
                .textCase(.uppercase)
                .latinTracking(0.8)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            if let trailing {
                Text(verbatim: trailing)
                    .font(Theme.number(13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
