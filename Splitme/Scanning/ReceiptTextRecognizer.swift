import Foundation
import Vision
import CoreGraphics

/// One recognised line of text with its vertical position on the receipt.
struct RecognizedLine {
    var text: String
    var midY: CGFloat      // 1 = top of image, 0 = bottom (Vision coordinates)
    var minX: CGFloat
    var maxX: CGFloat
}

enum ReceiptOCRError: Error, LocalizedError {
    case noImage
    case noText

    var errorDescription: String? {
        switch self {
        case .noImage: return "That image could not be read."
        case .noText: return "No text was found on the receipt. Try again with more light, or enter the items by hand."
        }
    }
}

/// Runs Apple's on-device text recogniser. Nothing leaves the phone.
enum ReceiptTextRecognizer {
    static func recognizeLines(in image: CGImage) async throws -> [RecognizedLine] {
        let observations = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[VNRecognizedTextObservation], Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning:
                        request.results as? [VNRecognizedTextObservation] ?? [])
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false   // receipts are not prose; correction hurts
            request.recognitionLanguages = ["en-US", "ar-SA"]

            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }

        let raw: [RecognizedLine] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let box = obs.boundingBox
            return RecognizedLine(text: text, midY: box.midY, minX: box.minX, maxX: box.maxX)
        }
        guard !raw.isEmpty else { throw ReceiptOCRError.noText }

        return merge(raw)
    }

    /// Vision often returns the item name and its price as two separate
    /// observations on the same physical line. Merge fragments whose vertical
    /// centres are close, ordering them left-to-right.
    static func merge(_ lines: [RecognizedLine], tolerance: CGFloat = 0.008) -> [RecognizedLine] {
        let sorted = lines.sorted { $0.midY > $1.midY }
        var groups: [[RecognizedLine]] = []

        for line in sorted {
            if let last = groups.last, let ref = last.first,
               abs(ref.midY - line.midY) <= tolerance {
                groups[groups.count - 1].append(line)
            } else {
                groups.append([line])
            }
        }

        return groups.map { group in
            let ordered = group.sorted { $0.minX < $1.minX }
            return RecognizedLine(
                text: ordered.map(\.text).joined(separator: "  "),
                midY: ordered.map(\.midY).reduce(0, +) / CGFloat(ordered.count),
                minX: ordered.map(\.minX).min() ?? 0,
                maxX: ordered.map(\.maxX).max() ?? 1
            )
        }
    }
}
