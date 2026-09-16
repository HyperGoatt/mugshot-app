import SwiftUI
import UIKit

enum MugshotPostAspectRatioPolicy {
    static let minimum: CGFloat = 3.0 / 4.0
    static let maximum: CGFloat = 1.91
    static let fallback: CGFloat = minimum

    static func clamped(_ ratio: CGFloat) -> CGFloat {
        guard ratio.isFinite, ratio > 0 else { return fallback }
        return min(max(ratio, minimum), maximum)
    }

    static func ratio(for size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return fallback }
        return clamped(size.width / size.height)
    }

    static func carouselRatio(for imageSizes: [CGSize]) -> CGFloat {
        guard let first = imageSizes.first else { return fallback }
        return ratio(for: first)
    }
}

enum MugshotPostLocationLine {
    static func locality(
        address: String?,
        cityState: String?,
        city: String?
    ) -> String? {
        locality(from: address)
            ?? locality(from: cityState)
            ?? locality(from: city)
    }

    static func locality(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        var components = rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !components.isEmpty else { return nil }

        if let last = components.last,
           ["united states", "usa", "us"].contains(last.lowercased()) {
            components.removeLast()
        }

        if let stateIndex = components.lastIndex(where: isStateComponent),
           stateIndex > components.startIndex {
            let city = components[components.index(before: stateIndex)]
            let state = normalizedState(components[stateIndex])
            guard !city.isEmpty, let state else { return nil }
            return "\(city), \(state)"
        }

        guard let first = components.first else { return nil }

        // A lone street line is not a locality and is too precise for the
        // compact post/share surface. Prefer no secondary line until a city is
        // available.
        if components.count == 1, first.contains(where: \.isNumber) {
            return nil
        }

        if components.count >= 2,
           first.contains(where: \.isNumber),
           let last = components.last {
            return last
        }
        return first
    }

    static func displayName(name: String, locality: String?) -> String {
        guard let locality = locality?.trimmingCharacters(in: .whitespacesAndNewlines),
              !locality.isEmpty,
              locality.caseInsensitiveCompare(name) != .orderedSame else {
            return name
        }
        return "\(name) | \(locality)"
    }

    private static func isStateComponent(_ value: String) -> Bool {
        normalizedState(value) != nil
    }

    private static func normalizedState(_ value: String) -> String? {
        let candidate = value
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)?
            .uppercased()
        guard let candidate,
              candidate.count == 2,
              candidate.allSatisfy(\.isLetter) else {
            return nil
        }
        return candidate
    }
}

final class MugshotPostAspectRatioCache: @unchecked Sendable {
    static let shared = MugshotPostAspectRatioCache()
    private let cache = NSCache<NSString, NSNumber>()

    func ratio(for key: String) -> CGFloat? {
        cache.object(forKey: key as NSString).map { CGFloat(truncating: $0) }
    }

    func store(_ ratio: CGFloat, for key: String) {
        cache.setObject(NSNumber(value: Double(ratio)), forKey: key as NSString)
    }
}

private struct MugshotImageSizeReporterKey: EnvironmentKey {
    static let defaultValue: ((CGSize) -> Void)? = nil
}

struct MugshotInMemoryPostImage: View {
    let image: UIImage
    @Environment(\.mugshotImageSizeReporter) private var reportImageSize

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .onAppear {
                reportImageSize?(image.size)
            }
            .onChange(of: image.size) { _, newSize in
                reportImageSize?(newSize)
            }
    }
}

extension EnvironmentValues {
    var mugshotImageSizeReporter: ((CGSize) -> Void)? {
        get { self[MugshotImageSizeReporterKey.self] }
        set { self[MugshotImageSizeReporterKey.self] = newValue }
    }
}

enum MugshotPostMediaSource: Hashable {
    case local(String)
    case remote(String)
    case asset(String)
    case placeholder(usesMugsyFallback: Bool, stableID: String)

    var cacheKey: String {
        switch self {
        case .local(let path): return "local:\(path)"
        case .remote(let url): return "remote:\(url)"
        case .asset(let name): return "asset:\(name)"
        case .placeholder(let usesMugsyFallback, let stableID):
            return "placeholder:\(usesMugsyFallback):\(stableID)"
        }
    }
}

struct MugshotPostMediaImage: View {
    let source: MugshotPostMediaSource
    @Environment(\.mugshotImageSizeReporter) private var reportImageSize

