//
//  ThemeManager.swift
//  testMugshot
//
//  Theme management system. Now forced to Legacy Light theme.
//

import SwiftUI
import Combine

/// Defines the available theme variants for the app
enum AppThemeVariant: String, Codable {
    case legacyLight = "legacy_light"
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .legacyLight: return "Legacy Light"
        }
    }
}

/// Singleton manager for app-wide theme state
class ThemeManager: ObservableObject, @unchecked Sendable {
    static let shared = ThemeManager()
    
    /// The currently active theme variant
    @Published var currentTheme: AppThemeVariant = .legacyLight
    
    private init() {
        // Force legacy light theme
        self.currentTheme = .legacyLight
        print("[ThemeManager] Initialized with fixed theme: legacyLight")
    }
    
    /// No-op as themes are removed
    func toggleTheme() {
        // No-op
    }
    
    /// No-op as themes are removed
    func setTheme(_ theme: AppThemeVariant) {
        // No-op
    }
    
    /// Check if currently in legacy light mode
    var isLegacyLight: Bool {
        true
    }
    
    /// Always false
    var isLight20: Bool {
        false
    }
    
    /// Always false
    var isModernDark: Bool {
        false
    }
    
    /// Check if currently in any modern theme
    var isModern: Bool {
        false
    }
}
