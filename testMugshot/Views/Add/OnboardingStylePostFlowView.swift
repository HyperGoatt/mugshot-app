//
//  OnboardingStylePostFlowView.swift
//  testMugshot
//
//  New onboarding-style multi-step posting flow with ConcentricOnboarding animations
//

import SwiftUI
import PhotosUI
import MapKit

struct OnboardingStylePostFlowView: View {
    @ObservedObject var dataManager: DataManager
    var preselectedCafe: Cafe? = nil
    @EnvironmentObject var tabCoordinator: TabCoordinator
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var hapticsManager: HapticsManager
    
    @State private var currentStep = 0
    @State private var selectedCafe: Cafe?
    @State private var drinkType: DrinkType = .coffee
    @State private var customDrinkType: String = ""
    @State private var drinkSubtype: String = ""
    @State private var photoImages: [UIImage] = []
    @State private var posterPhotoIndex: Int = 0
    @State private var ratings: [String: Double] = [:]
    @State private var caption: String = ""
    @State private var notes: String = ""
    @State private var visibility: VisitVisibility = .everyone
    @State private var showPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isSaving = false
    @State private var savedVisit: Visit?
    @State private var showVisitDetail = false
    @State private var validationErrors: [String] = []
    @State private var showCustomizeRatings = false
    
    @StateObject private var searchService = MapSearchService()
    @State private var searchText = ""
    @State private var isCafeSearchActive = true
    
    private let defaultSearchRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    private var maxStepIndex: Int { 5 } // 0-5 = 6 steps
    
    var overallScore: Double {
        dataManager.appData.ratingTemplate.calculateOverallScore(ratings: ratings)
    }
    
