import SwiftUI
import SwiftData

struct BillEditorView: View {
    @Bindable var bill: Bill
    var startByScanning: Bool = false

    @Environment(\.modelContext) private var context
    @State private var tab: Tab

    init(bill: Bill, startByScanning: Bool = false, initialTab: Tab = .items) {
        self.bill = bill
        self.startByScanning = startByScanning
        _tab = State(initialValue: initialTab)
    }

    @State private var showingScanner = false
    @State private var scanState: ScanState = .idle
    @State private var scanError: String?

    enum Tab: String, CaseIterable, Identifiable {
        case items = "Items"
        case charges = "Charges"
        case shares = "Shares"
        var id: String { rawValue }
    }

    enum ScanState {
        case idle
        case reading
        case review(ParsedReceipt)
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
                    .onTapGesture { KeyboardDismisser.dismiss() }

            VStack(spacing: 0) {
                SegmentedPills(options: Tab.allCases,
                               title: { LocalizedStringKey($0.rawValue) },
                               selection: $tab)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 10)

                switch tab {
                case .items:   ItemsSection(bill: bill, onScan: { showingScanner = true })
                case .charges: ChargesSection(bill: bill)
                case .shares:  SharesSection(bill: bill)
                }
            }
        }
        .navigationTitle(Text(verbatim: bill.displayTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.canvas, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingScanner = true
                } label: {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("Scan receipt")
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            DocumentScannerView(
                onFinish: { images in
                    showingScanner = false
                    Task { await read(images) }
                },
                onCancel: { showingScanner = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: Binding(
            get: { if case .review = scanState { return true } else { return false } },
            set: { if !$0 { scanState = .idle } }
        )) {
            if case .review(let receipt) = scanState {
                ScanReviewView(receipt: receipt, currencyCode: bill.currencyCode) { items, charges in
                    apply(items: items, charges: charges)
                    scanState = .idle
                }
            }
        }
        .overlay {
            if case .reading = scanState { ReadingOverlay() }
        }
        .alert("Could not read that", isPresented: Binding(
            get: { scanError != nil }, set: { if !$0 { scanError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scanError ?? "")
        }
        .task {
            if startByScanning && bill.items.isEmpty { showingScanner = true }
        }
    }

    // MARK: - Scanning

    private func read(_ images: [CGImage]) async {
        guard !images.isEmpty else { return }
        scanState = .reading
        do {
            var lines: [RecognizedLine] = []
            for image in images {
                lines += try await ReceiptTextRecognizer.recognizeLines(in: image)
            }
            let receipt = ReceiptParser.parse(lines: lines)
            bill.scannedText = receipt.rawText
            if bill.title.trimmingCharacters(in: .whitespaces).isEmpty,
               let merchant = receipt.merchant {
                bill.title = merchant
            }
            scanState = .review(receipt)
        } catch {
            scanState = .idle
            scanError = error.localizedDescription
        }
    }

    private func apply(items: [ParsedItem], charges: ScanReviewView.Charges) {
        for item in items {
            _ = bill.addItem(name: item.name, unitPriceMinor: item.unitPriceMinor,
                             quantity: item.quantity)
        }
        if let tax = charges.taxPercent { bill.taxPercent = tax }
        if let service = charges.servicePercent { bill.servicePercent = service }
        if let discount = charges.discountMinor { bill.discountMinor = discount }
        if let extra = charges.extraMinor { bill.extraMinor = extra }
        bill.chargeMode = charges.chargeMode
        tab = .items
    }
}

private struct ReadingOverlay: View {
    @State private var sweep = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 54, height: 72)
                    Rectangle()
                        .fill(Theme.brandGradient)
                        .frame(width: 54, height: 2)
                        .shadow(color: Theme.accent, radius: 6)
                        .offset(y: sweep ? 32 : -32)
                }
                Text("Reading the receipt…")
                    .font(Theme.label(15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(30)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                sweep = true
            }
        }
    }
}

// MARK: - Items

private struct ItemsSection: View {
    @Bindable var bill: Bill
    var onScan: () -> Void

    @Environment(\.modelContext) private var context
    @State private var showingAddItem = false

