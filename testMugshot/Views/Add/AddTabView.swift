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
import Supabase

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
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedCafe: Cafe?
    @State private var isCafeSearchActive = false
    @State private var drinkType: DrinkType = .coffee
    @State private var customDrinkType: String = ""
    @State private var drinkDetails: String = ""
    @State private var caption: String = ""
    @State private var notes: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var posterPhotoIndex: Int = 0
    @State private var ratings: [String: Double] = [:]
    @State private var visibility: VisitVisibility = .everyone
    @State private var showCustomizeRatings = false
    @State private var validationErrors: [String] = []
    @State private var savedVisit: Visit?
    @State private var showVisitDetail = false
    @State private var savedRemoteVisit: RemoteVisitSummary?
    @State private var isSavingRemoteVisit = false
    @State private var pendingPhotoUploadVisit: RemoteVisitSummary?
    @State private var photoUploadFailureMessage: String?
    
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

    private var saveButtonTitle: String {
        if pendingPhotoUploadVisit != nil {
            return "Visit Saved"
        }

        if isSavingRemoteVisit {
            return photoImages.isEmpty ? "Saving..." : "Uploading..."
        }

        return canSubmitVisit ? "Save Visit" : "Complete Required Details"
    }

    private var progressItems: [LogVisitProgressItem] {
        [
            LogVisitProgressItem(
                title: "Cafe",
                systemImage: "mappin.and.ellipse",
                isComplete: selectedCafe != nil
            ),
            LogVisitProgressItem(
                title: "Drink",
                systemImage: "cup.and.saucer.fill",
                isComplete: drinkDetails.remoteTrimmedNonEmpty != nil &&
                    (drinkType != .other || customDrinkType.remoteTrimmedNonEmpty != nil)
            ),
            LogVisitProgressItem(
                title: "Rating",
                systemImage: "star.fill",
                isComplete: overallScore > 0
            ),
            LogVisitProgressItem(
                title: "Caption",
                systemImage: "text.bubble.fill",
                isComplete: caption.remoteTrimmedNonEmpty != nil
            )
        ]
    }

    private var completedProgressCount: Int {
        progressItems.filter(\.isComplete).count
    }

    private var canSubmitVisit: Bool {
        completedProgressCount == progressItems.count
    }

    private var isSaveButtonDisabled: Bool {
        isSavingRemoteVisit || pendingPhotoUploadVisit != nil || !canSubmitVisit
    }

    private var drinkDisplayName: String {
        if drinkType == .other,
           let customDrink = customDrinkType.remoteTrimmedNonEmpty {
            return customDrink
        }

        if let details = drinkDetails.remoteTrimmedNonEmpty {
            return details
        }

        return drinkType.rawValue
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
                .sheet(item: $savedRemoteVisit, onDismiss: {
                    resetForm()
                    tabCoordinator.selectedTab = 4
                    dismiss()
                }) { visit in
                    RemoteVisitDetailView(
                        visitId: visit.id,
                        initialSummary: visit,
                        currentUserId: authModel.authenticatedUser?.id
                    )
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
                        .padding(.bottom, 110)
                }
                .scrollDismissesKeyboard(.interactively)
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
        VStack(spacing: 18) {
            LogVisitHeroHeader(
                completedCount: completedProgressCount,
                totalCount: progressItems.count,
                hasPhoto: !photoImages.isEmpty,
                isRemoteMode: authModel.authenticatedUser != nil
            )
            .id("top")
            .padding(.top, 16)

            LogVisitProgressCard(
                items: progressItems,
                isSaving: isSavingRemoteVisit,
                isRemoteMode: authModel.authenticatedUser != nil
            )

            PhotosSection(
                selectedPhotos: $selectedPhotos,
                photoImages: $photoImages,
                posterPhotoIndex: $posterPhotoIndex
            )

            if authModel.authenticatedUser != nil {
                RemotePhotoReadinessSection(photoCount: photoImages.count)
            }

            AddVisitSummaryStrip(
                cafeName: selectedCafe?.name,
                drinkName: drinkDisplayName,
                overallScore: overallScore,
                visibility: visibility,
                photoCount: photoImages.count
            )

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

            DrinkDetailsSection(drinkDetails: $drinkDetails)

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
                ValidationErrorCard(errors: validationErrors)
            }

            if let pendingPhotoUploadVisit,
               let photoUploadFailureMessage {
                PhotoUploadRecoveryCard(
                    message: photoUploadFailureMessage,
                    isRetrying: isSavingRemoteVisit,
                    retryAction: retryPhotoUpload,
                    openSavedVisitAction: {
                        openSavedRemoteVisit(pendingPhotoUploadVisit)
                    }
                )
            }
            
            // Save button
            Button {
                saveVisit()
            } label: {
                SaveVisitButtonLabel(
                    title: saveButtonTitle,
                    isSaving: isSavingRemoteVisit,
                    photoCount: photoImages.count
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .disabled(isSaveButtonDisabled)
            .opacity(isSaveButtonDisabled ? 0.62 : 1.0)
        }
    }
    
    private func resetForm() {
        // Reset all form fields
        selectedCafe = nil
        isCafeSearchActive = false
        drinkType = .coffee
        customDrinkType = ""
        drinkDetails = ""
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
        savedRemoteVisit = nil
        showVisitDetail = false
        isSavingRemoteVisit = false
        pendingPhotoUploadVisit = nil
        photoUploadFailureMessage = nil

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
        guard !isSavingRemoteVisit else {
            return
        }

        validationErrors = []
        
        // Validate
        guard let cafe = selectedCafe else {
            validationErrors.append("Please select a Cafe location")
            return
        }

        guard drinkType != .other || customDrinkType.remoteTrimmedNonEmpty != nil else {
            validationErrors.append("Please specify a custom drink type")
            return
        }

        guard drinkDetails.remoteTrimmedNonEmpty != nil else {
            validationErrors.append("Please add drink details")
            return
        }
        
        guard caption.remoteTrimmedNonEmpty != nil else {
            validationErrors.append("Please write a caption")
            return
        }

        guard overallScore > 0 else {
            validationErrors.append("Please add at least one rating")
            return
        }

        if let authenticatedUser = authModel.authenticatedUser {
            Task {
                await saveRemoteVisit(cafe: cafe, authenticatedUser: authenticatedUser)
            }
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

    @MainActor
    private func saveRemoteVisit(
        cafe: Cafe,
        authenticatedUser: AuthenticatedUser
    ) async {
        isSavingRemoteVisit = true
        validationErrors = []

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            var remoteVisit = try await service.createNoPhotoVisit(
                userId: authenticatedUser.id,
                cafe: cafe,
                drinkType: drinkType,
                customDrinkType: customDrinkType,
                drinkSubtype: drinkDetails,
                caption: caption,
                notes: notes,
                visibility: visibility,
                ratings: ratings,
                ratingTemplate: dataManager.appData.ratingTemplate
            )

            if !photoImages.isEmpty {
                do {
                    remoteVisit = try await attachSelectedPhotos(
                        to: remoteVisit,
                        authenticatedUser: authenticatedUser,
                        client: client,
                        visitService: service
                    )
                } catch {
                    isSavingRemoteVisit = false
                    pendingPhotoUploadVisit = remoteVisit
                    photoUploadFailureMessage = photoUploadMessage(for: error)
                    return
                }
            }

            isSavingRemoteVisit = false
            pendingPhotoUploadVisit = nil
            photoUploadFailureMessage = nil
            mirrorRemoteCafe(from: remoteVisit)
            savedRemoteVisit = remoteVisit
        } catch {
            isSavingRemoteVisit = false
            validationErrors = [error.localizedDescription]
            scrollToTop = true
        }
    }

    private func retryPhotoUpload() {
        guard let pendingPhotoUploadVisit,
              let authenticatedUser = authModel.authenticatedUser,
              !isSavingRemoteVisit else {
            return
        }

        Task {
            await retryPhotoUpload(
                for: pendingPhotoUploadVisit,
                authenticatedUser: authenticatedUser
            )
        }
    }

    @MainActor
    private func retryPhotoUpload(
        for remoteVisit: RemoteVisitSummary,
        authenticatedUser: AuthenticatedUser
    ) async {
        isSavingRemoteVisit = true
        validationErrors = []

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let updatedVisit = try await attachSelectedPhotos(
                to: remoteVisit,
                authenticatedUser: authenticatedUser,
                client: client,
                visitService: service
            )

            isSavingRemoteVisit = false
            pendingPhotoUploadVisit = nil
            photoUploadFailureMessage = nil
            mirrorRemoteCafe(from: updatedVisit)
            savedRemoteVisit = updatedVisit
        } catch {
            isSavingRemoteVisit = false
            photoUploadFailureMessage = photoUploadMessage(for: error)
        }
    }

    private func openSavedRemoteVisit(_ visit: RemoteVisitSummary) {
        pendingPhotoUploadVisit = nil
        photoUploadFailureMessage = nil
        mirrorRemoteCafe(from: visit)
        savedRemoteVisit = visit
    }

    private func mirrorRemoteCafe(from visit: RemoteVisitSummary) {
        guard let cafe = visit.cafe else {
            return
        }

        dataManager.upsertRemoteCafe(
            cafe,
            averageRating: visit.visit.overallScore,
            visitCount: 1
        )
    }

    private func attachSelectedPhotos(
        to remoteVisit: RemoteVisitSummary,
        authenticatedUser: AuthenticatedUser,
        client: SupabaseClient,
        visitService: VisitService
    ) async throws -> RemoteVisitSummary {
        let uploadService = VisitPhotoUploadService(client: client)
        let uploadedPhotos = try await uploadService.uploadPhotos(
            userId: authenticatedUser.id,
            visitId: remoteVisit.id,
            images: photoImages,
            posterPhotoIndex: posterPhotoIndex
        )

        return try await visitService.attachPhotoURLs(
            visitId: remoteVisit.id,
            photoURLs: uploadedPhotos.publicURLs,
            posterPhotoIndex: uploadedPhotos.posterPhotoIndex
        )
    }

    private func photoUploadMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        return "Visit saved, but the photos did not upload."
    }
}

