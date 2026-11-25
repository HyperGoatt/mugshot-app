import Foundation

enum MugsyNotificationFamily: String, Codable, CaseIterable, Sendable {
    case firstMemory = "first_memory"
    case secondMemory = "second_memory"
    case photoMemory = "photo_memory"
    case repeatMemory = "repeat_memory"
    case homeMemory = "home_memory"
    case weeklyPour = "weekly_pour"
    case returnMemory = "return_memory"
    case onThisDay = "on_this_day"
}

struct MugsyNotificationCopyTemplate: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let family: MugsyNotificationFamily
    let title: String
    let body: String
    /// Raw MugsyCatalogPose identifier; Foundation-only selection stays testable.
    let pose: String
    let asset: String
    let requires: [String]
    let destination: String
}

struct MugsyNotificationCopyUse: Equatable, Sendable {
    let templateID: String
    let usedAt: Date
}

/// The JSON in functions/_shared is the single reviewed copy authority. The app
/// bundles that same file; a missing or invalid registry cannot produce a send.
struct MugsyNotificationCopyCatalog: Codable, Sendable {
    let version: Int
    let locale: String
    let templates: [MugsyNotificationCopyTemplate]

    static let repeatCooldown: TimeInterval = 28 * 24 * 60 * 60
    static let allowedFacts: Set<String> = [
        "no_memory", "one_memory", "photo_interest", "repeat_available",
        "home_interest", "eligible_week", "return_eligible", "eligible_anniversary"
    ]

    init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
        try validate()
    }

    static func load(bundle: Bundle = .main) -> Self? {
        guard let url = bundle.url(forResource: "mugsy-copy-v1", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? Self(data: data)
    }

    func select(
        family: MugsyNotificationFamily,
        facts: Set<String>,
        recentUses: [MugsyNotificationCopyUse],
        now: Date,
        rotationKey: String
    ) -> MugsyNotificationCopyTemplate? {
        let threshold = now.addingTimeInterval(-Self.repeatCooldown)
        let unavailable = Set(recentUses.filter { $0.usedAt > threshold }.map(\.templateID))
        let eligible = templates.filter {
            $0.family == family && Set($0.requires).isSubset(of: facts)
                && !unavailable.contains($0.id)
        }.sorted { $0.id < $1.id }
        guard !eligible.isEmpty else { return nil }
        // Swift's Hasher changes between processes. FNV-1a is stable across
        // launches and architectures; rotation keys stay outside analytics.
        let day = Int64(floor(now.timeIntervalSince1970 / 86400))
        let hash = "\(rotationKey):\(day)".utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        return eligible[Int(hash % UInt64(eligible.count))]
    }

    /// Safe presentation-only fallback. Transport always requires a validated
    /// registry. Contracts assert this preview matches the canonical variant.
    static var previewSecondMemory: MugsyNotificationCopyTemplate {
        load()?.templates.first { $0.id == "second_memory_1" }
            ?? MugsyNotificationCopyTemplate(
                id: "second_memory_1", family: .secondMemory,
                title: "The sequel could be good",
                body: "Had a sip worth keeping? There’s room for the next chapter.",
                pose: "journalKeeper", asset: "MugsyPoseJournal", requires: ["one_memory"],
                destination: "composer"
            )
    }

    private func validate() throws {
        guard version == 1, locale == "en", templates.count == 32,
              Set(templates.map(\.id)).count == templates.count else {
            throw CatalogError.invalidRegistry
        }
        for family in MugsyNotificationFamily.allCases {
            let variants = templates.filter { $0.family == family }
            guard Set(variants.map(\.id)) == Set((1...4).map { "\(family.rawValue)_\($0)" }) else {
                throw CatalogError.invalidRegistry
            }
        }
        for template in templates {
            guard !template.title.isEmpty, template.title.count <= 64,
                  !template.body.isEmpty, template.body.count <= 160,
                  !template.requires.isEmpty,
                  Set(template.requires).isSubset(of: Self.allowedFacts),
                  Self.requiredFact(for: template.family).map({ template.requires.contains($0) }) == true,
                  Self.presentation(for: template.family) == [template.pose, template.asset, template.destination],
                  !template.title.contains("\n"), !template.body.contains("\n") else {
                throw CatalogError.invalidRegistry
            }
        }
    }

    private static func requiredFact(for family: MugsyNotificationFamily) -> String? {
        switch family {
        case .firstMemory: "no_memory"
        case .secondMemory: "one_memory"
        case .photoMemory: "photo_interest"
        case .repeatMemory: "repeat_available"
        case .homeMemory: "home_interest"
        case .weeklyPour: "eligible_week"
        case .returnMemory: "return_eligible"
        case .onThisDay: "eligible_anniversary"
        }
    }

    private static func presentation(for family: MugsyNotificationFamily) -> [String] {
        switch family {
        case .firstMemory, .returnMemory: ["welcomeWave", "MugsyPoseWave", "composer"]
        case .secondMemory: ["journalKeeper", "MugsyPoseJournal", "composer"]
        case .photoMemory: ["cameraCompanion", "MugsyPoseCamera", "composer"]
        case .repeatMemory: ["cozyRitual", "MugsyPoseCozy", "repeat"]
        case .homeMemory: ["beanKeeper", "MugsyPoseBeans", "home"]
        case .weeklyPour: ["journalKeeper", "MugsyPoseJournal", "weekly_pour"]
        case .onThisDay: ["journalKeeper", "MugsyPoseJournal", "memory"]
        }
    }

    enum CatalogError: Error { case invalidRegistry }
}
