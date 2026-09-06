import SwiftUI

/// The languages Splitme ships in. English and Arabic, switched inside the app
/// rather than only through iOS Settings, because people split bills with
/// friends who read different scripts and expect to flip in one tap.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case arabic = "ar"

    var id: String { rawValue }

    static let storageKey = "splitmeLanguage"

    /// What the system asks for on a first launch.
    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ar") ? .arabic : .english
    }

    /// Arabic with Latin digits: receipts, menus and price tags in Egypt print
    /// Western numerals, and money that does not match the paper in your hand
    /// is money people distrust. Change `numbers=latn` to `arab` for ٠١٢٣.
    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en_US")
        case .arabic:  return Locale(identifier: "ar_EG@numbers=latn")
        }
    }

    var layoutDirection: LayoutDirection {
        self == .arabic ? .rightToLeft : .leftToRight
    }

    /// This language's own name, in its own script.
    var endonym: String {
        switch self {
        case .english: return "English"
        case .arabic:  return "العربية المصرية"
        }
    }

    /// A short badge for the language the toggle would switch *to*.
    var switchTargetBadge: String {
        other.rawValue == "ar" ? "ع" : "EN"
    }

    var other: AppLanguage {
        self == .english ? .arabic : .english
    }
}

/// Applies the chosen language to everything below it: string lookup follows
/// the locale, and the whole layout mirrors for Arabic.
struct LanguageProvider: ViewModifier {
    @AppStorage(AppLanguage.storageKey) private var stored = AppLanguage.systemDefault.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: stored) ?? .english
    }

    func body(content: Content) -> some View {
        content
            .environment(\.locale, language.locale)
            .environment(\.layoutDirection, language.layoutDirection)
            .id(language)   // rebuild cleanly when the direction flips
    }

}

extension View {
    func splitmeLanguage() -> some View { modifier(LanguageProvider()) }
}

/// The toolbar control. Shows the language you would switch *to*, so the tap is
/// predictable — a bare globe never tells you where you are going.
struct LanguageToggle: View {
    @AppStorage(AppLanguage.storageKey) private var stored = AppLanguage.systemDefault.rawValue

    private var language: AppLanguage { AppLanguage(rawValue: stored) ?? .english }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                stored = language.other.rawValue
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .semibold))
                Text(language.switchTargetBadge)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.accentSoft))
        }
        .buttonStyle(.plain)
        // Always announced in the target language's own words.
        .accessibilityLabel(Text(verbatim: language.other.endonym))
        .accessibilityHint(Text("Switch the app language", bundle: .main))
    }
}
