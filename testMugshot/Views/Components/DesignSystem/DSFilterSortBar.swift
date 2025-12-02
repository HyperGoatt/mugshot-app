//
//  DSFilterSortBar.swift
//  testMugshot
//
//  Unified filter/sort control with contextual options.
//

import SwiftUI

enum SavedSortOption: String, CaseIterable, Identifiable {
    case bestRated = "Best Rated"
    case worstRated = "Worst Rated"
    case mostVisited = "Most Visited"
    case recentlyVisited = "Recently Visited"
    case recentlyAdded = "Recently Added"
    case closestToMe = "Closest to Me"
    case alphabetical = "A → Z"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .bestRated: return "star.fill"
        case .worstRated: return "star"
        case .mostVisited: return "repeat"
        case .recentlyVisited: return "clock"
        case .recentlyAdded: return "plus.circle"
        case .closestToMe: return "location"
        case .alphabetical: return "textformat.abc"
        }
    }
}

struct DSFilterSortBar: View {
    let availableOptions: [SavedSortOption]
    @Binding var selectedOption: SavedSortOption
    var showSearch: Bool = false
    var onSearchTap: (() -> Void)?
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Sort dropdown
            Menu {
                ForEach(availableOptions) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedOption = option
                        }
                    } label: {
                        Label {
                            Text(option.rawValue)
                        } icon: {
                            if selectedOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.Colors.iconDefault)
                    
                    Text(selectedOption.rawValue)
                        .font(DS.Typography.subheadline(.medium))
                        .foregroundColor(DS.Colors.textPrimary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.Colors.iconSubtle)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.cardBackground)
                .cornerRadius(DS.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.Colors.borderSubtle.opacity(0.5), lineWidth: 0.5)
                )
            }
            
            Spacer()
            
            // Optional search button
            if showSearch {
                Button {
                    onSearchTap?()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DS.Colors.iconDefault)
                        .frame(width: 36, height: 36)
                        .background(DS.Colors.cardBackground)
                        .cornerRadius(DS.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .stroke(DS.Colors.borderSubtle.opacity(0.5), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.pagePadding)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        DSFilterSortBar(
            availableOptions: [.bestRated, .worstRated, .mostVisited, .alphabetical],
            selectedOption: .constant(.bestRated),
            showSearch: true
        )
        
        DSFilterSortBar(
            availableOptions: [.recentlyAdded, .closestToMe, .alphabetical],
            selectedOption: .constant(.recentlyAdded)
        )
    }
    .background(DS.Colors.screenBackground)
}

