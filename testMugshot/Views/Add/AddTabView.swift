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
                .background(Color.creamWhite)
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
                        .foregroundColor(.espressoBrown)
                    }
                }
                .toolbarBackground(Color.mugshotMint, for: .navigationBar)
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
                        VisitDetailView(visit: visit, dataManager: dataManager)
                    }
                }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            // Light background
            Color.sandBeige.opacity(0.3)
                .ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    formContent
                        .padding(.horizontal, 16)
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
    }
    
    private var formContent: some View {
        VStack(spacing: 24) {
            // Header section (inside scrollable content)
            VStack(alignment: .leading, spacing: 8) {
                Text("Log a Visit")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.espressoBrown)
                
                Text("Share your sip and what made it special.")
                    .font(.system(size: 16))
                    .foregroundColor(.espressoBrown.opacity(0.7))
            }
            .id("top")
            .padding(.top, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        
            // Cafe Location
            CafeLocationSection(
                selectedCafe: $selectedCafe,
                searchText: $searchText,
                isSearchActive: $isCafeSearchActive,
                searchService: searchService,
                dataManager: dataManager,
                searchRegion: defaultSearchRegion
            )
            
            // Drink Type
            DrinkTypeSection(
                drinkType: $drinkType,
                customDrinkType: $customDrinkType
            )
            
            // Photos
            PhotosSection(
                photoImages: $photoImages,
                posterPhotoIndex: $posterPhotoIndex,
                showPhotoPicker: $showPhotoPicker
            )
            
            // Ratings
            RatingsSection(
                dataManager: dataManager,
                ratings: $ratings,
                overallScore: overallScore,
                showCustomize: $showCustomizeRatings
            )
            
            // Caption
            CaptionSection(caption: $caption)
            
            // Notes
            NotesSection(notes: $notes)
            
            // Visibility
            VisibilitySection(visibility: $visibility)
            
            // Validation errors
            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(validationErrors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(DesignSystem.cornerRadius)
            }
            
            // Save button
            Button("Save Visit") {
                saveVisit()
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
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
        
        guard let userId = dataManager.appData.currentUser?.id else {
            return
        }
        
        // Convert photos to strings and cache the images
        let photoPaths = photoImages.enumerated().map { index, image in
            let path = "photo_\(UUID().uuidString)_\(index)"
            // Cache the image for later retrieval
            PhotoCache.shared.store(image, forKey: path)
            return path
        }
        
        // Parse mentions from caption
        let mentions = MentionParser.parseMentions(from: caption)
        
        let visit = Visit(
            cafeId: cafe.id,
            userId: userId,
            createdAt: Date(),
            drinkType: drinkType,
            customDrinkType: drinkType == .other ? customDrinkType : nil,
            caption: caption,
            notes: notes.isEmpty ? nil : notes,
            photos: photoPaths,
            posterPhotoIndex: posterPhotoIndex,
            ratings: ratings,
            overallScore: overallScore,
            visibility: visibility,
            likeCount: 0,
            likedByUserIds: [],
            comments: [],
            mentions: mentions
        )
        
        dataManager.addVisit(visit)
        savedVisit = visit
        showVisitDetail = true
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Cafe Location")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.espressoBrown)
            
            if isSearchActive {
                // Inline search mode
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.espressoBrown.opacity(0.6))
                            
                            TextField("Search cafes...", text: $searchText)
                                .foregroundColor(.espressoBrown)
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
                                        .foregroundColor(.espressoBrown.opacity(0.4))
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
                        
                        Button("Cancel") {
                            searchText = ""
                            searchService.cancelSearch()
                            isSearchActive = false
                        }
                        .foregroundColor(.espressoBrown)
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
                                        .foregroundColor(.mugshotMint)
                                        .font(.system(size: 14))
                                    Text(cafe.name)
                                        .font(.system(size: 16))
                                        .foregroundColor(.espressoBrown)
                                }
                                
                                if !cafe.address.isEmpty {
                                    Text(cafe.address)
                                        .font(.system(size: 14))
                                        .foregroundColor(.espressoBrown.opacity(0.7))
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.espressoBrown.opacity(0.6))
                                Text("Search for a Cafe…")
                                    .foregroundColor(.espressoBrown.opacity(0.6))
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.espressoBrown.opacity(0.4))
                    }
                    .padding()
                    .background(Color.creamWhite)
                    .cornerRadius(DesignSystem.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                            .stroke(Color.sandBeige, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
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
                        .padding()
                    Spacer()
                }
                .background(Color.creamWhite)
            } else if let error = searchService.searchError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.espressoBrown.opacity(0.5))
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.creamWhite)
            } else if searchService.searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Text("No results found")
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                }
                .padding()
                .background(Color.creamWhite)
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
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mapItem.name ?? "Unknown")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.espressoBrown)
                                        
                                        if let address = formatAddress(from: mapItem.placemark), !address.isEmpty {
                                            Text(address)
                                                .font(.system(size: 12))
                                                .foregroundColor(.espressoBrown.opacity(0.6))
                                        }
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.creamWhite)
                            }
                            .buttonStyle(.plain)
                            
                            if index < searchService.searchResults.count - 1 {
                                Divider()
                                    .background(Color.sandBeige)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color.creamWhite)
            }
        }
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige, lineWidth: 1)
        )
        .shadow(
            color: DesignSystem.cardShadow.color,
            radius: DesignSystem.cardShadow.radius,
            x: DesignSystem.cardShadow.x,
            y: DesignSystem.cardShadow.y
        )
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.espressoBrown)
            
            VStack(alignment: .leading, spacing: 0) {
                // Main button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDropdown.toggle()
                    }
                }) {
                    HStack {
                        Text(showDropdown ? "Select drink type" : (drinkType == .other && !customDrinkType.isEmpty ? customDrinkType : (drinkType == .other && customDrinkType.isEmpty ? "Select drink type" : drinkType.rawValue)))
                            .foregroundColor(showDropdown || (drinkType == .other && customDrinkType.isEmpty) ? .espressoBrown.opacity(0.6) : .espressoBrown)
                        Spacer()
                        Image(systemName: showDropdown ? "chevron.up" : "chevron.down")
                            .foregroundColor(.espressoBrown.opacity(0.4))
                            .font(.system(size: 12))
                    }
                    .padding()
                    .background(Color.creamWhite)
                    .cornerRadius(DesignSystem.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                            .stroke(Color.sandBeige, lineWidth: 1)
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
                                        .foregroundColor(.espressoBrown)
                                    Spacer()
                                    if drinkType == type {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.mugshotMint)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(drinkType == type ? Color.mugshotMint.opacity(0.2) : Color.creamWhite)
                            }
                            .buttonStyle(.plain)
                            
                            if type != DrinkType.allCases.last {
                                Divider()
                                    .background(Color.sandBeige)
                            }
                        }
                    }
                    .background(Color.creamWhite)
                    .cornerRadius(DesignSystem.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                            .stroke(Color.sandBeige, lineWidth: 1)
                    )
                    .shadow(
                        color: DesignSystem.cardShadow.color,
                        radius: DesignSystem.cardShadow.radius,
                        x: DesignSystem.cardShadow.x,
                        y: DesignSystem.cardShadow.y
                    )
                    .padding(.top, 4)
                }
            }
            
            // Custom drink type field (shown when "Other" is selected)
            if drinkType == .other {
                TextField("What are you drinking?", text: $customDrinkType)
                    .foregroundColor(.inputText)
                    .tint(.mugshotMint)
                    .accentColor(.mugshotMint)
                    .padding()
                    .background(Color.inputBackground)
                    .cornerRadius(DesignSystem.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                            .stroke(Color.sandBeige, lineWidth: 1)
                    )
                    .padding(.top, 8)
            }
        }
        .cardStyle()
    }
}

