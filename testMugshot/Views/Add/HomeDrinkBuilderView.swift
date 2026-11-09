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
    @State private var milkIDs: Set<UUID>
    @FocusState private var focusedField: String?

    private enum Destination: Identifiable {
        case base, parts, switchPart(UUID), gear, preview(HomeRecipeReference)
        var id: String {
            switch self {
            case .base: "base"
            case .parts: "parts"
            case .switchPart(let id): "switch-\(id.uuidString)"
            case .gear: "gear"
            case .preview(let ref): ref.versionID.uuidString
            }
        }
    }

    init(store: HomeRecipeWorkspaceStore, draft: HomeRecipeEditorDraft? = nil,
         component: HomeRecipeRecord? = nil, onSaved: @escaping (UUID) -> Void) {
        self.store = store; self.onSaved = onSaved; originalScope = store.scope
        let initial = draft ?? HomeRecipeEditorDraft(content: HomeDrinkComposition.starting(with: component))
        _draft = State(initialValue: initial)
        _milkIDs = State(initialValue: Set(initial.content.ingredients.filter(HomeDrinkComposition.isMilk).map(\.id)))
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
                    mix
                    portionsCard
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
                }
                .padding(.horizontal, 22).padding(.vertical, 22)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
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
                case .base, .parts, .switchPart:
                    partPicker(for: item)
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
        let base = baseID
        let milk = draft.content.ingredients.filter { $0.id != base && milkIDs.contains($0.id) }
        let additions = draft.content.ingredients.filter { $0.id != base && !milkIDs.contains($0.id) }
        return VStack(alignment: .leading, spacing: 14) {
            mixHeader
            HomeEditorSection("Base", symbol: "cup.and.saucer", detail: "Start with a brew or choose a saved recipe.") {
                baseRow
                if let base, let item = draft.content.ingredients.first(where: { $0.id == base }) {
                    HomeDrinkPartQuantity(ingredient: HomeEditorBindings.item(item, in: $draft.content.ingredients),
                        onEditing: { amountEditing(item.id, $0) })
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HomeEditorSection("Milk", symbol: "drop", detail: "Add milk or cream if you use it.") {
                ForEach(milk) { partRow($0) }
                milkMenu(milk.first)
            }
            HomeEditorSection("Add-ins", symbol: "sparkles", detail: "Use a saved syrup or foam, or add an ingredient.") {
                ForEach(additions) { partRow($0) }
                additionControls
            }
        }
    }

    private func partRow(_ item: HomeRecipeIngredient) -> some View {
        HomeDrinkPartRow(ingredient: HomeEditorBindings.item(item, in: $draft.content.ingredients),
            focusedField: $focusedField, linkedCaption: linkCaption(for: item),
            onAmountEditing: { amountEditing(item.id, $0) },
            onPreview: { if let reference = item.recipe { dismissKeyboard(); destination = .preview(reference) } },
            onSwitch: item.recipe == nil ? nil : { dismissKeyboard(); destination = .switchPart(item.id) },
            onRemove: {
                dismissKeyboard()
                draft.content.ingredients.removeAll { $0.id == item.id }
                milkIDs.remove(item.id)
            })
    }

    @ViewBuilder private var mixHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Text("The mix").font(.title3.weight(.semibold))
                quantityHint
            }
        } else {
            HStack { Text("The mix").font(.title3.weight(.semibold)); Spacer(); quantityHint }
        }
    }

    private var quantityHint: some View { Text("Amounts are optional").font(.caption).foregroundStyle(Color.secondaryText) }

    @ViewBuilder private var additionControls: some View {
        if dynamicTypeSize.isAccessibilitySize { VStack(spacing: 10) { savedRecipeButton; ingredientMenu } }
        else { HStack(spacing: 10) { savedRecipeButton; ingredientMenu } }
    }

    private var savedRecipeButton: some View {
        Button { dismissKeyboard(); destination = .parts } label: {
            Label("Saved add-in", systemImage: "book.pages").frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("home.drink.addRecipe")
    }

    private var ingredientMenu: some View {
        Menu {
            ForEach(["Water", "Ice", "Honey", "Sugar"], id: \.self) { name in
                Button(name) { addIngredient(name) }
            }
            Button("Something else…") { customIngredient = ""; addsCustomIngredient = true }
        } label: {
            Label("Ingredient", systemImage: "plus").frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private func milkMenu(_ current: HomeRecipeIngredient?) -> some View {
        Menu {
            ForEach(["Milk", "Oat milk", "Almond milk", "Soy milk", "Cream"], id: \.self) { name in
                Button(name) { chooseMilk(name, replacing: current?.id) }
            }
        } label: {
            Label(current == nil ? "Add milk" : "Change milk", systemImage: current == nil ? "plus" : "arrow.left.arrow.right")
                .frame(minHeight: 44)
        }
        .accessibilityIdentifier("home.drink.milk")
    }

    private var portionsCard: some View {
        HomeEditorSection("Servings", symbol: "person.2", detail: "Scale the amounts in this drink. Brew settings describe one brew.") {
            Menu {
                ForEach([1.0, 2.0, 4.0], id: \.self) { servings in
                    Button(portionsLabel(servings)) { scale(to: servings) }
                }
            } label: {
                Label(portionsLabel(draft.content.servings), systemImage: "arrow.up.arrow.down")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("home.drink.servings")
        }
    }

    private func portionsLabel(_ count: Double) -> String {
        HomeRecipeContent.number(count) + (count == 1 ? " serving" : " servings")
    }

    @ViewBuilder private var baseRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) { baseIdentity; chooseBase }
        } else {
            HStack(spacing: 12) {
                HomeMethodIconView(method: draft.content.method, size: 28)
                    .frame(width: 40, height: 44).background(Color.sandBeige.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                baseIdentity
                Spacer(minLength: 0)
                chooseBase
            }
        }
    }

    private var baseIdentity: some View {
        VStack(alignment: .leading, spacing: 4) {
            let item = draft.content.ingredients.first { $0.id == baseID }
            Text(item?.name ?? "Choose your base").font(.headline).fixedSize(horizontal: false, vertical: true)
            if let item, let reference = item.recipe {
                if let caption = linkCaption(for: item) {
                    Text(caption).font(.caption).foregroundStyle(Color.secondaryText)
                }
                Button("View recipe", systemImage: "arrow.up.right") {
                    dismissKeyboard(); destination = .preview(reference)
                }
                .font(.caption.weight(.semibold)).frame(minHeight: 44)
                .accessibilityLabel("Open \(item.name) recipe")
            } else if let dose = draft.content.targets.dose, let output = draft.content.targets.resolvedOutput {
                Text("Starting point · \(HomeRecipeContent.number(dose)) g → \(HomeRecipeContent.number(output)) \(draft.content.method.outputUnit)")
                    .font(.caption).foregroundStyle(Color.secondaryText)
            }
        }
    }

    private var chooseBase: some View {
        Button("Change base") { dismissKeyboard(); destination = .base }
            .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            .accessibilityIdentifier("home.drink.chooseBase")
    }

    private func linkCaption(for ingredient: HomeRecipeIngredient) -> String? {
        guard let reference = ingredient.recipe else { return nil }
        guard let version = store.workspace.version(reference) else { return "Saved version unavailable" }
        let source = version.content.creatorCredit.remoteTrimmedNonEmpty
            ?? URLComponents(string: version.content.sourceURL)?.host ?? "Recipe book"
        return "Version \(version.number) · \(source)"
    }

    private func partPicker(for item: Destination) -> some View {
        let selectingBase = item.id == "base"
        let replacing: HomeRecipeIngredient? = {
            if case .switchPart(let id) = item { return draft.content.ingredients.first { $0.id == id } }
            return nil
        }()
        let blocked = replacing.map { old in Set(draft.content.ingredients.filter { $0.id != old.id }.compactMap(\.recipe)) } ?? []
        return HomeDrinkPartPicker(store: store, selectingBase: selectingBase, excluding: draft.recipeID,
            replacingName: replacing?.name, blockedReferences: blocked) { recipe, version in
            guard isCurrentOwner else { return }
            if selectingBase {
                HomeDrinkComposition.useBase(recipe, version: version, in: &draft.content, replacing: baseID)
            } else if let replacing {
                HomeDrinkComposition.replacePart(id: replacing.id, with: recipe, version: version, in: &draft.content)
            } else {
                HomeDrinkComposition.add(recipe, version: version, to: &draft.content)
            }
            destination = nil
        } onPreset: { method in
            guard isCurrentOwner else { return }
            HomeDrinkComposition.usePreset(method, in: &draft.content, replacing: baseID)
            destination = nil
        }
    }

    private func amountEditing(_ id: UUID, _ editing: Bool) {
        if editing { editingAmountID = id }
        else if editingAmountID == id { editingAmountID = nil }
    }

    private func chooseMilk(_ name: String, replacing id: UUID?) {
        guard isCurrentOwner else { return }
        dismissKeyboard()
        if let id, let index = draft.content.ingredients.firstIndex(where: { $0.id == id }) {
            draft.content.ingredients[index].name = name
        } else {
            let milk = HomeRecipeIngredient(name: name, unit: "ml")
            milkIDs.insert(milk.id)
            draft.content.ingredients.append(milk)
        }
    }

    private func scale(to servings: Double) {
        guard isCurrentOwner else { return }
        dismissKeyboard()
        guard let scaled = HomeDrinkComposition.scaled(draft.content, toServings: servings) else {
            error = "Check the ingredient amounts before scaling this drink."
            return
        }
        draft.content = scaled
        error = nil
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
        draft.content.ingredients.append(HomeRecipeIngredient(name: name, unit: ["Ice", "Honey", "Sugar"].contains(name) ? "g" : "ml"))
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
    let linkedCaption: String?
    let onAmountEditing: (Bool) -> Void
    let onPreview: () -> Void
    let onSwitch: (() -> Void)?
    let onRemove: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    identity
                    Text("In this drink").font(.caption).foregroundStyle(Color.secondaryText)
                    amount
                    HStack { switchButton; Spacer(minLength: 0); remove }
                }
            } else if ingredient.recipe != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { identity; Spacer(minLength: 0); remove }
                    HStack { amount; Spacer(minLength: 0); switchButton }
                }
            } else {
                HStack(spacing: 8) {
                    identity.frame(maxWidth: .infinity, alignment: .leading)
                    amount
                    remove
                }
            }
        }
        .padding(10).background(Color.creamWhite, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private var identity: some View {
        if ingredient.recipe != nil {
            Button(action: onPreview) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ingredient.name).font(.headline).multilineTextAlignment(.leading)
                    if let linkedCaption { Text(linkedCaption).font(.caption).foregroundStyle(Color.secondaryText) }
                    Label("View recipe", systemImage: "arrow.up.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.mugshotSageText)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("Open \(ingredient.name) recipe")
            .accessibilityHint(linkedCaption ?? "")
        } else {
            TextField("Ingredient", text: $ingredient.name, axis: .vertical)
                .font(.subheadline.weight(.semibold)).focused($focusedField, equals: "name-" + ingredient.id.uuidString)
        }
    }

    @ViewBuilder private var switchButton: some View {
        if let onSwitch {
            Button("Switch", systemImage: "arrow.left.arrow.right", action: onSwitch)
                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                .accessibilityLabel("Switch \(ingredient.name)")
        }
    }

    private var remove: some View {
        Button(role: .destructive, action: onRemove) {
            Image(systemName: "minus.circle").frame(width: 44, height: 44)
        }
        .foregroundStyle(Color.tertiaryText).accessibilityLabel("Remove \(ingredient.name)")
    }

    private var amount: some View {
        HomeDrinkPartQuantity(ingredient: $ingredient, onEditing: onAmountEditing)
    }
}

