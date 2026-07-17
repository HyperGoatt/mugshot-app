import SwiftUI

enum TastingLens2Sheet: String, Identifiable {
    case identity
    case customize

    var id: String { rawValue }
}

// MARK: - Drink identity

struct TastingLensIdentityEditor: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (SensoryDrinkIdentity) -> Void

    @State private var identity: SensoryDrinkIdentity
    @State private var sweetenersText: String
    @State private var flavorsText: String
    @State private var additionsText: String

    init(
        identity: SensoryDrinkIdentity,
        onSave: @escaping (SensoryDrinkIdentity) -> Void
    ) {
        self.onSave = onSave
        var reconciledIdentity = identity
        if !Self.validPreparations(for: identity.family).contains(identity.preparation) {
            reconciledIdentity.preparation = Self.defaultPreparation(for: identity.family)
        }
        _identity = State(initialValue: reconciledIdentity)
        _sweetenersText = State(initialValue: identity.sweeteners.joined(separator: ", "))
        _flavorsText = State(initialValue: identity.flavors.joined(separator: ", "))
        _additionsText = State(initialValue: identity.additions.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Drink name", text: $identity.rawName, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("tastingLens2.identity.name")

                    Picker("Base drink", selection: $identity.family) {
                        ForEach(SensoryBeverageFamily.allCases, id: \.self) { family in
                            Text(family.title).tag(family)
                        }
                    }

                    Picker("Preparation", selection: $identity.preparation) {
                        ForEach(Self.validPreparations(for: identity.family), id: \.self) { preparation in
                            Text(preparation.title).tag(preparation)
                        }
                    }

                    Picker("Serving temperature", selection: $identity.temperature) {
                        ForEach(SensoryServingTemperature.allCases, id: \.self) { temperature in
                            Text(temperature.title).tag(temperature)
                        }
                    }
                } header: {
                    Text("What are you tasting?")
                } footer: {
                    Text("The confirmed identity chooses a versioned base pack. You can always correct it.")
                }

                Section {
                    TextField("Milk, if any", text: optionalMilkBinding)
                        .textInputAutocapitalization(.words)
                    TextField("Sweeteners, separated by commas", text: $sweetenersText, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Flavors, separated by commas", text: $flavorsText, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Other additions, separated by commas", text: $additionsText, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("What was added?")
                } footer: {
                    Text("Mugshot keeps added flavor, milk, and sweetness separate from sensations you notice in the base drink.")
                }

                Section {
                    Label("This information selects questions. It never calculates your stars.", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Confirm drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use this drink") { save() }
                        .disabled(identity.rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("tastingLens2.identity.save")
                }
            }
            .tint(.mugshotSage)
            .onChange(of: identity.family) { _, newFamily in
                reconcilePreparation(for: newFamily)
            }
        }
    }

    private var optionalMilkBinding: Binding<String> {
        Binding(
            get: { identity.milk ?? "" },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                identity.milk = trimmed.isEmpty ? nil : value
            }
        )
    }

    private func reconcilePreparation(for family: SensoryBeverageFamily) {
        let validPreparations = Self.validPreparations(for: family)
        guard identity.preparation == .unknown || !validPreparations.contains(identity.preparation) else {
            return
        }
        identity.preparation = Self.defaultPreparation(for: family)
    }

    private static func validPreparations(
        for family: SensoryBeverageFamily
    ) -> [SensoryPreparation] {
        switch family {
        case .espresso:
            return [.espresso, .americano, .other, .unknown]
        case .brewedCoffee:
            return [.pourOver, .drip, .immersion, .coldBrew, .other, .unknown]
        case .milkCoffee:
            return [.latte, .cappuccino, .flatWhite, .cortado, .other, .unknown]
        case .matcha:
            return [.whiskedPowder, .other, .unknown]
        case .matchaLatte:
            return [.latte, .whiskedPowder, .other, .unknown]
        case .hojichaLeaf:
            return [.steepedLeaf, .coldBrew, .other, .unknown]
        case .hojichaPowder:
            return [.whiskedPowder, .other, .unknown]
        case .hojichaLatte:
            return [.latte, .whiskedPowder, .steepedLeaf, .other, .unknown]
        case .greenTea, .blackTea, .whiteTea, .oolongTea, .herbalInfusion:
            return [.steepedLeaf, .coldBrew, .other, .unknown]
        case .milkTea:
            return [.milkTea, .latte, .steepedLeaf, .other, .unknown]
        case .universal, .unknown:
            return SensoryPreparation.allCases
        }
    }

    private static func defaultPreparation(
        for family: SensoryBeverageFamily
    ) -> SensoryPreparation {
        switch family {
        case .espresso: return .espresso
        case .brewedCoffee: return .drip
        case .milkCoffee, .matchaLatte, .hojichaLatte: return .latte
        case .matcha, .hojichaPowder: return .whiskedPowder
        case .hojichaLeaf, .greenTea, .blackTea, .whiteTea, .oolongTea, .herbalInfusion:
            return .steepedLeaf
        case .milkTea: return .milkTea
        case .universal, .unknown: return .unknown
        }
    }

    private func save() {
        identity.rawName = identity.rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        identity.sweeteners = commaSeparatedValues(sweetenersText)
        identity.flavors = commaSeparatedValues(flavorsText)
        identity.additions = commaSeparatedValues(additionsText)
        identity.confidence = 1
        identity.provenance = .user
        identity.userConfirmed = true
        identity.modifiers = rebuiltModifiers(from: identity)
        onSave(identity)
        dismiss()
    }

    private func rebuiltModifiers(from identity: SensoryDrinkIdentity) -> [SensoryDrinkModifier] {
        var modifiers = identity.modifiers.filter { $0.kind == .foam || $0.kind == .topping || $0.kind == .dilution }
        if let milk = identity.milk?.trimmingCharacters(in: .whitespacesAndNewlines), !milk.isEmpty {
            modifiers.append(
                SensoryDrinkModifier(id: "milk.\(stableSlug(milk))", kind: .milk, label: milk, userConfirmed: true)
            )
        }
        modifiers.append(contentsOf: identity.sweeteners.map {
            SensoryDrinkModifier(id: "sweetener.\(stableSlug($0))", kind: .sweetener, label: $0, userConfirmed: true)
        })
        modifiers.append(contentsOf: identity.flavors.map {
            SensoryDrinkModifier(id: "flavor.\(stableSlug($0))", kind: .flavor, label: $0, userConfirmed: true)
        })
        modifiers.append(contentsOf: identity.additions.map {
            SensoryDrinkModifier(id: "addition.\(stableSlug($0))", kind: .other, label: $0, userConfirmed: true)
        })
        return modifiers
    }

    private func commaSeparatedValues(_ value: String) -> [String] {
        var seen: Set<String> = []
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { value in
                guard !value.isEmpty else { return false }
                return seen.insert(value.localizedLowercase).inserted
            }
    }

    private func stableSlug(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "_")
    }
}