// MARK: - Photos Section

struct PhotosSection: View {
    @Binding var photoImages: [UIImage]
    @Binding var posterPhotoIndex: Int
    @Binding var showPhotoPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.espressoBrown)
            
            if photoImages.isEmpty {
                Button(action: {
                    showPhotoPicker = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 32))
                            .foregroundColor(.espressoBrown.opacity(0.5))
                        
                        Text("Tap to add photos (\(photoImages.count)/10)")
                            .font(.system(size: 14))
                            .foregroundColor(.espressoBrown.opacity(0.7))
                        
                        Text("Photos will be compressed automatically.")
                            .font(.system(size: 12))
                            .foregroundColor(.espressoBrown.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color.clear)
                    .cornerRadius(DesignSystem.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(.sandBeige)
                    )
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photoImages.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: photoImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))
                                
                                // Poster indicator
                                if index == posterPhotoIndex {
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.mugshotMint)
                                                .background(Color.white)
                                                .clipShape(Circle())
                                                .padding(4)
                                        }
                                        Spacer()
                                    }
                                }
                                
                                // Remove button
                                Button(action: {
                                    photoImages.remove(at: index)
                                    if posterPhotoIndex >= photoImages.count - 1 {
                                        posterPhotoIndex = max(0, photoImages.count - 2)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                                .offset(x: 4, y: -4)
                                
                                // Tap to set poster
                                Button(action: {
                                    posterPhotoIndex = index
                                }) {
                                    Color.clear
                                        .frame(width: 100, height: 100)
                                }
                            }
                        }
                        
                        if photoImages.count < 10 {
                            Button(action: {
                                showPhotoPicker = true
                            }) {
                                RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                                    .fill(Color.sandBeige.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .foregroundColor(.espressoBrown.opacity(0.5))
                                    )
                            }
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Ratings Section

struct RatingsSection: View {
    @ObservedObject var dataManager: DataManager
    @Binding var ratings: [String: Double]
    let overallScore: Double
    @Binding var showCustomize: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ratings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                
                Spacer()
                
                Button(action: {
                    showCustomize = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                        Text("Customize")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.mugshotMint)
                }
            }
            
            ForEach(dataManager.appData.ratingTemplate.categories) { category in
                RatingCategoryRow(
                    category: category,
                    rating: Binding(
                        get: { ratings[category.name] ?? 0.0 },
                        set: { ratings[category.name] = $0 }
                    ),
                    weightMultiplier: dataManager.appData.ratingTemplate.getWeightMultiplier(for: category)
                )
            }
            
            Divider()
                .padding(.vertical, 8)
            
            HStack {
                Text("Overall Score")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.mugshotMint)
                    Text(String(format: "%.1f", overallScore))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.espressoBrown)
                }
            }
        }
        .cardStyle()
    }
}

