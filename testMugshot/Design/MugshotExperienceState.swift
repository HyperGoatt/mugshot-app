//
//  MugshotExperienceState.swift
//  testMugshot
//

import SwiftUI

enum MugshotUserFacingError {
    static func message(for error: Error, context: Context) -> String {
        if let pendingError = error as? PendingVisitSubmissionStoreError {
            return pendingError.localizedDescription
        }

        if let uploadError = error as? VisitPhotoUploadError {
            return uploadError.localizedDescription
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "You’re offline. Check your connection, then try again."
            case .timedOut:
                return "That took too long. Please try again."
            default:
                break
            }
        }

        let lowercased = error.localizedDescription.lowercased()
        let authenticationFailureMarkers = [
            "auth session missing",
            "session_not_found",
            "session expired",
            "session_expired",
            "refresh_token_not_found",
            "refresh token not found",
            "refresh_token_already_used",
            "invalid_jwt",
            "invalid jwt",
            "bad_jwt",
            "bad jwt",
            "jwt expired"
        ]
        if authenticationFailureMarkers.contains(where: lowercased.contains) {
            return "Your session ended. Sign in again to continue."
        }

        switch context {
        case .sipSave:
            return "We couldn’t finish this save. Your sip is still here—try again."
        case .tastingLensSnapshot:
            return "We couldn’t save the Tasting Lens record. Your sip and tasting answers are still here—try again."
        case .photoUpload:
            return "We couldn’t upload the photo. Your sip and photo are still here—try again."
        case .social:
            return "We couldn’t save that change. Please try again."
        case .cafeSearch:
            return "We couldn’t find cafes right now. Try again or enter the cafe name yourself."
        case .location:
            return "Location isn’t available. You can still search for a cafe."
        case .account:
            return "We couldn’t update your account. Please try again."
        case .loading:
            return "We couldn’t load this yet. Please try again."
        }
    }

    enum Context: Equatable {
        case sipSave
        case tastingLensSnapshot
        case photoUpload
        case social
        case cafeSearch
        case location
        case account
        case loading
    }
}

enum SipRemoteSaveOperation: Equatable {
    case preparing
    case creatingVisit
    case savingTastingLens
    case uploadingPhotos
    case finalizing

    var errorContext: MugshotUserFacingError.Context {
        switch self {
        case .savingTastingLens:
            return .tastingLensSnapshot
        case .uploadingPhotos:
            return .photoUpload
        case .preparing, .creatingVisit, .finalizing:
            return .sipSave
        }
    }

    var recoveryMessage: String {
        switch self {
        case .savingTastingLens:
            return "Your sip and Tasting Lens answers are safe. Retry continues the same save."
        case .uploadingPhotos:
            return "Your sip and photos are safe. Retry continues the same upload."
        case .preparing, .creatingVisit, .finalizing:
            return "Your sip is safe. Retry continues the same save without making a duplicate."
        }
    }
}

struct MugshotRecoveryCard: View {
    let title: String
    let message: String
    let actionTitle: String
    var systemImage = "arrow.clockwise"
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            MugsyAnimatedView(
                configuration: MugsyPlacement.recovery.configuration,
                action: .recovering,
                isPaused: true
            )
            .frame(width: 88, height: 88)
            .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.espressoBrown)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Label(actionTitle, systemImage: systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityHint(message)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .cardStyle(radius: DesignSystem.Radius.heroCard)
    }
}

struct MugshotLoadingCards: View {
    var count = 3
    var cardHeight: CGFloat = 156

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    Capsule().frame(width: 132, height: 14)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .frame(maxWidth: .infinity)
                        .frame(height: cardHeight - 56)
                }
                .padding(16)
                .foregroundStyle(Color.sandBeige.opacity(0.88))
                .redacted(reason: .placeholder)
                .cardStyle()
                .accessibilityHidden(true)
            }
        }
    }
}

enum MugshotLoadingLayout {
    case feed
    case journal
    case collection
    case cafeDetail
}

/// Layout-faithful loading placeholders for Mugshot's primary surfaces.
/// These deliberately avoid shimmer and motion so they remain calm, cheap to
/// render, and compatible with Reduce Motion by default.
struct MugshotLoadingState: View {
    let layout: MugshotLoadingLayout
    var count = 3

