import SwiftUI
import UIKit

struct HomeDrinkBuilderSheet: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    @State private var draft: HomeRecipeEditorDraft
    let onSaved: (UUID) -> Void
    private let originalScope: LocalAccountScope
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var editingAmountID: UUID?
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
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center, spacing: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("YOUR NEXT FAVORITE").recipeEyebrow()
                            TextField("Name your drink", text: $draft.content.name, axis: .vertical)
                                .font(.system(.largeTitle, design: .serif).weight(.medium))
                                .lineLimit(1...3).autocorrectionDisabled().focused($focusedField, equals: "name")
                                .accessibilityLabel("Drink recipe name").accessibilityIdentifier("home.drink.name")
                            Text("A base. A little something. All you.")
                                .font(.subheadline).foregroundStyle(Color.secondaryText)
                        }
                        Spacer(minLength: 0)
                        if !dynamicTypeSize.isAccessibilitySize {
                            HomeDrinkIllustration().frame(width: 70, height: 96).accessibilityHidden(true)
                        }
                    }
                    Rectangle().fill(Color.mugshotLine).frame(height: 1)
                    VStack(alignment: .leading, spacing: 12) {
                        mixHeader
                        mix
                        additionControls
                    }
                    if draft.content.method != .other {
                        DisclosureGroup("Brew settings") {
                            VStack(spacing: 12) {
                                inventoryControls
                                targetEditors
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
                }.padding(22)
            }
            .scrollDismissesKeyboard(.never)
            .background(Color.creamWhite).foregroundStyle(Color.espressoBrown)
            .navigationTitle(draft.recipeID == nil ? "Build a drink" : "Your drink recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    if editingAmountID == nil {
                        Spacer()
                        Button("Done", action: dismissKeyboard).accessibilityIdentifier("home.drink.keyboardDone")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if focusedField == nil && editingAmountID == nil {
                    VStack(spacing: 8) {
                        if draftSaved { Label(dynamicTypeSize.isAccessibilitySize ? "Draft saved" : "Draft saved on this phone", systemImage: "checkmark").font(.caption).foregroundStyle(Color.secondaryText) }
                        Button(action: save) { Text(dynamicTypeSize.isAccessibilitySize ? "Save recipe" : "Save drink recipe").frame(maxWidth: .infinity) }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(!isCurrentOwner || draft.content.name.remoteTrimmedNonEmpty == nil)
                            .accessibilityIdentifier("home.drink.save")
                    }.padding(.horizontal, 22).padding(.vertical, 12).background(Color.creamWhite)
                }
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
                Group {
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
                }.environment(\.dynamicTypeSize, dynamicTypeSize)
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
                        onAmountEditing: { editing in
                            if editing { editingAmountID = ingredient.id }
                            else if editingAmountID == ingredient.id { editingAmountID = nil }
                        },
                        onPreview: { if let reference = ingredient.recipe { dismissKeyboard(); destination = .preview(reference) } },
                        onRemove: { dismissKeyboard(); draft.content.ingredients.removeAll { $0.id == ingredient.id } })
                }
            }
        }
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.mugshotLine, lineWidth: 1))
    }

    @ViewBuilder private var mixHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) { Text("The mix").font(.title3.weight(.semibold)); quantityHint }
        } else { HStack { Text("The mix").font(.title3.weight(.semibold)); Spacer(); quantityHint } }
    }
    private var quantityHint: some View { Text("Amounts are optional").font(.caption).foregroundStyle(Color.secondaryText) }
    @ViewBuilder private var additionControls: some View {
        if dynamicTypeSize.isAccessibilitySize { VStack(spacing: 10) { savedRecipeButton; ingredientMenu } }
        else { HStack(spacing: 10) { savedRecipeButton; ingredientMenu } }
    }
    private var savedRecipeButton: some View {
        Button { dismissKeyboard(); destination = .parts } label: {
            Label("Saved recipe", systemImage: "book.pages").frame(maxWidth: .infinity)
        }.buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("home.drink.addRecipe")
    }
    private var ingredientMenu: some View {
        Menu {
            ForEach(["Milk", "Oat milk", "Water", "Ice", "Honey"], id: \.self) { name in Button(name) { addIngredient(name) } }
            Button("Something else…") { customIngredient = ""; addsCustomIngredient = true }
        } label: { Label("Ingredient", systemImage: "plus").frame(maxWidth: .infinity) }
        .buttonStyle(SecondaryButtonStyle())
    }

    @ViewBuilder private var baseRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 14) { baseIdentity; chooseBase.frame(maxWidth: .infinity, alignment: .leading) }
                .padding(16)
        } else {
            HStack(spacing: 12) {
                HomeMethodIconView(method: draft.content.method, size: 30)
                    .frame(width: 40, height: 44).background(Color.sandBeige.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                baseIdentity
                Spacer(minLength: 0)
                chooseBase
            }.padding(16)
        }
    }
    private var baseIdentity: some View {
                VStack(alignment: .leading, spacing: 3) {
                    Text("THE BASE").recipeEyebrow()
                    Text(draft.content.ingredients.first(where: { $0.id == baseID })?.name ?? "Choose your base")
                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                    if let base = draft.content.ingredients.first(where: { $0.id == baseID }), let reference = base.recipe {
                        Button("View recipe ↗") { dismissKeyboard(); destination = .preview(reference) }
                            .font(.caption.weight(.semibold)).frame(minHeight: 32)
                    } else if let dose = draft.content.targets.dose, let output = draft.content.targets.resolvedOutput {
                        Text("Starting point · \(HomeRecipeContent.number(dose)) g → \(HomeRecipeContent.number(output)) g")
                            .font(.caption).foregroundStyle(Color.secondaryText)
                    }
                }
    }
    private var chooseBase: some View {
                Button(dynamicTypeSize.isAccessibilitySize ? "Change base" : "Change") { dismissKeyboard(); destination = .base }
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    .accessibilityIdentifier("home.drink.chooseBase")
    }

    private var inventoryControls: some View {
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
                Button("Gear", systemImage: "kettle") { dismissKeyboard(); destination = .gear }
        }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
    }

    @ViewBuilder private var targetEditors: some View {
        if draft.content.method.family == .coffee {
            if draft.content.metricConfiguration != nil { HomeConfiguredTargetsEditor(content: $draft.content) }
            else { HomeTargetsEditor(targets: $draft.content.targets, method: draft.content.method, advanced: $advanced) }
        } else {
            HomeNumberField(title: "\(draft.content.method.inputLabel) (g)", value: $draft.content.targets.dose)
            HomeNumberField(title: "\(draft.content.method.outputLabel) (\(draft.content.method.outputUnit))", value: Binding(
                get: { draft.content.targets.resolvedOutput },
                set: { draft.content.targets.output = $0; draft.content.targets.calculation = .output }))
            if draft.content.method.family == .tea || draft.content.method == .steepedHojicha {
                HomeNumberField(title: "Steep time (seconds)", value: $draft.content.targets.steepSeconds)
            } else { HomeNumberField(title: "Preparation time (seconds)", value: $draft.content.targets.seconds) }
            HomeNumberField(title: "Temperature (°C)", value: $draft.content.targets.temperature)
        }
    }

    private func addIngredient(_ name: String) {
        guard isCurrentOwner else { return }
        draft.content.ingredients.append(HomeRecipeIngredient(name: name, unit: ["Ice", "Honey"].contains(name) ? "g" : "ml"))
    }
    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    private func reloadShelf() {
        guard isCurrentOwner else { return }
        shelf = HomeLibraryStore.shared.load(in: originalScope)
    }
    private func save() {
        guard isCurrentOwner, !didSave else { return }
        dismissKeyboard()
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
    @FocusState.Binding var focusedField: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onAmountEditing: (Bool) -> Void
    let onPreview: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { identity; Spacer(minLength: 0); remove }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("In this drink").font(.caption).foregroundStyle(Color.secondaryText)
                        amount
                    }
                }
            } else {
                HStack(spacing: 8) {
                    identity.frame(maxWidth: .infinity, alignment: .leading)
                    amount
                    remove
                }
            }
        }.padding(14)
    }

    private var identity: some View {
        Group {
                if ingredient.recipe != nil {
                    Button(action: onPreview) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ingredient.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                            Text("View recipe ↗").font(.caption).foregroundStyle(Color.mugshotSageText)
                        }
                    }.buttonStyle(.plain).accessibilityLabel("Open \(ingredient.name) recipe")
                } else {
                    TextField("Ingredient", text: $ingredient.name, axis: .vertical)
                        .font(.subheadline.weight(.semibold)).focused($focusedField, equals: "name-" + ingredient.id.uuidString)
                }
        }
    }
    private var remove: some View {
        Button(role: .destructive, action: onRemove) {
            Image(systemName: "minus.circle").frame(width: dynamicTypeSize.isAccessibilitySize ? 76 : 44,
                                                   height: dynamicTypeSize.isAccessibilitySize ? 76 : 44)
        }
            .foregroundStyle(Color.tertiaryText).accessibilityLabel("Remove \(ingredient.name)")
    }
    private var amount: some View {
            HStack(spacing: 4) {
                HomeDrinkAmountField(value: $ingredient.amount, onEditing: onAmountEditing, label: "Amount of \(ingredient.name)")
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 140 : 64,
                           height: dynamicTypeSize.isAccessibilitySize ? 76 : 44)
                Menu(ingredient.unit.isEmpty ? "Unit" : ingredient.unit) {
                    ForEach(["ml", "g", "tsp", "tbsp", "oz", "cup", "serving"], id: \.self) { unit in
                        Button(unit) { ingredient.unit = unit }
                    }
                }.frame(minWidth: 44, minHeight: 44).font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("Unit for \(ingredient.name)")
            }
    }
}

