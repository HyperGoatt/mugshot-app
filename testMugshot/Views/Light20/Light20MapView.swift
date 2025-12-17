//
//  Light20MapView.swift
//  testMugshot
//
//  Light 2.0 map with clean pins and floating search
//  Rating-based pin colors: green ≥4.0, yellow 3.0-3.9, red <3.0, blue want-to-try
//

import SwiftUI
import MapKit
import CoreLocation

struct Light20MapView: View {
    @ObservedObject var dataManager: DataManager
    var onLogVisitRequested: ((Cafe) -> Void)?
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchService = MapSearchService()
    @EnvironmentObject private var hapticsManager: HapticsManager
    
    @State private var region: MKCoordinateRegion?
    @State private var selectedCafe: Cafe?
    @State private var showCafeDetail = false
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var lastSearchRegion: MKCoordinateRegion?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var annotations: [ModernCafeAnnotation] = []
    @State private var showSearchResults = false
    
    private var referenceLocation: CLLocation {
        let activeRegion = region ?? defaultRegion
        return CLLocation(latitude: activeRegion.center.latitude, longitude: activeRegion.center.longitude)
    }
    
    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    private var searchResults: [Cafe] {
        guard !searchText.isEmpty else { return [] }
        return dataManager.appData.cafes.filter { cafe in
            cafe.name.localizedCaseInsensitiveContains(searchText)
        }.sorted { cafe1, cafe2 in
            guard let loc1 = cafe1.location, let loc2 = cafe2.location else { return false }
            let dist1 = referenceLocation.distance(from: CLLocation(latitude: loc1.latitude, longitude: loc1.longitude))
            let dist2 = referenceLocation.distance(from: CLLocation(latitude: loc2.latitude, longitude: loc2.longitude))
            return dist1 < dist2
        }
    }
    
    var body: some View {
        ZStack {
            DS.Colors.light20Background
                .ignoresSafeArea()
            
            Map(position: $cameraPosition) {
                if let userLocation = locationManager.location {
                    Annotation("", coordinate: userLocation.coordinate) {
                        Circle()
                            .fill(DS.Colors.light20MintPrimary)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                    }
                }
                
                ForEach(annotations) { annotation in
                    Annotation("", coordinate: annotation.coordinate) {
                        Button(action: {
                            hapticsManager.lightTap()
                            selectedCafe = annotation.cafe
                        }) {
                            Light20CafePin(
                                rating: annotation.rating,
                                isSelected: selectedCafe?.id == annotation.cafe.id,
                                isWantToTry: annotation.isWantToTry
                            )
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .preferredColorScheme(.light)
            .ignoresSafeArea()
            .onMapCameraChange { context in
                region = context.region
            }
            
            VStack {
                Light20MapSearchBar(
                    searchText: $searchText,
                    isActive: $isSearchActive,
                    onSubmit: {
                        performSearch()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .onChange(of: searchText) { _, newValue in
                    showSearchResults = !newValue.isEmpty
                }
                
                if showSearchResults && !searchResults.isEmpty {
                    searchResultsList
                }
                
                Spacer()
                
                Light20MapLegend()
                    .padding(.bottom, 110)
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            if let selectedCafe = selectedCafe {
                VStack {
                    Spacer()
                    Light20CafeListCard(
                        cafe: selectedCafe,
                        dataManager: dataManager,
                        onTap: {
                            showCafeDetail = true
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showCafeDetail) {
            if let cafe = selectedCafe {
                Light20CafeDetailView(
                    cafe: cafe,
                    dataManager: dataManager,
                    onLogVisitRequested: onLogVisitRequested
                )
            }
        }
        .onAppear {
            loadAnnotations()
            if let userLocation = locationManager.location {
                cameraPosition = .region(MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        }
    }
    
    private var searchResultsList: some View {
        ScrollView {
            VStack(spacing: 1) {
                ForEach(searchResults.prefix(10)) { cafe in
                    Button(action: {
                        selectSearchResult(cafe)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 20))
                                .foregroundColor(DS.Colors.light20MintPrimary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cafe.name)
                                    .light20Subheading()
                                    .lineLimit(1)
                                
                                Text(cafe.address)
                                    .light20Label()
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                        .padding(12)
                    }
                    .light20FloatingCard()
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxHeight: 300)
    }
    
    private func performSearch() {
        lastSearchRegion = region
        loadAnnotations()
        isSearchActive = false
        showSearchResults = false
    }
    
    private func selectSearchResult(_ cafe: Cafe) {
        searchText = ""
        showSearchResults = false
        selectedCafe = cafe
        
        if let location = cafe.location {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    private func loadAnnotations() {
        annotations = dataManager.appData.cafes.compactMap { cafe -> ModernCafeAnnotation? in
            guard let location = cafe.location else { return nil }
            
            let userVisits = dataManager.appData.visits.filter { $0.cafeId == cafe.id }
            let totalScore = userVisits.reduce(0.0) { partial, visit in
                partial + visit.overallScore
            }
            let avgRating = userVisits.isEmpty ? nil : totalScore / Double(userVisits.count)
            let isWantToTry = cafe.wantToTry
            
            return ModernCafeAnnotation(
                id: cafe.id,
                coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                cafe: cafe,
                rating: avgRating ?? 0,
                isWantToTry: isWantToTry
            )
        }
    }
}


