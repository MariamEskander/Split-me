import Foundation

struct ParsedItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var quantity: Int
    var unitPriceMinor: Minor

    var lineTotalMinor: Minor { unitPriceMinor * max(quantity, 1) }
}

struct ParsedReceipt {
    var merchant: String?
    var items: [ParsedItem] = []
    var subtotalMinor: Minor?
    var taxMinor: Minor?
    var taxPercent: Double?
    var serviceMinor: Minor?
    var servicePercent: Double?
    var discountMinor: Minor?
    var tipMinor: Minor?
    var totalMinor: Minor?
    var rawText: String = ""

    var itemsTotalMinor: Minor { items.reduce(0) { $0 + $1.lineTotalMinor } }

    /// Difference between the receipt's printed total and what the parsed items
    /// plus charges add up to. Non-zero means the user should check the items.
    func discrepancy(fractionDigits: Int = 2) -> Minor? {
        guard let totalMinor else { return nil }
        let charges = (taxMinor ?? 0) + (serviceMinor ?? 0) + (tipMinor ?? 0) - (discountMinor ?? 0)
        let computed = (subtotalMinor ?? itemsTotalMinor) + charges
        let diff = totalMinor - computed
        return diff == 0 ? nil : diff
    }
}

/// Rule-based receipt reader: no model, no network. Works on the merged OCR
/// lines by looking for a trailing amount and classifying the label in front of it.
enum ReceiptParser {

    // MARK: - Keyword tables (English + Arabic)

    /// Unambiguous "this is the final total" phrases. Checked before the
    /// subtotal words, because Arabic "المجموع الكلي" (grand total) contains
    /// "المجموع" (total/subtotal) and would otherwise be misread as a subtotal.
    private static let grandTotalWords = ["grand total", "total due", "amount due",
                                          "net total", "balance due", "total payable",
                                          "المجموع الكلي", "الاجمالي الكلي",
                                          "إجمالي الفاتورة", "اجمالي الفاتورة",
                                          "المبلغ المستحق", "المطلوب", "الصافي"]
    private static let totalWords = ["total", "الاجمالي", "الإجمالي", "اجمالي", "إجمالي"]
    private static let subtotalWords = ["subtotal", "sub total", "sub-total", "net amount",
                                        "المجموع الفرعي", "الاجمالي الفرعي",
                                        "المجموع", "مجموع"]
    private static let taxWords = ["vat", "tax", "gst", "sales tax", "ضريبة", "ضريبه",
                                   "ض.ق.م", "القيمة المضافة", "ضريبة القيمة المضافة"]
    private static let serviceWords = ["service charge", "service", "svc", "srv",
                                       "خدمة", "خدمه", "رسوم الخدمة", "رسوم خدمة"]
    private static let discountWords = ["discount", "disc.", "promo", "coupon", "offer",
                                        "خصم", "تخفيض"]
    private static let tipWords = ["tip", "gratuity", "بقشيش", "اكرامية"]
    private static let deliveryWords = ["delivery", "cover charge", "minimum charge",
                                        "توصيل", "رسوم"]

    /// Lines that are never items and never charges — receipt furniture. Checked
    /// *first*, so that e.g. "VAT Reg No 123456789" is discarded outright rather
    /// than being read as a tax amount of 1,234,567.89.
    private static let noiseWords = ["cash", "change", "visa", "mastercard", "master card",
                                     "credit", "debit", "card", "mada", "payment", "paid",
                                     "invoice", "receipt", "bill no", "check", "thank",
                                     "welcome", "tel", "phone", "fax", "mobile",
                                     "date", "time", "table", "cashier", "server",
                                     "waiter", "order", "branch", "guest", "cover",
                                     "seat", "qty", "quantity", "description", "item",
                                     "price", "amount", "www", "http", ".com",
                                     "vat no", "vat reg", "tax no", "trn", "c.r",
                                     "reg no", "serial", "ref", "auth", "terminal",
                                     "operator", "till", "pos",
                                     "نقدي", "باقي", "شكرا", "فاتورة", "تاريخ", "الوقت",
                                     "طاولة", "كاشير", "الكاشير", "رقم", "الرقم الضريبي",
                                     "الكمية", "الصنف", "السعر", "البيان", "عدد", "فرع",
                                     "مرجع", "بطاقة", "مدى", "فيزا"]

    // MARK: - Entry points

    static func parse(lines: [RecognizedLine], fractionDigits: Int = 2) -> ParsedReceipt {
        parse(texts: lines.map(\.text), fractionDigits: fractionDigits)
    }

