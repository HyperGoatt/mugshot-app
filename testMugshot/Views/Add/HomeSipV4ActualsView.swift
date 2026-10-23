import SwiftUI

/// One optional record of what happened across the base and the assembled drink.
/// Empty rows are unknown, never implied matches with the recipe.
struct HomeSipV4ActualsView: View {
    @Binding var draft: SipDraft
    let content: HomeRecipeContent
    let isRecoveryLocked: Bool
    let onContinue: () -> Void

    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared

    private var base: HomeRecipeContent {
        guard content.template == .drink else { return content }
        if let reference = content.ingredients.compactMap(\.recipe).first(where: { reference in
            guard let method = store.workspace.version(reference)?.content.method else { return false }
            return [.coffee, .matcha, .hojicha, .tea].contains(method.family)
        }), var linked = store.workspace.version(reference)?.content {
            linked.targets = linked.targets.applying(content.targets)
            return linked
        }
        if content.targets.dose != nil {
            var espresso = content
            espresso.method = .espresso
            espresso.name = "Espresso"
            return espresso
        }
        return content
    }

    private var baseName: String {
        content.template == .drink ? base.name : base.method.title
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(draft.drinkName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color.mugshotSage)
                    Text("How did it go?")
                        .font(.system(size: 31, weight: .semibold, design: .serif))
                    Text("One place for the base and every part of the drink. Leave anything you didn’t measure blank.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }

                if base.targets.dose != nil || base.targets.resolvedOutput != nil
                    || base.targets.seconds != nil || base.targets.steepSeconds != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle(baseName, trailing: "Planned → Today")
                        VStack(spacing: 0) {
                            if let planned = base.targets.dose {
                                amountRow("\(base.method.inputLabel.capitalized)", planned: planned,
                                          unit: "g", key: "dose", value: \.dose)
                            }
                            if let planned = base.targets.resolvedOutput {
                                amountRow(base.method.outputLabel.capitalized, planned: planned,
                                          unit: base.method.outputUnit, key: "output", value: \.output)
                            }
                            if let planned = base.targets.seconds {
                                amountRow("\(base.method == .espresso ? "Shot" : "Brew") time", planned: planned,
                                          unit: "sec", key: "seconds", value: \.seconds)
                            } else if let planned = base.targets.steepSeconds {
                                steepRow(plannedSeconds: planned)
                            }
                        }
                        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mugshotLine))
                    }
                }

                if !content.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("In the \(content.name.remoteTrimmedNonEmpty ?? "drink")", trailing: "Optional")
                        VStack(spacing: 0) {
                            ForEach(content.ingredients.filter { $0.name.remoteTrimmedNonEmpty != nil }) { ingredient in
                                ingredientRow(ingredient)
                            }
                        }
                        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.mugshotLine))
                    }
                }

                let customFields = content.fields.filter(\.isVisible)
                if !customFields.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Other details", trailing: "Optional")
                        ForEach(customFields) { field in
                            if field.kind == .choice {
                                Picker(field.label, selection: customActualBinding(for: field)) {
                                    Text("Unknown").tag("")
                                    ForEach(field.choices, id: \.self) { Text($0).tag($0) }
                                }
                            } else {
                                HStack {
                                    Text(field.label)
                                    Spacer()
                                    TextField("Unknown", text: customActualBinding(for: field))
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(field.kind == .number || field.kind == .duration ? .decimalPad : .default)
                                }
                                .frame(minHeight: 44)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 20))
                }

                MugsyFactNudge(text: factualNudge)
            }
            .padding(.horizontal, DesignSystem.Space.md)
            .padding(.top, 20)
            .padding(.bottom, 115)
        }
        .background(Color.creamWhite)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button(action: onContinue) {
                    Text("Continue to my sip")
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isRecoveryLocked)
                .accessibilityIdentifier("logASipV3.primaryAction")
                Text("You can skip anything unmeasured")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mugshotSage)
            }
            .padding(.horizontal, DesignSystem.Space.md)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
        }
    }

    private func sectionTitle(_ title: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer()
            Text(trailing).font(.caption).foregroundStyle(Color.secondaryText)
        }
    }

    private func amountRow(
        _ title: String, planned: Double, unit: String, key: String,
        value: WritableKeyPath<HomeAttemptActuals, Double?>
    ) -> some View {
        HomeV4ActualAmountRow(
            title: title, planned: planned, unit: unit,
            amount: Binding(
                get: { draft.homeAttemptActuals[keyPath: value] },
                set: { newValue in
                    var actuals = draft.homeAttemptActuals
                    actuals[keyPath: value] = newValue
                    actuals.confirmedAsPlannedKeys.remove(key)
                    draft.homeAttemptActuals = actuals
                }
            ),
            confirmed: Binding(
                get: { draft.homeAttemptActuals.confirmedAsPlannedKeys.contains(key) },
                set: { confirmation in
                    var actuals = draft.homeAttemptActuals
                    if confirmation {
                        actuals[keyPath: value] = planned
                        actuals.confirmedAsPlannedKeys.insert(key)
                    } else {
                        actuals[keyPath: value] = nil
                        actuals.confirmedAsPlannedKeys.remove(key)
                    }
                    draft.homeAttemptActuals = actuals
                }
            )
        )
    }

    private func ingredientRow(_ ingredient: HomeRecipeIngredient) -> some View {
        let key = HomeAttemptActuals.ingredientKey(ingredient.id)
        return HomeV4ActualAmountRow(
            title: ingredient.name, planned: ingredient.amount, unit: ingredient.unit,
            amount: Binding(
                get: { draft.homeAttemptActuals.ingredients.first { $0.ingredientID == ingredient.id }?.amount },
                set: { newValue in
                    var actuals = draft.homeAttemptActuals
                    actuals.ingredients.removeAll { $0.ingredientID == ingredient.id }
                    actuals.confirmedAsPlannedKeys.remove(key)
                    if let newValue {
                        actuals.ingredients.append(HomeIngredientActual(
                            ingredientID: ingredient.id, amount: newValue, unit: ingredient.unit
                        ))
                    }
                    draft.homeAttemptActuals = actuals
                }
            ),
            confirmed: Binding(
                get: { draft.homeAttemptActuals.confirmedAsPlannedKeys.contains(key) },
                set: { confirmation in
                    var actuals = draft.homeAttemptActuals
                    actuals.ingredients.removeAll { $0.ingredientID == ingredient.id }
                    if confirmation, let amount = ingredient.amount {
                        actuals.ingredients.append(HomeIngredientActual(
                            ingredientID: ingredient.id, amount: amount,
                            unit: ingredient.unit, wasConfirmedAsPlanned: true
                        ))
                        actuals.confirmedAsPlannedKeys.insert(key)
                    } else {
                        actuals.confirmedAsPlannedKeys.remove(key)
                    }
                    draft.homeAttemptActuals = actuals
                }
            )
        )
    }

    private func steepRow(plannedSeconds: Double) -> some View {
        let divisor: Double = plannedSeconds >= 3_600 ? 3_600 : plannedSeconds >= 60 ? 60 : 1
        let unit = divisor == 3_600 ? "hr" : divisor == 60 ? "min" : "sec"
        return HomeV4ActualAmountRow(
            title: "Steep duration", planned: plannedSeconds / divisor, unit: unit,
            amount: Binding(
                get: { draft.homeAttemptActuals.seconds.map { $0 / divisor } },
                set: { value in
                    var actuals = draft.homeAttemptActuals
                    actuals.seconds = value.map { $0 * divisor }
                    actuals.confirmedAsPlannedKeys.remove("seconds")
                    draft.homeAttemptActuals = actuals
                }
            ),
            confirmed: Binding(
                get: { draft.homeAttemptActuals.confirmedAsPlannedKeys.contains("seconds") },
                set: { confirmed in
                    var actuals = draft.homeAttemptActuals
                    actuals.seconds = confirmed ? plannedSeconds : nil
                    if confirmed { actuals.confirmedAsPlannedKeys.insert("seconds") }
                    else { actuals.confirmedAsPlannedKeys.remove("seconds") }
                    draft.homeAttemptActuals = actuals
                }
            )
        )
    }

    private var factualNudge: String {
        let differences = draft.homeAttemptActuals.factualDifferences(
            from: base.targets,
            inputLabel: base.method.inputLabel.capitalized,
            outputLabel: base.method.outputLabel.capitalized,
            outputUnit: base.method.outputUnit,
            ingredients: content.ingredients
        )
        if differences.isEmpty { return "Anything unmeasured stays unknown. Taste comes next." }
        return "\(differences.prefix(2).joined(separator: "; ")). Taste comes next."
    }

    private func customActualBinding(for definition: HomeCustomField) -> Binding<String> {
        Binding(get: {
            draft.homeAttemptActuals.customFields.first {
                ($0.stableKey ?? $0.id.uuidString) == (definition.stableKey ?? definition.id.uuidString)
            }?.value ?? ""
        }, set: { value in
            var actuals = draft.homeAttemptActuals
            let key = definition.stableKey ?? definition.id.uuidString
            actuals.customFields.removeAll { ($0.stableKey ?? $0.id.uuidString) == key }
            if !value.isEmpty {
                var field = definition
                field.value = value
                actuals.customFields.append(field)
            }
            draft.homeAttemptActuals = actuals
        })
    }
}

