//
//  ModernLogVisitView.swift
//  testMugshot
//
//  Modern 5-step log visit flow with animations
//

import SwiftUI
import PhotosUI

struct ModernLogVisitView: View {
    @ObservedObject var dataManager: DataManager
    var preselectedCafe: Cafe?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    // Step state
    @State private var currentStep: Int = 0
    
    // Step 1: Cafe
    @State private var selectedCafe: Cafe?
    @State private var cafeSearchText = ""
    
    // Step 2: Drink
    @State private var drinkType: DrinkType = .coffee
    @State private var specificDrink = ""
    
    // Step 3: Ratings
    @State private var flavorRating: Double = 0
    @State private var ambianceRating: Double = 0
    @State private var serviceRating: Double = 0
    
    // Step 4: Photos
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var posterPhotoIndex: Int = 0
    
    // Step 5: Caption & Publish
    @State private var caption = ""
    @State private var visibility: VisitVisibility = .everyone
    @State private var isSaving = false
    
    private var overallScore: Double {
        guard flavorRating > 0 || ambianceRating > 0 || serviceRating > 0 else { return 0 }
        let sum = flavorRating + ambianceRating + serviceRating
        let count = [flavorRating, ambianceRating, serviceRating].filter { $0 > 0 }.count
        return count > 0 ? sum / Double(count) : 0
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return selectedCafe != nil
        case 1: return !specificDrink.isEmpty
        case 2: return overallScore > 0
        case 3: return true // Photos optional
        case 4: return !caption.isEmpty
        default: return false
        }
    }
    
    var body: some View {
        ZStack {
            DS.Colors.dynamicBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Progress dots
                ModernStepProgress(currentStep: currentStep, totalSteps: 5)
                
                // Step content
                stepContent
                    .frame(maxHeight: .infinity)
                
                // Navigation buttons
                navigationButtons
            }
        }
        .onAppear {
            if let cafe = preselectedCafe {
                selectedCafe = cafe
                currentStep = 1
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button(action: {
                if currentStep > 0 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep -= 1
                    }
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch currentStep {
            case 0: step1CafeSelection
            case 1: step2DrinkDetails
            case 2: step3Ratings
            case 3: step4Photos
            case 4: step5Caption
            default: EmptyView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Step 1: Cafe Selection
    
    private var step1CafeSelection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Where did you go?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DS.Colors.dynamicTextSecondary)
                
                TextField("Search cafes...", text: $cafeSearchText)
                    .font(.system(size: 16))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                    .tint(DS.Colors.dynamicPrimaryAccent)
            }
            .padding()
            .themeAwareFloatingCard(cornerRadius: 20)
            
            // Cafe results
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(searchedCafes) { cafe in
                        Button(action: {
                            hapticsManager.mediumTap()
                            selectedCafe = cafe
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cafe.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(DS.Colors.dynamicTextPrimary)
                                    Text(cafe.address)
                                        .font(.system(size: 14))
                                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                
                                if selectedCafe?.id == cafe.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                                }
                            }
                            .padding()
                            .themeAwareFloatingCard(cornerRadius: 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var searchedCafes: [Cafe] {
        let cafes = dataManager.appData.cafes
        if cafeSearchText.isEmpty {
            return Array(cafes.sorted { $0.name < $1.name }.prefix(20))
        }
        return cafes.filter { $0.name.localizedCaseInsensitiveContains(cafeSearchText) }
    }
    
    // MARK: - Step 2: Drink Details
    
    private var step2DrinkDetails: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("What did you drink?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            // Drink type chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([DrinkType.coffee, .tea, .matcha, .chai, .other], id: \.self) { type in
                        Button(action: {
                            hapticsManager.lightTap()
                            drinkType = type
                        }) {
                            Text(type.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(drinkType == type ? .white : DS.Colors.dynamicTextPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(drinkType == type ? DS.Colors.dynamicPrimaryAccent : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(DS.Colors.dynamicTextSecondary, lineWidth: drinkType == type ? 0 : 1)
                                )
                                .cornerRadius(20)
                        }
                    }
                }
            }
            
            // Specific drink field
            VStack(alignment: .leading, spacing: 8) {
                Text("Specific drink?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DS.Colors.dynamicTextSecondary)
                
                TextField("e.g., Oat Milk Latte", text: $specificDrink)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                    .tint(DS.Colors.dynamicPrimaryAccent)
                    .padding()
                    .themeAwareFloatingCard(cornerRadius: 16)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Step 3: Ratings
    
    private var step3Ratings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("How was it?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                
                ModernAnimatedStarRating(category: "Flavor", rating: $flavorRating)
                ModernAnimatedStarRating(category: "Ambiance", rating: $ambianceRating)
                ModernAnimatedStarRating(category: "Service", rating: $serviceRating)
                
                // Overall score display
                if overallScore > 0 {
                    VStack(spacing: 8) {
                        Text(String(format: "%.1f", overallScore))
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                        
                        Text("OVERALL")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DS.Colors.dynamicTextTertiary)
                            .textCase(.uppercase)
                            .kerning(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Step 4: Photos
    
    private var step4Photos: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Share your sip")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            // Photo picker button
            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 48))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                    
                    Text("Add photos")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DS.Colors.dynamicTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(DS.Colors.dynamicTextSecondary, style: StrokeStyle(lineWidth: 2, dash: [8]))
                )
            }
            .onChange(of: selectedPhotos) { _, newPhotos in
                loadPhotos(from: newPhotos)
            }
            
            // Selected photos grid
            if !photoImages.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(photoImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(12)
                            
                            if posterPhotoIndex == index {
                                Text("Poster")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(DS.Colors.dynamicPrimaryAccent)
                                    .cornerRadius(6)
                                    .offset(x: -4, y: 4)
                            }
                        }
                        .onTapGesture {
                            posterPhotoIndex = index
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Step 5: Caption & Publish
    
    private var step5Caption: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Tell your story")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(DS.Colors.dynamicTextPrimary)
            
            // Caption field
            VStack(alignment: .trailing, spacing: 8) {
                TextField("What made this sip special?", text: $caption, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundColor(DS.Colors.dynamicTextPrimary)
                    .tint(DS.Colors.dynamicPrimaryAccent)
                    .lineLimit(3...6)
                    .padding()
                    .themeAwareFloatingCard(cornerRadius: 16)
                
                Text("\(caption.count)/200")
                    .font(.system(size: 13))
                    .foregroundColor(DS.Colors.dynamicTextSecondary)
            }
            .onChange(of: caption) { _, newValue in
                if newValue.count > 200 {
                    caption = String(newValue.prefix(200))
                }
            }
            
            // Privacy toggle
            VStack(alignment: .leading, spacing: 12) {
                Text("Who can see this?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DS.Colors.dynamicTextSecondary)
                
                HStack(spacing: 0) {
                    ForEach([VisitVisibility.friends, .everyone], id: \.self) { option in
                        Button(action: {
                            hapticsManager.lightTap()
                            visibility = option
                        }) {
                            Text(option == .friends ? "Friends" : "Everyone")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(visibility == option ? DS.Colors.dynamicTextPrimary : DS.Colors.dynamicTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(visibility == option ? DS.Colors.dynamicPrimaryAccent.opacity(0.2) : Color.clear)
                        }
                    }
                }
                .background(DS.Colors.dynamicCardBackgroundAlt)
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        VStack(spacing: 12) {
            if currentStep < 4 {
                // Next button
                Button(action: nextStep) {
                    Text("Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(canProceed ? .white : DS.Colors.dynamicTextTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canProceed ? DS.Colors.dynamicPrimaryAccent : DS.Colors.dynamicCardBackgroundAlt)
                        .cornerRadius(20)
                }
                .disabled(!canProceed)
            } else {
                // Publish button
                Button(action: publishVisit) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Publish Visit")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canProceed ? DS.Colors.dynamicPrimaryAccent : DS.Colors.dynamicCardBackgroundAlt)
                .cornerRadius(20)
                .disabled(!canProceed || isSaving)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    // MARK: - Actions
    
    private func nextStep() {
        hapticsManager.mediumTap()
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep += 1
        }
    }
    
    private func loadPhotos(from items: [PhotosPickerItem]) {
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            
            await MainActor.run {
                photoImages = images
            }
        }
    }
    
    private func publishVisit() {
        guard let cafe = selectedCafe,
              let userId = dataManager.appData.currentUser?.id else { return }
        
        isSaving = true
        hapticsManager.heavyTap()
        
        // Save photos to cache
        var photoPaths: [String] = []
        for image in photoImages {
            let photoId = UUID().uuidString
            PhotoCache.shared.store(image, forKey: photoId)
            photoPaths.append(photoId)
        }
        
        // Create visit
        let visit = Visit(
            cafeId: cafe.id,
            userId: userId,
            drinkType: drinkType,
            drinkSubtype: specificDrink,
            caption: caption,
            photos: photoPaths,
            posterPhotoIndex: posterPhotoIndex,
            ratings: [
                "flavor": flavorRating,
                "ambiance": ambianceRating,
                "service": serviceRating
            ],
            overallScore: overallScore,
            visibility: visibility
        )
        
        // Save to data manager
        dataManager.addVisit(visit)
        
        // Dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
        }
    }
}