struct RatingCategoryRow: View {
    let category: RatingCategory
    @Binding var rating: Double
    let weightMultiplier: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Text(category.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.espressoBrown)
                    
                    if weightMultiplier != 1.0 {
                        Text("(\(formatWeight(weightMultiplier)) importance)")
                            .font(.system(size: 12))
                            .foregroundColor(.mugshotMint)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    Button(action: {
                        let newRating = Double(index + 1)
                        // Tapping the same star again sets to 0
                        rating = rating == newRating ? 0.0 : newRating
                    }) {
                        Image(systemName: rating > Double(index) ? "star.fill" : "star")
                            .foregroundColor(rating > Double(index) ? .mugshotMint : .espressoBrown.opacity(0.3))
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return String(format: "%.0fx", weight)
        } else {
            return String(format: "%.1fx", weight)
        }
    }
}

// MARK: - Caption Section

struct CaptionSection: View {
    @Binding var caption: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Caption")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                
                Spacer()
                
                Text("\(caption.count)/200")
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.6))
            }
            
            TextField("Share your thoughts or first impressions…", text: Binding(
                get: { caption },
                set: { newValue in
                    if newValue.count <= 200 {
                        caption = newValue
                    }
                }
            ), axis: .vertical)
                .lineLimit(3...6)
                .foregroundColor(.inputText)
                .tint(.mugshotMint)
                .accentColor(.mugshotMint)
                .padding()
                .background(Color.inputBackground)
                .cornerRadius(DesignSystem.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .stroke(Color.inputBorder, lineWidth: 1)
                )
        }
        .cardStyle()
    }
}

// MARK: - Notes Section