// MARK: - Customize My Lens

struct TastingLensCustomizeSheet: View {
    private enum AnswerKind: String, CaseIterable, Identifiable {
        case descriptor
        case intensity
        case textureState
        case relationship
        case duration
        case preference

        var id: String { rawValue }

        var title: String {
            switch self {
            case .descriptor: return "Descriptor choices"
            case .intensity: return "Intensity"
            case .textureState: return "Texture or state"
            case .relationship: return "Relationship"
            case .duration: return "Duration"
            case .preference: return "Preference"
            }
        }

        var measure: SensoryMeasureType {
            switch self {
            case .descriptor, .textureState: return .multipleChoice
            case .intensity: return .intensity
            case .relationship: return .singleChoice
            case .duration: return .duration
            case .preference: return .preference
            }
        }

        var defaultOptions: [String] {
            switch self {
            case .relationship: return ["Joined", "Layered", "Led by one part"]
            case .preference: return ["Not for me", "Neutral", "I liked it"]
            case .duration: return []
            case .descriptor, .textureState, .intensity: return []
            }
        }

        var needsOptions: Bool {
            self == .descriptor || self == .textureState
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let criteria: [SensoryCriterionDefinition]
    let identity: SensoryDrinkIdentity
    let onSave: (TastingLensUserPreferences) -> Void

    @State private var preferences: TastingLensUserPreferences
    @State private var customTitle = ""
    @State private var customPrompt = ""
    @State private var customDimension: SensoryDimension = .flavor
    @State private var answerKind: AnswerKind = .descriptor
    @State private var customOptions = ""
    @State private var pinsNewCriterion = true
    @State private var showsNewCriterion = false
    @State private var customCriteriaEditMode: EditMode = .inactive

    init(
        criteria: [SensoryCriterionDefinition],
        identity: SensoryDrinkIdentity,
        preferences: TastingLensUserPreferences,
        onSave: @escaping (TastingLensUserPreferences) -> Void
    ) {
        self.criteria = criteria
        self.identity = identity
        self.onSave = onSave
        _preferences = State(initialValue: preferences)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Default tasting depth", selection: $preferences.defaultDepth) {
                        ForEach(TastingDepth.allCases) { depth in
                            Text(depth.title).tag(depth)
                        }
                    }
                } header: {
                    Text("Everyday default")
                } footer: {
                    Text("You can still choose Quick, Guided, or Deep for any individual sip.")
                }

