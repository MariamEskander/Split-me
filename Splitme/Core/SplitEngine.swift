import Foundation

/// How the restaurant prices its menu.
enum ChargeMode: String, Codable, CaseIterable, Identifiable {
    /// Menu prices are net; tax and service are added on top of the subtotal.
    case addedOnTop
    /// Menu prices already contain tax and service; they are only shown as a breakdown.
    case includedInPrices

    var id: String { rawValue }

    var label: String {
        switch self {
        case .addedOnTop: return "Tax & service added on top"
        case .includedInPrices: return "Tax & service already included"
        }
    }

    var explanation: String {
        switch self {
        case .addedOnTop:
            return "Charged on the subtotal and split in proportion to what each person ordered."
        case .includedInPrices:
            return "Shown as a breakdown only, never added to the total a second time."
        }
    }
}

/// A value-type snapshot of everything the engine needs. Kept separate from the
/// SwiftData models so the maths is pure and testable.
struct SplitInput {
    struct Person: Identifiable, Hashable {
        let id: UUID
        var name: String
    }

    struct Item: Identifiable, Hashable {
        let id: UUID
        var name: String
        var unitPrice: Minor
        var quantity: Int
        /// People sharing this item. Empty means "everyone" (split equally).
        var assignees: Set<UUID>

        var lineTotal: Minor { unitPrice * max(quantity, 1) }
    }

    var people: [Person]
    var items: [Item]
    var taxPercent: Double
    var servicePercent: Double
    var chargeMode: ChargeMode
    /// Extra amount added to the whole bill (tip, delivery, cover charge).
    var extraMinor: Minor
    /// Bill-wide discount, entered as a positive amount.
    var discountMinor: Minor
}

struct PersonShare: Identifiable {
    let id: UUID
    var name: String
    var itemsSubtotal: Minor
    var service: Minor
    var tax: Minor
    var extra: Minor
    var discount: Minor
    var total: Minor
    /// Item name → the amount of that item charged to this person.
    var lines: [(name: String, amount: Minor)]
}

struct SplitResult {
    var shares: [PersonShare]
    var itemsSubtotal: Minor
    var service: Minor
    var tax: Minor
    var extra: Minor
    var discount: Minor
    var grandTotal: Minor
    /// Items nobody was assigned to, which were therefore split across everyone.
    var unassignedItemNames: [String]
}

enum SplitEngine {
    static func calculate(_ input: SplitInput) -> SplitResult {
        let people = input.people
        guard !people.isEmpty else {
            return SplitResult(shares: [], itemsSubtotal: 0, service: 0, tax: 0, extra: 0,
                               discount: 0, grandTotal: 0, unassignedItemNames: [])
        }

        let personIndex = Dictionary(uniqueKeysWithValues: people.enumerated().map { ($1.id, $0) })

        var subtotals = Array(repeating: Minor(0), count: people.count)
        var lines: [[(name: String, amount: Minor)]] = Array(repeating: [], count: people.count)
        var unassigned: [String] = []

        for item in input.items {
            // Only assignees that still exist on the bill count.
            let valid = item.assignees.filter { personIndex[$0] != nil }
            let targets: [Int]
            if valid.isEmpty {
                unassigned.append(item.name)
                targets = Array(people.indices)
            } else {
                // Stable order (bill order) so penny rounding is deterministic.
                targets = people.indices.filter { valid.contains(people[$0].id) }
            }

            let portions = Money.divide(item.lineTotal, into: targets.count)
            for (offset, personIdx) in targets.enumerated() {
                subtotals[personIdx] += portions[offset]
                lines[personIdx].append((item.name, portions[offset]))
            }
        }

        let itemsSubtotal = subtotals.reduce(0, +)

        // Bill-level charges, then apportioned back by how much each person ordered.
        let totalService: Minor
        let totalTax: Minor
        switch input.chargeMode {
        case .addedOnTop:
            totalService = Money.percent(input.servicePercent, of: itemsSubtotal)
            totalTax = Money.percent(input.taxPercent, of: itemsSubtotal + totalService)
        case .includedInPrices:
            // The menu prices already contain both charges, so there is nothing
            // to add and nothing to show: the item prices *are* the bill.
            totalService = 0
            totalTax = 0
        }

        let serviceShares = Money.apportion(totalService, weights: subtotals)
        let taxShares = Money.apportion(totalTax, weights: subtotals)
        let extraShares = Money.apportion(input.extraMinor, weights: subtotals)
        let discountShares = Money.apportion(input.discountMinor, weights: subtotals)

        var shares: [PersonShare] = []
        for (i, person) in people.enumerated() {
            let chargesAddOn = input.chargeMode == .addedOnTop
            let total = subtotals[i]
                + (chargesAddOn ? serviceShares[i] + taxShares[i] : 0)
                + extraShares[i]
                - discountShares[i]

            shares.append(PersonShare(
                id: person.id,
                name: person.name,
                itemsSubtotal: subtotals[i],
                service: serviceShares[i],
                tax: taxShares[i],
                extra: extraShares[i],
                discount: discountShares[i],
                total: total,
                lines: lines[i]
            ))
        }

        return SplitResult(
            shares: shares,
            itemsSubtotal: itemsSubtotal,
            service: totalService,
            tax: totalTax,
            extra: input.extraMinor,
            discount: input.discountMinor,
            grandTotal: shares.reduce(0) { $0 + $1.total },
            unassignedItemNames: unassigned
        )
    }
}
