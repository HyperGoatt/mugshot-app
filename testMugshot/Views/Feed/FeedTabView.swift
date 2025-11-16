//
//  FeedTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

// Helper view to display the poster image for a visit
struct PosterImageView: View {
    let visit: Visit
    
    var body: some View {
        if let posterPath = visit.posterImagePath {
            PhotoImageView(photoPath: posterPath)
        } else {
            // Fallback placeholder
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(DS.Colors.cardBackgroundAlt)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(DS.Colors.iconSubtle)
                )
        }
    }
}

struct FeedTabView: View {
    @ObservedObject var dataManager: DataManager
    @State private var selectedScope: FeedScope = .friends
    @State private var selectedVisit: Visit?
    @State private var showVisitDetail = false
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Feed")
                        .font(DS.Typography.screenTitle)
                        .foregroundColor(DS.Colors.textPrimary)
                    Text("Sips from the community")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                    
                    // Scope toggle
                    HStack {
                        Spacer()
                        DSDesignSegmentedControl(
                            options: FeedScope.allCases.map { $0.displayName },
                            selectedIndex: Binding(
                                get: { FeedScope.allCases.firstIndex(of: selectedScope) ?? 0 },
                                set: { selectedScope = FeedScope.allCases[$0] }
                            )
                        )
                        Spacer()
                    }
                    .padding(.top, DS.Spacing.md)
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.appBarBackground)
                
                // Feed cards
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.cardVerticalGap) {
                        ForEach(visits) { visit in
                            VisitCard(
                                visit: visit,
                                dataManager: dataManager,
                                selectedScope: selectedScope,
                                onCafeTap: {
                                    if let cafe = dataManager.getCafe(id: visit.cafeId) {
                                        selectedCafe = cafe
                                        showCafeDetail = true
                                    }
                                }
                            )
                            .onTapGesture {
                                selectedVisit = visit
                                showVisitDetail = true
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    .padding(.top, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.xxl)
                }
                .background(DS.Colors.screenBackground)
            }
            .background(DS.Colors.screenBackground)
        }
        .fullScreenCover(isPresented: $showVisitDetail) {
            if let visit = selectedVisit {
                VisitDetailView(visit: visit, dataManager: dataManager)
            }
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                CafeDetailView(cafe: cafe, dataManager: dataManager)
            }
        }
    }
    
    private var visits: [Visit] {
        guard let currentUserId = dataManager.appData.currentUser?.id else {
            return []
        }
        return dataManager.getFeedVisits(scope: selectedScope, currentUserId: currentUserId)
    }
}

struct VisitCard: View {
    let visit: Visit
    @ObservedObject var dataManager: DataManager
    let selectedScope: FeedScope
    var onCafeTap: (() -> Void)? = nil
    
    var cafe: Cafe? {
        dataManager.getCafe(id: visit.cafeId)
    }
    
    var user: User? {
        // For now, use current user. Later, fetch by visit.userId
        dataManager.appData.currentUser?.id == visit.userId ? dataManager.appData.currentUser : nil
    }
    
