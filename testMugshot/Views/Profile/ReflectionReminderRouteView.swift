import SwiftUI

struct ReflectionReminderRouteView: View {
    let route: PendingReflectionReminderRoute
    @ObservedObject var dataManager: DataManager
    let onFinished: () -> Void

    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @State private var summary: RemoteVisitSummary?
    @State private var reminder: ReflectionReminderRecord?
    @State private var weeklyVisits: [RemoteVisitSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            destinationContent
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { finish() }
                }
            }
        }
        .task(id: route.id) { await load() }
        .onDisappear(perform: onFinished)
    }

    @ViewBuilder
    private var destinationContent: some View {
        if isLoading {
            ProgressView("Opening your reflection…")
        } else if let errorMessage {
            ContentUnavailableView(
                "Reflection unavailable",
                systemImage: "book.closed",
                description: Text(errorMessage)
            )
        } else if let reminder, reminder.kind == .weekly {
            weeklyContent(reminder)
        } else if let summary {
            RemoteVisitDetailView(
                visitId: summary.id,
                initialSummary: summary,
                currentUserId: route.accountID,
                dataManager: dataManager
            )
        } else {
            ContentUnavailableView(
                "Reflection unavailable",
                systemImage: "book.closed",
                description: Text("This reminder is no longer available to this account.")
            )
        }
    }

    private func weeklyContent(_ reminder: ReflectionReminderRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your week in Mugshot")
                        .font(.title2.bold())
                        .foregroundStyle(Color.espressoBrown)
                    Text(weekDateRange(reminder))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                    Text("\(weeklyVisits.count) \(weeklyVisits.count == 1 ? "MugShot" : "MugShots") to revisit")
                        .font(.headline)
                        .foregroundStyle(Color.espressoBrown)
                }

                if weeklyVisits.isEmpty {
                    ContentUnavailableView(
                        "No MugShots from this week",
                        systemImage: "book.closed",
                        description: Text("A MugShot from this reflection may have been removed.")
                    )
                } else {
                    ForEach(weeklyVisits) { visit in
                        NavigationLink {
                            RemoteVisitDetailView(
                                visitId: visit.id,
                                initialSummary: visit,
                                currentUserId: route.accountID,
                                dataManager: dataManager
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(visit.visit.drinkDisplayName)
                                    .font(.headline)
                                    .foregroundStyle(Color.espressoBrown)
                                Text(visit.cafe?.name ?? visit.visit.locationName ?? "A sip you saved")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondaryText)
                                Text(visit.visit.createdAtDate, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.creamWhite)
    }

    private func weekDateRange(_ reminder: ReflectionReminderRecord) -> String {
        guard let start = reminder.weekStart, let end = reminder.scheduledDate else { return "Past seven days" }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: reminder.timezoneName)
        formatter.dateStyle = .medium
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    @MainActor
    private func load() async {
        guard authModel.authenticatedUser?.id == route.accountID else {
            isLoading = false
            errorMessage = "Sign in to the account that owns this reflection."
            return
        }
        do {
            let client = try SupabaseClientProvider.shared.client()
            let records = try await ReflectionReminderService(client: client).delivered(
                accountID: route.accountID,
                limit: 1,
                occurrenceID: route.occurrenceID
            )
            guard let record = records.first, record.destination == route.destination else {
                errorMessage = "This reminder is no longer available to this account."
                isLoading = false
                return
            }
            reminder = record
            let visits = VisitService(client: client)
            switch route.destination {
            case .memory(let visitID):
                summary = try await visits.fetchOwnedVisitSummary(
                    visitId: visitID,
                    userId: route.accountID
                )
                if summary?.visit.uploadState != VisitUploadState.complete.rawValue {
                    summary = nil
                    errorMessage = "This MugShot has not finished publishing."
                }
            case .journal:
                guard let start = record.weekStart, let end = record.scheduledDate else {
                    errorMessage = "This reflection could not be dated."
                    isLoading = false
                    return
                }
                weeklyVisits = try await visits.fetchOwnedVisits(
                    userId: route.accountID,
                    from: start,
                    before: end
                )
            }
        } catch {
            errorMessage = MugshotUserFacingError.message(for: error, context: .loading)
        }
        isLoading = false
    }

    private func finish() {
        onFinished()
        dismiss()
    }
}
