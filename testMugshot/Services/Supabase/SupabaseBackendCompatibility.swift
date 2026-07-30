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
}
