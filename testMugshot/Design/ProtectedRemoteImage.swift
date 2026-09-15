import SwiftUI

struct ProtectedRemoteImage<Content: View>: View {
    let storedValue: String
    @ViewBuilder let content: (UIImage?) -> Content
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isMugshotTabActive) private var tabIsActive
    @State private var image: UIImage?
    @State private var loadedScope: String?
    @State private var safetyGeneration = 0
    @State private var authorizedUntil = Date.distantPast

    private var account: String { authModel.authenticatedUser?.id.uuidString ?? "anonymous" }
    private var scope: String { "\(account)|\(storedValue)|\(safetyGeneration)" }
    private var visible: Bool { scenePhase == .active && tabIsActive }

    var body: some View {
        ZStack {
            Color.clear
            content(loadedScope == scope && scenePhase != .background && authorizedUntil > Date() ? image : nil)
        }
            .onReceive(NotificationCenter.default.publisher(for: .mugshotSafetyAccessChanged)) { _ in
                image = nil; loadedScope = nil; safetyGeneration += 1
            }
            .task(id: authorizedUntil) {
                let expiry = authorizedUntil
                guard expiry > Date() else { return }
                do {
                    try await Task.sleep(for: .seconds(max(0, expiry.timeIntervalSinceNow)))
                    try Task.checkCancellation()
                    guard authorizedUntil == expiry else { return }
                    image = nil; loadedScope = nil
                } catch { }
            }
            .task(id: "\(scope)|\(visible)") {
                guard visible else { return }
                let expected = scope
                var renew = false
                do {
                    while !Task.isCancelled {
                        let receipt = try await ProtectedImageStore.shared.load(storedValue, account: account, renew: renew)
                        try Task.checkCancellation()
                        guard scope == expected, visible else { return }
                        image = receipt.image; loadedScope = expected; authorizedUntil = receipt.expiresAt
                        // Renew while visible without tearing down already-authorized pixels.
                        let remaining = max(0, receipt.expiresAt.timeIntervalSinceNow)
                        try await Task.sleep(for: .seconds(max(0, remaining - 10)))
                        renew = true
                    }
                } catch {
                    guard !Task.isCancelled, scope == expected else { return }
                    image = nil; loadedScope = nil
                }
            }
    }
}
