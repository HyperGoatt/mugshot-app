//
//  EditVisitView.swift
//  testMugshot
//
//  View for editing an existing visit's details.
//

import SwiftUI

struct EditVisitView: View {
    @ObservedObject var dataManager: DataManager
    @Binding var visit: Visit
    @Environment(\.dismiss) private var dismiss
    @StateObject private var hapticsManager = HapticsManager.shared
    
    // Editing state
    @State private var editedDrinkType: DrinkType
    @State private var editedCustomDrinkType: String
    @State private var editedCaption: String
    @State private var editedNotes: String
    @State private var editedVisibility: VisitVisibility
    @State private var editedRatings: [String: Double]
    @State private var editedPosterPhotoIndex: Int
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let ratingCategories = ["Taste", "Ambiance", "Presentation", "Value"]
    
    init(dataManager: DataManager, visit: Binding<Visit>) {
        self.dataManager = dataManager
        self._visit = visit
        
        // Initialize editing state from visit
        _editedDrinkType = State(initialValue: visit.wrappedValue.drinkType)
        _editedCustomDrinkType = State(initialValue: visit.wrappedValue.customDrinkType ?? "")
        _editedCaption = State(initialValue: visit.wrappedValue.caption)
        _editedNotes = State(initialValue: visit.wrappedValue.notes ?? "")
        _editedVisibility = State(initialValue: visit.wrappedValue.visibility)
        _editedRatings = State(initialValue: visit.wrappedValue.ratings)
        _editedPosterPhotoIndex = State(initialValue: visit.wrappedValue.posterPhotoIndex)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Poster Photo Section (only if visit has photos)
                    if !visit.photos.isEmpty {
                        posterPhotoSection
                    }
                    
                    // Drink Type Section
                    drinkTypeSection
                    
                    // Caption Section
                    captionSection
                    
                    // Ratings Section
                    ratingsSection
                    
                    // Notes Section
                    notesSection
                    
                    // Visibility Section
                    visibilitySection
                }
                .padding(DS.Spacing.pagePadding)
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Edit Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .font(DS.Typography.subheadline(.semibold))
                    .foregroundColor(DS.Colors.primaryAccent)
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Poster Photo Section
    
