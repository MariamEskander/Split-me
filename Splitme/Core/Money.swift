import Foundation

/// All money in Splitme is stored as an integer number of minor units (e.g. cents,
/// piastres) so that repeated splitting and re-summing never drifts.
typealias Minor = Int

enum Money {
    /// Parses user / OCR text into minor units. Tolerates Arabic-Indic digits,
    /// thousands separators, and both `.` and `,` as the decimal mark.
    static func parse(_ raw: String, fractionDigits: Int = 2) -> Minor? {
        var s = raw.westernDigits.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
        guard !s.isEmpty else { return nil }

        let negative = s.hasPrefix("-")
        s = s.replacingOccurrences(of: "-", with: "")

        // Decide which separator is the decimal mark: the last one, if it is
        // followed by 1-2 digits. Everything else is a grouping separator.
        var integerPart = s
        var fractionPart = ""
        if let idx = s.lastIndex(where: { $0 == "." || $0 == "," }) {
            let tail = String(s[s.index(after: idx)...])
            if tail.count <= fractionDigits, !tail.isEmpty, tail.allSatisfy(\.isNumber) {
                integerPart = String(s[s.startIndex..<idx])
                fractionPart = tail
            }
        }
        integerPart = integerPart.filter(\.isNumber)
        guard !integerPart.isEmpty || !fractionPart.isEmpty else { return nil }

        let padded = fractionPart.padding(toLength: fractionDigits, withPad: "0", startingAt: 0)
        guard let whole = Int(integerPart.isEmpty ? "0" : integerPart),
              let frac = Int(padded.isEmpty ? "0" : padded) else { return nil }

        let scale = Int(pow(10.0, Double(fractionDigits)))
        let value = whole * scale + frac
        return negative ? -value : value
    }

    static func string(_ amount: Minor, currencyCode: String, fractionDigits: Int = 2) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        let scale = pow(10.0, Double(fractionDigits))
        return f.string(from: NSNumber(value: Double(amount) / scale)) ?? "\(amount)"
    }

    /// Plain decimal text suitable for a `TextField` (no currency symbol).
    static func editable(_ amount: Minor, fractionDigits: Int = 2) -> String {
        let scale = Int(pow(10.0, Double(fractionDigits)))
        let whole = abs(amount) / scale
        let frac = abs(amount) % scale
        let sign = amount < 0 ? "-" : ""
        return "\(sign)\(whole).\(String(format: "%0\(fractionDigits)d", frac))"
    }

    /// Splits `amount` into `parts` shares that sum back to exactly `amount`.
    /// The remainder pennies go to the first shares (deterministic).
    static func divide(_ amount: Minor, into parts: Int) -> [Minor] {
        guard parts > 0 else { return [] }
        let base = amount / parts
        let remainder = amount - base * parts
        let step = remainder >= 0 ? 1 : -1
        var shares = Array(repeating: base, count: parts)
        for i in 0..<abs(remainder) { shares[i % parts] += step }
        return shares
    }

    /// Applies `percent` to `amount`, rounding half-up to the nearest minor unit.
    static func percent(_ percent: Double, of amount: Minor) -> Minor {
        let exact = Double(amount) * percent / 100.0
        return Int((exact).rounded())
    }

    /// Distributes `total` across `weights` proportionally, summing to exactly
    /// `total` (largest-remainder method).
    static func apportion(_ total: Minor, weights: [Minor]) -> [Minor] {
        let weightSum = weights.reduce(0, +)
        guard weightSum != 0 else { return divide(total, into: max(weights.count, 1)) }

        var allocated: [Minor] = []
        var remainders: [(index: Int, frac: Double)] = []
        for (i, w) in weights.enumerated() {
            let exact = Double(total) * Double(w) / Double(weightSum)
            let floored = exact < 0 ? Int(exact.rounded(.up)) : Int(exact.rounded(.down))
            allocated.append(floored)
            remainders.append((i, abs(exact - Double(floored))))
        }
        var leftover = total - allocated.reduce(0, +)
        let step = leftover >= 0 ? 1 : -1
        for (index, _) in remainders.sorted(by: { $0.frac > $1.frac }) where leftover != 0 {
            allocated[index] += step
            leftover -= step
        }
        return allocated
    }
}

extension String {
    /// Converts Arabic-Indic and Eastern Arabic-Indic digits to 0-9.
    var westernDigits: String {
        var out = ""
        for ch in self {
            switch ch {
            case "\u{0660}"..."\u{0669}":
                out.append(Character(UnicodeScalar(ch.unicodeScalars.first!.value - 0x0660 + 48)!))
            case "\u{06F0}"..."\u{06F9}":
                out.append(Character(UnicodeScalar(ch.unicodeScalars.first!.value - 0x06F0 + 48)!))
            case "\u{066B}": out.append(".")   // Arabic decimal separator
            case "\u{066C}": out.append(",")   // Arabic thousands separator
            default: out.append(ch)
            }
        }
        return out
    }
}

enum AppDefaults {
    /// Splitme is built for Egypt first, so a new bill starts in pounds rather
    /// than whatever the device happens to be set to.
    static let currencyCode = "EGP"
}
