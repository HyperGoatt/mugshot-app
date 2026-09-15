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
                    } else { Button("Add preparation details") { edit(recipe, version: version) } }
                    Button("Log a make", systemImage: "plus") { onLog(recipe) }
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
                            Text(item.content.summary)
                            Text(item.content.notes)
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
                if !content.summary.isEmpty { Text(content.summary) }
                if let temperature = content.targets.temperature { LabeledContent("Temperature", value: "\(HomeRecipeContent.number(temperature)) °C") }
                if !content.targets.grind.isEmpty { LabeledContent("Grind", value: content.targets.grind) }
                if !content.targets.dilution.isEmpty { LabeledContent("Serving dilution", value: content.targets.dilution) }
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
        if !content.steps.isEmpty {
            Section("Instructions") {
                ForEach(Array(content.steps.enumerated()), id: \.element.id) { index, step in
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

struct HomeAttemptDetailScreen: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let attemptID: UUID
    let onRepeat: (HomeRecipeRecord?, HomeRecipeContent?) -> Void
    let onServing: (HomeAttemptRecord) -> Void
    let onSaveRecipe: (HomeRecipeContent) -> Void
    let onShare: (HomeAttemptRecord) -> Void
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
                        if let image = store.photo(name) { Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16)) }
                    }
                    Text(attempt.rating.map { "\(HomeRecipeContent.number($0)) / 5" } ?? "Unrated")
                    if !attempt.reaction.isEmpty { Text(attempt.reaction) }
                    if !attempt.privateNote.isEmpty { Text(attempt.privateNote) }
                    if let makeAgain = attempt.makeAgain { LabeledContent("Make again", value: makeAgain.title) }
                }
                Section("Recorded measurements") {
                    measurement("Coffee", value: attempt.actuals.dose, target: attempt.targets?.targets.dose, unit: "g")
                    measurement("Yield or water", value: attempt.actuals.output, target: attempt.targets?.targets.resolvedOutput, unit: "g")
                    measurement("Time", value: attempt.actuals.seconds, target: attempt.targets?.targets.seconds, unit: "sec")
                    if !attempt.actuals.dilution.isEmpty { LabeledContent("Serving dilution", value: attempt.actuals.dilution) }
                    if let amount = attempt.actuals.batchMilliliters { LabeledContent("Batch made", value: "\(HomeRecipeContent.number(amount)) ml") }
                    if let amount = attempt.actuals.servingMilliliters { LabeledContent("Serving amount", value: "\(HomeRecipeContent.number(amount)) ml") }
                }
                if !attempt.nextTimeNote.isEmpty { Section("For next time") { Text(attempt.nextTimeNote) } }
                Section {
                    if attempt.preparation?.method == .coldBrew, attempt.batchSourceAttemptID == nil {
                        Button("Log a serving from this batch") { onServing(attempt) }
                    }
                    Button("Make again") { onRepeat(recipe, recipe == nil ? attempt.preparation : nil) }
                        .buttonStyle(.borderedProminent).tint(.mugshotSage)
                    Button("Use this attempt’s setup") { onRepeat(recipe, attempt.recipeCandidate) }
                    Button("Save as recipe") { onSaveRecipe(attempt.recipeCandidate) }
                    Button("Share this make", systemImage: "square.and.arrow.up") { onShare(attempt) }
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
    }
    private func measurement(_ name: String, value: Double?, target: Double?, unit: String) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(name, value: value.map { "\(HomeRecipeContent.number($0)) \(unit)" } ?? "Not recorded")
            if let target { Text("Target: \(HomeRecipeContent.number(target)) \(unit)").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct HomePreparationScreen: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let sessionID: UUID
    let onFinish: (HomeAttemptRecord) -> Void
    @State private var linked: HomeLinkedRecipeSheet?
    @State private var scale: Double = 1
    private var session: HomePreparationSession? { store.workspace.sessions.first { $0.id == sessionID } }

    var body: some View {
        List {
            if let session, let content = session.attempt.preparation {
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
                    if session.stepIndex == 0 {
                        HStack {
                            TextField("Scale", value: $scale, format: .number).keyboardType(.decimalPad)
                            Button("Scale amounts") {
                                guard scale.isFinite, scale > 0 else { return }
                                change { $0.attempt.preparation = content.scaled(by: scale) }
                                scale = 1
                            }
                        }
                    }
                }
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
                                Toggle("Already prepared", isOn: Binding(get: { session.preparedRecipeIDs.contains(reference.recipeID) }, set: { ready in
                                    change { if ready { $0.preparedRecipeIDs.insert(reference.recipeID) } else { $0.preparedRecipeIDs.remove(reference.recipeID) } }
                                }))
                            }
                        }
                    }
                }
                if content.steps.indices.contains(session.stepIndex) {
                    let step = content.steps[session.stepIndex]
                    Section("Step \(session.stepIndex + 1) of \(content.steps.count)") {
                        Text(step.instruction).font(.title3)
                        if let start = step.startSeconds { Text("At \(HomeRecipeContent.number(start)) seconds") }
                        if let water = content.cumulativeWater(through: session.stepIndex) {
                            LabeledContent("Cumulative water", value: "\(HomeRecipeContent.number(water)) g")
                        }
                        if let wait = step.waitSeconds { Text("Wait \(HomeRecipeContent.number(wait)) seconds") }
                        if content.steps.indices.contains(session.stepIndex + 1) {
                            Text("Next: \(content.steps[session.stepIndex + 1].instruction)").font(.caption).foregroundStyle(.secondary)
                            Button("Next step") { change { $0.stepIndex += 1 } }
                        }
                        if session.stepIndex > 0 { Button("Previous step") { change { $0.stepIndex -= 1 } } }
                    }
                }
                Section {
                    Button(content.method == .coldBrew ? "Finish batch" : "Finished") { finish(session, measured: true) }
                        .buttonStyle(.borderedProminent).tint(.mugshotSage)
                    Button("I’ve already made it") { finish(session, measured: false) }
                }
            }
        }.navigationTitle("Make").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(Color.creamWhite)
            .sheet(item: $linked) { item in HomeLinkedRecipeDetail(store: store, reference: item.reference) }
    }
    private func change(_ update: (inout HomePreparationSession) -> Void) {
        guard var value = session else { return }
        update(&value)
        do { try store.saveSession(value) } catch { store.errorMessage = error.localizedDescription }
    }
    private func finish(_ session: HomePreparationSession, measured: Bool) {
        var attempt = session.attempt
        if measured, let start = session.timerStartedAt { attempt.actuals.seconds = max(0, Date.now.timeIntervalSince(start)) }
        if attempt.preparation?.method == .coldBrew { attempt.batchID = session.id }
        onFinish(attempt)
    }
}
