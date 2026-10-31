#if DEBUG
import SwiftUI

/// Exercises the production components with explicit local fixtures. This route
/// performs no network mutation, installs no asset and is excluded from Release.
struct MugshotCompletionPreviewHost: View {
    private let owner = UUID(uuidString: "00000000-0000-4000-8000-000000000051")!
    private let alternateOwner = UUID(uuidString: "00000000-0000-4000-8000-000000000052")!
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.mugshotReduceMotionOverride) private var motionOverride
    @State private var operation = ProcessInfo.processInfo.arguments.contains("--ui-testing-fixed-completion")
        ? UUID(uuidString: "00000000-0000-4000-8000-000000000054")! : UUID()
    @State private var renderIdentity = UUID()
    @State private var quick = false
    @State private var social = true
    @State private var otherAccount = false
    @State private var quietWeek = ProcessInfo.processInfo.arguments.contains("--ui-testing-completion-quiet-week")
    @State private var showsWeek = false
    @State private var scrub = false
    @State private var progress = 0.5
    @State private var automaticPlayback = ProcessInfo.processInfo.arguments.contains("--ui-testing-motion-playback")
    @State private var playbackStarted = false
    @State private var playbackStatus = "Waiting for recording"


    private var receipt: MugshotSaveReceipt {
        MugshotSaveReceipt(id: operation, ownerID: owner, drinkName: "Cortado",
                          isExpressive: !quick, audience: social ? .friends : nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("A moment, remembered")
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .foregroundStyle(Color.espressoBrown)
                    Text("Local fixtures · production components")
                        .font(.caption).foregroundStyle(Color.secondaryText)
                    if ProcessInfo.processInfo.arguments.contains("--ui-testing-motion-playback") {
                        Text(playbackStatus).font(.caption)
                            .accessibilityIdentifier("physical.qa.status")
                    }
                    MugshotSaveReceiptView(receipt: receipt,
                        detail: social ? "Kept in your journal · Friends" : "Kept in your private Home journal")
                        .id(renderIdentity)
                        .environment(\.mugshotFeedbackOwnerID, otherAccount ? alternateOwner : owner)
                    Button("Replay new completion") { automaticPlayback = false; operation = UUID() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Reopen same completion") { automaticPlayback = false; renderIdentity = UUID() }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Week in review") { automaticPlayback = false; showsWeek = true }
                        .buttonStyle(SecondaryButtonStyle())
                    Toggle("Quick save", isOn: manual($quick))
                    Toggle("Social post", isOn: manual($social))
                    Toggle("Another account", isOn: manual($otherAccount))
                    Toggle("Quiet week", isOn: manual($quietWeek))
                    Toggle("Inspect rig timeline", isOn: manual($scrub))
                    if scrub {
                        MugsyCompletionMoment(progress: progress)
                            .frame(width: 200, height: 200)
                            .frame(maxWidth: .infinity)
                        Slider(value: manual($progress), in: 0...1)
                            .accessibilityLabel("Completion progress")
                    }
                }
                .padding(20)
            }
            .background(Color.creamWhite)
            .navigationTitle("Completion inspection")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showsWeek) {
                let entries = quietWeek ? [] : Self.entries
                let privateHome = quietWeek ? [] : [Self.privateHome]
                JournalReflectionDetailView(
                    reflection: JournalReflectionEngine.summary(for: .week, entries: entries,
                                                                savedHomeAttempts: privateHome,
                                                                referenceDate: Self.referenceDate),
                    entries: entries, milestones: [], savedHomeAttempts: privateHome,
                    referenceDate: Self.referenceDate
                )
                .environment(\.dynamicTypeSize, typeSize)
                .environment(\.mugshotReduceMotionOverride, motionOverride)
            }
            .task(id: "\(automaticPlayback):\(scenePhase)") { await runPlaybackIfRequested() }
        }
    }

    private func manual<Value>(_ binding: Binding<Value>) -> Binding<Value> {
        Binding(get: { binding.wrappedValue }, set: { value in
            automaticPlayback = false
            binding.wrappedValue = value
        })
    }

    /// State-driven authoring only. Real components remain interactive; manual
    /// changes and scene inactivity cancel old work, and activation never replays it.
    @MainActor
    private func runPlaybackIfRequested() async {
        guard automaticPlayback, !playbackStarted, scenePhase == .active else { return }
        playbackStarted = true
        UserDefaults.standard.set("running", forKey: "MugshotMotionQA.playbackState")
        var operationIDs = [operation.uuidString]
        do {
            try await playbackWait(6)
            playbackStatus = "New completed social operation"
            operation = UUID()
            operationIDs.append(operation.uuidString)
            try await playbackWait(2)
            playbackStatus = "Same operation reopened — no repeat"
            renderIdentity = UUID()
            try await playbackWait(2)
            playbackStatus = "Concise private save"
            quick = true
            social = false
            operation = UUID()
            operationIDs.append(operation.uuidString)
            try await playbackWait(2)
            playbackStatus = "Another account — result hidden"
            otherAccount = true
            try await playbackWait(2)
            playbackStatus = "Original account — no repeat"
            otherAccount = false
            try await playbackWait(2)
            playbackStatus = "Actual fixture week"
            showsWeek = true
            try await playbackWait(3)
            showsWeek = false
            try await playbackWait(2)
            quietWeek = true
            playbackStatus = "Quiet week"
            showsWeek = true
            try await playbackWait(3)
            showsWeek = false
            playbackStatus = "Playback complete"
            UserDefaults.standard.set(operationIDs, forKey: "MugshotMotionQA.operationIDs")
            UserDefaults.standard.set("complete", forKey: "MugshotMotionQA.playbackState")
            print("MugshotMotionQA: playback_complete")
        } catch {
            UserDefaults.standard.set("cancelled", forKey: "MugshotMotionQA.playbackState")
            print("MugshotMotionQA: playback_cancelled")
        }
    }

    @MainActor
    private func playbackWait(_ seconds: Int) async throws {
        try await Task.sleep(for: .seconds(seconds))
        guard automaticPlayback, scenePhase == .active else { throw CancellationError() }
    }

    private static let referenceDate = ISO8601DateFormatter().date(from: "2026-10-30T12:00:00Z")!
    private static var privateHome: HomeAttemptRecord {
        var value = HomeAttemptRecord(name: "Private filter coffee")
        value.savedAt = ISO8601DateFormatter().date(from: "2026-10-22T12:00:00Z")!
        return value
    }
    private static var entries: [JournalEntryProjection] {
        ["Cortado", "Filter coffee"].enumerated().map { index, name in
            let row = SupabaseVisitRow(
                id: UUID(), userId: UUID(), cafeId: nil,
                drinkType: "Coffee", drinkTypeCustom: nil, drinkSubtype: name,
                caption: "A calm coffee break", notes: nil, visibility: "Private",
                ratings: ["Overall": 4], overallScore: 4, posterPhotoURL: nil,
                contextType: "Home", locationName: "Home", cityState: nil,
                brewMethod: nil, createdAt: "2026-10-2\(2 + index)T12:00:00Z"
            )
            return JournalEntryProjection(summary: RemoteVisitSummary(visit: row, cafe: nil),
                                          privateNote: nil, isBookmarked: false)
        }
    }
}
#endif
