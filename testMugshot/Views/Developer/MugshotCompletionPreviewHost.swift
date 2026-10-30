#if DEBUG
import SwiftUI

/// Exercises the production components with explicit local fixtures. This route
/// performs no network mutation, installs no asset and is excluded from Release.
struct MugshotCompletionPreviewHost: View {
    private let owner = UUID(uuidString: "00000000-0000-4000-8000-000000000051")!
    private let alternateOwner = UUID(uuidString: "00000000-0000-4000-8000-000000000052")!
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.mugshotReduceMotionOverride) private var motionOverride
    @State private var operation = UUID()
    @State private var renderIdentity = UUID()
    @State private var quick = false
    @State private var social = true
    @State private var otherAccount = false
    @State private var quietWeek = ProcessInfo.processInfo.arguments.contains("--ui-testing-completion-quiet-week")
    @State private var showsWeek = false
    @State private var scrub = false
    @State private var progress = 0.5

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
                    MugshotSaveReceiptView(receipt: receipt,
                        detail: social ? "Kept in your journal · Friends" : "Kept in your private Home journal")
                        .id(renderIdentity)
                        .environment(\.mugshotFeedbackOwnerID, otherAccount ? alternateOwner : owner)
                    Button("Replay new completion") { operation = UUID() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Reopen same completion") { renderIdentity = UUID() }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Week in review") { showsWeek = true }
                        .buttonStyle(SecondaryButtonStyle())
                    Toggle("Quick save", isOn: $quick)
                    Toggle("Social post", isOn: $social)
                    Toggle("Another account", isOn: $otherAccount)
                    Toggle("Quiet week", isOn: $quietWeek)
                    Toggle("Inspect rig timeline", isOn: $scrub)
                    if scrub {
                        MugsyCompletionMoment(progress: progress)
                            .frame(width: 200, height: 200)
                            .frame(maxWidth: .infinity)
                        Slider(value: $progress, in: 0...1)
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
        }
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