    var body: some View {
        Group {
            switch layout {
            case .feed:
                VStack(spacing: 12) {
                    ForEach(0..<count, id: \.self) { _ in
                        feedCard
                    }
                }
            case .journal:
                VStack(spacing: 12) {
                    ForEach(0..<count, id: \.self) { _ in
                        journalRow
                    }
                }
            case .collection:
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<count, id: \.self) { _ in
                            collectionTile
                        }
                    }
                }
            case .cafeDetail:
                cafeDetail
            }
        }
        .foregroundStyle(Color.sandBeige.opacity(0.92))
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }

    private var feedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 7) {
                    loadingBar(width: 126, height: 13)
                    loadingBar(width: 92, height: 10)
                }
                Spacer()
            }

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .frame(maxWidth: .infinity)
                .frame(height: 238)

            loadingBar(width: 172, height: 18)
            loadingBar(width: 238, height: 12)

            HStack(spacing: 10) {
                Capsule().frame(width: 62, height: 38)
                Capsule().frame(width: 62, height: 38)
                Capsule().frame(width: 46, height: 38)
                Spacer()
            }
        }
        .padding(14)
        .cardStyle(radius: DesignSystem.Radius.heroCard)
    }

    private var journalRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                .frame(width: 92, height: 96)

            VStack(alignment: .leading, spacing: 8) {
                loadingBar(width: 104, height: 10)
                loadingBar(width: 166, height: 18)
                loadingBar(width: 126, height: 12)
                loadingBar(width: 58, height: 11)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var collectionTile: some View {
        VStack(alignment: .leading, spacing: 9) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .frame(width: 154, height: 72)
            loadingBar(width: 112, height: 14)
            loadingBar(width: 76, height: 10)
        }
        .frame(width: 154, alignment: .leading)
        .padding(12)
        .cardStyle()
    }

    private var cafeDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            loadingBar(width: 210, height: 24)
            loadingBar(width: 164, height: 12)

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .frame(height: 74)
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .frame(height: 74)
            }

            Capsule().frame(maxWidth: .infinity).frame(height: 48)

            ForEach(0..<2, id: \.self) { _ in
                journalRow
            }
        }
    }

    private func loadingBar(width: CGFloat, height: CGFloat) -> some View {
        Capsule().frame(width: width, height: height)
    }
}

struct MugshotCompletionFact: Identifiable, Equatable {
    let icon: String
    let label: String
    let value: String

    var id: String { "\(icon)-\(label)-\(value)" }
}

struct MugshotCompletionCard: View {
    var assetName: String? = nil
    var mugsyConfiguration: MugsyModelConfiguration? = nil
    var mugsyAction: MugsyActionState = .success
    var systemImage = "checkmark"
    let eyebrow: String
    let title: String
    let message: String
    var facts: [MugshotCompletionFact] = []
    var celebrates = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var reduceMotionOverride
    @State private var revealProgress: CGFloat = 0
    @State private var confettiProgress: CGFloat = 0

    private var effectiveReduceMotion: Bool { reduceMotionOverride ?? reduceMotion }

