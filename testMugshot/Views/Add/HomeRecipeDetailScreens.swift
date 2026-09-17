import SwiftUI

struct HomeRecipeDetailScreen: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let recipeID: UUID
    let onEdit: (HomeRecipeEditorDraft) -> Void
    let onLog: (HomeRecipeRecord) -> Void
    let onMake: (HomeRecipeRecord) -> Void
    let onAttempt: (UUID) -> Void
    @State private var linked: HomeLinkedRecipeSheet?
    private var recipe: HomeRecipeRecord? { store.workspace.recipes.first { $0.id == recipeID } }

    var body: some View {
        List {
            if let recipe, let version = recipe.current {
                Section {
                    HomeRecipeRow(content: version.content)
                    Text("Your recipe · Version \(version.number)").font(.caption).foregroundStyle(.secondary)
                    if version.content.isActionable {
                        Button("Make this", systemImage: "play.fill") { onMake(recipe) }
                            .buttonStyle(.borderedProminent).tint(.mugshotSage)
                            .accessibilityIdentifier("home.recipe.make")
                    } else { Button("Add preparation details") { edit(recipe, version: version) } }
                    Button("Log a make", systemImage: "plus") { onLog(recipe) }
                        .accessibilityIdentifier("home.recipe.log")
                }
                if !recipe.nextTimeNote.isEmpty {
                    Section("For next time") {
                        Text(recipe.nextTimeNote)
                        Button("Mark addressed") { change { $0.nextTimeNote = "" } }
                    }
                }
                HomeRecipeInformation(content: version.content) { reference in
                    linked = HomeLinkedRecipeSheet(reference: reference)
                }
                Section("Your recipe") {
                    Button("Edit recipe") { edit(recipe, version: version) }
                    Button(recipe.isPinned ? "Remove from usuals" : "Pin to usuals", systemImage: "pin") { change { $0.isPinned.toggle() } }
                    Button(recipe.isArchived ? "Restore recipe" : "Archive recipe") { change { $0.isArchived.toggle() } }
                }
                Section("Attempts") {
                    let attempts = store.workspace.attempts.filter { $0.recipe?.recipeID == recipeID }.sorted { $0.createdAt > $1.createdAt }
                    if attempts.isEmpty { Text("Your first make starts here.").foregroundStyle(.secondary) }
                    ForEach(attempts) { attempt in
                        Button {
                            onAttempt(attempt.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(attempt.name)
                                Text(attempt.createdAt, style: .date).font(.caption)
                                if let rating = attempt.rating { Text("\(HomeRecipeContent.number(rating)) / 5").font(.caption) }
                                if recipe.favoriteAttemptID == attempt.id { Label("Favorite result", systemImage: "star.fill").font(.caption) }
                            }
                        }
                    }
                }
                Section("Versions") {
                    ForEach(recipe.versions.reversed()) { item in
                        DisclosureGroup("Version \(item.number) · \(item.createdAt.formatted(date: .abbreviated, time: .omitted))") {
                            HomeRecipeVersionSummary(content: item.content)
                        }
                    }
                }
            } else { ContentUnavailableView("Recipe unavailable", systemImage: "book.closed") }
        }
        .navigationTitle(recipe?.current?.content.name ?? "Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(Color.creamWhite)
        .sheet(item: $linked) { item in
            HomeLinkedRecipeDetail(store: store, reference: item.reference)
        }
    }
    private func edit(_ recipe: HomeRecipeRecord, version: HomeRecipeVersion) {
        onEdit(HomeRecipeEditorDraft(recipeID: recipe.id, baseVersionID: version.id, content: version.content))
    }
    private func change(_ update: (inout HomeRecipeRecord) -> Void) {
        do {
            try store.mutate { state in
                if let index = state.recipes.firstIndex(where: { $0.id == recipeID }) { update(&state.recipes[index]) }
            }
        } catch { store.errorMessage = error.localizedDescription }
    }
}

