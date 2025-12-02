//
//  ProfileFavoriteDrinkPage.swift
//  testMugshot
//
//  Page 3: Favorite Drink
//

import SwiftUI

struct ProfileFavoriteDrinkPage: View {
    let initialFavoriteDrink: String?
    let onUpdate: (String?) -> Void
    
    @State private var selectedDrink: String?
    
    private let drinks = ["Latte", "Cappuccino", "Cold Brew", "Drip", "Espresso", "Matcha", "Tea", "Other"]
    
    init(initialFavoriteDrink: String?, onUpdate: @escaping (String?) -> Void) {
        self.initialFavoriteDrink = initialFavoriteDrink
        self.onUpdate = onUpdate
        _selectedDrink = State(initialValue: initialFavoriteDrink)
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Title
            Text("What's your go-to drink?")
                .font(DS.Typography.screenTitle)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.pagePadding)
            
            // Drink chips
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DS.Spacing.md) {
                ForEach(drinks, id: \.self) { drink in
                    Button(action: {
                        selectedDrink = selectedDrink == drink ? nil : drink
                        onUpdate(selectedDrink)
                    }) {
                        Text(drink)
                            .font(DS.Typography.bodyText)
                            .foregroundStyle(selectedDrink == drink ? DS.Colors.textOnMint : DS.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.pill)
                                    .fill(selectedDrink == drink ? DS.Colors.primaryAccent : DS.Colors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.pill)
                                    .stroke(DS.Colors.borderSubtle, lineWidth: selectedDrink == drink ? 0 : 1)
                            )
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.pagePadding)
            .padding(.top, DS.Spacing.lg)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

