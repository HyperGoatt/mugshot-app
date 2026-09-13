import SwiftUI

struct ContentScreeningView: View {
    @EnvironmentObject private var authModel: AppAuthModel

    var body: some View {
        Group {
            if let accountID = authModel.authenticatedUser?.id {
                ScreeningAccountView(accountID: accountID).id(accountID)
            } else {
                ContentUnavailableView("Sign in required", systemImage: "person.badge.key")
            }
        }
        .navigationTitle("Shared Content Status")
    }
}

private struct ScreeningAccountView: View {
    let accountID: UUID
    @Environment(\.scenePhase) private var scenePhase
    @State private var items: [ContentScreeningItem] = []
    @State private var reviewer = false
    @State private var loading = false
    @State private var error: String?
    @State private var requestID = UUID()

    var body: some View {
        List {
            Section {
                Text("Shared content is checked before others can see it. Content awaiting screening or review remains available to you. Passing screening does not change your audience or profile consent.")
                Text("Private journal content is excluded. Shared text and supported photos are processed by OpenAI for safety screening, without opting into model training. Mugshot handles review decisions.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if reviewer {
                NavigationLink("Review shared content") {
                    ScreeningQueueView(accountID: accountID)
                }
                NavigationLink("Review reports and appeals") {
                    ModerationCasesView(accountID: accountID)
                }
            }
            Section("Your latest 100 screening records") {
                if loading { ProgressView("Checking status…") }
                if let error {
                    Text(error).foregroundStyle(.secondary)
                    Button("Try again") { Task { await load() } }
                } else if !loading && items.isEmpty {
                    Text("No screening records are available for this account.")
                }
                ForEach(items) { item in
                    NavigationLink {
                        ScreeningDetailView(accountID: accountID, item: item, reviewing: false)
                    } label: { ScreeningRow(item: item) }
                }
            }
        }
        .task(id: scenePhase) {
            if scenePhase == .active { await load() } else { clear() }
        }
        .refreshable { await load() }
    }

    private func clear() { requestID = UUID(); loading = false; items = []; reviewer = false; error = nil }

    @MainActor private func load() async {
        guard !loading else { return }
        let request = UUID(); requestID = request
        loading = true
        defer { if requestID == request { loading = false } }
        do {
            let service = try ContentScreeningService(accountID: accountID)
            let statuses = try await service.status()
            let role = try await service.role()
            guard !Task.isCancelled, requestID == request, scenePhase == .active else { return }
            items = statuses; reviewer = role != nil; error = nil
        } catch {
            guard requestID == request else { return }
            clear()
            if !Task.isCancelled { self.error = "Screening status is unavailable. Try again when connected." }
        }
    }
}

private struct ScreeningRow: View {
    let item: ContentScreeningItem
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title).font(.headline)
            Text(item.stateTitle).font(.subheadline)
            if let date = ModerationDateParser.date(from: item.updated_at) {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Reference \(item.subject_id.uuidString.prefix(8).lowercased())")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct ScreeningQueueView: View {
    let accountID: UUID
    @Environment(\.scenePhase) private var scenePhase
    @State private var items: [ContentScreeningItem] = []
    @State private var filter = "needs_review"
    @State private var loading = false
    @State private var hasMore = false
    @State private var error: String?
    @State private var requestID = UUID()

    var body: some View {
        List {
            Picker("Queue", selection: $filter) {
                Text("Awaiting review").tag("needs_review")
                Text("Pending screening").tag("pending")
                Text("Rejected").tag("rejected")
                Text("Approved").tag("approved")
            }
            if let error {
                Text(error)
                Button("Try again") { Task { await load(more: false) } }
            }
            if loading { ProgressView("Loading queue…") }
            if !loading && error == nil && items.isEmpty { Text("No content in this queue.") }
            ForEach(items) { item in
                NavigationLink {
                    ScreeningDetailView(accountID: accountID, item: item, reviewing: true)
                } label: { ScreeningRow(item: item) }
            }
            if hasMore {
                Button("Load more") { Task { await load(more: true) } }.disabled(loading)
            }
        }
        .navigationTitle("Content Review")
        .task(id: "\(filter)-\(scenePhase)") {
            requestID = UUID(); loading = false; error = nil
            items = []; hasMore = false
            if scenePhase == .active { await load(more: false) }
        }
        .refreshable { await load(more: false) }
    }

    @MainActor private func load(more: Bool) async {
        let request = UUID(); requestID = request
        let expectedFilter = filter
        loading = true; error = nil
        defer { if requestID == request { loading = false } }
        do {
            let page = try await ContentScreeningService(accountID: accountID)
                .queue(state: expectedFilter, after: more ? items.last : nil)
            guard !Task.isCancelled, requestID == request, filter == expectedFilter, scenePhase == .active else { return }
            if more {
                let existing = Set(items.map(\.id))
                items += page.filter { !existing.contains($0.id) }
            } else { items = page }
            hasMore = page.count == 25
        } catch {
            guard requestID == request, filter == expectedFilter else { return }
            items = []; hasMore = false
            if !Task.isCancelled { self.error = "The review queue is unavailable or your review access has changed." }
        }
    }
}

struct ScreeningDetailView: View {
    let accountID: UUID
    let item: ContentScreeningItem
    let reviewing: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var current: ContentScreeningItem?
    @State private var reason = ""
    @State private var busy = false
    @State private var message: String?
    @State private var decision: String?
    @State private var previewGeneration = UUID()
    @State private var loadedImages: Set<Int> = []
    @State private var requestID = UUID()

