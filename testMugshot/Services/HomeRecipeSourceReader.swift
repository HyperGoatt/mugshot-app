import Foundation

enum HomeRecipeSourceError: LocalizedError, Equatable {
    case invalidLink, unavailable, tooLarge, invalidMedia, videoTooLong
    var errorDescription: String? {
        switch self {
        case .invalidLink: "Paste a public Instagram post or TikTok video link."
        case .unavailable: "This post isn’t readable here. Paste its caption or add a screenshot or saved video instead. Your link can still be saved."
        case .tooLarge: "That source is too large to read. Try a screenshot or a shorter video."
        case .invalidMedia: "Couldn’t read that attachment. Try a screenshot or paste the instructions."
        case .videoTooLong: "Choose a video up to 60 seconds, or add screenshots of the recipe."
        }
    }
}

struct HomeRecipeSourceURL: Equatable, Sendable {
    enum Provider: Equatable, Sendable { case instagram, tiktok }
    let url: URL
    let provider: Provider

    init(_ raw: String) throws {
        guard var parts = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme?.lowercased() == "https", parts.user == nil, parts.password == nil,
              parts.port == nil, let host = parts.host?.lowercased() else { throw HomeRecipeSourceError.invalidLink }
        let path = parts.path.split(separator: "/").map(String.init)
        func matches(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }
        if ["instagram.com", "www.instagram.com", "m.instagram.com"].contains(host),
           path.count == 2, ["p", "reel", "tv"].contains(path[0]), matches(path[1], "^[A-Za-z0-9_-]{2,100}$") {
            provider = .instagram; parts.host = "www.instagram.com"
        } else if ["tiktok.com", "www.tiktok.com", "m.tiktok.com"].contains(host),
                  (path.count == 3 && matches(path[0], "^@[A-Za-z0-9_.-]{1,64}$") && ["video", "photo"].contains(path[1]) && matches(path[2], "^[0-9]{6,30}$")) ||
                    (path.count == 2 && path[0] == "t" && matches(path[1], "^[A-Za-z0-9_-]{2,100}$")) {
            provider = .tiktok; parts.host = "www.tiktok.com"
        } else if ["vm.tiktok.com", "vt.tiktok.com"].contains(host), path.count == 1,
                  matches(path[0], "^[A-Za-z0-9_-]{2,100}$") { provider = .tiktok }
        else { throw HomeRecipeSourceError.invalidLink }
        parts.scheme = "https"; parts.query = nil; parts.fragment = nil
        if provider == .instagram { parts.path = "/" + path.joined(separator: "/") + "/" }
        guard let url = parts.url else { throw HomeRecipeSourceError.invalidLink }
        self.url = url
    }

    static func allowsVideo(_ url: URL) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.scheme == "https",
              parts.user == nil, parts.password == nil, parts.port == nil, let host = parts.host?.lowercased() else { return false }
        return ["cdninstagram.com", "fbcdn.net", "tiktokcdn.com", "tiktokv.com", "byteoversea.com"].contains {
            host == $0 || host.hasSuffix("." + $0)
        }
    }
}

struct HomeRecipeSource: Sendable {
    let url: URL
    var title: String = ""
    var text: String = ""
    var creator: String = ""
    var videoURL: URL?
}