    static func parse(texts: [String], fractionDigits: Int = 2) -> ParsedReceipt {
        var receipt = ParsedReceipt()
        receipt.rawText = texts.joined(separator: "\n")
        receipt.merchant = texts.first { line in
            let l = line.trimmingCharacters(in: .whitespaces)
            return l.count >= 3 && amounts(in: l, fractionDigits: fractionDigits).isEmpty
        }

        // Most receipts print every price with a fraction. When that is true of
        // this receipt, a bare integer is not a price — which is what stops
        // "Order 45", "Table 12" and "Branch 3" being read as items.
        let decimalAmounts = texts.reduce(0) { count, text in
            count + amounts(in: text.westernDigits, fractionDigits: fractionDigits)
                .filter(\.hasFraction).count
        }
        let requireFraction = decimalAmounts >= 2

        // Items live in a band between the header and the totals block. Once a
        // subtotal/total/tax/service line appears, nothing below it is an item —
        // which is what stops the total itself, and the cash/change/thank-you
        // trailer, from being added even if OCR garbles their labels.
        var inTotalsBlock = false

        for text in texts {
            let normalized = text.westernDigits
            let lower = normalized.lowercased()

            // Receipt furniture and identifiers are discarded before anything
            // else looks at them.
            if contains(lower, noiseWords) || looksLikeIdentifier(normalized) { continue }

            let found = amounts(in: normalized, fractionDigits: fractionDigits)

            if let amount = found.last?.value {
                if contains(lower, grandTotalWords) {
                    receipt.totalMinor = max(receipt.totalMinor ?? 0, amount)
                    inTotalsBlock = true
                    continue
                }
                if contains(lower, subtotalWords) {
                    receipt.subtotalMinor = amount
                    inTotalsBlock = true
                    continue
                }
                if contains(lower, totalWords) {
                    receipt.totalMinor = max(receipt.totalMinor ?? 0, amount)
                    inTotalsBlock = true
                    continue
                }
                if contains(lower, taxWords) {
                    receipt.taxMinor = amount
                    receipt.taxPercent = percentage(in: normalized) ?? receipt.taxPercent
                    inTotalsBlock = true
                    continue
                }
                if contains(lower, serviceWords) {
                    receipt.serviceMinor = amount
                    receipt.servicePercent = percentage(in: normalized) ?? receipt.servicePercent
                    inTotalsBlock = true
                    continue
                }
                if contains(lower, discountWords) {
                    receipt.discountMinor = abs(amount)
                    inTotalsBlock = true
                    continue
                }
                if contains(lower, tipWords) || contains(lower, deliveryWords) {
                    receipt.tipMinor = (receipt.tipMinor ?? 0) + amount
                    inTotalsBlock = true
                    continue
                }
            }

            guard !inTotalsBlock else { continue }
            if let item = item(from: normalized, requireFraction: requireFraction,
                               fractionDigits: fractionDigits) {
                receipt.items.append(item)
            }
        }

        // Last defence for the reported "the total gets added as an item": if a
        // line's amount is exactly the receipt total, it was the total, not
        // something anyone ordered.
        //
        // A sum-matching heuristic was tried here too — a trailing line equal to
        // everything above it — and deliberately removed: it deleted a genuine
        // "Sharing platter 40.00" from a bill of "Coffee 20 + Tea 20". Silently
        // dropping a real item changes what people pay, which is far worse than
        // leaving a stray row for the review screen to catch.
        if let total = receipt.totalMinor, receipt.items.count >= 2 {
            receipt.items.removeAll { $0.lineTotalMinor == total }
        }

        // Derive percentages from amounts when the receipt only printed money.
        let base = receipt.subtotalMinor ?? (receipt.itemsTotalMinor > 0 ? receipt.itemsTotalMinor : nil)
        if let base, base > 0 {
            if receipt.servicePercent == nil, let s = receipt.serviceMinor {
                receipt.servicePercent = round(Double(s) / Double(base) * 1000) / 10
            }
            if receipt.taxPercent == nil, let t = receipt.taxMinor {
                let taxBase = base + (receipt.serviceMinor ?? 0)
                receipt.taxPercent = round(Double(t) / Double(taxBase) * 1000) / 10
            }
        }

        return receipt
    }

    /// Reference numbers, dates and times: a number on the line, but never a price.
    static func looksLikeIdentifier(_ text: String) -> Bool {
        let patterns = [
            #"#\s*\d"#,                        // "Invoice # 45821"
            #"\bno[.:]?\s*\d"#,               // "Bill No 12"
            #"\d{7,}"#,                        // registration / phone / barcode runs
            #"\d{1,4}\s*[/\-.]\s*\d{1,2}\s*[/\-.]\s*\d{1,4}"#,   // a date
            #"\d{1,2}:\d{2}"#,                 // a time
        ]
        let lower = text.lowercased()
        return patterns.contains { lower.range(of: $0, options: .regularExpression) != nil }
    }