    private var validReason: Bool {
        let count = reason.trimmingCharacters(in: .whitespacesAndNewlines).count
        return (1...1000).contains(count)
    }

    var body: some View {
        Form {
            if let message { Text(message) }
            if let current {
                Section { ScreeningRow(item: current) }
                if reviewing {
                    Section("Current shared content") {
                        Text(current.payload?.text ?? "No shared text")
                        ForEach(Array((current.media_urls ?? []).enumerated()), id: \.offset) { index, url in
                            ScreeningReviewImage(url: url.flatMap(URL.init(string:))) {
                                loadedImages.insert(index)
                            }.id(previewGeneration)
                        }
                    }
                    Section("Screening signals") {
                        Text((current.reason ?? "No automated reason").replacingOccurrences(of: "_", with: " ").capitalized)
                        ForEach((current.evidence?.categories ?? [:]).filter { $0.value }.map(\.key).sorted(), id: \.self) { category in
                            Text(category.replacingOccurrences(of: "_", with: " ").capitalized)
                        }
                        Text("Automated flags are signals for your review. Read the content and record your own reason.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Review history") {
                        ForEach(Array((current.history ?? []).enumerated()), id: \.offset) { _, event in
                            Text("\(event.decision.capitalized): \(event.reason)")
                        }
                    }
                } else if let reviewReason = current.review_reason {
                    Section("Review reason") { Text(reviewReason) }
                }
                if reviewing && current.self_review_conflict == true {
                    Text("Another appointed reviewer must decide on your own content.")
                } else if reviewing || (["needs_review", "rejected"].contains(current.state) && current.appeal_requested_at == nil) {
                    Section(reviewing ? "Reason shown to the owner if rejected" : "What should the reviewer know?") {
                        TextEditor(text: $reason).frame(minHeight: 110)
                            .accessibilityLabel("Review reason")
                        Text("\(reason.count) of 1,000 characters").font(.caption)
                        if reviewing {
                            Button("Approve sharing") { decision = "approved" }
                                .disabled(busy || !validReason || loadedImages.count != (current.payload?.images.count ?? 0))
                            Button("Reject sharing", role: .destructive) { decision = "rejected" }
                                .disabled(busy || !validReason)
                        } else {
                            Button("Request reconsideration") { Task { await submit(nil) } }
                                .disabled(busy || !validReason)
                        }
                    }.disabled(busy)
                } else if current.appeal_requested_at != nil {
                    Text("Your reconsideration request is recorded. Mugshot will review it here; there is no guaranteed response time during alpha.")
                }
            }
            Button(busy ? "Loading…" : "Refresh current status") { Task { await load() } }.disabled(busy)
        }
        .navigationTitle(reviewing ? "Review Content" : "Content Status")
        .confirmationDialog("Record this review decision?", isPresented: Binding(
            get: { decision != nil }, set: { if !$0 { decision = nil } }
        ), titleVisibility: .visible) {
            Button(decision == "approved" ? "Approve sharing" : "Reject sharing",
                   role: decision == "rejected" ? .destructive : nil) {
                let chosen = decision; decision = nil
                Task { await submit(chosen) }
            }
        }
        .task(id: scenePhase) {
            clear()
            guard scenePhase == .active else { return }
            await load()
        }
        .task(id: previewGeneration) {
            // Each fresh preview has its own expiration, including manual refreshes.
            if reviewing && current != nil {
                do { try await Task.sleep(for: .seconds(55)) } catch { return }
                current = nil; message = "Preview expired. Refresh before deciding."
            }
        }
        .onDisappear { clear() }
    }

    private func clear() {
        requestID = UUID(); current = nil; reason = ""; decision = nil
        busy = false; loadedImages = []; previewGeneration = UUID()
    }

    @MainActor private func load() async {
        guard !busy else { return }
        let request = UUID(); requestID = request
        busy = true; current = nil; message = nil; loadedImages = []; previewGeneration = UUID()
        defer { if requestID == request { busy = false } }
        do {
            let service = try ContentScreeningService(accountID: accountID)
            let result: ContentScreeningItem?
            if reviewing { result = try await service.preview(item) }
            else { result = try await service.status().first { $0.id == item.id } }
            guard !Task.isCancelled, requestID == request, scenePhase == .active else { return }
            current = result
            previewGeneration = UUID()
            if result == nil { message = "This content changed or is no longer available. Return to the list and refresh." }
        } catch {
            if requestID == request && !Task.isCancelled { message = "Couldn’t load current content. Refresh to try again." }
        }
    }

    @MainActor private func submit(_ decision: String?) async {
        guard !busy, validReason, let current else { return }
        let request = UUID(); requestID = request
        busy = true
        defer { if requestID == request { busy = false } }
        do {
            let applied = try await ContentScreeningService(accountID: accountID)
                .decide(current, decision: decision, reason: reason.trimmingCharacters(in: .whitespacesAndNewlines))
            guard !Task.isCancelled, requestID == request, scenePhase == .active else { return }
            self.current = nil; reason = ""
            message = applied ? "Your decision or request was recorded. Refresh to see its current status." : "The content changed. Return to the list and refresh before reviewing."
        } catch {
            guard requestID == request else { return }
            self.current = nil
            message = "Delivery couldn’t be confirmed. Refresh the status before trying again."
        }
    }
}

private struct ScreeningReviewImage: View {
    let url: URL?
    let onLoaded: () -> Void
    @State private var image: UIImage?
    @State private var failed = false
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else if failed { Text("Photo unavailable. Do not approve content you cannot inspect.") }
            else { ProgressView("Loading photo…") }
        }
        .task(id: url) {
            image = nil; failed = false
            guard let url, url.scheme == "https" else { failed = true; return }
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.timeoutIntervalForRequest = 15
            let session = URLSession(configuration: config)
            defer { session.invalidateAndCancel() }
            do {
                let (data, response) = try await session.data(from: url)
                guard !Task.isCancelled else { return }
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      data.count <= 8 * 1024 * 1024, let decoded = UIImage(data: data) else {
                    failed = true; return
                }
                image = decoded
                onLoaded()
            } catch { if !Task.isCancelled { failed = true } }
        }
        .onDisappear { image = nil }
    }
}
