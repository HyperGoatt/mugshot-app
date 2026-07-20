#if DEBUG
import SwiftUI

struct LogASipV3LabView: View {
    @State private var draft = V3LabDraft.fixture
    @State private var step: V3LabStep = .setup
    @State private var presentedSheet: V3LabSheet?
    @State private var sipCoachIndex = 0
    @State private var contextCoachIndex = 0
    @State private var flavorDepth = 0
    @State private var newCriterionName = ""

    var body: some View {
        ZStack {
            Color.creamWhite.ignoresSafeArea()
            currentScreen
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .foregroundStyle(Color.espressoBrown)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(V3LabStep.allCases) { destination in
                        Button {
                            move(to: destination)
                        } label: {
                            Label(destination.title, systemImage: destination == step ? "checkmark" : stepIcon(destination))
                        }
                    }

                    Divider()

                    Button("Reset fixture", systemImage: "arrow.counterclockwise") {
                        withAnimation(DesignSystem.Motion.base) {
                            draft = .fixture
                            step = .setup
                        }
                    }
                } label: {
                    Text("\(step.rawValue + 1) of \(V3LabStep.allCases.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                }
                .accessibilityLabel("UI Lab step \(step.rawValue + 1) of \(V3LabStep.allCases.count)")
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            sheetContent(sheet)
                .presentationDetents(sheet.detents)
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.creamWhite)
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch step {
        case .setup:
            V3LabSetupScreen(
                draft: $draft,
                onAddPhoto: { presentedSheet = .photo },
                onContinue: { move(to: .sip) }
            )
        case .sip:
            V3LabSipScreen(
                draft: $draft,
                onEditSetup: { move(to: .setup) },
                onCoach: { presentedSheet = .coach(.sip) },
                onExploreFlavors: { presentedSheet = .flavors },
                onAddOwn: {
                    newCriterionName = ""
                    presentedSheet = .addCriterion(.sip)
                },
                onContinue: { move(to: .context) }
            )
        case .context:
            V3LabContextScreen(
                draft: $draft,
                onCoach: { presentedSheet = .coach(.context) },
                onAddOwn: {
                    newCriterionName = ""
                    presentedSheet = .addCriterion(.context)
                },
                onContinue: { move(to: .publish) }
            )
        case .publish:
            V3LabPublishScreen(
                draft: $draft,
                onInviteFriends: { presentedSheet = .inviteFriends },
                onPublish: { move(to: .passport) }
            )
        case .passport:
            V3LabTastePassportScreen(
                draft: draft,
                onWhy: { presentedSheet = .passportWhy },
                onStartAnother: {
                    withAnimation(DesignSystem.Motion.base) {
                        draft = .fixture
                        step = .setup
                    }
                }
            )
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: V3LabSheet) -> some View {
        switch sheet {
        case .photo:
            V3LabPhotoOptionsSheet(usesPlaceholder: $draft.didUsePlaceholder)
        case .coach(let target):
            if target == .sip {
                V3LabCoachSheet(
                    title: "Taste with Mugsy",
                    prompts: V3LabCoachPrompt.sip,
                    index: $sipCoachIndex
                )
            } else {
                V3LabCoachSheet(
                    title: draft.context == .home ? "Experiment with Mugsy" : "Notice the setting",
                    prompts: V3LabCoachPrompt.forContext(draft.context),
                    index: $contextCoachIndex
                )
            }
        case .flavors:
            V3LabFlavorExplorerSheet(depth: $flavorDepth)
        case .addCriterion(let target):
            V3LabAddCriterionSheet(
                name: $newCriterionName,
                target: target,
                onAdd: { addCustomCriterion(to: target) }
            )
        case .inviteFriends:
            V3LabFriendPickerSheet(selectedCount: $draft.invitedFriendCount)
        case .passportWhy:
            V3LabPassportWhySheet()
        }
    }

    private func move(to destination: V3LabStep) {
        withAnimation(DesignSystem.Motion.slow) {
            step = destination
        }
    }

    private func addCustomCriterion(to target: V3LabCriterionTarget) {
        let trimmed = newCriterionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let criterion = V3LabCriterion(
            id: "custom-\(UUID().uuidString)",
            title: trimmed,
            systemImage: "slider.horizontal.3",
            rating: 0,
            importance: .normal,
            isPinned: false
        )

        switch target {
        case .sip: draft.sipCriteria.append(criterion)
        case .context: draft.contextCriteria.append(criterion)
        }
        presentedSheet = nil
    }

    private func stepIcon(_ step: V3LabStep) -> String {
        switch step {
        case .setup: return "photo"
        case .sip: return "cup.and.saucer"
        case .context: return "storefront"
        case .publish: return "arrow.up.circle"
        case .passport: return "book.closed"
        }
    }
}

private enum V3LabSheet: Identifiable {
    case photo
    case coach(V3LabCriterionTarget)
    case flavors
    case addCriterion(V3LabCriterionTarget)
    case inviteFriends
    case passportWhy

    var id: String {
        switch self {
        case .photo: return "photo"
        case .coach(let target): return "coach-\(target.rawValue)"
        case .flavors: return "flavors"
        case .addCriterion(let target): return "criterion-\(target.rawValue)"
        case .inviteFriends: return "friends"
        case .passportWhy: return "passport-why"
        }
    }

    var detents: Set<PresentationDetent> {
        switch self {
        case .flavors: return [.medium, .large]
        default: return [.medium]
        }
    }
}

enum V3LabCriterionTarget: String, Equatable {
    case sip
    case context
}

private struct V3LabPhotoOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var usesPlaceholder: Bool

    var body: some View {
        V3LabSheetShell(
            title: "Add a visual",
            subtitle: "Photos make the memory vivid, but your journal is never held hostage."
        ) {
            Button {
                usesPlaceholder = false
                dismiss()
            } label: {
                sheetChoice(icon: "camera.fill", title: "Take a photo", detail: "Uses the fixture photo in this visual lab")
            }
            Button {
                usesPlaceholder = false
                dismiss()
            } label: {
                sheetChoice(icon: "photo.on.rectangle", title: "Choose from library", detail: "Uses the fixture photo in this visual lab")
            }
            Button {
                usesPlaceholder = true
                dismiss()
            } label: {
                sheetChoice(icon: "mug.fill", title: "I missed the photo", detail: "Use Mugsy's friendly placeholder")
            }
        }
    }

    private func sheetChoice(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.mugshotSage)
                .frame(width: 38, height: 38)
                .background(Color.mugshotMint.opacity(0.22))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.tertiaryText)
        }
        .padding(12)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
    }
}

