//
//  MugshotExperienceState.swift
//  testMugshot
//

import SwiftUI

enum MugshotUserFacingError {
    static func message(for error: Error, context: Context) -> String {
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
        if lowercased.contains("jwt") || lowercased.contains("session") || lowercased.contains("unauthorized") {
            return "Your session ended. Sign in again to continue."
        }

        switch context {
        case .photoUpload:
            return "We couldn’t add that photo. Your sip is still here—try again or remove the photo."
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

    enum Context {
        case photoUpload
        case social
        case cafeSearch
        case location
        case account
        case loading
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
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.mugshotSage)

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
    var systemImage = "checkmark"
    let eyebrow: String
    let title: String
    let message: String
    var facts: [MugshotCompletionFact] = []

    var body: some View {
        VStack(spacing: 14) {
            Group {
                if let assetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.foamWhite)
                        .frame(width: 64, height: 64)
                        .background(Color.mugshotSage, in: Circle())
                }
            }
            .frame(width: 72, height: 72)
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
        .padding(.horizontal, 26)
        .padding(.vertical, 24)
        .mugshotGlassSurface(radius: 26, tint: .foamWhite, interactive: false)
        .accessibilityElement(children: .combine)
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
        averageRating > 0 ? String(format: "%.1f", averageRating) : "Unrated"
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