// MARK: - Log Visit Header

struct LogVisitHeroHeader: View {
    let completedCount: Int
    let totalCount: Int
    let hasPhoto: Bool
    let isRemoteMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Log a Sip")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    Text("Capture the drink, then add the essentials.")
                        .font(.system(size: 16))
                        .foregroundColor(.espressoBrown.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(spacing: 5) {
                    Text("\(min(completedCount + 1, max(totalCount, 1)))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .frame(width: 42, height: 42)
                        .background(Color.mugshotMint.opacity(0.55))
                        .clipShape(Circle())

                    Text("of \(max(totalCount, 1))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.espressoBrown.opacity(0.6))
                }
                .accessibilityLabel("\(completedCount) of \(totalCount) visit details complete")
            }

            HStack(spacing: 8) {
                LogVisitHeroPill(
                    title: hasPhoto ? "Photo ready" : "Photo optional",
                    systemImage: hasPhoto ? "photo.fill" : "camera"
                )

                LogVisitHeroPill(
                    title: isRemoteMode ? "Supabase live" : "Local draft",
                    systemImage: isRemoteMode ? "checkmark.circle.fill" : "tray.fill"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.espressoBrown)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct LogVisitHeroPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))

            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.espressoBrown.opacity(0.78))
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Color.creamWhite.opacity(0.92))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.sandBeige.opacity(0.9), lineWidth: 1)
        )
    }
}

