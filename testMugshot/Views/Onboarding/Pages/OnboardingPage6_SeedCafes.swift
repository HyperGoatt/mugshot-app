//
//  OnboardingPage6_SeedCafes.swift
//  testMugshot
//
//  Page 6: Seed Cafes
//

import SwiftUI
import MapKit

struct SeedCafesPage: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var locationManager: LocationManager
    let hasLocationPermission: Bool
    @Binding var seedCafes: [Cafe]
    @Binding var preselectedCafe: Cafe?
    
    @State private var nearbyCafes: [Cafe] = []
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @StateObject private var searchService = MapSearchService()
    
    private var defaultRegion: MKCoordinateRegion {
        if let location = locationManager.location {
            return MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            if hasLocationPermission {
                locationBasedView
            } else {
                manualSearchView
            }
            
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xxl)
        .onAppear {
            if hasLocationPermission {
                loadNearbyCafes()
            }
        }
        .onChange(of: searchService.searchResults) { oldResults, newResults in
            if !newResults.isEmpty {
                convertSearchResultsToCafes()
            }
        }
        .onChange(of: searchService.isSearching) { _, isSearching in
            self.isSearching = isSearching
        }
    }
    
    private var locationBasedView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("Add cafes near you")
                .font(DS.Typography.title1(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            if isSearching {
                ProgressView()
                    .padding()
            } else if nearbyCafes.isEmpty {
                Text("No cafes found nearby")
                    .font(DS.Typography.bodyText)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: DS.Spacing.md) {
                        ForEach(nearbyCafes) { cafe in
                            CafeSelectionRow(
                                cafe: cafe,
                                isSelected: seedCafes.contains(where: { $0.id == cafe.id }),
                                onToggle: {
                                    toggleCafe(cafe)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                }
                .frame(maxHeight: 300)
            }
        }
    }
    
    private var manualSearchView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("Search a cafe you love")
                .font(DS.Typography.title1(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            TextField("Search cafes...", text: $searchText)
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(DS.Colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                )
                .padding(.horizontal, DS.Spacing.pagePadding)
                .onSubmit {
                    searchCafes()
                }
            
            if isSearching {
                ProgressView()
                    .padding()
            } else if !nearbyCafes.isEmpty {
                ScrollView {
                    VStack(spacing: DS.Spacing.md) {
                        ForEach(nearbyCafes) { cafe in
                            CafeSelectionRow(
                                cafe: cafe,
                                isSelected: seedCafes.contains(where: { $0.id == cafe.id }),
                                onToggle: {
                                    toggleCafe(cafe)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DS.Spacing.pagePadding)
                }
                .frame(maxHeight: 300)
            }
        }
    }
    
    private func loadNearbyCafes() {
        // Search for "coffee" or "cafe" near location
        let query = "coffee cafe"
        searchService.search(query: query, region: defaultRegion)
    }
    
    private func searchCafes() {
        guard !searchText.isEmpty else {
            nearbyCafes = []
            isSearching = false
            return
        }
        
        isSearching = true
        searchService.search(query: searchText, region: defaultRegion)
    }
    
    private func convertSearchResultsToCafes() {
        guard !searchService.searchResults.isEmpty else {
            nearbyCafes = []
            isSearching = false
            return
        }
        
        let cafes = searchService.searchResults.prefix(5).map { mapItem in
            dataManager.findOrCreateCafe(from: mapItem)
        }
        nearbyCafes = Array(cafes)
        isSearching = false
        
        // Pre-select first cafe if we have results and none selected
        if let first = nearbyCafes.first, seedCafes.isEmpty {
            toggleCafe(first)
        }
    }
    
    private func toggleCafe(_ cafe: Cafe) {
        if let index = seedCafes.firstIndex(where: { $0.id == cafe.id }) {
            seedCafes.remove(at: index)
            if preselectedCafe?.id == cafe.id {
                preselectedCafe = nil
            }
        } else {
            seedCafes.append(cafe)
            if preselectedCafe == nil {
                preselectedCafe = cafe
            }
        }
    }
}

struct CafeSelectionRow: View {
    let cafe: Cafe
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(cafe.name)
                        .font(DS.Typography.bodyText)
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    if !cafe.address.isEmpty {
                        Text(cafe.address)
                            .font(DS.Typography.caption1())
                            .foregroundStyle(DS.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? DS.Colors.primaryAccent : DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(DS.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(isSelected ? DS.Colors.primaryAccent.opacity(0.5) : DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

