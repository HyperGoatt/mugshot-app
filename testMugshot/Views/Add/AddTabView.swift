//
//  AddTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import PhotosUI
import MapKit
import CoreLocation

// MARK: - LogVisitView Audit
//
// - Ratings UI:
//   Defined once in `RatingsSection` / `RatingCategoryRow` at the bottom of this file.
//   Logic is sound (per-category stars + overall score) but the view is tightly coupled
//   to `LogVisitView` and not reusable elsewhere.
//
// - Spacing & padding:
//   Root form uses a hard-coded `VStack(spacing: 24)` and mixes design-system spacing
//   (`DS.Spacing.*`) with magic numbers (24, 40, 3...8 line limits, etc.).
//   Section cards each manage their own padding and vertical spacing, leading to
//   inconsistent gaps between sections.
//
// - Colors, fonts, corner radii:
//   Most text and backgrounds correctly use `DS.Colors` and `DS.Typography`, but
//   some elements (e.g. dashed photo placeholder, sliders, list rows) hard-code
//   sizes and layout instead of leaning on shared card patterns.
//   Multiple sections create their own card styling (`background + cornerRadius +
//   dsCardShadow()`), which duplicates what `DSBaseCard` already provides.
//
// - Wiring / business logic:
//   * Photo picking: `selectedPhotos` + `photoImages` are driven by `PhotosPicker`
//     and `loadPhotos(from:)`, then converted into string paths and cached in
//     `saveVisit()`. Poster photo index is tracked via `posterPhotoIndex`.
//   * Ratings: `ratings: [String: Double]` is initialized from
//     `dataManager.appData.ratingTemplate` and updated through `RatingCategoryRow`
//     star taps; `overallScore` is computed via `ratingTemplate.calculateOverallScore`.
//   * Visibility: `visibility: VisitVisibility` is bound to `VisibilitySection`,
//     which toggles between `.private`, `.friends`, `.everyone`.
//   * Caption/Notes: `caption` and `notes` bindings are wired into `CaptionSection`
//     and `NotesSection`; caption is required, notes are optional. Caption already
//     enforces a 200‑char limit but notes do not.
//   * Save Visit: `saveVisit()` performs validation (cafe selection, drink type,
//     caption present, user ID resolution), persists a `Visit` through
//     `dataManager.addVisit`, then presents `VisitDetailView`. This logic should
//     remain untouched during the UI refactor.

struct AddTabView: View {
    @ObservedObject var dataManager: DataManager
    var preselectedCafe: Cafe? = nil
    
    var body: some View {
        LogVisitView(dataManager: dataManager, preselectedCafe: preselectedCafe)
    }
}

struct LogVisitView: View {
    @ObservedObject var dataManager: DataManager
    var preselectedCafe: Cafe? = nil
    @EnvironmentObject var tabCoordinator: TabCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedCafe: Cafe?
    @State private var isCafeSearchActive = false
    @State private var drinkType: DrinkType = .coffee
    @State private var customDrinkType: String = ""
    @State private var caption: String = ""
    @State private var notes: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var posterPhotoIndex: Int = 0
    @State private var ratings: [String: Double] = [:]
    @State private var visibility: VisitVisibility = .everyone
    @State private var showCustomizeRatings = false
    @State private var showPhotoPicker = false
    @State private var validationErrors: [String] = []
    @State private var isSaving = false
    @State private var savedVisit: Visit?
    @State private var showVisitDetail = false
    
    @StateObject private var searchService = MapSearchService()
    @State private var searchText = ""
    @State private var scrollToTop = false
    
