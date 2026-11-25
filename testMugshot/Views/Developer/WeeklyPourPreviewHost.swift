#if DEBUG
import SwiftUI

/// Fictional local fixtures exercise the production story components. No
/// account, remote read/write, notification or analytics is part of this host.
struct WeeklyPourPreviewHost: View {
    @State private var showsStory = true
    @State private var showsArchive = false
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000701")!

    private var story: WeeklyPourStory {
        let end = ISO8601DateFormatter().date(from: "2026-11-22T23:00:00Z")!
        let window = WeeklyPourWindow(endingAt: end)
        let cafe = UUID(uuidString: "00000000-0000-0000-0000-000000000702")!
        let otherCafe = UUID(uuidString: "00000000-0000-0000-0000-000000000703")!
        let variant = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--weekly-pour-state=") }?
            .replacingOccurrences(of: "--weekly-pour-state=", with: "") ?? "full"
        let names = ["Flat white", "Filter coffee", "Flat white", "Vanilla latte", "Espresso"]
        var moments = names.enumerated().map { index, name in
            let isHome = index == 1 || index == 4
            return WeeklyPourMoment(id: UUID(uuidString: "00000000-0000-0000-0000-00000000071\(index)")!,
                ownerID: owner, date: end.addingTimeInterval(-Double(5 - index) * 86400 + 3600),
                drink: name, location: isHome ? "At home" : index == 3 ? "Little Window" : "Noonday",
                cafeID: isHome ? nil : index == 3 ? otherCafe : cafe,
                isAtHome: isHome, rating: index == 3 ? 4.5 : index == 4 ? nil : 4,
                caption: index == 3 ? "Found my new favorite corner. A slow Saturday, just how I like it." : nil,
                photo: variant == "no-photo" ? nil : .fixture(index == 3 || index == 0 || index == 2 ? "V3CreamyLatte" : "V3QuietCafeCorner"),
                isPrivate: variant == "private" || isHome, isComplete: true, origin: .journal, linkedVisitID: nil)
        }
        if variant == "quiet" { moments = [] }
        if variant == "single" { moments = [moments[3]] }
        if variant == "unrated" {
            moments = moments.map { value in
                WeeklyPourMoment(id: value.id, ownerID: owner, date: value.date, drink: value.drink,
                    location: value.location, cafeID: value.cafeID, isAtHome: value.isAtHome,
                    rating: nil, caption: value.caption, photo: value.photo, isPrivate: value.isPrivate,
                    isComplete: true, origin: .journal, linkedVisitID: nil)
            }
        }
        return WeeklyPourStory(ownerID: owner, window: window, candidates: moments)
    }

    var body: some View {
        Group {
            if showsStory {
                WeeklyPourStoryView(story: story, onClose: { showsStory = false },
                    onChooseWeek: { showsArchive = true }, canShare: { true })
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text("Journal").font(.system(.largeTitle, design: .serif))
                            WeeklyPourInvitation { showsStory = true }
                            Text("Fictional preview memories").font(.caption).foregroundStyle(Color.roastBrown)
                        }.padding(20)
                    }.background(Color.creamWhite)
                }
            }
        }
        .sheet(isPresented: $showsArchive) { WeeklyPourArchiveView(selected: story.window) { _ in } }
    }
}
#endif