    var body: some View {
        ZStack {
            // Full screen ConcentricOnboardingView with animations
            PostFlowConcentricViewFixed(
                pageContents: createPages(),
                currentStep: $currentStep,
                canProceed: canProceedToNext,
                duration: 0.8,
                nextIcon: "arrow.right",
                onLastPageNext: {
                    saveVisit()
                },
                onPageChange: { index in
                    hapticsManager.playImpact(style: .light)
                }
            )
            
            // Cancel button - always visible in top leading, respecting safe area
            GeometryReader { geometry in
                VStack {
                    HStack {
                        Button(action: {
                            hapticsManager.playImpact(style: .medium)
                            resetForm()
                            tabCoordinator.selectedTab = 0
                            dismiss()
                        }) {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Cancel")
                                    .font(DS.Typography.bodyText)
                            }
                            .foregroundColor(DS.Colors.textPrimary)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(DS.Colors.cardBackground.opacity(0.9))
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                        }
                        .padding(.leading, DS.Spacing.pagePadding)
                        
                        Spacer()
                    }
                    .padding(.top, geometry.safeAreaInsets.top + DS.Spacing.sm + 30)
                    
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showCustomizeRatings) {
            CustomizeRatingsView(
                dataManager: dataManager,
                isPresented: $showCustomizeRatings
            )
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotos) { oldValue, newValue in
            loadPhotos(from: newValue)
        }
        .onAppear {
            if let cafe = preselectedCafe {
                selectedCafe = cafe
                isCafeSearchActive = false
            }
            initializeRatings()
        }
        .fullScreenCover(isPresented: $showVisitDetail, onDismiss: {
            resetForm()
            tabCoordinator.switchToFeed()
            dismiss()
        }) {
            if let visit = savedVisit {
                NavigationStack {
                    VisitDetailView(dataManager: dataManager, visit: visit, showsDismissButton: true)
                }
            }
        }
    }
    
    private func createPages() -> [(view: AnyView, background: Color)] {
        return [
            // Step 1: Cafe Selection
            (AnyView(PostFlowStep1_Cafe(
                selectedCafe: $selectedCafe,
                searchText: $searchText,
                isSearchActive: $isCafeSearchActive,
                searchService: searchService,
                dataManager: dataManager,
                searchRegion: defaultSearchRegion,
                preselectedCafe: preselectedCafe
            )), DS.Colors.mintSoftFill),
            
            // Step 2: Drink Type
            (AnyView(PostFlowStep2_Drink(
                drinkType: $drinkType,
                customDrinkType: $customDrinkType,
                drinkSubtype: $drinkSubtype
            )), DS.Colors.blueSoftFill),
            
            // Step 3: Photos
            (AnyView(PostFlowStep3_Photos(
                photoImages: $photoImages,
                posterIndex: $posterPhotoIndex,
                showPhotoPicker: $showPhotoPicker,
                selectedPhotos: $selectedPhotos,
                onPhotosChanged: { loadPhotos(from: $0) }
            )), DS.Colors.mintSoftFill),
            
            // Step 4: Ratings
            (AnyView(PostFlowStep4_Ratings(
                dataManager: dataManager,
                ratings: $ratings,
                overallScore: overallScore,
                onCustomizeTapped: { showCustomizeRatings = true }
            )), DS.Colors.blueSoftFill),
            
            // Step 5: Caption & Notes
            (AnyView(PostFlowStep5_Caption(
                caption: $caption,
                notes: $notes,
                visibility: $visibility
            )), DS.Colors.mintSoftFill),
            
            // Step 6: Review & Submit
            (AnyView(PostFlowStep6_Review(
                cafe: selectedCafe,
                drinkType: drinkType,
                customDrinkType: customDrinkType,
                photoCount: photoImages.count,
                overallScore: overallScore,
                caption: caption,
                isSaving: isSaving,
                validationErrors: validationErrors
            )), DS.Colors.blueSoftFill)
        ]
    }
    
    
    private var canProceedToNext: Bool {
        switch currentStep {
        case 0: return selectedCafe != nil
        case 1: return (drinkType != .other || !customDrinkType.isEmpty) && !drinkSubtype.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2: return true // Photos are optional
        case 3: return true // Ratings are optional
        case 4: return !caption.isEmpty
        case 5: return true // Review step
        default: return true
        }
    }
    
    private func initializeRatings() {
        for category in dataManager.appData.ratingTemplate.categories {
            if ratings[category.name] == nil {
                ratings[category.name] = 0.0
            }
        }
    }
    
    private func loadPhotos(from items: [PhotosPickerItem]) {
        Task {
            var loadedImages: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loadedImages.append(image)
                }
            }
            await MainActor.run {
                photoImages = loadedImages
                if !photoImages.isEmpty && posterPhotoIndex >= photoImages.count {
                    posterPhotoIndex = 0
                }
            }
        }
    }
    
    private func resetForm() {
        selectedCafe = nil
        drinkType = .coffee
        customDrinkType = ""
        drinkSubtype = ""
        photoImages = []
        posterPhotoIndex = 0
        ratings = [:]
        caption = ""
        notes = ""
        visibility = .everyone
        validationErrors = []
        searchText = ""
        searchService.cancelSearch()
        savedVisit = nil
        showVisitDetail = false
        currentStep = 0
        isCafeSearchActive = true
        initializeRatings()
    }
    
    private func saveVisit() {
        // Haptic: confirm save button tap
        hapticsManager.mediumTap()
        Task {
            await saveVisitAsync()
        }
    }
    
    @MainActor
    private func saveVisitAsync() async {
        validationErrors = []
        
        guard let cafe = selectedCafe else {
            validationErrors.append("Please select a Cafe location")
            currentStep = 0
            hapticsManager.playError()
            return
        }
        
        guard drinkType != .other || !customDrinkType.isEmpty else {
            validationErrors.append("Please specify a custom drink type")
            currentStep = 1
            hapticsManager.playError()
            return
        }
        
        guard !drinkSubtype.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationErrors.append("Please specify what drink you got")
            currentStep = 1
            hapticsManager.playError()
            return
        }
        
        guard !caption.isEmpty else {
            validationErrors.append("Please write a caption")
            currentStep = 4
            hapticsManager.playError()
            return
        }
        
        if dataManager.appData.currentUser == nil {
            if let username = dataManager.appData.currentUserUsername {
                let newUser = User(
                    username: username,
                    displayName: dataManager.appData.currentUserDisplayName,
                    location: dataManager.appData.currentUserLocation ?? "",
                    profileImageID: dataManager.appData.currentUserProfileImageId,
                    bannerImageID: dataManager.appData.currentUserBannerImageId,
                    bio: dataManager.appData.currentUserBio ?? "",
                    instagramURL: dataManager.appData.currentUserInstagramHandle,
                    websiteURL: dataManager.appData.currentUserWebsite,
                    favoriteDrink: dataManager.appData.currentUserFavoriteDrink
                )
                dataManager.setCurrentUser(newUser)
            } else {
                validationErrors.append("Please complete your profile setup")
                hapticsManager.playError()
                return
            }
        }
        
        let mentions = MentionParser.parseMentions(from: caption)
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            let visit = try await dataManager.createVisit(
                cafe: cafe,
                drinkType: drinkType,
                customDrinkType: drinkType == .other ? customDrinkType : nil,
                drinkSubtype: drinkSubtype.isEmpty ? nil : drinkSubtype,
                caption: caption,
                notes: notes.isEmpty ? nil : notes,
                photoImages: photoImages,
                posterPhotoIndex: posterPhotoIndex,
                ratings: ratings,
                overallScore: overallScore,
                visibility: visibility,
                mentions: mentions
            )
            savedVisit = visit
            // Haptic: visit save success
            hapticsManager.playSuccess()
            showVisitDetail = true
        } catch {
            // Haptic: visit save error
            hapticsManager.playError()
            if let supabaseError = error as? SupabaseError {
                validationErrors.append(supabaseError.userFriendlyDescription)
            } else {
                validationErrors.append("Something went wrong saving your visit. Please try again.")
            }
        }
    }
}

