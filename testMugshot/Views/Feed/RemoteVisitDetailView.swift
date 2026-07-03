//
//  RemoteVisitDetailView.swift
//  testMugshot
//

import SwiftUI

struct RemoteVisitDetailView: View {
    let visitId: UUID
    let initialSummary: RemoteVisitSummary
    let currentUserId: UUID?
    @ObservedObject var dataManager: DataManager

    @Environment(\.dismiss) private var dismiss
    @State private var detail: RemoteVisitDetail?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var socialError: String?
    @State private var isSavingSocialAction = false
    @State private var commentText = ""
    @State private var isShowingEditVisit = false
    @State private var isDeletingVisit = false
    @State private var showDeleteConfirmation = false

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
                if let detail,
                   currentUserId == detail.summary.visit.userId {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Button {
                                isShowingEditVisit = true
                            } label: {
                                Label("Edit Visit", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Visit", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.espressoBrown)
                        }
                        .disabled(isDeletingVisit)
                    }
                }

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
            .sheet(isPresented: $isShowingEditVisit) {
                if let detail,
                   let currentUserId {
                    EditRemoteVisitView(
                        detail: detail,
                        currentUserId: currentUserId,
                        onSave: saveVisitEdits
                    )
                }
            }
            .confirmationDialog(
                "Delete this visit?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Visit", role: .destructive) {
                    Task {
                        await deleteVisit()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the remote visit from Profile, Feed, and cafe history.")
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
                MugAvatarView(name: detail.summary.authorDisplayName, diameter: 40)

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
        MugTagChip(title: title, systemImage: systemImage)
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
        MugScoreBadge(score: score)
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
                        .foregroundColor(.mugshotForest)
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
                                .tint(.mugshotForest)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    Task {
                        await toggleLike()
                    }
                } label: {
                    Label("\(detail.likeCount)", systemImage: detail.currentUserHasLiked ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(detail.currentUserHasLiked ? .mugshotForest : .espressoBrown.opacity(0.78))
                }
                .buttonStyle(.plain)
                .disabled(currentUserId == nil || isSavingSocialAction)

                Label("\(detail.commentCount)", systemImage: "bubble.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.espressoBrown.opacity(0.78))

                Spacer(minLength: 0)

                if detail.summary.cafe != nil {
                    Button {
                        saveCafeFromVisit(detail)
                    } label: {
                        Label(isCafeSaved(detail) ? "Saved" : "Save Cafe", systemImage: isCafeSaved(detail) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }

            if let socialError {
                Text(socialError)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
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

            if currentUserId != nil {
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Add a comment", text: $commentText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(11)
                        .background(Color.sandBeige.opacity(0.32))
                        .cornerRadius(DesignSystem.smallCornerRadius)

                    Button {
                        Task {
                            await postComment()
                        }
                    } label: {
                        Image(systemName: isSavingSocialAction ? "hourglass" : "paperplane.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(commentText.remoteTrimmedNonEmpty == nil || isSavingSocialAction)
                }
            }
        }
        .padding(.horizontal)
    }

    private var loadingContent: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.mugshotForest)

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
            .foregroundColor(.mugshotForest)
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

    @MainActor
    private func toggleLike() async {
        guard let currentUserId,
              let detail else {
            return
        }

        isSavingSocialAction = true
        socialError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let state = try await service.toggleLike(
                visitId: visitId,
                userId: currentUserId,
                currentlyLiked: detail.currentUserHasLiked
            )
            applySocialState(state)
            isSavingSocialAction = false
        } catch {
            socialError = "Could not update like."
            isSavingSocialAction = false
        }
    }

    @MainActor
    private func postComment() async {
        guard let currentUserId,
              let detail,
              commentText.remoteTrimmedNonEmpty != nil else {
            return
        }

        let text = commentText
        isSavingSocialAction = true
        socialError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            _ = try await service.addComment(
                visitId: visitId,
                userId: currentUserId,
                text: text
            )
            self.detail = try await service.fetchVisitDetail(
                visitId: visitId,
                currentUserId: currentUserId
            )
            commentText = ""
            isSavingSocialAction = false
        } catch {
            self.detail = detail
            socialError = "Could not post comment."
            isSavingSocialAction = false
        }
    }

    @MainActor
    private func saveVisitEdits(
        caption: String,
        notes: String,
        visibility: VisitVisibility
    ) async -> Bool {
        guard let currentUserId else {
            return false
        }

        do {
            let update = try SupabaseVisitUpdate.make(
                caption: caption,
                notes: notes,
                visibility: visibility
            )
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let summary = try await service.updateVisit(
                visitId: visitId,
                userId: currentUserId,
                update: update
            )
            self.detail = try await service.fetchVisitDetail(
                visitId: summary.id,
                currentUserId: currentUserId
            )
            return true
        } catch {
            socialError = error.localizedDescription
            return false
        }
    }

    @MainActor
    private func deleteVisit() async {
        guard let currentUserId else {
            return
        }

        isDeletingVisit = true
        socialError = nil

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            try await service.deleteVisit(
                visitId: visitId,
                userId: currentUserId
            )
            isDeletingVisit = false
            dismiss()
        } catch {
            socialError = "Could not delete visit."
            isDeletingVisit = false
        }
    }

    private func applySocialState(_ state: RemoteVisitSocialState) {
        guard let detail else {
            return
        }

        self.detail = RemoteVisitDetail(
            summary: RemoteVisitSummary(
                visit: detail.summary.visit,
                cafe: detail.summary.cafe,
                author: detail.summary.author,
                socialState: state
            ),
            photos: detail.photos,
            comments: detail.comments,
            likeCount: state.likeCount,
            currentUserHasLiked: state.currentUserHasLiked
        )
    }

    private func isCafeSaved(_ detail: RemoteVisitDetail) -> Bool {
        guard let remoteCafeId = detail.summary.cafe?.id else {
            return false
        }

        return dataManager.appData.cafes.contains { cafe in
            (cafe.remoteCafeId == remoteCafeId || cafe.id == remoteCafeId) && (cafe.isFavorite || cafe.wantToTry)
        }
    }

    private func saveCafeFromVisit(_ detail: RemoteVisitDetail) {
        guard let remoteCafe = detail.summary.cafe else {
            return
        }

        let existing = dataManager.appData.cafes.first {
            $0.remoteCafeId == remoteCafe.id || $0.id == remoteCafe.id
        }
        let localCafe = dataManager.upsertRemoteCafe(
            remoteCafe,
            isFavorite: true,
            wantToTry: existing?.wantToTry ?? false
        )

        guard let currentUserId else {
            return
        }

        Task {
            do {
                let client = try SupabaseClientProvider.shared.client()
                let service = CafeStateService(client: client)
                let summary = try await service.setCafeState(
                    userId: currentUserId,
                    cafe: localCafe,
                    isFavorite: true,
                    wantToTry: existing?.wantToTry ?? false
                )
                dataManager.applyRemoteCafeState(summary)
            } catch {
                socialError = "Could not save cafe."
            }
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
                                    .tint(.mugshotForest)
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
            MugAvatarView(name: comment.authorDisplayName, diameter: 38)

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

struct EditRemoteVisitView: View {
    let detail: RemoteVisitDetail
    let currentUserId: UUID
    let onSave: (String, String, VisitVisibility) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var caption: String
    @State private var notes: String
    @State private var visibility: VisitVisibility
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        detail: RemoteVisitDetail,
        currentUserId: UUID,
        onSave: @escaping (String, String, VisitVisibility) async -> Bool
    ) {
        self.detail = detail
        self.currentUserId = currentUserId
        self.onSave = onSave
        _caption = State(initialValue: detail.summary.visit.caption)
        _notes = State(initialValue: detail.summary.visit.trimmedNotes ?? "")
        _visibility = State(initialValue: VisitVisibility.supabaseValue(detail.summary.visit.visibility))
    }

    private var canSave: Bool {
        caption.remoteTrimmedNonEmpty != nil && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Caption")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)

                        TextField("Caption", text: $caption, axis: .vertical)
                            .lineLimit(3...6)
                            .remoteVisitEditField()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Private Notes")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)

                        TextField("Only visible to you", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .remoteVisitEditField()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visibility")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)

                        Picker("Visibility", selection: $visibility) {
                            Text("Private").tag(VisitVisibility.private)
                            Text("Friends").tag(VisitVisibility.friends)
                            Text("Everyone").tag(VisitVisibility.everyone)
                        }
                        .pickerStyle(.segmented)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task {
                            await save()
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.espressoBrown)
                            }
                            Text("Save Visit")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.62)
                }
                .padding(DesignSystem.largePadding)
            }
            .background(Color.creamWhite)
            .navigationTitle("Edit Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        guard canSave else {
            return
        }

        isSaving = true
        errorMessage = nil
        let didSave = await onSave(caption, notes, visibility)
        isSaving = false

        if didSave {
            dismiss()
        } else {
            errorMessage = "Could not save visit edits."
        }
    }
}

private extension View {
    func remoteVisitEditField() -> some View {
        padding(12)
            .foregroundColor(.inputText)
            .tint(.mugshotForest)
            .background(Color.inputBackground)
            .cornerRadius(DesignSystem.smallCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                    .stroke(Color.inputBorder, lineWidth: 1)
            )
    }
}

extension VisitVisibility {
    static func supabaseValue(_ value: String) -> VisitVisibility {
        switch value.lowercased() {
        case "private":
            return .private
        case "friends":
            return .friends
        default:
            return .everyone
        }
    }
}
