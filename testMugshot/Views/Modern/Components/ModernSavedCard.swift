//
//  ModernSavedCard.swift
//  testMugshot
//
//  Glass card for saved cafes in horizontal scroll
//

import SwiftUI
import CoreLocation

struct ModernSavedCard: View {
    let cafe: Cafe
    let userLocation: CLLocation?
    let visitCount: Int
    let lastVisitDate: Date?
    let dataManager: DataManager
    let onTap: () -> Void
    
    private var distance: String? {
        guard let userLocation = userLocation,
              let cafeLocation = cafe.location else { return nil }
        
        let cafeCLLocation = CLLocation(latitude: cafeLocation.latitude, longitude: cafeLocation.longitude)
        let distanceInMeters = userLocation.distance(from: cafeCLLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        
        if distanceInMiles < 0.1 {
            return "Nearby"
        } else if distanceInMiles < 1.0 {
            return String(format: "%.1f mi", distanceInMiles)
        } else {
            return String(format: "%.0f mi", distanceInMiles)
        }
    }
    
    private var cafeImageURL: String? {
        let visits = dataManager.getVisitsForCafe(cafe.id)
        guard let firstVisit = visits.first,
              let posterPath = firstVisit.posterImagePath else { return nil }
        return firstVisit.remoteURL(for: posterPath)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Cafe image
                if let imageURL = cafeImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 280, height: 180)
                                .clipped()
                        default:
                            imagePlaceholder
                        }
                    }
                } else {
                    imagePlaceholder
                }
                
                // Cafe info
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Text(cafe.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DS.Colors.dynamicTextPrimary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        if cafe.averageRating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                Text(String(format: "%.1f", cafe.averageRating))
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DS.Colors.dynamicPrimaryAccent)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Details row
                    HStack(spacing: 12) {
                        if let distance = distance {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                                Text(distance)
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(DS.Colors.dynamicTextSecondary)
                        }
                        
                        if visitCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 12))
                                Text("\(visitCount) \(visitCount == 1 ? "visit" : "visits")")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(DS.Colors.dynamicTextSecondary)
                        }
                    }
                    
                    if let lastDate = lastVisitDate {
                        Text("Last visited \(formatDate(lastDate))")
                            .font(.system(size: 12))
                            .foregroundColor(DS.Colors.dynamicTextTertiary)
                    }
                }
                .padding(16)
            }
            .frame(width: 280)
            .background(DS.Colors.dynamicCardBackgroundAlt)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DS.Colors.modernGlassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var imagePlaceholder: some View {
        Rectangle()
            .fill(DS.Colors.dynamicCardBackgroundAlt)
            .frame(width: 280, height: 180)
            .overlay(
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 48))
                    .foregroundColor(DS.Colors.dynamicTextTertiary)
            )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}


