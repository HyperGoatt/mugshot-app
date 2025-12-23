//
//  Visit+Display.swift
//  testMugshot
//
//  Shared display helpers for Visit presentation.
//

import Foundation

extension Visit {
    /// Returns the best display name for a visit's location.
    /// - For cafe visits: resolves the cafe name (if available), otherwise falls back to "Unknown Cafe".
    /// - For Craft Sips: uses `locationName` (if set), otherwise falls back to "Craft Sip".
    func displayLocationName(cafeLookup: (UUID) -> Cafe?) -> String {
        if let cafeId = cafeId {
            return cafeLookup(cafeId)?.name ?? "Unknown Cafe"
        }
        return locationName ?? "Craft Sip"
    }
}

