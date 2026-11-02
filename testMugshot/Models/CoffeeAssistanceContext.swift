import Foundation

enum CoffeeAssistanceContext {
    static func journal(_ entries: [JournalEntryProjection], ownerID: UUID,
                        includePrivateNotes: Bool = false) -> [CoffeeAssistanceEvidence] {
        entries.filter { $0.summary.visit.userId == ownerID && $0.summary.visit.uploadState == "complete" }
            .sorted { $0.date > $1.date }.map { entry in
                let visit = entry.summary.visit
                let score = visit.overallScore > 0 ? String(format: "%.1f / 5", visit.overallScore) : "Unrated"
                var facts = ["Date: \(entry.date.formatted(.iso8601.year().month().day()))",
                    "Context: \(entry.context.rawValue)", "Place: \(entry.summary.locationTitle)",
                    "City: \(visit.cityState ?? "Unknown")", "Rating: \(score)",
                    "Caption: \(visit.caption)"]
                if includePrivateNotes, let note = entry.privateNote, !note.isEmpty { facts.append("Private note: \(note)") }
                return CoffeeAssistanceEvidence(id: entry.id.uuidString.lowercased(),
                    title: visit.drinkDisplayName, detail: facts.joined(separator: "\n"))
            }
    }

    static func home(_ attempts: [HomeAttemptRecord], canonicalIDs: Set<UUID>,
                     includePrivateNotes: Bool = false) -> [CoffeeAssistanceEvidence] {
        attempts.filter { $0.savedAt != nil && $0.publicationStatus != .published
            && !canonicalIDs.contains($0.id)
            && !($0.publicationDraftID.map(canonicalIDs.contains) ?? false) }
            .sorted { ($0.savedAt ?? $0.createdAt) > ($1.savedAt ?? $1.createdAt) }
            .map { attempt($0, includePrivateNotes: includePrivateNotes) }
    }

    static func attempt(_ attempt: HomeAttemptRecord, includePrivateNotes: Bool = false) -> CoffeeAssistanceEvidence {
        var values = ["Date: \((attempt.savedAt ?? attempt.createdAt).formatted(.iso8601.year().month().day()))",
            "Context: Private Home sip", "Method: \(attempt.preparation?.methodDisplayName ?? "Unknown")",
            "Reaction: \(CoffeeAssistanceText.bound(attempt.reaction, to: 160))", "Rating: \(attempt.resolvedRating.map { String(format: "%.1f / 5", $0) } ?? "Unrated")"]
        if includePrivateNotes {
            if !attempt.nextTimeNote.isEmpty { values.append("Next-time note: \(CoffeeAssistanceText.bound(attempt.nextTimeNote, to: 160))") }
            if !attempt.privateNote.isEmpty { values.append("Private note: \(CoffeeAssistanceText.bound(attempt.privateNote, to: 120))") }
        }
        if let dose = attempt.actuals.dose { values.append("Recorded input: \(dose) g") }
        if let output = attempt.actuals.output { values.append("Recorded output: \(output) (method units)") }
        if let seconds = attempt.actuals.seconds { values.append("Recorded time: \(seconds) seconds") }
        if let temperature = attempt.actuals.temperature { values.append("Recorded temperature: \(temperature) C") }
        if !attempt.actuals.grind.isEmpty { values.append("Recorded grind setting: \(attempt.actuals.grind)") }
        for actual in attempt.actuals.ingredients.prefix(6) {
            let name = attempt.preparation?.ingredients.first { $0.id == actual.ingredientID }?.name ?? "Ingredient"
            values.append("Recorded ingredient \(CoffeeAssistanceText.bound(name, to: 60)): \(HomeRecipeContent.number(actual.amount)) \(actual.unit)")
        }
        values.append("All unlisted actual measurements are unknown. Preparation targets are not recorded actuals.")
        return CoffeeAssistanceEvidence(id: "home-\(attempt.id.uuidString.lowercased())", title: attempt.name, detail: values.joined(separator: "\n"))
    }

    static func candidates(_ evidence: [CoffeeAssistanceEvidence], query: String) -> [CoffeeAssistanceEvidence] {
        let stopWords: Set<String> = ["what", "was", "that", "the", "where", "find", "with", "from", "this", "have", "when", "which", "did", "and", "for", "my", "of", "in", "i", "a"]
        let terms = query.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
            .filter { !stopWords.contains($0) }
        return evidence.enumerated().sorted { left, right in
            func score(_ item: CoffeeAssistanceEvidence) -> Int {
                let text = (item.title + " " + item.detail).lowercased()
                return terms.filter { text.contains($0) }.count
            }
            let a = score(left.element), b = score(right.element)
            return a == b ? left.offset < right.offset : a > b
        }.prefix(40).map(\.element)
    }

    static func week(_ reflection: JournalReflectionSummary) -> CoffeeAssistanceEvidence {
        CoffeeAssistanceEvidence(id: "period-facts", title: reflection.periodLabel,
            detail: "Verified completed sips: \(reflection.entryCount)\nDistinct cafes: \(reflection.cafeCount)\nPrivate Home sips included: \(reflection.privateHomeEntryCount)\nPeriod: \(reflection.startDate.formatted(.iso8601)) up to but excluding \(reflection.endDate.formatted(.iso8601)). No drafts included.")
    }
}
