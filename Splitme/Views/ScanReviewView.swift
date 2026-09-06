import SwiftUI

/// Every scan lands here first. Text recognition gets names and prices wrong on
/// creased or faded receipts, so nothing reaches the bill until it is checked.
struct ScanReviewView: View {
    struct Charges {
        var chargeMode: ChargeMode = .addedOnTop
        var taxPercent: Double?
        var servicePercent: Double?
        var discountMinor: Minor?
        var extraMinor: Minor?
    }

    let receipt: ParsedReceipt
    let currencyCode: String
    var onApply: ([ParsedItem], Charges) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var rows: [ScanRow] = []
    @State private var charges = Charges()
    @State private var applyCharges = true
    @State private var showingRawText = false

    private var included: [ScanRow] {
        rows.filter { $0.include && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }
    private var includedTotal: Minor { included.reduce(0) { $0 + $1.lineTotal } }

    /// Gap between what was picked up and the total printed on the receipt.
    private var gap: Minor? {
        guard let printed = receipt.totalMinor else { return nil }
        let service = charges.chargeMode == .addedOnTop
            ? Money.percent(charges.servicePercent ?? 0, of: includedTotal) : 0
        let tax = charges.chargeMode == .addedOnTop
            ? Money.percent(charges.taxPercent ?? 0, of: includedTotal + service) : 0
        let computed = includedTotal + service + tax
            + (charges.extraMinor ?? 0) - (charges.discountMinor ?? 0)
        let diff = printed - computed
        return abs(diff) <= 2 ? nil : diff   // tolerate the receipt's own rounding
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                    .onTapGesture { KeyboardDismisser.dismiss() }

                ScrollView {
                    VStack(spacing: 14) {
                        // What matched, and whether it adds up
                        MatchSummary(itemCount: included.count,
                                     itemsTotal: includedTotal,
                                     printedTotal: receipt.totalMinor,
                                     gap: gap,
                                     currencyCode: currencyCode)

                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Items found",
                                          trailing: Money.string(includedTotal,
                                                                 currencyCode: currencyCode))
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach($rows) { $row in
                                    ReviewRow(row: $row, currencyCode: currencyCode)
                                    Divider().overlay(Theme.hairline)
                                }

                                Button {
                                    withAnimation {
                                        rows.append(ScanRow(name: "", quantity: 1, priceMinor: 0))
                                    }
                                } label: {
                                    Label("Add a missing item", systemImage: "plus")
                                        .font(Theme.label(14, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 13)
                                }
                                .buttonStyle(.plain)
                            }
                            .card(padding: 0)

                            Text("Check the names and prices against the paper — swipe a row away or untick anything that is not an item.")
                                .font(Theme.label(12))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.horizontal, 4)
                        }

                        // Charges
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(isOn: $applyCharges) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use the charges it found")
                                        .font(Theme.label(15, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Fine-tune everything on the Charges tab afterwards.")
                                        .font(Theme.label(12))
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                            .tint(Theme.accent)

                            if applyCharges {
                                Divider().overlay(Theme.hairline)
                                ForEach(ChargeMode.allCases) { mode in
                                    Button {
                                        withAnimation(.easeOut(duration: 0.18)) {
                                            charges.chargeMode = mode
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: charges.chargeMode == mode
                                                  ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 17))
                                                .foregroundStyle(charges.chargeMode == mode
                                                                 ? Theme.accent : Theme.textTertiary)
                                            Text(LocalizedStringKey(mode.label))
                                                .font(Theme.label(14))
                                                .foregroundStyle(Theme.textPrimary)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }

                                Divider().overlay(Theme.hairline)
                                chargeLine("Service", percent: charges.servicePercent,
                                           amount: receipt.serviceMinor)
                                chargeLine("Tax", percent: charges.taxPercent,
                                           amount: receipt.taxMinor)
                                if let discount = charges.discountMinor, discount != 0 {
                                    AmountRow(label: "Discount", amount: -discount,
                                              currencyCode: currencyCode)
                                }
                                if let extra = charges.extraMinor, extra != 0 {
                                    AmountRow(label: "Extra", amount: extra,
                                              currencyCode: currencyCode)
                                }
                            }
                        }
                        .card()

                        Button("See the raw scanned text") { showingRawText = true }
                            .font(Theme.label(13, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 2)
                    }
                    .padding(Theme.gutter)
                    .padding(.bottom, 80)
                }
                .splitmeCanvas()

                // Sticky commit bar — the count is the whole decision.
                VStack {
                    Spacer()
                    Button {
                        let items = included.map {
                            ParsedItem(name: $0.name.trimmingCharacters(in: .whitespaces),
                                       quantity: $0.quantity,
                                       unitPriceMinor: $0.priceMinor)
                        }
                        onApply(items, applyCharges ? charges : Charges())
                        dismiss()
                    } label: {
                        Text(included.isEmpty
                             ? "Nothing selected"
                             : "Add \(included.count) items to the bill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(included.isEmpty)
                    .opacity(included.isEmpty ? 0.45 : 1)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 10)
                    .padding(.top, 12)
                    .background(
                        LinearGradient(colors: [Theme.canvas.opacity(0), Theme.canvas],
                                       startPoint: .top, endPoint: .bottom)
                    )
                }
                .ignoresSafeArea(edges: .bottom)
                .padding(.bottom, 20)
            }
            .navigationTitle("Check the items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .sheet(isPresented: $showingRawText) {
                RawTextView(text: receipt.rawText) { showingRawText = false }
            }
            .onAppear(perform: seed)
        }
        .preferredColorScheme(.dark)
    }

    private func chargeLine(_ label: String, percent: Double?, amount: Minor?) -> some View {
        HStack {
            Text(label)
                .font(Theme.label(14))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if let percent, percent > 0 {
                Text(verbatim: percent == percent.rounded()
                     ? "\(Int(percent))%"
                     : String(format: "%.2f%%", percent))
                    .font(Theme.number(13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accentSoft))
            }
            if let amount, amount != 0 {
                Text(verbatim: Money.string(amount, currencyCode: currencyCode))
                    .font(Theme.number(14))
                    .foregroundStyle(Theme.textPrimary)
            } else if percent == nil {
                Text("not found")
                    .font(Theme.label(13))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func seed() {
        guard rows.isEmpty else { return }
        rows = receipt.items.map {
            ScanRow(name: $0.name, quantity: $0.quantity, priceMinor: $0.unitPriceMinor)
        }
        charges.taxPercent = receipt.taxPercent
        charges.servicePercent = receipt.servicePercent
        charges.discountMinor = receipt.discountMinor
        charges.extraMinor = receipt.tipMinor

        // If the printed total already matches the items alone, the menu prices
        // must have been tax- and service-inclusive.
        if let printed = receipt.totalMinor, receipt.taxMinor != nil || receipt.serviceMinor != nil {
            let itemsOnly = receipt.itemsTotalMinor
            if itemsOnly > 0, abs(printed - itemsOnly) <= 2 {
                charges.chargeMode = .includedInPrices
            }
        }
    }
}

// MARK: - Pieces

private struct MatchSummary: View {
    var itemCount: Int
    var itemsTotal: Minor
    var printedTotal: Minor?
    var gap: Minor?
    var currencyCode: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                stat(value: "\(itemCount)", label: "items read")
                Divider().frame(height: 34).overlay(Theme.hairline)
                stat(value: Money.string(itemsTotal, currencyCode: currencyCode),
                     label: "picked up")
                if let printedTotal {
                    Divider().frame(height: 34).overlay(Theme.hairline)
                    stat(value: Money.string(printedTotal, currencyCode: currencyCode),
                         label: "on receipt")
                }
            }

            if let gap {
                NoticeBanner(
                    icon: "exclamationmark.triangle.fill",
                    title: "Off by \(Money.string(abs(gap), currencyCode: currencyCode))",
                    detail: gap > 0
                        ? "Something is missing, or a price was read too low."
                        : "Something is counted twice, or a price was read too high."
                )
            } else if printedTotal != nil {
                NoticeBanner(
                    icon: "checkmark.seal.fill",
                    title: "Matches the receipt total",
                    detail: nil,
                    tint: Theme.positive
                )
            }
        }
        .card()
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(verbatim: value)
                .font(Theme.number(17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Theme.label(11))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// One editable line of the scan. Kept at file scope so the row view can bind
/// to it directly.
struct ScanRow: Identifiable {
    let id = UUID()
    var include: Bool = true
    var name: String
    var quantity: Int
    var priceMinor: Minor

    var lineTotal: Minor { priceMinor * max(quantity, 1) }
}

private struct ReviewRow: View {
    @Binding var row: ScanRow
    var currencyCode: String

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { row.include.toggle() }
            } label: {
                Image(systemName: row.include ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(row.include ? Theme.accent : Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: row.include)

            TextField("Item name", text: $row.name)
                .font(Theme.label(15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .alignedToReadingEdge(of: row.name)

            if row.quantity > 1 {
                Text("×\(row.quantity)")
                    .font(Theme.number(12, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accentSoft))
            }

            Stepper("", value: $row.quantity, in: 1...99)
                .labelsHidden()
                .fixedSize()
                .scaleEffect(0.82)
                .frame(width: 68)

            AmountField(title: "0.00", minor: $row.priceMinor, currencyCode: currencyCode)
                .frame(width: 84)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .opacity(row.include ? 1 : 0.45)
    }
}

private struct RawTextView: View {
    var text: String
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                    .onTapGesture { KeyboardDismisser.dismiss() }
                ScrollView {
                    Text(text)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .card(padding: 14)
                        .padding(Theme.gutter)
                }
                .splitmeCanvas()
            }
            .navigationTitle("Scanned text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