                Section {
                    ForEach(criteria) { criterion in
                        criterionRow(criterion)
                    }
                } header: {
                    Text("For \(identity.family.title)")
                } footer: {
                    Text("Pinning changes which questions appear first. It never gives a question more scoring influence.")
                }

                Section {
                    DisclosureGroup(isExpanded: $showsNewCriterion) {
                        customCriterionEditor
                    } label: {
                        Label("Create a typed criterion", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.espressoBrown)
                    }
                } footer: {
                    Text("Custom questions must declare what their answers mean. Generic star rows and weights are intentionally unavailable.")
                }

                if !preferences.customCriteria.isEmpty {
                    Section {
                        ForEach(preferences.customCriteria) { criterion in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    TextField(
                                        "Criterion name",
                                        text: customCriterionTitleBinding(id: criterion.id)
                                    )
                                        .font(.subheadline.weight(.semibold))
                                        .textInputAutocapitalization(.sentences)
                                    Text(criterion.measure.displayTitle)
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    deleteCustomCriterion(id: criterion.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Delete \(criterion.title)")
                            }
                        }
                        .onMove(perform: moveCustomCriteria)
                    } header: {
                        HStack {
                            Text("Your custom criteria")
                            Spacer()
                            Button(customCriteriaEditMode.isEditing ? "Done ordering" : "Reorder") {
                                withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
                                    customCriteriaEditMode = customCriteriaEditMode.isEditing ? .inactive : .active
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .textCase(nil)
                            .frame(minHeight: 44, alignment: .trailing)
                            .contentShape(Rectangle())
                        }
                    } footer: {
                        Text("Rename in place or reorder these questions. Saved visits keep the wording and order they originally showed.")
                    }
                }

                Section {
                    Label("Not sure, Skip, Not present, and Not relevant remain distinct in every custom criterion.", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .environment(\.editMode, $customCriteriaEditMode)
            .navigationTitle("Customize My Lens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                        .accessibilityIdentifier("tastingLens2.customize.save")
                }
            }
            .tint(.mugshotSage)
        }
    }

    private func criterionRow(_ criterion: SensoryCriterionDefinition) -> some View {
        let pinned = isPinned(criterion.id)
        let core = isCoreCriterion(criterion)
        let hidden = preferences.hidesCriterion(
            targetID: criterion.id,
            scopeID: identity.personalizationScopeID
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(criterion.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(hidden ? Color.tertiaryText : Color.espressoBrown)
                    Text("\(criterion.dimension.displayTitle) · \(criterion.measure.displayTitle)")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer(minLength: 4)

                if core {
                    Label("Core step", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .frame(minHeight: 44)
                } else {
                    Button {
                        setPinned(criterion.id, !pinned)
                    } label: {
                        Image(systemName: pinned ? "pin.fill" : "pin")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(pinned ? "Unpin \(criterion.title)" : "Pin \(criterion.title)")
                    .accessibilityAddTraits(pinned ? .isSelected : [])
                    .disabled(hidden)

                    Button {
                        setHidden(criterion.id, !hidden)
                    } label: {
                        Image(systemName: hidden ? "eye.slash.fill" : "eye")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(hidden ? "Show \(criterion.title)" : "Hide \(criterion.title) for this drink type")
                    .accessibilityAddTraits(hidden ? .isSelected : [])
                }
            }
        }
    }

    private func isCoreCriterion(_ criterion: SensoryCriterionDefinition) -> Bool {
        criterion.measure == .ownWords
            || criterion.measure == .overallEnjoyment
            || criterion.id == "criterion.flavor.web"
            || criterion.id == "criterion.mugsy.leading"
    }

    private var customCriterionEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Criterion name", text: $customTitle)
                .textInputAutocapitalization(.sentences)
            TextField("Question to ask", text: $customPrompt, axis: .vertical)
                .lineLimit(1...3)
                .textInputAutocapitalization(.sentences)

            Picker("Sensory dimension", selection: $customDimension) {
                ForEach(customizableDimensions, id: \.self) { dimension in
                    Text(dimension.displayTitle).tag(dimension)
                }
            }

            Picker("Answer type", selection: $answerKind) {
                ForEach(AnswerKind.allCases) { type in
                    Text(type.title).tag(type)
                }
            }

            if answerKind.needsOptions {
                TextField("Choices, separated by commas", text: $customOptions, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.sentences)
            } else if !answerKind.defaultOptions.isEmpty {
                Text(answerKind.defaultOptions.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            Toggle("Pin for \(identity.family.title)", isOn: $pinsNewCriterion)

            Button("Add criterion") { addCustomCriterion() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canAddCustomCriterion)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("tastingLens2.customize.add")
        }
        .padding(.top, 10)
    }

    private var customizableDimensions: [SensoryDimension] {
        [.appearance, .aroma, .taste, .flavor, .body, .texture, .astringency, .finish, .temperatureChange, .integration, .balance, .personalResponse]
    }

    private var parsedCustomOptions: [String] {
        let source = answerKind.defaultOptions.isEmpty
            ? customOptions.split(separator: ",").map(String.init)
            : answerKind.defaultOptions
        var seen: Set<String> = []
        return source
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.localizedLowercase).inserted }
    }

    private var canAddCustomCriterion: Bool {
        !customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!answerKind.needsOptions || !parsedCustomOptions.isEmpty)
    }

