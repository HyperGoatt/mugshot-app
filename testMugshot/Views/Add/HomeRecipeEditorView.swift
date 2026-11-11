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
    @State private var library = HomeLibrarySnapshot.empty

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
        HomeEditorCanvas(title: "Make it yours.",
            detail: "Keep the ingredients, steps and little details that make this recipe worth making again.",
            symbol: draft.content.template.symbol) {
            identityCard
            if originalScope.userID != nil, draft.content.sourceReuseAllowed != false { importCard }
            if draft.content.template == .coffee || draft.content.template == .preparation {
                preparationCard
                if showCoffeeLibrary { coffeeLibraryCard }
            }
            if showIngredients { ingredientsCard }
            if showSteps { instructionsCard }
            if showOrganization { organizationCard }
            if showCustomFields { customFieldsCard }
            if optionalSectionsRemain { optionalSectionsCard }
        }
        .disabled(store.scope != originalScope)
        .navigationTitle(draft.recipeID == nil ? "New recipe" : "Edit recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        .safeAreaInset(edge: .bottom) { saveBar }
        .task {
            guard store.scope == originalScope else { return }
            library = HomeLibraryStore.shared.load(in: originalScope)
        }
        .onChange(of: store.scope) { _, scope in if scope != originalScope { dismiss() } }
        .onChange(of: draft) { _, value in
            autosaveTask?.cancel()
            autosaveTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, !didSave, store.scope == originalScope else { return }
                do { try store.saveDraft(value) } catch { self.error = error.localizedDescription }
            }
        }
        .onDisappear {
            autosaveTask?.cancel()
            guard !didSave, store.scope == originalScope else { return }
            do {
                if draft.content.hasMeaningfulDraftContent { try store.saveDraft(draft) }
                else { try store.discardRecipeDraft(id: draft.id, expectedScope: originalScope) }
            } catch { self.error = error.localizedDescription }
        }
        .sheet(item: $linkedPicker) { _ in
            HomeRecipeLinkPicker(store: store, excluding: draft.recipeID) { record, version in
                guard store.scope == originalScope else { return }
                draft.content.ingredients.append(HomeRecipeIngredient(name: version.content.name,
                    amount: 1, unit: "serving", recipe: HomeRecipeReference(recipeID: record.id, versionID: version.id)))
            }
        }
    }

    private var identityCard: some View {
        HomeEditorSection("The recipe", symbol: draft.content.template.symbol) {
            HomeEditorField("Recipe name", text: $draft.content.name, placeholder: "Give it a name", identifier: "home.recipe.name")
                .font(.title3.weight(.semibold))
            Picker("Recipe type", selection: Binding(get: { draft.content.template }, set: changeTemplate)) {
                ForEach(HomeRecipeTemplate.allCases.filter { $0 != .coffee }) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu).frame(minHeight: 44)
            DisclosureGroup("Inspiration & credit", isExpanded: $sourceExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    HomeEditorField("Source link", text: $draft.content.sourceURL, placeholder: "Instagram, TikTok or a website")
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    HomeEditorField("Creator credit", text: $draft.content.creatorCredit, placeholder: "Optional")
                    HomeEditorField("Source text", text: $draft.content.sourceText,
                        placeholder: "Paste a caption or instructions", axis: .vertical)
                }.padding(.top, 12)
            }
        }
    }

    private var importCard: some View {
        HomeEditorSection("Read from your source", symbol: "text.viewfinder",
                          detail: "Keep the creator’s source with the recipe. Your edits stay in this draft.") {
            CoffeeAssistanceButton(ownerID: originalScope.userID, task: .recipeImport,
                evidence: CoffeeAssistanceRecipeImport.source(draft.content), allowsPhoto: true,
                onAccepted: { result in
                    guard store.scope == originalScope else { return }
                    CoffeeAssistanceRecipeImport.apply(result.fields, to: &draft.content)
                    showIngredients = !draft.content.ingredients.isEmpty
                    showSteps = !draft.content.steps.isEmpty
                    sourceExpanded = true
                })
        }
    }

    private var preparationCard: some View {
        HomeEditorSection("How you make it", symbol: draft.content.method.systemImage) {
            Picker("Method", selection: Binding(get: { draft.content.method }, set: { method in
                let previous = draft.content.method
                draft.content.changeMethod(from: previous, to: method)
                if method == .pourOver { showSteps = true }
            })) {
                ForEach(HomeBrewMethod.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu).frame(minHeight: 44)
            .accessibilityIdentifier("home.recipe.method")
            if draft.content.method == .other {
                HomeEditorField("Custom method name", text: $draft.content.customMethodName,
                    placeholder: "Your way of making it", identifier: "home.recipe.customMethodName")
                Text("Add any useful text, number, duration or choice fields below.")
                    .font(.caption).foregroundStyle(Color.secondaryText)
            }
            if draft.content.metricConfiguration != nil {
                HomeConfiguredTargetsEditor(content: $draft.content)
            } else if draft.content.method != .other {
                HomeTargetsEditor(targets: $draft.content.targets, method: draft.content.method, advanced: $advanced)
            }
            NavigationLink {
                HomeRecipeFieldConfigurationScreen(content: $draft.content)
            } label: {
                Label("Customize preparation fields", systemImage: "slider.horizontal.3").frame(minHeight: 44)
            }
        }
    }

    private var coffeeLibraryCard: some View {
        HomeEditorSection("Beans & gear", symbol: "kettle", detail: "Optional details for this recipe.") {
            Menu(draft.content.coffee?.displayName ?? "Choose coffee") {
                Button("None") { draft.content.coffee = nil }
                ForEach(library.bags.filter { $0.status.isCurrent }) { bag in
                    Button(bag.displayName) { draft.content.coffee = bag.safeSnapshot }
                }
            }.frame(minHeight: 44)
            ForEach(library.equipment.filter { $0.archivedAt == nil }) { gear in
                Toggle(gear.displayName, isOn: Binding(get: { draft.content.equipment.contains(gear.snapshot) }, set: { selected in
                    draft.content.equipment.removeAll { $0 == gear.snapshot }
                    if selected { draft.content.equipment.append(gear.snapshot) }
                })).frame(minHeight: 44)
            }
            if library.bags.isEmpty && library.equipment.isEmpty {
                Text("Your Home library is ready whenever you want to add beans or gear.")
                    .font(.caption).foregroundStyle(Color.secondaryText)
            }
        }
    }

    private var ingredientsCard: some View {
        HomeEditorSection("Ingredients", symbol: "list.bullet",
                          detail: "Use the row menu to reorder or remove an ingredient.") {
            ForEach(draft.content.ingredients) { item in
                ingredientRow(item, index: draft.content.ingredients.firstIndex { $0.id == item.id } ?? 0)
            }
            Button("Add ingredient", systemImage: "plus") { draft.content.ingredients.append(HomeRecipeIngredient()) }
                .frame(minHeight: 44).accessibilityIdentifier("home.recipe.addIngredient")
            Button("Link a saved recipe", systemImage: "link") { linkedPicker = HomeRecipeLinkPickerPresentation() }
                .frame(minHeight: 44).accessibilityIdentifier("home.recipe.link")
        }
    }

    private func ingredientRow(_ item: HomeRecipeIngredient, index: Int) -> some View {
        let ingredient = HomeEditorBindings.item(item, in: $draft.content.ingredients)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INGREDIENT \(index + 1)").font(.caption.weight(.bold)).foregroundStyle(Color.mugshotSageText)
                Spacer()
                rowActions(label: "Ingredient \(index + 1) actions", removeTitle: "Remove ingredient",
                    index: index, count: draft.content.ingredients.count, identifier: "home.recipe.ingredient.\(index).actions",
                    earlier: { moveIngredient(item.id, by: -1) }, later: { moveIngredient(item.id, by: 1) },
                    remove: { endEditing(); draft.content.ingredients.removeAll { $0.id == item.id } })
            }
            HomeEditorField("Ingredient", text: ingredient.name, placeholder: "What goes in?",
                identifier: "home.recipe.ingredient.\(index).name")
            HomeNumberField(title: "Amount", value: ingredient.amount)
            HomeEditorField("Unit", text: ingredient.unit, placeholder: "g, ml, tsp…")
            if item.recipe != nil {
                Label("Linked recipe", systemImage: "link").font(.caption).foregroundStyle(Color.secondaryText)
                Button("Use as plain ingredient") { ingredient.wrappedValue.recipe = nil }.frame(minHeight: 44)
            }
        }
        .padding(14).background(Color.creamWhite.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
    }

    private var instructionsCard: some View {
        HomeEditorSection(draft.content.method == .pourOver ? "Pouring steps" : "Instructions", symbol: "list.number") {
            ForEach(draft.content.steps) { item in
                instructionRow(item, index: draft.content.steps.firstIndex { $0.id == item.id } ?? 0)
            }
            Button("Add step", systemImage: "plus") { draft.content.steps.append(HomePreparationStep()) }
                .frame(minHeight: 44).accessibilityIdentifier("home.recipe.addStep")
        }
    }

    private func instructionRow(_ item: HomePreparationStep, index: Int) -> some View {
        let step = HomeEditorBindings.item(item, in: $draft.content.steps)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Step \(index + 1)", systemImage: "circle.fill").font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mugshotSageText)
                Spacer()
                rowActions(label: "Step \(index + 1) actions", removeTitle: "Remove step",
                    index: index, count: draft.content.steps.count, identifier: "home.recipe.step.\(index).actions",
                    earlier: { moveStep(item.id, by: -1) }, later: { moveStep(item.id, by: 1) },
                    remove: { endEditing(); draft.content.steps.removeAll { $0.id == item.id } })
            }
            HomeEditorField("Instruction", text: step.instruction, placeholder: "One clear action", axis: .vertical,
                identifier: "home.recipe.step.\(index).instruction")
            Toggle("Show when making", isOn: Binding(get: { step.wrappedValue.isHidden != true }, set: { step.wrappedValue.isHidden = !$0 }))
                .frame(minHeight: 44)
            HomeNumberField(title: "Start at (seconds)", value: step.startSeconds)
            HomeNumberField(title: "Wait (seconds)", value: step.waitSeconds)
            if draft.content.method == .pourOver {
                Picker("Water", selection: step.waterMode) {
                    ForEach(HomeWaterTargetMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }.frame(minHeight: 44)
                HomeNumberField(title: "Water (g)", value: step.waterGrams)
            }
        }
        .padding(14).background(Color.creamWhite.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
    }

    private var organizationCard: some View {
        HomeEditorSection("Yield & notes", symbol: "tag") {
            HStack {
                Text("Servings").font(.subheadline)
                Spacer()
                TextField("Optional", value: $draft.content.servings, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(minHeight: 44)
                    .accessibilityLabel("Servings")
            }
            HomeEditorField("Yield", text: $draft.content.yieldDescription, placeholder: "One bottle, two cups…")
            HomeEditorField("Tags", text: $tagsText, placeholder: "Separate with commas")
                .onChange(of: tagsText) { _, value in
                    draft.content.tags = value.split(separator: ",", omittingEmptySubsequences: true)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                }
            HomeEditorField("Preparation notes", text: $draft.content.notes, placeholder: "Useful for next time", axis: .vertical)
        }
    }

    private var customFieldsCard: some View {
        HomeEditorSection("Your own details", symbol: "slider.horizontal.3") {
            ForEach(draft.content.fields) { item in
                customFieldRow(item, index: draft.content.fields.firstIndex { $0.id == item.id } ?? 0)
            }
            Button("Add custom field", systemImage: "plus") { draft.content.fields.append(HomeCustomField()) }
                .frame(minHeight: 44).accessibilityIdentifier("home.recipe.addField")
        }
    }

    private func customFieldRow(_ item: HomeCustomField, index: Int) -> some View {
        let field = HomeEditorBindings.item(item, in: $draft.content.fields)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DETAIL \(index + 1)").font(.caption.weight(.bold)).foregroundStyle(Color.mugshotSageText)
                Spacer()
                rowActions(label: "Detail \(index + 1) actions", removeTitle: "Remove field",
                    index: index, count: draft.content.fields.count, identifier: "home.recipe.field.\(index).actions",
                    earlier: { moveField(item.id, by: -1) }, later: { moveField(item.id, by: 1) },
                    remove: { endEditing(); draft.content.fields.removeAll { $0.id == item.id } })
            }
            HomeEditorField("Field name", text: field.label, placeholder: "A useful detail")
            Picker("Type", selection: field.kind) {
                ForEach(HomeCustomFieldKind.allCases, id: \.self) { Text($0.title).tag($0) }
            }.frame(minHeight: 44)
            if item.kind == .choice {
                HomeEditorField("Choices", text: Binding(get: { choicesText[item.id] ?? field.wrappedValue.choices.joined(separator: ", ") }, set: { value in
                    choicesText[item.id] = value
                    field.wrappedValue.choices = value.split(separator: ",", omittingEmptySubsequences: true)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    if !field.wrappedValue.value.isEmpty, !field.wrappedValue.choices.contains(field.wrappedValue.value) { field.wrappedValue.value = "" }
                }), placeholder: "Separate with commas")
                Picker("Value", selection: field.value) {
                    Text("Not set").tag("")
                    ForEach(item.choices, id: \.self) { Text($0).tag($0) }
                }.frame(minHeight: 44)
            } else {
                HomeEditorField("Value", text: field.value, placeholder: "Optional")
                    .keyboardType(item.kind == .number || item.kind == .duration ? .decimalPad : .default)
                if item.kind == .number { HomeEditorField("Unit", text: field.unit, placeholder: "Optional") }
                if item.kind == .duration { Text("Duration in seconds").font(.caption).foregroundStyle(Color.secondaryText) }
            }
            Toggle("Show when making", isOn: field.isVisible).frame(minHeight: 44)
        }
        .padding(14).background(Color.creamWhite.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
    }

    private var optionalSectionsCard: some View {
        HomeEditorSection("Make room for more", symbol: "plus.circle", detail: "Only add the details you need.") {
            if (draft.content.template == .coffee || draft.content.template == .preparation), draft.content.method.family == .coffee, !showCoffeeLibrary {
                Button("Beans and equipment", systemImage: "shippingbox") { showCoffeeLibrary = true }.frame(minHeight: 44)
            }
            if !showIngredients { Button("Ingredients", systemImage: "list.bullet") { showIngredients = true }.frame(minHeight: 44) }
            if !showSteps { Button("Instructions", systemImage: "list.number") { showSteps = true }.frame(minHeight: 44) }
            if !showOrganization { Button("Yield, tags, and notes", systemImage: "tag") { showOrganization = true }.frame(minHeight: 44) }
            if !showCustomFields { Button("Custom field", systemImage: "slider.horizontal.3") { showCustomFields = true }.frame(minHeight: 44) }
        }
    }

    private var saveBar: some View {
        VStack(spacing: 6) {
            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.footnote).foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(draft.recipeID == nil ? "Save recipe" : "Save changes to recipe") { save() }
                .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: .infinity)
                .disabled(draft.content.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.scope != originalScope)
                .accessibilityIdentifier("home.recipe.save")
            if draft.recipeID != nil {
                Button("Save as new recipe") { save(asCopy: true) }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(draft.content.name.remoteTrimmedNonEmpty == nil || store.scope != originalScope)
                    .accessibilityIdentifier("home.recipe.saveCopy")
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10).background(Color.creamWhite)
    }

    private func rowActions(label: String, removeTitle: String, index: Int, count: Int, identifier: String,
                            earlier: @escaping () -> Void, later: @escaping () -> Void, remove: @escaping () -> Void) -> some View {
        HomeEditorRowActions(label: label, removeTitle: removeTitle, canMoveEarlier: index > 0,
            canMoveLater: index + 1 < count, identifier: identifier,
            onMoveEarlier: earlier, onMoveLater: later, onRemove: remove)
    }
    private func moveIngredient(_ id: UUID, by amount: Int) {
        endEditing()
        guard let index = draft.content.ingredients.firstIndex(where: { $0.id == id }), draft.content.ingredients.indices.contains(index + amount) else { return }
        draft.content.ingredients.swapAt(index, index + amount)
    }
    private func moveStep(_ id: UUID, by amount: Int) {
        endEditing()
        guard let index = draft.content.steps.firstIndex(where: { $0.id == id }), draft.content.steps.indices.contains(index + amount) else { return }
        draft.content.steps.swapAt(index, index + amount)
    }
    private func moveField(_ id: UUID, by amount: Int) {
        endEditing()
        guard let index = draft.content.fields.firstIndex(where: { $0.id == id }), draft.content.fields.indices.contains(index + amount) else { return }
        draft.content.fields.swapAt(index, index + amount)
    }
    private func endEditing() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    private var optionalSectionsRemain: Bool {
        ((draft.content.template == .coffee || draft.content.template == .preparation)
            && draft.content.method.family == .coffee && !showCoffeeLibrary)
            || !showIngredients || !showSteps || !showOrganization || !showCustomFields
    }
    private func changeTemplate(to template: HomeRecipeTemplate) {
        guard draft.content.template != template else { return }
        draft.content.template = template
        if (template == .coffee || template == .preparation), draft.content.method == .other, !draft.content.isActionable {
            draft.content.method = .espresso
            draft.content.targets = HomeRecipeContent.defaultTargets(for: .espresso)
        }
        if template == .component || template == .drink { showIngredients = true; showSteps = true }
    }
    private func save(asCopy: Bool = false) {
        guard !didSave, store.scope == originalScope else {
            error = "Your account changed. This recipe was not moved to another account."
            return
        }
        endEditing()
        autosaveTask?.cancel()
        do { let id = try store.saveRecipe(draft, asCopy: asCopy); didSave = true; onSaved(id); dismiss() }
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
            return (filter == nil || matches(content, filter: filter))
                && (query.isEmpty || content.searchText.localizedCaseInsensitiveContains(query))
        }
    }

    private func matches(_ content: HomeRecipeContent, filter: HomeRecipeTemplate?) -> Bool {
        guard let filter else { return true }
        switch filter {
        case .coffee:
            return content.template == .coffee
                || (content.template == .preparation && content.method.family == .coffee)
        case .component:
            return content.template == .component
                || (content.template == .preparation && content.method.family == .component)
        case .drink:
            return content.template == .drink || content.method == .completeDrink
        case .preparation: return content.template == .preparation
        case .custom: return content.template == .custom
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

                ForEach(HomeRecipeTemplate.allCases.filter { $0 != .coffee }) { template in
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
        case .preparation: "Coffee, matcha, hojicha, tea, components, and any other method."
        case .coffee: "Legacy coffee preparation. Existing recipes remain unchanged."
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
        HomeEditorCanvas(title: "A setup that fits.",
            detail: "Rename, hide or reorder details. Hidden fields keep their saved values and calculations.",
            symbol: "slider.horizontal.3") {
            HomeEditorSection("Your preparation fields", symbol: "list.bullet") {
                ForEach(fields.wrappedValue) { item in
                    metricRow(item)
                }
            }
            Button("Use method defaults", systemImage: "arrow.counterclockwise") { content.metricConfiguration = nil }
                .frame(minHeight: 44)
        }
        .navigationTitle("Preparation fields").navigationBarTitleDisplayMode(.inline)
    }
    private func metricRow(_ item: HomeRecipeMetricConfiguration) -> some View {
        let field = HomeEditorBindings.item(item, in: fields)
        let index = fields.wrappedValue.firstIndex { $0.id == item.id } ?? 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.metric.label).font(.subheadline.weight(.semibold)).foregroundStyle(Color.mugshotSageText)
                Spacer()
                Menu {
                    Button("Move earlier", systemImage: "arrow.up") { move(item.id, by: -1) }.disabled(index == 0)
                    Button("Move later", systemImage: "arrow.down") { move(item.id, by: 1) }.disabled(index + 1 >= fields.wrappedValue.count)
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                        .background(Color.mugshotMint.opacity(0.28), in: Circle())
                }
                .accessibilityLabel("\(item.metric.label) field actions")
            }
            HomeEditorField("Field label", text: field.label, placeholder: item.metric.label)
            Toggle("Show field", isOn: field.isVisible).frame(minHeight: 44)
        }
        .padding(14).background(Color.creamWhite.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
    }
    private func move(_ id: HomeRecipeMetricConfiguration.ID, by amount: Int) {
        var values = fields.wrappedValue
        guard let index = values.firstIndex(where: { $0.id == id }), values.indices.contains(index + amount) else { return }
        values.swapAt(index, index + amount)
        fields.wrappedValue = values
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
                HomeEditorField(label, text: $content.targets.grind, placeholder: "Optional")
            } else if field.metric == .dilution {
                HomeEditorField(label, text: $content.targets.dilution, placeholder: "Optional")
            }
        }
    }
}

