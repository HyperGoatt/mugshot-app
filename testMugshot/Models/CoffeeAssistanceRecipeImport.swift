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
            let added = CoffeeAssistanceRecipeImport.apply(allowed, to: &content)
            ingredients += content.ingredients.filter { added[$0.id] != nil }
            steps += content.steps.filter { added[$0.id] != nil }
            origins.merge(added) { _, new in new }
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
    @discardableResult
    static func apply(_ fields: [CoffeeAssistanceField], to content: inout HomeRecipeContent) -> [UUID: CoffeeAssistanceField] {
        guard content.sourceReuseAllowed != false else { return [:] }
        var added: [UUID: CoffeeAssistanceField] = [:]
        for field in fields {
            switch field.key {
            case "name" where content.name.isEmpty: content.name = field.value
            case "creatorCredit" where content.creatorCredit.isEmpty: content.creatorCredit = field.value
            case "sourceURL" where content.sourceURL.isEmpty:
                if let url = URL(string: field.value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
                    content.sourceURL = field.value
                }
            case "ingredient":
                let ingredient = PrintedRecipeIngredient.parse(field.value)
                if !content.ingredients.contains(where: {
                    $0.recipe == nil && $0.name == ingredient.name && $0.amount == ingredient.amount && $0.unit == ingredient.unit
                }) {
                    content.ingredients.append(ingredient)
                    added[ingredient.id] = field
                }
            case "step":
                if !content.steps.contains(where: { $0.instruction == field.value }) {
                    let step = HomePreparationStep(instruction: field.value)
                    content.steps.append(step)
                    added[step.id] = field
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
        return added
    }
}

/// Splits only printed measurements that fit the editor's single numeric amount.
/// Keep the original line for ranges, ambiguous prefixes and unmeasured ingredients.
private enum PrintedRecipeIngredient {
    private static let fractions: [Character: Double] = [
        "¼": 1 / 4, "½": 1 / 2, "¾": 3 / 4, "⅐": 1 / 7, "⅑": 1 / 9, "⅒": 1 / 10,
        "⅓": 1 / 3, "⅔": 2 / 3, "⅕": 1 / 5, "⅖": 2 / 5, "⅗": 3 / 5, "⅘": 4 / 5,
        "⅙": 1 / 6, "⅚": 5 / 6, "⅛": 1 / 8, "⅜": 3 / 8, "⅝": 5 / 8, "⅞": 7 / 8
    ]
    private static let leadingAmount = expression(
        #"^((?:[0-9]+\h+)?[0-9]+\h*[/⁄]\h*[0-9]+|(?:[0-9]+\h*)?[\#(String(fractions.keys.sorted()))]|[0-9]+(?:\.[0-9]+)?|\.[0-9]+|an?)(.*)$"#
    )
    private static let leadingUnit = expression(
        #"^(fluid\h+ounces?|fl\.?\h*oz|tablespoons?|teaspoons?|tbsp|tsp|cups?|milliliters?|millilitres?|ml|liters?|litres?|l|kilograms?|kg|grams?|g|milligrams?|mg|ounces?|oz|pounds?|lbs?|pinch(?:es)?|dash(?:es)?|drops?|splashes?|shots?|scoops?|cans?|sticks?)\.?(?=\s|$)(?:\s+of(?=\s))?\s*(.*)$"#
    )
    private static let optional = expression(#"^(optional\s*:)\s*(.*)$"#)
    private static let preparation = expression(#"^((?:zest|juice)\s+of)\s+(.*)$"#)

    static func parse(_ line: String) -> HomeRecipeIngredient {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let qualifier = split(text, with: optional)
        let body = qualifier?.tail ?? text
        var ingredient: HomeRecipeIngredient?
        if let prep = split(body, with: preparation), let measured = measured(prep.tail), measured.unit.isEmpty {
            ingredient = measured
            ingredient?.name = "\(prep.head) \(measured.name)"
        } else {
            ingredient = measured(body)
        }
        guard var ingredient else { return HomeRecipeIngredient(name: text, unit: "") }
        if qualifier != nil { ingredient.name += " (optional)" }
        return ingredient
    }

    private static func measured(_ text: String) -> HomeRecipeIngredient? {
        guard let parts = split(text, with: leadingAmount) else { return nil }
        let remainder = parts.tail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard remainder.first?.isLetter == true || remainder.hasPrefix("(") else { return nil }
        let next = remainder.lowercased().split(whereSeparator: \.isWhitespace).first
        guard next != "to", next != "or", next != "and" else { return nil }
        let unit = split(remainder, with: leadingUnit)
        let name = unit?.tail ?? remainder
        guard !name.isEmpty else { return nil }
        let article = ["a", "an"].contains(parts.head.lowercased())
        // Require a recognizable unit for an article or an amount written without a space.
        guard unit != nil || (!article && parts.tail.first?.isWhitespace == true),
              let amount = article ? 1 : number(parts.head), amount.isFinite, amount > 0 else { return nil }
        let spelling = unit?.head.lowercased().replacingOccurrences(of: ".", with: "") ?? ""
        let unitName = spelling.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return HomeRecipeIngredient(name: name, amount: amount, unit: unitName == "floz" ? "fl oz" : unitName)
    }

    private static func number(_ token: String) -> Double? {
        if let glyph = token.last, let fraction = fractions[glyph] {
            let prefix = token.dropLast().trimmingCharacters(in: .whitespaces)
            guard let whole = prefix.isEmpty ? 0 : Double(prefix) else { return nil }
            return whole + fraction
        }
        let fraction = token.split(omittingEmptySubsequences: false) { $0 == "/" || $0 == "⁄" }
        guard fraction.count == 2 else { return Double(token) }
        let numeratorParts = fraction[0].split(whereSeparator: \.isWhitespace)
        guard let numerator = numeratorParts.last.flatMap({ Double($0) }),
              let denominator = Double(fraction[1].trimmingCharacters(in: .whitespaces)), denominator > 0 else { return nil }
        let whole = numeratorParts.count == 2 ? Double(numeratorParts[0]) ?? 0 : 0
        return whole + numerator / denominator
    }

    private static func expression(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    }

    private static func split(_ text: String, with expression: NSRegularExpression?) -> (head: String, tail: String)? {
        guard let match = expression?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let head = Range(match.range(at: 1), in: text), let tail = Range(match.range(at: 2), in: text) else { return nil }
        return (String(text[head]), String(text[tail]))
    }
}
