import SwiftUI

struct ModerationCasesView: View {
    let accountID: UUID
    @Environment(\.scenePhase) private var scenePhase
    @State private var kind = "report"
    @State private var status = "pending"
    @State private var items: [ModerationReviewCase] = []
    @State private var loading = false
    @State private var hasMore = false
    @State private var message: String?
    @State private var requestID = UUID()

    var body: some View {
        List {
            Picker("Cases", selection: $kind) {
                Text("Reports").tag("report")
                Text("Appeals").tag("appeal")
            }
            Picker("Status", selection: $status) {
                Text("Pending").tag("pending")
                Text("Under review").tag("reviewing")
                Text("Closed").tag("closed")
            }
            if loading { ProgressView("Loading cases…") }
            if let message {
                Text(message)
                Button("Try again") { Task { await load(more: false) } }
            }
            if !loading && message == nil && items.isEmpty { Text("No cases in this queue.") }
            ForEach(items) { item in
                NavigationLink {
                    ModerationCaseDetailView(accountID: accountID, original: item)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title).font(.headline)
                        Text(item.reason.replacingOccurrences(of: "_", with: " ").capitalized)
                        Text("Reference \(item.id.uuidString.prefix(8).lowercased())")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if hasMore {
                Button("Load more") { Task { await load(more: true) } }.disabled(loading)
            }
        }
        .navigationTitle("Reports and Appeals")
        .task(id: "\(kind)-\(status)-\(scenePhase)") {
            clear()
            if scenePhase == .active { await load(more: false) }
        }
        .refreshable { await load(more: false) }
    }

    private func clear() { requestID = UUID(); items = []; message = nil; hasMore = false; loading = false }

    @MainActor private func load(more: Bool) async {
        let request = UUID(); requestID = request
        loading = true; message = nil
        defer { if requestID == request { loading = false } }
        do {
            let page = try await ContentScreeningService(accountID: accountID)
                .cases(kind: kind, status: status, after: more ? items.last : nil)
            guard !Task.isCancelled, requestID == request, scenePhase == .active else { return }
            if more {
                let existing = Set(items.map(\.id))
                items += page.filter { !existing.contains($0.id) }
            } else { items = page }
            hasMore = page.count == 25
        } catch {
            guard requestID == request else { return }
            items = []; hasMore = false
            if !Task.isCancelled { message = "Cases are unavailable or your review access has changed." }
        }
    }
}

private struct ModerationCaseDetailView: View {
    let accountID: UUID
    let original: ModerationReviewCase
    @Environment(\.scenePhase) private var scenePhase
    @State private var current: ModerationReviewCase?
    @State private var currentContent: ContentScreeningItem?
    @State private var resolution = ""
    @State private var newStatus = "resolved"
    @State private var action = ""
    @State private var endsAt = Date.now.addingTimeInterval(86400)
    @State private var busy = false
    @State private var confirming = false
    @State private var message: String?
    @State private var requestID = UUID()

    private var reasonLimit: Int { original.kind == "report" ? 80 : 1000 }
    private var validReason: Bool {
        (1...reasonLimit).contains(resolution.trimmingCharacters(in: .whitespacesAndNewlines).count)
    }

