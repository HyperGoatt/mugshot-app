//
//  CafeDetailView.swift
//  testMugshot
//
//  Detail view for a cafe showing info, stats, and recent visits.
//

import SwiftUI

struct CafeDetailView: View {
    let cafe: Cafe
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var showLogVisit = false
    @State private var selectedVisit: Visit?
    
    var visits: [Visit] {
        dataManager.getVisitsForCafe(cafe.id)
    }
    
    // Get hero image from most recent visit, or nil if no visits/photos
    var heroImagePath: String? {
        let sortedVisits = visits.sorted { $0.createdAt > $1.createdAt }
        return sortedVisits.first?.posterImagePath
    }
    
    var heroImageRemoteURL: String? {
        guard let visit = visits.sorted(by: { $0.createdAt > $1.createdAt }).first,
              let key = visit.posterImagePath else {
            return nil
        }
        return visit.remoteURL(for: key)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero image - user photos > placeholder
                    if let imagePath = heroImagePath {
                        PhotoImageView(photoPath: imagePath, remoteURL: heroImageRemoteURL)
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 250)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.sandBeige)
                            .frame(height: 250)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.espressoBrown.opacity(0.3))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Cafe name and address
                        VStack(alignment: .leading, spacing: 8) {
                            Text(cafe.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.espressoBrown)
                            
                            if !cafe.address.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.mugshotMint)
                                    Text(cafe.address)
                                        .font(.system(size: 14))
                                        .foregroundColor(.espressoBrown.opacity(0.7))
                                }
                            }
                            
                            if let category = cafe.placeCategory {
                                Text(category)
                                    .font(.system(size: 12))
                                    .foregroundColor(.espressoBrown.opacity(0.6))
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Stats row
                        HStack(spacing: 24) {
                            VStack(alignment: .leading) {
                                Text("Average Rating")
                                    .font(.system(size: 12))
                                    .foregroundColor(.espressoBrown.opacity(0.6))
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.mugshotMint)
                                        .font(.system(size: 14))
                                    Text(String(format: "%.1f", cafe.averageRating))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.espressoBrown)
                                }
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Total Visits")
                                    .font(.system(size: 12))
                                    .foregroundColor(.espressoBrown.opacity(0.6))
                                Text("\(cafe.visitCount)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.espressoBrown)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Button("Log Visit") {
                                showLogVisit = true
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: .infinity)
                            
                            HStack(spacing: 12) {
                                // Get Directions button
                                Button(action: {
                                    openInMaps()
                                }) {
                                    HStack {
                                        Image(systemName: "map")
                                            .font(.system(size: 14))
                                        Text("Get Directions")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.espressoBrown)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.sandBeige)
                                    .cornerRadius(DesignSystem.cornerRadius)
                                }
                                
                                // Visit Website button (only if URL available)
                                if let websiteURL = cafe.websiteURL, !websiteURL.isEmpty {
                                    Button(action: {
                                        openWebsite(urlString: websiteURL)
                                    }) {
                                        HStack {
                                            Image(systemName: "safari")
                                                .font(.system(size: 14))
                                            Text("Website")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(.espressoBrown)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.sandBeige)
                                        .cornerRadius(DesignSystem.cornerRadius)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Recent visits
                        if !visits.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Visits")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.espressoBrown)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                
                                ForEach(visits.prefix(5)) { visit in
                                    VisitRow(visit: visit, dataManager: dataManager) {
                                        selectedVisit = visit
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color.creamWhite)
            .navigationTitle("Café Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLogVisit) {
                LogVisitView(dataManager: dataManager, preselectedCafe: cafe)
            }
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(dataManager: dataManager, visit: visit)
            }
        }
    }
    
    private func openInMaps() {
        guard let location = cafe.location else {
            print("[Cafe] Get directions failed - no location for \(cafe.name)")
            return
        }
        
        print("[Cafe] Get directions tapped for \(cafe.name) at (\(location.latitude), \(location.longitude))")
        
        // Use mapItemURL if available, otherwise construct Maps URL from coordinates
        if let mapURLString = cafe.mapItemURL, let url = URL(string: mapURLString) {
            UIApplication.shared.open(url)
        } else {
            // Fallback: open Maps with coordinates
            let encodedName = cafe.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "http://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=\(encodedName)"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openWebsite(urlString: String) {
        // Normalize URL - add https:// if missing
        var normalizedURL = urlString
        if !normalizedURL.lowercased().hasPrefix("http://") && !normalizedURL.lowercased().hasPrefix("https://") {
            normalizedURL = "https://\(normalizedURL)"
        }
        
        print("[Cafe] Open website tapped: \(normalizedURL)")
        
        guard let url = URL(string: normalizedURL) else {
            print("[Cafe] Failed to create URL from: \(normalizedURL)")
            return
        }
        UIApplication.shared.open(url)
    }
}

struct VisitRow: View {
    let visit: Visit
    @ObservedObject var dataManager: DataManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                PhotoThumbnailView(
                    photoPath: visit.posterImagePath,
                    remoteURL: visit.posterImagePath.flatMap { visit.remoteURL(for: $0) },
                    size: 60
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.date, style: .date)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                    
                    Text(visit.drinkType.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(.espressoBrown.opacity(0.7))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.mugshotMint)
                        .font(.system(size: 12))
                    Text(String(format: "%.1f", visit.overallScore))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.espressoBrown)
                }
            }
            .padding()
            .background(Color.sandBeige)
            .cornerRadius(DesignSystem.smallCornerRadius)
        }
        .buttonStyle(.plain)
    }
}

