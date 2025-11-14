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
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .fill(Color.sandBeige)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.espressoBrown.opacity(0.3))
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
                // Custom header
                VStack(alignment: .leading, spacing: 0) {
                    // Top spacing from safe area
                    Spacer()
                        .frame(height: 16)
                    
                    // Title and search icon row
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Feed")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.espressoBrown)
                            
                            Text("Sips from the community")
                                .font(.system(size: 15))
                                .foregroundColor(.espressoBrown.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Search functionality - can be added later
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18))
                                .foregroundColor(.espressoBrown)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Space between subtitle and toggle
                    Spacer()
                        .frame(height: 12)
                    
                    // Pill-style scope toggle container - centered
                    HStack {
                        Spacer()
                        HStack(spacing: 0) {
                            ForEach(FeedScope.allCases, id: \.self) { scope in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedScope = scope
                                    }
                                }) {
                                    Text(scope.displayName)
                                        .font(.system(size: 14, weight: selectedScope == scope ? .semibold : .medium))
                                        .foregroundColor(selectedScope == scope ? .espressoBrown : .espressoBrown.opacity(0.7))
                                        .frame(width: 90)
                                        .frame(height: 36)
                                        .background(
                                            selectedScope == scope 
                                                ? Color.creamWhite 
                                                : Color.clear
                                        )
                                        .cornerRadius(18)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(Color.sandBeige.opacity(0.4))
                        .cornerRadius(18)
                        Spacer()
                    }
                    .padding(.bottom, 16)
                }
                .background(Color.creamWhite)
                
                // Feed cards
                ScrollView {
                    LazyVStack(spacing: 12) {
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
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .background(Color.sandBeige.opacity(0.3))
            }
            .background(Color.creamWhite)
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
        VStack(alignment: .leading, spacing: 0) {
            // Top author bar
            HStack(alignment: .top, spacing: 12) {
                // Avatar - 32pt diameter
                Circle()
                    .fill(Color.mugshotMint)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(user?.username.prefix(1).uppercased() ?? "U")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                    )
                
                // Name and date
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(user?.displayNameOrUsername ?? user?.username ?? "user")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.espressoBrown)
                        
                        if isCurrentUser {
                            Text("You")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    
                    Text(formatDate(visit.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.espressoBrown.opacity(0.6))
                }
                
                Spacer()
                
                // Rating badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.mugshotMint)
                    Text(String(format: "%.1f", visit.overallScore))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.sandBeige.opacity(0.5))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)
            
            // Main hero image - fixed 4:3 aspect ratio
            if !visit.photos.isEmpty {
                PosterImageView(visit: visit)
                    .aspectRatio(4/3, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                // Placeholder when no photo
                Rectangle()
                    .fill(Color.sandBeige)
                    .aspectRatio(4/3, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.espressoBrown.opacity(0.3))
                    )
            }
            
            VStack(alignment: .leading, spacing: 10) {
                // Cafe + drink info row
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.mugshotMint)
                        Button(action: {
                            onCafeTap?()
                        }) {
                            Text(cafe?.name ?? "Unknown Café")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.espressoBrown)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(visit.drinkType.rawValue + (visit.customDrinkType.map { " • \($0)" } ?? ""))
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // Caption
                if !visit.caption.isEmpty {
                    MentionText(text: visit.caption, mentions: visit.mentions)
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                }
                
                // Social row
                HStack(spacing: 16) {
                    Button(action: {
                        if let userId = dataManager.appData.currentUser?.id {
                            dataManager.toggleVisitLike(visit.id, userId: userId)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 15))
                                .foregroundColor(isLiked ? .mugshotMint : .espressoBrown.opacity(0.7))
                            Text("\(visit.likeCount)")
                                .font(.system(size: 14))
                                .foregroundColor(.espressoBrown.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 15))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                        Text("\(visit.commentCount)")
                            .font(.system(size: 14))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color.creamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
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
                                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius))
                                    }
                                }
                                .padding()
                            }
                        } else {
                            // Fallback placeholder when no photos
                            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                                .fill(Color.sandBeige)
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 48))
                                        .foregroundColor(.espressoBrown.opacity(0.3))
                                )
                                .padding(.horizontal)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Header: Cafe + Author
                            VStack(alignment: .leading, spacing: 8) {
                                Text(cafe?.name ?? "Unknown Café")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.espressoBrown)
                                
                                if let address = cafe?.address, !address.isEmpty {
                                    Text(address)
                                        .font(.system(size: 14))
                                        .foregroundColor(.espressoBrown.opacity(0.7))
                                }
                                
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.mugshotMint)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(user?.username.prefix(1).uppercased() ?? "U")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.espressoBrown)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("@\(user?.username ?? "user")")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.espressoBrown)
                                        
                                        Text(timeAgoString(from: visit.createdAt))
                                            .font(.system(size: 12))
                                            .foregroundColor(.espressoBrown.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.top, 8)
                            }
                            
                            Divider()
                            
                            // Drink type
                            HStack {
                                Text("Drink")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.espressoBrown)
                                
                                Spacer()
                                
                                Text(visit.drinkType.rawValue + (visit.customDrinkType.map { " • \($0)" } ?? ""))
                                    .font(.system(size: 14))
                                    .foregroundColor(.espressoBrown.opacity(0.7))
                            }
                            
                            // Overall score
                            HStack {
                                Text("Overall Score")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.espressoBrown)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.mugshotMint)
                                    Text(String(format: "%.1f", visit.overallScore))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.espressoBrown)
                                }
                            }
                            
                            // Rating breakdown
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Rating Breakdown")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.espressoBrown)
                                
                                ForEach(Array(visit.ratings.keys.sorted()), id: \.self) { category in
                                    if let rating = visit.ratings[category] {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(category)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.espressoBrown)
                                                Spacer()
                                                Text(String(format: "%.1f", rating))
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.mugshotMint)
                                            }
                                            
                                            ProgressView(value: rating, total: 5.0)
                                                .tint(.mugshotMint)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color.sandBeige.opacity(0.3))
                            .cornerRadius(DesignSystem.cornerRadius)
                            
                            // Caption with mentions
                            if !visit.caption.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Caption")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.espressoBrown)
                                    
                                    MentionText(text: visit.caption, mentions: visit.mentions)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            // Notes (private)
                            if let notes = visit.notes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Private Notes")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.espressoBrown.opacity(0.7))
                                    
                                    Text(notes)
                                        .font(.system(size: 14))
                                        .foregroundColor(.espressoBrown.opacity(0.7))
                                }
                            }
                            
                            Divider()
                            
                            // Social actions
                            HStack(spacing: 32) {
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
                                            .foregroundColor(isLiked ? .mugshotMint : .espressoBrown.opacity(0.7))
                                        Text("\(visit.likeCount)")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.espressoBrown)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.right")
                                        .font(.system(size: 18))
                                        .foregroundColor(.espressoBrown.opacity(0.7))
                                    Text("\(visit.commentCount)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.espressoBrown)
                                }
                            }
                            .padding(.vertical, 8)
                            
                            // Comments section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Comments")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.espressoBrown)
                                
                                if comments.isEmpty {
                                    Text("No comments yet")
                                        .font(.system(size: 14))
                                        .foregroundColor(.espressoBrown.opacity(0.6))
                                        .padding(.vertical, 8)
                                } else {
                                    ForEach(comments) { comment in
                                        CommentRow(comment: comment, dataManager: dataManager)
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
                            .foregroundColor(.inputText)
                            .tint(.mugshotMint)
                            .accentColor(.mugshotMint)
                            .padding(8)
                            .background(Color.inputBackground)
                            .cornerRadius(DesignSystem.smallCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                                    .stroke(Color.inputBorder, lineWidth: 1)
                            )
                            .focused($isCommentFocused)
                            .lineLimit(1...4)
                        
                        Button(action: {
                            addComment()
                        }) {
                            Text("Send")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.mugshotMint)
                        }
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(Color.creamWhite)
                }
            }
            .background(Color.creamWhite)
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
                                    .foregroundColor(.espressoBrown)
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Caption")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            TextField("Caption", text: $editableVisit.caption, axis: .vertical)
                                .lineLimit(3...6)
                                .foregroundColor(.inputText)
                                .tint(.mugshotMint)
                                .padding()
                                .background(Color.inputBackground)
                                .cornerRadius(DesignSystem.cornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                                        .stroke(Color.inputBorder, lineWidth: 1)
                                )
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            TextField("Notes", text: Binding(get: { editableVisit.notes ?? "" }, set: { editableVisit.notes = $0 }), axis: .vertical)
                                .lineLimit(3...8)
                                .foregroundColor(.inputText)
                                .tint(.mugshotMint)
                                .padding()
                                .background(Color.inputBackground)
                                .cornerRadius(DesignSystem.cornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                                        .stroke(Color.inputBorder, lineWidth: 1)
                                )
                        }
                        
                        // Visibility
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Visibility")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.espressoBrown)
                            Picker("", selection: $editableVisit.visibility) {
                                Text("Private").tag(VisitVisibility.private)
                                Text("Friends").tag(VisitVisibility.friends)
                                Text("Everyone").tag(VisitVisibility.everyone)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding()
                }
                .background(Color.creamWhite)
                .navigationTitle("Edit Visit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.espressoBrown)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            dataManager.updateVisit(editableVisit)
                            onSave(editableVisit)
                            dismiss()
                        }
                        .foregroundColor(.mugshotMint)
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
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.mugshotMint)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(user?.username.prefix(1).uppercased() ?? "U")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(user?.username ?? "user")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                
                MentionText(text: comment.text, mentions: comment.mentions)
                    .font(.system(size: 14))
                
                Text(timeAgoString(from: comment.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.6))
            }
            
            Spacer()
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

