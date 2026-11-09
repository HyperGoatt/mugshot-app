import Foundation

/// Typed words and each captured source stay independent. Spoken text belongs
/// to one selected clip and is usable only during its current opt-in.
struct HomeRecipeCaptureSources {
    enum Kind: CaseIterable { case caption, screenshot, linkedVideo, video }
    var typedCaption = ""
    private var parts: [Kind: String] = [:]
    private var spokenText = ""
    private(set) var includesSpeech = false
    private(set) var speechGeneration = UUID()

    var hasSpokenText: Bool { includesSpeech && !spokenText.isEmpty }

    var text: String {
        var chunks = typedCaption.isEmpty ? [] : [typedCaption]
        for key in Kind.allCases {
            if let part = parts[key], !part.isEmpty, !chunks.contains(where: { $0.contains(part) }) {
                chunks.append(part)
            }
        }
        if hasSpokenText { chunks.append("Spoken instructions (on-device transcript):\n" + spokenText) }
        return chunks.joined(separator: "\n\n")
    }

    mutating func set(_ kind: Kind, text: String) {
        parts[kind] = String(text.prefix(12_000))
    }

    mutating func setSpeechEnabled(_ enabled: Bool) {
        guard includesSpeech != enabled else { return }
        includesSpeech = enabled
        speechGeneration = UUID()
        spokenText = ""
    }

    mutating func resetSelectedVideo() {
        parts[.video] = nil
        includesSpeech = false
        speechGeneration = UUID()
        spokenText = ""
    }

    @discardableResult
    mutating func applySpeech(_ text: String, generation: UUID) -> Bool {
        guard includesSpeech, generation == speechGeneration else { return false }
        spokenText = String(text.prefix(12_000))
        return true
    }
}
