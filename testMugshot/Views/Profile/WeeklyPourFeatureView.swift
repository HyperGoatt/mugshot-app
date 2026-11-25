import SwiftUI

struct WeeklyPourPresentation: Identifiable {
    let ownerID: UUID
    var id: UUID { ownerID }
}

struct WeeklyPourInvitation: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("THE WEEKLY POUR")
                        .font(.caption2.weight(.bold)).tracking(1.8)
                    Text("Your week,\nfreshly remembered.")
                        .font(.system(.title, design: .serif)).tracking(-0.4)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Open my week", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold)).padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MugsyCatalogView(pose: .journalKeeper, rendering: .artwork)
                    .frame(width: 102, height: 128).accessibilityHidden(true)
            }
            .foregroundStyle(Color.espressoBrown)
            .padding(20)
            .background(Color.mugshotMint.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Week in review. Your Weekly Pour. Open your latest completed week.")
        .accessibilityIdentifier("weeklyPour.invitation")
    }
}

struct WeeklyPourFeatureView: View {
    let ownerID: UUID
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var homeStore = HomeRecipeWorkspaceStore.shared
    @StateObject private var store: WeeklyPourStore
    @State private var window = WeeklyPourWindow.latestCompleted()
    @State private var retry = 0
    @State private var showsArchive = false

    init(ownerID: UUID) {
        self.ownerID = ownerID
        _store = StateObject(wrappedValue: WeeklyPourStore(ownerID: ownerID))
    }

    private var ownsPresentation: Bool { authModel.authenticatedUser?.id == ownerID }

    var body: some View {
        Group {
            if ownsPresentation, let story = store.story {
                WeeklyPourStoryView(story: story, onClose: { dismiss() },
                    onChooseWeek: { showsArchive = true },
                    canShare: { ownsPresentation && scenePhase == .active })
                    .id(story.window)
            } else {
                loadingOrFailure
            }
        }
        .background(Color.creamWhite)
        .privacySensitive()
        .task(id: "\(window.end.timeIntervalSince1970)|\(retry)") { await load() }
        .sheet(isPresented: $showsArchive) {
            WeeklyPourArchiveView(selected: window) { selected in window = selected }
        }
        .onChange(of: authModel.authenticatedUser?.id) { _, account in
            if account != ownerID { store.invalidate(); dismiss() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mugshotSafetyAccessChanged)) { _ in
            store.invalidate()
            retry += 1
        }
        .onDisappear { store.invalidate() }
    }

    private var loadingOrFailure: some View {
        VStack(spacing: 20) {
            HStack {
                Text("THE WEEKLY POUR").font(.caption.weight(.bold)).tracking(1.8)
                Spacer()
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly).frame(width: 44, height: 44)
            }
            Spacer()
            if let failure = store.failure {
                Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                Text("A moment to reconnect.").font(.system(.title, design: .serif))
                Text(failure).font(.body).multilineTextAlignment(.center)
                    .foregroundStyle(Color.roastBrown)
                Button("Try again") { retry += 1 }.buttonStyle(.borderedProminent).tint(.mugshotSageText)
                    .accessibilityIdentifier("weeklyPour.retry")
                Button("Choose another week") { showsArchive = true }
                    .foregroundStyle(Color.mugshotSageText).frame(minHeight: 44)
            } else {
                ProgressView("Gathering your week…").tint(.mugshotSageText)
            }
            Spacer()
        }
        .padding(24).foregroundStyle(Color.espressoBrown)
    }

    @MainActor private func load() async {
        guard ownsPresentation else { store.invalidate(); return }
        let local: [WeeklyPourMoment]
        do {
            let snapshot = try homeStore.exportSnapshot(ownerID: ownerID)
            local = WeeklyPourDataSource.privateMoments(snapshot.attempts, ownerID: ownerID)
        } catch {
            await store.load(window: window, local: []) { _, _ in throw error }
            return
        }
        await store.load(window: window, local: local) { owner, interval in
            let service = VisitService(client: try SupabaseClientProvider.shared.client())
            return try await service.fetchWeeklyPour(userID: owner, window: interval)
                .map(WeeklyPourDataSource.moment)
        }
        if !ownsPresentation { store.invalidate() }
    }
}

struct WeeklyPourArchiveView: View {
    let selected: WeeklyPourWindow
    let onSelect: (WeeklyPourWindow) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var chosenDate = Date()
    private let latest = WeeklyPourWindow.latestCompleted()

    var body: some View {
        NavigationStack {
            List {
                Section("Your completed weeks") {
                    ForEach(0..<12, id: \.self) { index in
                        let week = WeeklyPourWindow(endingAt: latest.end.addingTimeInterval(-Double(index) * WeeklyPourWindow.duration))
                        Button { choose(week) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(week.title).foregroundStyle(Color.espressoBrown)
                                    Text(week.yearLabel).font(.caption).foregroundStyle(Color.roastBrown)
                                }
                                Spacer()
                                if week == selected {
                                    Image(systemName: "checkmark").foregroundStyle(Color.mugshotSageText)
                                }
                            }.frame(minHeight: 44)
                        }
                        .accessibilityLabel("\(week.title), \(week.yearLabel)\(week == selected ? ", selected" : "")")
                    }
                }
                Section("A little further back") {
                    DatePicker("Choose a date", selection: $chosenDate, in: ...latest.end, displayedComponents: .date)
                    Button("Open that week") {
                        let dayEnd = Calendar.current.startOfDay(for: chosenDate).addingTimeInterval(86399)
                        choose(.latestCompleted(at: min(dayEnd, latest.end)))
                    }.foregroundStyle(Color.mugshotSageText)
                }
            }
            .scrollContentBackground(.hidden).background(Color.creamWhite)
            .navigationTitle("Your Weekly Pours").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear { chosenDate = min(selected.end, latest.end) }
    }

    private func choose(_ week: WeeklyPourWindow) { onSelect(week); dismiss() }
}
