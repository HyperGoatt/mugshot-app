#if DEBUG
import SwiftUI
import UIKit

/// Fictional Journal acceptance fixtures, reached only by the explicit UI-test
/// launch route. Owner storage and production transport are never used here.
struct HomeJournalPreviewHost: View {
    @StateObject private var dataManager = DataManager(defaults: UserDefaults(suiteName: "MugshotHomeJournalFixture")!)
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var seeded = false
    @State private var showsArchive = false
    @State private var status: String?
    private static let homeID = UUID(uuidString: "00000000-0000-4000-8000-000000000081")!

    private var homeEntries: [HomeAttemptRecord] {
        HomeJournalProjection.privateEntries(in: store.workspace, scope: store.scope,
            expectedScope: .guest, publishedIDs: Set(Self.entries.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Journal").font(.largeTitle.weight(.semibold))
                    Text("Every sip, one familiar view.").font(.subheadline).foregroundStyle(Color.secondaryText)
                    ForEach(homeEntries) { attempt in
                        HomeJournalEntryRow(attempt: attempt, scope: .guest) { status = "Opened \(attempt.name)" }
                    }
                    ForEach(Self.entries) { entry in
                        RemoteJournalRow(visit: entry.summary, onOpen: { status = "Opened \(entry.summary.visit.drinkDisplayName)" })
                    }
                    if let status { Text(status).accessibilityIdentifier("journal.fixture.status") }
                    Button("View Journal archive") { showsArchive = true }
                        .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("journal.fixture.archive")
                        .disabled(store.scope != .guest)
                    Button("Simulate account switch") { store.activate(.user(UUID())) }
                        .buttonStyle(SecondaryButtonStyle()).accessibilityIdentifier("journal.fixture.switchScope")
                }
                .padding(20)
            }
            .background(Color.creamWhite).foregroundStyle(Color.espressoBrown)
            .task { seed() }
            .fullScreenCover(isPresented: $showsArchive) {
                JournalArchiveView(entries: Self.entries,
                    homeScope: .guest, currentUserID: nil, dataManager: dataManager,
                    onComposeDraft: { _ in }, onShareHomeAttempt: { _ in }, onRepeatHomeAttempt: { _ in },
                    onOpenRecipeBook: {}, showsPhase2Tools: true)
                    .environment(\.dynamicTypeSize, typeSize)
            }
        }
    }

    @MainActor private func seed() {
        guard !seeded, MugshotLaunchEnvironment.isUITesting,
              ProcessInfo.processInfo.arguments.contains("--ui-testing-home-journal") else { return }
        seeded = true
        store.activate(.guest)
        do {
            if !store.workspace.attempts.contains(where: { $0.id == Self.homeID }) {
                let bytes = Self.photo.jpegData(compressionQuality: 0.8)!
                let name = try store.savePhoto(bytes, attemptID: Self.homeID)
                var preparation = HomeRecipeContent(name: "Cinnamon latte", template: .drink, method: .completeDrink)
                preparation.coffee = CoffeeBagSnapshot(roaster: "Fixture Roasters", name: "Morning")
                let attempt = HomeAttemptRecord(id: Self.homeID, name: "Cinnamon latte", locationName: "Kitchen counter",
                    homeCoffeeBagID: UUID(uuidString: "00000000-0000-4000-8000-000000000084"), preparation: preparation,
                    rating: 4.5, reaction: "A cozy coffee break.", photoNames: [name], savedAt: .now)
                try store.saveAttempt(attempt)
            }
        } catch { status = "Fixture could not load" }
    }

    private static var entries: [JournalEntryProjection] {
        [
            ("00000000-0000-4000-8000-000000000082", "Cafe", "Maple Cafe", "Cortado", -120.0),
            ("00000000-0000-4000-8000-000000000083", "Elsewhere", "An afternoon walk", "Iced matcha", -240.0)
        ].map { id, context, location, drink, offset in
            let row = SupabaseVisitRow(id: UUID(uuidString: id)!, userId: UUID(), cafeId: nil,
                drinkType: "Coffee", drinkTypeCustom: nil, drinkSubtype: drink, caption: "A little sip", notes: nil,
                visibility: "Private", ratings: ["Overall": 4], overallScore: 4, posterPhotoURL: nil,
                contextType: context, locationName: location, cityState: nil, brewMethod: nil,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(offset)))
            return JournalEntryProjection(summary: RemoteVisitSummary(visit: row, cafe: nil), privateNote: nil, isBookmarked: false)
        }
    }

    private static var photo: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320)).image { context in
            UIColor(red: 0.81, green: 0.87, blue: 0.80, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 320))
            UIColor.white.setFill(); UIBezierPath(ovalIn: CGRect(x: 49, y: 55, width: 225, height: 225)).fill()
            UIColor(red: 0.48, green: 0.28, blue: 0.15, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 69, y: 75, width: 185, height: 185)).fill()
            UIColor(red: 0.96, green: 0.86, blue: 0.68, alpha: 1).setStroke()
            let swirl = UIBezierPath(ovalIn: CGRect(x: 98, y: 104, width: 126, height: 126)); swirl.lineWidth = 16; swirl.stroke()
        }
    }
}
#endif