    var body: some View {
        Group {
            switch source {
            case .local(let path):
                PhotoImageView(photoPath: path)
            case .remote(let url):
                RemotePhotoImageView(urlString: url, placeholderSystemName: "photo.on.rectangle")
            case .asset(let name):
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .onAppear {
                        if let size = UIImage(named: name)?.size {
                            reportImageSize?(size)
                        }
                    }
            case .placeholder(let usesMugsyFallback, let stableID):
                RemoteFeedNoPhotoPoster(
                    usesMugsyFallback: usesMugsyFallback,
                    stableID: stableID
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

struct MugshotAdaptivePostMedia<Content: View>: View {
    let ratioCacheKey: String
    let drinkName: String
    let locationName: String
    let locationDetail: String?
    let score: Double
    let cornerRadius: CGFloat
    let onLocationTap: (() -> Void)?
    let locationAccessibilityIdentifier: String?
    let onMediaTap: (() -> Void)?
    private let content: Content
    @State private var aspectRatio: CGFloat

    init(
        ratioCacheKey: String,
        drinkName: String,
        locationName: String,
        locationDetail: String? = nil,
        score: Double,
        cornerRadius: CGFloat = 18,
        onLocationTap: (() -> Void)? = nil,
        locationAccessibilityIdentifier: String? = nil,
        onMediaTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.ratioCacheKey = ratioCacheKey
        self.drinkName = drinkName
        self.locationName = locationName
        self.locationDetail = locationDetail
        self.score = score
        self.cornerRadius = cornerRadius
        self.onLocationTap = onLocationTap
        self.locationAccessibilityIdentifier = locationAccessibilityIdentifier
        self.onMediaTap = onMediaTap
        self.content = content()
        _aspectRatio = State(
            initialValue: MugshotPostAspectRatioCache.shared.ratio(for: ratioCacheKey)
                ?? MugshotPostAspectRatioPolicy.fallback
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let onMediaTap {
                mediaArtwork
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onMediaTap)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Open \(drinkName) at \(displayLocationName)")
                    .accessibilityHint("Opens post details")
            } else {
                mediaArtwork
            }

            MugshotPostArtworkOverlay(
                drinkName: drinkName,
                locationName: locationName,
                locationDetail: locationDetail,
                score: score,
                onLocationTap: onLocationTap,
                locationAccessibilityIdentifier: locationAccessibilityIdentifier
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 17)
        }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityElement(children: onLocationTap == nil ? .ignore : .contain)
            .accessibilityLabel(score > 0
                ? "\(drinkName) at \(displayLocationName), Mugshot score \(score.formatted(.number.precision(.fractionLength(1)))) out of 5"
                : "\(drinkName) at \(displayLocationName), Unrated")
    }

    private var displayLocationName: String {
        MugshotPostLocationLine.displayName(name: locationName, locality: locationDetail)
    }

    private var mediaArtwork: some View {
        content
            .environment(\.mugshotImageSizeReporter, reportImageSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.38),
                        .init(color: .black.opacity(0.16), location: 0.60),
                        .init(color: .black.opacity(0.78), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
    }

    private func reportImageSize(_ size: CGSize) {
        let nextRatio = MugshotPostAspectRatioPolicy.ratio(for: size)
        MugshotPostAspectRatioCache.shared.store(nextRatio, for: ratioCacheKey)
        guard abs(aspectRatio - nextRatio) > 0.001 else { return }
        aspectRatio = nextRatio
    }
}

struct MugshotPostArtworkOverlay: View {
    let drinkName: String
    let locationName: String
    let locationDetail: String?
    let score: Double
    let onLocationTap: (() -> Void)?
    let locationAccessibilityIdentifier: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(drinkName)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .tracking(-0.35)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)

                if let onLocationTap {
                    Button(action: onLocationTap) {
                        HStack(spacing: 5) {
                            locationLine
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(locationAccessibilityIdentifier ?? "sip.detail.cafe")
                    .accessibilityLabel("Open \(locationName) cafe details")
                    .accessibilityHint("Opens this cafe")
                } else {
                    locationLine
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                if score > 0 {
                    Text(score.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 38, weight: .regular, design: .serif))
                        .monospacedDigit()
                    Text("OUT OF 5")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.3)
                } else {
                    Text("Unrated").font(.subheadline)
                }
            }
            .fixedSize()
            .accessibilityHidden(true)
        }
        .foregroundStyle(Color.white)
        .shadow(color: .black.opacity(0.42), radius: 5, x: 0, y: 2)
    }

    @ViewBuilder
    private var locationLine: some View {
        if let locality = locationDetail?.trimmingCharacters(in: .whitespacesAndNewlines),
           !locality.isEmpty,
           locality.caseInsensitiveCompare(locationName) != .orderedSame {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) {
                    Text(locationName)
                        .foregroundColor(.white)
                    Text("|")
                        .foregroundColor(.white.opacity(0.78))
                    Text(locality)
                        .foregroundColor(.mugshotMint)
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 1) {
                    Text(locationName)
                        .foregroundColor(.white)
                    Text(locality)
                        .foregroundColor(.mugshotMint)
                }
            }
        } else {
            Text(locationName)
                .foregroundColor(.white)
        }
    }
}