private struct HomeRecipeVersionSummary: View {
    let content: HomeRecipeContent
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content.template.title).font(.caption).foregroundStyle(.secondary)
            if !content.summary.isEmpty { Text(content.summary) }
            ForEach(content.ingredients) { ingredient in
                HStack {
                    Text(ingredient.name)
                    Spacer()
                    Text([ingredient.amount.map(HomeRecipeContent.number) ?? "", ingredient.unit]
                        .filter { !$0.isEmpty }.joined(separator: " "))
                        .foregroundStyle(.secondary)
                }.font(.caption)
            }
            ForEach(Array(content.visibleSteps.enumerated()), id: \.element.id) { index, step in
                Text("\(index + 1). \(step.instruction)").font(.caption)
            }
            ForEach(content.fields.filter(\.isVisible)) { field in
                LabeledContent(field.label, value: [field.value, field.unit].filter { !$0.isEmpty }.joined(separator: " "))
                    .font(.caption)
            }
            if !content.notes.isEmpty { Text(content.notes).font(.caption) }
        }
    }
}

struct HomeLinkedRecipeSheet: Identifiable {
    let reference: HomeRecipeReference
    var id: UUID { reference.versionID }
}

struct HomeLinkedRecipeDetail: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let reference: HomeRecipeReference
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if let version = store.workspace.version(reference) {
                    HomeRecipeRow(content: version.content)
                    Text("Version \(version.number)").font(.caption)
                    HomeRecipeInformation(content: version.content, onLinked: nil)
                } else { Text("This version is unavailable. Your parent recipe is unchanged.") }
            }
            .navigationTitle("Linked recipe")
            .toolbar { Button("Done") { dismiss() } }
            .scrollContentBackground(.hidden).background(Color.creamWhite)
        }
    }
}

