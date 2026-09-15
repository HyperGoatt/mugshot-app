import SwiftUI

struct HomeRecipeEditorView: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    @State var draft: HomeRecipeEditorDraft
    let onSaved: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var advanced = false
    @State private var linkedPicker = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("Recipe name", text: $draft.content.name)
                    .accessibilityIdentifier("home.recipe.name")
                Picker("Starting template", selection: $draft.content.template) {
                    ForEach(HomeRecipeTemplate.allCases) { Text($0.title).tag($0) }
                }
                TextField("Inspiration link (optional)", text: $draft.content.sourceURL)
                    .textInputAutocapitalization(.never).keyboardType(.URL)
                TextField("Creator credit (optional)", text: $draft.content.creatorCredit)
            }
            if draft.content.template == .coffee {
                Section("Coffee preparation") {
                    Picker("Method", selection: $draft.content.method) {
                        ForEach(HomeBrewMethod.allCases) { Text($0.title).tag($0) }
                    }
                    if draft.content.metricConfiguration != nil {
                        HomeConfiguredTargetsEditor(content: $draft.content)
                    } else if draft.content.method != .other {
                        HomeTargetsEditor(targets: $draft.content.targets, method: draft.content.method, advanced: $advanced)
                    }
                    NavigationLink("Customize preparation fields") {
                        HomeRecipeFieldConfigurationScreen(content: $draft.content)
                    }
                }
                Section("Beans and equipment") {
                    let library = HomeLibraryStore.shared.load(in: store.scope)
                    Menu(draft.content.coffee?.displayName ?? "Choose coffee (optional)") {
                        Button("None") { draft.content.coffee = nil }
                        ForEach(library.bags.filter { $0.status.isCurrent }) { bag in
                            Button(bag.displayName) { draft.content.coffee = bag.safeSnapshot }
                        }
                    }
                    ForEach(library.equipment.filter { $0.archivedAt == nil }) { gear in
                        Toggle(gear.displayName, isOn: Binding(get: {
                            draft.content.equipment.contains(gear.snapshot)
                        }, set: { selected in
                            draft.content.equipment.removeAll { $0 == gear.snapshot }
                            if selected { draft.content.equipment.append(gear.snapshot) }
                        }))
                    }
                }
            }
            Section("Ingredients") {
                ForEach($draft.content.ingredients) { $ingredient in
                    VStack(alignment: .leading) {
                        TextField("Ingredient", text: $ingredient.name)
                        HStack {
                            HomeNumberField(title: "Amount", value: $ingredient.amount)
                            TextField("Unit", text: $ingredient.unit).frame(maxWidth: 85)
                        }
                        if ingredient.recipe != nil {
                            Label("Linked recipe version", systemImage: "link").font(.caption).foregroundStyle(.secondary)
                            Button("Use as plain ingredient") { ingredient.recipe = nil }
                        }
                    }
                }
                .onDelete { draft.content.ingredients.remove(atOffsets: $0) }
                .onMove { draft.content.ingredients.move(fromOffsets: $0, toOffset: $1) }
                Button("Add ingredient", systemImage: "plus") { draft.content.ingredients.append(HomeRecipeIngredient()) }
                Button("Link a recipe", systemImage: "link") { linkedPicker = true }
            }
            Section("Instructions") {
                ForEach($draft.content.steps) { $step in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Instruction", text: $step.instruction, axis: .vertical)
                        HomeNumberField(title: "Start at (seconds)", value: $step.startSeconds)
                        HomeNumberField(title: "Wait (seconds)", value: $step.waitSeconds)
                        if draft.content.method == .pourOver {
                            Picker("Water", selection: $step.waterMode) {
                                ForEach(HomeWaterTargetMode.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            HomeNumberField(title: "Water (g)", value: $step.waterGrams)
                        }
                    }
                }
                .onDelete { draft.content.steps.remove(atOffsets: $0) }
                .onMove { draft.content.steps.move(fromOffsets: $0, toOffset: $1) }
                Button("Add step", systemImage: "plus") { draft.content.steps.append(HomePreparationStep()) }
            }
            Section("Yield and organization") {
                TextField("Servings", value: $draft.content.servings, format: .number).keyboardType(.decimalPad)
                TextField("Yield, e.g. one bottle", text: $draft.content.yieldDescription)
                TextField("Tags, separated by commas", text: Binding(get: { draft.content.tags.joined(separator: ", ") }, set: {
                    draft.content.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }))
                TextField("Preparation notes", text: $draft.content.notes, axis: .vertical)
            }
            Section("Custom fields") {
                ForEach($draft.content.fields) { $field in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Field name", text: $field.label)
                        Picker("Type", selection: $field.kind) {
                            ForEach(HomeCustomFieldKind.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        if field.kind == .choice {
                            TextField("Choices, separated by commas", text: Binding(get: { field.choices.joined(separator: ", ") }, set: {
                                field.choices = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                            }))
                            Picker("Value", selection: $field.value) {
                                Text("Not set").tag("")
                                ForEach(field.choices, id: \.self) { Text($0).tag($0) }
                            }
                        } else {
                            TextField("Value", text: $field.value)
                                .keyboardType(field.kind == .number || field.kind == .duration ? .decimalPad : .default)
                            if field.kind == .number { TextField("Unit", text: $field.unit) }
                            if field.kind == .duration { Text("Duration in seconds").font(.caption).foregroundStyle(.secondary) }
                        }
                        Toggle("Show when making", isOn: $field.isVisible)
                    }
                }
                .onDelete { draft.content.fields.remove(atOffsets: $0) }
                .onMove { draft.content.fields.move(fromOffsets: $0, toOffset: $1) }
                Button("Add custom field", systemImage: "plus") { draft.content.fields.append(HomeCustomField()) }
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
        }
        .scrollContentBackground(.hidden).background(Color.creamWhite)
        .navigationTitle(draft.recipeID == nil ? "New recipe" : "Edit recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            ToolbarItem(placement: .primaryAction) { EditButton() }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save recipe") { save() }
                    .disabled(draft.content.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("home.recipe.save")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: draft) { _, value in
            do { try store.saveDraft(value) } catch { self.error = error.localizedDescription }
        }
        .sheet(isPresented: $linkedPicker) {
            NavigationStack {
                List(store.workspace.recipes.filter { !$0.isArchived && $0.id != draft.recipeID }) { record in
                    if let current = record.current {
                        Button {
                            draft.content.ingredients.append(HomeRecipeIngredient(name: current.content.name,
                                amount: 1, unit: "serving", recipe: HomeRecipeReference(recipeID: record.id, versionID: current.id)))
                            linkedPicker = false
                        } label: { HomeRecipeRow(content: current.content) }
                    }
                }.navigationTitle("Link a recipe")
            }
        }
    }
    private func save() {
        do { let id = try store.saveRecipe(draft); onSaved(id); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

private struct HomeRecipeFieldConfigurationScreen: View {
    @Binding var content: HomeRecipeContent
    private var fields: Binding<[HomeRecipeMetricConfiguration]> {
        Binding(get: { content.configuredMetrics }, set: { content.metricConfiguration = $0 })
    }
    var body: some View {
        List {
            Section {
                Text("Rename, hide, or reorder fields for this recipe. Hiding a field keeps its saved value and calculations.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(fields) { $field in
                VStack(alignment: .leading) {
                    TextField(field.metric.label, text: $field.label)
                        .accessibilityLabel("Label for \(field.metric.label)")
                    Toggle("Show field", isOn: $field.isVisible)
                }
            }
            .onMove { source, destination in
                var values = content.configuredMetrics
                values.move(fromOffsets: source, toOffset: destination)
                content.metricConfiguration = values
            }
            Button("Use method defaults") { content.metricConfiguration = nil }
        }
        .navigationTitle("Preparation fields")
        .toolbar { EditButton() }
        .scrollContentBackground(.hidden).background(Color.creamWhite)
    }
}

struct HomeConfiguredTargetsEditor: View {
    @Binding var content: HomeRecipeContent
    var body: some View {
        Picker("Calculate", selection: $content.targets.calculation) {
            ForEach(HomeRecipeCalculation.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        if content.targets.calculation == .ratio {
            HomeNumberField(title: "Ratio · 1 to", value: $content.targets.ratio)
        } else {
            LabeledContent("Calculated ratio", value: content.targets.resolvedRatio.map { "1:\(HomeRecipeContent.number($0))" } ?? "Not set")
        }
        ForEach(content.configuredMetrics.filter(\.isVisible)) { field in
            let label = field.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? field.metric.label : field.label
            if field.metric == .output, content.targets.calculation == .ratio {
                LabeledContent(label, value: content.targets.resolvedOutput.map { "\(HomeRecipeContent.number($0)) g" } ?? "Not set")
            } else if let keyPath = field.metric.numericKeyPath {
                HomeNumberField(title: label, value: Binding(get: { content.targets[keyPath: keyPath] }, set: { content.targets[keyPath: keyPath] = $0 }))
            } else if field.metric == .grind {
                TextField(label, text: $content.targets.grind)
            } else if field.metric == .dilution {
                TextField(label, text: $content.targets.dilution)
            }
        }
    }
}

struct HomeNumberField: View {
    let title: String
    @Binding var value: Double?
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Optional", value: $value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .accessibilityLabel(title)
        }
    }
}

struct HomeTargetsEditor: View {
    @Binding var targets: HomeRecipeTargets
    let method: HomeBrewMethod
    @Binding var advanced: Bool
    var body: some View {
        if method == .pod {
            HomeNumberField(title: "Target beverage (g)", value: Binding(get: { targets.output }, set: {
                targets.output = $0
                targets.calculation = .output
            }))
            HomeNumberField(title: "Target time (seconds)", value: $targets.seconds)
        } else {
        HomeNumberField(title: "Coffee dose (g)", value: $targets.dose)
        Picker("Calculate", selection: $targets.calculation) {
            ForEach(HomeRecipeCalculation.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        if targets.calculation == .ratio {
            HomeNumberField(title: "Ratio · 1 to", value: $targets.ratio)
            LabeledContent(method == .espresso ? "Target yield" : "Total water", value: targets.resolvedOutput.map { "\(HomeRecipeContent.number($0)) g" } ?? "Not set")
        } else {
            HomeNumberField(title: method == .espresso ? "Target yield (g)" : "Total water (g)", value: $targets.output)
            LabeledContent("Ratio", value: targets.resolvedRatio.map { "1:\(HomeRecipeContent.number($0))" } ?? "Not set")
        }
        if method == .coldBrew {
            HomeNumberField(title: "Steep duration (hours)", value: Binding(get: { targets.steepSeconds.map { $0 / 3600 } }, set: { targets.steepSeconds = $0.map { $0 * 3600 } }))
            TextField("Serving dilution (optional)", text: $targets.dilution)
        } else {
            HomeNumberField(title: method == .frenchPress || method == .immersion ? "Steep time (seconds)" : "Target time (seconds)", value: $targets.seconds)
        }
        }
        DisclosureGroup("More details", isExpanded: $advanced) {
            if method == .pod { HomeNumberField(title: "Coffee dose (g)", value: $targets.dose) }
            TextField("Grinder setting", text: $targets.grind)
            HomeNumberField(title: "Temperature (°C)", value: $targets.temperature)
            if method == .espresso {
                HomeNumberField(title: "Preinfusion (seconds)", value: $targets.preinfusion)
                HomeNumberField(title: "Pressure (bar)", value: $targets.pressure)
            } else if method != .coldBrew {
                HomeNumberField(title: "Steep (seconds)", value: $targets.steepSeconds)
            }
        }
    }
}

struct HomeRecipeRow: View {
    let content: HomeRecipeContent
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: content.template.symbol).font(.title3).foregroundStyle(Color.mugshotSage).frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(content.name).font(.headline).foregroundStyle(Color.espressoBrown)
                Text(content.summary.isEmpty ? "Saved reference" : content.summary).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 5)
    }
}