struct AddVisitSummaryStrip: View {
    let cafeName: String?
    let drinkName: String
    let overallScore: Double
    let visibility: VisitVisibility
    let photoCount: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                AddVisitSummaryPill(
                    title: cafeName ?? "Choose cafe",
                    systemImage: cafeName == nil ? "mappin.and.ellipse" : "mappin.circle.fill",
                    isComplete: cafeName != nil
                )

                AddVisitSummaryPill(
                    title: drinkName,
                    systemImage: "cup.and.saucer.fill",
                    isComplete: !drinkName.isEmpty
                )

                AddVisitSummaryPill(
                    title: overallScore > 0 ? String(format: "%.1f", overallScore) : "Rate",
                    systemImage: "star.fill",
                    isComplete: overallScore > 0
                )

                AddVisitSummaryPill(
                    title: visibility.rawValue,
                    systemImage: visibility.iconName,
                    isComplete: true
                )

                AddVisitSummaryPill(
                    title: photoCount == 0 ? "No photo" : "\(photoCount) photo\(photoCount == 1 ? "" : "s")",
                    systemImage: photoCount == 0 ? "photo" : "photo.fill",
                    isComplete: photoCount > 0
                )
            }
            .padding(.vertical, 2)
        }
    }
}

struct AddVisitSummaryPill: View {
    let title: String
    let systemImage: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(isComplete ? .espressoBrown : .espressoBrown.opacity(0.62))
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(isComplete ? Color.mugshotMint.opacity(0.22) : Color.creamWhite.opacity(0.88))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isComplete ? Color.mugshotMint.opacity(0.55) : Color.sandBeige.opacity(0.82), lineWidth: 1)
        )
    }
}

