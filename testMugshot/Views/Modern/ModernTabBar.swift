//
//  ModernTabBar.swift
//  testMugshot
//
//  Floating tab bar with glassmorphism/floating design for Modern themes (Light & Dark)
//

import SwiftUI

struct ModernTabBar: View {
    @Binding var selectedTab: Int
    let onTabSelected: (Int) -> Void
    
    @State private var isPressedTab: Int? = nil
    
    private let tabs: [(icon: String, selectedIcon: String, label: String)] = [
        ("map", "map.fill", "Map"),
        ("square.grid.2x2", "square.grid.2x2.fill", "Feed"),
        ("plus", "plus", "Add"), // FAB
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
                        ModernTabBarItem(
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
        .frame(height: 90) // Extra space for FAB elevation
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(
            ModernTabBarBackground()
        )
    }
}

// MARK: - Tab Bar Item

struct ModernTabBarItem: View {
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
                        // Outer glow effect
                        Circle()
                            .fill(DS.Colors.dynamicPrimaryAccent.opacity(0.2))
                            .frame(width: 68, height: 68)
                            .blur(radius: 8)
                            .opacity(isSelected ? 1.0 : 0.6)
                        
                        // Main FAB circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DS.Colors.dynamicPrimaryAccent,
                                        DS.Colors.dynamicPrimaryAccent.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(
                                color: DS.Colors.dynamicPrimaryAccent.opacity(0.3),
                                radius: 10,
                                x: 0,
                                y: 5
                            )
                        
                        // Plus icon
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(DS.Colors.dynamicTextOnAccent)
                            .rotationEffect(.degrees(isLocalPressed ? 90 : 0))
                    }
                    .scaleEffect(isLocalPressed ? 0.88 : (isSelected ? 1.05 : 1.0))
                    .offset(y: -10) // Elevate above tab bar
                } else {
                    // Regular tab icons
                    ZStack {
                        // Selected icon
                        Image(systemName: selectedIcon)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Colors.dynamicPrimaryAccent)
                            .opacity(isSelected ? 1.0 : 0.0)
                            .scaleEffect(isSelected ? 1.0 : 0.8)
                        
                        // Unselected icon
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .light, design: .rounded))
                            .foregroundColor(DS.Colors.dynamicIconInactive)
                            .opacity(isSelected ? 0.0 : 1.0)
                            .scaleEffect(isSelected ? 0.8 : 1.0)
                    }
                    .scaleEffect(isLocalPressed ? 0.85 : 1.0)
                    .frame(height: 28)
                    
                    // Label - hidden for better minimalism
                    // Uncomment if you want labels:
                    // Text(label)
                    //     .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    //     .foregroundColor(isSelected ? DS.Colors.modernAccent : DS.Colors.modernTextTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(ModernTabBarButtonStyle(isPressed: $isLocalPressed))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isLocalPressed)
    }
}

// MARK: - Tab Bar Button Style

struct ModernTabBarButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Tab Bar Background

struct ModernTabBarBackground: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Theme-aware background (Modern Dark only now)
            // Dark mode: Glass background
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(DS.Colors.modernBackground.opacity(0.9))
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DS.Colors.dynamicBorder.opacity(0),
                                    DS.Colors.dynamicBorder,
                                    DS.Colors.dynamicBorder.opacity(0)
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
