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
    case most
    case more
    case normal
    case less

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

struct V3LabFriend: Identifiable, Equatable {
    let id: String
    let name: String
    let imageURL: String?
}

struct V3LabCoachPrompt: Identifiable, Equatable {
    let id: String
    let prompt: String
    let hint: String

    static let sip: [V3LabCoachPrompt] = [
        .init(id: "first", prompt: "What hits first?", hint: "Notice the opening second before naming a flavor."),
        .init(id: "stays", prompt: "What's after the sip?", hint: "Think about finish, texture, and what lingers."),
        .init(id: "change", prompt: "How does it change?", hint: "A drink can become brighter, thinner, sweeter, or quieter."),
        .init(id: "feeling", prompt: "What feeling does it leave?", hint: "Your experience matters more than a technical answer.")
    ]

    static func forContext(_ context: V3LabContext) -> [V3LabCoachPrompt] {
        switch context {
        case .cafe:
            return [
                .init(id: "arrival", prompt: "How did the room greet you?", hint: "Notice light, sound, movement, and how easy it felt to settle in."),
                .init(id: "service", prompt: "How did the interaction feel?", hint: "Describe what happened without turning an employee into the review."),
                .init(id: "value", prompt: "Did the experience feel worth it?", hint: "Value can include care, comfort, craft, and price."),
                .init(id: "return", prompt: "What would bring you back?", hint: "Look for the part of the memory you would want again.")
            ]
        case .home:
            return [
                .init(id: "change", prompt: "What changed this time?", hint: "Name the smallest variable you remember."),
                .init(id: "result", prompt: "What did that version make possible?", hint: "Describe the result without assuming one change caused it."),
                .init(id: "next", prompt: "What's one next experiment?", hint: "Change one variable so tomorrow can teach you something.")
            ]
        case .elsewhere:
            return [
                .init(id: "place", prompt: "How did the setting change the sip?", hint: "A view, journey, person, or pause can shape the memory."),
                .init(id: "sense", prompt: "What else could you hear or feel?", hint: "Let the setting be evidence, not merely a location."),
                .init(id: "remember", prompt: "What will future you want to remember?", hint: "Keep the one detail that makes this moment distinct.")
            ]
        }
    }
}

struct V3LabFlavorNode: Identifiable, Equatable {
    let id: String
    let title: String
    var children: [V3LabFlavorNode] = []

    var isLeaf: Bool { children.isEmpty }
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
    var invitedFriendIDs: Set<String>
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
        return (((sipScore + contextScore) / 2) * 10).rounded() / 10
    }

    var isReadyToPublish: Bool {
        !drinkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && sipScore > 0
            && (context == .home || contextScore > 0)
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
                importance: .less,
                isPinned: false
            ),
            V3LabCriterion(
                id: "orange-balance",
                title: "Orange balance",
                systemImage: "circle.lefthalf.filled",
                rating: 3,
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
        invitedFriendIDs: ["amanda", "jake", "sarah"],
        makeAgain: .withATweak,
        recipeVersion: 4,
        didUsePlaceholder: false
    )
}

extension V3LabSuggestion {
    static let sip: [V3LabSuggestion] = [
        .init(id: "aroma", title: "Aroma", systemImage: "wind"),
        .init(id: "flavor", title: "Flavor", systemImage: "mouth"),
        .init(id: "sweetness", title: "Sweetness", systemImage: "cube.fill"),
        .init(id: "brightness", title: "Brightness", systemImage: "sun.max"),
        .init(id: "bitterness", title: "Bitterness", systemImage: "drop.triangle"),
        .init(id: "body", title: "Body", systemImage: "water.waves"),
        .init(id: "texture", title: "Texture", systemImage: "waveform.path"),
        .init(id: "balance", title: "Balance", systemImage: "scale.3d"),
        .init(id: "finish", title: "Finish", systemImage: "hourglass.bottomhalf.filled"),
        .init(id: "presentation", title: "Presentation", systemImage: "sparkles"),
        .init(id: "coffee-presence", title: "Coffee presence", systemImage: "cup.and.saucer"),
        .init(id: "milk-integration", title: "Milk integration", systemImage: "cloud.fill"),
        .init(id: "flavor-accuracy", title: "Flavor accuracy", systemImage: "scope"),
        .init(id: "orange-balance", title: "Orange balance", systemImage: "circle.lefthalf.filled"),
        .init(id: "refreshment", title: "Refreshment", systemImage: "snowflake"),
        .init(id: "aftertaste", title: "Aftertaste", systemImage: "arrow.uturn.forward"),
        .init(id: "intensity", title: "Intensity", systemImage: "dial.medium"),
        .init(id: "complexity", title: "Complexity", systemImage: "circle.hexagongrid"),
        .init(id: "clarity", title: "Clarity", systemImage: "sparkle.magnifyingglass"),
        .init(id: "temperature", title: "Temperature", systemImage: "thermometer.medium"),
        .init(id: "value", title: "Value", systemImage: "dollarsign"),
        .init(id: "novelty", title: "Novelty", systemImage: "lightbulb"),
        .init(id: "comfort", title: "Comfort", systemImage: "heart"),
        .init(id: "nostalgia", title: "Nostalgia", systemImage: "clock.arrow.circlepath")
    ]