struct SaveVisitButtonLabel: View {
    let title: String
    let isSaving: Bool
    let photoCount: Int

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 9) {
                if isSaving {
                    ProgressView()
                        .tint(.espressoBrown)
                } else {
                    Image(systemName: photoCount > 0 ? "photo.on.rectangle.angled" : "cup.and.saucer.fill")
                        .font(.system(size: 15, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 17, weight: .bold))
            }

            if isSaving {
                Text(photoCount > 0 ? "Saving the visit, then uploading photos" : "Saving to your taste journal")
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.72)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private extension DrinkType {
    var shortDisplayName: String {
        switch self {
        case .hotChocolate:
            return "Chocolate"
        default:
            return rawValue
        }
    }

    var iconName: String {
        switch self {
        case .coffee:
            return "cup.and.saucer.fill"
        case .matcha:
            return "leaf.fill"
        case .hojicha:
            return "flame.fill"
        case .tea:
            return "mug.fill"
        case .chai:
            return "sparkles"
        case .hotChocolate:
            return "takeoutbag.and.cup.and.straw.fill"
        case .other:
            return "ellipsis"
        }
    }
}

private extension VisitVisibility {
    var iconName: String {
        switch self {
        case .private:
            return "lock.fill"
        case .friends:
            return "person.2.fill"
        case .everyone:
            return "globe"
        }
    }
}

// MARK: - Log Visit Progress

struct LogVisitProgressItem: Identifiable {
    let title: String
    let systemImage: String
    let isComplete: Bool

    var id: String { title }
}

struct LogVisitProgressCard: View {
    let items: [LogVisitProgressItem]
    let isSaving: Bool
    let isRemoteMode: Bool

    private var completedCount: Int {
        items.filter(\.isComplete).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: completedCount == items.count ? "checkmark.circle.fill" : "leaf.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.mugshotMint)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isSaving ? "Saving your visit" : "\(completedCount) of \(items.count) ready")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.espressoBrown)

                    Text(isRemoteMode ? "This saves to Supabase and appears in Profile Recent." : "This saves locally until you sign in.")
                        .font(.system(size: 13))
                        .foregroundColor(.espressoBrown.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            ProgressView(value: Double(completedCount), total: Double(max(items.count, 1)))
                .tint(.mugshotMint)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(items) { item in
                    LogVisitProgressChip(item: item)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct LogVisitProgressChip: View {
    let item: LogVisitProgressItem

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: item.isComplete ? "checkmark.circle.fill" : item.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(item.isComplete ? .mugshotMint : .espressoBrown.opacity(0.55))

            Text(item.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(item.isComplete ? .espressoBrown : .espressoBrown.opacity(0.62))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(item.isComplete ? Color.mugshotMint.opacity(0.18) : Color.sandBeige.opacity(0.32))
        .cornerRadius(999)
    }
}

struct RemotePhotoReadinessSection: View {
    let photoCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: photoCount > 0 ? "icloud.and.arrow.up.fill" : "camera.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.espressoBrown.opacity(0.72))
                    .frame(width: 34, height: 34)
                    .background(Color.sandBeige.opacity(0.55))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(photoCount > 0 ? "Ready to upload \(photoCount) photo\(photoCount == 1 ? "" : "s")" : "Photos are optional")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.espressoBrown)

                    Text(photoCount > 0 ? "Selected photos save with this visit and appear on the remote detail screen." : "No-photo visits still save normally. Add photos here when you want them on the remote visit.")
                        .font(.system(size: 13))
                        .foregroundColor(.espressoBrown.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                ReadinessPill(title: "No-photo save live", systemImage: "checkmark.circle.fill")
                ReadinessPill(title: "Storage ready", systemImage: "shippingbox.fill")
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct PhotoUploadRecoveryCard: View {
    let message: String
    let isRetrying: Bool
    let retryAction: () -> Void
    let openSavedVisitAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.espressoBrown.opacity(0.76))
                    .frame(width: 34, height: 34)
                    .background(Color.sandBeige.opacity(0.55))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Visit saved without photos")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.espressoBrown)

                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.espressoBrown.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button {
                    retryAction()
                } label: {
                    HStack(spacing: 6) {
                        if isRetrying {
                            ProgressView()
                                .tint(.espressoBrown)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isRetrying ? "Trying..." : "Try Again")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isRetrying)

                Button {
                    openSavedVisitAction()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Open Visit")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isRetrying)
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct ReadinessPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.espressoBrown.opacity(0.78))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.mugshotMint.opacity(0.18))
        .cornerRadius(999)
    }
}

struct ValidationErrorCard: View {
    let errors: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red.opacity(0.82))

                Text("Finish these before saving")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
            }

            ForEach(errors, id: \.self) { error in
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.espressoBrown.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.red.opacity(0.08))
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.red.opacity(0.16), lineWidth: 1)
        )
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
            SectionTitle(
                title: "Where was this from?",
                subtitle: selectedCafe == nil ? "Search or type the cafe name." : "This cafe will be attached to the visit."
            )
            
            if isSearchActive {
                // Inline search mode
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.espressoBrown.opacity(0.6))
                            
                            TextField("Search cafes...", text: $searchText)
                                .foregroundColor(.espressoBrown)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
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
                                Text("Search for a cafe…")
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
        .padding(16)
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

                    typedCafeButton
                }
                .padding()
                .background(Color.creamWhite)
            } else if searchService.searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Text("No results found")
                        .font(.system(size: 14))
                        .foregroundColor(.espressoBrown.opacity(0.7))

                    typedCafeButton
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

    private var typedCafeButton: some View {
        let cafeName = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return Group {
            if !cafeName.isEmpty {
                Button {
                    let cafe = dataManager.findOrCreateCafe(named: cafeName)
                    selectedCafe = cafe
                    searchText = ""
                    searchService.cancelSearch()
                    isSearchActive = false
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.mugshotMint)
                        Text("Use \(cafeName)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                        Spacer()
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

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "What type of drink is it?",
                subtitle: "Quick pick now; exact drink name comes next."
            )

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(DrinkType.allCases, id: \.self) { type in
                    DrinkTypeChip(
                        type: type,
                        isSelected: drinkType == type
                    ) {
                        drinkType = type
                        if type != .other {
                            customDrinkType = ""
                        }
                    }
                }
            }
            
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
        .padding(16)
        .cardStyle()
    }
}

