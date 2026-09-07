import SwiftUI

struct SharesSection: View {
    var bill: Bill

    @State private var expanded: Set<UUID> = []
    @State private var shareText: SharePayload?

    var body: some View {
        let result = bill.result
        let maxTotal = result.shares.map(\.total).max() ?? 1

        ScrollView {
            if bill.items.isEmpty {
                VStack(spacing: 20) {
                    Spacer().frame(height: 60)
                    EmptyStateView(title: "Nothing to split yet",
                                   message: "Scan the receipt or add a few items, then everyone's share appears here.") {
                        BrandArtView(art: .receipt, width: 140)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    // One illustration, at the top, and only once every item has
                    // an owner — so it means "done", not decoration.
                    if result.unassignedItemNames.isEmpty {
                        BrandArtView(art: .highFive, width: 150)
                            .padding(.top, 2)
                    }

                    HeroTotal(result: result, currencyCode: bill.currencyCode,
                              people: result.shares.count)

                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader(title: "Each person pays")
                            .padding(.horizontal, 4)
                            .padding(.bottom, 6)

                        VStack(spacing: 0) {
                            ForEach(Array(result.shares.enumerated()), id: \.element.id) { index, share in
                                ShareRow(
                                    share: share,
                                    currencyCode: bill.currencyCode,
                                    colorIndex: colorIndex(for: share.id),
                                    proportion: maxTotal > 0 ? Double(share.total) / Double(maxTotal) : 0,
                                    isExpanded: expanded.contains(share.id),
                                    chargeMode: bill.chargeMode
                                ) {
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                        if expanded.contains(share.id) { expanded.remove(share.id) }
                                        else { expanded.insert(share.id) }
                                    }
                                } onShare: {
                                    shareText = SharePayload(text: BillSharing.message(for: share, bill: bill))
                                }

                                if index < result.shares.count - 1 {
                                    Divider().overlay(Theme.hairline)
                                }
                            }
                        }
                        .card(padding: 0)
                    }

                    VStack(spacing: 11) {
                        SectionHeader(title: "Bill total")
                        TotalsRows(result: result, currencyCode: bill.currencyCode,
                                   chargeMode: bill.chargeMode)
                    }
                    .card()

                    Button {
                        shareText = SharePayload(text: BillSharing.summary(for: bill))
                    } label: {
                        Label("Share with friends", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 2)

                    Text("Shares always add up to the total — leftover pennies are handed out one at a time, never rounded away.")
                        .font(Theme.label(12, weight: .regular))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)

                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 28)
            }
        }
        .splitmeCanvas()
        .sheet(item: $shareText) { payload in
            ShareSheet(text: payload.text)
        }
    }

    private func colorIndex(for id: UUID) -> Int {
        bill.participants.first { $0.id == id }?.colorIndex ?? 0
    }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let text: String
}

/// The number people actually came here for.
private struct HeroTotal: View {
    var result: SplitResult
    var currencyCode: String
    var people: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("Bill total")
                .font(Theme.label(11, weight: .semibold))
                .textCase(.uppercase)
                .latinTracking(1.4)
                .foregroundStyle(Theme.textTertiary)
            Text(verbatim: Money.string(result.grandTotal, currencyCode: currencyCode))
                .font(Theme.number(40, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("across \(people) people")
                .font(Theme.label(13, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.heroGradient)
                }
        }
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Theme.hairlineStrong, lineWidth: 1))
    }
}

private struct ShareRow: View {
    var share: PersonShare
    var currencyCode: String
    var colorIndex: Int
    var proportion: Double
    var isExpanded: Bool
    var chargeMode: ChargeMode
    var onTap: () -> Void
    var onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Avatar(name: share.name, colorIndex: colorIndex, size: 38)