    static let cafe: [V3LabSuggestion] = [
        .init(id: "atmosphere", title: "Atmosphere", systemImage: "sun.max"),
        .init(id: "service", title: "Service", systemImage: "person.crop.circle.badge.checkmark"),
        .init(id: "comfort", title: "Comfort", systemImage: "chair.lounge"),
        .init(id: "value", title: "Value", systemImage: "dollarsign"),
        .init(id: "menu-clarity", title: "Menu clarity", systemImage: "menucard"),
        .init(id: "noise", title: "Noise level", systemImage: "speaker.wave.2"),
        .init(id: "lighting", title: "Lighting", systemImage: "lightbulb"),
        .init(id: "seating", title: "Seating", systemImage: "chair"),
        .init(id: "cleanliness", title: "Cleanliness", systemImage: "sparkles"),
        .init(id: "wait-time", title: "Wait time", systemImage: "clock"),
        .init(id: "hospitality", title: "Hospitality", systemImage: "hand.wave"),
        .init(id: "music", title: "Music", systemImage: "music.note"),
        .init(id: "walkability", title: "Walkability", systemImage: "figure.walk"),
        .init(id: "accessibility", title: "Accessibility", systemImage: "accessibility"),
        .init(id: "wifi", title: "Wi-Fi", systemImage: "wifi"),
        .init(id: "outlets", title: "Outlets", systemImage: "powerplug"),
        .init(id: "workability", title: "Workability", systemImage: "laptopcomputer"),
        .init(id: "presentation", title: "Presentation", systemImage: "rectangle.3.group"),
        .init(id: "crowd-energy", title: "Crowd energy", systemImage: "person.3"),
        .init(id: "to-go", title: "To-go readiness", systemImage: "takeoutbag.and.cup.and.straw"),
        .init(id: "return-appeal", title: "Return appeal", systemImage: "arrow.uturn.backward.circle")
    ]

    static let elsewhere: [V3LabSuggestion] = [
        .init(id: "view", title: "View", systemImage: "binoculars"),
        .init(id: "comfort", title: "Comfort", systemImage: "chair.lounge"),
        .init(id: "occasion", title: "Occasion", systemImage: "sparkles"),
        .init(id: "company", title: "Company", systemImage: "person.2"),
        .init(id: "weather", title: "Weather", systemImage: "cloud.sun"),
        .init(id: "sound", title: "Sound", systemImage: "waveform"),
        .init(id: "scenery", title: "Scenery", systemImage: "mountain.2"),
        .init(id: "pace", title: "Pace", systemImage: "figure.walk.motion"),
        .init(id: "novelty", title: "Novelty", systemImage: "lightbulb"),
        .init(id: "access", title: "Ease of access", systemImage: "arrow.triangle.turn.up.right.diamond"),
        .init(id: "temperature", title: "Temperature", systemImage: "thermometer.medium"),
        .init(id: "memory", title: "Memory", systemImage: "bookmark"),
        .init(id: "grounding", title: "Grounding", systemImage: "leaf"),
        .init(id: "privacy", title: "Privacy", systemImage: "eye.slash"),
        .init(id: "energy", title: "Energy", systemImage: "bolt"),
        .init(id: "value", title: "Value", systemImage: "dollarsign"),
        .init(id: "service", title: "Service", systemImage: "person.crop.circle.badge.checkmark"),
        .init(id: "presentation", title: "Presentation", systemImage: "sparkles"),
        .init(id: "return-appeal", title: "Return appeal", systemImage: "arrow.uturn.backward.circle")
    ]
}

extension V3LabFriend {
    static let recommended: [V3LabFriend] = [
        .init(id: "amanda", name: "Amanda", imageURL: nil),
        .init(id: "jake", name: "Jake", imageURL: nil),
        .init(id: "sarah", name: "Sarah", imageURL: nil),
        .init(id: "jimmy", name: "Jimmy", imageURL: nil),
        .init(id: "kelly", name: "Kelly", imageURL: nil)
    ]
}

enum V3LabMedia {
    static let photos = [
        "V3OrangeCreamsicleHeroV2",
        "V3OrangeCreamsicleSquare",
        "V3OrangeCitrusDetail",
        "V3QuietCafeCorner"
    ]
}

