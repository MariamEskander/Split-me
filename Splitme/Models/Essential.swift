import Foundation
import SwiftData

/// Something you keep forgetting. The list you want read back to you on the way
/// out the door.
@Model
final class Essential {
    var id: UUID = UUID()
    var name: String = ""
    /// An SF Symbol, so the list is scannable at a glance.
    var symbol: String = "shippingbox.fill"
    /// Off means "not today" — kept on the list, left out of the reminder.
    var isEnabled: Bool = true
    var sortIndex: Int = 0

    init(name: String, symbol: String = "shippingbox.fill", sortIndex: Int = 0) {
        self.name = name
        self.symbol = symbol
        self.sortIndex = sortIndex
    }

    /// Common culprits, offered as one-tap suggestions on an empty list.
    static let suggestions: [(name: String, symbol: String)] = [
        ("Water bottle", "waterbottle.fill"),
        ("ID", "person.text.rectangle.fill"),
        ("Keys", "key.fill"),
        ("Wallet", "creditcard.fill"),
        ("Charger", "cable.connector"),
        ("Headphones", "headphones"),
        ("Sunglasses", "sunglasses.fill"),
        ("Umbrella", "umbrella.fill"),
        ("Medication", "pills.fill"),
        ("Laptop", "laptopcomputer"),
    ]
}
