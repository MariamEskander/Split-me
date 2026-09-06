# Checks

Two dev-only checks for the parts of the app that are pure logic. There is no
XCTest target yet, so both compile standalone with `swiftc`.

## 1. Parser + split engine

```sh
swiftc -o /tmp/splitme-checks Checks/main.swift \
  Splitme/Core/Money.swift Splitme/Core/SplitEngine.swift Splitme/Scanning/ReceiptParser.swift
/tmp/splitme-checks
```

Covers: English and Arabic receipts (including Arabic-Indic digits and `٫` as the
decimal mark), comma decimals, quantity forms (`2 x Latte`, `Latte x3`), noise-line
rejection, penny-exact division, tax-inclusive mode adding nothing, and that every
share adds back up to the bill total.

## 2. Scan pipeline, end to end

Runs a real image through Vision and then the parser — the same code path the app
uses, so it catches breakage in the recogniser itself, not just the parsing rules.

```sh
swiftc -o /tmp/splitme-ocr Checks/OCRCheck/main.swift \
  Splitme/Scanning/ReceiptTextRecognizer.swift \
  Splitme/Scanning/ReceiptParser.swift Splitme/Core/Money.swift
/tmp/splitme-ocr path/to/receipt.png
```

Prints the merged OCR lines, the parsed items with quantities and unit prices, the
detected charges, and any discrepancy against the receipt's printed total. Any
photo of a receipt works; a rendered one gives a deterministic baseline.
