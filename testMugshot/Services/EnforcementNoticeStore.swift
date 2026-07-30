import Combine
import Foundation

@MainActor
final class EnforcementNoticeStore: ObservableObject {
    @Published private(set) var primaryAction: ModerationEnforcementAction?
    @Published private(set) var activeCount = 0

    private let defaults: UserDefaults
    private let loadActions: (UUID) async throws -> [ModerationEnforcementAction]
    private var accountID: UUID?
    private var requestID: UUID?
    private let keyPrefix = "MugshotEnforcementSummary.v1."

    init(
        defaults: UserDefaults = .standard,
        loadActions: ((UUID) async throws -> [ModerationEnforcementAction])? = nil
    ) {
        self.defaults = defaults
        self.loadActions = loadActions ?? { accountID in
            try await SocialSafetyService(
                client: try SupabaseClientProvider.shared.client()
            ).enforcementState(accountID: accountID)
        }
    }

    func prepare(accountID: UUID?) {
        guard self.accountID != accountID else { return }
        self.accountID = accountID
        requestID = nil
        guard let accountID else {
            primaryAction = nil
            activeCount = 0
            return
        }
        apply(cachedActions(accountID: accountID))
    }

    func activate(accountID: UUID?) async {
        prepare(accountID: accountID)
        guard accountID != nil else { return }
        await refresh()
    }

    func refresh() async {
        guard let accountID else { return }
        let currentRequestID = UUID()
        requestID = currentRequestID
        do {
            let actions = try await loadActions(accountID)
            guard self.accountID == accountID,
                  requestID == currentRequestID else { return }
            cache(actions, accountID: accountID)
            apply(actions)
        } catch is CancellationError {
        } catch {
            // A previously confirmed summary remains visible offline. Server
            // permissions still enforce the current decision independently.
        }
    }

    func removeAll(accountID: UUID) {
        defaults.removeObject(forKey: key(accountID))
        if self.accountID == accountID {
            primaryAction = nil
            activeCount = 0
        }
    }

    private func apply(_ actions: [ModerationEnforcementAction]) {
        let active = actions.filter(\.isCurrentlyActive)
        activeCount = active.count
        primaryAction = active.sorted {
            if priority($0.actionKind) != priority($1.actionKind) {
                return priority($0.actionKind) > priority($1.actionKind)
            }
            return (ModerationDateParser.date(from: $0.startsAt) ?? .distantPast)
                > (ModerationDateParser.date(from: $1.startsAt) ?? .distantPast)
        }.first
    }

    private func priority(_ kind: ModerationActionKind) -> Int {
        switch kind {
        case .accountSuspended: 4
        case .socialRestricted: 3
        case .contentHidden: 2
        case .warning: 1
        }
    }

    private func cachedActions(accountID: UUID) -> [ModerationEnforcementAction] {
        guard let data = defaults.data(forKey: key(accountID)),
              let actions = try? JSONDecoder().decode(
                [ModerationEnforcementAction].self,
                from: data
              ) else { return [] }
        return actions
    }

    private func cache(
        _ actions: [ModerationEnforcementAction],
        accountID: UUID
    ) {
        guard let data = try? JSONEncoder().encode(actions) else { return }
        defaults.set(data, forKey: key(accountID))
    }

    private func key(_ accountID: UUID) -> String {
        keyPrefix + LocalAccountScope.user(accountID).defaultsComponent
    }
}