/// Keep the live editing buffer in the native control while parent drafts autosave.
/// Reformat only outside editing; otherwise a parent refresh can reset an in-flight digit.
private struct HomeDrinkAmountField: UIViewRepresentable {
    @Binding var value: Double?
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17
    let onEditing: (Bool) -> Void
    let label: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = "—"; field.keyboardType = .decimalPad; field.textAlignment = .right
        field.font = .systemFont(ofSize: fontSize)
        field.tintColor = UIColor(Color.mugshotSageText)
        field.textColor = UIColor(Color.espressoBrown); field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        let toolbar = UIToolbar(); toolbar.sizeToFit()
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(Coordinator.done))
        done.accessibilityIdentifier = "home.drink.keyboardDone"
        toolbar.items = [UIBarButtonItem(systemItem: .flexibleSpace), done]
        field.inputAccessoryView = toolbar
        return field
    }
    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.accessibilityLabel = label
        field.accessibilityHint = "Optional amount in this drink."
        if field.font?.pointSize != fontSize { field.font = .systemFont(ofSize: fontSize) }
        if !field.isFirstResponder { field.text = formattedValue }
    }
    static func dismantleUIView(_ field: UITextField, coordinator: Coordinator) {
        field.delegate = nil
        field.removeTarget(coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.resignFirstResponder()
    }
    private var formattedValue: String {
        value.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...8))) } ?? ""
    }
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: HomeDrinkAmountField
        weak var field: UITextField?
        init(_ parent: HomeDrinkAmountField) { self.parent = parent }
        func textFieldDidBeginEditing(_ textField: UITextField) { field = textField; parent.onEditing(true) }
        func textFieldDidEndEditing(_ textField: UITextField) {
            changed(textField); parent.onEditing(false); textField.text = parent.formattedValue
        }
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let next = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
                .replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
            return next.range(of: "^[0-9]*(\\.[0-9]*)?$", options: .regularExpression) != nil
        }
        @objc func changed(_ field: UITextField) {
            let next = Double((field.text ?? "").replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: "."))
            if parent.value != next { parent.value = next }
        }
        @objc func done() { field?.resignFirstResponder() }
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
                            Button { onPreset(method); dismiss() } label: {
                                Label(method.title, systemImage: method.systemImage).frame(minHeight: 40)
                            }.accessibilityIdentifier("home.drink.preset.\(method.rawValue)")
                        }
                        Menu("Another method") {
                            ForEach(HomeBrewMethod.allCases.filter {
                                [.coffee, .matcha, .hojicha, .tea, .other].contains($0.family)
                            }) { method in Button(method.title) { onPreset(method); dismiss() } }
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
                            Button { onRecipe(record, version); dismiss() } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: HomeRecipeUse.suggested(for: version.content).symbol).frame(width: 32)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(version.content.name).font(.headline)
                                        Text(HomeRecipeUse.suggested(for: version.content).title).font(.caption).foregroundStyle(Color.secondaryText)
                                    }
                                    Spacer(); Image(systemName: "plus.circle").foregroundStyle(Color.mugshotSageText)
                                }.frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .accessibilityLabel(selectingBase ? "Use \(version.content.name) as base" : "Add \(version.content.name)")
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
