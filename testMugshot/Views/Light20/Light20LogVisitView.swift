//
//  Light20LogVisitView.swift
//  testMugshot
//
//  Light 2.0 log visit flow with clean cards and mint pill button
//  Wide "Post to Journal" CTA button
//

import SwiftUI
import PhotosUI

struct Light20LogVisitView: View {
    @ObservedObject var dataManager: DataManager
    var preselectedCafe: Cafe?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var currentStep: Int = 0
    @State private var selectedCafe: Cafe?
    @State private var cafeSearchText = ""
    @State private var drinkType: DrinkType = .coffee
    @State private var specificDrink = ""
    @State private var flavorRating: Double = 0
    @State private var ambianceRating: Double = 0
    @State private var serviceRating: Double = 0
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var posterPhotoIndex: Int = 0
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
        case 3: return true
        case 4: return !caption.isEmpty
        default: return false
        }
    }
    
    var body: some View {
        ZStack {
            DS.Colors.light20Background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                Light20StepProgress(currentStep: currentStep, totalSteps: 5)
                    .padding(.vertical, DS.Spacing.lg)
                
                ScrollView {
                    stepContent
                        .padding(.horizontal, DS.Spacing.pagePadding)
                }
                .frame(maxHeight: .infinity)
                
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
                Image(systemName: currentStep > 0 ? "chevron.left" : "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DS.Colors.light20CharcoalBlack)
            }
            
            Spacer()
            
            Text("Log a Visit")
                .light20Subheading()
            
            Spacer()
            
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.top, 60)
    }
    
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
    
    private var step1CafeSelection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Where did you go?")
                .light20Heading()
            
            TextField("Search for a cafe...", text: $cafeSearchText)
                .textFieldStyle(Light20TextFieldStyle())
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filteredCafes.prefix(10)) { cafe in
                        Button(action: {
                            hapticsManager.lightTap()
                            selectedCafe = cafe
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(cafe.name)
                                        .light20Subheading()
                                    Text(cafe.address)
                                        .light20Label()
                                }
                                Spacer()
                                if selectedCafe?.id == cafe.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(DS.Colors.light20MintPrimary)
                                }
                            }
                            .padding()
                        }
                        .light20FloatingCard()
                    }
                }
            }
        }
    }
    
    private var step2DrinkDetails: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("What'd you get?")
                .light20Heading()
            
            let drinkTypes = Array(DrinkType.allCases)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(drinkTypes, id: \.self) { type in
                        Button(action: {
                            drinkType = type
                        }) {
                            Text(type.rawValue)
                        }
                        .buttonStyle(Light20PillChipStyle(isSelected: drinkType == type))
                    }
                }
            }
            
            TextField("e.g. Iced vanilla latte, Cortado...", text: $specificDrink)
                .textFieldStyle(Light20TextFieldStyle())
        }
    }
    
    private var step3Ratings: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("How was it?")
                .light20Heading()
            
            VStack(spacing: 20) {
                RatingRow(label: "Ambiance", rating: $ambianceRating)
                RatingRow(label: "Presentation", rating: $serviceRating)
                RatingRow(label: "Taste", rating: $flavorRating)
            }
            .light20FloatingCard()
            .padding()
        }
    }
    
    private var step4Photos: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Show us!")
                .light20Heading()
            
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            ) {
                VStack(spacing: 16) {
                    Image(systemName: "camera")
                        .font(.system(size: 48))
                        .foregroundColor(DS.Colors.light20MintPrimary)
                    
                    Text("Add Photos")
                        .light20Subheading()
                    
                    Text("Up to 10 · Auto-optimized")
                        .light20Label()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .light20FloatingCard()
            }
        }
    }
    
    private var step5Caption: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Caption")
                .light20Heading()
            
            TextField("What made this moment special?", text: $caption, axis: .vertical)
                .textFieldStyle(Light20TextFieldStyle())
                .lineLimit(4...8)
            
            Text("Who can see?")
                .light20Subheading()
            
            HStack(spacing: 12) {
                ForEach([VisitVisibility.private, .friends, .everyone], id: \.self) { vis in
                    Button(action: {
                        visibility = vis
                    }) {
                        Text(vis.displayName)
                    }
                    .buttonStyle(Light20PillChipStyle(isSelected: visibility == vis))
                }
            }
        }
    }
    
    private var navigationButtons: some View {
        VStack(spacing: 12) {
            if currentStep == 4 {
                Button(action: {
                    Task {
                        await saveVisit()
                    }
                }) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Post to Journal")
                    }
                }
                .buttonStyle(Light20PrimaryButtonStyle(isEnabled: canProceed && !isSaving))
                .disabled(!canProceed || isSaving)
            } else {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep += 1
                    }
                }) {
                    Text("Continue")
                }
                .buttonStyle(Light20PrimaryButtonStyle(isEnabled: canProceed))
                .disabled(!canProceed)
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.bottom, 40)
    }
    
    private var filteredCafes: [Cafe] {
        if cafeSearchText.isEmpty {
            return Array(dataManager.appData.cafes.prefix(20))
        }
        return dataManager.appData.cafes.filter { $0.name.localizedCaseInsensitiveContains(cafeSearchText) }
    }
    
    private func saveVisit() async {
        guard let cafe = selectedCafe else { return }
        isSaving = true
        
        // TODO: Implement actual save logic
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isSaving = false
        dismiss()
    }
}

struct RatingRow: View {
    let label: String
    @Binding var rating: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .light20Subheading()
                Spacer()
                ForEach(1...5, id: \.self) { index in
                    Button(action: {
                        rating = Double(index)
                    }) {
                        Image(systemName: rating >= Double(index) ? "star.fill" : "star")
                            .foregroundColor(rating >= Double(index) ? DS.Colors.light20MintPrimary : DS.Colors.light20IconInactive)
                    }
                }
            }
        }
    }
}

extension VisitVisibility {
    var displayName: String {
        switch self {
        case .private: return "Private"
        case .friends: return "Friends"
        case .everyone: return "Public"
        }
    }
}


