import Foundation
import Supabase
import UIKit

struct RemoteHomeLibrary: Equatable {
    let bags: [CoffeeBag]
    let equipment: [EquipmentProfile]
}

/// Owner-only synchronization for the Home library. Visits carry immutable,
/// socially safe snapshots; these mutable rows never power public surfaces.
final class HomeLibraryService {
    private let client: SupabaseClient
    private let bagColumns = """
    id, user_id, roaster, name, producer, origin, process, variety, roast_level,
    roast_date, tasting_notes, starting_weight_grams, remaining_weight_grams,
    status, opened_at, frozen_at, private_photo_path, created_at, updated_at
    """
    private let equipmentColumns = """
    id, user_id, role, nickname, brand, model, notes, archived_at, created_at, updated_at
    """
    private let photoBucket = "home-coffee-bag-photos"

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetch(userID: UUID) async throws -> RemoteHomeLibrary {
        async let bags: [HomeCoffeeBagRow] = client
            .from("home_coffee_bags")
            .select(bagColumns)
            .eq("user_id", value: userID.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value
        async let equipment: [HomeEquipmentProfileRow] = client
            .from("home_equipment_profiles")
            .select(equipmentColumns)
            .eq("user_id", value: userID.uuidString)
            .order("updated_at", ascending: false)
            .execute()
            .value

        return try await RemoteHomeLibrary(
            bags: bags.map(\.model),
            equipment: equipment.map(\.model)
        )
    }

    @discardableResult
    func upsert(_ bag: CoffeeBag, userID: UUID) async throws -> CoffeeBag {
        let row: HomeCoffeeBagRow = try await client
            .from("home_coffee_bags")
            .upsert(HomeCoffeeBagPayload(bag: bag, userID: userID), onConflict: "id")
            .select(bagColumns)
            .single()
            .execute()
            .value
        return row.model
    }

    @discardableResult
    func upsert(_ equipment: EquipmentProfile, userID: UUID) async throws -> EquipmentProfile {
        let row: HomeEquipmentProfileRow = try await client
            .from("home_equipment_profiles")
            .upsert(HomeEquipmentProfilePayload(equipment: equipment, userID: userID), onConflict: "id")
            .select(equipmentColumns)
            .single()
            .execute()
            .value
        return row.model
    }

    func uploadBagPhoto(_ image: UIImage, bagID: UUID, userID: UUID) async throws -> String {
        let normalized = image.resizedForVisitUpload(maxDimension: 1_600)
        guard let data = normalized.jpegData(compressionQuality: 0.84) else {
            throw HomeLibraryServiceError.photoEncodingFailed
        }
        let path = "\(userID.uuidString.lowercased())/\(bagID.uuidString.lowercased()).jpg"
        try await client.storage.from(photoBucket).upload(
            path,
            data: data,
            options: FileOptions(
                cacheControl: "86400",
                contentType: "image/jpeg",
                upsert: true
            )
        )
        return path
    }
}

enum HomeLibraryServiceError: LocalizedError {
    case photoEncodingFailed

    var errorDescription: String? {
        "Mugshot couldn’t prepare that bag photo. Try another image."
    }
}

private struct HomeCoffeeBagRow: Decodable {
    let id: UUID
    let userID: UUID
    let roaster: String
    let name: String
    let producer: String
    let origin: String
    let process: String
    let variety: String
    let roastLevel: String
    let roastDate: String?
    let tastingNotes: String
    let startingWeightGrams: Double?
    let remainingWeightGrams: Double?
    let status: String
    let openedAt: String?
    let frozenAt: String?
    let privatePhotoPath: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, roaster, name, producer, origin, process, variety, status
        case userID = "user_id"
        case roastLevel = "roast_level"
        case roastDate = "roast_date"
        case tastingNotes = "tasting_notes"
        case startingWeightGrams = "starting_weight_grams"
        case remainingWeightGrams = "remaining_weight_grams"
        case openedAt = "opened_at"
        case frozenAt = "frozen_at"
        case privatePhotoPath = "private_photo_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var model: CoffeeBag {
        CoffeeBag(
            id: id,
            ownerUserID: userID,
            roaster: roaster,
            name: name,
            producer: producer,
            origin: origin,
            process: process,
            variety: variety,
            roastLevel: roastLevel,
            roastDate: roastDate?.remoteDateOnly,
            tastingNotes: tastingNotes,
            startingWeightGrams: startingWeightGrams,
            remainingWeightGrams: remainingWeightGrams,
            status: CoffeeBagStatus(rawValue: status) ?? .open,
            openedAt: openedAt?.homeISO8601Date,
            frozenAt: frozenAt?.homeISO8601Date,
            privatePhotoPath: privatePhotoPath,
            localPhotoPath: nil,
            createdAt: createdAt.homeISO8601Date ?? .distantPast,
            updatedAt: updatedAt.homeISO8601Date ?? .distantPast
        )
    }
}