    var isCurrentUser: Bool {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return false }
        return visit.userId == currentUserId
    }
    
    var isLiked: Bool {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return false }
        return visit.isLikedBy(userId: currentUserId)
    }
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Top author bar
            HStack(alignment: .top, spacing: 12) {
                // Avatar - 32pt diameter
                Circle()
                    .fill(DS.Colors.primaryAccent)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(user?.username.prefix(1).uppercased() ?? "U")
                            .font(DS.Typography.caption1)
                            .foregroundColor(DS.Colors.textOnMint)
                    )
                
                // Name and date
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(user?.displayNameOrUsername ?? user?.username ?? "user")
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textPrimary)
                        
                        if isCurrentUser {
                            Text("You")
                                    .font(DS.Typography.metaLabel)
                                    .foregroundColor(DS.Colors.textOnBlue)
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, 2)
                                    .background(DS.Colors.blueSoftFill)
                                    .cornerRadius(DS.Radius.chip)
                        }
                    }
                    
                    Text(formatDate(visit.createdAt))
                            .font(DS.Typography.caption1)
                            .foregroundColor(DS.Colors.textSecondary)
                }
                
                Spacer()
                
                // Rating badge
                    DSScoreBadge(score: visit.overallScore)
            }
            
            // Main hero image - fixed 4:3 aspect ratio
            if !visit.photos.isEmpty {
                PosterImageView(visit: visit)
                    .aspectRatio(4/3, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                    .clipped()
                        .cornerRadius(DS.Radius.card)
                } else {
                // Placeholder when no photo
                Rectangle()
                        .fill(DS.Colors.cardBackgroundAlt)
                    .aspectRatio(4/3, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                                .foregroundColor(DS.Colors.iconSubtle)
                    )
            }
            
            VStack(alignment: .leading, spacing: 10) {
                // Cafe + drink info row
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                                .font(.system(size: 11))
                                .foregroundColor(DS.Colors.primaryAccent)
                        Button(action: {
                            onCafeTap?()
                        }) {
                            Text(cafe?.name ?? "Unknown Café")
                                    .font(DS.Typography.bodyText)
                                    .foregroundColor(DS.Colors.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(visit.drinkType.rawValue + (visit.customDrinkType.map { " • \($0)" } ?? ""))
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                }
                
                // Caption
                if !visit.caption.isEmpty {
                    MentionText(text: visit.caption, mentions: visit.mentions)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(2)
                }
                
                // Social row
                    HStack(spacing: DS.Spacing.lg) {
                    Button(action: {
                        if let userId = dataManager.appData.currentUser?.id {
                            dataManager.toggleVisitLike(visit.id, userId: userId)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 15))
                                    .foregroundColor(isLiked ? DS.Colors.primaryAccent : DS.Colors.textSecondary)
                            Text("\(visit.likeCount)")
                                    .font(DS.Typography.bodyText)
                                    .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                                .font(.system(size: 15))
                                .foregroundColor(DS.Colors.textSecondary)
                        Text("\(visit.commentCount)")
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
            }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct VisitDetailView: View {
    @ObservedObject var dataManager: DataManager
    @State private var visit: Visit
    @Environment(\.dismiss) var dismiss
    @State private var commentText = ""
    @FocusState private var isCommentFocused: Bool
        @State private var showEdit = false
        @State private var showDeleteAlert = false
    
    init(visit: Visit, dataManager: DataManager) {
        self._visit = State(initialValue: visit)
        self.dataManager = dataManager
    }
    
    var cafe: Cafe? {
        dataManager.getCafe(id: visit.cafeId)
    }
    
    var user: User? {
        dataManager.appData.currentUser?.id == visit.userId ? dataManager.appData.currentUser : nil
    }
    
    var isLiked: Bool {
        guard let currentUserId = dataManager.appData.currentUser?.id else { return false }
        return visit.isLikedBy(userId: currentUserId)
    }
    
    var comments: [Comment] {
        dataManager.getComments(for: visit.id)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Photo carousel
                        if !visit.photos.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // Show poster image first, then rest
                                    let orderedPhotos = getOrderedPhotos(for: visit)
                                    ForEach(orderedPhotos, id: \.self) { photoPath in
                                        PhotoImageView(photoPath: photoPath)
                                            .frame(width: 300, height: 300)
                                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                                    }
                                }
                                .padding()
                            }
                        } else {
                            // Fallback placeholder when no photos
                            RoundedRectangle(cornerRadius: DS.Radius.card)
                                .fill(DS.Colors.cardBackgroundAlt)
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 48))
                                        .foregroundColor(DS.Colors.iconSubtle)
                                )
                                .padding(.horizontal)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Header: Cafe + Author
                            VStack(alignment: .leading, spacing: 8) {
                                Text(cafe?.name ?? "Unknown Café")
                                    .font(DS.Typography.title1(.bold))
                                    .foregroundColor(DS.Colors.textPrimary)
                                
                                if let address = cafe?.address, !address.isEmpty {
                                    Text(address)
                                        .font(DS.Typography.bodyText)
                                        .foregroundColor(DS.Colors.textSecondary)
                                }
                                
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(DS.Colors.primaryAccent)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(user?.username.prefix(1).uppercased() ?? "U")
                                                .font(DS.Typography.caption1)
                                                .foregroundColor(DS.Colors.textOnMint)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("@\(user?.username ?? "user")")
                                            .font(DS.Typography.bodyText)
                                            .foregroundColor(DS.Colors.textPrimary)
                                        
                                        Text(timeAgoString(from: visit.createdAt))
                                            .font(DS.Typography.caption2)
                                            .foregroundColor(DS.Colors.textSecondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.top, 8)
                            }
                            
                            Divider()
                            
                            // Drink type
                            HStack {
                                Text("Drink")
                                    .font(DS.Typography.sectionTitle)
                                    .foregroundColor(DS.Colors.textPrimary)
                                
                                Spacer()
                                
                                Text(visit.drinkType.rawValue + (visit.customDrinkType.map { " • \($0)" } ?? ""))
                                    .font(DS.Typography.bodyText)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                            
                            // Overall score
                            HStack {
                                Text("Overall Score")
                                    .font(DS.Typography.sectionTitle)
                                    .foregroundColor(DS.Colors.textPrimary)
                                
                                Spacer()
                                
                                DSScoreBadge(score: visit.overallScore)
                            }
                            
                            // Rating breakdown
                            DSBaseCard {
                                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                                    Text("Rating Breakdown")
                                        .font(DS.Typography.sectionTitle)
                                        .foregroundColor(DS.Colors.textPrimary)
                                    
                                    ForEach(Array(visit.ratings.keys.sorted()), id: \.self) { category in
                                        if let rating = visit.ratings[category] {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text(category)
                                                        .font(DS.Typography.bodyText)
                                                        .foregroundColor(DS.Colors.textPrimary)
                                                    Spacer()
                                                    Text(String(format: "%.1f", rating))
                                                        .font(DS.Typography.bodyText)
                                                        .foregroundColor(DS.Colors.primaryAccent)
                                                }
                                                
                                                ProgressView(value: rating, total: 5.0)
                                                    .tint(DS.Colors.primaryAccent)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Caption with mentions
                            if !visit.caption.isEmpty {
                                DSBaseCard {
                                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                        Text("Caption")
                                            .font(DS.Typography.sectionTitle)
                                            .foregroundColor(DS.Colors.textPrimary)
                                        MentionText(text: visit.caption, mentions: visit.mentions)
                                            .font(DS.Typography.bodyText)
                                            .foregroundColor(DS.Colors.textPrimary)
                                    }
                                }
                            }
                            
                            // Notes (private)
                            if let notes = visit.notes, !notes.isEmpty {
                                DSBaseCard {
                                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                        Text("Private Notes")
                                            .font(DS.Typography.sectionTitle)
                                            .foregroundColor(DS.Colors.textSecondary)
                                        Text(notes)
                                            .font(DS.Typography.bodyText)
                                            .foregroundColor(DS.Colors.textSecondary)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Social actions
                            HStack(spacing: DS.Spacing.section) {
                                Button(action: {
                                    if let userId = dataManager.appData.currentUser?.id {
                                        dataManager.toggleVisitLike(visit.id, userId: userId)
                                        // Update local visit state
                                        if let updatedVisit = dataManager.getVisit(id: visit.id) {
                                            visit = updatedVisit
                                        }
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: isLiked ? "heart.fill" : "heart")
                                            .font(.system(size: 18))
                                            .foregroundColor(isLiked ? DS.Colors.primaryAccent : DS.Colors.textSecondary)
                                        Text("\(visit.likeCount)")
                                            .font(DS.Typography.bodyText)
                                            .foregroundColor(DS.Colors.textPrimary)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.right")
                                        .font(.system(size: 18))
                                        .foregroundColor(DS.Colors.textSecondary)
                                    Text("\(visit.commentCount)")
                                        .font(DS.Typography.bodyText)
                                        .foregroundColor(DS.Colors.textPrimary)
                                }
                            }
                            .padding(.vertical, 8)
                            
                            // Comments section
                            DSBaseCard {
                                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                                    Text("Comments")
                                        .font(DS.Typography.sectionTitle)
                                        .foregroundColor(DS.Colors.textPrimary)
                                    
                                    if comments.isEmpty {
                                        Text("No comments yet")
                                            .font(DS.Typography.bodyText)
                                            .foregroundColor(DS.Colors.textSecondary)
                                            .padding(.vertical, DS.Spacing.sm)
                                    } else {
                                        ForEach(comments) { comment in
                                            CommentRow(comment: comment, dataManager: dataManager)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Comment composer
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        TextField("Add a comment…", text: $commentText, axis: .vertical)
                            .foregroundColor(DS.Colors.textPrimary)
                            .tint(DS.Colors.primaryAccent)
                            .accentColor(DS.Colors.primaryAccent)
                            .padding(8)
                            .background(DS.Colors.cardBackground)
                            .cornerRadius(DS.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                            )
                            .focused($isCommentFocused)
                            .lineLimit(1...4)
                        
                        Button(action: {
                            addComment()
                        }) {
                            Text("Send")
                                .font(DS.Typography.buttonLabel)
                                .foregroundColor(DS.Colors.primaryAccent)
                        }
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(DS.Colors.cardBackground)
                }
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Visit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                    // Menu for edit/delete if this is the current user's visit
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if let currentUserId = dataManager.appData.currentUser?.id, currentUserId == visit.userId {
                            Menu {
                                Button("Edit") { showEdit = true }
                                Button(role: .destructive) {
                                    showDeleteAlert = true
                                } label: {
                                    Text("Delete")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(DS.Colors.textPrimary)
                            }
                        }
                    }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Refresh visit data
                if let updatedVisit = dataManager.getVisit(id: visit.id) {
                    visit = updatedVisit
                }
            }
                .sheet(isPresented: $showEdit) {
                    EditVisitView(visit: visit, dataManager: dataManager) { updated in
                        visit = updated
                    }
                }
                .alert("Delete this visit?", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        dataManager.deleteVisit(id: visit.id)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will remove it from your map, feed, and saved lists.")
                }
        }
    }
    
    private func addComment() {
        guard let userId = dataManager.appData.currentUser?.id,
              !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        dataManager.addComment(to: visit.id, userId: userId, text: commentText)
        commentText = ""
        isCommentFocused = false
        
        // Refresh visit to get updated comments
        if let updatedVisit = dataManager.getVisit(id: visit.id) {
            visit = updatedVisit
        }
    }
    
    // Simple edit screen for a visit (caption, notes, ratings, visibility)
    struct EditVisitView: View {
        @Environment(\.dismiss) var dismiss
        @ObservedObject var dataManager: DataManager
        @State private var editableVisit: Visit
        var onSave: (Visit) -> Void
        
        init(visit: Visit, dataManager: DataManager, onSave: @escaping (Visit) -> Void) {
            self._editableVisit = State(initialValue: visit)
            self.dataManager = dataManager
            self.onSave = onSave
        }
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Caption
                            DSBaseCard {
                                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                    Text("Caption")
                                        .font(DS.Typography.sectionTitle)
                                        .foregroundColor(DS.Colors.textPrimary)
                                    TextField("Caption", text: $editableVisit.caption, axis: .vertical)
                                        .lineLimit(3...6)
                                        .foregroundColor(DS.Colors.textPrimary)
                                        .tint(DS.Colors.primaryAccent)
                                        .padding()
                                        .background(DS.Colors.cardBackground)
                                        .cornerRadius(DS.Radius.md)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                                        )
                                }
                            }
                        
                        // Notes
                            DSBaseCard {
                                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                    Text("Notes")
                                        .font(DS.Typography.sectionTitle)
                                        .foregroundColor(DS.Colors.textPrimary)
                                    TextField("Notes", text: Binding(get: { editableVisit.notes ?? "" }, set: { editableVisit.notes = $0 }), axis: .vertical)
                                        .lineLimit(3...8)
                                        .foregroundColor(DS.Colors.textPrimary)
                                        .tint(DS.Colors.primaryAccent)
                                        .padding()
                                        .background(DS.Colors.cardBackground)
                                        .cornerRadius(DS.Radius.md)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                                        )
                                }
                            }
                        
                        // Visibility
                            DSBaseCard {
                                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                    Text("Visibility")
                                        .font(DS.Typography.sectionTitle)
                                        .foregroundColor(DS.Colors.textPrimary)
                                    Picker("", selection: $editableVisit.visibility) {
                                        Text("Private").tag(VisitVisibility.private)
                                        Text("Friends").tag(VisitVisibility.friends)
                                        Text("Everyone").tag(VisitVisibility.everyone)
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                    }
                    .padding()
                }
                    .background(DS.Colors.screenBackground)
                .navigationTitle("Edit Visit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(DS.Colors.textPrimary)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            dataManager.updateVisit(editableVisit)
                            onSave(editableVisit)
                            dismiss()
                        }
                            .foregroundColor(DS.Colors.primaryAccent)
                    }
                }
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Helper to get ordered photos (poster first, then rest)
    private func getOrderedPhotos(for visit: Visit) -> [String] {
        guard !visit.photos.isEmpty else { return [] }
        
        var ordered = visit.photos
        if let posterPath = visit.posterImagePath,
           let posterIndex = ordered.firstIndex(of: posterPath) {
            // Move poster to front
            ordered.remove(at: posterIndex)
            ordered.insert(posterPath, at: 0)
        }
        return ordered
    }
}

struct CommentRow: View {
    let comment: Comment
    @ObservedObject var dataManager: DataManager
    
    var user: User? {
        // For now, use current user. Later, fetch by comment.userId
        dataManager.appData.currentUser?.id == comment.userId ? dataManager.appData.currentUser : nil
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Circle()
                .fill(DS.Colors.primaryAccent)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(user?.username.prefix(1).uppercased() ?? "U")
                        .font(DS.Typography.caption1)
                        .foregroundColor(DS.Colors.textOnMint)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(user?.username ?? "user")")
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textPrimary)
                
                MentionText(text: comment.text, mentions: comment.mentions)
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Text(timeAgoString(from: comment.createdAt))
                    .font(DS.Typography.caption2)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(DS.Spacing.cardPadding)
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.md)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

