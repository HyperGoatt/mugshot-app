import AppIntents
import Foundation

struct SipSystemRoute: Codable, Equatable, Identifiable {
    enum Destination: String, Codable {
        case cafeSip
        case homeSip
        case repeatRecentSip
        case brewSavedRecipe
        case cameraSip
        case journal
    }

    let id: UUID
    let destination: Destination

    init(id: UUID = UUID(), destination: Destination) {
        self.id = id
        self.destination = destination
    }
}

@MainActor
final class SipSystemRouter: ObservableObject {
    static let shared = SipSystemRouter()
    private static let storageKey = "MugshotSystemEntry.pendingRoute.v1"

    @Published private(set) var pendingRoute: SipSystemRoute?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            pendingRoute = try? JSONDecoder().decode(SipSystemRoute.self, from: data)
        }
    }

    func enqueue(_ destination: SipSystemRoute.Destination) {
        enqueue(SipSystemRoute(destination: destination))
    }

    func enqueue(_ route: SipSystemRoute) {
        pendingRoute = route
        persist(route)
    }

    func enqueue(url: URL) {
        guard let route = Self.destination(for: url) else { return }
        enqueue(route)
    }

    static func destination(for url: URL) -> SipSystemRoute.Destination? {
        guard url.scheme?.lowercased() == "mugshot" else { return nil }
        switch url.host?.lowercased() {
        case "cafe-sip": return .cafeSip
        case "home-sip": return .homeSip
        case "repeat-sip": return .repeatRecentSip
        case "brew-recipe": return .brewSavedRecipe
        case "camera": return .cameraSip
        case "journal": return .journal
        default: return nil
        }
    }

    func consume(_ route: SipSystemRoute) {
        guard pendingRoute?.id == route.id else { return }
        pendingRoute = nil
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist(_ route: SipSystemRoute) {
        guard let data = try? JSONEncoder().encode(route) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

private protocol MugshotOpenIntent: AppIntent {}

extension MugshotOpenIntent {
    static var openAppWhenRun: Bool { true }

    @MainActor
    func open(_ destination: SipSystemRoute.Destination) {
        SipSystemRouter.shared.enqueue(destination)
    }
}

struct LogCafeSipIntent: MugshotOpenIntent {
    static let title: LocalizedStringResource = "Log a Cafe Sip"
    static let description = IntentDescription("Open Mugshot to remember a sip from a cafe.")

    func perform() async throws -> some IntentResult {
        await open(.cafeSip)
        return .result()
    }
}

struct LogHomeSipIntent: MugshotOpenIntent {
    static let title: LocalizedStringResource = "Log a Home Sip"
    static let description = IntentDescription("Open Mugshot to remember coffee made at home.")

    func perform() async throws -> some IntentResult {
        await open(.homeSip)
        return .result()
    }
}

struct RepeatRecentSipIntent: MugshotOpenIntent {
    static let title: LocalizedStringResource = "Repeat Recent Sip"
    static let description = IntentDescription("Open a new draft based on your latest sip.")

    func perform() async throws -> some IntentResult {
        await open(.repeatRecentSip)
        return .result()
    }
}

struct BrewSavedRecipeIntent: MugshotOpenIntent {
    static let title: LocalizedStringResource = "Brew a Saved Recipe"
    static let description = IntentDescription("Open a new Home draft from your latest saved recipe.")

    func perform() async throws -> some IntentResult {
        await open(.brewSavedRecipe)
        return .result()
    }
}

struct OpenJournalIntent: MugshotOpenIntent {
    static let title: LocalizedStringResource = "Open Journal"
    static let description = IntentDescription("Open your Mugshot coffee journal.")

    func perform() async throws -> some IntentResult {
        await open(.journal)
        return .result()
    }
}

struct OpenSipCameraIntent: MugshotOpenIntent {
    static let title: LocalizedStringResource = "Capture a Sip"
    static let description = IntentDescription("Open a sip draft with the camera ready.")

    func perform() async throws -> some IntentResult {
        await open(.cameraSip)
        return .result()
    }
}

struct MugshotAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogCafeSipIntent(),
            phrases: ["Log a cafe sip with \(.applicationName)"],
            shortTitle: "Log Cafe Sip",
            systemImageName: "mappin.and.ellipse"
        )
        AppShortcut(
            intent: LogHomeSipIntent(),
            phrases: ["Log a home sip with \(.applicationName)"],
            shortTitle: "Log Home Sip",
            systemImageName: "house.fill"
        )
        AppShortcut(
            intent: RepeatRecentSipIntent(),
            phrases: ["Repeat my recent sip in \(.applicationName)"],
            shortTitle: "Repeat Recent Sip",
            systemImageName: "arrow.clockwise"
        )
        AppShortcut(
            intent: BrewSavedRecipeIntent(),
            phrases: ["Brew a saved recipe with \(.applicationName)"],
            shortTitle: "Brew Saved Recipe",
            systemImageName: "book.pages.fill"
        )
        AppShortcut(
            intent: OpenJournalIntent(),
            phrases: ["Open my \(.applicationName) journal"],
            shortTitle: "Open Journal",
            systemImageName: "book.closed.fill"
        )
    }
}