private struct HomeCoffeeBagPayload: Encodable {
    let id: UUID
    let userID: UUID
    let roaster: String
    let name: String
    let producer: String
    let origin: String
    let process: String
    let variety: String
    let roastLevel: String
    let roastDate: String?
    let tastingNotes: String
    let startingWeightGrams: Double?
    let remainingWeightGrams: Double?
    let status: String
    let openedAt: String?
    let frozenAt: String?
    let privatePhotoPath: String?
    let createdAt: String
    let updatedAt: String

    init(bag: CoffeeBag, userID: UUID) {
        id = bag.id
        self.userID = userID
        roaster = bag.roaster
        name = bag.name
        producer = bag.producer
        origin = bag.origin
        process = bag.process
        variety = bag.variety
        roastLevel = bag.roastLevel
        roastDate = bag.roastDate.map(DateFormatter.remoteDateOnly.string)
        tastingNotes = bag.tastingNotes
        startingWeightGrams = bag.startingWeightGrams
        remainingWeightGrams = bag.remainingWeightGrams
        status = bag.status.rawValue
        openedAt = bag.openedAt.map(ISO8601DateFormatter().string)
        frozenAt = bag.frozenAt.map(ISO8601DateFormatter().string)
        privatePhotoPath = bag.privatePhotoPath
        createdAt = ISO8601DateFormatter().string(from: bag.createdAt)
        updatedAt = ISO8601DateFormatter().string(from: bag.updatedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, roaster, name, producer, origin, process, variety, status
        case userID = "user_id"
        case roastLevel = "roast_level"
        case roastDate = "roast_date"
        case tastingNotes = "tasting_notes"
        case startingWeightGrams = "starting_weight_grams"
        case remainingWeightGrams = "remaining_weight_grams"
        case openedAt = "opened_at"
        case frozenAt = "frozen_at"
        case privatePhotoPath = "private_photo_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct HomeEquipmentProfileRow: Decodable {
    let id: UUID
    let userID: UUID
    let role: String
    let nickname: String
    let brand: String
    let modelName: String
    let notes: String
    let archivedAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, role, nickname, brand, notes
        case userID = "user_id"
        case modelName = "model"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var model: EquipmentProfile {
        EquipmentProfile(
            id: id,
            ownerUserID: userID,
            role: EquipmentRole(rawValue: role) ?? .other,
            nickname: nickname,
            brand: brand,
            model: modelName,
            notes: notes,
            archivedAt: archivedAt?.homeISO8601Date,
            createdAt: createdAt.homeISO8601Date ?? .distantPast,
            updatedAt: updatedAt.homeISO8601Date ?? .distantPast
        )
    }
}

private struct HomeEquipmentProfilePayload: Encodable {
    let id: UUID
    let userID: UUID
    let role: String
    let nickname: String
    let brand: String
    let model: String
    let notes: String
    let archivedAt: String?
    let createdAt: String
    let updatedAt: String

    init(equipment: EquipmentProfile, userID: UUID) {
        id = equipment.id
        self.userID = userID
        role = equipment.role.rawValue
        nickname = equipment.nickname
        brand = equipment.brand
        model = equipment.model
        notes = equipment.notes
        archivedAt = equipment.archivedAt.map(ISO8601DateFormatter().string)
        createdAt = ISO8601DateFormatter().string(from: equipment.createdAt)
        updatedAt = ISO8601DateFormatter().string(from: equipment.updatedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, role, nickname, brand, model, notes
        case userID = "user_id"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private extension String {
    var remoteDateOnly: Date? {
        DateFormatter.remoteDateOnly.date(from: self)
    }

    var homeISO8601Date: Date? {
        ISO8601DateFormatter().date(from: self)
    }
}

private extension DateFormatter {
    static let remoteDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