private struct HomeV4ActualAmountRow: View {
    let title: String
    let planned: Double?
    let unit: String
    @Binding var amount: Double?
    @Binding var confirmed: Bool
    @State private var isEditing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(2)
                Spacer(minLength: 4)
                if let planned {
                    Text("\(HomeRecipeContent.number(planned)) \(unit) planned")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    Text("No planned amount")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            if confirmed {
                HStack(spacing: 8) {
                    Text("✓ As planned")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.mugshotSage)
                    Spacer()
                    Button("Change") { confirmed = false; isEditing = true }
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                    Button("Unknown") { confirmed = false; isEditing = false }
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                }
            } else if isEditing || amount != nil {
                HStack(spacing: 3) {
                    TextField("0", text: $text)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                        .focused($focused)
                        .frame(maxWidth: .infinity)
                    Text(unit).font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
                    Button("Unknown") {
                        amount = nil
                        text = ""
                        isEditing = false
                        focused = false
                    }
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
                }
                .accessibilityLabel("Actual \(title)")
                .onChange(of: text) { _, newText in
                    let normalized = newText.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
                    amount = Double(normalized)
                }
                .onAppear { text = amount.map { HomeRecipeContent.number($0) } ?? "" }
                .onChange(of: amount) { _, newValue in
                    if !focused { text = newValue.map { HomeRecipeContent.number($0) } ?? "" }
                }
            } else {
                HStack(spacing: 10) {
                    Text("Unknown")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                    Spacer()
                    if planned != nil {
                        Button("As planned") { confirmed = true; MugshotHaptic.selection.play() }
                            .font(.caption.weight(.bold))
                            .frame(minHeight: 44)
                    }
                    Button { isEditing = true } label: {
                        Image(systemName: "pencil")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Enter actual \(title)")
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minHeight: 76)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 14) }
        .onChange(of: isEditing) { _, editing in
            if editing {
                Task { @MainActor in focused = true }
            }
        }
    }
}

private struct MugsyFactNudge: View {
    let text: String
    var body: some View {
        HStack(spacing: 14) {
            MugsyModelView(configuration: .init(prop: .journalNotebook))
                .frame(width: 54, height: 54)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Mugsy’s note")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                Text(text).font(.caption).foregroundStyle(Color.mugshotSageText)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(Color.mugshotMint.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
    }
}
