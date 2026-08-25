import Foundation
import Supabase

/// Keeps additive app/backend rollouts from turning an unavailable optional
/// projection into a false offline state. Only a missing RPC is compatible;
/// authorization, decoding, and transport failures still surface normally.
enum SupabaseBackendCompatibility {
    static func isMissingFunction(_ error: Error) -> Bool {
        guard let postgrestError = error as? PostgrestError else { return false }
        return postgrestError.code == "PGRST202"
            || postgrestError.code == "42883"
    }

    /// Allows read-only cafe hydration to survive the short window between an
    /// additive client release and its matching database migration. Keep this
    /// deliberately specific so auth, transport, and unrelated schema errors
    /// are never hidden behind a legacy query.
    static func isMissingAppleMapsPlaceIDColumn(_ error: Error) -> Bool {
        guard let postgrestError = error as? PostgrestError,
              ["42703", "PGRST204"].contains(postgrestError.code) else {
            return false
        }

        let description = "\(postgrestError.message) \(String(describing: postgrestError))"
            .lowercased()
        return description.contains("apple_maps_place_id")
    }

    static func isMissingReactionKindColumn(_ error: Error) -> Bool {
        guard let postgrestError = error as? PostgrestError,
              ["42703", "PGRST204"].contains(postgrestError.code) else {
            return false
        }

        let description = "\(postgrestError.message) \(String(describing: postgrestError))"
            .lowercased()
        return description.contains("reaction_kind")
    }
}
