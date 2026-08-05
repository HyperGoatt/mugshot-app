//
//  MugshotRootView.swift
//  testMugshot
//

import CryptoKit
import SwiftUI

struct MugshotRootView: View {
    @ObservedObject var dataManager: DataManager
    @StateObject private var authModel = AppAuthModel()
    @State private var authCallbackQueue = MugshotAuthCallbackQueue()
    
    var body: some View {
        Group {
#if DEBUG
            if MugshotLaunchEnvironment.shouldShowRecoveryBannerDesignQA {
                AutomaticSipRecoveryBannerPreviewHost()
            } else if MugshotLaunchEnvironment.shouldShowFeedRefreshDesignQA {
                FeedRefreshPreviewHost()
            } else if MugshotLaunchEnvironment.shouldShowEditSipDesignQA {
                EditSipPreviewHost()
            } else if MugshotLaunchEnvironment.shouldShowPeopleRecapDesignQA {
                JournalPeopleRecapPreviewHost()
            } else if MugshotLaunchEnvironment.shouldShowSipDetailDesignQA {
                SipDetailPreviewHost(presentation: .previewOwner)
            } else if MugshotLaunchEnvironment.isUITesting {
                MainTabView(dataManager: dataManager)
            } else {
                authenticatedRoot
            }
#else
            if MugshotLaunchEnvironment.isUITesting {
                MainTabView(dataManager: dataManager)
            } else {
                authenticatedRoot
            }
#endif
        }
        .environmentObject(authModel)
        .modifier(MugshotDebugDynamicTypeModifier())
        .preferredColorScheme(.light)
        .task {
            guard !MugshotLaunchEnvironment.isUITesting else { return }
            await PerformanceMonitor.measure("Session restore") {
                await authModel.restoreSession(dataManager: dataManager)
            }
            await processPendingAuthCallbacks()
        }
        .onOpenURL { url in
            guard authCallbackQueue.enqueue(url) else { return }
            Task {
                await processPendingAuthCallbacks()
            }
        }
        .onChange(of: authModel.status) { _, status in
            guard status != .checking,
                  authCallbackQueue.pendingCount > 0 else { return }
            Task {
                await processPendingAuthCallbacks()
            }
        }
        .onChange(of: authModel.authenticatedUser?.id) { previousUserID, userID in
            if previousUserID != nil, previousUserID != userID {
                MugshotAnalytics.shared.reset()
            }
            if let userID {
                MugshotAnalytics.shared.identify(userID: userID)
            }
        }
    }

    @ViewBuilder
    private var authenticatedRoot: some View {
        switch authModel.status {
        case .checking:
            AuthLoadingView()
        case .configurationRequired(let message):
            SupabaseConfigurationRequiredView(message: message)
        case .working, .signedOut, .sessionUnavailable, .failed, .signedIn:
            MainTabView(dataManager: dataManager)
        }
    }

    private func processPendingAuthCallbacks() async {
        while let url = authCallbackQueue.nextIfReady(
            authModel.status != .checking
        ) {
            let result = await authModel.handleAuthCallback(
                url,
                dataManager: dataManager
            )
            switch result {
            case .retry:
                authCallbackQueue.retryCurrentCallback()
                return
            case .ignored, .consumed:
                authCallbackQueue.completeCurrentCallback()
            }
        }
    }
}

private struct MugshotDebugDynamicTypeModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
#if DEBUG
        if MugshotLaunchEnvironment.shouldUseAccessibilityXXXL {
            content.environment(\.dynamicTypeSize, .accessibility5)
        } else {
            content
        }
#else
        content
#endif
    }
}

/// Keeps email confirmation and recovery callbacks safe while the initial
/// session restore owns the auth client. It also prevents duplicate SwiftUI
/// URL delivery from exchanging the same one-time link twice.
struct MugshotAuthCallbackQueue {
    private struct Item: Equatable {
        let url: URL
        let fingerprint: Data
    }

    private var pending: [Item] = []
    private var inFlight: Item?
    private var consumedFingerprints: Set<Data> = []

    var pendingCount: Int { pending.count }
    var isProcessing: Bool { inFlight != nil }

    @discardableResult
    mutating func enqueue(_ url: URL) -> Bool {
        guard MugshotAuthCallbackRoute.resolve(url) != nil else { return false }
        let fingerprint = Data(
            SHA256.hash(data: Data(url.absoluteString.utf8))
        )
        guard !consumedFingerprints.contains(fingerprint),
              inFlight?.fingerprint != fingerprint,
              !pending.contains(where: { $0.fingerprint == fingerprint }) else {
            return true
        }
        pending.append(Item(url: url, fingerprint: fingerprint))
        return true
    }

    mutating func nextIfReady(_ isReady: Bool) -> URL? {
        guard isReady, inFlight == nil, !pending.isEmpty else { return nil }
        let item = pending.removeFirst()
        inFlight = item
        return item.url
    }

    mutating func completeCurrentCallback() {
        guard let inFlight else { return }
        consumedFingerprints.insert(inFlight.fingerprint)
        self.inFlight = nil
    }

    mutating func retryCurrentCallback() {
        guard let inFlight else { return }
        pending.insert(inFlight, at: 0)
        self.inFlight = nil
    }
}
