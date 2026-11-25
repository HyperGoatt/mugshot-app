import Combine
import Foundation

@MainActor
final class WeeklyPourStore: ObservableObject {
    let ownerID: UUID
    @Published private(set) var story: WeeklyPourStory?
    @Published private(set) var failure: String?
    @Published private(set) var isLoading = false
    private var requestID: UUID?

    init(ownerID: UUID) { self.ownerID = ownerID }

    func load(
        window: WeeklyPourWindow,
        local: [WeeklyPourMoment],
        fetch: (UUID, WeeklyPourWindow) async throws -> [WeeklyPourMoment]
    ) async {
        let request = UUID()
        requestID = request
        story = nil
        failure = nil
        isLoading = true
        defer { if requestID == request { isLoading = false } }
        do {
            let remote = try await fetch(ownerID, window)
            guard !Task.isCancelled, requestID == request else { return }
            story = WeeklyPourStory(ownerID: ownerID, window: window, candidates: remote + local)
        } catch {
            guard !Task.isCancelled, requestID == request else { return }
            failure = "Your week couldn’t load. Your memories are safe. Try again when you’re connected."
        }
    }

    func invalidate() {
        requestID = nil
        story = nil
        failure = nil
        isLoading = false
    }
}
