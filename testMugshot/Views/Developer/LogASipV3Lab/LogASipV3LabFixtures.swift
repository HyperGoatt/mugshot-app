#if DEBUG
import Foundation

enum V3LabStep: Int, CaseIterable, Identifiable {
    case setup
    case sip
    case context
    case publish
    case passport

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .setup: return "Log a Sip"
        case .sip: return "How was the sip?"
        case .context: return "How was the cafe?"
        case .publish: return "Publish Mugshot"
        case .passport: return "Taste Passport"
        }
    }
}

enum V3LabContext: String, CaseIterable, Identifiable {
    case cafe
    case home
    case elsewhere

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cafe: return "Cafe"
        case .home: return "Home"
        case .elsewhere: return "Elsewhere"
        }
    }

    var icon: String {
        switch self {
        case .cafe: return "storefront"
        case .home: return "house"
        case .elsewhere: return "mappin.and.ellipse"
        }
    }

    var reflectionTitle: String {
        switch self {
        case .cafe: return "How was the cafe?"
        case .home: return "Would you make it again?"
        case .elsewhere: return "How was the setting?"
        }
    }

    var scoreTitle: String {
        switch self {
        case .cafe: return "Cafe score"
        case .home: return "Make it again"
        case .elsewhere: return "Setting score"
        }
    }
}

enum V3LabImportance: String, CaseIterable, Identifiable {
    case less
    case normal
    case more
    case most

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var weight: Double {
        switch self {
        case .less: return 0.5
        case .normal: return 1
        case .more: return 1.5
        case .most: return 2.25
        }
    }
}

enum V3LabAudience: String, CaseIterable, Identifiable {
    case `private`
    case friends
    case everyone

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var breadth: Int {
        switch self {
        case .private: return 0
        case .friends: return 1
        case .everyone: return 2
        }
    }
}

enum V3LabRawNoteVisibility: String, CaseIterable, Identifiable {
    case `private`
    case friends
    case everyone

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var breadth: Int {
        switch self {
        case .private: return 0
        case .friends: return 1
        case .everyone: return 2
        }
    }
}

enum V3LabMakeAgain: String, CaseIterable, Identifiable {
    case yes
    case withATweak
    case notThisVersion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yes: return "Yes"
        case .withATweak: return "With a tweak"
        case .notThisVersion: return "Not this one"
        }
    }
}

struct V3LabCriterion: Identifiable, Equatable {
    let id: String
    var title: String
    var systemImage: String
    var rating: Double
    var importance: V3LabImportance
    var isPinned: Bool
}

struct V3LabSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
}

struct V3LabDraft: Equatable {
    var context: V3LabContext
    var coverIndex: Int
    var drinkName: String
    var cafeName: String
    var settingName: String
    var homeSetupName: String
    var sipNote: String
    var contextNote: String
    var caption: String
    var sipScore: Double
    var contextScore: Double
    var sipCriteria: [V3LabCriterion]
    var contextCriteria: [V3LabCriterion]
    var audience: V3LabAudience
    var rawNoteVisibility: V3LabRawNoteVisibility
    var invitedFriendCount: Int
    var makeAgain: V3LabMakeAgain
    var recipeVersion: Int
    var didUsePlaceholder: Bool

    var contextDisplayName: String {
        switch context {
        case .cafe: return cafeName
        case .home: return homeSetupName
        case .elsewhere: return settingName
        }
    }

    var contextLabel: String {
        switch context {
        case .cafe: return "Cafe"
        case .home: return "Home setup"
        case .elsewhere: return "Setting"
        }
    }

    var contextScoreLabel: String {
        switch context {
        case .cafe: return "Cafe"
        case .home: return "Home"
        case .elsewhere: return "Setting"
        }
    }

    var mugshotScore: Double {
        guard context != .home else { return sipScore }
        return ((sipScore + contextScore) / 2 * 2).rounded() / 2
    }

    var allowedRawNoteVisibilities: [V3LabRawNoteVisibility] {
        V3LabRawNoteVisibility.allCases.filter { $0.breadth <= audience.breadth }
    }

    mutating func constrainRawNoteVisibility() {
        guard rawNoteVisibility.breadth > audience.breadth else { return }
        switch audience {
        case .private: rawNoteVisibility = .private
        case .friends: rawNoteVisibility = .friends
        case .everyone: break
        }
    }

    func weightedAverage(for criteria: [V3LabCriterion]) -> Double? {
        let rated = criteria.filter { $0.rating > 0 }
        let totalWeight = rated.reduce(0) { $0 + $1.importance.weight }
        guard totalWeight > 0 else { return nil }
        let sum = rated.reduce(0) { $0 + ($1.rating * $1.importance.weight) }
        return (sum / totalWeight * 10).rounded() / 10
    }

    static let fixture = V3LabDraft(
        context: .cafe,
        coverIndex: 0,
        drinkName: "Iced Orange Creamsicle",
        cafeName: "The Daily",
        settingName: "Window seat on the Coast Starlight",
        homeSetupName: "Joe's Home Cafe",
        sipNote: "Orange hits first, fades fast, then turns thin and milky.",
        contextNote: "Quiet in the back, louder near the bar.\nBeautiful menu, hard to find prices.",
        caption: "More creamsicle than coffee.",
        sipScore: 2.5,
        contextScore: 3.5,
        sipCriteria: [
            V3LabCriterion(
                id: "body",
                title: "Body",
                systemImage: "water.waves",
                rating: 1.5,
                importance: .more,
                isPinned: true
            ),
            V3LabCriterion(
                id: "presentation",
                title: "Presentation",
                systemImage: "sparkles",
                rating: 4,
                importance: .normal,
                isPinned: false
            )
        ],
        contextCriteria: [
            V3LabCriterion(
                id: "atmosphere",
                title: "Atmosphere",
                systemImage: "sun.max",
                rating: 3,
                importance: .most,
                isPinned: true
            ),
            V3LabCriterion(
                id: "value",
                title: "Value",
                systemImage: "dollarsign",
                rating: 2,
                importance: .more,
                isPinned: true
            )
        ],
        audience: .friends,
        rawNoteVisibility: .private,
        invitedFriendCount: 3,
        makeAgain: .withATweak,
        recipeVersion: 4,
        didUsePlaceholder: false
    )
}

extension V3LabSuggestion {
    static let sip: [V3LabSuggestion] = [
        V3LabSuggestion(id: "coffee-presence", title: "Coffee presence", systemImage: "cup.and.saucer"),
        V3LabSuggestion(id: "value", title: "Value", systemImage: "dollarsign"),
        V3LabSuggestion(id: "orange-balance", title: "Orange balance", systemImage: "circle.lefthalf.filled")
    ]

    static let cafe: [V3LabSuggestion] = [
        V3LabSuggestion(id: "service", title: "Service", systemImage: "person.crop.circle.badge.checkmark"),
        V3LabSuggestion(id: "comfort", title: "Comfort", systemImage: "chair.lounge"),
        V3LabSuggestion(id: "menu-clarity", title: "Menu clarity", systemImage: "menucard")
    ]

    static let elsewhere: [V3LabSuggestion] = [
        V3LabSuggestion(id: "view", title: "View", systemImage: "binoculars"),
        V3LabSuggestion(id: "comfort", title: "Comfort", systemImage: "chair.lounge"),
        V3LabSuggestion(id: "occasion", title: "Occasion", systemImage: "sparkles")
    ]
}
#endif
