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