    private func addCustomCriterion() {
        guard canAddCustomCriterion else { return }
        let id = "custom.\(UUID().uuidString.lowercased())"
        let title = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = parsedCustomOptions.enumerated().map { index, label in
            SensoryChoiceDefinition(
                id: "\(id).option.\(index)",
                label: label,
                helper: nil,
                descriptorID: nil
            )
        }
        let criterion = SensoryCriterionDefinition(
            id: id,
            title: title,
            prompt: prompt.isEmpty ? title : prompt,
            helper: customHelper,
            accessibilityLabel: prompt.isEmpty ? title : prompt,
            dimension: customDimension,
            stage: customDimension.defaultStage,
            measure: answerKind.measure,
            scaleID: {
                switch answerKind {
                case .intensity: return "scale.intensity_3"
                case .duration: return "scale.duration_3"
                default: return nil
                }
            }(),
            options: options,
            descriptorRootIDs: [],
            depths: [.guided, .deep],
            applicability: [
                SensoryApplicabilityRule(
                    field: .family,
                    values: [identity.family.rawValue]
                )
            ],
            evidenceSourceIDs: [],
            order: 10_000 + preferences.customCriteria.count
        )
        preferences.customCriteria.append(criterion)
        if pinsNewCriterion { setPinned(id, true) }
        customTitle = ""
        customPrompt = ""
        customOptions = ""
        answerKind = .descriptor
        customDimension = .flavor
        pinsNewCriterion = true
        MugshotHaptic.softImpact.play()
    }

    private var customHelper: String {
        switch answerKind {
        case .descriptor: return "Choose any descriptors that fit. Your own wording remains valid."
        case .intensity: return "Record strength separately from whether you enjoyed it."
        case .textureState: return "Choose any tactile states you notice."
        case .relationship: return "Describe how the parts relate without turning it into a score."
        case .duration: return "Describe how long it remains. Longer is not automatically better."
        case .preference: return "This is an explicit personal preference, not intensity or quality."
        }
    }

    private func isPinned(_ criterionID: String) -> Bool {
        preferences.pinnedCriterionIDs(for: identity.personalizationScopeID).contains(criterionID)
    }

    private func setPinned(_ criterionID: String, _ pinned: Bool) {
        guard !Self.coreCriterionIDs.contains(criterionID) else { return }
        let scopeID = identity.personalizationScopeID
        var ids = preferences.pinnedCriterionIDsByScope[scopeID] ?? []
        if pinned {
            if !ids.contains(criterionID) { ids.append(criterionID) }
        } else {
            ids.removeAll { $0 == criterionID }
        }
        preferences.pinnedCriterionIDsByScope[scopeID] = ids
        preferences.updatedAt = .now
    }

    private func setHidden(_ criterionID: String, _ hidden: Bool) {
        guard !Self.coreCriterionIDs.contains(criterionID) else { return }
        let scopeID = identity.personalizationScopeID
        preferences.dismissals.removeAll {
            $0.targetID == criterionID && $0.scopeID == scopeID && $0.snapshotID == nil
        }
        if hidden {
            preferences.dismissals.append(
                SensorySuggestionDismissal(
                    targetID: criterionID,
                    scopeID: scopeID,
                    reason: .notRelevant
                )
            )
        }
        preferences.updatedAt = .now
    }