enum MugshotCaptionTruncation {
    static let suffix = "… more"

    static func truncatedText(
        _ text: String,
        width: CGFloat,
        font: UIFont,
        lineLimit: Int = 2
    ) -> String? {
        guard width > 0, lineLimit > 0 else { return nil }
        let fullHeight = measuredHeight(text, width: width, font: font)
        let allowedHeight = ceil(font.lineHeight * CGFloat(lineLimit))
        guard fullHeight > allowedHeight + 0.5 else { return nil }

        let characters = Array(text)
        var lower = 0
        var upper = characters.count
        var best = ""

        while lower <= upper {
            let midpoint = (lower + upper) / 2
            let prefix = String(characters.prefix(midpoint))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = prefix + suffix
            if measuredHeight(candidate, width: width, font: font) <= allowedHeight + 0.5 {
                best = prefix
                lower = midpoint + 1
            } else {
                upper = midpoint - 1
            }
        }

        return best + suffix
    }

    private static func measuredHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(bounds.height)
    }
}

struct MugshotExpandableCaption: View {
    let caption: String
    var mentions: [Mention] = []
    var alwaysExpanded = false
    var usesDetailTypography = false
    @State private var isExpanded = false
    @State private var availableWidth: CGFloat = 0

    private var measurementFont: UIFont {
        usesDetailTypography
            ? UIFont.preferredFont(forTextStyle: .body)
            : UIFont.systemFont(ofSize: 15)
    }

    private var truncatedCaption: String? {
        guard !alwaysExpanded, !isExpanded else { return nil }
        return MugshotCaptionTruncation.truncatedText(
            caption,
            width: availableWidth,
            font: measurementFont
        )
    }

    var body: some View {
        Group {
            if let truncatedCaption {
                Button {
                    isExpanded = true
                } label: {
                    Text(MentionTextFormatter.attributedString(for: truncatedCaption))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(caption)
                .accessibilityHint("Expands the full caption")
                .accessibilityIdentifier("feed.caption.more")
            } else {
                Text(MentionTextFormatter.attributedString(for: caption))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(caption)
            }
        }
        .font(usesDetailTypography ? .body : .system(size: 15))
        .foregroundStyle(Color.espressoBrown.opacity(0.78))
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { availableWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in
                        availableWidth = width
                    }
            }
        }
    }
}

struct MugshotFeedPostPresentation {
    let visitID: UUID
    let mediaSources: [MugshotPostMediaSource]
    let drinkName: String
    let locationName: String
    let locationDetail: String?
    let score: Double
    let caption: String?
    let mentions: [Mention]
    let authorName: String
    let username: String
    let avatarURL: String?
    let timestamp: String
    let authorBadge: String?
    let recommendation: String?
    let recommendationSystemImage: String
}

/// Owned by the Feed, rather than a recycled LazyVStack row. This object does
/// not publish changes across the Feed when one carousel advances.
final class FeedMediaSelectionStore {
    private var selections: [UUID: String] = [:]
    func selection(for visitID: UUID, available: [String]) -> String? {
        if let key = selections[visitID], available.contains(key) { return key }
        selections[visitID] = available.first
        return available.first
    }
    func select(_ key: String?, for visitID: UUID) { selections[visitID] = key }
}

private struct FeedMediaSelectionKey: EnvironmentKey {
    static let defaultValue: FeedMediaSelectionStore? = nil
}

extension EnvironmentValues {
    var feedMediaSelections: FeedMediaSelectionStore? {
        get { self[FeedMediaSelectionKey.self] }
        set { self[FeedMediaSelectionKey.self] = newValue }
    }
}

struct MugshotFeedPostCard<Footer: View>: View {
    let presentation: MugshotFeedPostPresentation
    let onOpen: () -> Void
    var onAuthorTap: (() -> Void)? = nil
    var onCafeTap: (() -> Void)? = nil
    var cafeAccessibilityIdentifier: String? = nil
    var onMediaOpen: ((String) -> Void)? = nil
    @State private var selectedMediaKey: String?
    @Environment(\.feedMediaSelections) private var mediaSelections
    @ViewBuilder let footer: () -> Footer