// MARK: - Step 1: Cafe Selection

struct PostFlowStep1_Cafe: View {
    @Binding var selectedCafe: Cafe?
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    @ObservedObject var searchService: MapSearchService
    @ObservedObject var dataManager: DataManager
    let searchRegion: MKCoordinateRegion
    let preselectedCafe: Cafe?
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Icon
            Image(systemName: "location.fill")
                .font(.system(size: 80))
                .foregroundStyle(DS.Colors.primaryAccent)
                .padding(.bottom, DS.Spacing.lg)
            
            // Title
            Text("Where did you visit?")
                .font(DS.Typography.title1(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Subtitle
            Text("Search for the cafe you visited")
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
            
            // Cafe search UI
            DSBaseCard {
                CafeLocationSection(
                    selectedCafe: $selectedCafe,
                    searchText: $searchText,
                    isSearchActive: $isSearchActive,
                    searchService: searchService,
                    dataManager: dataManager,
                    searchRegion: searchRegion
                )
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Selected cafe preview
            if let cafe = selectedCafe {
                DSBaseCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DS.Colors.primaryAccent)
                            Text("Selected")
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                        
                        Text(cafe.name)
                            .font(DS.Typography.cardTitle)
                            .foregroundColor(DS.Colors.textPrimary)
                        
                        if !cafe.address.isEmpty {
                            Text(cafe.address)
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
            
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xxl)
        .onAppear {
            if let cafe = preselectedCafe {
                selectedCafe = cafe
                isSearchActive = false
            }
        }
    }
}

// MARK: - Step 2: Drink Type

struct PostFlowStep2_Drink: View {
    @Binding var drinkType: DrinkType
    @Binding var customDrinkType: String
    @Binding var drinkSubtype: String
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Icon
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 80))
                .foregroundStyle(DS.Colors.primaryAccent)
                .padding(.bottom, DS.Spacing.lg)
            
