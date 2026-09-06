import Foundation
import CoreGraphics
struct RecognizedLine { var text: String; var midY: CGFloat = 0; var minX: CGFloat = 0; var maxX: CGFloat = 1 }

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    let ok = actual == expected
    if !ok { failures += 1 }
    print("\(ok ? "PASS" : "FAIL") \(label)\n     got: \(actual)\n     exp: \(expected)")
}

// --- Receipt 1: tax & service added on top, English
let r1 = ReceiptParser.parse(texts: [
    "CAIRO KITCHEN",
    "Tel: 0100 123 4567",
    "Date 04/09/2026  Table 12",
    "2 x Chicken Shawarma   85.00   170.00",
    "Grilled Halloumi        120.50",
    "1 Lemon Mint            35.00",
    "Fresh Orange x2         60.00",
    "Subtotal               385.50",
    "Service 12%             46.26",
    "VAT 14%                 60.45",
    "TOTAL                  492.21",
    "CASH                   500.00",
    "CHANGE                   7.79",
])
check("r1 items", r1.items.map { "\($0.name)|\($0.quantity)|\($0.unitPriceMinor)" }.joined(separator: ", "),
      "Chicken Shawarma|2|8500, Grilled Halloumi|1|12050, Lemon Mint|1|3500, Fresh Orange|2|3000")
check("r1 charges", "sub=\(r1.subtotalMinor ?? -1) svc=\(r1.serviceMinor ?? -1)/\(r1.servicePercent ?? -1) tax=\(r1.taxMinor ?? -1)/\(r1.taxPercent ?? -1) total=\(r1.totalMinor ?? -1)",
      "sub=38550 svc=4626/12.0 tax=6045/14.0 total=49221")

// --- Receipt 2: Arabic, Arabic-Indic digits, discount
let r2 = ReceiptParser.parse(texts: [
    "مطعم البيت",
    "٢ × كشري            ٤٥٫٠٠     ٩٠٫٠٠",
    "فراخ مشوية                   ١٢٠٫٠٠",
    "خصم                           ٢١٫٠٠",
    "ضريبة ١٤٪                     ٢٦٫٤٦",
    "الإجمالي                     ٢١٥٫٤٦",
])
check("r2 items", r2.items.map { "\($0.name)|\($0.quantity)|\($0.unitPriceMinor)" }.joined(separator: ", "),
      "كشري|2|4500, فراخ مشوية|1|12000")
check("r2 charges", "disc=\(r2.discountMinor ?? -1) tax=\(r2.taxMinor ?? -1)/\(r2.taxPercent ?? -1) total=\(r2.totalMinor ?? -1)",
      "disc=2100 tax=2646/14.0 total=21546")

// --- Receipt 3: comma decimals, tax-inclusive prices, noise
let r3 = ReceiptParser.parse(texts: [
    "Cafe Riche  ·  VAT No 123456789",
    "Espresso            2,50",
    "Cappuccino x3       12,00",
    "Cheesecake           4,75",
    "Total               19,25",
])
check("r3 items", r3.items.map { "\($0.name)|\($0.quantity)|\($0.unitPriceMinor)" }.joined(separator: ", "),
      "Espresso|1|250, Cappuccino|3|400, Cheesecake|1|475")
check("r3 total", "\(r3.totalMinor ?? -1) itemsTotal=\(r3.itemsTotalMinor)", "1925 itemsTotal=1925")

// --- Receipt 4: a real-world receipt full of furniture. None of the header
// lines, identifiers, or the totals trailer may become items.
let r4 = ReceiptParser.parse(texts: [
    "KOSHARY EL TAHRIR",
    "15 Nile Street, Cairo",
    "Tel: 0100 123 4567",
    "VAT Reg No 123456789",
    "Invoice # 45821",
    "Date 04/09/2026  Time 20:15",
    "Table 12", "Guests 4", "Order 45",
    "--------------------------------",
    "Koshary Large             45.00",
    "2 x Hawawshi              70.00",
    "Fresh Lime                18.50",
    "--------------------------------",
    "Subtotal                 133.50",
    "Service 12%               16.02",
    "VAT 14%                   20.93",
    "TOTAL                    170.45",
    "Cash                     200.00",
    "Change                    29.55",
    "Thank you for visiting!",
    "Branch 3",
])
check("r4 items", r4.items.map { "\($0.name)|\($0.quantity)|\($0.unitPriceMinor)" }.joined(separator: ", "),
      "Koshary Large|1|4500, Hawawshi|2|3500, Fresh Lime|1|1850")
check("r4 charges", "sub=\(r4.subtotalMinor ?? -1) svc=\(r4.serviceMinor ?? -1) tax=\(r4.taxMinor ?? -1) total=\(r4.totalMinor ?? -1)",
      "sub=13350 svc=1602 tax=2093 total=17045")

// A tax-registration line must not be mistaken for the tax amount, even when it
// comes after the real VAT line (so a later overwrite cannot mask the bug).
let r5 = ReceiptParser.parse(texts: [
    "Falafel plate              30.00",
    "Service 12%                 3.60",
    "VAT 14%                     4.70",
    "TOTAL                      38.30",
    "VAT Reg No 987654321",
])
check("r5 tax not the reg number", "\(r5.taxMinor ?? -1)", "470")

