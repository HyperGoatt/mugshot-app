import Foundation
import Supabase

/// Reuses the existing owner-private Home Storage boundary and its account
/// deletion/export policies. Attempt media is never a public recipe attachment.
struct HomeRecipeMediaService {
    let client: SupabaseClient
    static let bucket = "home-coffee-bag-photos"

    static func path(owner: UUID, name: String) throws -> String {
        guard name.count == 77, name.hasSuffix(".jpg"),
              UUID(uuidString: String(name.prefix(36))) != nil,
              name.dropFirst(36).first == "-",
              UUID(uuidString: String(name.dropFirst(37).prefix(36))) != nil else {
            throw HomeRecipeWorkspaceError.invalid("Invalid private photo reference.")
        }
        return "\(owner.uuidString.lowercased())/home-attempts/\(name)"
    }

    func upload(_ data: Data, name: String, owner: UUID) async throws {
        try await client.storage.from(Self.bucket).upload(
            Self.path(owner: owner, name: name), data: data,
            options: FileOptions(contentType: "image/jpeg", upsert: true))
    }

    func download(name: String, owner: UUID) async throws -> Data {
        try await client.storage.from(Self.bucket).download(path: Self.path(owner: owner, name: name))
    }
}

extension HomeRecipeWorkspace {
    var referencedPhotoNames: Set<String> {
        var records = attempts
        records.append(contentsOf: attemptDrafts)
        records.append(contentsOf: attemptConflicts ?? [])
        records.append(contentsOf: sessions.map(\.attempt))
        records.append(contentsOf: (preparationConflicts ?? []).map(\.attempt))
        return Set(records.flatMap(\.photoNames))
    }
}
