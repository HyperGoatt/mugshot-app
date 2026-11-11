import Foundation

enum CoffeeAssistanceRecipeImport {
    /// Owns only automatically generated draft fields. Edited/deleted fields are
    /// protected by their source identity across subsequent OCR/provider reads.
    struct Draft {
        private var ingredients: [HomeRecipeIngredient] = []
        private var steps: [HomePreparationStep] = []
        private var origins: [UUID: CoffeeAssistanceField] = [:]
        private var protected: [CoffeeAssistanceField] = []
        private var name: String?
        private var protectsName = false
        private var method: HomeBrewMethod?
        private var customMethod = ""

        mutating func apply(_ fields: [CoffeeAssistanceField], to content: inout HomeRecipeContent) {
            guard content.sourceReuseAllowed != false else { return }
            let allowed = fields.filter { field in
                !(field.key == "name" && protectsName) && !protected.contains { original in
                    guard original.key == field.key else { return false }
                    let a = normalized(original.sourceQuote), b = normalized(field.sourceQuote)
                    return normalized(original.value) == normalized(field.value) || (!a.isEmpty && a == b)
                        || (min(a.count, b.count) >= 8 && (a.contains(b) || b.contains(a)))
                }
            }
            let previous = content
            CoffeeAssistanceRecipeImport.apply(allowed, to: &content)
            let addedIngredients = content.ingredients.filter { item in !previous.ingredients.contains { $0.id == item.id } }
            let addedSteps = content.steps.filter { item in !previous.steps.contains { $0.id == item.id } }
            ingredients += addedIngredients; steps += addedSteps
            for item in addedIngredients { origins[item.id] = allowed.first { $0.key == "ingredient" && $0.value == item.name } }
            for item in addedSteps { origins[item.id] = allowed.first { $0.key == "step" && $0.value == item.instruction } }
            if previous.name.isEmpty, !content.name.isEmpty { name = content.name }
            if previous.method == .other, previous.customMethodName.isEmpty,
               content.method != .other || !content.customMethodName.isEmpty {
                method = content.method; customMethod = content.customMethodName
            }
        }

        mutating func replace(_ fields: [CoffeeAssistanceField], to content: inout HomeRecipeContent) {
            guard content.sourceReuseAllowed != false else { return }
            // An incomplete suggestion cannot erase a usable fallback
            // section that it did not actually replace.
            removeGenerated(from: &content, keys: Set(fields.map(\.key)))
            apply(fields, to: &content)
        }

        mutating func removeGenerated(from content: inout HomeRecipeContent,
                                      keys: Set<String> = ["ingredient", "step", "name", "method"]) {
            if keys.contains("ingredient") {
                for item in ingredients where !content.ingredients.contains(item) {
                    if let origin = origins[item.id] { protected.append(origin) }
                }
                content.ingredients.removeAll { ingredients.contains($0) }
                for item in ingredients { origins[item.id] = nil }
                ingredients = []
            }
            if keys.contains("step") {
                for item in steps where !content.steps.contains(item) {
                    if let origin = origins[item.id] { protected.append(origin) }
                }
                content.steps.removeAll { steps.contains($0) }
                for item in steps { origins[item.id] = nil }
                steps = []
            }
            if keys.contains("name"), let name {
                if content.name == name { content.name = "" } else { protectsName = true }
                self.name = nil
            }
            if keys.contains("method") {
                if content.method == method, content.customMethodName == customMethod {
                    content.method = .other; content.customMethodName = ""
                }
                method = nil; customMethod = ""
            }
        }

        private func normalized(_ text: String) -> String {
            text.lowercased().replacingOccurrences(of: "[^\\p{L}\\p{N}]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func source(_ content: HomeRecipeContent) -> [CoffeeAssistanceEvidence] {
        guard content.sourceReuseAllowed != false else { return [] }
        let text = content.sourceText
        var result = [CoffeeAssistanceEvidence(id: "recipe-target", title: "Selected recipe",
            detail: bounded("Name: \(content.name)\nUse: \(content.template.rawValue)"))]
        let hasCredit = !content.creatorCredit.isEmpty || !content.sourceURL.isEmpty
        var remaining = text.unicodeScalars[...]
        while !remaining.isEmpty && result.count < (hasCredit ? 19 : 20) {
            // Match the evidence UTF-16 limit before advancing. Counting visible
            // characters first can discard the rest of a multi-scalar character.
            var end = remaining.startIndex
            var units = 0
            while end != remaining.endIndex {
                let nextUnits = remaining[end].value > 0xFFFF ? 2 : 1
                guard units + nextUnits <= 800 else { break }
                units += nextUnits
                end = remaining.index(after: end)
            }
            let part = String(remaining[..<end])
            remaining = remaining[end...]
            result.append(CoffeeAssistanceEvidence(id: "recipe-source-\(result.count)", title: "Recipe source text", detail: part))
        }
        if hasCredit {
            result.insert(CoffeeAssistanceEvidence(id: "recipe-credit", title: "Source and credit",
                detail: bounded("Creator: \(content.creatorCredit)\nSource: \(content.sourceURL)")), at: 0)
        }
        return result
    }

    private static func bounded(_ text: String) -> String {
        var output = "", units = 0
        for scalar in text.unicodeScalars {
            let count = scalar.value > 0xFFFF ? 2 : 1
            guard units + count <= 800 else { break }
            output.unicodeScalars.append(scalar); units += count
        }
        return output
    }

    /// Fills an editable capture draft; ordinary Save stays separate. Existing content is preserved; import
    /// fills blank identity fields and appends selected ingredients/steps.
    static func apply(_ fields: [CoffeeAssistanceField], to content: inout HomeRecipeContent) {
        guard content.sourceReuseAllowed != false else { return }
        for field in fields {
            switch field.key {
            case "name" where content.name.isEmpty: content.name = field.value
            case "creatorCredit" where content.creatorCredit.isEmpty: content.creatorCredit = field.value
            case "sourceURL" where content.sourceURL.isEmpty:
                if let url = URL(string: field.value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
                    content.sourceURL = field.value
                }
            case "ingredient":
                // Retain the exact printed amount/name together; do not guess units.
                if !content.ingredients.contains(where: { $0.name == field.value }) {
                    content.ingredients.append(HomeRecipeIngredient(name: field.value, amount: nil, unit: ""))
                }
            case "step":
                if !content.steps.contains(where: { $0.instruction == field.value }) {
                    content.steps.append(HomePreparationStep(instruction: field.value))
                }
            case "notes":
                if !content.notes.contains(field.value) {
                    content.notes += (content.notes.isEmpty ? "" : "\n") + field.value
                }
            case "method" where content.method == .other && content.customMethodName.isEmpty:
                let method = HomeBrewMethod(storedValue: field.value)
                content.method = method
                if method == .other { content.customMethodName = field.value }
            default: break
            }
        }
    }
}