                    VStack(alignment: .leading, spacing: 9) {
                        Text(verbatim: share.name)
                            .font(Theme.label(15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        // A bar makes an uneven split visible before anyone has
                        // to compare the numbers themselves.
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.surfaceSunken).frame(height: 5)
                                Capsule()
                                    .fill(PersonPalette.gradient(for: colorIndex))
                                    .frame(width: max(5, geo.size.width * proportion), height: 5)
                            }
                        }
                        .frame(height: 5)
                    }

                    Text(verbatim: Money.string(share.total, currencyCode: currencyCode))
                        .font(Theme.number(17, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(share.lines.enumerated()), id: \.offset) { _, line in
                        AmountRow(label: LocalizedStringKey(line.name), amount: line.amount,
                                  currencyCode: currencyCode, emphasis: .quiet)
                    }
                    Divider().overlay(Theme.hairline)
                    AmountRow(label: "Items", amount: share.itemsSubtotal, currencyCode: currencyCode)
                    if chargeMode == .addedOnTop {
                        if share.service != 0 {
                            AmountRow(label: "Service", amount: share.service, currencyCode: currencyCode)
                        }
                        if share.tax != 0 {
                            AmountRow(label: "Tax", amount: share.tax, currencyCode: currencyCode)
                        }
                    }
                    if share.extra != 0 {
                        AmountRow(label: "Extra", amount: share.extra, currencyCode: currencyCode)
                    }
                    if share.discount != 0 {
                        AmountRow(label: "Discount", amount: -share.discount, currencyCode: currencyCode)
                    }

                    Button(action: onShare) {
                        Label("Send \(share.name) their share", systemImage: "paperplane.fill")
                            .font(Theme.label(13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.leading, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
    }
}

/// Plain-text messages so a share can go through any messaging app. Laid out
/// as: the bill's total and its charge breakdown, then one block per person
/// giving their total followed by what they actually ordered — each block
/// divided by a rule so it stays readable in a chat bubble.
enum BillSharing {
    private static let rule = "-----"

    static func summary(for bill: Bill) -> String {
        let result = bill.result
        let code = bill.currencyCode
        var out: [String] = []

        out.append("\(bill.displayTitle) · Billy")
        out.append(rule)

        // The whole bill first: total, then how it is made up.
        out.append("TOTAL: \(Money.string(result.grandTotal, currencyCode: code))")
        out.append("Items: \(Money.string(result.itemsSubtotal, currencyCode: code))")
        if bill.chargeMode == .addedOnTop {
            if result.service != 0 {
                out.append("Service (\(percentText(bill.servicePercent))): "
                           + Money.string(result.service, currencyCode: code))
            }
            if result.tax != 0 {
                out.append("Tax (\(percentText(bill.taxPercent))): "
                           + Money.string(result.tax, currencyCode: code))
            }
        } else {
            out.append("Tax & service included in the prices")
        }
        if result.extra != 0 {
            out.append("Extra: \(Money.string(result.extra, currencyCode: code))")
        }
        if result.discount != 0 {
            out.append("Discount: -\(Money.string(result.discount, currencyCode: code))")
        }

        // Then a block per person: their total, then their order.
        for share in result.shares {
            out.append(rule)
            out.append(contentsOf: block(for: share, bill: bill, totalLabel: share.name))
        }
        out.append(rule)

        return out.joined(separator: "\n")
    }

    /// One person's own message — the same block, addressed to them.
    static func message(for share: PersonShare, bill: Bill) -> String {
        var out: [String] = []
        out.append("\(bill.displayTitle) · Billy")
        out.append(rule)
        out.append(contentsOf: block(for: share, bill: bill, totalLabel: "\(share.name), you owe"))
        out.append(rule)
        return out.joined(separator: "\n")
    }

    /// `total, then his order` — the person's figure first so it is the thing
    /// they see, with the itemisation underneath it as the justification.
    private static func block(for share: PersonShare, bill: Bill,
                              totalLabel: String) -> [String] {
        let code = bill.currencyCode
        var out: [String] = []

        out.append("\(totalLabel): \(Money.string(share.total, currencyCode: code))")

        for line in share.lines where line.amount != 0 {
            out.append("  • \(line.name): \(Money.string(line.amount, currencyCode: code))")
        }
        if bill.chargeMode == .addedOnTop {
            if share.service != 0 {
                out.append("  Service: \(Money.string(share.service, currencyCode: code))")
            }
            if share.tax != 0 {
                out.append("  Tax: \(Money.string(share.tax, currencyCode: code))")
            }
        }
        if share.extra != 0 {
            out.append("  Extra: \(Money.string(share.extra, currencyCode: code))")
        }
        if share.discount != 0 {
            out.append("  Discount: -\(Money.string(share.discount, currencyCode: code))")
        }
        return out
    }

    private static func percentText(_ percent: Double) -> String {
        percent == percent.rounded() ? "\(Int(percent))%" : String(format: "%.2f%%", percent)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