    private var posterPhotoSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Cover Photo")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            Text("Tap to set as cover image")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(Array(visit.photos.enumerated()), id: \.offset) { index, photoPath in
                        posterPhotoThumbnail(photoPath: photoPath, index: index)
                    }
                }
            }
        }
    }
    
    private func posterPhotoThumbnail(photoPath: String, index: Int) -> some View {
        let isPoster = index == editedPosterPhotoIndex
        let remoteURL = visit.remotePhotoURLByKey[photoPath]
        
        return Button {
            hapticsManager.lightTap()
            editedPosterPhotoIndex = index
        } label: {
            ZStack(alignment: .topTrailing) {
                // Photo thumbnail
                Group {
                    if let remoteURL = remoteURL, let url = URL(string: remoteURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                placeholderImage
                            case .empty:
                                ProgressView()
                            @unknown default:
                                placeholderImage
                            }
                        }
                    } else if let cachedImage = PhotoCache.shared.retrieve(forKey: photoPath) {
                        Image(uiImage: cachedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        placeholderImage
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                
                // Poster badge
                if isPoster {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                        Text("Cover")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(DS.Colors.textOnMint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(DS.Colors.primaryAccent)
                    .clipShape(Capsule())
                    .offset(x: 4, y: -4)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isPoster ? DS.Colors.primaryAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(DS.Colors.cardBackgroundAlt)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(DS.Colors.iconSubtle)
            )
    }
    
    // MARK: - Drink Type Section
    
    private var drinkTypeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Drink Type")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(DrinkType.allCases, id: \.self) { type in
                        drinkTypeChip(type)
                    }
                }
            }
            
            if editedDrinkType == .other {
                TextField("Custom drink type", text: $editedCustomDrinkType)
                    .font(DS.Typography.bodyText)
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.cardBackgroundAlt)
                    .cornerRadius(DS.Radius.md)
            }
        }
    }
    
    private func drinkTypeChip(_ type: DrinkType) -> some View {
        let isSelected = editedDrinkType == type
        return Button {
            hapticsManager.lightTap()
            editedDrinkType = type
        } label: {
            Text(type.rawValue)
                .font(DS.Typography.subheadline(.medium))
                .foregroundColor(isSelected ? DS.Colors.textOnMint : DS.Colors.textPrimary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(isSelected ? DS.Colors.primaryAccent : DS.Colors.cardBackgroundAlt)
                .cornerRadius(DS.Radius.pill)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Caption Section
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Caption")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            TextEditor(text: $editedCaption)
                .font(DS.Typography.bodyText)
                .frame(minHeight: 100)
                .padding(DS.Spacing.sm)
                .background(DS.Colors.cardBackgroundAlt)
                .cornerRadius(DS.Radius.md)
        }
    }
    
    // MARK: - Ratings Section
    
    private var ratingsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Ratings")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            ForEach(ratingCategories, id: \.self) { category in
                ratingRow(for: category)
            }
        }
    }
    
    private func ratingRow(for category: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(category)
                .font(DS.Typography.subheadline(.medium))
                .foregroundColor(DS.Colors.textSecondary)
            
            HStack(spacing: DS.Spacing.xs) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        hapticsManager.lightTap()
                        editedRatings[category] = Double(value)
                    } label: {
                        Image(systemName: Double(value) <= (editedRatings[category] ?? 0) ? "star.fill" : "star")
                            .font(.system(size: 24))
                            .foregroundColor(Double(value) <= (editedRatings[category] ?? 0) ? DS.Colors.primaryAccent : DS.Colors.iconSubtle)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                if let rating = editedRatings[category], rating > 0 {
                    Text(String(format: "%.1f", rating))
                        .font(DS.Typography.subheadline(.semibold))
                        .foregroundColor(DS.Colors.textPrimary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Radius.md)
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.textTertiary)
                Text("Private Notes")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
            }
            
            TextEditor(text: $editedNotes)
                .font(DS.Typography.bodyText)
                .frame(minHeight: 80)
                .padding(DS.Spacing.sm)
                .background(DS.Colors.cardBackgroundAlt)
                .cornerRadius(DS.Radius.md)
            
            Text("Only visible to you")
                .font(DS.Typography.caption2())
                .foregroundColor(DS.Colors.textTertiary)
        }
    }
    
    // MARK: - Visibility Section
    
    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Visibility")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            HStack(spacing: DS.Spacing.sm) {
                ForEach([VisitVisibility.everyone, .friends, .private], id: \.self) { visibility in
                    visibilityChip(visibility)
                }
            }
        }
    }
    
    private func visibilityChip(_ visibility: VisitVisibility) -> some View {
        let isSelected = editedVisibility == visibility
        let icon: String = {
            switch visibility {
            case .everyone: return "globe"
            case .friends: return "person.2"
            case .private: return "lock"
            }
        }()
        
        return Button {
            hapticsManager.lightTap()
            editedVisibility = visibility
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(visibility.rawValue)
                    .font(DS.Typography.subheadline(.medium))
            }
            .foregroundColor(isSelected ? DS.Colors.textOnMint : DS.Colors.textPrimary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.primaryAccent : DS.Colors.cardBackgroundAlt)
            .cornerRadius(DS.Radius.pill)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Save Changes
    
    private func saveChanges() {
        print("[VisitEdit] Starting edit for visit id=\(visit.id)")
        
        isSaving = true
        
        // Calculate new overall score
        let nonZeroRatings = editedRatings.values.filter { $0 > 0 }
        let newOverallScore: Double
        if nonZeroRatings.isEmpty {
            newOverallScore = 0.0
        } else {
            newOverallScore = nonZeroRatings.reduce(0, +) / Double(nonZeroRatings.count)
        }
        
        // Update visit properties
        var updatedVisit = visit
        updatedVisit.drinkType = editedDrinkType
        updatedVisit.customDrinkType = editedDrinkType == .other ? editedCustomDrinkType : nil
        updatedVisit.caption = editedCaption
        updatedVisit.notes = editedNotes.isEmpty ? nil : editedNotes
        updatedVisit.visibility = editedVisibility
        updatedVisit.ratings = editedRatings
        updatedVisit.overallScore = newOverallScore
        updatedVisit.mentions = MentionParser.parseMentions(from: editedCaption)
        updatedVisit.posterPhotoIndex = editedPosterPhotoIndex
        
        // Update poster photo URL if index changed and photos exist
        if !visit.photos.isEmpty && editedPosterPhotoIndex < visit.photos.count {
            let posterPhotoPath = visit.photos[editedPosterPhotoIndex]
            if let remoteURL = visit.remotePhotoURLByKey[posterPhotoPath] {
                updatedVisit.posterPhotoURL = remoteURL
            }
        }
        
        Task {
            do {
                // Update in Supabase if we have a remote ID
                if visit.supabaseId != nil {
                    try await dataManager.updateVisitRemote(updatedVisit)
                }
                
                // Update local state
                await MainActor.run {
                    dataManager.updateVisit(updatedVisit)
                    visit = updatedVisit
                    isSaving = false
                    print("[VisitEdit] Saved changes for visit id=\(visit.id)")
                    hapticsManager.playSuccess()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                    print("[VisitEdit] Failed to save visit: \(error.localizedDescription)")
                }
            }
        }
    }
}

