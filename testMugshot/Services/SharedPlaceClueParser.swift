import Foundation

struct PlaceShareClue: Equatable {
    let query: String
    let source: PlaceImportSource
}

enum SharedPlaceClueParser {
    static func clue(
        url: URL?,
        text: String?,
        suggestedName: String?,
        resolvedURL: URL? = nil
    ) -> PlaceShareClue {
        let effectiveURL = resolvedURL ?? url
        let source = source(for: url ?? effectiveURL)
        if let query = query(from: effectiveURL, source: source) {
            return PlaceShareClue(query: query, source: source)
        }
        if let text = clean(text), !looksLikeBareURL(text) {
            return PlaceShareClue(
                query: text,
                source: source == .generalURL ? .text : source
            )
        }
        if let suggestedName = clean(suggestedName), !looksLikeBareURL(suggestedName) {
            return PlaceShareClue(query: suggestedName, source: source)
        }
        return PlaceShareClue(query: "", source: source)
    }

    private static func source(for url: URL?) -> PlaceImportSource {
        let host = url?.host?.lowercased() ?? ""
        if host.contains("google") || host.contains("goo.gl") || host == "g.co" {
            return .googleMaps
        }
        if host.contains("apple.com") { return .appleMaps }
        if host.contains("tiktok") { return .tiktok }
        if host.contains("instagram") { return .instagram }
        return url == nil ? .text : .generalURL
    }

    private static func query(from url: URL?, source: PlaceImportSource) -> String? {
        guard let url else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let keys: [String]
        switch source {
        case .appleMaps: keys = ["q", "address"]
        case .googleMaps: keys = ["query", "q", "destination"]
        default: keys = ["q", "query", "place", "location"]
        }
        for key in keys {
            if let rawValue = items.first(where: { $0.name == key })?.value,
               let value = clean(rawValue.replacingOccurrences(of: "+", with: " ")) {
                return value
            }
        }
        let path = url.path.removingPercentEncoding ?? url.path
        if let placeRange = path.range(of: "/place/"),
           let name = path[placeRange.upperBound...].split(separator: "/").first {
            return clean(String(name).replacingOccurrences(of: "+", with: " "))
        }
        return nil
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : String(cleaned.prefix(180))
    }

    private static func looksLikeBareURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        return url.scheme != nil && url.host != nil
    }
}
