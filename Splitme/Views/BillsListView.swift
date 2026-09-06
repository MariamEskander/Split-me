import SwiftUI
import SwiftData

struct BillsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Bill.createdAt, order: .reverse) private var bills: [Bill]

    @State private var newBill: Bill?
    @State private var showingNewBill = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                    .onTapGesture { KeyboardDismisser.dismiss() }

                if bills.isEmpty {
                    VStack(spacing: 28) {
                        Spacer()
                        EmptyStateView(
                            title: "No bills yet",
                            message: "Scan the receipt, tap who ordered what, and send everyone their exact share."
                        ) {
                            BrandArtView(art: .receipt, width: 150)
                        }
                        Button {
                            showingNewBill = true
                        } label: {
                            Label("Start a bill", systemImage: "plus")
                        }
                        .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                        Spacer()
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(bills) { bill in
                            ZStack {
                                NavigationLink { BillEditorView(bill: bill) } label: { EmptyView() }
                                    .opacity(0)
                                BillCard(bill: bill)
                            }
                            .plainListRow()
                        }
                        .onDelete(perform: delete)

                        Color.clear.frame(height: 92).plainListRow()
                    }
                    .listStyle(.plain)
                    .splitmeCanvas()
                }
            }
            .navigationTitle("Bills")
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { LanguageToggle() }
            }
            .overlay(alignment: .bottom) {
                if !bills.isEmpty {
                    NewBillFAB { showingNewBill = true }
                        .padding(.bottom, 12)
                }
            }
            .sheet(isPresented: $showingNewBill) {
                NewBillView { bill in
                    context.insert(bill)
                    newBill = bill
                }
            }
            .navigationDestination(item: $newBill) { bill in
                BillEditorView(bill: bill, startByScanning: true)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(bills[index]) }
    }
}

/// The kit puts the primary action on a raised teal disc at the bottom centre,
/// where a thumb actually reaches — not in the top-right corner.
private struct NewBillFAB: View {
    var action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                Text("New bill")
                    .font(Theme.label(15, weight: .semibold))
            }
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Capsule().fill(Theme.brandGradient))
            .overlay(Capsule().strokeBorder(Brand.mint.opacity(0.4), lineWidth: 1))
            .shadow(color: Brand.teal.opacity(0.4), radius: 18, y: 8)
            .shadow(color: Brand.navy.opacity(0.5), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: pressed)
        .simultaneousGesture(TapGesture().onEnded { pressed.toggle() })
    }
}

private struct BillCard: View {
    let bill: Bill

    var body: some View {
        let result = bill.result
        let people = bill.sortedParticipants

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: bill.displayTitle)
                        .font(Theme.label(17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(bill.createdAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(Theme.label(13, weight: .regular))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 10)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: Money.string(result.grandTotal, currencyCode: bill.currencyCode))
                        .font(Theme.number(20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(bill.items.count) items")
                        .font(Theme.label(12, weight: .regular))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Divider().overlay(Theme.hairline)

            HStack(spacing: 10) {
                AvatarCluster(names: people.map(\.name), colorIndexes: people.map(\.colorIndex))
                Spacer(minLength: 4)

                // At a glance: is this bill finished, or does it still need
                // someone assigned to something?
                if bill.items.isEmpty {
                    Text("No items yet")
                        .font(Theme.label(12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                } else if result.unassignedItemNames.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Settled")
                            .font(Theme.label(12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.positive)
                } else {
                    Text("\(result.unassignedItemNames.count) items unassigned")
                        .font(Theme.label(12, weight: .medium))
                        .foregroundStyle(Theme.warning)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .card()
    }
}
