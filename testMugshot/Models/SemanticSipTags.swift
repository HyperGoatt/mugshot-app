import Foundation

/// Suggests optional, human-readable journal tags from the order description.
/// Suggestions describe the order or ritual; they never invent how the drink
/// tasted. The raw drink name remains the source of truth.
enum SemanticSipTagEngine {
    private struct Candidate {
        let title: String
        let score: Int
    }

    static func suggestions(
        drinkName: String,
        analysis: DrinkAnalysis?,
        context: JournalEntryContext,
        limit: Int = 4
    ) -> [String] {
        let normalized = normalize(drinkName)
        guard !normalized.isEmpty else { return [] }

        var candidates: [Candidate] = []
        func add(_ title: String, score: Int, when condition: Bool) {
            guard condition else { return }
            candidates.append(Candidate(title: title, score: score))
        }
        func containsAny(_ terms: [String]) -> Bool {
            terms.contains { normalized.contains($0) }
        }

        let bakeryTerms = [
            "cinnamon bun", "cinnamon roll", "cookie", "cake", "tiramisu",
            "pastry", "croissant", "donut", "doughnut", "brownie"
        ]
        let seasonalTerms = [
            "pumpkin", "peppermint", "gingerbread", "eggnog", "chestnut",
            "holiday", "seasonal"
        ]
        let spiceTerms = [
            "cinnamon", "cardamom", "nutmeg", "clove", "ginger", "spice",
            "chai", "horchata"
        ]
        let dessertTerms = [
            "caramel", "vanilla", "buttercream", "mocha", "chocolate",
            "brown sugar", "maple", "honey", "marshmallow"
        ]
        let citrusTerms = ["orange", "lemon", "yuzu", "grapefruit", "citrus", "bergamot"]
        let berryTerms = ["strawberry", "raspberry", "blueberry", "blackberry", "berry"]
        let tropicalTerms = ["coconut", "pineapple", "mango", "passionfruit", "banana"]
        let fruitTerms = citrusTerms + berryTerms + tropicalTerms + ["cherry", "peach", "apple", "pear", "fig"]
        let plantMilkTerms = ["oat milk", "almond milk", "soy milk", "coconut milk", "macadamia milk"]

        add("Bakery-inspired", score: 100, when: containsAny(bakeryTerms))
        add("Seasonal special", score: 98, when: containsAny(seasonalTerms))
        add("Spice-led order", score: 94, when: containsAny(spiceTerms))
        add("Dessert-style", score: 90, when: containsAny(dessertTerms) || containsAny(bakeryTerms))
        add("Citrus twist", score: 96, when: containsAny(citrusTerms))
        add("Berry-inspired", score: 96, when: containsAny(berryTerms))
        add("Tropical twist", score: 95, when: containsAny(tropicalTerms))
        add("Fruit-forward order", score: 86, when: containsAny(fruitTerms))
        add("Plant-milk pick", score: 84, when: containsAny(plantMilkTerms) || analysis?.milk?.contains("oat") == true || analysis?.milk?.contains("almond") == true || analysis?.milk?.contains("soy") == true)
        add("Layered treat", score: 88, when: containsAny(["cream top", "cold foam", "buttercream", "whipped", "layered"]))
        add("House signature", score: 82, when: containsAny(["signature", "house special", "house latte", "cafe special"]))
        add("Low-caffeine choice", score: 86, when: (analysis.map { $0.caffeineModifier != .regular } ?? false) || containsAny(["decaf", "half caf", "half-caf"]))

        add("Washed process", score: 93, when: containsAny(["washed process", "washed ethiopian", "washed colombian", "washed kenya"]))
        add("Natural process", score: 93, when: containsAny(["natural process", "natural ethiopian", "dry process"]))
        add("Honey process", score: 93, when: containsAny(["honey process", "yellow honey", "red honey", "black honey"]))
        add("Single-origin", score: 88, when: containsAny(["single origin", "ethiopian", "ethiopia", "kenyan", "kenya", "colombian", "colombia", "guatemala", "rwanda", "burundi", "panama geisha", "gesha"]))

        let manualBrew = analysis.map {
            [.pourOver, .chemex, .aeropress, .frenchPress].contains($0.preparation)
        } ?? containsAny(["pour over", "pourover", "chemex", "aeropress", "french press", "v60"])
        add("Manual brew", score: 91, when: manualBrew)

        let flavorCount = Set((analysis?.flavors ?? []) + (analysis?.additions ?? [])).count
        add("Creative flavor build", score: 80, when: flavorCount >= 2 || containsAny([" and ", " infused ", " flight "]))
        add("Matcha creation", score: 89, when: analysis?.family == .matcha && (flavorCount > 0 || containsAny(fruitTerms + dessertTerms)))
        add("Chilled ritual", score: 72, when: analysis.map { $0.temperature != .hot } ?? containsAny(["iced", "cold", "frozen"]))
        add("Home experiment", score: 70, when: context != .cafe)

        var seen = Set<String>()
        return candidates
            .sorted { lhs, rhs in
                lhs.score == rhs.score ? lhs.title < rhs.title : lhs.score > rhs.score
            }
            .compactMap { candidate in
                guard seen.insert(candidate.title).inserted else { return nil }
                return candidate.title
            }
            .prefix(max(0, limit))
            .map { $0 }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
