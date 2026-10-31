import Foundation

/// Serializes a visit across the composer, manual retry, and lifecycle recovery.
/// Tokens prevent a late completion from releasing a newer operation.
@MainActor
final class SipPublicationGate {
    static let shared = SipPublicationGate()
    private struct Identity: Equatable {
        let userID: UUID
        let visitID: UUID
    }
    private var operations: [UUID: Identity] = [:]

    func begin(userID: UUID, visitID: UUID) -> UUID? {
        let identity = Identity(userID: userID, visitID: visitID)
        guard !operations.values.contains(identity) else { return nil }
        let token = UUID()
        operations[token] = identity
        return token
    }

    func isActive(userID: UUID, visitID: UUID) -> Bool {
        operations.values.contains(Identity(userID: userID, visitID: visitID))
    }

    func finish(token: UUID) {
        guard operations.removeValue(forKey: token) != nil else { return }
        NotificationCenter.default.post(name: .sipPublicationFinished, object: nil)
    }
}

extension Notification.Name {
    static let sipPublicationFinished = Notification.Name("MugshotSipPublicationFinished")
}
