//
//  ThemeManager.swift
//  testMugshot
//
//  Theme management system for toggling between Legacy Light and Modern Dark modes.
//

import SwiftUI
import Combine

/// Defines the available theme variants for the app
enum AppThemeVariant: String, Codable {
    case legacyLight = "legacy_light"
    case light20 = "light_20"
    case modernDark = "modern_dark"
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .legacyLight: return "Legacy Light"
        case .light20: return "Light 2.0"
        case .modernDark: return "Modern Dark"
        }
    }
}

/// Singleton manager for app-wide theme state
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    /// The currently active theme variant
    @Published var currentTheme: AppThemeVariant {
        didSet {
            // Persist the theme choice
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "appThemeVariant")
            print("[ThemeManager] Theme changed to: \(currentTheme.rawValue)")
        }
    }
    
    private init() {
        // Load persisted theme or default to legacy light
        if let savedTheme = UserDefaults.standard.string(forKey: "appThemeVariant"),
           let theme = AppThemeVariant(rawValue: savedTheme) {
            self.currentTheme = theme
            print("[ThemeManager] Loaded saved theme: \(theme.rawValue)")
        } else {
            self.currentTheme = .legacyLight
            print("[ThemeManager] Initialized with default theme: legacyLight")
        }
    }
    
    /// Toggle between themes (cycles through all three)
    func toggleTheme() {
        switch currentTheme {
        case .legacyLight:
            currentTheme = .light20
        case .light20:
            currentTheme = .modernDark
        case .modernDark:
            currentTheme = .legacyLight
        }
    }
    
    /// Switch to a specific theme
    func setTheme(_ theme: AppThemeVariant) {
        currentTheme = theme
    }
    
    /// Check if currently in legacy light mode
    var isLegacyLight: Bool {
        currentTheme == .legacyLight
    }
    
    /// Check if currently in Light 2.0 mode
    var isLight20: Bool {
        currentTheme == .light20
    }
    
    /// Check if currently in modern dark mode
    var isModernDark: Bool {
        currentTheme == .modernDark
    }
    
    /// Check if currently in any modern theme (Light 2.0 or dark)
    var isModern: Bool {
        currentTheme == .light20 || currentTheme == .modernDark
    }
}
