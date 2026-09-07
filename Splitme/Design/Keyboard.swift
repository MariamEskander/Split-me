import SwiftUI
import UIKit

extension View {
    /// A **Done** button above the keyboard.
    ///
    /// This is the only guaranteed way out for the amount and percentage
    /// fields: they use `.decimalPad`, which has no Return key at all, so
    /// without this there is literally no key to press. Tapping elsewhere is
    /// not enough either — the canvas sits *behind* a full-screen scroll view,
    /// so taps land on the content, not on the background.
    func keyboardDismissBar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { KeyboardDismisser.dismiss() }
                    .font(Theme.label(16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

enum KeyboardDismisser {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

/// Unicode aligns Latin text to the left, which is correct in isolation but
/// leaves an English item name stranded mid-row on a right-to-left screen — the
/// text sits against the left of its slot with a gap out to the reading edge.
///
/// This pulls Latin content to the reading edge in Arabic by giving the field a
/// left-to-right sub-environment (so `.trailing` means "right" absolutely) and
/// aligning to it. Arabic content is left alone: natural alignment already puts
/// it where it belongs, and forcing it would move it the wrong way.
struct ReadingEdgeAlignment: ViewModifier {
    @Environment(\.layoutDirection) private var direction
    var text: String

    private var isLatinContent: Bool {
        guard let letter = text.first(where: { $0.isLetter }) else { return false }
        return letter.isASCII
    }

    func body(content: Content) -> some View {
        Group {
            if direction == .rightToLeft && isLatinContent {
                content
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(.trailing)
            } else {
                content.multilineTextAlignment(.leading)
            }
        }
    }
}

extension View {
    /// Keeps editable text against the reading edge in both languages.
    func alignedToReadingEdge(of text: String) -> some View {
        modifier(ReadingEdgeAlignment(text: text))
    }
}
