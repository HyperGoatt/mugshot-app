//
//  AddTabView.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI
import MapKit
import CoreLocation
import Supabase
import AVFoundation

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
    @State private var pendingRemoteSubmission: PendingRemoteSubmission?
    @State private var uploadRecoveryMessage: String?
    @State private var showPhotoSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showCameraPermissionRecovery = false
    @State private var requestedRequirement: AddVisitRequirement?
    
    @StateObject private var searchService = MapSearchService()
    @StateObject private var cafeLocationManager = LocationManager()
    @State private var searchText = ""
    @State private var cafeSearchRegion = LogVisitView.defaultSearchRegion
    @State private var scrollToTop = false
    
    private static let defaultSearchRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var overallScore: Double {
        dataManager.appData.ratingTemplate.calculateOverallScore(ratings: ratings)
    }

    private var saveButtonTitle: String {
        if isSavingRemoteVisit {
            return photoImages.isEmpty ? "Saving..." : "Uploading..."
        }

        if pendingRemoteSubmission != nil {
            return "Retry saving"
        }

        if canSubmitVisit {
            return "Save to journal"
        }

        return firstIncompleteRequirement?.actionTitle ?? "Save to journal"
    }

    private var progressItems: [LogVisitProgressItem] {
        [
            LogVisitProgressItem(
                requirement: .photo,
                title: "Photo",
                systemImage: "photo.fill",
                isComplete: !photoImages.isEmpty
            ),
            LogVisitProgressItem(
                requirement: .cafe,
                title: "Cafe",
                systemImage: "mappin.and.ellipse",
                isComplete: selectedCafe != nil
            ),
            LogVisitProgressItem(
                requirement: .drink,
                title: "Drink",
                systemImage: "cup.and.saucer.fill",
                isComplete: drinkDetails.remoteTrimmedNonEmpty != nil &&
                    (drinkType != .other || customDrinkType.remoteTrimmedNonEmpty != nil)
            ),
            LogVisitProgressItem(
                requirement: .rating,
                title: "Rating",
                systemImage: "star.fill",
                isComplete: overallScore > 0
            ),
            LogVisitProgressItem(
                requirement: .caption,
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
        isSavingRemoteVisit
    }

    private var firstIncompleteRequirement: AddVisitRequirement? {
        progressItems.first(where: { !$0.isComplete })?.requirement
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
                .toolbarBackground(Color.creamWhite, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    stickySaveFooter
                }
                .sheet(isPresented: $showCustomizeRatings) {
                    CustomizeRatingsView(
                        dataManager: dataManager,
                        isPresented: $showCustomizeRatings
                    )
                }
                .confirmationDialog(
                    "Add a photo",
                    isPresented: $showPhotoSourceDialog,
                    titleVisibility: .visible
                ) {
                    Button("Take Photo") {
                        requestCamera()
                    }
                    Button("Choose from Library") {
                        showPhotoLibrary = true
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("A photo gives this sip its cover. You can add up to ten.")
                }
                .sheet(isPresented: $showCamera) {
                    CameraCaptureView(image: Binding(
                        get: { nil },
                        set: { image in
                            guard let image else { return }
                            appendPhotos([image])
                        }
                    ), isPresented: $showCamera)
                }
                .sheet(isPresented: $showPhotoLibrary) {
                    PhotoLibraryPickerView(
                        images: Binding(
                            get: { [] },
                            set: { images in appendPhotos(images) }
                        ),
                        isPresented: $showPhotoLibrary,
                        maximumSelectionCount: max(1, 10 - photoImages.count)
                    )
                }
                .alert("Camera access is off", isPresented: $showCameraPermissionRecovery) {
                    Button("Choose from Library") {
                        showPhotoLibrary = true
                    }
                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Allow Camera access in Settings to take a new sip photo, or choose one from your library.")
                }
                .onAppear {
                    if let cafe = preselectedCafe {
                        selectedCafe = cafe
                    }
                    initializeRatings()
                    initializeCafeSearchLocationIfAvailable()
                }
                .onChange(of: cafeLocationManager.location) { _, location in
                    guard let location else { return }
                    updateCafeSearchRegion(for: location)
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
                .fullScreenCover(item: $savedRemoteVisit, onDismiss: {
                    resetForm()
                    tabCoordinator.selectedTab = 4
                    dismiss()
                }) { visit in
                    RemoteVisitDetailView(
                        visitId: visit.id,
                        initialSummary: visit,
                        currentUserId: authModel.authenticatedUser?.id,
                        dataManager: dataManager,
                        justPosted: true
                    )
                }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            // Light background
            Color.creamWhite
                .ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    formContent
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
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
                .onChange(of: requestedRequirement) { _, requirement in
                    guard let requirement else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(requirement.rawValue, anchor: .top)
                    }
                    requestedRequirement = nil
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
                isRemoteMode: authModel.authenticatedUser != nil,
                onSelect: { requestedRequirement = $0 }
            )

            PhotosSection(
                photoImages: $photoImages,
                posterPhotoIndex: $posterPhotoIndex,
                onAddPhoto: { showPhotoSourceDialog = true }
            )
            .id(AddVisitRequirement.photo.rawValue)

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
                searchRegion: cafeSearchRegion,
                searchAreaDescription: cafeSearchAreaDescription,
                locationActionTitle: cafeLocationActionTitle,
                onLocationAction: useCurrentLocationForCafeSearch
            )
            .id(AddVisitRequirement.cafe.rawValue)
            
            // Drink Type
            DrinkTypeSection(
                drinkType: $drinkType,
                customDrinkType: $customDrinkType
            )

            DrinkDetailsSection(drinkDetails: $drinkDetails)
                .id(AddVisitRequirement.drink.rawValue)

            // Ratings
            RatingsSection(
                dataManager: dataManager,
                ratings: $ratings,
                overallScore: overallScore,
                showCustomize: $showCustomizeRatings
            )
            .id(AddVisitRequirement.rating.rawValue)
            
            // Caption
            CaptionSection(caption: $caption)
                .id(AddVisitRequirement.caption.rawValue)
            
            // Notes
            NotesSection(notes: $notes)
            
            // Visibility
            VisibilitySection(visibility: $visibility)
            
            // Validation errors
            if !validationErrors.isEmpty {
                ValidationErrorCard(errors: validationErrors)
            }
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
        pendingRemoteSubmission = nil
        uploadRecoveryMessage = nil

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
    
    private func appendPhotos(_ images: [UIImage]) {
        let remaining = max(0, 10 - photoImages.count)
        photoImages.append(contentsOf: images.prefix(remaining))
        if !photoImages.isEmpty && posterPhotoIndex >= photoImages.count {
            posterPhotoIndex = 0
        }
    }

    private var cafeSearchAreaDescription: String {
        if cafeLocationManager.location != nil {
            return "Searching around your current location"
        }

        switch cafeLocationManager.authorizationStatus {
        case .denied, .restricted:
            return "Location is off — search by cafe or neighborhood"
        case .notDetermined:
            return "Search nearby or type a cafe name"
        default:
            return "Finding your current location…"
        }
    }

    private var cafeLocationActionTitle: String {
        switch cafeLocationManager.authorizationStatus {
        case .denied, .restricted:
            return "Settings"
        case .authorizedAlways, .authorizedWhenInUse:
            return cafeLocationManager.location == nil ? "Find me" : "Near me"
        case .notDetermined:
            return "Near me"
        @unknown default:
            return "Near me"
        }
    }

    private func initializeCafeSearchLocationIfAvailable() {
        let status = cafeLocationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        cafeLocationManager.startUpdatingLocation()
        if let location = cafeLocationManager.location {
            updateCafeSearchRegion(for: location)
        }
    }

    private func useCurrentLocationForCafeSearch() {
        switch cafeLocationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            cafeLocationManager.requestCurrentLocation()
            if let location = cafeLocationManager.location {
                updateCafeSearchRegion(for: location)
            }
        case .notDetermined:
            cafeLocationManager.requestLocationPermission()
        case .denied, .restricted:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        @unknown default:
            break
        }
    }

    private func updateCafeSearchRegion(for location: CLLocation) {
        cafeSearchRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchService.search(query: searchText, region: cafeSearchRegion)
        }
    }

    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        showCameraPermissionRecovery = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionRecovery = true
        @unknown default:
            showCameraPermissionRecovery = true
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

        guard AddVisitValidation.hasRequiredPhoto(
            photoCount: photoImages.count
        ) else {
            validationErrors.append(AddVisitValidation.photoRequiredMessage)
            scrollToTop = true
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

    private var stickySaveFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let uploadRecoveryMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundColor(.mugshotSage)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your draft is safe")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.espressoBrown)
                        Text(uploadRecoveryMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button("Discard", role: .destructive) {
                        Task { await discardPendingSubmission() }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .disabled(isSavingRemoteVisit)
                }
                .padding(12)
                .background(Color.sandBeige.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let requirement = firstIncompleteRequirement,
               pendingRemoteSubmission == nil {
                Text("Next: \(requirement.guidance)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondaryText)
            }

            Button {
                handleStickySaveAction()
            } label: {
                SaveVisitButtonLabel(
                    title: saveButtonTitle,
                    isSaving: isSavingRemoteVisit,
                    photoCount: photoImages.count
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity)
            .disabled(isSaveButtonDisabled)
            .accessibilityHint(
                canSubmitVisit || pendingRemoteSubmission != nil
                    ? "Saves this sip to your journal"
                    : "Takes you to the next required detail"
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().overlay(Color.sandBeige)
        }
    }

    private func handleStickySaveAction() {
        guard !isSavingRemoteVisit else { return }

        if pendingRemoteSubmission != nil || canSubmitVisit {
            saveVisit()
            return
        }

        guard let requirement = firstIncompleteRequirement else { return }
        if requirement == .photo {
            showPhotoSourceDialog = true
        } else {
            requestedRequirement = requirement
        }
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
            var attempt = pendingRemoteSubmission
            if attempt == nil {
                let remoteVisit = try await service.createVisit(
                    userId: authenticatedUser.id,
                    cafe: cafe,
                    drinkType: drinkType,
                    customDrinkType: customDrinkType,
                    drinkSubtype: drinkDetails,
                    caption: caption,
                    notes: notes,
                    // An upload draft is intentionally private until its media and
                    // publication state are both complete.
                    visibility: .private,
                    ratings: ratings,
                    ratingTemplate: dataManager.appData.ratingTemplate,
                    uploadState: .uploading
                )
                attempt = PendingRemoteSubmission(visit: remoteVisit, uploadedPhotos: nil)
                pendingRemoteSubmission = attempt
            }

            guard var submission = attempt else { return }
            if submission.uploadedPhotos == nil {
                let uploadService = VisitPhotoUploadService(client: client)
                let photos = try await uploadService.uploadPhotos(
                    userId: authenticatedUser.id,
                    visitId: submission.visit.id,
                    images: photoImages,
                    posterPhotoIndex: posterPhotoIndex
                )
                submission.uploadedPhotos = photos
                pendingRemoteSubmission = submission
            }

            guard let uploadedPhotos = submission.uploadedPhotos else { return }
            _ = try await service.attachPhotoURLs(
                visitId: submission.visit.id,
                photoURLs: uploadedPhotos.publicURLs,
                posterPhotoIndex: uploadedPhotos.posterPhotoIndex
            )
            let remoteVisit = try await service.finalizeVisit(
                visitId: submission.visit.id,
                userId: authenticatedUser.id,
                visibility: visibility
            )

            isSavingRemoteVisit = false
            pendingRemoteSubmission = nil
            uploadRecoveryMessage = nil
            mirrorRemoteCafe(from: remoteVisit)
            savedRemoteVisit = remoteVisit
        } catch {
            isSavingRemoteVisit = false
            if let attempt = pendingRemoteSubmission {
                let client = try? SupabaseClientProvider.shared.client()
                if let client {
                    try? await VisitService(client: client).markVisitUploadFailed(
                        visitId: attempt.visit.id,
                        userId: authenticatedUser.id
                    )
                }
                uploadRecoveryMessage = MugshotUserFacingError.message(for: error, context: .photoUpload)
            } else {
                validationErrors = [MugshotUserFacingError.message(for: error, context: .loading)]
                scrollToTop = true
            }
        }
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

    @MainActor
    private func discardPendingSubmission() async {
        guard let submission = pendingRemoteSubmission,
              let authenticatedUser = authModel.authenticatedUser else {
            return
        }

        isSavingRemoteVisit = true
        do {
            let client = try SupabaseClientProvider.shared.client()
            if let photos = submission.uploadedPhotos {
                try await VisitPhotoUploadService(client: client).deletePhotos(at: photos.objectPaths)
            }
            try await VisitService(client: client).deleteVisit(
                visitId: submission.visit.id,
                userId: authenticatedUser.id
            )
            resetForm()
        } catch {
            isSavingRemoteVisit = false
            uploadRecoveryMessage = MugshotUserFacingError.message(for: error, context: .photoUpload)
        }
    }
}

enum AddVisitRequirement: String, CaseIterable, Identifiable {
    case photo
    case cafe
    case drink
    case rating
    case caption

    var id: String { rawValue }

    var actionTitle: String {
        switch self {
        case .photo: return "Add a photo"
        case .cafe: return "Choose a cafe"
        case .drink: return "Add drink details"
        case .rating: return "Rate this sip"
        case .caption: return "Write a caption"
        }
    }

    var guidance: String {
        switch self {
        case .photo: return "add a sip photo"
        case .cafe: return "choose where it was from"
        case .drink: return "name the drink"
        case .rating: return "add a taste rating"
        case .caption: return "write a tasting note"
        }
    }
}

private struct PendingRemoteSubmission {
    let visit: RemoteVisitSummary
    var uploadedPhotos: UploadedVisitPhotos?
}

enum AddVisitValidation {
    static let photoRequiredMessage = "Add a sip photo so this memory has a cover."

    static func hasRequiredPhoto(photoCount: Int) -> Bool {
        photoCount > 0
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
                    Text("Log a sip")
                        .mugshotDisplay(size: 34)
                        .foregroundColor(.espressoBrown)

                    Text("Capture the sip, rate the moment, and save what you want to remember.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(spacing: 5) {
                    Image(systemName: completedCount == totalCount ? "checkmark" : "sparkles")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.foamWhite)
                        .frame(width: 42, height: 42)
                        .background(Color.mugshotSage)
                        .clipShape(Circle())

                    Text(completedCount == totalCount ? "Ready" : "Draft")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.espressoBrown.opacity(0.6))
                }
                .accessibilityLabel(completedCount == totalCount ? "Sip ready to save" : "Sip draft")
            }

            HStack(spacing: 8) {
                LogVisitHeroPill(
                    title: hasPhoto ? "Cover chosen" : "Add a cover",
                    systemImage: hasPhoto ? "photo.fill" : "camera"
                )

                LogVisitHeroPill(
                    title: isRemoteMode ? "Shareable sip" : "Taste journal",
                    systemImage: isRemoteMode ? "sparkles" : "book.closed.fill"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.sandBeige.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.espressoBrown)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
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
                    title: photoCount == 0 ? "Add cover" : "\(photoCount) photo\(photoCount == 1 ? "" : "s")",
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
        .background(isComplete ? Color.mugshotSage.opacity(0.22) : Color.creamWhite.opacity(0.88))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isComplete ? Color.mugshotSage.opacity(0.55) : Color.sandBeige.opacity(0.82), lineWidth: 1)
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
                        .tint(.foamWhite)
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
    let requirement: AddVisitRequirement
    let title: String
    let systemImage: String
    let isComplete: Bool

    var id: String { title }
}

struct LogVisitProgressCard: View {
    let items: [LogVisitProgressItem]
    let isSaving: Bool
    let isRemoteMode: Bool
    let onSelect: (AddVisitRequirement) -> Void

    private var completedCount: Int {
        items.filter(\.isComplete).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: completedCount == items.count ? "checkmark.circle.fill" : "leaf.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isSaving ? "Saving your sip" : (completedCount == items.count ? "Ready to log" : "Build your sip"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.espressoBrown)

                    Text(isRemoteMode ? "Your sip stays private until its photo is safely saved, then appears in your journal." : "This saves to your taste journal on this device.")
                        .font(.system(size: 13))
                        .foregroundColor(.espressoBrown.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            ProgressView(value: Double(completedCount), total: Double(max(items.count, 1)))
                .tint(.mugshotSage)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(items) { item in
                    Button {
                        onSelect(item.requirement)
                    } label: {
                        LogVisitProgressChip(item: item)
                    }
                    .buttonStyle(.plain)
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
        .background(item.isComplete ? Color.mugshotSage.opacity(0.18) : Color.sandBeige.opacity(0.32))
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
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
    let searchAreaDescription: String
    let locationActionTitle: String
    let onLocationAction: () -> Void
    
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
                        .mugshotFormField()
                        
                        Button("Cancel") {
                            searchText = ""
                            searchService.cancelSearch()
                            isSearchActive = false
                        }
                        .foregroundColor(.espressoBrown)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.mugshotSage)

                        Text(searchAreaDescription)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondaryText)

                        Spacer(minLength: 8)

                        Button(locationActionTitle, action: onLocationAction)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.mugshotSage)
                            .accessibilityHint("Updates cafe search to use your current location")
                    }
                    .padding(.horizontal, 4)
                    
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
                                        .foregroundColor(.mugshotSage)
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
                    .mugshotFormField()
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
                                        Text(mapItem.name ?? "Cafe")
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
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
                            .foregroundColor(.mugshotSage)
                        Text("Use \(cafeName)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                        Spacer()
                    }
                    .padding()
                    .background(Color.creamWhite)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                            .stroke(Color.mugshotLine, lineWidth: 1)
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
                    .mugshotFormField()
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
            .background(isSelected ? Color.mugshotSage.opacity(0.28) : Color.sandBeige.opacity(0.24))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.mugshotSage : Color.sandBeige.opacity(0.7), lineWidth: 1)
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
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .mugshotFormField()
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Photos Section

struct PhotosSection: View {
    @Binding var photoImages: [UIImage]
    @Binding var posterPhotoIndex: Int
    let onAddPhoto: () -> Void

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
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.espressoBrown)

                    Text(photoImages.isEmpty ? "Pick a cover that brings the sip back." : "Choose the poster photo for this visit.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                }

                Spacer(minLength: 12)

                Text("\(photoImages.count)/10")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.roastBrown)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.sandBeige.opacity(0.68))
                    .clipShape(Capsule())
            }
            
            if photoImages.isEmpty {
                Button(action: onAddPhoto) {
                    photoPickerLabel
                }
                .buttonStyle(.plain)
            } else {
                Image(uiImage: photoImages[safePosterIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Poster photo")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.creamWhite)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.espressoBrown.opacity(0.72))
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
                                            .foregroundColor(.mugshotSage)
                                            .background(Color.foamWhite)
                                            .clipShape(Circle())
                                            .padding(5)
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                                        .stroke(index == safePosterIndex ? Color.mugshotSage : Color.clear, lineWidth: 2)
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
                            Button(action: onAddPhoto) {
                                RoundedRectangle(cornerRadius: DesignSystem.smallCornerRadius)
                                    .fill(Color.sandBeige.opacity(0.62))
                                    .frame(width: 86, height: 86)
                                    .overlay(
                                        VStack(spacing: 5) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 17, weight: .semibold))
                                            Text("Add")
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        .foregroundColor(.roastBrown.opacity(0.72))
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
                    .fill(Color.sandBeige.opacity(0.62))
                    .frame(height: 150)

                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.roastBrown.opacity(0.58))

                    Text("Add a photo")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    Text("A clear cover makes your journal easier to scan.")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Add a photo to give this sip a cover.")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.roastBrown.opacity(0.78))
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.foamWhite)
        .cornerRadius(DesignSystem.Radius.heroCard)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundColor(.mugshotLine)
        )
    }

    private func removePhoto(at index: Int) {
        guard photoImages.indices.contains(index) else {
            return
        }

        photoImages.remove(at: index)

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
                    .foregroundColor(.mugshotSage)
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
                    .background(Color.mugshotSage.opacity(0.24))
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
                            .foregroundColor(.mugshotSage)
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
                .mugshotFormField()
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
                .mugshotFormField()
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
            .background(isSelected ? Color.mugshotSage.opacity(0.2) : Color.sandBeige.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                    .stroke(isSelected ? Color.mugshotSage : Color.clear, lineWidth: 2)
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
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.espressoBrown.opacity(0.6))
                        
                        TextField("Search cafes...", text: $searchText)
                            .foregroundColor(.inputText)
                            .tint(.mugshotSage)
                            .accentColor(.mugshotSage)
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
                    .mugshotFormField()
                }
                .padding()
                
                // Results
                if searchService.isSearching {
                    ProgressView()
                        .padding()
                } else if let error = searchService.searchError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.roastBrown.opacity(0.5))
                        Text(error)
                            .foregroundColor(.secondaryText)
                    }
                    .padding()
                } else if searchService.searchResults.isEmpty && !searchText.isEmpty {
                    Text("No results found")
                        .foregroundColor(.secondaryText)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                        ForEach(searchService.searchResults, id: \.self) { mapItem in
                            Button(action: {
                                let cafe = dataManager.findOrCreateCafe(from: mapItem)
                                selectedCafe = cafe
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mapItem.name ?? "Cafe")
                                            .foregroundColor(.espressoBrown)
                                        if let address = formatAddress(from: mapItem.placemark), !address.isEmpty {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(.tertiaryText)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.tertiaryText)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(Color.foamWhite)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .padding(.leading, 16)
                        }
                        }
                    }
                }
            }
            .background(Color.creamWhite)
            .navigationTitle("Search cafes")
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tune your taste score")
                            .mugshotDisplay(size: 28)
                            .foregroundColor(.espressoBrown)

                        Text("Give more weight to what matters most in your sip memories.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)
                    
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
                            Text("Add taste note")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.mugshotSage.opacity(0.22))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.mugshotSage.opacity(0.38), lineWidth: 1))
                    }
                }
                .padding()
            }
            .background(Color.creamWhite)
            .navigationTitle("Taste Weights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
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
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 34, height: 34)
                    .background(Color.mugshotSage.opacity(0.16))
                    .clipShape(Circle())

                TextField("Category name", text: $category.name)
                    .mugshotFormField()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red.opacity(0.82))
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Circle())
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Influence")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.espressoBrown.opacity(0.72))

                    Spacer()

                    Text(formatWeight(weightMultiplier))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.mugshotSage.opacity(0.22))
                        .clipShape(Capsule())
                }
                
                Slider(value: $weightMultiplier, in: 0.5...3.0, step: 0.5)
                    .tint(.mugshotSage)
                    .onChange(of: weightMultiplier) { oldValue, newValue in
                        // Store as multiplier (will be normalized when template is saved)
                        category.weight = newValue
                    }
            }
        }
        .padding(14)
        .cardStyle(radius: DesignSystem.Radius.card, shadow: DesignSystem.subtleShadow)
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