struct HomeRecipeInformation: View {
    let content: HomeRecipeContent
    var onLinked: ((HomeRecipeReference) -> Void)?
    var body: some View {
        if content.template == .coffee {
            Section("Preparation targets") {
                Text(content.method.title)
                if content.metricConfiguration != nil {
                    HomeConfiguredTargetSummary(content: content)
                } else {
                    if !content.summary.isEmpty { Text(content.summary) }
                    if let temperature = content.targets.temperature { LabeledContent("Temperature", value: "\(HomeRecipeContent.number(temperature)) °C") }
                    if !content.targets.grind.isEmpty { LabeledContent("Grind", value: content.targets.grind) }
                    if !content.targets.dilution.isEmpty { LabeledContent("Serving dilution", value: content.targets.dilution) }
                }
                if let coffee = content.coffee?.displayName { Text(coffee) }
                ForEach(content.equipment) { Text($0.displayName) }
            }
        }
        if !content.ingredients.isEmpty {
            Section("Ingredients") {
                ForEach(content.ingredients) { ingredient in
                    HStack {
                        if let reference = ingredient.recipe, let onLinked {
                            Button(ingredient.name) { onLinked(reference) }
                        } else { Text(ingredient.name) }
                        Spacer()
                        Text(ingredient.amount.map { "\(HomeRecipeContent.number($0)) \(ingredient.unit)" } ?? ingredient.unit)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        if !content.visibleSteps.isEmpty {
            Section("Instructions") {
                ForEach(Array(content.visibleSteps.enumerated()), id: \.element.id) { index, step in
                    VStack(alignment: .leading) {
                        Text("\(index + 1). \(step.instruction)")
                        if let water = step.waterGrams { Text("\(step.waterMode.title): \(HomeRecipeContent.number(water)) g").font(.caption) }
                        if let time = step.startSeconds { Text("At \(HomeRecipeContent.number(time)) seconds").font(.caption) }
                        if let wait = step.waitSeconds { Text("Wait \(HomeRecipeContent.number(wait)) seconds").font(.caption) }
                    }
                }
            }
        }
        if !content.fields.filter(\.isVisible).isEmpty {
            Section("Details") {
                ForEach(content.fields.filter(\.isVisible)) { field in
                    LabeledContent(field.label, value: [field.value, field.unit].filter { !$0.isEmpty }.joined(separator: " "))
                }
            }
        }
        if !content.notes.isEmpty { Section("Preparation notes") { Text(content.notes) } }
        if !content.sourceURL.isEmpty || !content.creatorCredit.isEmpty {
            Section("Inspiration") {
                Text(content.creatorCredit)
                if let url = URL(string: content.sourceURL), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    Link(content.sourceURL, destination: url)
                } else { Text(content.sourceURL).textSelection(.enabled) }
            }
        }
    }
}

private struct HomeConfiguredTargetSummary: View {
    let content: HomeRecipeContent
    var body: some View {
        ForEach(content.configuredMetrics.filter(\.isVisible)) { field in
            let title = field.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? field.metric.label : field.label
            if field.metric == .output, let value = content.targets.resolvedOutput {
                LabeledContent(title, value: HomeRecipeContent.number(value))
            } else if let keyPath = field.metric.numericKeyPath, let value = content.targets[keyPath: keyPath] {
                LabeledContent(title, value: HomeRecipeContent.number(value))
            } else if field.metric == .grind, !content.targets.grind.isEmpty {
                LabeledContent(title, value: content.targets.grind)
            } else if field.metric == .dilution, !content.targets.dilution.isEmpty {
                LabeledContent(title, value: content.targets.dilution)
            }
        }
    }
}

struct HomeAttemptDetailScreen: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let attemptID: UUID
    let onRepeat: (HomeRecipeRecord?, HomeRecipeContent?) -> Void
    let onServing: (HomeAttemptRecord) -> Void
    let onSaveRecipe: (HomeRecipeContent) -> Void
    let onShare: (HomeAttemptRecord) -> Void
    @State private var comparison: HomeAttemptRecord?
    private var attempt: HomeAttemptRecord? { store.workspace.attempts.first { $0.id == attemptID } }
    private var recipe: HomeRecipeRecord? { store.workspace.recipes.first { $0.id == attempt?.recipe?.recipeID } }

    var body: some View {
        List {
            if let attempt {
                Section {
                    Label("Saved privately", systemImage: "checkmark.circle.fill").foregroundStyle(Color.mugshotSage)
                    Text(attempt.name).font(.title2).fontDesign(.serif)
                    Text(attempt.createdAt, style: .date).font(.caption)
                    ForEach(attempt.photoNames, id: \.self) { name in
                        if let image = store.photo(name) {
                            Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                                .accessibilityLabel("Photo of this make")
                        } else {
                            Label("Photo unavailable on this device", systemImage: "photo.badge.exclamationmark")
                                .foregroundStyle(.secondary)
                            Button("Retry photo sync") { Task { await store.synchronize() } }
                        }
                    }
                    Text(attempt.rating.map { "\(HomeRecipeContent.number($0)) / 5" } ?? "Unrated")
                    if !attempt.reaction.isEmpty { Text(attempt.reaction) }
                    if !attempt.privateNote.isEmpty { Text(attempt.privateNote) }
                    if let makeAgain = attempt.makeAgain { LabeledContent("Make again", value: makeAgain.title) }
                }
                Section("Recorded measurements") {
                    if attempt.preparation == nil || attempt.preparation?.template == .coffee {
                        measurement("Coffee", value: attempt.actuals.dose, target: attempt.plannedTargets?.dose, unit: "g")
                        measurement("Yield or water", value: attempt.actuals.output, target: attempt.plannedTargets?.resolvedOutput, unit: "g")
                    }
                    measurement("Time", value: attempt.actuals.seconds,
                        target: attempt.plannedTargets?.seconds ?? attempt.plannedTargets?.steepSeconds, unit: "sec")
                    measurement("Temperature", value: attempt.actuals.temperature, target: attempt.plannedTargets?.temperature, unit: "°C")
                    LabeledContent("Grind", value: attempt.actuals.grind.isEmpty ? "Not recorded" : attempt.actuals.grind)
                    if !attempt.actuals.dilution.isEmpty { LabeledContent("Serving dilution", value: attempt.actuals.dilution) }
                    if let amount = attempt.actuals.batchMilliliters { LabeledContent("Batch made", value: "\(HomeRecipeContent.number(amount)) ml") }
                    if let amount = attempt.actuals.servingMilliliters { LabeledContent("Serving amount", value: "\(HomeRecipeContent.number(amount)) ml") }
                }
                if !attempt.nextTimeNote.isEmpty { Section("For next time") { Text(attempt.nextTimeNote) } }
                if let reference = attempt.recipe {
                    let others = store.workspace.attempts.filter { $0.id != attempt.id && $0.recipe?.recipeID == reference.recipeID }
                        .sorted { $0.createdAt > $1.createdAt }
                    if !others.isEmpty {
                        Section("Compare results") {
                            Menu("Compare with another make") {
                                ForEach(others) { other in
                                    Button("\(other.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(other.rating.map { HomeRecipeContent.number($0) + " / 5" } ?? "Unrated")") {
                                        comparison = other
                                    }
                                }
                            }
                        }
                    }
                }
                Section {
                    if attempt.preparation?.method == .coldBrew, attempt.batchSourceAttemptID == nil {
                        Button("Log a serving from this batch") { onServing(attempt) }
                    }
                    Button("Make again") { onRepeat(recipe, recipe == nil ? attempt.preparation : nil) }
                        .buttonStyle(.borderedProminent).tint(.mugshotSage)
                    Button("Use this attempt’s setup") { onRepeat(recipe, attempt.recipeCandidate) }
                    Button("Save as recipe") { onSaveRecipe(attempt.recipeCandidate) }
                    if attempt.publicationStatus == .published {
                        Label("Published", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.mugshotSage)
                    } else {
                        Button("Share this make", systemImage: "square.and.arrow.up") { onShare(attempt) }
                    }
                    if attempt.publicationStatus == .failed {
                        Label("Your post draft is saved and ready to retry.", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let recipe {
                        Button(recipe.favoriteAttemptID == attemptID ? "Unpin favorite result" : "Pin favorite result") {
                            do {
                                try store.mutate { state in
                                    if let index = state.recipes.firstIndex(where: { $0.id == recipe.id }) {
                                        state.recipes[index].favoriteAttemptID = recipe.favoriteAttemptID == attemptID ? nil : attemptID
                                    }
                                }
                            } catch { store.errorMessage = error.localizedDescription }
                        }
                    }
                }
            }
        }.navigationTitle("My make").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(Color.creamWhite)
            .sheet(item: $comparison) { other in
                if let attempt { HomeAttemptComparisonScreen(current: attempt, previous: other) }
            }
    }
    private func measurement(_ name: String, value: Double?, target: Double?, unit: String) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(name, value: value.map { "\(HomeRecipeContent.number($0)) \(unit)" } ?? "Not recorded")
            if let target { Text("Target: \(HomeRecipeContent.number(target)) \(unit)").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

/// Each side describes observations, not inferred causes or missing measurements.
private struct HomeAttemptComparisonScreen: View {
    let current: HomeAttemptRecord
    let previous: HomeAttemptRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Compare what you recorded. Different beans, equipment, or preparation can change the result; this comparison does not identify the cause.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                result(current, title: "This make")
                result(previous, title: "Compared make")
            }
            .navigationTitle("Compare makes").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .scrollContentBackground(.hidden).background(Color.creamWhite)
        }
    }

    private func result(_ attempt: HomeAttemptRecord, title: String) -> some View {
        Section(title) {
            Text(attempt.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.headline)
            LabeledContent("Rating", value: attempt.rating.map { "\(HomeRecipeContent.number($0)) / 5" } ?? "Unrated")
            if !attempt.reaction.isEmpty { LabeledContent("Reaction", value: attempt.reaction) }
            let preparation = attempt.preparation ?? attempt.targets
            if preparation?.template == .coffee {
                metric("Coffee", attempt.actuals.dose, "g")
                metric(preparation?.method == .espresso ? "Beverage yield" : "Water", attempt.actuals.output, "g")
                metric("Time", attempt.actuals.seconds, "sec")
                metric("Temperature", attempt.actuals.temperature, "°C")
                LabeledContent("Grind", value: attempt.actuals.grind.isEmpty ? "Not recorded" : attempt.actuals.grind)
                LabeledContent("Beans", value: preparation?.coffee?.displayName ?? "Not recorded")
                LabeledContent("Equipment", value: preparation?.equipment.map(\.displayName).joined(separator: ", ").nonemptyComparisonValue ?? "Not recorded")
            }
            if attempt.actuals.servingMilliliters != nil { metric("Serving", attempt.actuals.servingMilliliters, "ml") }
            if !attempt.actuals.dilution.isEmpty { LabeledContent("Dilution", value: attempt.actuals.dilution) }
            if !attempt.privateNote.isEmpty { Text(attempt.privateNote) }
        }
    }

    private func metric(_ title: String, _ value: Double?, _ unit: String) -> some View {
        LabeledContent(title, value: value.map { "\(HomeRecipeContent.number($0)) \(unit)" } ?? "Not recorded")
    }
}

private extension String {
    var nonemptyComparisonValue: String? { isEmpty ? nil : self }
}

struct HomePreparationScreen: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let sessionID: UUID
    let onFinish: (HomeAttemptRecord) -> Void
    var onDiscard: () -> Void = {}
    var onKeep: () -> Void = {}
    @State private var linked: HomeLinkedRecipeSheet?
    @State private var preparingLinked: HomeLinkedRecipeSheet?
    @State private var scale: Double = 1
    @State private var scalingBasis = "Multiplier"
    @State private var scalingError: String?
    @Environment(\.scenePhase) private var scenePhase
    @State private var authorizedContent: HomeRecipeContent?
    @State private var sourceError: String?
    @State private var confirmsDiscard = false
    private var session: HomePreparationSession? { store.workspace.sessions.first { $0.id == sessionID } }

    var body: some View {
        List {
            if let session, let content = session.attempt.preparation ?? authorizedContent {
                Section {
                    HomeRecipeRow(content: content)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Duration.seconds(session.timerStartedAt.map { max(0, context.date.timeIntervalSince($0)) }
                                ?? (content.method == .coldBrew ? session.elapsed(at: context.date) : 0)).formatted(.time(pattern: .hourMinuteSecond)))
                                .font(.largeTitle.monospacedDigit()).accessibilityLabel("Elapsed time")
                            if let readyAt = session.readyAt {
                                Text("Ready around \(readyAt.formatted(date: .abbreviated, time: .shortened))")
                            }
                        }
                    }
                    if content.method != .coldBrew {
                        Button(session.timerStartedAt == nil ? "Start timer" : "Restart timer") {
                            change { $0.timerStartedAt = .now }
                        }
                    }
                    if session.readyAt != nil {
                        Button(session.reminderEnabled ? "Cancel reminder" : "Set a reminder") {
                            Task {
                                do { try await store.setReminder(for: session, enabled: !session.reminderEnabled) }
                                catch { store.errorMessage = error.localizedDescription }
                            }
                        }
                    }
                    if session.stepIndex == 0, session.attempt.preparation != nil {
                        Picker("Scale by", selection: $scalingBasis) {
                            Text("Multiplier").tag("Multiplier")
                            Text("Servings").tag("Servings")
                            if content.targets.dose != nil { Text("Coffee dose").tag("Coffee dose") }
                        }
                        HStack {
                            TextField(scalingBasis == "Coffee dose" ? "Coffee dose (g)" : scalingBasis, value: $scale, format: .number)
                                .keyboardType(.decimalPad).accessibilityLabel(scalingBasis)
                            Button("Scale amounts") {
                                let divisor = scalingBasis == "Servings" ? content.servings
                                    : scalingBasis == "Coffee dose" ? (content.targets.dose ?? 0) : 1
                                guard scale.isFinite, scale > 0, divisor.isFinite, divisor > 0 else {
                                    scalingError = "Enter a positive amount to scale this recipe."
                                    return
                                }
                                change { $0.attempt.preparation = content.scaled(by: scale / divisor) }
                                scalingError = nil
                                scalingBasis = "Multiplier"
                                scale = 1
                            }
                        }
                        if let scalingError { Text(scalingError).font(.footnote).foregroundStyle(.red) }
                    }
                }
                if content.template == .coffee {
                    Section("Targets") {
                        if let dose = content.targets.dose {
                            LabeledContent("Coffee", value: "\(HomeRecipeContent.number(dose)) g")
                        }
                        if let output = content.targets.resolvedOutput {
                            LabeledContent(content.method == .espresso ? "Yield" : "Water",
                                value: "\(HomeRecipeContent.number(output)) g")
                        }
                        if let ratio = content.targets.resolvedRatio {
                            LabeledContent("Ratio", value: "1:\(HomeRecipeContent.number(ratio))")
                        }
                        if let seconds = content.targets.seconds {
                            LabeledContent("Target time", value: HomeRecipeContent.durationSummary(seconds))
                        }
                        if let steep = content.targets.steepSeconds {
                            LabeledContent("Steep", value: HomeRecipeContent.durationSummary(steep))
                        }
                        if !content.targets.grind.isEmpty { LabeledContent("Grind", value: content.targets.grind) }
                        if let temperature = content.targets.temperature {
                            LabeledContent("Temperature", value: "\(HomeRecipeContent.number(temperature)) °C")
                        }
                        if !content.targets.dilution.isEmpty {
                            LabeledContent("Serving dilution", value: content.targets.dilution)
                        }
                    }
                }
                let visibleFields = content.fields.filter(\.isVisible)
                if !visibleFields.isEmpty {
                    Section("Recipe details") {
                        ForEach(visibleFields) { field in
                            LabeledContent(field.label.isEmpty ? "Detail" : field.label,
                                value: field.value.isEmpty ? "Not set" : [field.value, field.unit].filter { !$0.isEmpty }.joined(separator: " "))
                        }
                    }
                }
                if !content.notes.isEmpty { Section("Preparation notes") { Text(content.notes) } }
                if !content.ingredients.isEmpty {
                    Section("Ingredients") {
                        ForEach(content.ingredients) { item in
                            Toggle(isOn: Binding(get: { session.completedIngredientIDs.contains(item.id) }, set: { checked in
                                change { if checked { $0.completedIngredientIDs.insert(item.id) } else { $0.completedIngredientIDs.remove(item.id) } }
                            })) {
                                Text("\(item.name) · \(item.amount.map(HomeRecipeContent.number) ?? "") \(item.unit)")
                            }
                            if let reference = item.recipe {
                                Button("View \(item.name)") { linked = HomeLinkedRecipeSheet(reference: reference) }
                                Toggle("Already prepared", isOn: Binding(get: {
                                    session.linkedPreparations?.first { $0.reference == reference }?.completedAt != nil
                                }, set: { ready in
                                    change {
                                        var progress = $0.linkedPreparations ?? []
                                        progress.removeAll { $0.reference == reference }
                                        progress.append(HomeLinkedPreparationProgress(reference: reference, completedAt: ready ? .now : nil))
                                        $0.linkedPreparations = progress
                                    }
                                }))
                                Button("Prepare \(item.name)") { preparingLinked = HomeLinkedRecipeSheet(reference: reference) }
                            }
                        }
                    }
                }
                if content.visibleSteps.indices.contains(session.stepIndex) {
                    let step = content.visibleSteps[session.stepIndex]
                    Section("Step \(session.stepIndex + 1) of \(content.visibleSteps.count)") {
                        Text(step.instruction).font(.title3)
                        if let start = step.startSeconds { Text("At \(HomeRecipeContent.number(start)) seconds") }
                        if let water = content.cumulativeWater(through: session.stepIndex) {
                            LabeledContent("Cumulative water", value: "\(HomeRecipeContent.number(water)) g")
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Cumulative water")
                                .accessibilityValue("\(HomeRecipeContent.number(water)) grams")
                                .accessibilityIdentifier("home.make.cumulative-water")
                        }
                        if let wait = step.waitSeconds { Text("Wait \(HomeRecipeContent.number(wait)) seconds") }
                        if content.visibleSteps.indices.contains(session.stepIndex + 1) {
                            Text("Next: \(content.visibleSteps[session.stepIndex + 1].instruction)").font(.caption).foregroundStyle(.secondary)
                            Button("Next step") { change { $0.stepIndex += 1 } }
                                .accessibilityIdentifier("home.make.next")
                        }
                        if session.stepIndex > 0 { Button("Previous step") { change { $0.stepIndex -= 1 } } }
                    }
                }
                Section {
                    Button(content.method == .coldBrew ? "Finish batch" : "Finished") { finish(session, measured: true) }
                        .buttonStyle(.borderedProminent).tint(.mugshotSage)
                        .accessibilityIdentifier("home.make.finish")
                    Button("I’ve already made it") { finish(session, measured: false) }
                }
            } else if let session {
                Section {
                    Text(sourceError ?? "Opening the original recipe…")
                    Button("Log without instructions") { finish(session, measured: false) }
                }
            }
            if let error = store.errorMessage { Text(error).font(.footnote).foregroundStyle(.red) }
        }.navigationTitle("Make").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { confirmsDiscard = true }
                }
            }
            .confirmationDialog("Discard this preparation?", isPresented: $confirmsDiscard) {
                Button("Keep for later", action: onKeep)
                Button("Discard preparation", role: .destructive, action: onDiscard)
                Button("Continue making", role: .cancel) { }
            } message: {
                Text("Discard removes this unfinished session. The saved recipe is unchanged.")
            }
            .scrollContentBackground(.hidden).background(Color.creamWhite)
            .sheet(item: $linked) { item in HomeLinkedRecipeDetail(store: store, reference: item.reference) }
            .sheet(item: $preparingLinked) { item in
                HomeLinkedPreparationScreen(store: store, parentSessionID: sessionID, reference: item.reference)
            }
            .task(id: scenePhase) {
                // No-copy instructions remain in memory only and are authorized
                // again after backgrounding; durable progress contains no source text.
                guard session?.attempt.preparation == nil else { return }
                authorizedContent = nil
                guard scenePhase == .active, let reference = session?.attempt.recipe else { return }
                let scope = store.scope
                do {
                    let client = try SupabaseClientProvider.shared.client()
                    let content = try await HomeRecipeWorkspaceService(client: client).content(versionID: reference.versionID)
                    guard store.scope == scope, !Task.isCancelled else { return }
                    authorizedContent = content
                    sourceError = content == nil ? "Preparation details are unavailable. You can still log your result." : nil
                } catch {
                    guard store.scope == scope, !Task.isCancelled else { return }
                    sourceError = "The original recipe is private, removed, or offline. Your progress is saved."
                }
            }
    }
    private func change(_ update: (inout HomePreparationSession) -> Void) {
        guard var value = session else { return }
        update(&value)
        do { try store.saveSession(value) } catch { store.errorMessage = error.localizedDescription }
    }
    private func finish(_ session: HomePreparationSession, measured: Bool) {
        do {
            let method = (session.attempt.preparation ?? authorizedContent)?.method
            // A cold-brew finish records the durable end timestamp, but elapsed
            // time remains an optional actual instead of being silently asserted.
            let recordsTimerActual = measured && method != .coldBrew
            let attempt = try store.finishPreparation(sessionID: session.id,
                measuredTimer: recordsTimerActual, content: authorizedContent)
            onFinish(attempt)
        } catch { store.errorMessage = error.localizedDescription }
    }
}

