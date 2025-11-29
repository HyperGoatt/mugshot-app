//
//  PostcardPreviewSheet.swift
//  testMugshot
//
//  Preview modal for Mugshot Postcards with multi-photo carousel.
//  Shows individual postcards for each photo + a collage option.
//

import SwiftUI
import UIKit
import Photos

/// Represents a postcard variant in the carousel
enum PostcardItem: Identifiable, Equatable {
    case single(index: Int, image: UIImage)
    case collage(images: [UIImage])
    
    var id: String {
        switch self {
        case .single(let index, _):
            return "single-\(index)"
        case .collage:
            return "collage"
        }
    }
    
    static func == (lhs: PostcardItem, rhs: PostcardItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Preview sheet for viewing and sharing postcards
struct PostcardPreviewSheet: View {
    let visit: Visit
    let cafe: Cafe?
    let authorImage: UIImage?
    let authorAvatarURL: String?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var hapticsManager = HapticsManager.shared
    
    // All loaded photos
    @State private var loadedPhotos: [UIImage] = []
    @State private var isLoadingPhotos = true
    
    // Postcard items (singles + optional collage)
    @State private var postcardItems: [PostcardItem] = []
    
    // Selection state
    @State private var selectedItemId: String?
    
    // Rendering state for selected item
    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    
    // Share states
    @State private var showShareSheet = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var showInstagramError = false
    @State private var instagramErrorMessage = ""
    
    // Variant
    @State private var selectedVariant: MugshotPostcardView.PostcardVariant = .light
    
    // MARK: - Computed Properties
    
    private var postcardData: PostcardData {
        PostcardData(
            cafeName: cafe?.name ?? "Unknown Café",
            cafeCity: cafe?.city,
            visitDate: visit.createdAt,
            drinkType: visit.drinkType,
            customDrinkType: visit.customDrinkType,
            overallScore: visit.overallScore,
            caption: visit.caption,
            photoImage: nil,
            authorDisplayName: visit.authorDisplayNameOrUsername,
            authorUsername: visit.authorUsernameHandle,
            authorAvatarImage: authorImage,
            authorAvatarURL: authorAvatarURL
        )
    }
    
    private var selectedItem: PostcardItem? {
        postcardItems.first { $0.id == selectedItemId }
    }
    
    /// Calculate even-rounded photo count for collage
    private var collagePhotoCount: Int {
        let count = loadedPhotos.count
        return count >= 2 ? (count / 2) * 2 : 0 // Round down to nearest even
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.screenBackground
                    .ignoresSafeArea()
                
                VStack(spacing: DS.Spacing.md) {
                    // Variant picker
                    variantPicker
                    
                    // Carousel of postcards
                    if isLoadingPhotos {
                        loadingView
                    } else {
                        postcardCarousel
                    }
                    
                    Spacer()
                    
                    // Action buttons (only when item selected)
                    if selectedItemId != nil {
                        actionButtons
                    } else {
                        selectPrompt
                    }
                }
                .padding(.top, DS.Spacing.md)
                
                // Rendering overlay
                if isRendering {
                    renderingOverlay
                }
            }
            .navigationTitle("Share Postcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.textSecondary)
                }
            }
        }
        .task {
            await loadAllPhotos()
            buildPostcardItems()
        }
        .onChange(of: selectedVariant) { _, _ in
            if selectedItemId != nil {
                renderSelectedPostcard()
            }
        }
        .onChange(of: selectedItemId) { _, _ in
            renderSelectedPostcard()
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedImage {
                ShareSheet(items: [image])
            }
        }
        .alert("Saved!", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your postcard has been saved to Photos.")
        }
        .alert("Save Failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to save to Photos. Please check your privacy settings.")
        }
        .alert("Instagram", isPresented: $showInstagramError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(instagramErrorMessage)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(DS.Colors.primaryAccent)
            Text("Loading photos...")
                .font(DS.Typography.subheadline())
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
        }
    }
    
    // MARK: - Variant Picker
    
    private var variantPicker: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach([MugshotPostcardView.PostcardVariant.light, .dark], id: \.self) { variant in
                Button {
                    hapticsManager.selectionChanged()
                    selectedVariant = variant
                } label: {
                    Text(variant == .light ? "Light" : "Dark")
                        .font(DS.Typography.subheadline(.medium))
                        .foregroundColor(selectedVariant == variant ? DS.Colors.textOnMint : DS.Colors.textSecondary)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            selectedVariant == variant
                                ? DS.Colors.primaryAccent
                                : DS.Colors.cardBackgroundAlt
                        )
                        .cornerRadius(DS.Radius.pill)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
    }
    
    // MARK: - Postcard Carousel
    
    private var postcardCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.lg) {
                ForEach(postcardItems) { item in
                    postcardCard(for: item)
                        .onTapGesture {
                            hapticsManager.lightTap()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedItemId = item.id
                            }
                        }
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.vertical, DS.Spacing.sm)
        }
    }
    
    @ViewBuilder
    private func postcardCard(for item: PostcardItem) -> some View {
        let isSelected = item.id == selectedItemId
        
        VStack(spacing: DS.Spacing.sm) {
            // Preview card
            GeometryReader { geo in
                Group {
                    switch item {
                    case .single(_, let image):
                        MugshotPostcardView(
                            data: postcardData,
                            visitPhoto: image,
                            variant: selectedVariant
                        )
                    case .collage(let images):
                        CollagePostcardView(
                            data: postcardData,
                            photos: images,
                            variant: selectedVariant
                        )
                    }
                }
                .scaleEffect(geo.size.width / 1080.0)
                .frame(width: geo.size.width, height: geo.size.width * (1920.0/1080.0))
                .position(x: geo.size.width/2, y: (geo.size.width * (1920.0/1080.0))/2)
            }
            .frame(width: isSelected ? 280 : 240, height: isSelected ? 498 : 427)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(isSelected ? DS.Colors.primaryAccent : Color.clear, lineWidth: 4)
            )
            .shadow(color: .black.opacity(isSelected ? 0.25 : 0.1), radius: isSelected ? 20 : 10, x: 0, y: isSelected ? 10 : 5)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            
            // Label
            Text(itemLabel(for: item))
                .font(DS.Typography.caption1(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
        }
    }
    
    private func itemLabel(for item: PostcardItem) -> String {
        switch item {
        case .single(let index, _):
            return "Photo \(index + 1)"
        case .collage(let images):
            return "Collage (\(images.count))"
        }
    }
    
    // MARK: - Select Prompt
    
    private var selectPrompt: some View {
        Text("Tap a postcard to select it")
            .font(DS.Typography.subheadline())
            .foregroundColor(DS.Colors.textSecondary)
            .padding(.bottom, DS.Spacing.xxl * 2)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: DS.Spacing.md) {
            // Primary: Share button
            Button {
                hapticsManager.mediumTap()
                showShareSheet = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Share")
                        .font(DS.Typography.buttonLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.primaryAccent)
                .foregroundColor(DS.Colors.textOnMint)
                .cornerRadius(DS.Radius.primaryButton)
            }
            .disabled(renderedImage == nil)
            .opacity(renderedImage == nil ? 0.5 : 1)
            
            // Secondary row: Instagram + Save
            HStack(spacing: DS.Spacing.md) {
                Button {
                    hapticsManager.mediumTap()
                    shareToInstagram()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Instagram Story")
                            .font(DS.Typography.subheadline(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.cardBackground)
                    .foregroundColor(DS.Colors.textPrimary)
                    .cornerRadius(DS.Radius.primaryButton)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.primaryButton)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                .disabled(renderedImage == nil)
                .opacity(renderedImage == nil ? 0.5 : 1)
                
                Button {
                    hapticsManager.lightTap()
                    saveToPhotos()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Save")
                            .font(DS.Typography.subheadline(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.cardBackground)
                    .foregroundColor(DS.Colors.textPrimary)
                    .cornerRadius(DS.Radius.primaryButton)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.primaryButton)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                .disabled(renderedImage == nil)
                .opacity(renderedImage == nil ? 0.5 : 1)
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.bottom, DS.Spacing.xxl)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Rendering Overlay
    
    private var renderingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: DS.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(DS.Colors.primaryAccent)
                
                Text("Generating postcard...")
                    .font(DS.Typography.subheadline())
                    .foregroundColor(.white)
            }
            .padding(DS.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // MARK: - Photo Loading
    
    @MainActor
    private func loadAllPhotos() async {
        print("📸 [PostcardCarousel] Loading all photos for visit...")
        isLoadingPhotos = true
        
        var photos: [UIImage] = []
        
        for (index, photoPath) in visit.photos.enumerated() {
            print("📸 [PostcardCarousel] Loading photo \(index + 1)/\(visit.photos.count): \(photoPath)")
            
            // Try local cache first
            if let cachedImage = PhotoCache.shared.retrieve(forKey: photoPath) {
                print("📸 [PostcardCarousel] ✅ Found in cache")
                photos.append(cachedImage)
                continue
            }
            
            // Try remote URL
            if let remoteURLString = visit.remotePhotoURLByKey[photoPath],
               let remoteURL = URL(string: remoteURLString),
               let image = await downloadImage(from: remoteURL) {
                print("📸 [PostcardCarousel] ✅ Downloaded from remote")
                photos.append(image)
                continue
            }
            
            print("📸 [PostcardCarousel] ⚠️ Could not load photo \(index + 1)")
        }
        
        // If no photos loaded, try posterPhotoURL as fallback
        if photos.isEmpty, let posterURLString = visit.posterPhotoURL,
           let posterURL = URL(string: posterURLString),
           let image = await downloadImage(from: posterURL) {
            print("📸 [PostcardCarousel] ✅ Loaded poster fallback")
            photos.append(image)
        }
        
        loadedPhotos = photos
        isLoadingPhotos = false
        print("📸 [PostcardCarousel] Loaded \(photos.count) photos total")
    }
    
    private func downloadImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("📸 [PostcardCarousel] ❌ Download failed: \(error)")
            return nil
        }
    }
    
    private func buildPostcardItems() {
        var items: [PostcardItem] = []
        
        // Add individual postcards for each photo
        for (index, photo) in loadedPhotos.enumerated() {
            items.append(.single(index: index, image: photo))
        }
        
        // Add collage if we have at least 2 photos
        let collageCount = collagePhotoCount
        if collageCount >= 2 {
            let collagePhotos = Array(loadedPhotos.prefix(collageCount))
            items.append(.collage(images: collagePhotos))
        }
        
        postcardItems = items
        
        // Auto-select first item if available
        if let firstItem = items.first {
            selectedItemId = firstItem.id
        }
        
        print("📸 [PostcardCarousel] Built \(items.count) postcard items (collage: \(collageCount >= 2 ? "yes" : "no"))")
    }
    
    // MARK: - Rendering
    
    private func renderSelectedPostcard() {
        guard let item = selectedItem else {
            renderedImage = nil
            return
        }
        
        isRendering = true
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            
            switch item {
            case .single(_, let image):
                renderedImage = PostcardRenderer.renderPostcard(
                    data: postcardData,
                    visitPhoto: image,
                    variant: selectedVariant
                )
            case .collage(let images):
                renderedImage = renderCollagePostcard(photos: images)
            }
            
            isRendering = false
        }
    }
    
    private func renderCollagePostcard(photos: [UIImage]) -> UIImage? {
        let collageView = CollagePostcardView(
            data: postcardData,
            photos: photos,
            variant: selectedVariant
        )
        return PostcardRenderer.render(collageView, size: PostcardRenderer.storiesSize)
    }
    
    // MARK: - Share Actions
    
    private func shareToInstagram() {
        guard let image = renderedImage else { return }
        
        InstagramStoriesService.shareToStories(image: image) { result in
            switch result {
            case .success:
                hapticsManager.playSuccess()
            case .failure(let error):
                hapticsManager.playError()
                instagramErrorMessage = error.localizedDescription
                showInstagramError = true
            }
        }
    }
    
    private func saveToPhotos() {
        guard let image = renderedImage else { return }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    hapticsManager.playSuccess()
                    showSaveSuccess = true
                default:
                    hapticsManager.playError()
                    showSaveError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PostcardPreviewSheet(
        visit: Visit(
            cafeId: UUID(),
            userId: UUID(),
            drinkType: .coffee,
            customDrinkType: "Cortado",
            caption: "Amazing coffee!",
            photos: ["photo1", "photo2", "photo3"],
            ratings: ["Taste": 4.5],
            overallScore: 4.2,
            authorDisplayName: "Joe Rosso",
            authorUsername: "joerosso"
        ),
        cafe: Cafe(
            name: "Sightglass Coffee",
            city: "San Francisco"
        ),
        authorImage: nil,
        authorAvatarURL: nil
    )
}
