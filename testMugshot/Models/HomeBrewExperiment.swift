import Foundation

/// The instruction the owner chose to bring into a private repeat draft.
struct HomeBrewExperimentPlan: Codable, Equatable {
    let title: String
    let instruction: String
    let tasteFor: String?
}

struct HomeBrewExperiment: Equatable {
    struct Measurement: Equatable {
        let isRecorded: Bool
        let before: String
        let next: String
        var source: String { isRecorded ? "Recorded this sip" : "Recipe plan" }
    }

    let plan: HomeBrewExperimentPlan
    var measurement: Measurement? = nil
    var change: HomeBrewPlanChange? = nil

    static func suggestions(for attempt: HomeAttemptRecord, comparison: HomeAttemptComparison) -> [Self] {
        let candidates = comparison.changes.compactMap(measuredExperiment)
        let ordered = candidates.filter { $0.measurement?.isRecorded == true }
            + candidates.filter { $0.measurement?.isRecorded == false }
        var ideas = Array(ordered.prefix(2))
        if let idea = tastingExperiment(for: attempt) { ideas.append(idea) }
        ideas.append(Self(plan: HomeBrewExperimentPlan(
            title: "Taste it at two moments",
            instruction: "Take a small sip when the drink is ready. Wait two minutes, then taste it again.",
            tasteFor: "Which flavor stands out more in the second sip?"
        )))
        ideas.append(Self(plan: HomeBrewExperimentPlan(
            title: "Record a starting point",
            instruction: "Make your usual drink and measure one ingredient you normally pour by eye. Write down the amount in your sip.",
            tasteFor: "Name one flavor or texture you’d like to repeat or change."
        )))
        return ideas
    }

    private static func measuredExperiment(_ row: HomeAttemptComparison.Row) -> Self? {
        guard let planned = row.planned, let expected = planned.amount,
              expected > 0, HomeBrewPlanChange.accepts(expected, for: row.key) else { return nil }
        let unit = row.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["g", "ml", "oz", "fl oz", "tsp", "tbsp", "s", "°c", "°f"].contains(unit) else { return nil }

        let actual = row.actual.flatMap { reading -> HomeAttemptComparison.Reading? in
            guard let amount = reading.amount, amount > 0, HomeBrewPlanChange.accepts(amount, for: row.key),
                  reading.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == unit else { return nil }
            return reading
        }
        let baseline = actual ?? planned
        let amount = baseline.amount ?? expected
        let next: Double
        if amount != expected {
            // Revisit the recipe amount when the recorded pour differed.
            next = expected
        } else {
            switch row.key {
            case .temperature: next = amount - (unit == "°f" ? 4 : 2)
            case .duration: next = (amount * 0.9).rounded()
            default: next = (amount * 90).rounded() / 100
            }
        }
        guard next > 0, next != amount, HomeBrewPlanChange.accepts(next, for: row.key) else { return nil }

        let nextReading = HomeAttemptComparison.Reading(amount: next, unit: row.unit).display
        let title = "Adjust \(row.title.lowercased())"
        let tasteFor: String
        switch row.key {
        case .duration, .temperature: tasteFor = "Notice how the aroma and finish compare."
        case .ingredient: tasteFor = "Notice how this ingredient changes the balance of the drink."
        default: tasteFor = "Does the next sip taste lighter, stronger, or about the same?"
        }
        return Self(
            plan: HomeBrewExperimentPlan(title: title, instruction: "Use \(nextReading) for \(row.title.lowercased()) in your next brew.", tasteFor: tasteFor),
            measurement: Measurement(isRecorded: actual != nil, before: baseline.display, next: nextReading),
            change: next == expected ? nil : HomeBrewPlanChange(key: row.key, expected: expected, amount: next)
        )
    }

    private static func tastingExperiment(for attempt: HomeAttemptRecord) -> Self? {
        let method = (attempt.preparation ?? attempt.targets)?.method
        let name = attempt.name
        let plan: HomeBrewExperimentPlan
        if name.localizedCaseInsensitiveContains("latte") || [.matchaLatte, .hojichaLatte, .teaLatte].contains(method) {
            plan = HomeBrewExperimentPlan(
                title: "Find the sweetness you like",
                instruction: "Taste the latte before adding sweetener. If you use syrup, add a little at a time and taste after each small pour.",
                tasteFor: "Stop where you can still taste the base through the sweetness."
            )
        } else if method?.family == .matcha || name.localizedCaseInsensitiveContains("matcha") {
            plan = HomeBrewExperimentPlan(
                title: "Try a longer whisk",
                instruction: "Use your usual matcha and water. Whisk for five extra seconds.",
                tasteFor: "Notice whether the texture feels smoother."
            )
        } else if [.westernTea, .gongfuTea, .steepedHojicha].contains(method) {
            plan = HomeBrewExperimentPlan(
                title: "Compare two steep times",
                instruction: "Taste a spoonful at your usual steep time. Give the leaves 15 more seconds, then taste again.",
                tasteFor: "Look for more aroma, body, or dryness in the second taste."
            )
        } else {
            return nil
        }
        return Self(plan: plan)
    }
}
