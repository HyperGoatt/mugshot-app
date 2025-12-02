//
//  ProfilePhotosPage.swift
//  testMugshot
//
//  Page 5: Profile & Banner Photos
//

import SwiftUI
import PhotosUI

struct ProfilePhotosPage: View {
    let initialProfileImageId: String?
    let initialBannerImageId: String?
    let onUpdate: (String?, String?) -> Void
    
    @State private var selectedProfileImage: PhotosPickerItem?
    @State private var selectedBannerImage: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var bannerImage: UIImage?
    @State private var showingProfilePicker = false
    @State private var showingBannerPicker = false
    
    init(initialProfileImageId: String?, initialBannerImageId: String?, onUpdate: @escaping (String?, String?) -> Void) {
        self.initialProfileImageId = initialProfileImageId
        self.initialBannerImageId = initialBannerImageId
        self.onUpdate = onUpdate
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Title
            Text("Add your photos")
                .font(DS.Typography.screenTitle)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Subtitle
            Text("Optional - add a profile picture and banner")
                .font(DS.Typography.bodyText)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding * 2)
                .padding(.top, DS.Spacing.sm)
            
            // Photo upload areas
            VStack(spacing: DS.Spacing.lg) {
                // Banner photo
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Banner Photo")
                        .font(DS.Typography.subheadline())
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    Button(action: { showingBannerPicker = true }) {
                        ZStack {
                            if let bannerImage = bannerImage {
                                Image(uiImage: bannerImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 120)
                                    .cornerRadius(DS.Radius.lg)
                                    .clipped()
                            } else {
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .fill(DS.Colors.cardBackgroundAlt)
                                    .frame(height: 120)
                                    .overlay(
                                        VStack(spacing: DS.Spacing.xs) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 24))
                                                .foregroundStyle(DS.Colors.iconDefault)
                                            Text("Add Banner")
                                                .font(DS.Typography.caption1())
                                                .foregroundStyle(DS.Colors.textSecondary)
                                        }
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // Profile photo
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Profile Photo")
                        .font(DS.Typography.subheadline())
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    Button(action: { showingProfilePicker = true }) {
                        ZStack {
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(DS.Colors.cardBackgroundAlt)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        VStack(spacing: DS.Spacing.xs) {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 40))
                                                .foregroundStyle(DS.Colors.iconDefault)
                                            Text("Add Photo")
                                                .font(DS.Typography.caption1())
                                                .foregroundStyle(DS.Colors.textSecondary)
                                        }
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.top, DS.Spacing.lg)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .photosPicker(
            isPresented: $showingBannerPicker,
            selection: $selectedBannerImage,
            matching: .images
        )
        .photosPicker(
            isPresented: $showingProfilePicker,
            selection: $selectedProfileImage,
            matching: .images
        )
        .onChange(of: selectedBannerImage) { _, newValue in
            loadBannerImage(from: newValue)
        }
        .onChange(of: selectedProfileImage) { _, newValue in
            loadProfileImage(from: newValue)
        }
        .onAppear {
            // Load existing images from PhotoCache if IDs are provided
            if let profileId = initialProfileImageId,
               let cachedImage = PhotoCache.shared.retrieve(forKey: profileId) {
                profileImage = cachedImage
            }
            if let bannerId = initialBannerImageId,
               let cachedImage = PhotoCache.shared.retrieve(forKey: bannerId) {
                bannerImage = cachedImage
            }
        }
    }
    
    private func loadBannerImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.bannerImage = image
                        // Save image to PhotoCache and get ID
                        let imageId = UUID().uuidString
                        PhotoCache.shared.store(image, forKey: imageId)
                        onUpdate(initialProfileImageId, imageId)
                    }
                }
            case .failure:
                break
            }
        }
    }
    
    private func loadProfileImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.profileImage = image
                        // Save image to PhotoCache and get ID
                        let imageId = UUID().uuidString
                        PhotoCache.shared.store(image, forKey: imageId)
                        onUpdate(imageId, initialBannerImageId)
                    }
                }
            case .failure:
                break
            }
        }
    }
}