// The totals block cuts off item detection, so a garbled total label below it
// still cannot become an item.
let r6 = ReceiptParser.parse(texts: [
    "Latte                      45.00",
    "Subtotal                   45.00",
    "VAT 14%                     6.30",
    "T0TA1                      51.30",
])
check("r6 garbled total ignored", r6.items.map(\.name).joined(separator: ","), "Latte")

// Known limitation, asserted so it stays visible: with no charge block *and* a
// garbled total label, there is nothing to identify the total by, so it survives
// as an item for the review screen to catch. Guessing by sum was tried and
// dropped real dishes (see r8).
let r7 = ReceiptParser.parse(texts: [
    "Espresso                   20.00",
    "Cortado                    25.00",
    "Cheesecake                 35.00",
    "T0TA1                      80.00",
])
check("r7 garbled total with no charge block survives (known limitation)",
      r7.items.map(\.name).joined(separator: ","),
      "Espresso,Cortado,Cheesecake,T0TA1")

// A genuine dish costing the same as two earlier ones must survive.
let r8 = ReceiptParser.parse(texts: [
    "Coffee                     20.00",
    "Tea                        20.00",
    "Sharing platter            40.00",
])
check("r8 real item not dropped", r8.items.map(\.name).joined(separator: ","),
      "Coffee,Tea,Sharing platter")

// A receipt that prints whole numbers only: integers must still be read as
// prices, while the furniture stays out.
let r9 = ReceiptParser.parse(texts: [
    "CAFE CORNER", "Table 5",
    "Espresso                      25",
    "Latte                         35",
    "TOTAL                         60",
])
check("r9 integer prices", r9.items.map { "\($0.name)|\($0.unitPriceMinor)" }.joined(separator: ", "),
      "Espresso|2500, Latte|3500")

// --- Money
check("divide 10.00/3", Money.divide(1000, into: 3).map(String.init).joined(separator: ","), "334,333,333")
check("divide sums", "\(Money.divide(1000, into: 3).reduce(0,+))", "1000")
check("apportion", Money.apportion(1000, weights: [1,1,1]).reduce(0,+).description, "1000")
check("parse 1,234.56", "\(Money.parse("1,234.56") ?? -1)", "123456")
check("parse 19,25", "\(Money.parse("19,25") ?? -1)", "1925")
check("parse ٩٠٫٠٠", "\(Money.parse("٩٠٫٠٠") ?? -1)", "9000")

// --- Split engine: exclusive charges, uneven pennies
let a = UUID(), b = UUID(), c = UUID()
let items: [SplitInput.Item] = [
    .init(id: UUID(), name: "Shawarma", unitPrice: 8500, quantity: 2, assignees: [a, b]),
    .init(id: UUID(), name: "Halloumi", unitPrice: 12050, quantity: 1, assignees: [c]),
    .init(id: UUID(), name: "Water", unitPrice: 1000, quantity: 1, assignees: []),  // everyone
]
let input = SplitInput(people: [.init(id: a, name: "Mariam"), .init(id: b, name: "Omar"), .init(id: c, name: "Nour")],
                       items: items, taxPercent: 14, servicePercent: 12,
                       chargeMode: .addedOnTop, extraMinor: 0, discountMinor: 0)
let out = SplitEngine.calculate(input)
check("engine subtotal", "\(out.itemsSubtotal)", "30050")
check("engine reconciles", "\(out.shares.reduce(0){$0+$1.total}) == \(out.grandTotal)", "\(out.grandTotal) == \(out.grandTotal)")
check("engine grand", "\(out.itemsSubtotal + out.service + out.tax)", "\(out.grandTotal)")
check("engine unassigned", out.unassignedItemNames.joined(separator: ","), "Water")
print("shares: " + out.shares.map { "\($0.name)=\(Money.editable($0.total))" }.joined(separator: " "))

// --- Inclusive mode: total must equal the item prices, tax/service informational
let inc = SplitEngine.calculate(SplitInput(people: [.init(id: a, name: "A"), .init(id: b, name: "B")],
    items: [.init(id: UUID(), name: "Meal", unitPrice: 19250, quantity: 1, assignees: [a, b])],
    taxPercent: 14, servicePercent: 12, chargeMode: .includedInPrices, extraMinor: 0, discountMinor: 0))
// Included mode adds nothing: the menu prices *are* the bill, and no charge
// lines are derived (the Charges tab hides the rates in this mode).
check("inclusive total", "\(inc.grandTotal)", "19250")
check("inclusive adds nothing", "svc=\(inc.service) tax=\(inc.tax)", "svc=0 tax=0")
check("inclusive equals items", "\(inc.grandTotal)", "\(inc.itemsSubtotal)")

// --- Discount + extra apportioned, still reconciles
let adj = SplitEngine.calculate(SplitInput(people: [.init(id: a, name: "A"), .init(id: b, name: "B"), .init(id: c, name: "C")],
    items: [.init(id: UUID(), name: "X", unitPrice: 1001, quantity: 1, assignees: [a]),
            .init(id: UUID(), name: "Y", unitPrice: 2002, quantity: 1, assignees: [b, c])],
    taxPercent: 5, servicePercent: 10, chargeMode: .addedOnTop, extraMinor: 777, discountMinor: 333))
check("adj reconciles", "\(adj.shares.reduce(0){$0+$1.total})", "\(adj.grandTotal)")
check("adj expected", "\(adj.grandTotal)", "\(adj.itemsSubtotal + adj.service + adj.tax + 777 - 333)")

print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURE(S)")
