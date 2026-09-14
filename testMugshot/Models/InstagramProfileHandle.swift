import Foundation

enum InstagramProfileHandleError: LocalizedError, Equatable {
    case unsupportedAddress
    case invalidHandle

    var errorDescription: String? {
        switch self {
        case .unsupportedAddress:
            return "Enter an Instagram username or an instagram.com profile link."
        case .invalidHandle:
            return "Instagram usernames may use up to 30 letters, numbers, periods, or underscores."
        }
    }
}

enum InstagramProfileHandle {
    private static let allowedHosts = ["instagram.com", "www.instagram.com", "m.instagram.com"]
    private static let nonProfilePaths = [
        "about", "accounts", "developer", "direct", "explore", "legal", "p", "reel", "reels", "stories"
    ]

    static func normalize(_ value: String) throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate: String
        if trimmed.localizedCaseInsensitiveContains("://") {
            guard let components = URLComponents(string: trimmed),
                  components.scheme?.lowercased() == "https",
                  let host = components.host?.lowercased(),
                  allowedHosts.contains(host),
                  components.query == nil,
                  components.fragment == nil else {
                throw InstagramProfileHandleError.unsupportedAddress
            }
            let parts = components.path.split(separator: "/", omittingEmptySubsequences: true)
            guard parts.count == 1 else {
                throw InstagramProfileHandleError.unsupportedAddress
            }
            candidate = String(parts[0])
        } else {
            candidate = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        }

        let normalized = candidate.lowercased()
        guard (1...30).contains(normalized.count),
              normalized.unicodeScalars.allSatisfy({ scalar in
                  switch scalar.value {
                  case 48...57, 97...122, 46, 95: true
                  default: false
                  }
              }),
              !normalized.hasPrefix("."),
              !normalized.hasSuffix("."),
              !normalized.contains(".."),
              !nonProfilePaths.contains(normalized) else {
            throw InstagramProfileHandleError.invalidHandle
        }
        return normalized
    }

    static func profileURL(for storedValue: String?) -> URL? {
        guard let storedValue,
              let handle = try? normalize(storedValue) else { return nil }
        return URL(string: "https://www.instagram.com/\(handle)/")
    }
}