struct NotesSection: View {
    @Binding var notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes (Optional)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.espressoBrown)
            
            TextField("Anything extra you'd like to remember?", text: $notes, axis: .vertical)
                .lineLimit(3...8)
                .foregroundColor(.inputText)
                .tint(.mugshotMint)
                .accentColor(.mugshotMint)
                .padding()
                .background(Color.inputBackground)
                .cornerRadius(DesignSystem.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .stroke(Color.inputBorder, lineWidth: 1)
                )
        }
        .cardStyle()
    }
}

// MARK: - Visibility Section

struct VisibilitySection: View {
    @Binding var visibility: VisitVisibility
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visibility")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.espressoBrown)
            
            HStack(spacing: 12) {
                VisibilityButton(
                    title: "Private",
                    subtitle: "Only you",
                    isSelected: visibility == .private,
                    action: { visibility = .private }
                )
                
                VisibilityButton(
                    title: "Friends",
                    subtitle: "Friends can see",
                    isSelected: visibility == .friends,
                    action: { visibility = .friends }
                )
                
                VisibilityButton(
                    title: "Everyone",
                    subtitle: "Visible to all",
                    isSelected: visibility == .everyone,
                    action: { visibility = .everyone }
                )
            }
        }
        .cardStyle()
    }
}

struct VisibilityButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .espressoBrown : .espressoBrown.opacity(0.7))
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.espressoBrown.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.mugshotMint.opacity(0.2) : Color.sandBeige.opacity(0.3))
            .cornerRadius(DesignSystem.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                    .stroke(isSelected ? Color.mugshotMint : Color.clear, lineWidth: 2)
            )
        }
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
                            .foregroundColor(.espressoBrown.opacity(0.6))
                        
                        TextField("Search cafes...", text: $searchText)
                            .foregroundColor(.inputText)
                            .tint(.mugshotMint)
                            .accentColor(.mugshotMint)
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
                                    .foregroundColor(.espressoBrown.opacity(0.4))
                            }
                        }
                    }
                    .padding()
                    .background(Color.creamWhite)
                    .cornerRadius(DesignSystem.cornerRadius)
                }
                .padding()
                
                // Results
                if searchService.isSearching {
                    ProgressView()
                        .padding()
                } else if let error = searchService.searchError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.espressoBrown.opacity(0.5))
                        Text(error)
                            .foregroundColor(.espressoBrown.opacity(0.7))
                    }
                    .padding()
                } else if searchService.searchResults.isEmpty && !searchText.isEmpty {
                    Text("No results found")
                        .foregroundColor(.espressoBrown.opacity(0.7))
                        .padding()
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
                                            .foregroundColor(.espressoBrown)
                                        if let address = formatAddress(from: mapItem.placemark), !address.isEmpty {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(.espressoBrown.opacity(0.6))
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .background(Color.creamWhite)
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
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                        .padding(.top)
                    
                    ForEach(editingCategories.indices, id: \.self) { index in
                        CustomizeRatingCategoryRow(
                            category: $editingCategories[index],
                            onDelete: {
                                editingCategories.remove(at: index)
                            }
                        )
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
                        .foregroundColor(.mugshotMint)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.sandBeige.opacity(0.3))
                        .cornerRadius(DesignSystem.cornerRadius)
                    }
                }
                .padding()
            }
            .background(Color.creamWhite)
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
                    .buttonStyle(PrimaryButtonStyle())
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.espressoBrown.opacity(0.4))
                
                // Category name
                TextField("Category name", text: $category.name)
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
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            // Weight slider
            HStack {
                Text("Weight")
                    .font(.system(size: 14))
                    .foregroundColor(.espressoBrown)
                
                Slider(value: $weightMultiplier, in: 0.5...3.0, step: 0.5)
                    .onChange(of: weightMultiplier) { oldValue, newValue in
                        // Store as multiplier (will be normalized when template is saved)
                        category.weight = newValue
                    }
                
                Text(formatWeight(weightMultiplier))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.mugshotMint)
                    .frame(width: 40)
            }
        }
        .padding()
        .background(Color.sandBeige.opacity(0.3))
        .cornerRadius(DesignSystem.cornerRadius)
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

