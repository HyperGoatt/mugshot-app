//
//  OnboardingPage5_FavoriteDrink.swift
//  testMugshot
//
//  Page 5: Favorite Drink
//

import SwiftUI

struct FavoriteDrinkPage: View {
    @Binding var favoriteDrink: String?
    
    let drinks = [
        ("Latte", "cup.and.saucer.fill"),
        ("Cappuccino", "cup.and.saucer.fill"),
        ("Cold Brew", "cup.and.saucer.fill"),
        ("Drip", "cup.and.saucer.fill"),
        ("Espresso", "cup.and.saucer.fill"),
        ("Matcha", "cup.and.saucer.fill"),
        ("Tea", "cup.and.saucer.fill"),
        ("Other", "cup.and.saucer.fill")
    ]
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Title
            Text("What's your go-to drink?")
                .font(DS.Typography.title1(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
                .padding(.bottom, DS.Spacing.lg)
            
            // Drink grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DS.Spacing.md) {
                ForEach(drinks, id: \.0) { drink in
                    DrinkChip(
                        name: drink.0,
                        icon: drink.1,
                        isSelected: favoriteDrink == drink.0,
                        action: {
                            favoriteDrink = favoriteDrink == drink.0 ? nil : drink.0
                        }
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xxl)
    }
}

struct DrinkChip: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(isSelected ? DS.Colors.primaryAccent : DS.Colors.textSecondary)
                
                Text(name)
                    .font(DS.Typography.caption1())
                    .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(isSelected ? DS.Colors.primaryAccentSoftFill : DS.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(isSelected ? DS.Colors.primaryAccent : DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

