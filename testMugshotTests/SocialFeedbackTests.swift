import Foundation
import Testing
@testable import testMugshot

@MainActor
struct SocialFeedbackTests {
    enum Failure: Error { case offline }

    @Test func failedOptimisticSaveRestoresPriorStateExactlyOnce() async {
        var selected = true
        var rollbackCount = 0
        do {
            try await MugshotOptimisticAction.perform(isCurrent: { true }, request: { () async throws -> Bool in
                throw Failure.offline
            }, commit: { selected = $0 }, rollback: { selected = false; rollbackCount += 1 })
            Issue.record("Request must fail")
        } catch {}
        #expect(!selected)
        #expect(rollbackCount == 1)
    }

    @Test func staleAccountCannotCommitOrRollBackNewerState() async {
        for fails in [false, true] {
            var current = true
            var changes = 0
            _ = try? await MugshotOptimisticAction.perform(isCurrent: { current }, request: {
                current = false
                if fails { throw Failure.offline }
                return true
            }, commit: { _ in changes += 1 }, rollback: { changes += 1 })
            #expect(changes == 0)
        }
    }

    @Test func confirmedCommentSurvivesRefreshFailureWithoutAnotherSubmission() async throws {
        var submissions = 0
        let refreshed: Bool? = try await MugshotConfirmedAction.perform(commit: {
            submissions += 1
        }, refresh: { throw Failure.offline })
        #expect(refreshed == nil)
        #expect(submissions == 1)
    }

    @Test func failedCommentNeverRefreshesOrReportsACommit() async {
        var reads = 0
        do {
            let _: Bool? = try await MugshotConfirmedAction.perform(commit: { throw Failure.offline }, refresh: {
                reads += 1
                return true
            })
            Issue.record("Failed commit must propagate")
        } catch {}
        #expect(reads == 0)
    }
}
