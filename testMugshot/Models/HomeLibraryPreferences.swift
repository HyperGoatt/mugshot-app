import Foundation

struct HomeLibraryPreferences: Codable, Equatable, Sendable {
    var preferredMethod: HomeBrewMethod?
    var defaultBagID: UUID?
    var defaultEquipmentIDs: Set<UUID> = []
}

struct HomeLibraryDefaults {
    let bag: CoffeeBag?
    let equipment: [EquipmentProfile]
}

extension HomeLibrarySnapshot {
    func defaults(for ownerID: UUID?, method: HomeBrewMethod? = nil) -> HomeLibraryDefaults {
        let usesCoffee = method.map { $0.family == .coffee || $0 == .completeDrink } ?? true
        return HomeLibraryDefaults(
            bag: usesCoffee ? currentBags.first { $0.id == preferences?.defaultBagID && $0.ownerUserID == ownerID } : nil,
            equipment: activeEquipment.filter {
                $0.ownerUserID == ownerID && preferences?.defaultEquipmentIDs.contains($0.id) == true
            }
        )
    }
}

/// Applies only printed identity fields that the user has not edited during a scan.
enum CoffeeBagAutofill {
    static func apply(_ fields: [CoffeeAssistanceField], to bag: inout CoffeeBag, unchangedSince baseline: CoffeeBag) {
        let paths: [String: WritableKeyPath<CoffeeBag, String>] = [
            "roaster": \.roaster, "name": \.name, "producer": \.producer,
            "origin": \.origin, "process": \.process, "variety": \.variety,
            "roastLevel": \.roastLevel, "tastingNotes": \.tastingNotes
        ]
        for field in fields {
            guard field.value.remoteTrimmedNonEmpty != nil else { continue }
            if let path = paths[field.key], bag[keyPath: path] == baseline[keyPath: path] {
                bag[keyPath: path] = field.value
            } else if field.key == "roastDate", bag.roastDate == baseline.roastDate,
                      let date = HomeBagDateParser.date(from: field.value) {
                bag.roastDate = date
            }
        }
    }
}
