import SwiftUI

// MARK: - Avatars

struct Avatar: View {
    var name: String
    var colorIndex: Int
    var size: CGFloat = 34
    var filled: Bool = true

    var body: some View {
        Text(PersonPalette.initials(name))
            .font(Theme.label(size * 0.4, weight: .bold))
            .foregroundStyle(filled ? Brand.navy : PersonPalette.color(for: colorIndex))
            .frame(width: size, height: size)
            .background {
                if filled {
                    Circle().fill(PersonPalette.gradient(for: colorIndex))
                } else {
                    Circle().fill(PersonPalette.color(for: colorIndex).opacity(0.14))
                }
            }
            .overlay {
                if !filled {
                    Circle().strokeBorder(PersonPalette.color(for: colorIndex).opacity(0.45), lineWidth: 1)
                }
            }
    }
}

/// A tappable avatar used to assign a person to an item. Unselected reads as an
/// outline so a glance down the list shows exactly which rows are still open.
struct PersonChip: View {
    var name: String
    var colorIndex: Int
    var isSelected: Bool
    var action: () -> Void

    var size: CGFloat = 34

    var body: some View {
        Button(action: action) {
            // The tick is placed *within* the chip's bounds rather than offset
            // outside them, so it can never be clipped by the row or overlap a
            // neighbouring chip.
            ZStack(alignment: .bottomTrailing) {
                Avatar(name: name, colorIndex: colorIndex, size: size, filled: isSelected)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.26, weight: .black))
                        .foregroundStyle(Brand.navy)
                        .padding(size * 0.075)
                        .background(Circle().fill(.white))
                        .overlay(Circle().strokeBorder(Brand.navy.opacity(0.15), lineWidth: 0.5))
                }
            }
            .frame(width: size + 6, height: size + 6, alignment: .center)
            .scaleEffect(isSelected ? 1 : 0.95)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(name)
        .accessibilityValue(isSelected ? "assigned" : "not assigned")
    }
}

/// Lays subviews out left-to-right, wrapping onto a new line when the width
/// runs out. Used for the assignee chips so that *every* person on the bill is
/// visible on every item — a horizontal scroller hid the people off the edge,
/// which is exactly the thing you need to see to assign an item.
struct WrapLayout: Layout {
    var spacing: CGFloat = 9
    var lineSpacing: CGFloat = 9
    /// `Layout` cannot read the environment, so the caller passes the direction
    /// in; without this the chips would still run left-to-right in Arabic.
    var direction: LayoutDirection = .leftToRight

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func lines(for subviews: Subviews, width: CGFloat) -> [Line] {
        var result: [Line] = []
        var current = Line()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if needed > width, !current.indices.isEmpty {
                result.append(current)
                current = Line()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.width = needed
                current.height = max(current.height, size.height)
                current.indices.append(index)
            }
        }
        if !current.indices.isEmpty { result.append(current) }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let laid = lines(for: subviews, width: width)
        let height = laid.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(laid.count - 1, 0))
        let widest = laid.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let leftToRight = direction == .leftToRight
        var y = bounds.minY

        for line in lines(for: subviews, width: bounds.width) {
            var x = leftToRight ? bounds.minX : bounds.maxX
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: leftToRight ? x : x - size.width,
                                y: y + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += leftToRight ? (size.width + spacing) : -(size.width + spacing)
            }
            y += line.height + lineSpacing
        }
    }
}

/// A compact overlapping cluster, used on the bill cards.
struct AvatarCluster: View {
    var names: [String]
    var colorIndexes: [Int]
    var limit: Int = 4

    var body: some View {
        HStack(spacing: -9) {
            ForEach(Array(names.prefix(limit).enumerated()), id: \.offset) { index, name in
                Avatar(name: name,
                       colorIndex: index < colorIndexes.count ? colorIndexes[index] : index,
                       size: 26)
                    .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 2))
                    .zIndex(Double(limit - index))
            }
            if names.count > limit {
                Text(verbatim: "+\(names.count - limit)")
                    .font(Theme.label(11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.surfaceRaised))
                    .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 2))
            }
        }
    }
}

// MARK: - Fields

