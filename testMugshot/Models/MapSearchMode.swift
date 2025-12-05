//
//  MapSearchMode.swift
//  testMugshot
//
//  Developer-only flag to switch between Mugshot-ranked search
//  and Apple Maps' native ordering for place search.
//

import Foundation

enum MapSearchMode: String, Codable, CaseIterable, Identifiable {
    case mugshot
    case appleMapsNative

    var id: String { rawValue }

    /// Human-friendly label for Developer Tools UI.
    var displayName: String {
        switch self {
        case .mugshot:
            return "Mugshot Search"
        case .appleMapsNative:
            return "Apple Maps Native"
        }
    }

    /// Compact label for console logging.
    var logLabel: String {
        switch self {
        case .mugshot:
            return "Mugshot"
        case .appleMapsNative:
            return "AppleMaps"
        }
    }
}