private struct HomeDrinkPartQuantity: View {
    @Binding var ingredient: HomeRecipeIngredient
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onEditing: (Bool) -> Void

    var body: some View {
        HStack(spacing: 4) {
            HomeDrinkAmountField(value: $ingredient.amount, onEditing: onEditing, label: "Amount of \(ingredient.name)")
                .frame(width: dynamicTypeSize.isAccessibilitySize ? 132 : 64,
                       height: dynamicTypeSize.isAccessibilitySize ? 66 : 44)
            Menu(ingredient.unit.isEmpty ? "Unit" : ingredient.unit) {
                ForEach(["ml", "g", "tsp", "tbsp", "oz", "cup", "serving"], id: \.self) { unit in
                    Button(unit) { ingredient.unit = unit }
                }
            }
            .frame(minWidth: 44, minHeight: 44).font(.subheadline.weight(.semibold))
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
    let replacingName: String?
    let blockedReferences: Set<HomeRecipeReference>
    let onRecipe: (HomeRecipeRecord, HomeRecipeVersion) -> Void
    let onPreset: (HomeBrewMethod) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var recipes: [HomeRecipeRecord] {
        store.workspace.recipes.filter { record in
            guard !record.isArchived, record.id != excluding, let version = record.current else { return false }
            let reference = HomeRecipeReference(recipeID: record.id, versionID: version.id)
            return !blockedReferences.contains(reference)
                && HomeRecipeUse.suggested(for: version.content) == (selectingBase ? .base : .component)
                && (query.isEmpty || version.content.searchText.localizedCaseInsensitiveContains(query))
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
                Section(selectingBase ? "Your saved brews" : "Saved add-ins") {
                    if recipes.isEmpty {
                        Text(selectingBase ? "Choose a starting point, or save a brew to reuse it here." : "Save a syrup or foam first, or add a plain ingredient to your drink.")
                            .font(.subheadline).foregroundStyle(Color.secondaryText)
                    }
                    ForEach(recipes) { record in
                        if let version = record.current {
                            Button { onRecipe(record, version); dismiss() } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: HomeRecipeUse.suggested(for: version.content).symbol).frame(width: 32)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(version.content.name).font(.headline)
                                        Text(["Version \(version.number)", version.content.creatorCredit.remoteTrimmedNonEmpty].compactMap { $0 }.joined(separator: " · "))
                                            .font(.caption).foregroundStyle(Color.secondaryText)
                                    }
                                    Spacer(); Image(systemName: "plus.circle").foregroundStyle(Color.mugshotSageText)
                                }.frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .accessibilityLabel(selectingBase ? "Use \(version.content.name) as base"
                                    : replacingName == nil ? "Add \(version.content.name)" : "Use \(version.content.name)")
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Find a saved recipe")
            .navigationTitle(selectingBase ? "Choose your base" : replacingName.map { "Switch \($0)" } ?? "Choose an add-in")
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 220 : 95), spacing: 8)], spacing: 8) {
            ForEach([HomeRecipeUse.drink, .component, .base]) { use in
                Button {
                    selection = use
                    MugshotHaptic.selection.play()
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Image(systemName: use.symbol).foregroundStyle(Color.mugshotSageText).accessibilityHidden(true)
                        Text(use.title).font(.subheadline.weight(.semibold))
                        Text(use.example).font(.caption).foregroundStyle(Color.secondaryText)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                    .padding(10)
                    .foregroundStyle(Color.espressoBrown)
                    .background(selection == use ? Color.mugshotMint.opacity(0.4) : Color.creamWhite,
                        in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(selection == use ? Color.mugshotSageText : Color.mugshotLine))
                }
                .buttonStyle(.plain).accessibilityAddTraits(selection == use ? .isSelected : [])
                .accessibilityLabel(use.title).accessibilityHint(use.example)
                .accessibilityIdentifier("home.recipe.use.\(use.rawValue)")
            }
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
        let ingredientCount = ingredients.filter { $0.name.remoteTrimmedNonEmpty != nil || $0.recipe != nil }.count
        let stepCount = visibleSteps.filter { $0.instruction.remoteTrimmedNonEmpty != nil }.count
        var details: [String] = []
        if ingredientCount > 0 { details.append("\(ingredientCount) ingredient" + (ingredientCount == 1 ? "" : "s")) }
        if stepCount > 0 { details.append("\(stepCount) step" + (stepCount == 1 ? "" : "s")) }
        if details.isEmpty { return isReadyToMake ? summary : "Saved recipe idea" }
        if !isReadyToMake { details.append("Recipe idea") }
        return details.joined(separator: " · ")
    }
}