    // Default region for search (can be improved with location manager later)
    private let defaultSearchRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var overallScore: Double {
        dataManager.appData.ratingTemplate.calculateOverallScore(ratings: ratings)
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .background(DS.Colors.screenBackground)
                .safeAreaInset(edge: .bottom) {
                    SaveVisitButton(
                        isEnabled: canSave,
                        isLoading: isSaving,
                        onTap: saveVisit
                    )
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            resetForm()
                            // Switch to Map tab
                            tabCoordinator.selectedTab = 0
                            // If we're in a sheet (from Saved/Map), dismiss it
                            dismiss()
                        }
                        .foregroundColor(DS.Colors.textPrimary)
                    }
                }
                .toolbarBackground(DS.Colors.appBarBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
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
                    }
                    initializeRatings()
                }
                .fullScreenCover(isPresented: $showVisitDetail, onDismiss: {
                    // When visit detail is dismissed, switch to Feed tab and reset form
                    resetForm()
                    
                    // Switch to Feed tab
                    tabCoordinator.switchToFeed()
                    
                    // If we're in a sheet (from Saved/Map), dismiss it
                    dismiss()
                }) {
                    if let visit = savedVisit {
                        NavigationStack {
                            VisitDetailView(dataManager: dataManager, visit: visit, showsDismissButton: true)
                        }
                    }
                }
        }
    }
    
    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                formContent
                    .padding(.horizontal, DS.Spacing.pagePadding)
                    .padding(.bottom, DS.Spacing.xxl) // space above bottom button
            }
            .onChange(of: scrollToTop) { _, shouldScroll in
                if shouldScroll {
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                    scrollToTop = false
                }
            }
        }
    }
    
    private var formContent: some View {
        VStack(spacing: DS.Spacing.sectionVerticalGap) {
            // Header section (inside scrollable content)
            VStack(alignment: .leading, spacing: 8) {
                Text("Log a Visit")
                    .font(DS.Typography.screenTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Text("Share your sip and what made it special.")
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .id("top")
            .padding(.top, DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        
            // Cafe Location
            FormSectionCard(title: "Cafe Location") {
                CafeLocationSection(
                    selectedCafe: $selectedCafe,
                    searchText: $searchText,
                    isSearchActive: $isCafeSearchActive,
                    searchService: searchService,
                    dataManager: dataManager,
                    searchRegion: defaultSearchRegion
                )
            }
            
            // Drink Type
            FormSectionCard(title: "Drink Type") {
                DrinkTypeSection(
                    drinkType: $drinkType,
                    customDrinkType: $customDrinkType
                )
            }
            
            // Photos
            PhotoUploaderCard(
                images: photoImages,
                posterIndex: posterPhotoIndex,
                maxPhotos: 10,
                onAddTapped: { showPhotoPicker = true },
                onRemove: { index in
                    photoImages.remove(at: index)
                    if posterPhotoIndex >= photoImages.count {
                        posterPhotoIndex = max(0, photoImages.count - 1)
                    }
                },
                onSetPoster: { index in
                    posterPhotoIndex = index
                }
            )
            
            // Ratings
            RatingsCard(
                dataManager: dataManager,
                ratings: $ratings,
                overallScore: overallScore,
                onCustomizeTapped: { showCustomizeRatings = true }
            )
            
            // Caption & Notes
            CaptionNotesSection(
                caption: $caption,
                notes: $notes,
                captionLimit: 200,
                notesLimit: 200
            )
            
            // Visibility
            VisibilitySelector(visibility: $visibility)
            
            // Validation errors
            if !validationErrors.isEmpty {
                DSBaseCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        ForEach(validationErrors, id: \.self) { error in
                            Text("• \(error)")
                                .font(DS.Typography.bodyText)
                                .foregroundColor(DS.Colors.negativeChange)
                        }
                    }
                }
            }
            
        }
    }
    
    private var canSave: Bool {
        selectedCafe != nil &&
        (drinkType != .other || !customDrinkType.isEmpty) &&
        !caption.isEmpty
    }
    
    private func resetForm() {
        // Reset all form fields
        selectedCafe = nil
        isCafeSearchActive = false
        drinkType = .coffee
        customDrinkType = ""
        caption = ""
        notes = ""
        selectedPhotos = []
        photoImages = []
        posterPhotoIndex = 0
        ratings = [:]
        visibility = .everyone
        validationErrors = []
        searchText = ""
        searchService.cancelSearch()
        savedVisit = nil
        showVisitDetail = false
        
        // Re-initialize ratings
        initializeRatings()
        
        // Scroll to top
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollToTop = true
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
    
    private func saveVisit() {
        Task {
            await saveVisitAsync()
        }
    }
    
    @MainActor
    private func saveVisitAsync() async {
        validationErrors = []
        
        // Validate
        guard let cafe = selectedCafe else {
            validationErrors.append("Please select a Cafe location")
            return
        }
        
        guard drinkType != .other || !customDrinkType.isEmpty else {
            validationErrors.append("Please specify a custom drink type")
            return
        }
        
        guard !caption.isEmpty else {
            validationErrors.append("Please write a caption")
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
                return
            }
        }
        
        // Parse mentions from caption
        let mentions = MentionParser.parseMentions(from: caption)
        
        isSaving = true
        defer { isSaving = false }
        
        do {
            let visit = try await dataManager.createVisit(
                cafe: cafe,
                drinkType: drinkType,
                customDrinkType: drinkType == .other ? customDrinkType : nil,
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
            showVisitDetail = true
        } catch {
            // Debug logging for visit save errors
            print("❌ [AddTabView] Save visit error: \(error)")
            
            // Check for specific error types to provide better user feedback
            if let supabaseError = error as? SupabaseError {
                switch supabaseError {
                case .invalidSession:
                    print("❌ [AddTabView] Invalid session - user may need to sign in again")
                    validationErrors.append("Your session has expired. Please sign in again.")
                case .server(let status, let message):
                    print("❌ [AddTabView] Server error - status: \(status), message: \(message ?? "nil")")
                    if status == 401 || status == 403 {
                        validationErrors.append("You don't have permission to create visits. Please sign in again.")
                    } else if status == 400 {
                        validationErrors.append("Invalid visit data. Please check your inputs and try again.")
                    } else {
                        validationErrors.append("Something went wrong saving your visit. Please try again.")
                    }
                case .network(let message):
                    print("❌ [AddTabView] Network error: \(message)")
                    validationErrors.append("Network error. Please check your connection and try again.")
                case .decoding(let message):
                    print("❌ [AddTabView] Decoding error: \(message)")
                    validationErrors.append("Something went wrong saving your visit. Please try again.")
                }
            } else if let decodingError = error as? DecodingError {
                print("❌ [AddTabView] DecodingError details:")
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("  Type mismatch: expected \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("  Context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("  Value not found: expected \(type), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .keyNotFound(let key, let context):
                    print("  Key not found: \(key.stringValue), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("  Data corrupted: \(context.debugDescription)")
                    if let underlyingError = context.underlyingError {
                        print("  Underlying error: \(underlyingError)")
                    }
                @unknown default:
                    print("  Unknown decoding error")
                }
                validationErrors.append("Something went wrong saving your visit. Please try again.")
            } else {
                print("❌ [AddTabView] Unexpected error type: \(type(of: error))")
                validationErrors.append("Something went wrong saving your visit. Please try again.")
            }
        }
    }
}

// MARK: - Cafe Location Section

struct CafeLocationSection: View {
    @Binding var selectedCafe: Cafe?
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    @ObservedObject var searchService: MapSearchService
    @ObservedObject var dataManager: DataManager
    let searchRegion: MKCoordinateRegion
    
    var body: some View {
        DSBaseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cafe Location")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.Colors.textPrimary)
                
                if isSearchActive {
                    // Inline search mode
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(DS.Colors.textSecondary)
                                
                                TextField("Search cafes...", text: $searchText)
                                    .foregroundColor(DS.Colors.textPrimary)
                                    .onChange(of: searchText) { oldValue, newValue in
                                        if !newValue.isEmpty {
                                            searchService.search(query: newValue, region: searchRegion)
                                        } else {
                                            searchService.cancelSearch()
                                        }
                                    }
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                        searchService.cancelSearch()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(DS.Colors.iconSubtle)
                                    }
                                }
                            }
                            .padding(DS.Spacing.md)
                            .background(DS.Colors.cardBackground)
                            .cornerRadius(DS.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                            )
                            
                            Button("Cancel") {
                                searchText = ""
                                searchService.cancelSearch()
                                isSearchActive = false
                            }
                            .foregroundColor(DS.Colors.textPrimary)
                        }
                        
                        // Search results dropdown
                        if !searchText.isEmpty {
                            CafeSearchResultsDropdown(
                                searchService: searchService,
                                dataManager: dataManager,
                                searchText: $searchText,
                                selectedCafe: $selectedCafe,
                                isSearchActive: $isSearchActive
                            )
                        }
                    }
                } else {
                    // Display selected cafe or search prompt
                    Button(action: {
                        isSearchActive = true
                    }) {
                        HStack {
                            if let cafe = selectedCafe {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(DS.Colors.primaryAccent)
                                            .font(DS.Typography.caption1())
                                        Text(cafe.name)
                                            .font(DS.Typography.bodyText)
                                            .foregroundColor(DS.Colors.textPrimary)
                                    }
                                    
                                    if !cafe.address.isEmpty {
                                        Text(cafe.address)
                                            .font(DS.Typography.bodyText)
                                            .foregroundColor(DS.Colors.textSecondary)
                                    }
                                }
                            } else {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(DS.Colors.textSecondary)
                                    Text("Search for a Cafe…")
                                        .foregroundColor(DS.Colors.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(DS.Colors.iconSubtle)
                        }
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.cardBackground)
                        .cornerRadius(DS.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Cafe Search Results Dropdown

struct CafeSearchResultsDropdown: View {
    @ObservedObject var searchService: MapSearchService
    @ObservedObject var dataManager: DataManager
    @Binding var searchText: String
    @Binding var selectedCafe: Cafe?
    @Binding var isSearchActive: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if searchService.isSearching {
                HStack {
                    ProgressView()
                        .padding(DS.Spacing.md)
                    Spacer()
                }
                .background(DS.Colors.cardBackground)
            } else if let error = searchService.searchError {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(DS.Colors.iconSubtle)
                    Text(error)
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.cardBackground)
            } else if searchService.searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    Text("No results found")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.cardBackground)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(searchService.searchResults.enumerated()), id: \.offset) { index, mapItem in
                            Button(action: {
                                let cafe = dataManager.findOrCreateCafe(from: mapItem)
                                selectedCafe = cafe
                                searchText = ""
                                searchService.cancelSearch()
                                isSearchActive = false
                            }) {
                                DSBaseCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                            Text(mapItem.name ?? "Unknown")
                                                .font(DS.Typography.bodyText)
                                                .foregroundColor(DS.Colors.textPrimary)
                                            
                                            if let address = formatAddress(from: mapItem.placemark), !address.isEmpty {
                                                Text(address)
                                                    .font(DS.Typography.bodyText)
                                                    .foregroundColor(DS.Colors.textSecondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            if index < searchService.searchResults.count - 1 {
                                Divider()
                                    .background(DS.Colors.dividerSubtle)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(DS.Colors.cardBackground)
            }
        }
        .cornerRadius(DS.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
        .dsCardShadow()
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String? {
        var components: [String] = []
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

// MARK: - Drink Type Section

struct DrinkTypeSection: View {
    @Binding var drinkType: DrinkType
    @Binding var customDrinkType: String
    @State private var showDropdown = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drink Type")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: 0) {
                // Main button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDropdown.toggle()
                    }
                }) {
                    HStack {
                        Text(showDropdown ? "Select drink type" : (drinkType == .other && !customDrinkType.isEmpty ? customDrinkType : (drinkType == .other && customDrinkType.isEmpty ? "Select drink type" : drinkType.rawValue)))
                            .foregroundColor(showDropdown || (drinkType == .other && customDrinkType.isEmpty) ? DS.Colors.textSecondary : DS.Colors.textPrimary)
                        Spacer()
                        Image(systemName: showDropdown ? "chevron.up" : "chevron.down")
                            .foregroundColor(DS.Colors.iconSubtle)
                            .font(DS.Typography.caption2())
                    }
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.cardBackground)
                    .cornerRadius(DS.Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Dropdown menu
                if showDropdown {
                    VStack(spacing: 0) {
                        ForEach(DrinkType.allCases, id: \.self) { type in
                            Button(action: {
                                drinkType = type
                                if type != .other {
                                    customDrinkType = ""
                                }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showDropdown = false
                                }
                            }) {
                                HStack {
                                    Text(type.rawValue)
                                        .foregroundColor(DS.Colors.textPrimary)
                                    Spacer()
                                    if drinkType == type {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(DS.Colors.primaryAccent)
                                    }
                                }
                                .padding(DS.Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(drinkType == type ? DS.Colors.primaryAccentSoftFill : DS.Colors.cardBackground)
                            }
                            .buttonStyle(.plain)
                            
                            if type != DrinkType.allCases.last {
                                Divider()
                                    .background(DS.Colors.dividerSubtle)
                            }
                        }
                    }
                    .background(DS.Colors.cardBackground)
                    .cornerRadius(DS.Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
                    .dsCardShadow()
                    .padding(.top, 4)
                }
            }
            
            // Custom drink type field (shown when "Other" is selected)
            if drinkType == .other {
                TextField("What are you drinking?", text: $customDrinkType)
                    .foregroundColor(DS.Colors.textPrimary)
                    .tint(DS.Colors.primaryAccent)
                    .accentColor(DS.Colors.primaryAccent)
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.cardBackground)
                    .cornerRadius(DS.Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
                    .padding(.top, DS.Spacing.sm)
            }
        }
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Radius.card)
        .dsCardShadow()
    }
}


