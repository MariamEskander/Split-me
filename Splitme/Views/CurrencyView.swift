import SwiftUI

/// A standalone converter. Deliberately usable with no signal: the last fetched
/// snapshot is cached and labelled with its date, so the number on screen is
/// always attributable to a moment in time.
struct CurrencyView: View {
    @Environment(\.locale) private var locale
    @State private var store = RatesStore()
    @State private var amountMinor: Minor = 10000
    @State private var from = AppDefaults.currencyCode
    @State private var to = "USD"
    @State private var picking: Side?

    private enum Side: Identifiable {
        case from, to
        var id: Int { self == .from ? 0 : 1 }
    }

    private var amount: Double { Double(amountMinor) / 100 }

    private var converted: Double? {
        store.snapshot?.convert(amount, from: from, to: to)
    }

    private var unitRate: Double? {
        store.snapshot?.rate(from: from, to: to)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                    .onTapGesture { KeyboardDismisser.dismiss() }
                ScrollView {
                    VStack(spacing: 14) {
                        resultCard
                        converterCard
                        if let unitRate { rateCard(unitRate) }
                        statusCard
                    }
                    .padding(Theme.gutter)
                    .padding(.bottom, 24)
                }
                .splitmeCanvas()
            }
            .navigationTitle("Currency")
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { LanguageToggle() }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await store.refresh(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityLabel("Refresh rates")
                }
            }
            .sheet(item: $picking) { side in
                CurrencyPicker(
                    codes: store.snapshot?.codes ?? [],
                    selection: side == .from ? from : to
                ) { code in
                    if side == .from { from = code } else { to = code }
                }
            }
            .task {
                // Default the target to something other than the home currency.
                if to == from { to = from == "USD" ? AppDefaults.currencyCode : "USD" }
                await store.refresh()
            }
        }
    }

    // MARK: Cards

    private var resultCard: some View {
        VStack(spacing: 6) {
            Text(verbatim: to.currencyName(in: locale).uppercased())
                .font(Theme.label(11, weight: .semibold))
                .latinTracking(1.4)
                .foregroundStyle(Theme.textTertiary)

            if let converted {
                Text(verbatim: Self.format(converted, code: to))
                    .font(Theme.number(38, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else if case .loading = store.status {
                ProgressView().tint(Theme.accent).frame(height: 46)
            } else {
                Text("—")
                    .font(Theme.number(38, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }

            Text(verbatim: "\(Self.format(amount, code: from)) \(from)")
                .font(Theme.label(13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.heroGradient))
        }
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Theme.hairlineStrong, lineWidth: 1))
    }

    private var converterCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Amount")
                    .font(Theme.label(14))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                AmountField(title: "0.00", minor: $amountMinor, currencyCode: from)
                    .frame(width: 130)
            }

            Divider().overlay(Theme.hairline)

            HStack(spacing: 10) {
                currencyButton(code: from) { picking = .from }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        let old = from
                        from = to
                        to = old
                    }
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.brandGradient))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap currencies")

                currencyButton(code: to) { picking = .to }
            }
        }
        .card()
    }

    private func currencyButton(code: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: code)
                    .font(Theme.number(17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(verbatim: code.currencyName(in: locale))
                    .font(Theme.label(11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.surfaceSunken))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func rateCard(_ rate: Double) -> some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Rate")
            HStack {
                Text(verbatim: "1 \(from)")
                    .font(Theme.label(14))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(verbatim: "\(Self.rateText(rate)) \(to)")
                    .font(Theme.number(15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Divider().overlay(Theme.hairline)
            HStack {
                Text(verbatim: "1 \(to)")
                    .font(Theme.label(14))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(verbatim: "\(Self.rateText(1 / rate)) \(from)")
                    .font(Theme.number(15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .card()
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(spacing: 10) {
            if case .failed(let message) = store.status {
                NoticeBanner(
                    icon: "wifi.slash",
                    title: store.snapshot == nil
                        ? "Rates could not be loaded"
                        : "Showing the last rates saved on this device",
                    detail: LocalizedStringKey(message),
                    tint: store.snapshot == nil ? Theme.coral : Theme.warning
                )
            } else if let snapshot = store.snapshot, snapshot.isStale {
                NoticeBanner(
                    icon: "clock.arrow.circlepath",
                    title: "These rates may be out of date",
                    detail: "Saved \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)). Pull refresh to update."
                )
            }

            if let snapshot = store.snapshot {
                VStack(spacing: 4) {
                    Text("Published \(snapshot.publishedAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("\(snapshot.rates.count) currencies")
                    Text(verbatim: RatesProvider.attribution)
                }
                .font(Theme.label(11))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }

            if store.snapshot == nil, case .failed = store.status {
                Button("Try again") {
                    Task { await store.refresh(force: true) }
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
    }

    // MARK: Formatting

    /// Honours each currency's own fraction digits — KWD has three, JPY none.
    static func format(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.currencySymbol = ""
        return (formatter.string(from: NSNumber(value: value)) ?? "\(value)")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Rates need more precision than money: 1 EGP = 0.0196 USD.
    static func rateText(_ rate: Double) -> String {
        let digits = rate >= 100 ? 2 : rate >= 1 ? 4 : 6
        return String(format: "%.\(digits)f", rate)
    }
}

/// 160-plus codes need a search field, not a wheel.
private struct CurrencyPicker: View {
    @Environment(\.locale) private var locale
    var codes: [String]
    var selection: String
    var onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return codes }
        return codes.filter {
            $0.localizedCaseInsensitiveContains(trimmed)
                || $0.currencyName(in: locale).localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                    .onTapGesture { KeyboardDismisser.dismiss() }
                List {
                    ForEach(filtered, id: \.self) { code in
                        Button {
                            onPick(code)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text(verbatim: code)
                                    .font(Theme.number(15, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 52, alignment: .leading)
                                Text(verbatim: code.currencyName(in: locale))
                                    .font(Theme.label(14))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                if code == selection {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                        .plainListRow(insets: EdgeInsets(top: 4, leading: Theme.gutter,
                                                         bottom: 4, trailing: Theme.gutter))
                    }
                }
                .listStyle(.plain)
                .splitmeCanvas()
                .overlay {
                    if filtered.isEmpty {
                        EmptyStateView(icon: "magnifyingglass",
                                       title: "No match",
                                       message: "No currency matches “\(query)”.")
                    }
                }
            }
            .searchable(text: $query, prompt: "Search currencies")
            .navigationTitle("Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
