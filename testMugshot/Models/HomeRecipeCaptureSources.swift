import Foundation

/// Keep each selected source distinct so replacing a screenshot cannot erase its caption.
struct HomeRecipeCaptureSources {
    enum Kind: CaseIterable { case caption, screenshot, video }
    private var parts: [Kind: String] = [:]
    private var userText = ""
    private var lastRendered = ""

    mutating func update(_ kind: Kind, text: String, currentText: String) -> String {
        if currentText != lastRendered {
            userText = currentText
            parts = [:]
        }
        parts[kind] = String(text.prefix(12_000))
        var chunks = userText.isEmpty ? [] : [userText]
        for key in Kind.allCases {
            if let part = parts[key], !part.isEmpty, !chunks.contains(where: { $0.contains(part) }) { chunks.append(part) }
        }
        lastRendered = chunks.joined(separator: "\n\n")
        return lastRendered
    }
}