    var body: some View {
        let result = bill.result

        List {
            if bill.items.isEmpty {
                ScanPrompt(onScan: onScan, onManual: { showingAddItem = true })
                    .plainListRow(insets: EdgeInsets(top: 20, leading: Theme.gutter,
                                                     bottom: 8, trailing: Theme.gutter))
            } else {
                SectionHeader(title: "Items",
                              trailing: Money.string(result.itemsSubtotal,
                                                     currencyCode: bill.currencyCode))
                    .plainListRow(insets: EdgeInsets(top: 4, leading: Theme.gutter + 4,
                                                     bottom: 6, trailing: Theme.gutter + 4))

                ForEach(bill.sortedItems) { item in
                    ItemCard(item: item, bill: bill)
                        .plainListRow()
                }
                .onDelete(perform: deleteItems)

                if !result.unassignedItemNames.isEmpty {
                    NoticeBanner(
                        icon: "person.crop.circle.badge.questionmark",
                        title: "\(result.unassignedItemNames.count) items with nobody assigned",
                        detail: "Split equally between everyone until you tap who ordered them."
                    )
                    .plainListRow()
                }

                Button { showingAddItem = true } label: {
                    Label("Add an item", systemImage: "plus")
                }
                .buttonStyle(QuietButtonStyle())
                .plainListRow(insets: EdgeInsets(top: 10, leading: Theme.gutter,
                                                 bottom: 4, trailing: Theme.gutter))
            }

            SectionHeader(title: "Splitting between")
                .plainListRow(insets: EdgeInsets(top: 18, leading: Theme.gutter + 4,
                                                 bottom: 6, trailing: Theme.gutter + 4))

            PeopleCard(bill: bill)
                .plainListRow()

            Color.clear.frame(height: 16).plainListRow()
        }
        .listStyle(.plain)
        .splitmeCanvas()
        .sheet(isPresented: $showingAddItem) {
            AddItemView(currencyCode: bill.currencyCode) { name, price, qty in
                _ = bill.addItem(name: name, unitPriceMinor: price, quantity: qty)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = bill.sortedItems
        for index in offsets {
            let item = items[index]
            bill.items.removeAll { $0.id == item.id }
            context.delete(item)
        }
    }
}

private struct ScanPrompt: View {
    var onScan: () -> Void
    var onManual: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Button(action: onScan) {
                VStack(spacing: 14) {
                    BrandArtView(art: .receipt, width: 108)
                    Text("Scan the receipt")
                        .font(Theme.label(17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Read on your device — the photo never leaves your phone.")
                        .font(Theme.label(13, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .fill(Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.35),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                )
            }
            .buttonStyle(.plain)

            Button("Or add the items by hand", action: onManual)
                .font(Theme.label(14, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
    }
}

private struct ItemCard: View {
    @Bindable var item: BillItem
    var bill: Bill

    @Environment(\.layoutDirection) private var layoutDirection

    private var everyone: Bool {
        !bill.participants.isEmpty && item.assigneeIDs.count == bill.participants.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                TextField("Item", text: $item.name)
                    .font(Theme.label(15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .alignedToReadingEdge(of: item.name)

                if item.quantity > 1 {
                    Text(verbatim: "×\(item.quantity)")
                        .font(Theme.number(12, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.accentSoft))
                }

                VStack(alignment: .trailing, spacing: 3) {
                    AmountField(title: "0.00", minor: Binding(
                        get: { item.unitPriceMinor },
                        set: { item.unitPriceMinor = $0 }
                    ), currencyCode: bill.currencyCode)
                    .frame(width: 88)

                    // With a quantity, the unit price alone is ambiguous — show
                    // what the line actually costs.
                    if item.quantity > 1 {
                        Text(verbatim: "= \(Money.editable(item.lineTotalMinor))")
                            .font(Theme.number(11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            HStack(spacing: 10) {
                Stepper("Quantity", value: Binding(
                    get: { item.quantity },
                    set: { item.quantity = max(1, $0) }
                ), in: 1...99)
                .labelsHidden()
                .fixedSize()
                .scaleEffect(0.86)
                .frame(width: 78, alignment: .leading)

                Spacer(minLength: 0)

                assignmentSummary
                    .font(Theme.label(12))
                    .foregroundStyle(item.assigneeIDs.isEmpty ? Theme.warning : Theme.textTertiary)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        item.assigneeIDs = everyone ? [] : bill.sortedParticipants.map(\.id)
                    }
                } label: {
                    Text(everyone ? "Clear" : "All")
                        .font(Theme.label(12, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Capsule().fill(Theme.surfaceSunken))
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Every person on the bill, wrapped so none of them are hidden off
            // the edge of a scroller.
            WrapLayout(spacing: 8, lineSpacing: 8, direction: layoutDirection) {
                ForEach(bill.sortedParticipants) { person in
                    PersonChip(
                        name: person.name,
                        colorIndex: person.colorIndex,
                        isSelected: item.assigneeIDs.contains(person.id)
                    ) {
                        item.toggle(person.id)
                    }
                }
            }
        }
        .card(padding: 14)
    }

    private var assignmentSummary: Text {
        if item.assigneeIDs.isEmpty { return Text("nobody yet") }
        if everyone { return Text("everyone") }
        return Text("\(item.assigneeIDs.count) people")
    }
}

private struct PeopleCard: View {
    @Bindable var bill: Bill
    @Environment(\.modelContext) private var context
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(bill.sortedParticipants) { person in
                HStack(spacing: 12) {
                    Avatar(name: person.name, colorIndex: person.colorIndex, size: 30)
                    TextField("Name", text: Binding(
                        get: { person.name }, set: { person.name = $0 }
                    ))
                    .font(Theme.label(15, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
                    .alignedToReadingEdge(of: person.name)
                    Spacer()
                    Button {
                        remove(person)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(bill.participants.count <= 2)
                    .opacity(bill.participants.count <= 2 ? 0.3 : 1)
                }
                .padding(.vertical, 9)

                if person.id != bill.sortedParticipants.last?.id {
                    Divider().overlay(Theme.hairline)
                }
            }

            Divider().overlay(Theme.hairline)

            HStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30)
                TextField("Add someone", text: $draft)
                    .font(Theme.label(15, weight: .regular))
                    .focused($focused)
                    .onSubmit(add)
                    .submitLabel(.done)
                if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: add)
                        .font(Theme.label(14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.vertical, 11)
        }
        .card(padding: 14)
    }

    private func add() {
        let name = draft.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        _ = bill.addParticipant(name: name)
        draft = ""
    }

    private func remove(_ person: BillParticipant) {
        for item in bill.items { item.assigneeIDs.removeAll { $0 == person.id } }
        bill.participants.removeAll { $0.id == person.id }
        context.delete(person)
    }
}

private struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    var currencyCode: String
    var onAdd: (String, Minor, Int) -> Void

    @State private var name = ""
    @State private var price: Minor = 0
    @State private var quantity = 1
    @State private var added = 0
    @FocusState private var nameFocused: Bool

    private var canAdd: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                    .onTapGesture { KeyboardDismisser.dismiss() }
                VStack(spacing: 16) {
                    VStack(spacing: 14) {
                        HStack {
                            Text("Item")
                                .font(Theme.label(14))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                        }
                        TextField("e.g. Grilled halloumi", text: $name)
                            .font(Theme.label(17, weight: .medium))
                            .focused($nameFocused)
                            .submitLabel(.next)

                        Divider().overlay(Theme.hairline)

                        HStack {
                            Text("Unit price")
                                .font(Theme.label(14))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            AmountField(title: "0.00", minor: $price, currencyCode: currencyCode)
                                .frame(width: 110)
                        }

                        Divider().overlay(Theme.hairline)

                        HStack {
                            Text("Quantity")
                                .font(Theme.label(14))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(verbatim: "\(quantity)")
                                .font(Theme.number(17, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(minWidth: 26)
                            Stepper("", value: $quantity, in: 1...99).labelsHidden()
                        }
                    }
                    .card()

                    Button {
                        onAdd(name.trimmingCharacters(in: .whitespaces), price, quantity)
                        added += 1
                        name = ""
                        price = 0
                        quantity = 1
                        nameFocused = true
                    } label: {
                        Text("Add to bill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canAdd)
                    .opacity(canAdd ? 1 : 0.45)

                    if added > 0 {
                        Text("^[\(added) item](inflect: true) added")
                            .font(Theme.label(13))
                            .foregroundStyle(Theme.positive)
                            .transition(.opacity)
                    }

                    Spacer()
                }
                .padding(Theme.gutter)
            }
            .navigationTitle("Add items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.label(16, weight: .semibold))
                }
            }
            .onAppear { nameFocused = true }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Charges

private struct ChargesSection: View {
    @Bindable var bill: Bill

    var body: some View {
        let result = bill.result

        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Menu prices")
                    ForEach(ChargeMode.allCases) { mode in
                        ChargeModeOption(mode: mode, selected: bill.chargeMode == mode) {
                            withAnimation(.easeOut(duration: 0.18)) { bill.chargeMode = mode }
                        }
                    }
                }
                .card()

                if bill.chargeMode == .addedOnTop {
                    VStack(spacing: 20) {
                        PercentField(title: "Service", systemImage: "sparkles",
                                     value: Binding(get: { bill.servicePercent },
                                                    set: { bill.servicePercent = $0 }),
                                     presets: [0, 10, 12, 14])
                        Divider().overlay(Theme.hairline)
                        PercentField(title: "Tax / VAT", systemImage: "percent",
                                     value: Binding(get: { bill.taxPercent },
                                                    set: { bill.taxPercent = $0 }),
                                     presets: [0, 5, 14, 15])
                    }
                    .card()
                    .transition(.opacity)
                }

                VStack(spacing: 14) {
                    SectionHeader(title: "Adjustments")
                    HStack {
                        Label("Tip, delivery, cover", systemImage: "plus.circle")
                            .font(Theme.label(14))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        AmountField(title: "0.00", minor: Binding(
                            get: { bill.extraMinor }, set: { bill.extraMinor = $0 }
                        ), currencyCode: bill.currencyCode)
                        .frame(width: 104)
                    }
                    Divider().overlay(Theme.hairline)
                    HStack {
                        Label("Discount", systemImage: "minus.circle")
                            .font(Theme.label(14))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        AmountField(title: "0.00", minor: Binding(
                            get: { bill.discountMinor }, set: { bill.discountMinor = $0 }
                        ), currencyCode: bill.currencyCode)
                        .frame(width: 104)
                    }
                }
                .card()

                VStack(spacing: 11) {
                    SectionHeader(title: "Bill total")
                    TotalsRows(result: result, currencyCode: bill.currencyCode,
                               chargeMode: bill.chargeMode)
                }
                .card()
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 24)
        }
        .splitmeCanvas()
    }
}

private struct ChargeModeOption: View {
    var mode: ChargeMode
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(selected ? Theme.accent : Theme.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(mode.label))
                        .font(Theme.label(15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(LocalizedStringKey(mode.explanation))
                        .font(Theme.label(12, weight: .regular))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(selected ? Theme.accentSoft : Theme.surfaceSunken))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .strokeBorder(selected ? Theme.accent.opacity(0.45) : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct TotalsRows: View {
    var result: SplitResult
    var currencyCode: String
    var chargeMode: ChargeMode

    var body: some View {
        AmountRow(label: "Items", amount: result.itemsSubtotal, currencyCode: currencyCode)
        if chargeMode == .addedOnTop {
            if result.service != 0 {
                AmountRow(label: "Service", amount: result.service, currencyCode: currencyCode)
            }
            if result.tax != 0 {
                AmountRow(label: "Tax", amount: result.tax, currencyCode: currencyCode)
            }
        }
        if result.extra != 0 {
            AmountRow(label: "Extra", amount: result.extra, currencyCode: currencyCode)
        }
        if result.discount != 0 {
            AmountRow(label: "Discount", amount: -result.discount, currencyCode: currencyCode)
        }
        Divider().overlay(Theme.hairline).padding(.vertical, 2)
        AmountRow(label: "Total", amount: result.grandTotal,
                  currencyCode: currencyCode, emphasis: .total)
    }
}
