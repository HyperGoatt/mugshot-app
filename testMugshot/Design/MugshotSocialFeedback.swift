import Foundation

/// A late response may affect only the operation/account that started it.
enum MugshotOptimisticAction {
    @MainActor
    static func perform<Value>(
        isCurrent: () -> Bool,
        request: () async throws -> Value,
        commit: (Value) -> Void,
        rollback: () -> Void
    ) async throws {
        guard !Task.isCancelled, isCurrent() else { return }
        do {
            let value = try await request()
            guard !Task.isCancelled, isCurrent() else { return }
            commit(value)
        } catch {
            if !Task.isCancelled, isCurrent() { rollback() }
            throw error
        }
    }
}

/// A successful write remains successful if a subsequent projection read fails.
/// In particular, a posted comment must never invite a duplicate submission.
enum MugshotConfirmedAction {
    @MainActor
    static func perform<Value>(
        commit: () async throws -> Void,
        refresh: () async throws -> Value
    ) async throws -> Value? {
        try await commit()
        return try? await refresh()
    }
}
