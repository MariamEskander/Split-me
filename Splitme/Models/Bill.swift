import Foundation
import SwiftData

@Model
final class Bill {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var currencyCode: String = AppDefaults.currencyCode

    /// House rates for the region the app is aimed at; overridden by whatever a
    /// scan finds, and editable on the Charges tab.
    var taxPercent: Double = 14
    var servicePercent: Double = 12
    var chargeModeRaw: String = ChargeMode.addedOnTop.rawValue
    var extraMinor: Int = 0
    var discountMinor: Int = 0

    /// Raw OCR text kept so a bill can be re-parsed after editing the receipt.
    var scannedText: String?

    /// Where the bill happened, when picked from Maps rather than typed.
    var placeName: String?
    var placeDetail: String?
    var latitude: Double?
    var longitude: Double?

    @Relationship(deleteRule: .cascade, inverse: \BillParticipant.bill)
    var participants: [BillParticipant] = []

    @Relationship(deleteRule: .cascade, inverse: \BillItem.bill)
    var items: [BillItem] = []

    init(title: String = "", currencyCode: String? = nil) {
        self.title = title
        if let currencyCode { self.currencyCode = currencyCode }
    }

    var chargeMode: ChargeMode {
        get { ChargeMode(rawValue: chargeModeRaw) ?? .addedOnTop }
        set { chargeModeRaw = newValue.rawValue }
    }

    var sortedParticipants: [BillParticipant] {
        participants.sorted { $0.sortIndex < $1.sortIndex }
    }

    var sortedItems: [BillItem] {
        items.sorted { $0.sortIndex < $1.sortIndex }
    }

    var splitInput: SplitInput {
        SplitInput(
            people: sortedParticipants.map { .init(id: $0.id, name: $0.name) },
            items: sortedItems.map {
                .init(id: $0.id, name: $0.name, unitPrice: $0.unitPriceMinor,
                      quantity: $0.quantity, assignees: Set($0.assigneeIDs))
            },
            taxPercent: taxPercent,
            servicePercent: servicePercent,
            chargeMode: chargeMode,
            extraMinor: extraMinor,
            discountMinor: discountMinor
        )
    }

    var result: SplitResult { SplitEngine.calculate(splitInput) }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled bill" : title
    }

    func addParticipant(name: String) -> BillParticipant {
        let p = BillParticipant(name: name, sortIndex: (participants.map(\.sortIndex).max() ?? -1) + 1)
        p.bill = self
        participants.append(p)
        return p
    }

    func addItem(name: String, unitPriceMinor: Int, quantity: Int = 1) -> BillItem {
        let item = BillItem(name: name, unitPriceMinor: unitPriceMinor, quantity: quantity,
                            sortIndex: (items.map(\.sortIndex).max() ?? -1) + 1)
        item.bill = self
        items.append(item)
        return item
    }
}

@Model
final class BillParticipant {
    var id: UUID = UUID()
    var name: String = ""
    var sortIndex: Int = 0
    var bill: Bill?

    init(name: String, sortIndex: Int = 0) {
        self.name = name
        self.sortIndex = sortIndex
    }

    /// Colour follows the order people were added, so a bill's avatars are
    /// spread across the palette instead of landing on neighbouring hues.
    var colorIndex: Int { sortIndex }
}

@Model
final class BillItem {
    var id: UUID = UUID()
    var name: String = ""
    var unitPriceMinor: Int = 0
    var quantity: Int = 1
    var assigneeIDs: [UUID] = []
    var sortIndex: Int = 0
    var bill: Bill?

    init(name: String, unitPriceMinor: Int, quantity: Int = 1, sortIndex: Int = 0) {
        self.name = name
        self.unitPriceMinor = unitPriceMinor
        self.quantity = max(quantity, 1)
        self.sortIndex = sortIndex
    }

    var lineTotalMinor: Int { unitPriceMinor * max(quantity, 1) }

    func toggle(_ participantID: UUID) {
        if let idx = assigneeIDs.firstIndex(of: participantID) {
            assigneeIDs.remove(at: idx)
        } else {
            assigneeIDs.append(participantID)
        }
    }
}

@Model
final class SavedGroup {
    var id: UUID = UUID()
    var name: String = ""
    var memberNames: [String] = []
    var createdAt: Date = Date()
    var lastUsedAt: Date?

    init(name: String, memberNames: [String]) {
        self.name = name
        self.memberNames = memberNames
    }
}
