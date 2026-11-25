import Foundation

/// Executes production copy and attachment boundaries without iOS, credentials,
/// a network connection, or an installed app.
@main
struct MugsyNotificationCreativeContracts {
    static func main() throws {
        let path = CommandLine.arguments.dropFirst().first
            ?? "supabase/functions/_shared/mugsy-copy-v1.json"
        let catalog = try MugsyNotificationCopyCatalog(data: Data(contentsOf: URL(fileURLWithPath: path)))
        var checks = 0
        func expect(_ value: @autoclosure () -> Bool, _ message: String) {
            precondition(value(), message)
            checks += 1
        }
        let now = Date(timeIntervalSince1970: 1_795_608_000)
        let facts = Set(MugsyNotificationCopyCatalog.allowedFacts)
        expect(catalog.templates.count == 32, "Exactly 32 reviewed templates")
        expect(Set(catalog.templates.map(\.family)).count == 8, "Eight message families")
        expect(Set(catalog.templates.map(\.id)).count == 32, "Stable unique variant IDs")
        for family in MugsyNotificationFamily.allCases {
            let templates = catalog.templates.filter { $0.family == family }
            expect(templates.count == 4, "Four variants per family")
            let selected = catalog.select(family: family, facts: facts, recentUses: [], now: now, rotationKey: "local-fixture")
            expect(selected != nil, "Eligible family can select a variant")
            expect(selected == catalog.select(family: family, facts: facts, recentUses: [], now: now, rotationKey: "local-fixture"), "Selection is stable")
            let used = templates.map { MugsyNotificationCopyUse(templateID: $0.id, usedAt: now.addingTimeInterval(-1)) }
            expect(catalog.select(family: family, facts: facts, recentUses: used, now: now, rotationKey: "local-fixture") == nil, "Exhausted variants quietly skip")
            let old = templates.map { MugsyNotificationCopyUse(templateID: $0.id, usedAt: now.addingTimeInterval(-28 * 86400)) }
            expect(catalog.select(family: family, facts: facts, recentUses: old, now: now, rotationKey: "local-fixture") != nil, "A variant is available at 28 days")
            expect(catalog.select(family: family, facts: [], recentUses: [], now: now, rotationKey: "local-fixture") == nil, "Facts cannot be invented")
        }
        expect(MugsyNotificationCopyCatalog.previewSecondMemory.id == "second_memory_1", "Presentation fallback matches canonical variant")
        expect(catalog.templates.contains(MugsyNotificationCopyCatalog.previewSecondMemory), "Preview content matches authority")
        let canonicalData = try Data(contentsOf: URL(fileURLWithPath: path))
        let canonicalObject = try JSONSerialization.jsonObject(with: canonicalData) as! [String: Any]
        var invalidRegistry = canonicalObject
        invalidRegistry["locale"] = "unreviewed"
        expect((try? MugsyNotificationCopyCatalog(data: JSONSerialization.data(withJSONObject: invalidRegistry))) == nil, "Unreviewed locales fail closed")
        invalidRegistry = canonicalObject
        invalidRegistry["version"] = 2
        expect((try? MugsyNotificationCopyCatalog(data: JSONSerialization.data(withJSONObject: invalidRegistry))) == nil, "Unreviewed registry versions fail closed")
        var changedTemplates = canonicalObject["templates"] as! [[String: Any]]
        changedTemplates[0]["requires"] = []
        invalidRegistry = canonicalObject
        invalidRegistry["templates"] = changedTemplates
        expect((try? MugsyNotificationCopyCatalog(data: JSONSerialization.data(withJSONObject: invalidRegistry))) == nil, "A template cannot drop its eligibility fact")
        changedTemplates = canonicalObject["templates"] as! [[String: Any]]
        changedTemplates[0]["asset"] = "MugsyIdentityMaster"
        invalidRegistry["templates"] = changedTemplates
        expect((try? MugsyNotificationCopyCatalog(data: JSONSerialization.data(withJSONObject: invalidRegistry))) == nil, "A template cannot replace approved artwork")
        changedTemplates = canonicalObject["templates"] as! [[String: Any]]
        changedTemplates[0]["id"] = "second_memory_1"
        invalidRegistry["templates"] = changedTemplates
        expect((try? MugsyNotificationCopyCatalog(data: JSONSerialization.data(withJSONObject: invalidRegistry))) == nil, "Duplicate variants fail closed")
        changedTemplates = canonicalObject["templates"] as! [[String: Any]]
        changedTemplates[0]["title"] = "A title\nwith a second line"
        invalidRegistry["templates"] = changedTemplates
        expect((try? MugsyNotificationCopyCatalog(data: JSONSerialization.data(withJSONObject: invalidRegistry))) == nil, "Multiline headlines fail closed")
        var reversedRegistry = canonicalObject
        reversedRegistry["templates"] = (canonicalObject["templates"] as! [[String: Any]]).reversed().map { $0 }
        let reversed = try MugsyNotificationCopyCatalog(data: JSONSerialization.data(withJSONObject: reversedRegistry))
        expect(catalog.select(family: .secondMemory, facts: facts, recentUses: [], now: now, rotationKey: "local-fixture")
            == reversed.select(family: .secondMemory, facts: facts, recentUses: [], now: now, rotationKey: "local-fixture"), "Registry order does not change deterministic selection")
        var envelope: [String: Any] = [
            "version": 1,
            "recipient_id": UUID().uuidString,
            "occurrence_id": UUID().uuidString,
            "expires_at": ISO8601DateFormatter().string(from: now.addingTimeInterval(100)),
            "asset_id": "MugsyPoseJournal",
            "template_id": "second_memory_1"
        ]
        func asset(_ payload: [String: Any]) -> String? {
            MugsyNotificationAttachmentPolicy.assetIdentifier(userInfo: ["mugshot_mugsy": payload], now: now)
        }
        expect(asset(envelope) == "MugsyPoseJournal", "Approved artwork is eligible")
        for bad in ["../../secret", "https://example.invalid/private.jpg", "MugsyIdentityMaster", ""] {
            var invalid = envelope
            invalid["asset_id"] = bad
            expect(asset(invalid) == nil, "Only approved bundled PNGs can be selected")
        }
        var invalid = envelope
        invalid["version"] = 2
        expect(asset(invalid) == nil, "Unknown payload version retains plain text")
        invalid = envelope
        invalid["expires_at"] = ISO8601DateFormatter().string(from: now)
        expect(asset(invalid) == nil, "Expired artwork is not attached")
        invalid = envelope
        invalid["recipient_id"] = "another-account"
        expect(asset(invalid) == nil, "Malformed owner envelope retains plain text")
        invalid = envelope
        invalid["occurrence_id"] = "not-an-occurrence"
        expect(asset(invalid) == nil, "Malformed occurrence retains plain text")
        invalid = envelope
        invalid["expires_at"] = "not-a-date"
        expect(asset(invalid) == nil, "Invalid expiry retains plain text")
        invalid = envelope
        invalid["template_id"] = "second_memory_42"
        expect(asset(invalid) == nil, "Unreviewed variants retain plain text")
        expect(MugsyNotificationAttachmentPolicy.assetIdentifier(userInfo: [:], now: now) == nil, "Other notification kinds retain plain text")
        invalid = envelope
        invalid["template_id"] = "weekly_pour_1"
        invalid["asset_id"] = "MugsyPoseCamera"
        expect(asset(invalid) == nil, "Artwork must belong to the reviewed message family")
        envelope["expires_at"] = "2026-11-25T13:00:00.123Z"
        expect(asset(envelope) != nil, "Fractional ISO timestamps are supported")
        let resultLock = NSLock()
        var results: [Int] = []
        let gate = MugsyNotificationCompletionGate(fallback: 0) { value in
            resultLock.lock()
            results.append(value)
            resultLock.unlock()
        }
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            gate.finish(index.isMultiple(of: 2) ? nil : index)
        }
        expect(results.count == 1, "Expiry and processing race completes exactly once")
        expect(!gate.finish(9), "A completed notification cannot call the handler again")
        print("Mugsy creative contracts: \(checks) checks passed")
    }
}