/// A decimal text field that reads and writes integer minor units.
struct AmountField: View {
    var title: String
    @Binding var minor: Minor
    var currencyCode: String
    var alignment: TextAlignment = .trailing

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(title, text: $text)
            .font(Theme.number(16))
            .foregroundStyle(Theme.textPrimary)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(alignment)
            .focused($focused)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(focused ? Theme.accentSoft : Theme.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(focused ? Theme.accent.opacity(0.6) : Theme.hairline, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: focused)
            .onAppear { text = Money.editable(minor) }
            .onChange(of: focused) { _, isFocused in
                if isFocused {
                    if minor == 0 { text = "" }
                } else {
                    minor = Money.parse(text) ?? 0
                    text = Money.editable(minor)
                }
            }
            .onChange(of: text) { _, newValue in
                if focused, let parsed = Money.parse(newValue) { minor = parsed }
            }
            .onChange(of: minor) { _, newValue in
                if !focused { text = Money.editable(newValue) }
            }
    }
}

/// A percentage field with tappable presets — most bills use a house rate, so
/// typing should be the exception.
struct PercentField: View {
    var title: LocalizedStringKey
    var systemImage: String
    @Binding var value: Double
    var presets: [Double]

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.accentSoft))
                Text(title)
                    .font(Theme.label(15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                HStack(spacing: 2) {
                    TextField("0", value: $value, format: .number.precision(.fractionLength(0...2)))
                        .font(Theme.number(17))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused)
                        .frame(width: 46)
                    Text("%")
                        .font(Theme.number(15))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(focused ? Theme.accentSoft : Theme.surfaceSunken))
            }

            HStack(spacing: 7) {
                ForEach(presets, id: \.self) { preset in
                    let isOn = abs(value - preset) < 0.001
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { value = preset }
                    } label: {
                        (preset == 0 ? Text("None") : Text(verbatim: "\(Int(preset))%"))
                            .font(Theme.label(13, weight: .semibold))
                            .foregroundStyle(isOn ? .white : Theme.textSecondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(isOn ? Theme.accent : Theme.surfaceSunken))
                            .overlay(Capsule().strokeBorder(isOn ? .clear : Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isOn)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Rows

/// Label / amount line used in every breakdown.
struct AmountRow: View {
    var label: LocalizedStringKey
    var amount: Minor
    var currencyCode: String
    var emphasis: Emphasis = .normal

    enum Emphasis { case normal, quiet, total }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(emphasis == .total ? Theme.label(16, weight: .semibold) : Theme.label(14, weight: .regular))
                .foregroundStyle(emphasis == .quiet ? Theme.textTertiary : Theme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(verbatim: Money.string(amount, currencyCode: currencyCode))
                .font(emphasis == .total ? Theme.number(19, weight: .bold) : Theme.number(14))
                .foregroundStyle(emphasis == .total ? Theme.textPrimary
                                 : emphasis == .quiet ? Theme.textTertiary : Theme.textPrimary)
        }
    }
}

// MARK: - Empty state

struct EmptyStateView<Artwork: View>: View {
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    @ViewBuilder var artwork: () -> Artwork

    var body: some View {
        VStack(spacing: 20) {
            artwork()
            VStack(spacing: 7) {
                Text(title)
                    .font(Theme.label(20, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(Theme.label(14, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity)
    }
}

extension EmptyStateView where Artwork == GlyphArtwork {
    /// For the smaller empty states, where a full illustration would shout.
    init(icon: String, title: LocalizedStringKey, message: LocalizedStringKey) {
        self.init(title: title, message: message) { GlyphArtwork(icon: icon) }
    }
}

struct GlyphArtwork: View {
    var icon: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Brand.mint.opacity(0.14))
                .frame(width: 92, height: 92)
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.accent)
        }
    }
}

/// Inline notice — used for the unassigned-items warning and the scan mismatch.
struct NoticeBanner: View {
    var icon: String
    var title: LocalizedStringKey
    var detail: LocalizedStringKey?
    var tint: Color = Theme.warning

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.label(14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let detail {
                    Text(detail)
                        .font(Theme.label(13, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
            .fill(tint.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
            .strokeBorder(tint.opacity(0.28), lineWidth: 1))
    }
}