enum HomeRecipeSourceParser {
    static func parse(_ data: Data, contentType: String, source: HomeRecipeSourceURL) throws -> HomeRecipeSource {
        guard data.count <= 2_000_000 else { throw HomeRecipeSourceError.tooLarge }
        guard contentType.lowercased().contains("text/html"), let html = String(data: data, encoding: .utf8) else {
            throw HomeRecipeSourceError.unavailable
        }
        var metadata: [String: String] = [:]
        for tag in captures("<meta\\b[^>]*>", in: html) {
            var attrs: [String: String] = [:]
            for match in matches("([A-Za-z_:][-A-Za-z0-9_:]*)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')", in: tag) {
                let ns = tag as NSString
                let name = ns.substring(with: match.range(at: 1)).lowercased()
                let range = match.range(at: 2).location != NSNotFound ? match.range(at: 2) : match.range(at: 3)
                attrs[name] = decode(ns.substring(with: range))
            }
            if let key = attrs["property"] ?? attrs["name"], let value = attrs["content"] { metadata[key.lowercased()] = value }
        }
        var result = HomeRecipeSource(url: source.url, title: metadata["og:title"] ?? "", text: metadata["og:description"] ?? metadata["description"] ?? metadata["twitter:description"] ?? "")
        if source.provider == .tiktok {
            // Read only the selected post's object, never unrelated/recommended posts.
            for script in captures("<script\\b[^>]*id=[\"'](?:__UNIVERSAL_DATA_FOR_REHYDRATION__|SIGI_STATE)[\"'][^>]*>(.*?)</script>", in: html, group: 1) {
                guard let bytes = script.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { continue }
                let scope = json["__DEFAULT_SCOPE__"] as? [String: Any]
                let detail = scope?["webapp.video-detail"] as? [String: Any]
                let info = detail?["itemInfo"] as? [String: Any]
                var item = info?["itemStruct"] as? [String: Any]
                if item == nil, let module = json["ItemModule"] as? [String: Any], let id = source.url.pathComponents.last {
                    item = module[id] as? [String: Any]
                }
                if let caption = item?["desc"] as? String { result.text = caption }
                if let author = item?["author"] as? [String: Any], let name = author["uniqueId"] as? String { result.creator = "@" + name }
                let video = item?["video"] as? [String: Any]
                if let raw = video?["playAddr"] as? String, let url = URL(string: raw), HomeRecipeSourceURL.allowsVideo(url) { result.videoURL = url }
            }
        }
        if result.videoURL == nil, let raw = metadata["og:video:secure_url"] ?? metadata["og:video"],
           let url = URL(string: raw), HomeRecipeSourceURL.allowsVideo(url) { result.videoURL = url }
        if result.creator.isEmpty {
            result.creator = metadata["author"] ?? metadata["article:author"] ?? ""
            if source.provider == .tiktok, let handle = source.url.pathComponents.first(where: { $0.hasPrefix("@") }) { result.creator = handle }
        }
        result.text = String(result.text.prefix(12_000))
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 8, !["log in", "login", "sign up", "watch more", "make your day"].contains(where: { text.lowercased().hasPrefix($0) }) else {
            throw HomeRecipeSourceError.unavailable
        }
        return result
    }

    /// Deterministic fallback: only explicitly labelled sections, no invented amounts or steps.
    static func fields(in text: String) -> [CoffeeAssistanceField] {
        var section = "", output: [CoffeeAssistanceField] = []
        var pending = "", quote = "", numberedStep = false
        func flush() {
            guard !pending.isEmpty, !section.isEmpty, output.count < 40 else { pending = ""; quote = ""; return }
            output.append(CoffeeAssistanceField(key: section, value: pending, sourceQuote: quote))
            pending = ""; quote = ""
        }
        for raw in text.components(separatedBy: .newlines).prefix(160) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = line.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ": "))
            if ["ingredients", "you’ll need", "you'll need", "what you need"].contains(lower) {
                flush(); section = "ingredient"; continue
            }
            if ["steps", "instructions", "method", "directions", "preparation", "how to make"].contains(lower) {
                flush(); section = "step"; numberedStep = false; continue
            }
            if lower.hasPrefix("to make ") || lower == "to make" {
                flush()
                // A screenshot can contain syrup instructions followed by a latte.
                // Keep the first preparation together instead of combining recipes.
                if output.contains(where: { $0.key == "step" }) { break }
                section = "step"; continue
            }
            if ["notes", "tips", "nutrition", "source", "related recipes", "you may also like", "reviews", "comments"]
                .contains(where: { lower == $0 || lower.hasPrefix($0 + " ") }) || line.hasPrefix("#") {
                flush(); section = ""; continue
            }
            if ["print", "print recipe", "share", "save recipe", "subscribe", "sign up", "add to cart", "accept cookies"]
                .contains(lower) || lower.range(of: "^(?:get|save)\\s+[0-9]+%", options: .regularExpression) != nil { continue }
            guard !section.isEmpty, !line.isEmpty, line.count <= 500, output.count < 40 else { continue }
            let hasNumber = line.range(of: "^[0-9]+[.)]\\s+", options: .regularExpression) != nil
            let hasBullet = line.range(of: "^(?:[-•*●◦○]\\s*|o\\s+(?=[0-9¼½¾⅓⅔]))", options: .regularExpression) != nil
            let cleaned = line.replacingOccurrences(of: "^(?:[-•*●◦○]\\s*|o\\s+(?=[0-9¼½¾⅓⅔])|[0-9]+[.)]\\s+)", with: "", options: .regularExpression)
            guard !cleaned.isEmpty else { continue }
            let startsQuantity = cleaned.range(of: "^[0-9¼½¾⅓⅔⅛⅜⅝⅞]", options: .regularExpression) != nil
            if section == "ingredient" {
                let openParenthesis = pending.filter { $0 == "(" }.count > pending.filter { $0 == ")" }.count
                let unfinished = [" of", " the", " and", " or", " condensed", " insides", ","]
                    .contains { pending.lowercased().hasSuffix($0) }
                if hasBullet || startsQuantity || !(openParenthesis || unfinished) { flush() }
            } else {
                if hasNumber || hasBullet { flush(); numberedStep = hasNumber }
                else if !numberedStep, pending.last.map({ ".!?".contains($0) }) == true { flush() }
            }
            pending += (pending.isEmpty ? "" : " ") + cleaned
            quote += (quote.isEmpty ? "" : "\n") + line
        }
        flush()
        return output
    }

    private static func matches(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
        (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]))?
            .matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
    }
    private static func captures(_ pattern: String, in text: String, group: Int = 0) -> [String] {
        let ns = text as NSString
        return matches(pattern, in: text).compactMap { match in
            guard match.range(at: group).location != NSNotFound else { return nil }
            return ns.substring(with: match.range(at: group))
        }
    }
    private static func decode(_ text: String) -> String {
        var output = text
        for match in matches("&#(x[0-9a-f]+|[0-9]+);", in: text).reversed() {
            let token = (text as NSString).substring(with: match.range(at: 1))
            let value = token.lowercased().hasPrefix("x") ? UInt32(token.dropFirst(), radix: 16) : UInt32(token)
            if let value, let scalar = UnicodeScalar(value), let range = Range(match.range, in: output) { output.replaceSubrange(range, with: String(scalar)) }
        }
        for (entity, value) in ["&quot;": "\"", "&apos;": "'", "&#39;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&amp;": "&"] {
            output = output.replacingOccurrences(of: entity, with: value)
        }
        return output
    }
}

