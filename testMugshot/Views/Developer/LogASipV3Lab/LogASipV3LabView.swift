#if DEBUG
import SwiftUI

struct LogASipV3LabView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft = V3LabDraft.fixture
    @State private var step: V3LabStep = .setup
    @State private var presentedSheet: V3LabSheet?
    @State private var sipCoachIndex = 0
    @State private var contextCoachIndex = 0
    @State private var flavorPath: [V3LabFlavorNode] = []
    @State private var selectedFlavorIDs: Set<String> = []
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
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.espressoBrown)
                        .frame(width: 34, height: 34)
                        .background(Color.foamWhite)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.mugshotLine, lineWidth: 1))
                }
                .accessibilityLabel("Close Log a Sip")
            }

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
                            sipCoachIndex = 0
                            contextCoachIndex = 0
                            flavorPath = []
                            selectedFlavorIDs = []
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
                coachIndex: $sipCoachIndex,
                onEditSetup: { move(to: .setup) },
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
                coachIndex: $contextCoachIndex,
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
        case .flavors:
            V3LabFlavorExplorerSheet(
                path: $flavorPath,
                selectedFlavorIDs: $selectedFlavorIDs
            )
        case .addCriterion(let target):
            V3LabAddCriterionSheet(
                name: $newCriterionName,
                target: target,
                onAdd: { addCustomCriterion(to: target) }
            )
        case .inviteFriends:
            V3LabFriendPickerSheet(selectedIDs: $draft.taggedPeopleIDs)
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
    case flavors
    case addCriterion(V3LabCriterionTarget)
    case inviteFriends
    case passportWhy

    var id: String {
        switch self {
        case .photo: return "photo"
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

private struct V3LabFlavorExplorerSheet: View {
    @Binding var path: [V3LabFlavorNode]
    @Binding var selectedFlavorIDs: Set<String>

    var body: some View {
        V3LabSheetShell(
            title: "Explore flavors",
            subtitle: "Start broad, then keep drilling until a word feels useful."
        ) {
            if !path.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(DesignSystem.Motion.base) {
                            _ = path.popLast()
                        }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.mugshotSage)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            Text("Start")
                            ForEach(path) { node in
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 7, weight: .bold))
                                Text(node.title)
                            }
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.tertiaryText)
                    }
                }
            }

            Text(path.last?.title ?? "What are you noticing?")
                .mugshotDisplay(size: 21)
                .foregroundColor(.espressoBrown)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(currentNodes) { node in
                    Button {
                        withAnimation(DesignSystem.Motion.base) {
                            if node.isLeaf {
                                if selectedFlavorIDs.contains(node.id) {
                                    selectedFlavorIDs.remove(node.id)
                                } else {
                                    selectedFlavorIDs.insert(node.id)
                                }
                            } else {
                                path.append(node)
                            }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Text(node.title)
                                .font(.system(size: 12, weight: .semibold))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 2)
                            Image(systemName: node.isLeaf
                                ? (selectedFlavorIDs.contains(node.id) ? "checkmark.circle.fill" : "circle")
                                : "chevron.right"
                            )
                            .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(selectedFlavorIDs.contains(node.id) ? .foamWhite : .espressoBrown)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(selectedFlavorIDs.contains(node.id) ? Color.mugshotSage : Color.foamWhite)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                                .stroke(Color.mugshotLine, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if !selectedFlavorIDs.isEmpty {
                Label(
                    "\(selectedFlavorIDs.count) \(selectedFlavorIDs.count == 1 ? "note" : "notes") saved to this exploration",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.mugshotSage)
            }

            Text("Adapted from Counter Culture Coffee's Taster's Flavor Wheel (2020). Changes made. For prototype evaluation only.")
                .font(.system(size: 9))
                .foregroundColor(.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentNodes: [V3LabFlavorNode] {
        path.last?.children ?? V3LabFlavorNode.explorerRoots
    }
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
    @Binding var selectedIDs: Set<String>

    var body: some View {
        V3LabSheetShell(
            title: "Tag people",
            subtitle: "An invite creates a shared MugShot. It never publishes for them."
        ) {
            ForEach(V3LabFriend.recommended) { friend in
                Button {
                    if selectedIDs.contains(friend.id) {
                        selectedIDs.remove(friend.id)
                    } else {
                        selectedIDs.insert(friend.id)
                    }
                } label: {
                    HStack {
                        MugshotAvatar(name: friend.name, size: 40, imageURL: friend.imageURL)
                        Text(friend.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.espressoBrown)
                        Spacer()
                        Image(systemName: selectedIDs.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedIDs.contains(friend.id) ? .mugshotSage : .tertiaryText)
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
