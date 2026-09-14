import SwiftUI

/// Resolves stored media through the current viewer and drops displayed bytes
/// on account/lifecycle changes. Protected media is reauthorized while visible.
struct ProtectedRemoteImage<Content: View>: View {
    let storedValue: String
    @ViewBuilder let content: (UIImage?) -> Content
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var image: UIImage?
    @State private var loadedScope: String?

    private var scope: String {
        "\(authModel.authenticatedUser?.id.uuidString ?? "anonymous")|\(scenePhase)|\(storedValue)"
    }

    var body: some View {
        content(loadedScope == scope && scenePhase == .active ? image : nil)
            .task(id: scope) {
                image = nil
                loadedScope = nil
                guard scenePhase == .active else { return }
                let expectedScope = scope
                do {
                    while !Task.isCancelled {
                        let started = ContinuousClock.now
                        let url = try await VisitPhotoAccessService.shared.resolvedURL(for: storedValue)
                        let loaded = try await RemoteImagePipeline.shared.image(for: url)
                        try Task.checkCancellation()
                        guard expectedScope == scope, scenePhase == .active else { return }
                        image = loaded
                        loadedScope = expectedScope
                        guard url.path.hasPrefix("/storage/v1/object/sign/") else { return }
                        try await Task.sleep(until: started.advanced(by: .seconds(55)), clock: .continuous)
                        image = nil
                        loadedScope = nil
                    }
                } catch {
                    guard expectedScope == scope else { return }
                    image = nil
                    loadedScope = nil
                }
            }
    }
}