private struct V3LabCoachPrompt: Identifiable {
    let id: String
    let prompt: String
    let hint: String

    static let sip: [V3LabCoachPrompt] = [
        .init(id: "first", prompt: "What hits first?", hint: "Notice the opening second before naming a flavor."),
        .init(id: "stays", prompt: "What stays after the sip?", hint: "Think about finish, texture, and what lingers."),
        .init(id: "change", prompt: "How does it change?", hint: "A drink can become brighter, thinner, sweeter, or quieter."),
        .init(id: "feeling", prompt: "What feeling does it leave?", hint: "Your experience matters more than a technical answer.")
    ]

    static func forContext(_ context: V3LabContext) -> [V3LabCoachPrompt] {
        switch context {
        case .cafe:
            return [
                .init(id: "arrival", prompt: "How did the room greet you?", hint: "Notice light, sound, movement, and how easy it felt to settle in."),
                .init(id: "service", prompt: "How did the interaction feel?", hint: "Describe what happened without turning an employee into the review."),
                .init(id: "value", prompt: "Did the experience feel worth it?", hint: "Value can include care, comfort, craft, and price."),
                .init(id: "return", prompt: "What would bring you back?", hint: "Look for the part of the memory you would want again.")
            ]
        case .home:
            return [
                .init(id: "change", prompt: "What changed this time?", hint: "Name the smallest variable you remember."),
                .init(id: "result", prompt: "What did that version make possible?", hint: "Describe the result without assuming one change caused it."),
                .init(id: "next", prompt: "What is one next experiment?", hint: "Change one variable so tomorrow can teach you something.")
            ]
        case .elsewhere:
            return [
                .init(id: "place", prompt: "How did the setting change the sip?", hint: "A view, journey, person, or pause can shape the memory."),
                .init(id: "sense", prompt: "What else could you hear or feel?", hint: "Let the setting be evidence, not merely a location."),
                .init(id: "remember", prompt: "What will future you want to remember?", hint: "Keep the one detail that makes this moment distinct.")
            ]
        }
    }
}

private struct V3LabCoachSheet: View {
    let title: String
    let prompts: [V3LabCoachPrompt]
    @Binding var index: Int

