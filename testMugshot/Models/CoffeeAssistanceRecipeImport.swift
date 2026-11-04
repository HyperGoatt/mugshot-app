import Foundation

enum CoffeeAssistanceRecipeImport {
    static func source(_ content: HomeRecipeContent) -> [CoffeeAssistanceEvidence] {
        guard content.sourceReuseAllowed != false else { return [] }
        let text = content.sourceText
        var result: [CoffeeAssistanceEvidence] = []
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