    var body: some View {
        Form {
            if let message { Text(message) }
            if let current {
                Section("Case") {
                    LabeledContent("Status", value: current.status.capitalized)
                    LabeledContent("Reason", value: current.reason.replacingOccurrences(of: "_", with: " "))
                    if let statement = current.statement { Text(statement) }
                    if let text = current.subject_text, !text.isEmpty {
                        Text("Saved report text").font(.caption).foregroundStyle(.secondary)
                        Text(text)
                    }
                    if let action = current.action_kind {
                        LabeledContent("Enforcement", value: action.replacingOccurrences(of: "_", with: " "))
                    }
                    if let ends = current.ends_at, let date = ModerationDateParser.date(from: ends) {
                        LabeledContent("Ends", value: date.formatted())
                    }
                    if current.revoked_at != nil { Text("This enforcement action has been revoked.") }
                    if let resolution = current.resolution { Text("Resolution: \(resolution)") }
                    if current.kind == "report" {
                        if let currentContent {
                            NavigationLink("Inspect current shared content") {
                                ScreeningDetailView(accountID: accountID, item: currentContent, reviewing: true)
                            }
                        } else {
                            Text("Current shared content is unavailable. It may be Private, deleted, or outside screening. Saved report evidence remains separate.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if current.self_review_conflict {
                    Text("Another appointed reviewer must handle this case because it involves your report, content, or appeal.")
                } else if current.isOpen {
                    Section("Decision") {
                        Picker("Outcome", selection: $newStatus) {
                            if current.kind == "report" {
                                Text("Resolve report").tag("resolved")
                                Text("Dismiss report").tag("dismissed")
                            } else {
                                Text("Uphold enforcement").tag("upheld")
                                Text("Reverse enforcement").tag("reversed")
                                if current.revoked_at == nil { Text("Shorten enforcement").tag("modified") }
                            }
                            if current.status == "pending" { Text("Start review").tag("reviewing") }
                        }
                        if current.kind == "report" && newStatus == "resolved" {
                            Picker("Enforcement action", selection: $action) {
                                Text("No enforcement action").tag("")
                                if ["visit", "comment", "cafe_list_comment"].contains(current.target_kind) {
                                    Text("Hide reported content").tag("content_hidden")
                                }
                                Text("Warn the content owner").tag("warning")
                                Text("Restrict owner's social access").tag("social_restricted")
                                Text("Suspend owner's account").tag("account_suspended")
                            }
                            if ["social_restricted", "account_suspended"].contains(action) {
                                Text("This action has no scheduled end. It can be reversed through an appeal or by a moderation administrator.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        if current.kind == "appeal" && newStatus == "modified" {
                            DatePicker("New end", selection: $endsAt, in: Date.now...)
                            Text("The new end must be earlier than the existing end, if one is set.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        TextEditor(text: $resolution).frame(minHeight: 110)
                            .accessibilityLabel("Resolution reason")
                        Text("\(resolution.count) of \(reasonLimit) characters. This resolution is visible to the affected member.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Review and record decision") { confirming = true }
                            .disabled(!validReason)
                    }.disabled(busy)
                }
                Section("Recent review history") {
                    ForEach(Array(current.history.enumerated()), id: \.offset) { _, event in
                        VStack(alignment: .leading) {
                            Text(event.event_kind.replacingOccurrences(of: "_", with: " ").capitalized)
                            if let note = event.internal_note { Text(note).font(.footnote) }
                        }
                    }
                }
            }
            Button(busy ? "Loading…" : "Refresh case") { Task { await load() } }.disabled(busy)
        }
        .navigationTitle(original.title)
        .confirmationDialog("Record \(newStatus)\(action.isEmpty || newStatus != "resolved" ? "" : " with " + action.replacingOccurrences(of: "_", with: " "))?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Record decision", role: .destructive) { Task { await submit() } }
        }
        .task(id: scenePhase) {
            clear()
            newStatus = original.kind == "report" ? "resolved" : "upheld"
            if scenePhase == .active { await load() }
        }
    }

    private func clear() {
        requestID = UUID(); current = nil; currentContent = nil; resolution = ""; action = ""
        confirming = false; message = nil; busy = false
    }

    @MainActor private func load() async {
        let request = UUID(); requestID = request
        busy = true; current = nil; currentContent = nil; message = nil
        defer { if requestID == request { busy = false } }
        do {
            let service = try ContentScreeningService(accountID: accountID)
            let item = try await service.reviewCase(original)
            let content = item?.kind == "report" ? try await service.reportContent(original.id) : nil
            guard !Task.isCancelled, requestID == request, scenePhase == .active else { return }
            current = item
            currentContent = content
            newStatus = original.kind == "report" ? "resolved" : "upheld"
            action = ""; confirming = false
            if item == nil { message = "This case is no longer available." }
        } catch {
            if requestID == request && !Task.isCancelled { message = "Couldn’t load this case. Refresh to try again." }
        }
    }

    @MainActor private func submit() async {
        guard !busy, validReason, let current else { return }
        let request = UUID(); requestID = request; busy = true
        defer { if requestID == request { busy = false } }
        do {
            let applied = try await ContentScreeningService(accountID: accountID).resolveCase(
                current, status: newStatus, resolution: resolution.trimmingCharacters(in: .whitespacesAndNewlines),
                action: newStatus == "resolved" ? action : "", endsAt: newStatus == "modified" ? endsAt : nil
            )
            guard !Task.isCancelled, requestID == request, scenePhase == .active else { return }
            self.current = nil; resolution = ""
            message = applied ? "Decision recorded. Refresh to see the updated case." : "The case changed. Refresh before deciding."
        } catch {
            guard requestID == request else { return }
            self.current = nil
            message = "The decision could not be confirmed. Refresh before retrying. A shortened action must have a future end earlier than its current end."
        }
    }
}