/// Ephemeral, unauthenticated reads of the one public source chosen by the user.
/// Every redirect is revalidated. No cookies, credentials, arbitrary hosts or response logs.
final class HomeRecipeSourceReader: @unchecked Sendable {
    private let protocolClasses: [AnyClass]?
    init(protocolClasses: [AnyClass]? = nil) { self.protocolClasses = protocolClasses }
    func read(_ raw: String) async throws -> HomeRecipeSource {
        let source = try HomeRecipeSourceURL(raw)
        let (data, response) = try await fetch(source.url, limit: 2_000_000, video: false)
        let final = try HomeRecipeSourceURL(response.url?.absoluteString ?? source.url.absoluteString)
        return try HomeRecipeSourceParser.parse(data, contentType: response.mimeType ?? "", source: final)
    }

    func video(_ url: URL) async throws -> URL {
        guard HomeRecipeSourceURL.allowsVideo(url) else { throw HomeRecipeSourceError.invalidLink }
        let (data, response) = try await fetch(url, limit: 30_000_000, video: true)
        guard response.mimeType?.hasPrefix("video/") == true else { throw HomeRecipeSourceError.invalidMedia }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        try data.write(to: file, options: .atomic)
        return file
    }

    private func fetch(_ url: URL, limit: Int, video: Bool) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        let config = URLSessionConfiguration.ephemeral
        if let protocolClasses { config.protocolClasses = protocolClasses }
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil; config.urlCache = nil
        config.timeoutIntervalForRequest = 18; config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        let delegate = RedirectGuard(video: video)
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url); request.setValue(video ? "video/*" : "text/html", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
              response.expectedContentLength <= limit else { throw HomeRecipeSourceError.unavailable }
        var data = Data()
        for try await byte in bytes {
            if data.count % 4096 == 0 { try Task.checkCancellation() }
            guard data.count < limit else { throw HomeRecipeSourceError.tooLarge }
            data.append(byte)
        }
        return (data, response)
    }

    private final class RedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        let video: Bool
        private let lock = NSLock()
        private var count = 0
        init(video: Bool) { self.video = video }
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            lock.lock(); count += 1; let allowedCount = count <= 5; lock.unlock()
            guard allowedCount, let url = request.url,
                  video ? HomeRecipeSourceURL.allowsVideo(url) : (try? HomeRecipeSourceURL(url.absoluteString)) != nil else {
                completionHandler(nil); return
            }
            completionHandler(request)
        }
    }
}