// MARK: - Cafe Search Sheet

struct CafeSearchSheet: View {
    @Binding var searchText: String
    @ObservedObject var searchService: MapSearchService
    @ObservedObject var dataManager: DataManager
    @Binding var selectedCafe: Cafe?
    let region: MKCoordinateRegion
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(DS.Colors.textSecondary)
                        
                        TextField("Search cafes...", text: $searchText)
                            .foregroundColor(DS.Colors.textPrimary)
                            .tint(DS.Colors.primaryAccent)
                            .accentColor(DS.Colors.primaryAccent)
                            .onChange(of: searchText) { oldValue, newValue in
                                if !newValue.isEmpty {
                                    searchService.search(query: newValue, region: region)
                                } else {
                                    searchService.cancelSearch()
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchService.cancelSearch()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(DS.Colors.iconSubtle)
                            }
                        }
                    }
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.cardBackground)
                    .cornerRadius(DS.Radius.card)
                }
                .padding(DS.Spacing.pagePadding)
                
                // Results
                if searchService.isSearching {
                    ProgressView()
                        .padding(DS.Spacing.md)
                } else if let error = searchService.searchError {
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(DS.Colors.iconSubtle)
                        Text(error)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    .padding(DS.Spacing.md)
                } else if searchService.searchResults.isEmpty && !searchText.isEmpty {
                    Text("No results found")
                        .foregroundColor(DS.Colors.textSecondary)
                        .padding(DS.Spacing.md)
                } else {
                    List {
                        ForEach(searchService.searchResults, id: \.self) { mapItem in
                            Button(action: {
                                let cafe = dataManager.findOrCreateCafe(from: mapItem)
                                selectedCafe = cafe
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mapItem.name ?? "Unknown")
                                            .foregroundColor(DS.Colors.textPrimary)
                                        if let address = formatAddress(from: mapItem.placemark), !address.isEmpty {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(DS.Colors.textSecondary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Search Cafes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String? {
        var components: [String] = []
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

// MARK: - Customize Ratings View

struct CustomizeRatingsView: View {
    @ObservedObject var dataManager: DataManager
    @Binding var isPresented: Bool
    @State private var editingCategories: [RatingCategory]
    
    init(dataManager: DataManager, isPresented: Binding<Bool>) {
        self.dataManager = dataManager
        self._isPresented = isPresented
        // Start with a copy of current categories
        var categories = dataManager.appData.ratingTemplate.categories
        // Convert normalized weights to multipliers if needed
        let total = categories.reduce(0.0) { $0 + $1.weight }
        // If weights sum to ~1.0, they're normalized - convert to multipliers
        if total > 0.9 && total < 1.1 {
            let minWeight = categories.map { $0.weight }.min() ?? 1.0
            if minWeight > 0 {
                for i in categories.indices {
                    categories[i].weight = categories[i].weight / minWeight
                }
            }
        }
        self._editingCategories = State(initialValue: categories)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Define what matters most in your coffee journey and how much each criterion should count.")
                        .font(DS.Typography.bodyText)
                        .foregroundColor(DS.Colors.textSecondary)
                        .padding(.top, DS.Spacing.md)
                    
                    ForEach(editingCategories.indices, id: \.self) { index in
                        DSBaseCard {
                            CustomizeRatingCategoryRow(
                                category: $editingCategories[index],
                                onDelete: {
                                    editingCategories.remove(at: index)
                                }
                            )
                        }
                    }
                    
                    Button(action: {
                        // Find minimum weight to set new category to 1x
                        let minWeight = editingCategories.map { $0.weight }.min() ?? 1.0
                        let newCategory = RatingCategory(name: "New Category", weight: minWeight)
                        editingCategories.append(newCategory)
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add New Category")
                        }
                        .foregroundColor(DS.Colors.primaryAccent)
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.cardBackgroundAlt)
                        .cornerRadius(DS.Radius.card)
                    }
                }
                .padding(DS.Spacing.pagePadding)
            }
            .background(DS.Colors.screenBackground)
            .navigationTitle("Customize Ratings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save Changes") {
                        // Create template with multipliers (no normalization needed)
                        let updatedTemplate = RatingTemplate(categories: editingCategories)
                        dataManager.updateRatingTemplate(updatedTemplate)
                        isPresented = false
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                }
            }
        }
    }
}

struct CustomizeRatingCategoryRow: View {
    @Binding var category: RatingCategory
    let onDelete: () -> Void
    
    @State private var weightMultiplier: Double = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(DS.Colors.iconSubtle)
                
                // Category name
                TextField("Category name", text: $category.name)
                    .foregroundColor(DS.Colors.textPrimary)
                    .tint(DS.Colors.primaryAccent)
                    .accentColor(DS.Colors.primaryAccent)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.cardBackground)
                    .cornerRadius(DS.Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(DS.Colors.negativeChange)
                }
            }
            
            // Weight slider
            HStack {
                Text("Weight")
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.textPrimary)
                
                Slider(value: $weightMultiplier, in: 0.5...3.0, step: 0.5)
                    .onChange(of: weightMultiplier) { oldValue, newValue in
                        // Store as multiplier (will be normalized when template is saved)
                        category.weight = newValue
                    }
                
                Text(formatWeight(weightMultiplier))
                    .font(DS.Typography.bodyText)
                    .foregroundColor(DS.Colors.primaryAccent)
                    .frame(width: 40)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackgroundAlt)
        .cornerRadius(DS.Radius.card)
        .onAppear {
            // Weights are stored as multipliers, so use directly
            weightMultiplier = category.weight > 0 ? category.weight : 1.0
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return String(format: "%.0fx", weight)
        } else {
            return String(format: "%.1fx", weight)
        }
    }
}

