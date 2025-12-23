//
//  FeedbackSubmitSheet.swift
//  testMugshot
//
//  Sheet for submitting new feedback
//

import SwiftUI

struct FeedbackSubmitSheet: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    let onPostCreated: (FeedbackPost) -> Void
    
    // State
    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedCategory: FeedbackCategory = .general
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case title
        case details
    }
    
    private let feedbackService = SupabaseFeedbackService.shared
    
    private var currentUserId: String? {
        dataManager.appData.supabaseUserId
    }
    
    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmitting
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.sectionVerticalGap) {
                    // Category selector
                    categorySection
                    
                    // Title field
                    titleSection
                    
                    // Body field
                    bodySection
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(DS.Typography.caption1())
                            .foregroundColor(DS.Colors.negativeChange)
                            .padding(.horizontal, DS.Spacing.pagePadding)
                    }
                    
                    // Guidelines
                    guidelinesSection
                }
                .padding(.vertical, DS.Spacing.md)
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Submit Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: submitFeedback) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Submit")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(canSubmit ? DS.Colors.primaryAccent : DS.Colors.textTertiary)
                    .disabled(!canSubmit)
                }
            }
            .onAppear {
                focusedField = .title
            }
        }
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Category")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            Text("What type of feedback do you have?")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
            
            DSDesignSegmentedControl(
                options: FeedbackCategory.allCases.map { $0.displayName },
                selectedIndex: Binding(
                    get: { FeedbackCategory.allCases.firstIndex(of: selectedCategory) ?? 0 },
                    set: { newIndex in
                        let newCategory = FeedbackCategory.allCases[newIndex]
                        if newCategory != selectedCategory {
                            hapticsManager.selectionChanged()
                            selectedCategory = newCategory
                        }
                    }
                )
            )
            
            // Category description
            categoryDescriptionCard
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private var categoryDescriptionCard: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: selectedCategory.icon)
                .font(.system(size: 24))
                .foregroundColor(categoryIconColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedCategory.displayName)
                    .font(DS.Typography.headline())
                    .foregroundColor(DS.Colors.textPrimary)
                
                Text(categoryDescription)
                    .font(DS.Typography.caption1())
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }
    
    private var categoryIconColor: Color {
        switch selectedCategory {
        case .bug: return DS.Colors.redAccent
        case .feature: return DS.Colors.blueAccent
        case .general: return DS.Colors.primaryAccent
        }
    }
    
    private var categoryDescription: String {
        switch selectedCategory {
        case .bug:
            return "Report something that isn't working correctly"
        case .feature:
            return "Suggest a new feature or improvement"
        case .general:
            return "Share general thoughts or comments"
        }
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Title")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            TextField("Brief summary of your feedback", text: $title)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textPrimary)
                .focused($focusedField, equals: .title)
                .padding(DS.Spacing.md)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(focusedField == .title ? DS.Colors.primaryAccent : DS.Colors.borderSubtle, lineWidth: 1)
                )
            
            Text("\(title.count)/100 characters")
                .font(DS.Typography.caption2())
                .foregroundColor(title.count > 100 ? DS.Colors.negativeChange : DS.Colors.textTertiary)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - Body Section
    
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Details")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            TextField("Describe your feedback in detail...", text: $bodyText, axis: .vertical)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textPrimary)
                .lineLimit(5...15)
                .focused($focusedField, equals: .details)
                .padding(DS.Spacing.md)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(focusedField == .details ? DS.Colors.primaryAccent : DS.Colors.borderSubtle, lineWidth: 1)
                )
                .frame(minHeight: 150)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - Guidelines Section
    
    private var guidelinesSection: some View {
        DSBaseCard(background: DS.Colors.primaryAccentSoftFill, showBorder: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 16))
                        .foregroundColor(DS.Colors.primaryAccent)
                    
                    Text("Tips for great feedback")
                        .font(DS.Typography.headline())
                        .foregroundColor(DS.Colors.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    guidelineRow("Be specific and descriptive")
                    guidelineRow("Include steps to reproduce bugs")
                    guidelineRow("One topic per submission")
                    guidelineRow("Check if it's already been posted")
                }
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    private func guidelineRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(DS.Colors.primaryAccent)
            
            Text(text)
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
    
    // MARK: - Submit
    
    private func submitFeedback() {
        guard let userId = currentUserId else {
            errorMessage = "You must be signed in to submit feedback"
            return
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Please enter a title"
            return
        }
        
        guard trimmedTitle.count <= 100 else {
            errorMessage = "Title must be 100 characters or less"
            return
        }
        
        guard !trimmedBody.isEmpty else {
            errorMessage = "Please enter details"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            defer {
                Task { @MainActor in
                    isSubmitting = false
                }
            }
            
            do {
                let newPost = try await feedbackService.createFeedbackPost(
                    userId: userId,
                    title: trimmedTitle,
                    body: trimmedBody,
                    category: selectedCategory
                )
                
                await MainActor.run {
                    hapticsManager.playSuccess()
                    onPostCreated(newPost)
                    dismiss()
                }
            } catch {
                print("[FeedbackSubmit] Error creating post: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Failed to submit feedback. Please try again."
                    hapticsManager.playError()
                }
            }
        }
    }
}





