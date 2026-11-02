import Combine
import Foundation

@MainActor
final class CoffeeAssistanceSession: ObservableObject {
    @Published private(set) var result: CoffeeAssistanceResult?
    @Published private(set) var isWorking = false
    @Published private(set) var message: String?
    private var generation = UUID()
    private let transport: any CoffeeAssistanceTransport
    private let cache: CoffeeAssistanceCache

    init(transport: (any CoffeeAssistanceTransport)? = nil,
         cache: CoffeeAssistanceCache? = nil) {
        self.transport = transport ?? CoffeeAssistanceService()
        self.cache = cache ?? .shared
    }

    func invalidate() {
        generation = UUID()
        result = nil
        isWorking = false
        message = nil
    }

    func run(_ request: CoffeeAssistanceRequest, consent: Bool,
             currentOwner: () -> UUID?) async {
        invalidate()
        guard consent else { message = CoffeeAssistanceError.consentRequired.localizedDescription; return }
        guard currentOwner() == request.ownerID else { message = CoffeeAssistanceError.accountChanged.localizedDescription; return }
        let operation = generation
        if let existing = cache.result(for: request) { result = existing; return }
        isWorking = true
        defer { if generation == operation { isWorking = false } }
        MugshotAnalytics.shared.capture(.coffeeAssistance(task: request.task, action: .requested))
        do {
            let suggestion = try await transport.suggest(request)
            try Task.checkCancellation()
            guard generation == operation, currentOwner() == request.ownerID else { return }
            try suggestion.validate(for: request)
            result = suggestion
            cache.store(suggestion, for: request)
            MugshotAnalytics.shared.capture(.coffeeAssistance(task: request.task, action: .succeeded))
        } catch {
            guard generation == operation, currentOwner() == request.ownerID else { return }
            if !Task.isCancelled && !(error is CancellationError) {
                message = (error as? CoffeeAssistanceError)?.localizedDescription
                    ?? CoffeeAssistanceError.unavailable.localizedDescription
                MugshotAnalytics.shared.capture(.coffeeAssistance(task: request.task, action: .unavailable))
            }
        }
    }
}