    var body: some View {
        ZStack {
            if celebrates {
                MugshotConfettiBurst(progress: confettiProgress)
                    .frame(width: 280, height: 188)
                    .offset(y: -38)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 14) {
                Group {
                    if let assetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                    } else if let mugsyConfiguration {
                        if celebrates {
                            MugsyCelebrationLoopView(configuration: mugsyConfiguration)
                        } else {
                            MugsyAnimatedView(configuration: mugsyConfiguration, action: mugsyAction)
                        }
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.foamWhite)
                            .frame(width: 64, height: 64)
                            .background(Color.mugshotSage, in: Circle())
                    }
                }
                .frame(
                    width: mugsyConfiguration == nil ? 72 : (celebrates ? 136 : 106),
                    height: mugsyConfiguration == nil ? 72 : (celebrates ? 148 : 118)
                )
                .accessibilityHidden(true)

                VStack(spacing: 5) {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.mugshotSage)

                    Text(title)
                        .mugshotDisplay(size: 27)
                        .foregroundColor(.espressoBrown)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !facts.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(facts) { fact in
                            HStack(alignment: .firstTextBaseline, spacing: 9) {
                                Image(systemName: fact.icon)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.mugshotSage)
                                    .frame(width: 18)
                                Text(fact.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondaryText)
                                Spacer(minLength: 8)
                                Text(fact.value)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.espressoBrown)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.sandBeige.opacity(0.54))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 24)
        .mugshotGlassSurface(radius: 26, tint: .foamWhite, interactive: false)
        .scaleEffect(celebrates ? 0.88 + revealProgress * 0.12 : 1)
        .offset(y: celebrates ? 24 * (1 - revealProgress) : 0)
        .opacity(celebrates ? revealProgress : 1)
        .task {
            guard celebrates, revealProgress == 0 else { return }
            if effectiveReduceMotion {
                revealProgress = 1
                confettiProgress = 1
                return
            }

            withAnimation(MugshotMotion.celebration) {
                revealProgress = 1
            }
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.92)) {
                confettiProgress = 1
            }
            MugshotHaptic.success.play()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MugshotConfettiBurst: View {
    let progress: CGFloat

    private let colors: [Color] = [
        .mugshotMint,
        .mugshotSage,
        .mugshotLatte,
        MugsyStyleTokens.blush,
        MugshotDrinkAppearance.coffee.liquidColor
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<20, id: \.self) { index in
                    let angle = (Double(index) / 20 * .pi * 2) - (.pi / 2)
                    let distance = progress * CGFloat(48 + (index % 5) * 11)
                    let x = CGFloat(cos(angle)) * distance
                    let y = CGFloat(sin(angle)) * distance + progress * progress * 28
                    let fade = 1 - MugshotMotion.normalized((progress - 0.74) / 0.26)

                    RoundedRectangle(cornerRadius: index.isMultiple(of: 3) ? 4 : 1.5, style: .continuous)
                        .fill(colors[index % colors.count])
                        .frame(
                            width: index.isMultiple(of: 2) ? 7 : 4,
                            height: index.isMultiple(of: 2) ? 4 : 10
                        )
                        .rotationEffect(.degrees(Double(index * 31) + Double(progress) * 210))
                        .offset(x: x, y: y)
                        .opacity(min(1, progress * 5) * fade)
                }
            }
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .allowsHitTesting(false)
    }
}

struct MugshotLegacySipHero: View {
    let title: String
    let subtitle: String
    let score: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 54, height: 54)
                    .background(Color.mugshotMint.opacity(0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer()

                if let score, score > 0 {
                    MugshotRatingBadge(score: score)
                }
            }

            Text("Legacy sip")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.mugshotSage)

            Text(title)
                .mugshotDisplay(size: 28)
                .foregroundColor(.espressoBrown)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.mugshotMint.opacity(0.28), Color.sandBeige.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

enum MugshotCafeName {
    static func display(_ name: String?) -> String {
        let words = (name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        guard !words.isEmpty else { return "Cafe" }

        return words.map { word in
            let lowercased = word.lowercased()
            if lowercased == "and" || lowercased == "on" || lowercased == "the" {
                return lowercased
            }
            return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
        }
        .joined(separator: " ")
    }
}

enum MugshotCafeCategory {
    static func display(_ category: String?) -> String? {
        guard let category = category?.trimmingCharacters(in: .whitespacesAndNewlines),
              !category.isEmpty else {
            return nil
        }

        switch category.lowercased() {
        case let value where value.contains("cafe"):
            return "Cafe"
        case let value where value.contains("coffee"):
            return "Coffee shop"
        case let value where value.contains("bakery"):
            return "Bakery"
        case let value where value.contains("restaurant"):
            return "Restaurant"
        default:
            // MapKit's raw category values are implementation details (for
            // example, `MKPOICategoryCafe`), never customer-facing copy.
            return category
                .replacingOccurrences(of: "MKPOICategory", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }
}

extension Cafe {
    var consumerDisplayName: String {
        MugshotCafeName.display(name)
    }

    var consumerScoreLabel: String {
        averageRating > 0 ? String(format: "Sip avg %.1f", averageRating) : "Cafe not rated"
    }

    var consumerPlaceCategory: String? {
        MugshotCafeCategory.display(placeCategory)
    }
}

extension SupabaseCafeSummary {
    var consumerDisplayName: String {
        MugshotCafeName.display(name)
    }
}
