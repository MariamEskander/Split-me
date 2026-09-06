import Foundation
import AppKit

// End-to-end: a rendered receipt image -> Vision OCR -> the app's parser.
let path = CommandLine.arguments[1]
guard let data = NSImage(contentsOfFile: path)?
    .cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("could not load \(path)")
}

let sem = DispatchSemaphore(value: 0)
Task {
    do {
        let lines = try await ReceiptTextRecognizer.recognizeLines(in: data)
        print("--- merged OCR lines (\(lines.count)) ---")
        for l in lines { print("  \(l.text)") }

        let receipt = ReceiptParser.parse(lines: lines)
        print("--- parsed items (\(receipt.items.count)) ---")
        for i in receipt.items {
            print("  \(i.name) | qty \(i.quantity) | unit \(Money.editable(i.unitPriceMinor)) | line \(Money.editable(i.lineTotalMinor))")
        }
        func show(_ label: String, _ v: Minor?) { print("  \(label): \(v.map { Money.editable($0) } ?? "—")") }
        print("--- charges ---")
        show("subtotal", receipt.subtotalMinor)
        show("service", receipt.serviceMinor); print("  service %: \(receipt.servicePercent.map { "\($0)" } ?? "—")")
        show("tax", receipt.taxMinor); print("  tax %: \(receipt.taxPercent.map { "\($0)" } ?? "—")")
        show("total", receipt.totalMinor)
        print("  items sum: \(Money.editable(receipt.itemsTotalMinor))")
        print("  discrepancy: \(receipt.discrepancy().map { Money.editable($0) } ?? "none")")
    } catch {
        print("ERROR: \(error)")
    }
    sem.signal()
}
sem.wait()
