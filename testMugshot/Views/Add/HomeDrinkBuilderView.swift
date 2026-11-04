import SwiftUI

struct HomeDrinkBuilderSheet: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    @State private var draft: HomeRecipeEditorDraft
    let onSaved: (UUID) -> Void
    private let originalScope: LocalAccountScope
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @State private var destination: Destination?
    @State private var shelf = HomeLibrarySnapshot.empty
    @State private var advanced = false
    @State private var didEdit = false
    @State private var didSave = false
    @State private var draftSaved = false
    @State private var choseBeans = false
    @State private var customIngredient = ""
    @State private var addsCustomIngredient = false
    @State private var error: String?
    @FocusState private var focusedField: String?

    private enum Destination: Identifiable {
        case base, parts, gear, preview(HomeRecipeReference)
        var id: String {
            switch self { case .base: "base"; case .parts: "parts"; case .gear: "gear"; case .preview(let ref): ref.versionID.uuidString }
        }
    }

    init(store: HomeRecipeWorkspaceStore, draft: HomeRecipeEditorDraft? = nil,
         component: HomeRecipeRecord? = nil, onSaved: @escaping (UUID) -> Void) {
        self.store = store; self.onSaved = onSaved; originalScope = store.scope
        _draft = State(initialValue: draft ?? HomeRecipeEditorDraft(content: HomeDrinkComposition.starting(with: component)))
    }

    private var isCurrentOwner: Bool { store.scope == originalScope && authModel.authenticatedUser?.id == originalScope.userID }
    private var baseID: UUID? { HomeDrinkComposition.baseID(in: draft.content) { store.workspace.version($0)?.content } }
    private var defaults: HomeLibraryDefaults { shelf.defaults(for: originalScope.userID, method: draft.content.method) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .center, spacing: 18) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("YOUR NEXT FAVORITE").recipeEyebrow()
                            Text("Make it yours.").mugshotDisplay(size: 36)
                            Text("A base. A little something. All you.")
                                .font(.subheadline).foregroundStyle(Color.secondaryText)
                        }
                        Spacer(minLength: 0)
                        HomeDrinkIllustration().frame(width: 82, height: 110).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Text("NAME YOUR DRINK").recipeEyebrow()
                        TextField("Your new favorite", text: $draft.content.name)
                            .font(.system(size: 27, weight: .medium, design: .serif))
                            .autocorrectionDisabled().focused($focusedField, equals: "name")
                            .accessibilityLabel("Drink recipe name").accessibilityIdentifier("home.drink.name")
                        Rectangle().fill(Color.mugshotLine).frame(height: 1)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("The mix").font(.title3.weight(.semibold))
                            Spacer()
                            Text("Amounts are optional").font(.caption).foregroundStyle(Color.secondaryText)
                        }
                        mix
                        HStack(spacing: 10) {
                            Button { focusedField = nil; destination = .parts } label: { Label("Saved recipe", systemImage: "book.pages") }
                                .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("home.drink.addRecipe")
                            Menu {
                                ForEach(["Milk", "Oat milk", "Water", "Ice", "Honey"], id: \.self) { name in
                                    Button(name) { addIngredient(name) }
                                }
                                Button("Something else…") { customIngredient = ""; addsCustomIngredient = true }
                            } label: { Label("Ingredient", systemImage: "plus") }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    if draft.content.method != .other {
                        DisclosureGroup("Brew settings") {
                            VStack(spacing: 12) {
                                HomeTargetsEditor(targets: $draft.content.targets, method: draft.content.method, advanced: $advanced)
                            }.padding(.top, 12).pickerStyle(.menu)
                        }.font(.subheadline.weight(.semibold))
                    }
                    DisclosureGroup("Assembly steps") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach($draft.content.steps) { $step in
                                TextField("How does it come together?", text: $step.instruction, axis: .vertical)
                                    .lineLimit(2...5).focused($focusedField, equals: step.id.uuidString)
                            }
                            Button("Add a step", systemImage: "plus") { draft.content.steps.append(HomePreparationStep()) }
                        }.font(.body).padding(.top, 14)
                    }.font(.subheadline.weight(.semibold))
                    if !draft.content.sourceURL.isEmpty || !draft.content.creatorCredit.isEmpty {
                        Label([draft.content.creatorCredit, "Source kept with this recipe"].filter { !$0.isEmpty }.joined(separator: " · "), systemImage: "link")
                            .font(.caption).foregroundStyle(Color.secondaryText)
                    }
                    if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                    if draftSaved { Label("Draft saved on this phone", systemImage: "checkmark").font(.caption).foregroundStyle(Color.secondaryText) }
                }.padding(22)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.creamWhite).foregroundStyle(Color.espressoBrown)
            .navigationTitle(draft.recipeID == nil ? "Build a drink" : "Your drink recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }.accessibilityIdentifier("home.drink.keyboardDone")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: save) { Text("Save drink recipe").frame(maxWidth: .infinity) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isCurrentOwner || draft.content.name.remoteTrimmedNonEmpty == nil)
                    .accessibilityIdentifier("home.drink.save")
                    .padding(.horizontal, 22).padding(.vertical, 12).background(Color.creamWhite)
            }
            .onChange(of: draft.content) { _, _ in didEdit = true; draftSaved = false }
            .task(id: draft.content) {
                guard didEdit else { return }
                do {
                    try await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled, isCurrentOwner, !didSave else { return }
                    try store.saveDraft(draft); draftSaved = true
                } catch is CancellationError { }
                catch { self.error = "Your draft couldn’t be saved yet. Keep this screen open and try Save again." }
            }
            .task { reloadShelf() }
            .onChange(of: authModel.authenticatedUser?.id) { _, _ in if !isCurrentOwner { dismiss() } }
            .onChange(of: store.scope) { _, _ in if !isCurrentOwner { dismiss() } }
            .onDisappear {
                guard didEdit, !didSave, isCurrentOwner else { return }
                do { try store.saveDraft(draft) } catch { store.errorMessage = error.localizedDescription }
            }
            .sheet(item: $destination, onDismiss: reloadShelf) { item in
                switch item {
                case .base, .parts:
                    HomeDrinkPartPicker(store: store, selectingBase: item.id == "base", excluding: draft.recipeID) { recipe, version in
                        guard isCurrentOwner else { return }
                        if item.id == "base" || HomeRecipeUse.suggested(for: version.content) == .base {
                            HomeDrinkComposition.useBase(recipe, version: version, in: &draft.content, replacing: baseID)
                        } else { HomeDrinkComposition.add(recipe, version: version, to: &draft.content) }
                        destination = nil
                    } onPreset: { method in
                        guard isCurrentOwner else { return }
                        HomeDrinkComposition.usePreset(method, in: &draft.content, replacing: baseID)
                        destination = nil
                    }
                case .preview(let reference): HomeLinkedRecipeDetail(store: store, reference: reference)
                case .gear: HomeLibraryView(ownerID: originalScope.userID, initialSection: .gear)
                }
            }
            .alert("Add an ingredient", isPresented: $addsCustomIngredient) {
                TextField("Ingredient name", text: $customIngredient)
                Button("Add") { if let name = customIngredient.remoteTrimmedNonEmpty { addIngredient(name) } }
                Button("Cancel", role: .cancel) { }
            }
        }.tint(Color.mugshotSageText)
    }

    private var mix: some View {
        VStack(spacing: 0) {
            baseRow
            ForEach($draft.content.ingredients) { $ingredient in
                if ingredient.id != baseID {
                    Divider().overlay(Color.mugshotLine).padding(.horizontal, 18)
                    HomeDrinkPartRow(ingredient: $ingredient, focusedField: $focusedField,
                        onPreview: { if let reference = ingredient.recipe { focusedField = nil; destination = .preview(reference) } },
                        onRemove: { draft.content.ingredients.removeAll { $0.id == ingredient.id } })
                }
            }
        }
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.mugshotLine, lineWidth: 1))
    }

    private var baseRow: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                HomeMethodIconView(method: draft.content.method, size: 30)
                    .frame(width: 44, height: 44).background(Color.sandBeige.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("THE BASE").recipeEyebrow()
                    Text(draft.content.ingredients.first(where: { $0.id == baseID })?.name ?? "Choose your base")
                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button("Change") { focusedField = nil; destination = .base }
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    .accessibilityIdentifier("home.drink.chooseBase")
            }
            if let base = draft.content.ingredients.first(where: { $0.id == baseID }), let reference = base.recipe {
                Button("View base recipe", systemImage: "arrow.up.right") { focusedField = nil; destination = .preview(reference) }
                    .font(.caption.weight(.semibold)).frame(minHeight: 36)
            } else if let dose = draft.content.targets.dose, let output = draft.content.targets.resolvedOutput {
                Text("Starting point · \(HomeRecipeContent.number(dose)) g in → \(HomeRecipeContent.number(output)) g out")
                    .font(.caption).foregroundStyle(Color.secondaryText)
            }
            HStack(spacing: 12) {
                if draft.content.method.family == .coffee {
                    Menu {
                        Button("No saved bag") { draft.content.coffee = nil; choseBeans = true }
                        ForEach(shelf.bags.filter { $0.status.isCurrent && $0.ownerUserID == originalScope.userID }) { bag in
                            Button(bag.displayName) { draft.content.coffee = bag.safeSnapshot; choseBeans = true }
                        }
                    } label: {
                        Label(draft.content.coffee?.displayName ?? (choseBeans ? "No saved bag" : defaults.bag?.displayName ?? "Choose beans"), systemImage: "leaf")
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Button("Gear", systemImage: "kettle") { focusedField = nil; destination = .gear }
            }.font(.caption.weight(.semibold)).frame(minHeight: 36)
        }.padding(18)
    }

    private func addIngredient(_ name: String) {
        guard isCurrentOwner else { return }
        draft.content.ingredients.append(HomeRecipeIngredient(name: name, unit: ["Ice", "Honey"].contains(name) ? "g" : "ml"))
    }
    private func reloadShelf() {
        guard isCurrentOwner else { return }
        shelf = HomeLibraryStore.shared.load(in: originalScope)
    }
    private func save() {
        guard isCurrentOwner, !didSave else { return }
        focusedField = nil
        var saved = draft
        saved.content.template = .drink
        if saved.content.coffee == nil, !choseBeans { saved.content.coffee = defaults.bag?.safeSnapshot }
        if saved.content.equipment.isEmpty { saved.content.equipment = defaults.equipment.map(\.snapshot) }
        do {
            let id = try store.saveRecipe(saved)
            didSave = true; onSaved(id); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

private struct HomeDrinkPartRow: View {
    @Binding var ingredient: HomeRecipeIngredient
    @State private var amountText = ""
    @FocusState.Binding var focusedField: String?
    let onPreview: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: ingredient.recipe == nil ? "drop" : "book.pages")
                    .font(.title3).foregroundStyle(Color.mugshotSageText)
                    .frame(width: 44, height: 44).background(Color.mugshotMint.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                if ingredient.recipe != nil {
                    Button(action: onPreview) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ingredient.name).font(.headline).multilineTextAlignment(.leading)
                            Text("Your saved recipe ↗").font(.caption).foregroundStyle(Color.mugshotSageText)
                        }
                    }.buttonStyle(.plain).accessibilityLabel("Open \(ingredient.name) recipe")
                } else {
                    TextField("Ingredient", text: $ingredient.name, axis: .vertical)
                        .font(.headline).focused($focusedField, equals: "name-" + ingredient.id.uuidString)
                }
                Spacer(minLength: 0)
                Button(role: .destructive, action: onRemove) { Image(systemName: "minus.circle").frame(width: 44, height: 44) }
                    .foregroundStyle(Color.tertiaryText).accessibilityLabel("Remove \(ingredient.name)")
            }
            HStack {
                Text("In this drink").font(.caption).foregroundStyle(Color.secondaryText)
                Spacer()
                TextField("Optional", text: $amountText)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90, height: 44)
                    .focused($focusedField, equals: ingredient.id.uuidString)
                    .accessibilityLabel("Amount of \(ingredient.name)")
                Menu(ingredient.unit.isEmpty ? "Unit" : ingredient.unit) {
                    ForEach(["ml", "g", "tsp", "tbsp", "oz", "cup", "serving"], id: \.self) { unit in
                        Button(unit) { ingredient.unit = unit }
                    }
                }.frame(minWidth: 44, minHeight: 44).font(.subheadline.weight(.semibold))
                    .accessibilityLabel("Unit for \(ingredient.name)")
            }
        }.padding(18)
        .onAppear { syncAmountText() }
        .onChange(of: ingredient.amount) { _, _ in
            if focusedField != ingredient.id.uuidString { syncAmountText() }
        }
        .onChange(of: focusedField) { _, focused in
            if focused != ingredient.id.uuidString { syncAmountText() }
        }
        .onChange(of: amountText) { _, text in
            let parsed = Double(text.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: "."))
            if ingredient.amount != parsed { ingredient.amount = parsed }
        }
    }

    private func syncAmountText() {
        amountText = ingredient.amount.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...8))) } ?? ""
    }
}

