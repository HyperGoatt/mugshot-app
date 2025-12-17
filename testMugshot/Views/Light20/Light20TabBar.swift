//
//  Light20TabBar.swift
//  testMugshot
//
//  Floating tab bar for Light 2.0 theme
//  Clean minimal design with mint accent for active states
//

import SwiftUI

struct Light20TabBar: View {
    @Binding var selectedTab: Int
    let onTabSelected: (Int) -> Void
    
    @State private var isPressedTab: Int? = nil
    
    private let tabs: [(icon: String, selectedIcon: String, label: String)] = [
        ("map", "map.fill", "Map"),
        ("square.grid.2x2", "square.grid.2x2.fill", "Feed"),
        ("plus", "plus", "Add"),
        ("bookmark", "bookmark.fill", "Saved"),
        ("person", "person.fill", "Profile")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let tabWidth = geometry.size.width / CGFloat(tabs.count)
            
            ZStack(alignment: .top) {
                // Tab items
                HStack(spacing: 0) {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        Light20TabBarItem(
                            icon: tabs[index].icon,
                            selectedIcon: tabs[index].selectedIcon,
                            label: tabs[index].label,
                            isSelected: selectedTab == index,
                            isFAB: index == 2,
                            isPressed: isPressedTab == index
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                onTabSelected(index)
                            }
                        }
                        .frame(width: tabWidth)
                    }
                }
            }
            .frame(height: 70)
        }
        .frame(height: 90)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(
            Light20TabBarBackground()
        )
    }
}

// MARK: - Tab Bar Item

struct Light20TabBarItem: View {
    let icon: String
    let selectedIcon: String
    let label: String
    let isSelected: Bool
    let isFAB: Bool
    let isPressed: Bool
    let action: () -> Void
    
    @State private var isLocalPressed = false
    
    var body: some View {
        Button(action: {
            HapticsManager.shared.lightTap()
            action()
        }) {
            VStack(spacing: 4) {
                if isFAB {
                    // Floating Action Button (FAB)
                    ZStack {
                        // Mint glow effect
                        Circle()
                            .fill(DS.Colors.light20MintPrimary.opacity(0.15))
                            .frame(width: 68, height: 68)
                            .blur(radius: 8)
                        
                        // Main FAB circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DS.Colors.light20MintPrimary,
                                        DS.Colors.light20MintPrimary.opacity(0.95)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .light20MintGlow()
                        
                        // Plus icon
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(isLocalPressed ? 90 : 0))
                    }
                    .scaleEffect(isLocalPressed ? 0.88 : 1.0)
                    .offset(y: -10)
                } else {
                    // Regular tab icons
                    ZStack {
                        // Selected icon (mint fill)
                        Image(systemName: selectedIcon)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Colors.light20MintPrimary)
                            .opacity(isSelected ? 1.0 : 0.0)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                        
                        // Unselected icon (charcoal outline)
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .light, design: .rounded))
                            .foregroundColor(DS.Colors.light20IconInactive)
                            .opacity(isSelected ? 0.0 : 1.0)
                            .scaleEffect(isSelected ? 0.8 : 1.0)
                    }
                    .scaleEffect(isLocalPressed ? 0.85 : 1.0)
                    .frame(height: 28)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(Light20TabBarButtonStyle(isPressed: $isLocalPressed))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isLocalPressed)
    }
}

// MARK: - Tab Bar Button Style

struct Light20TabBarButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Tab Bar Background

struct Light20TabBarBackground: View {
    var body: some View {
        VStack(spacing: 0) {
            // Floating white card with subtle shadow
            Rectangle()
                .fill(DS.Colors.light20Background)
                .shadow(
                    color: DS.Shadow.light20FloatingCard.color,
                    radius: DS.Shadow.light20FloatingCard.radius,
                    x: DS.Shadow.light20FloatingCard.x,
                    y: -DS.Shadow.light20FloatingCard.y
                )
                .overlay(
                    // Top border with gradient
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DS.Colors.light20BorderLight.opacity(0),
                                    DS.Colors.light20BorderLight,
                                    DS.Colors.light20BorderLight.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1),
                    alignment: .top
                )
        }
    }
}


