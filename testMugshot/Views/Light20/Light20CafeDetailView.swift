//
//  Light20CafeDetailView.swift
//  testMugshot
//
//  Light 2.0 cafe detail with parallax hero and large star rating
//  Floating "Log a Visit" CTA
//

import SwiftUI

struct Light20CafeDetailView: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    var onLogVisitRequested: ((Cafe) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVisit: Visit?
    
    private var userVisits: [Visit] {
        dataManager.appData.visits
            .filter { $0.cafeId == cafe.id }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    private var averageRating: Double {
        guard !userVisits.isEmpty else { return 0 }
        let total = userVisits.reduce(0.0) { partial, visit in
            partial + visit.overallScore
        }
        return total / Double(userVisits.count)
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Parallax hero image
                        if let firstVisit = userVisits.first,
                           let posterPhoto = firstVisit.photos.first {
                            PhotoImageView(
                                photoPath: posterPhoto,
                                remoteURL: firstVisit.remotePhotoURLByKey[posterPhoto]
                            )
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(height: 250)
                            .clipped()
                            .light20ParallaxOffset(offset: geometry.frame(in: .global).minY)
                        } else {
                            Rectangle()
                                .fill(DS.Colors.light20Surface)
                                .frame(height: 250)
                                .overlay(
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(DS.Colors.light20IconInactive)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            // Cafe info
                            VStack(alignment: .leading, spacing: 8) {
                                Text(cafe.name)
                                    .light20Heading()
                                
                                Text(cafe.address)
                                    .light20Label()
                                
                                if averageRating > 0 {
                                    Light20AnimatedStarRating(rating: averageRating, size: 32)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.pagePadding)
                            .padding(.top, DS.Spacing.lg)
                            
                            // Visit stats
                            HStack(spacing: 32) {
                                VStack(spacing: 4) {
                                    Text("\(userVisits.count)")
                                        .light20DisplayNumber()
                                    Text("Visits")
                                        .light20Caption()
                                }
                                
                                if averageRating > 0 {
                                    VStack(spacing: 4) {
                                        Text(String(format: "%.1f", averageRating))
                                            .light20DisplayNumber()
                                        Text("Avg Rating")
                                            .light20Caption()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.lg)
                            .light20FloatingCard()
                            .padding(.horizontal, DS.Spacing.pagePadding)
                            
                            // Visit history
                            if !userVisits.isEmpty {
                                Text("Visit History")
                                    .light20Subheading()
                                    .padding(.horizontal, DS.Spacing.pagePadding)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(userVisits) { visit in
                                        if let photo = visit.photos.first {
                                            Button(action: {
                                                selectedVisit = visit
                                            }) {
                                                PhotoImageView(
                                                    photoPath: photo,
                                                    remoteURL: visit.remotePhotoURLByKey[photo]
                                                )
                                                .aspectRatio(1, contentMode: .fill)
                                                .clipped()
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.pagePadding)
                            }
                        }
                        .padding(.bottom, 120)
                    }
                }
            }
            .background(DS.Colors.light20Background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(DS.Colors.light20CharcoalBlack)
                    }
                }
            }
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
            .overlay(alignment: .bottom) {
                Light20StickyActionBar(
                    title: "Log a Visit",
                    action: {
                        onLogVisitRequested?(cafe)
                        dismiss()
                    }
                )
            }
        }
    }
}


