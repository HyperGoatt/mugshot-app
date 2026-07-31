import Foundation

enum SipCaptionPolicy {
    static let maximumLength = 1_000

    static func normalized(_ caption: String) -> String {
        caption.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func characterCount(_ caption: String) -> Int {
        caption.unicodeScalars.count
    }

    static func validationError(for caption: String) -> SipCaptionValidationError? {
        let normalizedCaption = normalized(caption)
        guard !normalizedCaption.isEmpty else { return .required }
        guard characterCount(normalizedCaption) <= maximumLength else {
            return .tooLong(maximum: maximumLength)
        }
        return nil
    }

    static func validateAndNormalize(_ caption: String) throws -> String {
        if let error = validationError(for: caption) {
            throw error
        }
        return normalized(caption)
    }
}

enum SipCaptionValidationError: LocalizedError, Equatable {
    case required
    case tooLong(maximum: Int)

    var errorDescription: String? {
        switch self {
        case .required:
            return "Add a caption before saving."
        case .tooLong(let maximum):
            return "Keep the caption to \(maximum.formatted()) characters or fewer."
        }
    }
}