struct DrinkTypeChip: View {
    let type: DrinkType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.system(size: 14, weight: .semibold))

                Text(type.shortDisplayName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundColor(isSelected ? .espressoBrown : .espressoBrown.opacity(0.72))
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.mugshotMint.opacity(0.28) : Color.sandBeige.opacity(0.24))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.mugshotMint : Color.sandBeige.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Drink Details Section

struct DrinkDetailsSection: View {
    @Binding var drinkDetails: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "What's the drink called?",
                subtitle: "Use the menu name or your own shorthand."
            )

            TextField("Latte, cortado, ceremonial matcha...", text: $drinkDetails)
                .foregroundColor(.inputText)
                .tint(.mugshotMint)
                .accentColor(.mugshotMint)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding()
                .background(Color.inputBackground)
                .cornerRadius(DesignSystem.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .stroke(Color.sandBeige, lineWidth: 1)
                )
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Photos Section

struct PhotosSection: View {
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var photoImages: [UIImage]
    @Binding var posterPhotoIndex: Int

    private var safePosterIndex: Int {
        guard !photoImages.isEmpty else {
            return 0
        }

        return min(max(posterPhotoIndex, 0), photoImages.count - 1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add a photo of your sip")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    Text(photoImages.isEmpty ? "Optional, but it makes the memory land." : "Choose the poster photo for this visit.")
                        .font(.system(size: 13))
                        .foregroundColor(.espressoBrown.opacity(0.64))
                }

                Spacer(minLength: 12)

                Text("\(photoImages.count)/10")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.espressoBrown.opacity(0.72))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.sandBeige.opacity(0.5))
                    .clipShape(Capsule())
            }
            
            if photoImages.isEmpty {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    photoPickerLabel
                }
                .buttonStyle(.plain)
            } else {
                Image(uiImage: photoImages[safePosterIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.largeCornerRadius))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Poster photo")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.espressoBrown)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(12)
                    }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photoImages.indices, id: \.self) { index in
                            Button {
                                posterPhotoIndex = index
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: photoImages[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 86, height: 86)
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius))

                                    if index == safePosterIndex {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.mugshotMint)
                                            .background(Color.creamWhite)
                                            .clipShape(Circle())
                                            .padding(5)
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                                        .stroke(index == safePosterIndex ? Color.mugshotMint : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    removePhoto(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.red.opacity(0.9))
                                        .background(Color.creamWhite)
                                        .clipShape(Circle())
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                        
                        if photoImages.count < 10 {
                            PhotosPicker(
                                selection: $selectedPhotos,
                                maxSelectionCount: 10,
                                matching: .images
                            ) {
                                RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                                    .fill(Color.sandBeige.opacity(0.3))
                                    .frame(width: 86, height: 86)
                                    .overlay(
                                        VStack(spacing: 5) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 17, weight: .semibold))
                                            Text("Add")
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        .foregroundColor(.espressoBrown.opacity(0.62))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var photoPickerLabel: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.largeCornerRadius)
                    .fill(Color.sandBeige.opacity(0.28))
                    .frame(height: 150)

                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.espressoBrown.opacity(0.5))

                    Text("Choose from Library")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    Text("Photos compress automatically before upload.")
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.58))
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Skip photo anytime; no-photo saves stay live.")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.espressoBrown.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.largeCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.largeCornerRadius)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundColor(.sandBeige.opacity(0.95))
        )
    }

    private func removePhoto(at index: Int) {
        guard photoImages.indices.contains(index) else {
            return
        }

        photoImages.remove(at: index)
        selectedPhotos = Array(selectedPhotos.prefix(photoImages.count))

        if photoImages.isEmpty {
            posterPhotoIndex = 0
        } else if posterPhotoIndex >= photoImages.count {
            posterPhotoIndex = photoImages.count - 1
        }
    }
}

