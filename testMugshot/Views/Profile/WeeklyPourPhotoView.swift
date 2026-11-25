import SwiftUI

/// Uses the app's existing authorization/cache boundary. Failed or revoked
/// media never becomes a fictional photo or a photo-free Mugsy memory.
struct WeeklyPourPhotoView: View {
    let moment: WeeklyPourMoment
    let ownerID: UUID
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var image: UIImage?
    @State private var loadedKey: String?
    @State private var expiresAt = Date.distantPast
    @State private var failed = false
    @State private var retry = 0
    private var key: String { "\(ownerID)|\(authModel.authenticatedUser?.id.uuidString ?? "none")|\(moment.id)|\(retry)" }
    private var ownsPhoto: Bool { authModel.authenticatedUser?.id == ownerID }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let fixture = fixtureAsset {
                    Image(fixture).resizable().scaledToFill()
                } else if moment.photo == nil {
                    ZStack {
                        Color.sandBeige
                        MugsyCatalogView(pose: .journalKeeper, rendering: .artwork).padding(12)
                    }
                } else if ownsPhoto, scenePhase == .active, loadedKey == key,
                          expiresAt > Date(), let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if failed {
                    VStack(spacing: 9) {
                        Image(systemName: "photo.badge.exclamationmark").font(.title3)
                        Text("Photo unavailable").font(.caption)
                        Button("Retry") { retry += 1 }.font(.caption.weight(.semibold)).frame(minHeight: 44)
                    }
                    .foregroundStyle(Color.roastBrown).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.sandBeige)
                } else {
                    ZStack { Color.sandBeige; ProgressView().tint(.mugshotSageText) }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height).clipped()
        }
        .task(id: "\(key)|\(scenePhase == .active)") { await load() }
        .task(id: expiresAt) {
            let expiry = expiresAt
            guard expiry > Date(), expiry != .distantFuture else { return }
            do {
                try await Task.sleep(for: .seconds(max(0, expiry.timeIntervalSinceNow)))
                try Task.checkCancellation()
                if expiresAt == expiry { clear() }
            } catch { }
        }
        .onChange(of: authModel.authenticatedUser?.id) { _, _ in clear() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { clear() } }
        .onReceive(NotificationCenter.default.publisher(for: .mugshotSafetyAccessChanged)) { _ in
            clear(); retry += 1
        }
        .accessibilityLabel(moment.photo == nil ? "No photo saved" : failed ? "Photo unavailable" : "\(moment.drink) photo")
    }

    private var fixtureAsset: String? {
#if DEBUG
        if case .fixture(let asset) = moment.photo { return asset }
#endif
        return nil
    }

    @MainActor private func load() async {
        guard let photo = moment.photo, ownsPhoto, scenePhase == .active else { return }
        let expected = key
        failed = false
        do {
            switch photo {
            case .local(let name):
                let data = try HomeRecipeWorkspaceStore.shared.exportPhoto(name: name, ownerID: ownerID)
                guard let decoded = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
                try Task.checkCancellation()
                guard ownsPhoto, key == expected else { return }
                image = decoded; loadedKey = expected; expiresAt = .distantFuture
            case .remote(let value):
                var renew = false
                while !Task.isCancelled {
                    let receipt = try await ProtectedImageStore.shared.load(value, account: ownerID.uuidString, renew: renew)
                    try Task.checkCancellation()
                    guard ownsPhoto, key == expected, scenePhase == .active else { return }
                    image = receipt.image; loadedKey = expected; expiresAt = receipt.expiresAt
                    try await Task.sleep(for: .seconds(max(0.1, receipt.expiresAt.timeIntervalSinceNow - 10)))
                    renew = true
                }
#if DEBUG
            case .fixture: break
#endif
            }
        } catch {
            guard !Task.isCancelled, key == expected else { return }
            clear(); failed = true
        }
    }

    private func clear() { image = nil; loadedKey = nil; expiresAt = .distantPast }
}