    var body: some View {
        V3LabSheetShell(title: title, subtitle: "Mugsy helps you think. Your words stay yours.") {
            HStack(alignment: .top, spacing: 14) {
                MugsyModelView(configuration: MugsyModelConfiguration(expression: .curious, prop: .journalNotebook))
                    .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 6) {
                    Text(prompts[safeIndex].prompt)
                        .mugshotDisplay(size: 22)
                        .foregroundColor(.espressoBrown)
                    Text(prompts[safeIndex].hint)
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )

            HStack {
                Button("Back", systemImage: "chevron.left") {
                    index = max(0, safeIndex - 1)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(safeIndex == 0)
                Spacer()
                Text("\(safeIndex + 1) of \(prompts.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.tertiaryText)
                Spacer()
                Button("Next", systemImage: "chevron.right") {
                    index = min(prompts.count - 1, safeIndex + 1)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(safeIndex == prompts.count - 1)
            }
        }
    }

    private var safeIndex: Int {
        min(max(index, 0), max(prompts.count - 1, 0))
    }
}

private struct V3LabFlavorExplorerSheet: View {
    @Binding var depth: Int

    private let levels = [
        ("Start broad", ["Fruity", "Sweet", "Roasted", "Other"]),
        ("Fruity", ["Citrus", "Berry", "Stone fruit", "Tropical"]),
        ("Citrus", ["Orange", "Lemon", "Grapefruit", "Lime"]),
        ("Orange", ["Fresh orange", "Marmalade", "Orange blossom", "Candied peel"])
    ]

    var body: some View {
        V3LabSheetShell(
            title: "Explore flavors",
            subtitle: "Tap from broad to specific. This prototype demonstrates the interaction; the production taxonomy will use the licensed source of truth."
        ) {
            Text(levels[safeDepth].0)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.mugshotSage)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(levels[safeDepth].1.enumerated()), id: \.offset) { index, flavor in
                    Button {
                        if index == 0, depth < levels.count - 1 {
                            withAnimation(DesignSystem.Motion.base) { depth += 1 }
                        }
                    } label: {
                        Text(flavor)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(index == 0 ? Color.mugshotMint.opacity(0.30) : Color.foamWhite)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                                    .stroke(Color.mugshotLine, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button("Start over") { depth = 0 }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                Spacer()
                Text("\(safeDepth + 1) of \(levels.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
            }
        }
    }

    private var safeDepth: Int { min(max(depth, 0), levels.count - 1) }
}

private struct V3LabAddCriterionSheet: View {
    @Binding var name: String
    let target: V3LabCriterionTarget
    let onAdd: () -> Void

    var body: some View {
        V3LabSheetShell(
            title: "Add your own criterion",
            subtitle: "Personal criteria are what make Mugshot yours."
        ) {
            TextField(target == .sip ? "Try sweetness or nostalgia" : "Try menu clarity or people-watching", text: $name)
                .textInputAutocapitalization(.sentences)
                .padding(14)
                .background(Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                        .stroke(Color.mugshotLine, lineWidth: 1)
                )

            Button("Add criterion", action: onAdd)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

private struct V3LabFriendPickerSheet: View {
    @Binding var selectedCount: Int

    private let friends = ["Amanda", "Jake", "Sarah", "Jimmy"]

    var body: some View {
        V3LabSheetShell(
            title: "Invite friends",
            subtitle: "An invite creates a shared memory. It never publishes for them."
        ) {
            ForEach(Array(friends.enumerated()), id: \.offset) { index, friend in
                Button {
                    selectedCount = selectedCount == index + 1 ? 0 : index + 1
                } label: {
                    HStack {
                        Circle()
                            .fill(Color.mugshotMint.opacity(0.38))
                            .frame(width: 36, height: 36)
                            .overlay(Text(String(friend.prefix(1))).font(.system(size: 13, weight: .bold)))
                        Text(friend)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                        Spacer()
                        Image(systemName: index < selectedCount ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(index < selectedCount ? .mugshotSage : .tertiaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct V3LabPassportWhySheet: View {
    var body: some View {
        V3LabSheetShell(
            title: "Why this identity?",
            subtitle: "Mugshot shows its work and leaves room for you to disagree."
        ) {
            explanation(icon: "leaf.fill", title: "Four citrus notes", detail: "Bright citrus appeared in four memories and is still taking shape.")
            explanation(icon: "water.waves", title: "Seven body ratings", detail: "Body becomes more important when your drinks turn creamy.")
            explanation(icon: "storefront", title: "Three quiet visits", detail: "Your strongest place memories mention calm corners.")
            Text("Nothing here changes a score, writes a caption, or publishes on your behalf.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.mugshotSage)
                .padding(.top, 4)
        }
    }

    private func explanation(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.mugshotSage)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

private struct V3LabSheetShell<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Space.md) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .mugshotDisplay(size: 27)
                        .foregroundColor(.espressoBrown)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .padding(DesignSystem.Space.lg)
        }
        .background(Color.creamWhite)
    }
}

#Preview("V3 five-screen UI Lab") {
    NavigationStack {
        LogASipV3LabView()
    }
}
#endif