struct HomeNumberField: View {
    let title: String
    @Binding var value: Double?
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
                input.multilineTextAlignment(.leading)
            }
        } else {
            HStack {
                Text(title)
                Spacer(minLength: 12)
                input.multilineTextAlignment(.trailing)
            }
        }
    }
    private var input: some View {
        TextField("Optional", value: $value, format: .number)
            .keyboardType(.decimalPad).frame(minHeight: 44)
            .accessibilityLabel(title)
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
            HomeNumberField(
                title: method == .espresso
                    ? "Target yield (\(method.outputUnit))"
                    : "\(method.outputLabel) (\(method.outputUnit))",
                value: $targets.output
            )
            LabeledContent("Ratio", value: targets.resolvedRatio.map { "1:\(HomeRecipeContent.number($0))" } ?? "Not set")
        }
        if method == .coldBrew {
            HomeNumberField(title: "Steep duration (hours)", value: Binding(get: { targets.steepSeconds.map { $0 / 3600 } }, set: { targets.steepSeconds = $0.map { $0 * 3600 } }))
            HomeEditorField("Serving dilution", text: $targets.dilution, placeholder: "Optional")
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
            HomeEditorField("Grinder setting", text: $targets.grind, placeholder: "Optional")
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
            if content.template == .coffee || content.template == .preparation {
                HomeMethodIconView(method: content.method, size: 24)
                    .frame(width: 32)
                    .accessibilityLabel(content.methodDisplayName)
            } else {
                Image(systemName: content.template.symbol)
                    .font(.title3).foregroundStyle(Color.mugshotSage).frame(width: 32)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(content.name).font(.headline).foregroundStyle(Color.espressoBrown)
                Text(HomeRecipeUse.suggested(for: content).title + " · " + content.recipeContentsSummary)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 5)
    }
}
