//
//  ProfilePostsGrid.swift
//  testMugshot
//
//  Instagram-style 3-column grid for profile posts
//

import SwiftUI

struct ProfilePostsGrid: View {
    let visits: [Visit]
    let onSelectVisit: (Visit) -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    
    var body: some View {
        if visits.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(visits) { visit in
                    PostGridItem(visit: visit)
                        .onTapGesture {
                            onSelectVisit(visit)
                        }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "camera")
                .font(.system(size: 40))
                .foregroundColor(DS.Colors.iconSubtle)
            
            Text("No posts yet")
                .font(DS.Typography.bodyText)
                .foregroundColor(DS.Colors.textSecondary)
            
            Text("Your sipping journey photos will appear here")
                .font(DS.Typography.caption1())
                .foregroundColor(DS.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl * 2)
    }
}

// MARK: - Post Grid Item

struct PostGridItem: View {
    let visit: Visit
    
    private var posterPath: String? {
        visit.posterImagePath
    }
    
    private var posterRemoteURL: String? {
        guard let key = posterPath else { return nil }
        return visit.remoteURL(for: key)
    }
    
    private var hasMultiplePhotos: Bool {
        visit.photos.count > 1
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Photo
                if let path = posterPath {
                    PhotoImageView(
                        photoPath: path,
                        remoteURL: posterRemoteURL
                    )
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
                } else {
                    // Placeholder for visits without photos
                    Rectangle()
                        .fill(DS.Colors.cardBackgroundAlt)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(DS.Colors.iconSubtle)
                                Text(String(format: "%.1f", visit.overallScore))
                                    .font(DS.Typography.caption1())
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                        )
                }
                
                // Multiple photos indicator
                if hasMultiplePhotos {
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        .padding(6)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    ScrollView {
        ProfilePostsGrid(
            visits: [],
            onSelectVisit: { _ in }
        )
    }
    .background(DS.Colors.screenBackground)
}

