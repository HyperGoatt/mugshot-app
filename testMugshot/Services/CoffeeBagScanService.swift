import Foundation
import ImageIO
import UIKit
@preconcurrency import Vision

final class CoffeeBagScanService: @unchecked Sendable {
    func scan(_ image: UIImage) async throws -> CoffeeBagScanProposal {
        guard let cgImage = image.cgImage else {
            throw CoffeeBagScanError.invalidImage
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "en-GB"]

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(
                        cgImage: cgImage,
                        orientation: orientation,
                        options: [:]
                    ).perform([request])
                    let lines = request.results?
                        .compactMap { $0.topCandidates(1).first?.string }
                        ?? []
                    continuation.resume(returning: CoffeeBagScanParser.proposal(from: lines))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum CoffeeBagScanError: LocalizedError {
    case invalidImage
    case noText

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Mugshot couldn’t read that image. Try another photo."
        case .noText:
            return "No coffee details were found. You can add the bag manually."
        }
    }
}

enum CoffeeBagScanParser {
    private static let labels: [CoffeeBagScanFieldKey: [String]] = [
        .roaster: ["roaster", "roasted by"],
        .name: ["coffee", "coffee name", "lot", "lot name"],
        .producer: ["producer", "farm", "washing station"],
        .origin: ["origin", "country", "region"],
        .process: ["process", "processing", "processed"],
        .variety: ["variety", "varietal", "cultivar"],
        .roastLevel: ["roast", "roast level"],
        .roastDate: ["roast date", "roasted on", "roasted"],
        .tastingNotes: ["tasting notes", "taste notes", "notes", "flavors", "flavour notes"]
    ]

    static func proposal(from rawLines: [String]) -> CoffeeBagScanProposal {
        let lines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            return CoffeeBagScanProposal(values: [], recognizedText: [])
        }

        var values: [CoffeeBagScanFieldKey: CoffeeBagScanValue] = [:]
        for (index, line) in lines.enumerated() {
            let normalized = normalize(line)
            for (key, candidates) in labels {
                guard values[key] == nil else { continue }
                for label in candidates {
                    let normalizedLabel = normalize(label)
                    if normalized == normalizedLabel,
                       lines.indices.contains(index + 1),
                       let value = clean(lines[index + 1], removing: nil) {
                        values[key] = CoffeeBagScanValue(
                            key: key,
                            value: value,
                            confidence: 0.86,
                            source: .label
                        )
                        break
                    }
                    if normalized.hasPrefix(normalizedLabel + ":") ||
                        normalized.hasPrefix(normalizedLabel + " ") {
                        guard let value = clean(line, removing: label) else { continue }
                        values[key] = CoffeeBagScanValue(
                            key: key,
                            value: value,
                            confidence: 0.91,
                            source: .label
                        )
                        break
                    }
                }
            }
        }

        inferProcess(from: lines, into: &values)
        inferHeading(from: lines, into: &values)

        return CoffeeBagScanProposal(
            values: CoffeeBagScanFieldKey.allCases.compactMap { values[$0] },
            recognizedText: lines
        )
    }

    private static func inferProcess(
        from lines: [String],
        into values: inout [CoffeeBagScanFieldKey: CoffeeBagScanValue]
    ) {
        guard values[.process] == nil else { return }
        let processes = [
            "washed", "natural", "honey", "anaerobic", "carbonic maceration",
            "wet hulled", "experimental"
        ]
        for line in lines {
            let normalized = normalize(line)
            if let match = processes.first(where: { normalized.contains($0) }) {
                values[.process] = CoffeeBagScanValue(
                    key: .process,
                    value: match.capitalized,
                    confidence: 0.68,
                    source: .inferredLayout
                )
                return
            }
        }
    }

    private static func inferHeading(
        from lines: [String],
        into values: inout [CoffeeBagScanFieldKey: CoffeeBagScanValue]
    ) {
        let candidates = lines.prefix(4).filter { line in
            let normalized = normalize(line)
            return line.count >= 3 && line.count <= 60 &&
                !labels.values.flatMap { $0 }.contains(where: {
                    normalized.hasPrefix(normalize($0))
                })
        }
        if values[.roaster] == nil, let first = candidates.first {
            values[.roaster] = CoffeeBagScanValue(
                key: .roaster,
                value: first,
                confidence: 0.52,
                source: .inferredLayout
            )
        }
        if values[.name] == nil, candidates.count > 1 {
            values[.name] = CoffeeBagScanValue(
                key: .name,
                value: candidates[candidates.index(after: candidates.startIndex)],
                confidence: 0.50,
                source: .inferredLayout
            )
        }
    }

    private static func clean(_ raw: String, removing label: String?) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let label {
            let escaped = NSRegularExpression.escapedPattern(for: label)
            value = value.replacingOccurrences(
                of: "^\\s*\(escaped)\\s*:?\\s*",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return value.remoteTrimmedNonEmpty
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9: ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
