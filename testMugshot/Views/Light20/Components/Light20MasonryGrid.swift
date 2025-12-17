//
//  Light20MasonryGrid.swift
//  testMugshot
//
//  Light 2.0 masonry photo grid
//  Edge-to-edge gallery style
//

import SwiftUI

struct Light20MasonryGrid: View {
    let visits: [Visit]
    let onVisitTap: (Visit) -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
            ForEach(visits, id: \.id) { visit in
                if let photo = visit.photos.first {
                    Button(action: {
                        onVisitTap(visit)
                    }) {
                        PhotoImageView(
                            photoPath: photo,
                            remoteURL: visit.remotePhotoURLByKey[photo]
                        )
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    }
                }
            }
        }
        .padding(.horizontal, 2)
    }
}


