import SwiftUI

struct HomeBrewExperimentSheet: View {
    let attempt: HomeAttemptRecord
    let comparison: HomeAttemptComparison
    let ownerID: UUID?
    let onStart: (HomeBrewExperimentPlan, HomeBrewPlanChange?) -> Bool

    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var permission = CoffeeAssistancePermissionStore.shared
    @StateObject private var session = CoffeeAssistanceSession()
    @State private var selectedIndex = 0
    @State private var requestID: UUID?
    @State private var startError = false

    private var canAskForAnotherIdea: Bool {
        ownerID != nil && (attempt.reaction.remoteTrimmedNonEmpty != nil || attempt.resolvedRating != nil
            || comparison.rows.contains { $0.actual?.amount != nil && $0.actual?.unit.isEmpty == false })
    }

    var body: some View {
        let ideas = HomeBrewExperiment.suggestions(for: attempt, comparison: comparison)
        let selection = ideas[min(selectedIndex, ideas.count - 1)]
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    experimentCard(selection)
                    Button {
                        selectedIndex = (selectedIndex + 1) % ideas.count
                        startError = false
                    } label: {
                        Label("Another idea", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("home.experiment.another")

                    if let ownerID, canAskForAnotherIdea {
                        connectedIdeas(ownerID: ownerID)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("home.experiment.scroll")
            .background(Color.creamWhite)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    if startError {
                        Text("This sip has changed. Open it again to try the latest plan.")
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button {
                        startError = !onStart(selection.plan, selection.change)
                    } label: {
                        Text("Start this experiment").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("home.experiment.start")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .background(Color.creamWhite)
            }
            .navigationTitle("Experiment with Mugsy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .tint(Color.mugshotSageText)
        .task(id: requestID) {
            guard let requestID, let ownerID, canAskForAnotherIdea else { return }
            let request = CoffeeAssistanceRequest(
                ownerID: ownerID, requestID: requestID, task: .brewExperiment,
                query: "Suggest one practical next trial in two short sentences. Give one action and one thing to taste for. Use recorded measurements and feedback where supplied. Label planned amounts as plans. Offer a trial without diagnosing the drink.",
                evidence: comparison.assistanceEvidence(for: attempt)
            )
            await session.run(request, consent: permission.isEnabled(ownerID: ownerID),
                              currentOwner: { authModel.authenticatedUser?.id })
        }
        .onChange(of: permission.revision) { _, _ in
            if !permission.isEnabled(ownerID: ownerID) { requestID = nil; session.invalidate() }
        }
        .onChange(of: authModel.authenticatedUser?.id) { _, current in
            if current != ownerID { requestID = nil; session.invalidate(); dismiss() }
        }
        .onDisappear { session.invalidate() }
    }

    private var introduction: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        return layout {
            MugsyModelView(configuration: MugsySceneResolver.scene(for: .coffeeRitual,
                stableID: attempt.id.uuidString).configuration)
                .frame(width: 78, height: 78)
                .background(Color.mugshotMint.opacity(0.33), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your next experiment")
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.espressoBrown)
                    .accessibilityAddTraits(.isHeader)
                Text(attempt.name)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func experimentCard(_ idea: HomeBrewExperiment) -> some View {
        HomeEditorSection(idea.plan.title, symbol: "sparkles") {
            Text(idea.plan.instruction)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("home.experiment.instruction")
            if let measurement = idea.measurement {
                VStack(alignment: .leading, spacing: 7) {
                    LabeledContent(measurement.source, value: measurement.before)
                    LabeledContent("Next target", value: measurement.next)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.mugshotSageText)
                }
                .font(.subheadline)
                .padding(12)
                .background(Color.sandBeige.opacity(0.44), in: .rect(cornerRadius: 12))
            }
            if let tasteFor = idea.plan.tasteFor {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Taste for", systemImage: "cup.and.saucer")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.mugshotSageText)
                    Text(tasteFor).font(.subheadline).foregroundStyle(Color.secondaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func connectedIdeas(ownerID: UUID) -> some View {
        HomeEditorSection("More from Mugsy", symbol: "sparkles") {
            DisclosureGroup("Ask for another suggestion") {
                VStack(alignment: .leading, spacing: 12) {
                    DisclosureGroup("Details sent to OpenAI") {
                        ForEach(comparison.assistanceEvidence(for: attempt)) { evidence in
                            Text(evidence.title).font(.footnote.weight(.semibold))
                            Text(evidence.detail).font(.footnote).foregroundStyle(Color.secondaryText)
                        }
                    }
                    if permission.isEnabled(ownerID: ownerID) {
                        if let result = session.result {
                            Text(result.text).fixedSize(horizontal: false, vertical: true)
                            Button("Start with this suggestion") {
                                let plan = HomeBrewExperimentPlan(title: "Mugsy’s suggestion", instruction: result.text, tasteFor: nil)
                                startError = !onStart(plan, nil)
                            }
                            .frame(minHeight: 44)
                        } else {
                            if let message = session.message { Text(message).font(.subheadline).foregroundStyle(Color.secondaryText) }
                            Button {
                                requestID = UUID()
                            } label: {
                                if session.isWorking { ProgressView("Asking Mugsy…") }
                                else { Text(session.message == nil ? "Ask Mugsy" : "Try again") }
                            }
                            .frame(minHeight: 44)
                            .disabled(session.isWorking || authModel.authenticatedUser?.id != ownerID)
                            .accessibilityIdentifier("home.experiment.ask")
                        }
                    } else {
                        MugsyPermissionControl(ownerID: ownerID)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

struct HomeBrewExperimentDraftCard: View {
    let plan: HomeBrewExperimentPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Mugsy’s experiment", systemImage: "sparkles")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.mugshotSageText)
            Text(plan.title).font(.headline).foregroundStyle(Color.espressoBrown)
            Text(plan.instruction).font(.subheadline).foregroundStyle(Color.secondaryText)
            if let tasteFor = plan.tasteFor {
                Text(tasteFor).font(.subheadline).foregroundStyle(Color.secondaryText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.mugshotMint.opacity(0.20), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.experiment.draft")
    }
}