            // Title
            Text("What did you drink?")
                .font(DS.Typography.title1(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Subtitle
            Text("Select your drink type")
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
            
            // Drink type selection
            DSBaseCard {
                DrinkTypeSection(
                    drinkType: $drinkType,
                    customDrinkType: $customDrinkType
                )
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Drink subtype field
            DrinkSubtypeField(
                drinkType: drinkType,
                drinkSubtype: $drinkSubtype
            )
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Selected drink preview
            if drinkType != .other || !customDrinkType.isEmpty {
                DSBaseCard {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DS.Colors.primaryAccent)
                        Text(drinkType == .other ? customDrinkType : drinkType.rawValue)
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
            
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xxl)
    }
}

// MARK: - Step 3: Photos

struct PostFlowStep3_Photos: View {
    @Binding var photoImages: [UIImage]
    @Binding var posterIndex: Int
    @Binding var showPhotoPicker: Bool
    @Binding var selectedPhotos: [PhotosPickerItem]
    let onPhotosChanged: ([PhotosPickerItem]) -> Void
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Icon
            Image(systemName: "photo.fill")
                .font(.system(size: 80))
                .foregroundStyle(DS.Colors.primaryAccent)
                .padding(.bottom, DS.Spacing.lg)
            
            // Title
            Text("Add photos")
                .font(DS.Typography.title1(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Subtitle
            Text("Photos are optional, but they make your visit more engaging")
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
            
            // Photo uploader
            PhotoUploaderCard(
                images: photoImages,
                posterIndex: posterIndex,
                maxPhotos: 10,
                onAddTapped: { showPhotoPicker = true },
                onRemove: { index in
                    photoImages.remove(at: index)
                    if posterIndex >= photoImages.count {
                        posterIndex = max(0, photoImages.count - 1)
                    }
                },
                onSetPoster: { index in
                    posterIndex = index
                }
            )
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Photo count info
            if photoImages.count > 0 {
                DSBaseCard {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DS.Colors.primaryAccent)
                        Text("\(photoImages.count) photo\(photoImages.count == 1 ? "" : "s") added")
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textPrimary)
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
            }
            
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xxl)
    }
}

// MARK: - Step 4: Ratings

struct PostFlowStep4_Ratings: View {
    @ObservedObject var dataManager: DataManager
    @Binding var ratings: [String: Double]
    let overallScore: Double
    let onCustomizeTapped: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                Spacer()
                    .frame(height: DS.Spacing.xxl)
                
                // Icon
                Image(systemName: "star.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(DS.Colors.primaryAccent)
                    .padding(.bottom, DS.Spacing.lg)
                
                // Title
                Text("Rate your visit")
                    .font(DS.Typography.title1(.bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Subtitle
                Text("How was your experience?")
                    .font(DS.Typography.bodyText)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding * 2)
                
                // Ratings card
                RatingsCard(
                    dataManager: dataManager,
                    ratings: $ratings,
                    overallScore: overallScore,
                    onCustomizeTapped: onCustomizeTapped
                )
                .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Overall score preview
                if overallScore > 0 {
                    DSBaseCard {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DS.Colors.primaryAccent)
                            Text("Overall: \(String(format: "%.1f", overallScore)) / 5.0")
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textPrimary)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                } else {
                    Text("Ratings are optional")
                        .font(DS.Typography.caption1())
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.top, DS.Spacing.sm)
                }
                
                Spacer()
                    .frame(height: DS.Spacing.xxl * 3) // Extra space for bottom button
            }
        }
    }
}

// MARK: - Step 5: Caption & Notes

struct PostFlowStep5_Caption: View {
    @Binding var caption: String
    @Binding var notes: String
    @Binding var visibility: VisitVisibility
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                Spacer()
                    .frame(height: DS.Spacing.xxl)
                
                // Icon
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(DS.Colors.primaryAccent)
                    .padding(.bottom, DS.Spacing.lg)
                
                // Title
                Text("Tell your story")
                    .font(DS.Typography.title1(.bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Subtitle
                Text("Share what made this visit special")
                    .font(DS.Typography.bodyText)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding * 2)
                
                // Caption & Notes
                CaptionNotesSection(
                    caption: $caption,
                    notes: $notes,
                    captionLimit: 200,
                    notesLimit: 200
                )
                .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Visibility selector
                VisibilitySelector(visibility: $visibility)
                    .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Caption preview
                if !caption.isEmpty {
                    DSBaseCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("Preview:")
                                .font(DS.Typography.caption1())
                                .foregroundColor(DS.Colors.textSecondary)
                            Text(caption)
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.textPrimary)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                }
                
                Spacer()
                    .frame(height: DS.Spacing.xxl * 3) // Extra space for bottom button
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard when tapping outside text fields
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Step 6: Review & Submit

struct PostFlowStep6_Review: View {
    let cafe: Cafe?
    let drinkType: DrinkType
    let customDrinkType: String
    let photoCount: Int
    let overallScore: Double
    let caption: String
    let isSaving: Bool
    let validationErrors: [String]
    
    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                Spacer()
                    .frame(height: DS.Spacing.xxl)
                
                // Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(DS.Colors.primaryAccent)
                    .padding(.bottom, DS.Spacing.lg)
                
                // Title
                Text("Review your visit")
                    .font(DS.Typography.title1(.bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Subtitle
                Text("Everything looks good? Tap 'Post Visit' to share")
                    .font(DS.Typography.bodyText)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.pagePadding * 2)
                
                // Review summary card
                DSBaseCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        if let cafe = cafe {
                            ReviewRow(
                                icon: "location.fill",
                                label: "Cafe",
                                value: cafe.name
                            )
                            
                            if !cafe.address.isEmpty {
                                Text(cafe.address)
                                    .font(DS.Typography.caption1())
                                    .foregroundColor(DS.Colors.textSecondary)
                                    .padding(.leading, 28) // Align with icon
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, DS.Spacing.xs)
                        
                        ReviewRow(
                            icon: "cup.and.saucer.fill",
                            label: "Drink",
                            value: drinkType == .other ? customDrinkType : drinkType.rawValue
                        )
                        
                        if photoCount > 0 {
                            Divider()
                                .padding(.vertical, DS.Spacing.xs)
                            
                            ReviewRow(
                                icon: "photo.fill",
                                label: "Photos",
                                value: "\(photoCount) photo\(photoCount == 1 ? "" : "s")"
                            )
                        }
                        
                        if overallScore > 0 {
                            Divider()
                                .padding(.vertical, DS.Spacing.xs)
                            
                            ReviewRow(
                                icon: "star.fill",
                                label: "Overall Score",
                                value: String(format: "%.1f / 5.0", overallScore)
                            )
                        }
                        
                        if !caption.isEmpty {
                            Divider()
                                .padding(.vertical, DS.Spacing.xs)
                            
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                HStack(spacing: DS.Spacing.sm) {
                                    Image(systemName: "text.bubble.fill")
                                        .foregroundColor(DS.Colors.primaryAccent)
                                        .frame(width: 20)
                                    Text("Caption")
                                        .font(DS.Typography.bodyText)
                                        .foregroundColor(DS.Colors.textSecondary)
                                }
                                
                                Text(caption)
                                    .font(DS.Typography.bodyText)
                                    .foregroundColor(DS.Colors.textPrimary)
                                    .padding(.leading, 28) // Align with icon
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.pagePadding)
                
                // Validation errors
                if !validationErrors.isEmpty {
                    DSBaseCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            ForEach(validationErrors, id: \.self) { error in
                                HStack(spacing: DS.Spacing.sm) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(DS.Colors.negativeChange)
                                    Text("• \(error)")
                                        .font(DS.Typography.bodyText)
                                        .foregroundColor(DS.Colors.negativeChange)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                }
                
                // Saving indicator
                if isSaving {
                    HStack(spacing: DS.Spacing.sm) {
                        ProgressView()
                            .tint(DS.Colors.primaryAccent)
                        Text("Posting your visit...")
                            .font(DS.Typography.bodyText)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    .padding(DS.Spacing.pagePadding)
                }
                
                Spacer()
                    .frame(height: DS.Spacing.xxl * 3) // Extra space for bottom button
            }
        }
    }
}

// MARK: - Review Row Helper

struct ReviewRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(DS.Colors.primaryAccent)
                .frame(width: 20)
            
            Text(label)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textPrimary)
        }
    }
}

// MARK: - PostFlowConcentricViewFixed

struct PostFlowConcentricViewFixed: View {
    let pageContents: [(view: AnyView, background: Color)]
    @Binding var currentStep: Int
    let canProceed: Bool
    let duration: Double
    let nextIcon: String
    let onLastPageNext: () -> Void
    let onPageChange: (Int) -> Void
    
    var body: some View {
        ConcentricOnboardingView(pageContents: pageContents)
            .duration(duration)
            .nextIcon(nextIcon)
            .shouldAllowNavigation {
                // Validate before allowing navigation - prevents navigation if false
                canProceed
            }
            .didChangeCurrentPage { index in
                currentStep = index
                onPageChange(index)
            }
            .insteadOfCyclingToFirstPage {
                // On last page when pressing next, save the visit instead of cycling
                onLastPageNext()
            }
    }
}