// MARK: - Ratings Section

struct RatingsSection: View {
    @ObservedObject var dataManager: DataManager
    @Binding var ratings: [String: Double]
    let overallScore: Double
    @Binding var showCustomize: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionTitle(
                    title: "Rate this sip",
                    subtitle: "Your taste score powers the journal."
                )
                
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

            RatingScorePanel(overallScore: overallScore)
            
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
        }
        .padding(16)
        .cardStyle()
    }
}

struct RatingScorePanel: View {
    let overallScore: Double

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    Image(systemName: starName(for: index))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(starColor(for: index))
                }
            }

            HStack(spacing: 10) {
                Text(overallScore > 0 ? String(format: "%.1f", overallScore) : "0.0")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.espressoBrown)

                Text(scoreLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.espressoBrown.opacity(0.72))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.mugshotMint.opacity(0.24))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.sandBeige.opacity(0.18))
        .cornerRadius(DesignSystem.largeCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.largeCornerRadius)
                .stroke(Color.sandBeige.opacity(0.7), lineWidth: 1)
        )
    }

    private var scoreLabel: String {
        switch overallScore {
        case 4.5...:
            return "Great sip"
        case 3.5..<4.5:
            return "Solid sip"
        case 0.1..<3.5:
            return "Logged honestly"
        default:
            return "Tap stars below"
        }
    }

    private func starName(for index: Int) -> String {
        overallScore > Double(index) ? "star.fill" : "star"
    }

    private func starColor(for index: Int) -> Color {
        overallScore > Double(index) ? .mugshotMint : .espressoBrown.opacity(0.24)
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
                SectionTitle(
                    title: "What stood out?",
                    subtitle: "A short memory for your taste journal."
                )
                
                Spacer()
                
                Text("\(caption.count)/200")
                    .font(.system(size: 12))
                    .foregroundColor(.espressoBrown.opacity(0.6))
            }
            
            TextField("Silky, bright, cozy, would order again...", text: Binding(
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
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Notes Section

struct NotesSection: View {
    @Binding var notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "Private note",
                subtitle: "Optional. Only you can see this."
            )
            
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
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Visibility Section

struct VisibilitySection: View {
    @Binding var visibility: VisitVisibility
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "Who can see this?",
                subtitle: "Private is safest; public can appear in Feed."
            )
            
            HStack(spacing: 12) {
                VisibilityButton(
                    title: "Private",
                    subtitle: "Only you",
                    systemImage: "lock.fill",
                    isSelected: visibility == .private,
                    action: { visibility = .private }
                )
                
                VisibilityButton(
                    title: "Friends",
                    subtitle: "Your circle",
                    systemImage: "person.2.fill",
                    isSelected: visibility == .friends,
                    action: { visibility = .friends }
                )
                
                VisibilityButton(
                    title: "Public",
                    subtitle: "Everyone",
                    systemImage: "globe",
                    isSelected: visibility == .everyone,
                    action: { visibility = .everyone }
                )
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct VisibilityButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .espressoBrown : .espressoBrown.opacity(0.6))

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
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
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