    // MARK: - Line interpretation

    private static func item(from rawText: String, requireFraction: Bool,
                             fractionDigits: Int) -> ParsedItem? {
        var text = rawText
        var quantity = 1

        // A leading quantity would otherwise be read as the line's first amount,
        // so strip it before looking for prices: "2 x Latte 90.00", "٢ لاتيه ٩٠٫٠٠".
        if let match = text.range(of: #"^\s*(\d{1,2})\s*(?:[xX×*]\s*)?(?=\D)"#, options: .regularExpression) {
            let digits = text[match].filter(\.isNumber)
            let remainder = String(text[match.upperBound...])
            if let q = Int(digits), q >= 1, q <= 50,
               remainder.trimmingCharacters(in: .whitespaces).count >= 2,
               remainder.contains(where: { $0.isLetter }) {
                quantity = q
                text = remainder
            }
        }

        let found = amounts(in: text, fractionDigits: fractionDigits)
        guard let last = found.last, last.value > 0 else { return nil }
        // On a receipt that prints fractions, a bare integer is a table number,
        // an order number or a branch number — not a price.
        if requireFraction && !last.hasFraction { return nil }

        // The name is whatever precedes the first amount on the line.
        var name = String(text[text.startIndex..<found[0].range.lowerBound])

        // Trailing quantity: "Latte x2 90.00"
        if quantity == 1, let match = name.range(of: #"\s*[xX×*]\s*(\d{1,2})\s*$"#, options: .regularExpression) {
            let digits = name[match].filter(\.isNumber)
            if let q = Int(digits), q >= 1, q <= 50 {
                quantity = q
                name = String(name[name.startIndex..<match.lowerBound])
            }
        }

        name = clean(name)
        guard name.count >= 2, name.contains(where: { $0.isLetter }) else { return nil }

        var unitPrice = last.value
        if quantity > 1 {
            // "2  Latte  45.00  90.00" — unit price printed next to the line total.
            let penultimate = found.count >= 2 ? found[found.count - 2].value : 0
            if penultimate > 0, abs(penultimate * quantity - last.value) <= quantity {
                unitPrice = penultimate
            } else if last.value % quantity == 0 {
                unitPrice = last.value / quantity
            } else {
                // Do not invent pennies: keep the printed total as a single line.
                return ParsedItem(name: name, quantity: 1, unitPriceMinor: last.value)
            }
        }

        return ParsedItem(name: name, quantity: quantity, unitPriceMinor: unitPrice)
    }

    private static func clean(_ name: String) -> String {
        var s = name.trimmingCharacters(in: .whitespacesAndNewlines)
        while let first = s.first, "*-•.#:|".contains(first) { s.removeFirst() }
        while let last = s.last, "*-•.#:|@ ".contains(last) { s.removeLast() }
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func contains(_ haystack: String, _ words: [String]) -> Bool {
        words.contains { haystack.contains($0) }
    }

    /// "12%" or "١٢٪" anywhere on the line.
    static func percentage(in text: String) -> Double? {
        let normalized = text.westernDigits.replacingOccurrences(of: "٪", with: "%")
        guard let range = normalized.range(of: #"(\d{1,2}(?:\.\d{1,2})?)\s*%"#, options: .regularExpression) else {
            return nil
        }
        let digits = normalized[range].filter { $0.isNumber || $0 == "." }
        return Double(digits)
    }

    /// Every money-looking number on a line, in reading order. Percentages and
    /// bare years/quantities are filtered out.
    struct Amount {
        var value: Minor
        var range: Range<String.Index>
        /// Whether the token was written with a decimal part, e.g. `45.00`.
        var hasFraction: Bool
    }

    static func amounts(in text: String, fractionDigits: Int = 2) -> [Amount] {
        let pattern = #"\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+[.,]\d{1,2}|\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let ns = text as NSString
        var out: [Amount] = []

        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let range = Range(match.range, in: text) else { continue }
            let token = String(text[range])

            // Skip percentages: "12%" / "12 %"
            let after = range.upperBound < text.endIndex
                ? text[range.upperBound...].prefix(2).trimmingCharacters(in: .whitespaces)
                : ""
            if after.hasPrefix("%") || after.hasPrefix("٪") { continue }

            // A bare integer with no decimal part is only money if it is not
            // obviously a quantity, a year, or a phone/receipt number.
            let hasDecimal = token.contains(".") || token.contains(",")
            if !hasDecimal {
                if token.count > 6 { continue }
                if token.count <= 1 { continue }
                if let n = Int(token), n >= 1900, n <= 2200 { continue }
            }

            guard let value = Money.parse(token, fractionDigits: fractionDigits) else { continue }
            out.append(Amount(value: value, range: range, hasFraction: hasDecimal))
        }
        return out
    }
}