private struct HomeDrinkPartPicker: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let selectingBase: Bool
    let excluding: UUID?
    let onRecipe: (HomeRecipeRecord, HomeRecipeVersion) -> Void
    let onPreset: (HomeBrewMethod) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var recipes: [HomeRecipeRecord] {
        store.workspace.recipes.filter { record in
            guard !record.isArchived, record.id != excluding, let content = record.current?.content,
                  HomeRecipeUse.suggested(for: content) != .drink else { return false }
            return (!selectingBase || HomeRecipeUse.suggested(for: content) == .base)
                && (query.isEmpty || content.searchText.localizedCaseInsensitiveContains(query))
        }.sorted { $0.current?.content.name.localizedStandardCompare($1.current?.content.name ?? "") == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if selectingBase, query.isEmpty {
                    Section("Start with a base") {
                        ForEach([HomeBrewMethod.espresso, .traditionalMatcha, .westernTea, .coldBrew]) { method in
                            Button { onPreset(method) } label: {
                                Label(method.title, systemImage: method.systemImage).frame(minHeight: 40)
                            }.accessibilityIdentifier("home.drink.preset.\(method.rawValue)")
                        }
                        Menu("Another method") {
                            ForEach(HomeBrewMethod.allCases.filter {
                                [.coffee, .matcha, .hojicha, .tea, .other].contains($0.family)
                            }) { method in Button(method.title) { onPreset(method) } }
                        }.frame(minHeight: 40)
                    }
                }
                Section(selectingBase ? "Your saved brews" : "From your recipe book") {
                    if recipes.isEmpty {
                        Text(selectingBase ? "Choose a starting point, or save a brew to reuse it here." : "Save a syrup, foam or brew first, or add a plain ingredient to your drink.")
                            .font(.subheadline).foregroundStyle(Color.secondaryText)
                    }
                    ForEach(recipes) { record in
                        if let version = record.current {
                            Button { onRecipe(record, version) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: HomeRecipeUse.suggested(for: version.content).symbol).frame(width: 32)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(version.content.name).font(.headline)
                                        Text(HomeRecipeUse.suggested(for: version.content).title).font(.caption).foregroundStyle(Color.secondaryText)
                                    }
                                    Spacer(); Image(systemName: "plus.circle").foregroundStyle(Color.mugshotSageText)
                                }.frame(minHeight: 52)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Find a saved recipe")
            .navigationTitle(selectingBase ? "Choose your base" : "Add something good")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .scrollContentBackground(.hidden).background(Color.creamWhite)
        }.tint(Color.mugshotSageText)
    }
}

