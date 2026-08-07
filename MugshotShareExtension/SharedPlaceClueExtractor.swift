import Foundation

struct SharedPlaceClue: Equatable {
    let query: String
    let source: ExtensionPlaceImportSource
}

enum SharedPlaceClueExtractor {
    static func clue(url: URL?, text: String?, suggestedName: String?) async -> SharedPlaceClue {
        let resolvedURL = await resolvedURLIfNeeded(url)
        let source = source(for: resolvedURL ?? url)
        let cleanedText = clean(text)

        if let urlQuery = query(from: resolvedURL ?? url, source: source) {
            return SharedPlaceClue(query: urlQuery, source: source)
        }
        if let cleanedText, !looksLikeBareURL(cleanedText) {
            return SharedPlaceClue(query: cleanedText, source: source == .generalURL ? .text : source)
        }
        if let suggested = clean(suggestedName), !looksLikeBareURL(suggested) {
            return SharedPlaceClue(query: suggested, source: source)
        }
        return SharedPlaceClue(query: "", source: source)
    }

    private static func source(for url: URL?) -> ExtensionPlaceImportSource {
        let host = url?.host?.lowercased() ?? ""
        if host.contains("google") || host.contains("goo.gl") { return .googleMaps }
        if host.contains("apple.com") { return .appleMaps }
        if host.contains("tiktok") { return .tiktok }
        if host.contains("instagram") { return .instagram }
        return url == nil ? .text : .generalURL
    }

    private static func query(
        from url: URL?,
        source: ExtensionPlaceImportSource
    ) -> String? {
        guard let url else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let preferredKeys: [String]
        switch source {
        case .appleMaps: preferredKeys = ["q", "address"]
        case .googleMaps: preferredKeys = ["query", "q", "destination"]
        default: preferredKeys = ["q", "query", "place", "location"]
        }
        for key in preferredKeys {
            if let rawValue = queryItems.first(where: { $0.name == key })?.value,
               let value = clean(rawValue.replacingOccurrences(of: "+", with: " ")) {
                return value
            }
        }

        let path = url.path.removingPercentEncoding ?? url.path
        if let placeRange = path.range(of: "/place/") {
            let remainder = path[placeRange.upperBound...]
            if let first = remainder.split(separator: "/").first {
                return clean(String(first).replacingOccurrences(of: "+", with: " "))
            }
        }
        return nil
    }

    private static func resolvedURLIfNeeded(_ url: URL?) async -> URL? {
        guard let url else { return nil }
        let host = url.host?.lowercased() ?? ""
        let isShort = host == "maps.app.goo.gl" || host == "goo.gl" || host == "g.co"
        guard isShort else { return url }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.httpMethod = "GET"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return response.url ?? url
        } catch {
            return url
        }
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(180))
    }

    private static func looksLikeBareURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        return url.scheme != nil && url.host != nil
    }
}
