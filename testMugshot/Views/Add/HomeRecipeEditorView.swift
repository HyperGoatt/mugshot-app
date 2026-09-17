import SwiftUI

struct HomeRecipeEditorView: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    @State var draft: HomeRecipeEditorDraft
    let onSaved: (UUID) -> Void
    private let originalScope: LocalAccountScope
    @Environment(\.dismiss) private var dismiss
    @State private var advanced: Bool
    @State private var sourceExpanded: Bool
    @State private var showIngredients: Bool
    @State private var showSteps: Bool
    @State private var showOrganization: Bool
    @State private var showCustomFields: Bool
    @State private var showCoffeeLibrary: Bool
    @State private var linkedPicker: HomeRecipeLinkPickerPresentation?
    @State private var error: String?
    @State private var autosaveTask: Task<Void, Never>?
    @State private var didSave = false
    @State private var tagsText: String
    @State private var choicesText: [UUID: String]

    init(store: HomeRecipeWorkspaceStore, draft: HomeRecipeEditorDraft, onSaved: @escaping (UUID) -> Void) {
        self.store = store
        originalScope = store.scope
        _draft = State(initialValue: draft)
        self.onSaved = onSaved
        let content = draft.content
        _advanced = State(initialValue: content.targets.temperature != nil || !content.targets.grind.isEmpty
            || content.targets.preinfusion != nil || content.targets.pressure != nil)
        _sourceExpanded = State(initialValue: !content.sourceURL.isEmpty || !content.creatorCredit.isEmpty)
        _showIngredients = State(initialValue: content.template == .component || content.template == .drink || !content.ingredients.isEmpty)
        _showSteps = State(initialValue: content.template == .component || content.template == .drink || !content.steps.isEmpty)
        _showOrganization = State(initialValue: !content.yieldDescription.isEmpty || !content.tags.isEmpty || !content.notes.isEmpty)
        _showCustomFields = State(initialValue: !content.fields.isEmpty)
        _showCoffeeLibrary = State(initialValue: content.coffee != nil || !content.equipment.isEmpty)
        _tagsText = State(initialValue: content.tags.joined(separator: ", "))
        _choicesText = State(initialValue: Dictionary(uniqueKeysWithValues: content.fields.map {
            ($0.id, $0.choices.joined(separator: ", "))
        }))
    }

    var body: some View {
        Form {
            Section {
                TextField("Recipe name", text: $draft.content.name)
                    .accessibilityIdentifier("home.recipe.name")
                    .font(.title3.weight(.semibold))
                Picker("Recipe type", selection: Binding(
                    get: { draft.content.template },
                    set: { changeTemplate(to: $0) }
                )) {
                    ForEach(HomeRecipeTemplate.allCases) { Text($0.title).tag($0) }
                }
                DisclosureGroup("Inspiration & credit", isExpanded: $sourceExpanded) {
                    TextField("Instagram, TikTok, or website link", text: $draft.content.sourceURL)
                        .textInputAutocapitalization(.never).keyboardType(.URL)
                    TextField("Creator credit (optional)", text: $draft.content.creatorCredit)
                }
            }
            if draft.content.template == .coffee {
                Section("Coffee preparation") {
                    Picker("Method", selection: Binding(get: { draft.content.method }, set: { method in
                        let previous = draft.content.method
                        draft.content.changeMethod(from: previous, to: method)
                        if method == .pourOver { showSteps = true }
                    })) {
                        ForEach(HomeBrewMethod.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("home.recipe.method")
                    if draft.content.metricConfiguration != nil {
                        HomeConfiguredTargetsEditor(content: $draft.content)
                    } else if draft.content.method != .other {
                        HomeTargetsEditor(targets: $draft.content.targets, method: draft.content.method, advanced: $advanced)
                    }
                    NavigationLink("Customize preparation fields") {
                        HomeRecipeFieldConfigurationScreen(content: $draft.content)
                    }
                }
                if showCoffeeLibrary {
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
            }
            if showIngredients {
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
                Button("Link a saved recipe", systemImage: "link") { linkedPicker = HomeRecipeLinkPickerPresentation() }
                    .accessibilityIdentifier("home.recipe.link")
            }
            }
            if showSteps {
                Section(draft.content.method == .pourOver ? "Pouring steps" : "Instructions") {
                ForEach($draft.content.steps) { $step in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Instruction", text: $step.instruction, axis: .vertical)
                        Toggle("Show when making", isOn: Binding(get: { step.isHidden != true }, set: { step.isHidden = !$0 }))
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
            }
            if showOrganization {
                Section("Yield and organization") {
                TextField("Servings", value: $draft.content.servings, format: .number).keyboardType(.decimalPad)
                TextField("Yield, e.g. one bottle", text: $draft.content.yieldDescription)
                TextField("Tags, separated by commas", text: $tagsText)
                    .onChange(of: tagsText) { _, value in
                        draft.content.tags = value.split(separator: ",", omittingEmptySubsequences: true)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    }
                TextField("Preparation notes", text: $draft.content.notes, axis: .vertical)
            }
            }
            if showCustomFields {
                Section("Custom fields") {
                ForEach($draft.content.fields) { $field in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Field name", text: $field.label)
                        Picker("Type", selection: $field.kind) {
                            ForEach(HomeCustomFieldKind.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        if field.kind == .choice {
                            TextField("Choices, separated by commas", text: Binding(
                                get: { choicesText[field.id] ?? field.choices.joined(separator: ", ") },
                                set: { value in
                                    choicesText[field.id] = value
                                    field.choices = value.split(separator: ",", omittingEmptySubsequences: true)
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                                    if !field.value.isEmpty, !field.choices.contains(field.value) { field.value = "" }
                                }
                            ))
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
            }
            if optionalSectionsRemain {
                Section("Add to this recipe") {
                    if draft.content.template == .coffee, !showCoffeeLibrary {
                        Button("Beans and equipment", systemImage: "shippingbox") { showCoffeeLibrary = true }
                    }
                    if !showIngredients { Button("Ingredients", systemImage: "list.bullet") { showIngredients = true } }
                    if !showSteps { Button("Instructions", systemImage: "list.number") { showSteps = true } }
                    if !showOrganization { Button("Yield, tags, and notes", systemImage: "tag") { showOrganization = true } }
                    if !showCustomFields { Button("Custom field", systemImage: "slider.horizontal.3") { showCustomFields = true } }
                }
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
        }
        .scrollContentBackground(.hidden).background(Color.creamWhite)
        .navigationTitle(draft.recipeID == nil ? "New recipe" : "Edit recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            ToolbarItem(placement: .primaryAction) { EditButton() }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Save recipe") { save() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(draft.content.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("home.recipe.save")
                .padding(.horizontal, DesignSystem.Space.md)
                .padding(.vertical, DesignSystem.Space.sm)
                .background(.ultraThinMaterial)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: draft) { _, value in
            autosaveTask?.cancel()
            autosaveTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, store.scope == originalScope else { return }
                do { try store.saveDraft(value) } catch { self.error = error.localizedDescription }
            }
        }
        .onDisappear {
            autosaveTask?.cancel()
            guard !didSave, store.scope == originalScope else { return }
            do {
                if draft.content.hasMeaningfulDraftContent { try store.saveDraft(draft) }
                else { try store.discardRecipeDraft(id: draft.id) }
            } catch { self.error = error.localizedDescription }
        }
        .sheet(item: $linkedPicker) { _ in
            HomeRecipeLinkPicker(store: store, excluding: draft.recipeID) { record, version in
                draft.content.ingredients.append(HomeRecipeIngredient(name: version.content.name,
                    amount: 1, unit: "serving", recipe: HomeRecipeReference(recipeID: record.id, versionID: version.id)))
            }
        }
    }
    private var optionalSectionsRemain: Bool {
        (draft.content.template == .coffee && !showCoffeeLibrary) || !showIngredients || !showSteps
            || !showOrganization || !showCustomFields
    }
    private func changeTemplate(to template: HomeRecipeTemplate) {
        guard draft.content.template != template else { return }
        draft.content.template = template
        if template == .coffee, draft.content.method == .other, !draft.content.isActionable {
            draft.content.method = .espresso
            draft.content.targets = HomeRecipeContent.defaultTargets(for: .espresso)
        }
        if template == .component || template == .drink {
            showIngredients = true
            showSteps = true
        }
    }
    private func save() {
        guard store.scope == originalScope else {
            error = "Your account changed. This recipe was not moved to another account."
            return
        }
        do { let id = try store.saveRecipe(draft); didSave = true; onSaved(id); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

private struct HomeRecipeLinkPickerPresentation: Identifiable {
    let id = UUID()
}

private struct HomeRecipeLinkPicker: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let excluding: UUID?
    let onSelect: (HomeRecipeRecord, HomeRecipeVersion) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var filter: HomeRecipeTemplate?
    @State private var preview: HomeLinkedRecipeSheet?

    private var recipes: [HomeRecipeRecord] {
        store.workspace.recipes.filter { record in
            guard !record.isArchived, record.id != excluding, let content = record.current?.content else { return false }
            return (filter == nil || content.template == filter)
                && (query.isEmpty || content.searchText.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Recipe kind", selection: $filter) {
                        Text("All").tag(nil as HomeRecipeTemplate?)
                        Text("Coffee").tag(HomeRecipeTemplate.coffee as HomeRecipeTemplate?)
                        Text("Components").tag(HomeRecipeTemplate.component as HomeRecipeTemplate?)
                        Text("Drinks").tag(HomeRecipeTemplate.drink as HomeRecipeTemplate?)
                    }
                    .pickerStyle(.segmented)
                }
                if recipes.isEmpty {
                    ContentUnavailableView("No matching recipes", systemImage: "book.closed",
                        description: Text("Save a recipe first, or add this as a plain ingredient."))
                } else {
                    Section("Choose an exact saved version") {
                        ForEach(recipes) { record in
                            if let version = record.current {
                                VStack(alignment: .leading, spacing: 8) {
                                    HomeRecipeRow(content: version.content)
                                    HStack {
                                        Button("Preview") {
                                            preview = HomeLinkedRecipeSheet(reference: HomeRecipeReference(recipeID: record.id, versionID: version.id))
                                        }
                                        .buttonStyle(.borderless)
                                        Spacer()
                                        Button("Link version \(version.number)") {
                                            onSelect(record, version)
                                            dismiss()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.mugshotSage)
                                        .accessibilityIdentifier("home.recipe.link.\(version.id.uuidString)")
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search recipes, tags, beans, or gear")
            .navigationTitle("Link a recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .sheet(item: $preview) { item in HomeLinkedRecipeDetail(store: store, reference: item.reference) }
        }
    }
}

struct HomeRecipeTemplateChooser: View {
    let onSelect: (HomeRecipeTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Space.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Space.xs) {
                    Text("What are you saving?")
                        .mugshotDisplay(size: 32)
                        .foregroundStyle(Color.espressoBrown)
                    Text("Choose a useful starting point. You can add or remove any field later.")
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(.bottom, DesignSystem.Space.xs)

                ForEach(HomeRecipeTemplate.allCases) { template in
                    Button { onSelect(template) } label: {
                        HStack(alignment: .top, spacing: DesignSystem.Space.md) {
                            Image(systemName: template.symbol)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Color.mugshotSageText)
                                .frame(width: 42, height: 42)
                                .background(Color.mugshotMint.opacity(0.3), in: Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                Text(template.title).font(.headline).foregroundStyle(Color.espressoBrown)
                                Text(description(for: template)).font(.subheadline).foregroundStyle(Color.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.mugshotSageText)
                        }
                        .padding(DesignSystem.Space.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle(shadow: DesignSystem.subtleShadow)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.recipe.template.\(template.rawValue)")
                }
            }
            .padding(DesignSystem.Space.md)
        }
        .background(Color.creamWhite)
        .navigationTitle("New recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
    }

    private func description(for template: HomeRecipeTemplate) -> String {
        switch template {
        case .coffee: "Espresso, pour-over, cold brew, French press, AeroPress, pods, and more."
        case .component: "Syrups, foams, sauces, concentrates, flavored milks, and toppings."
        case .drink: "Lattes, mochas, iced drinks, and complete creations with linked recipes."
        case .custom: "Start with only a name, then add exactly the fields you need."
        }
    }
}

struct HomeRecipeCreationFlow: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let onSaved: (UUID) -> Void
    @State private var selectedTemplate: HomeRecipeTemplate?

    var body: some View {
        NavigationStack {
            if let selectedTemplate {
                HomeRecipeEditorView(
                    store: store,
                    draft: HomeRecipeEditorDraft(content: .starting(selectedTemplate)),
                    onSaved: onSaved
                )
            } else {
                HomeRecipeTemplateChooser { template in
                    withAnimation(DesignSystem.Motion.base) { selectedTemplate = template }
                }
            }
        }
    }
}

private struct HomeRecipeFieldConfigurationScreen: View {
    @Binding var content: HomeRecipeContent
    private var fields: Binding<[HomeRecipeMetricConfiguration]> {
        Binding(get: {
            let configured = content.configuredMetrics
            let known = Set(configured.map(\.metric))
            return configured + HomeRecipeMetric.allCases.filter { !known.contains($0) }.map {
                HomeRecipeMetricConfiguration(metric: $0, label: $0.label, isVisible: false)
            }
        }, set: { content.metricConfiguration = $0 })
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
        Picker("Calculate", selection: Binding(
            get: { content.targets.calculation },
            set: { content.targets.setCalculation($0) }
        )) {
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
        Picker("Calculate", selection: Binding(
            get: { targets.calculation },
            set: { targets.setCalculation($0) }
        )) {
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
        } else if method == .frenchPress || method == .immersion {
            HomeNumberField(title: "Steep time (minutes)", value: Binding(
                get: { targets.steepSeconds.map { $0 / 60 } },
                set: { targets.steepSeconds = $0.map { $0 * 60 } }
            ))
        } else {
            HomeNumberField(title: "Target time (seconds)", value: $targets.seconds)
        }
        }
        DisclosureGroup("More details", isExpanded: $advanced) {
            if method == .pod { HomeNumberField(title: "Coffee dose (g)", value: $targets.dose) }
            TextField("Grinder setting", text: $targets.grind)
            HomeNumberField(title: "Temperature (°C)", value: $targets.temperature)
            if method == .espresso {
                HomeNumberField(title: "Preinfusion (seconds)", value: $targets.preinfusion)
                HomeNumberField(title: "Pressure (bar)", value: $targets.pressure)
            } else if method != .coldBrew && method != .frenchPress && method != .immersion {
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