struct HomeDrinkIllustration: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.mugshotMint.opacity(0.2)).frame(width: 100, height: 100)
            RoundedRectangle(cornerRadius: 11).stroke(Color.roastBrown, lineWidth: 2).frame(width: 22, height: 35).offset(x: 30, y: 13)
            VStack(spacing: 0) {
                Color.mugshotLatte.frame(height: 16)
                Color.sandBeige.frame(height: 24)
                Color.roastBrown.opacity(0.85).frame(height: 16)
            }
            .frame(width: 53, height: 60).clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14))
            .overlay(UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14).stroke(Color.roastBrown, lineWidth: 2))
            .offset(y: 13)
            Image(systemName: "sparkle").font(.system(size: 19, weight: .light)).foregroundStyle(Color.mugshotSageText).offset(x: -20, y: -35)
        }
    }
}

struct HomeRecipeUsePicker: View {
    @Binding var selection: HomeRecipeUse
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 8) { options } }
        else { HStack(spacing: 8) { options } }
    }
    @ViewBuilder private var options: some View {
        ForEach(HomeRecipeUse.allCases) { use in
            Button { selection = use; MugshotHaptic.selection.play() } label: {
                Label(use.title, systemImage: use.symbol).font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).frame(minHeight: 44)
                    .foregroundStyle(selection == use ? Color.foamWhite : Color.espressoBrown)
                    .background(selection == use ? Color.mugshotSageText : Color.foamWhite, in: Capsule())
                    .overlay(Capsule().stroke(selection == use ? Color.clear : Color.mugshotLine))
            }.buttonStyle(.plain).accessibilityAddTraits(selection == use ? .isSelected : [])
                .accessibilityIdentifier("home.recipe.use.\(use.rawValue)")
        }
    }
}

extension Text {
    func recipeEyebrow() -> some View {
        font(.system(.caption2, weight: .bold)).tracking(1.3).foregroundStyle(Color.mugshotSageText)
    }
}

extension HomeRecipeContent {
    var recipeContentsSummary: String {
        let ingredientText = "\(ingredients.count) ingredient" + (ingredients.count == 1 ? "" : "s")
        let stepText = "\(steps.count) step" + (steps.count == 1 ? "" : "s")
        if ingredients.isEmpty && steps.isEmpty { return isActionable ? summary : "Saved recipe idea" }
        return [ingredients.isEmpty ? nil : ingredientText, steps.isEmpty ? nil : stepText].compactMap { $0 }.joined(separator: " · ")
    }
}
