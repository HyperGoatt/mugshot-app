import Foundation

/// Compiles the production Foundation/Combine domain directly, without an app,
/// credentials, Simulator or production backend. See docs/WEEKLY_POUR.md.
@main
struct WeeklyPourContracts {
    @MainActor static func main() async throws {
        let owner = UUID()
        let otherOwner = UUID()
        let end = ISO8601DateFormatter().date(from: "2026-11-22T23:00:00Z")!
        let window = WeeklyPourWindow(endingAt: end)
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        func moment(_ offset: TimeInterval = -3600, id: UUID = UUID(),
                    ownerID: UUID? = nil, drink: String = "Flat white", rating: Double? = 4,
                    isPrivate: Bool = false, complete: Bool = true,
                    origin: WeeklyPourMoment.Origin = .journal,
                    linkedVisitID: UUID? = nil, cafeID: UUID? = nil) -> WeeklyPourMoment {
            WeeklyPourMoment(id: id, ownerID: ownerID ?? owner, date: end.addingTimeInterval(offset),
                drink: drink, location: "A saved place", cafeID: cafeID,
                isAtHome: origin == .home, rating: rating, caption: "A private saved caption",
                photo: nil, isPrivate: isPrivate, isComplete: complete,
                origin: origin, linkedVisitID: linkedVisitID)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        expect(WeeklyPourWindow.latestCompleted(at: end, calendar: calendar) == window, "Sunday boundary")
        expect(WeeklyPourWindow.latestCompleted(at: end.addingTimeInterval(-1), calendar: calendar).end < end,
               "Before the boundary remains the previous week")
        expect(window.end.timeIntervalSince(window.start) == 604800, "168 hour interval")
        expect(window.contains(window.start), "Start is inclusive")
        expect(!window.contains(window.end), "End is exclusive")
        expect(window.previous.end == window.start, "Archive is endpoint-bound")
        let dstEnd = ISO8601DateFormatter().date(from: "2026-11-01T23:00:00Z")!
        let dst = WeeklyPourWindow.latestCompleted(at: dstEnd, calendar: calendar)
        expect(dst.end == dstEnd && dst.end.timeIntervalSince(dst.start) == 604800, "DST retains UTC interval")

        let id = UUID()
        let records = [moment(id: id), moment(id: id), moment(ownerID: otherOwner),
                       moment(0), moment(-604801), moment(complete: false)]
        let owned = WeeklyPourStory(ownerID: owner, window: window, candidates: records)
        expect(owned.moments.count == 1, "Owner, publication, interval and identity filters")
        let quiet = WeeklyPourStory(ownerID: owner, window: window, candidates: [])
        expect(quiet.chapters == [.cover], "A quiet week has no padded chapters")
        expect(owned.chapters == [.cover, .standout, .keepsake], "A one-sip story is shorter")
        expect(quiet.standout == nil && quiet.repeatedDrink == nil, "No invented quiet-week highlights")

        let invalidRatings = [Double.nan, Double.infinity, -1, 0, 6]
        let unrated = WeeklyPourStory(ownerID: owner, window: window,
            candidates: invalidRatings.map { moment(rating: $0) })
        expect(!unrated.hasRatedStandout, "Invalid and absent scores cannot become superlatives")
        let earlier = moment(-7200, rating: 5)
        let later = moment(-3600, rating: 5)
        let rated = WeeklyPourStory(ownerID: owner, window: window,
            candidates: [moment(rating: nil), later, earlier])
        expect(rated.standout?.id == later.id, "Rating ties use the most recent memory")
        expect(rated.standout == WeeklyPourStory(ownerID: owner, window: window,
            candidates: [earlier, later]).standout, "Input order does not change highlight")

        let repeats = WeeklyPourStory(ownerID: owner, window: window,
            candidates: [moment(drink: "  FLAT   white "), moment(drink: "Flat white"), moment(drink: "Matcha")])
        expect(repeats.repeatedDrink?.moments.count == 2, "Repeat names normalize case and whitespace")
        expect(repeats.chapters.contains(.repeatOrder), "Recorded repeats earn a chapter")
        expect(!owned.chapters.contains(.repeatOrder), "One order is not a preference")

        let remote = moment(id: id)
        let duplicateHome = moment(origin: .home, linkedVisitID: id)
        let deduplicated = WeeklyPourStory(ownerID: owner, window: window,
            candidates: [remote, duplicateHome, moment(isPrivate: true, origin: .home)])
        expect(deduplicated.moments.count == 2, "Published Home saves count once")
        expect(deduplicated.shareSummary(includePrivate: false).momentCount == 1, "Private default is excluded")
        expect(deduplicated.shareSummary(includePrivate: true).momentCount == 2, "Private inclusion is explicit")
        expect(quiet.shareSummary(includePrivate: false).momentCount == 0, "No phantom share totals")
        let cafe = UUID()
        let places = WeeklyPourStory(ownerID: owner, window: window,
            candidates: [moment(cafeID: cafe), moment(cafeID: cafe), moment(isPrivate: true, origin: .home)])
        expect(places.places.count == 1 && places.places.first?.count == 2, "Cafe counts use stable IDs")
        expect(places.homeCount == 1, "Private Home saves are remembered in app")

        let model = WeeklyPourStore(ownerID: owner)
        await model.load(window: window, local: []) { _, _ in throw URLError(.notConnectedToInternet) }
        expect(model.failure != nil && model.story == nil, "Failure is not quiet-week emptiness")
        await model.load(window: window, local: []) { _, _ in [remote] }
        expect(model.story?.moments.count == 1 && model.failure == nil, "Retry replaces failure")
        let first = Task { @MainActor in
            await model.load(window: window.previous, local: []) { _, _ in
                try? await Task.sleep(for: .milliseconds(60))
                return [moment(-604900)]
            }
        }
        await Task.yield()
        await model.load(window: window, local: []) { _, _ in [remote] }
        await first.value
        expect(model.story?.window == window, "Stale request cannot overwrite newer week")
        let cancelled = Task { @MainActor in
            await model.load(window: window, local: []) { _, _ in
                try? await Task.sleep(for: .milliseconds(60))
                return [remote]
            }
        }
        await Task.yield()
        model.invalidate()
        cancelled.cancel()
        await cancelled.value
        expect(model.story == nil && model.failure == nil, "Invalidation clears owner data and late completion")
        print("Weekly Pour: \(checks) domain, privacy, retry and lifecycle contracts passed.")
    }
}