extension V3LabFlavorNode {
    static let explorerRoots: [V3LabFlavorNode] = [
        branch("flavor", "Flavor", [
            branch("fruit", "Fruit", [
                group("citrus", "Citrus", ["Lemon", "Lime", "Grapefruit", "Clementine", "Orange", "Blood Orange"]),
                group("apple-pear", "Apple / Pear", ["Green Apple", "Red Apple", "Asian Pear"]),
                group("melon", "Melon", ["Watermelon", "Honeydew", "Cantaloupe"]),
                group("grape", "Grape", ["White Grape", "Green Grape", "Red Grape", "Concord Grape"]),
                group("tropical", "Tropical Fruit", ["Lychee", "Star Fruit", "Tamarind", "Passion Fruit", "Pineapple", "Mango", "Papaya", "Kiwi", "Banana", "Coconut"]),
                group("stone-fruit", "Stone Fruit", ["Peach", "Nectarine", "Apricot", "Plum", "Cherry", "Black Cherry"]),
                group("berry", "Berry", ["Cranberry", "Raspberry", "Strawberry", "Blueberry", "Blackberry", "Currant"]),
                group("dried-fruit", "Dried Fruit", ["Golden Raisin", "Raisin", "Dried Fig", "Dried Date", "Prune"])
            ]),
            branch("sweet-sugary", "Sweet & Sugary", [
                group("chocolate", "Chocolate", ["Baker's Chocolate", "Dark Chocolate", "Bittersweet Chocolate", "Milk Chocolate", "White Chocolate"]),
                group("soft-sweets", "Soft Sweets", ["Vanilla", "Marzipan", "Nougat", "Honey", "Butter", "Cream", "Marshmallow"]),
                group("sugars", "Sugars", ["Cane Sugar", "Simple Syrup", "Brown Sugar", "Caramel", "Maple Syrup", "Molasses", "Cola"])
            ]),
            branch("nut", "Nut", [
                group("nuts", "Nuts", ["Almond", "Hazelnut", "Pecan", "Cashew", "Peanut", "Walnut"])
            ]),
            branch("grain-cereal", "Grain & Cereal", [
                group("grain-baked", "Grain & Baked", ["Fresh Bread", "Malt", "Barley", "Wheat", "Rye", "Graham Cracker", "Toasted Oats", "Pastry", "Popcorn"])
            ]),
            branch("roast", "Roast", [
                group("roast-notes", "Roast Notes", ["Toast", "Burnt Sugar", "Smoky", "Carbon"])
            ]),
            branch("spice", "Spice", [
                group("spices", "Spices", ["Black Pepper", "White Pepper", "Cinnamon", "Coriander", "Ginger", "Nutmeg", "Cumin", "Licorice / Anise", "Clove"])
            ]),
            branch("savory", "Savory", [
                group("savory-notes", "Savory Notes", ["Sundried Tomato", "Soy Sauce", "Meat-like", "Leathery"])
            ]),
            branch("vegetal-earthy-herb", "Vegetal / Earthy / Herb", [
                group("earth-wood", "Earth & Wood", ["Soil", "Wood", "Cedar", "Tobacco", "Straw"]),
                group("vegetal", "Vegetal", ["Leafy Greens", "Olive", "Green Pepper", "Squash", "Mushroom", "Carrot", "Tomato", "Sweet Pea", "Rhubarb"]),
                group("herb-tea", "Herb & Tea", ["Grassy", "Dill", "Sage", "Mint", "Green Tea", "Black Tea", "Hops", "Bergamot Oil"])
            ]),
            branch("floral", "Floral", [
                group("flowers", "Flowers", ["Hibiscus", "Rose / Rosewater", "Lavender", "Magnolia", "Honeysuckle", "Jasmine", "Orange Blossom", "Lemongrass"])
            ])
        ]),
        branch("body", "Body", [
            group("light", "Light", ["Watery", "Skim Milk", "Tea-like"]),
            group("medium", "Medium", ["Round", "2% Milk", "Creamy"]),
            group("heavy", "Heavy", ["Full", "Whole Milk", "Chewy"])
        ]),
        branch("character", "Character", [
            group("crisp-lively", "Crisp & Lively", ["Crisp", "Bright", "Vibrant", "Tart"]),
            group("muted", "Muted", ["Muted", "Dull", "Mild"]),
            group("wild", "Wild", ["Wild", "Unbalanced", "Sharp", "Pointed"]),
            group("structured", "Structured", ["Structured", "Balanced"]),
            group("dense", "Dense", ["Dense", "Deep", "Complex"]),
            group("soft", "Soft", ["Soft", "Faint", "Delicate"]),
            group("juicy", "Juicy", ["Juicy", "Syrupy"]),
            group("dry", "Dry", ["Dry", "Astringent"]),
            group("lingering", "Lingering", ["Lingering", "Coating", "Dirty"]),
            group("quick-clean", "Quick & Clean", ["Quick", "Clean"])
        ])
    ]

    private static func branch(_ id: String, _ title: String, _ children: [V3LabFlavorNode]) -> V3LabFlavorNode {
        V3LabFlavorNode(id: id, title: title, children: children)
    }

    private static func group(_ id: String, _ title: String, _ titles: [String]) -> V3LabFlavorNode {
        branch(id, title, titles.enumerated().map { index, title in
            V3LabFlavorNode(id: "\(id)-\(index)", title: title)
        })
    }
}
#endif
