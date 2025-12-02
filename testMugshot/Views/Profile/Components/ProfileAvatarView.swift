//
//  ProfileAvatarView.swift
//  testMugshot
//
//  Reusable profile avatar component that handles both local and remote images
//

import SwiftUI

struct ProfileAvatarView: View {
    let profileImageId: String?
    let profileImageURL: String?
    let username: String
    var size: CGFloat = 80
    
    @State private var localImage: UIImage?
    
    var body: some View {
        Group {
            if let localImage = localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let profileURL = profileImageURL,
                      let url = URL(string: profileURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        avatarPlaceholder
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(DS.Colors.cardBackground, lineWidth: 2)
        )
        .shadow(
            color: DS.Shadow.cardSoft.color.opacity(0.4),
            radius: 4,
            x: 0,
            y: 2
        )
        .onAppear {
            loadLocalImage()
        }
        .onChange(of: profileImageId) { _, _ in
            loadLocalImage()
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(DS.Colors.primaryAccent)
            .overlay(
                Text(username.prefix(1).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(DS.Colors.textOnMint)
            )
    }
    
    private func loadLocalImage() {
        if let imageID = profileImageId,
           let cachedImage = PhotoCache.shared.retrieve(forKey: imageID) {
            localImage = cachedImage
        } else {
            localImage = nil
        }
    }
}

#Preview {
    HStack(spacing: DS.Spacing.lg) {
        ProfileAvatarView(
            profileImageId: nil,
            profileImageURL: nil,
            username: "joe",
            size: 50
        )
        
        ProfileAvatarView(
            profileImageId: nil,
            profileImageURL: nil,
            username: "alice",
            size: 80
        )
        
        ProfileAvatarView(
            profileImageId: nil,
            profileImageURL: nil,
            username: "bob",
            size: 120
        )
    }
    .padding()
    .background(DS.Colors.screenBackground)
}

