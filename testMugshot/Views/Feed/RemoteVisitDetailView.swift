//
//  RemoteVisitDetailView.swift
//  testMugshot
//

import SwiftUI

struct RemoteVisitDetailView: View {
    let visitId: UUID
    let initialSummary: RemoteVisitSummary
    let currentUserId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var detail: RemoteVisitDetail?
    @State private var isLoading = false
    @State private var loadError: String?

    private var displayedSummary: RemoteVisitSummary {
        detail?.summary ?? initialSummary
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamWhite.ignoresSafeArea()

                if let detail {
                    detailContent(detail)
                } else if isLoading {
                    loadingContent
                } else if let loadError {
                    errorContent(loadError)
                } else {
                    loadingContent
                }
            }
            .navigationTitle("Visit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.espressoBrown)
                }
            }
            .task(id: visitId) {
                await loadDetail()
            }
        }
    }

    private func detailContent(_ detail: RemoteVisitDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                savedStatusSection(detail)
                photoSection(detail)
                headerSection(detail)
                drinkSection(detail)
                ratingSection(detail)
                captionSection(detail)
                socialSection(detail)
                commentsSection(detail)
            }
            .padding(.bottom, 24)
        }
        .background(Color.creamWhite)
    }

    private func photoSection(_ detail: RemoteVisitDetail) -> some View {
        Group {
            if detail.photoURLs.isEmpty {
                noPhotoHero(detail)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    RemotePhotoImageView(
                        urlString: detail.photoURLs.first,
                        placeholderSystemName: "photo.on.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 310)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.largeCornerRadius))
                    .overlay(alignment: .topTrailing) {
                        scoreBadge(score: detail.summary.visit.overallScore)
                            .padding(12)
                    }

                    if detail.photoURLs.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(detail.photoURLs.dropFirst().enumerated()), id: \.offset) { _, urlString in
                                    RemotePhotoImageView(
                                        urlString: urlString,
                                        placeholderSystemName: "photo"
                                    )
                                    .frame(width: 74, height: 74)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, currentUserId == detail.summary.visit.userId ? 0 : 16)
    }

    @ViewBuilder
    private func savedStatusSection(_ detail: RemoteVisitDetail) -> some View {
        if currentUserId == detail.summary.visit.userId {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.mugshotMint.opacity(0.32))
                        .frame(width: 64, height: 64)

                    Image(systemName: "checkmark")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundColor(.espressoBrown)
                }

                VStack(spacing: 4) {
                    Text("Sip saved")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    Text("Added to your taste journal and Profile Recent.")
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown.opacity(0.66))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 4)
        }
    }

    private func noPhotoHero(_ detail: RemoteVisitDetail) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 46))
                .foregroundColor(.espressoBrown.opacity(0.34))

            VStack(spacing: 4) {
                Text("No photo yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                Text(currentUserId == detail.summary.visit.userId ? "This sip is safely saved without a photo." : "This visit was saved without a photo.")
                    .font(.system(size: 13))
                    .foregroundColor(.espressoBrown.opacity(0.64))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(Color.sandBeige.opacity(0.48))
            .cornerRadius(DesignSystem.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                    .stroke(Color.sandBeige, lineWidth: 1)
            )
            .padding(.horizontal)
    }

    private func headerSection(_ detail: RemoteVisitDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(.espressoBrown.opacity(0.78))
                    .frame(width: 46, height: 46)
                    .background(Color.sandBeige.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))

                VStack(alignment: .leading, spacing: 6) {
                    Text(detail.summary.locationTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = detail.summary.locationSubtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.espressoBrown.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                scoreBadge(score: detail.summary.visit.overallScore)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(detail.summary.visit.drinkDisplayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)

                if !detail.summary.visit.caption.isEmpty {
                    Text(detail.summary.visit.caption)
                        .font(.system(size: 15))
                        .foregroundColor(.espressoBrown.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Circle()
                    .fill(Color.mugshotMint)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(detail.summary.authorInitial)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(detail.summary.authorDisplayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)

                    Text("@\(detail.summary.authorUsername) · \(timeAgoString(from: detail.summary.visit.createdAtDate))")
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.6))
                }

                Spacer()
            }

            HStack(spacing: 8) {
                visitMetaPill(detail.summary.visit.backendVisibilityLabel, systemImage: visibilityIcon(for: detail.summary.visit.backendVisibilityLabel))
                visitMetaPill(detail.summary.visit.contextDisplayName, systemImage: "cup.and.saucer.fill")
                visitMetaPill(timeAgoString(from: detail.summary.visit.createdAtDate), systemImage: "clock.fill")
            }
        }
        .padding()
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige, lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func visitMetaPill(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.espressoBrown.opacity(0.72))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.sandBeige.opacity(0.34))
        .clipShape(Capsule())
    }

    private func visibilityIcon(for label: String) -> String {
        switch label.lowercased() {
        case "private":
            return "lock.fill"
        case "friends":
            return "person.2.fill"
        default:
            return "globe"
        }
    }

    private func scoreBadge(score: Double) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(String(format: "%.1f", score))
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.espressoBrown)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.mugshotMint.opacity(0.35))
        .cornerRadius(999)
    }

    private func drinkSection(_ detail: RemoteVisitDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visit Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.espressoBrown)

            detailRow(title: "Drink", value: detail.summary.visit.drinkDisplayName)

            if let category = detail.summary.visit.drinkCategoryDisplayName,
               category != detail.summary.visit.drinkDisplayName {
                detailRow(title: "Category", value: category)
            }

            if let brewMethod = detail.summary.visit.brewMethod?.remoteTrimmedNonEmpty {
                detailRow(title: "Brew Method", value: brewMethod)
            }
        }
        .padding()
        .background(Color.sandBeige.opacity(0.28))
        .cornerRadius(DesignSystem.cornerRadius)
        .padding(.horizontal)
    }

    private func ratingSection(_ detail: RemoteVisitDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Overall Score")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.mugshotMint)
                    Text(String(format: "%.1f", detail.summary.visit.overallScore))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.espressoBrown)
                }
            }

            if !detail.summary.visit.ratings.isEmpty {
                Divider()

                ForEach(detail.summary.visit.ratings.keys.sorted(), id: \.self) { category in
                    if let rating = detail.summary.visit.ratings[category] {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(category)
                                    .font(.system(size: 14))
                                    .foregroundColor(.espressoBrown)

                                Spacer()

                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.espressoBrown)
                            }

                            ProgressView(value: rating, total: 5)
                                .tint(.mugshotMint)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige, lineWidth: 1)
        )
        .padding(.horizontal)
    }

    @ViewBuilder
    private func captionSection(_ detail: RemoteVisitDetail) -> some View {
        if currentUserId == detail.summary.visit.userId,
           let notes = detail.summary.visit.trimmedNotes {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Private Notes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.espressoBrown)

                    Text(notes)
                        .font(.system(size: 15))
                        .foregroundColor(.espressoBrown.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal)
        }
    }

    private func socialSection(_ detail: RemoteVisitDetail) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: detail.currentUserHasLiked ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundColor(detail.currentUserHasLiked ? .mugshotMint : .espressoBrown.opacity(0.72))

                Text("\(detail.likeCount)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.espressoBrown)
            }

            HStack(spacing: 7) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 18))
                    .foregroundColor(.espressoBrown.opacity(0.72))

                Text("\(detail.commentCount)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.espressoBrown)
            }

            Spacer(minLength: 0)

            Text("Read-only")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.55))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.sandBeige.opacity(0.32))
                .clipShape(Capsule())
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private func commentsSection(_ detail: RemoteVisitDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.espressoBrown)

            if detail.comments.isEmpty {
                Text("No comments yet")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                ForEach(detail.comments) { comment in
                    RemoteCommentRow(comment: comment)
                        .padding(.leading, comment.comment.parentCommentId == nil ? 0 : 18)
                }
            }
        }
        .padding(.horizontal)
    }

    private var loadingContent: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.mugshotMint)

            Text(displayedSummary.locationTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .multilineTextAlignment(.center)

            Text("Loading visit...")
                .font(.system(size: 13))
                .foregroundColor(.espressoBrown.opacity(0.65))
        }
        .padding()
    }

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Could not load visit")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.espressoBrown)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.espressoBrown.opacity(0.65))
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await loadDetail()
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.mugshotMint)
        }
        .padding()
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.espressoBrown)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.espressoBrown.opacity(0.72))
                .multilineTextAlignment(.trailing)
        }
    }

    private func loadDetail() async {
        isLoading = true
        loadError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            detail = try await service.fetchVisitDetail(
                visitId: visitId,
                currentUserId: currentUserId
            )
            isLoading = false
        } catch {
            detail = nil
            loadError = error.localizedDescription
            isLoading = false
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct RemotePhotoImageView: View {
    let urlString: String?
    let placeholderSystemName: String

    var body: some View {
        Group {
            if let urlString,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                            .overlay(
                                ProgressView()
                                    .tint(.mugshotMint)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .background(Color.sandBeige)
        .clipped()
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.sandBeige)
            .overlay(
                Image(systemName: placeholderSystemName)
                    .font(.system(size: 44))
                    .foregroundColor(.espressoBrown.opacity(0.32))
            )
    }
}

struct RemoteCommentRow: View {
    let comment: RemoteVisitComment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.mugshotMint)
                .frame(width: 38, height: 38)
                .overlay(
                    Text(comment.authorInitial)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(comment.authorDisplayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(1)

                    Text("@\(comment.authorUsername)")
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.55))
                        .lineLimit(1)
                }

                Text(comment.comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                Text(timeAgoString(from: comment.comment.createdAtDate))
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.55))
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(Color.sandBeige.opacity(0.3))
        .cornerRadius(DesignSystem.smallCornerRadius)
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