private struct HomeLinkedPreparationScreen: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let parentSessionID: UUID
    let reference: HomeRecipeReference
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    private var progress: HomeLinkedPreparationProgress {
        store.workspace.sessions.first { $0.id == parentSessionID }?.linkedPreparations?
            .first { $0.reference == reference } ?? HomeLinkedPreparationProgress(reference: reference)
    }

    var body: some View {
        NavigationStack {
            List {
                if let content = store.workspace.version(reference)?.content {
                    Section {
                        HomeRecipeRow(content: content)
                        Text("This prepares a component for your drink. It does not create a separate journal entry.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if let startedAt = progress.startedAt {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(Duration.seconds(max(0, (progress.completedAt ?? context.date).timeIntervalSince(startedAt))).formatted(.time(pattern: .hourMinuteSecond)))
                                    .font(.title.monospacedDigit())
                            }
                        }
                        Button(progress.startedAt == nil ? "Start timer" : "Restart timer") { update { $0.startedAt = .now; $0.completedAt = nil } }
                    }
                    HomeRecipeInformation(content: content, onLinked: nil)
                    if content.visibleSteps.indices.contains(progress.stepIndex) {
                        Section("Current step") {
                            Text(content.visibleSteps[progress.stepIndex].instruction).font(.headline)
                            if let water = content.cumulativeWater(through: progress.stepIndex) {
                                LabeledContent("Cumulative water", value: "\(HomeRecipeContent.number(water)) g")
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Cumulative water")
                                    .accessibilityValue("\(HomeRecipeContent.number(water)) grams")
                                    .accessibilityIdentifier("home.make.component.cumulative-water")
                            }
                            if progress.stepIndex + 1 < content.visibleSteps.count {
                                Button("Next step") { update { $0.stepIndex += 1 } }
                            }
                            if progress.stepIndex > 0 { Button("Previous step") { update { $0.stepIndex -= 1 } } }
                        }
                    }
                    Section {
                        Button("Ready for my drink") {
                            if update({ $0.completedAt = .now }) { dismiss() }
                        }.buttonStyle(.borderedProminent).tint(.mugshotSage)
                    }
                } else { Text("This linked version is unavailable. Your drink progress is saved.") }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Prepare component").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Close") { dismiss() } }
            .scrollContentBackground(.hidden).background(Color.creamWhite)
        }
    }

    @discardableResult private func update(_ change: (inout HomeLinkedPreparationProgress) -> Void) -> Bool {
        do {
            try store.mutate { state in
                guard let index = state.sessions.firstIndex(where: { $0.id == parentSessionID }) else {
                    throw HomeRecipeWorkspaceError.unavailableReference
                }
                var value = progress
                change(&value)
                var all = state.sessions[index].linkedPreparations ?? []
                all.removeAll { $0.reference == reference }
                all.append(value)
                state.sessions[index].linkedPreparations = all
            }
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
}
