import SwiftUI

struct HomeStarterPicker: View {
    var onLatte: (() -> Void)? = nil
    var onMoreMethods: (() -> Void)? = nil
    let onSelect: (HomeRecipeContent) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Make something simple")
                            .font(.system(.largeTitle, design: .serif).weight(.semibold))
                            .foregroundStyle(Color.espressoBrown)
                        Text("Pick a drink. Mugshot will walk you through it with what you have at home.")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                    }
                    ForEach(HomeStarterRecipes.all) { starter in
                        starterRow(starter)
                    }
                    if let onLatte {
                        Button("Latte", systemImage: "mug", action: onLatte)
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityIdentifier("logASipV4.home.starter.complete_drink")
                    }
                    if let onMoreMethods {
                        Button("Choose a method", systemImage: "slider.horizontal.3", action: onMoreMethods)
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityIdentifier("home.starter.methods")
                    }
                }
                .padding(DesignSystem.Space.md)
            }
            .background(Color.creamWhite)
            .navigationTitle("Starter recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func starterRow(_ starter: HomeStarterRecipe) -> some View {
        Button {
            onSelect(starter.content)
        } label: {
            HStack(spacing: 14) {
                HomeMethodIconView(method: starter.content.method, size: 27)
                    .frame(width: 48, height: 48)
                    .background(Color.mugshotMint.opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(starter.family)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.mugshotSageText)
                    Text(starter.content.name)
                        .font(.headline)
                        .foregroundStyle(Color.espressoBrown)
                    Text(starter.detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mugshotSageText)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.card).stroke(Color.mugshotLine))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.starter.\(starter.id)")
    }
}