    private func deleteCustomCriterion(id: String) {
        preferences.customCriteria.removeAll { $0.id == id }
        for scopeID in preferences.pinnedCriterionIDsByScope.keys {
            preferences.pinnedCriterionIDsByScope[scopeID]?.removeAll { $0 == id }
        }
        preferences.dismissals.removeAll { $0.targetID == id }
        preferences.updatedAt = .now
    }

    private func customCriterionTitleBinding(id: String) -> Binding<String> {
        Binding(
            get: {
                preferences.customCriteria.first(where: { $0.id == id })?.title ?? ""
            },
            set: { newValue in
                guard let index = preferences.customCriteria.firstIndex(where: { $0.id == id }) else { return }
                let original = preferences.customCriteria[index]
                guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                preferences.customCriteria[index] = copyCriterion(
                    original,
                    title: newValue,
                    prompt: original.prompt == original.title ? newValue : original.prompt,
                    order: original.order
                )
                preferences.updatedAt = .now
            }
        )
    }

    private func moveCustomCriteria(from source: IndexSet, to destination: Int) {
        preferences.customCriteria.move(fromOffsets: source, toOffset: destination)
        preferences.customCriteria = preferences.customCriteria.enumerated().map { index, criterion in
            copyCriterion(
                criterion,
                title: criterion.title,
                prompt: criterion.prompt,
                order: 10_000 + index
            )
        }
        preferences.updatedAt = .now
    }

    private func copyCriterion(
        _ criterion: SensoryCriterionDefinition,
        title: String,
        prompt: String,
        order: Int
    ) -> SensoryCriterionDefinition {
        SensoryCriterionDefinition(
            id: criterion.id,
            title: title,
            prompt: prompt,
            helper: criterion.helper,
            accessibilityLabel: criterion.accessibilityLabel == criterion.title
                ? title
                : criterion.accessibilityLabel,
            dimension: criterion.dimension,
            stage: criterion.stage,
            measure: criterion.measure,
            scaleID: criterion.scaleID,
            options: criterion.options,
            descriptorRootIDs: criterion.descriptorRootIDs,
            depths: criterion.depths,
            applicability: criterion.applicability,
            evidenceSourceIDs: criterion.evidenceSourceIDs,
            order: order
        )
    }

    private func save() {
        preferences.customCriteria = preferences.customCriteria.enumerated().map { index, criterion in
            let title = criterion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return copyCriterion(
                criterion,
                title: title.isEmpty ? "My criterion" : title,
                prompt: criterion.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                order: 10_000 + index
            )
        }
        preferences.updatedAt = .now
        onSave(preferences)
        dismiss()
    }

    private static let coreCriterionIDs: Set<String> = [
        "criterion.own_words",
        "criterion.flavor.web",
        "criterion.mugsy.leading",
        "criterion.overall.enjoyment"
    ]
}

private extension SensoryMeasureType {
    var displayTitle: String {
        switch self {
        case .ownWords: return "Own words"
        case .presence: return "Presence"
        case .intensity: return "Intensity"
        case .singleChoice: return "One choice"
        case .multipleChoice: return "Multiple choices"
        case .duration: return "Duration"
        case .preference: return "Preference"
        case .confidence: return "Confidence"
        case .qualityImpression: return "Personal style impression"
        case .overallEnjoyment: return "Personal enjoyment"
        }
    }
}

private extension SensoryDimension {
    var displayTitle: String {
        switch self {
        case .identity: return "Drink identity"
        case .appearance: return "Appearance"
        case .aroma: return "Aroma"
        case .taste: return "Taste structure"
        case .flavor: return "Flavor"
        case .body: return "Body"
        case .texture: return "Texture"
        case .astringency: return "Dry grip"
        case .finish: return "Finish"
        case .temperatureChange: return "Temperature change"
        case .integration: return "Integration"
        case .balance: return "Balance"
        case .unexpected: return "Something unexpected"
        case .personalResponse: return "Personal response"
        }
    }

    var defaultStage: SensoryStage {
        switch self {
        case .identity: return .ownWords
        case .appearance: return .appearance
        case .aroma: return .aroma
        case .taste: return .firstSip
        case .flavor: return .flavor
        case .body, .texture, .astringency: return .mouthfeel
        case .finish: return .finish
        case .temperatureChange: return .temperature
        case .integration, .balance, .unexpected: return .structure
        case .personalResponse: return .personal
        }
    }
}