    init(
        presentation: MugshotFeedPostPresentation,
        onOpen: @escaping () -> Void,
        onAuthorTap: (() -> Void)? = nil,
        onCafeTap: (() -> Void)? = nil,
        cafeAccessibilityIdentifier: String? = nil,
        onMediaOpen: ((String) -> Void)? = nil,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.presentation = presentation
        self.onOpen = onOpen
        self.onAuthorTap = onAuthorTap
        self.onCafeTap = onCafeTap
        self.cafeAccessibilityIdentifier = cafeAccessibilityIdentifier
        self.onMediaOpen = onMediaOpen
        let first = presentation.mediaSources.first?.cacheKey
        _selectedMediaKey = State(initialValue: first)
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 9) {
                    Button(action: onAuthorTap ?? onOpen) {
                        HStack(alignment: .center, spacing: 9) {
                        MugshotAvatar(
                            name: presentation.authorName,
                            size: 34,
                            imageURL: presentation.avatarURL
                        )

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(presentation.authorName)
                                    .font(.system(size: 13, weight: .bold))
                                    .lineLimit(1)
                                if let badge = presentation.authorBadge {
                                    Text(badge)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.mugshotMint.opacity(0.5), in: Capsule())
                                }
                            }
                            Text("@\(presentation.username) · \(presentation.timestamp)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.tertiaryText)
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(Color.espressoBrown)
                    .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open @\(presentation.username)'s profile")

                    Spacer(minLength: 8)
                }

                if let recommendation = presentation.recommendation {
                    Button(action: onOpen) {
                        Label(recommendation, systemImage: presentation.recommendationSystemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.mugshotSage)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Recommended because \(recommendation)")
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            MugshotAdaptivePostMedia(
                    ratioCacheKey: presentation.mediaSources.first?.cacheKey
                        ?? "placeholder:false:\(presentation.visitID.uuidString)",
                    drinkName: presentation.drinkName,
                    locationName: presentation.locationName,
                    locationDetail: presentation.locationDetail,
                    score: presentation.score,
                    onLocationTap: onCafeTap,
                    locationAccessibilityIdentifier: cafeAccessibilityIdentifier,
                    onMediaTap: openSelectedMedia
                ) {
                    MugshotFeedMediaCarousel(
                        sources: presentation.mediaSources,
                        selectedMediaKey: $selectedMediaKey
                    )
                }

            if let caption = presentation.caption {
                MugshotExpandableCaption(caption: caption, mentions: presentation.mentions)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
            }

            footer()
        }
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.foamWhite.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("feed.visitCard.\(presentation.visitID.uuidString)")
        .onAppear {
            if let mediaSelections {
                selectedMediaKey = mediaSelections.selection(
                    for: presentation.visitID,
                    available: presentation.mediaSources.map(\.cacheKey)
                )
            }
        }
        .onChange(of: selectedMediaKey) { _, key in
            mediaSelections?.select(key, for: presentation.visitID)
        }
        .onChange(of: presentation.mediaSources.map(\.cacheKey)) { _, keys in
            if let selectedMediaKey, keys.contains(selectedMediaKey) { return }
            selectedMediaKey = keys.first
        }
    }

    private func openSelectedMedia() {
        guard let selectedMediaKey else {
            onOpen()
            return
        }
        if let onMediaOpen {
            onMediaOpen(selectedMediaKey)
        } else {
            onOpen()
        }
    }
}

enum MugshotFeedMediaLoadingPolicy {
    static func loadedIndices(count: Int, selectedIndex: Int) -> Set<Int> {
        guard count > 0 else { return [] }
        let current = min(max(selectedIndex, 0), count - 1)
        return Set(max(current - 1, 0)...min(current + 1, count - 1))
    }
}

private struct MugshotFeedMediaCarousel: View {
    let sources: [MugshotPostMediaSource]
    @Binding var selectedMediaKey: String?
    @Environment(\.mugshotImageSizeReporter) private var reportCoverSize

    var body: some View {
        let resolvedSources = sources.isEmpty
            ? [MugshotPostMediaSource.placeholder(usesMugsyFallback: false, stableID: "feed")]
            : sources
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedMediaKey) {
                ForEach(Array(resolvedSources.enumerated()), id: \.element.cacheKey) { index, source in
                    Group {
                        if loadedIndices.contains(index) {
                            MugshotPostMediaImage(source: source)
                                .environment(
                                    \.mugshotImageSizeReporter,
                                    index == 0 ? reportCoverSize : nil
                                )
                        } else {
                            Color.sandBeige.opacity(0.72)
                                .accessibilityHidden(true)
                        }
                    }
                        .tag(Optional(source.cacheKey))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if resolvedSources.count > 1 {
                HStack(spacing: 4) {
                    ForEach(resolvedSources, id: \.cacheKey) { source in
                        Circle()
                            .fill(source.cacheKey == selectedMediaKey ? Color.foamWhite : Color.foamWhite.opacity(0.46))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.28), in: Capsule())
                .padding(12)
                .accessibilityLabel("Photo \(selectedIndex + 1) of \(resolvedSources.count)")
            }
        }
    }

    private var selectedIndex: Int {
        max(sources.firstIndex { $0.cacheKey == selectedMediaKey } ?? 0, 0)
    }

    private var loadedIndices: Set<Int> {
        MugshotFeedMediaLoadingPolicy.loadedIndices(
            count: sources.count,
            selectedIndex: selectedIndex
        )
    }
}
