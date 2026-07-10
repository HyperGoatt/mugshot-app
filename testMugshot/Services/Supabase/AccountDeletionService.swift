//
//  AccountDeletionService.swift
//  testMugshot
//

import Foundation
import Supabase

private struct AccountDeletionResponse: Decodable {
    let deleted: Bool
}

final class AccountDeletionService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func deleteCurrentAccount() async throws {
        let response: AccountDeletionResponse = try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(method: .post)
        )

        guard response.deleted else {
            throw AccountDeletionError.notDeleted
        }
    }
}

enum AccountDeletionError: LocalizedError {
    case notDeleted

    var errorDescription: String? {
        "We couldn’t delete your account. Please try again."
    }
}
