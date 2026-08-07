import MapKit
import SwiftUI
import UniformTypeIdentifiers
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 250 / 255, green: 246 / 255, blue: 240 / 255, alpha: 1)

        let model = ShareImportViewModel(extensionContext: extensionContext)
        let host = UIHostingController(
            rootView: ShareImportView(model: model) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
}

@MainActor
final class ShareImportViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case searching
        case results
        case noResults
        case offline(String)
        case saved
    }

    @Published var query = ""
    @Published var results: [MKMapItem] = []
    @Published var selected: MKMapItem?
    @Published var wantToTry = true
    @Published var selectedListID: UUID?
    @Published var note = ""
    @Published var state: State = .loading

    let eligibleLists = ExtensionImportStore.eligibleLists()
    private(set) var source: ExtensionPlaceImportSource = .text
    private weak var extensionContext: NSExtensionContext?
    private var searchTask: Task<Void, Never>?

    init(extensionContext: NSExtensionContext?) {
        self.extensionContext = extensionContext
        Task { await loadSharedClue() }
    }

    func search() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .noResults
            results = []
            return
        }
        state = .searching
        searchTask = Task {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = trimmed
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe])
                let response = try await MKLocalSearch(request: request).start()
                try Task.checkCancellation()
                var seen = Set<String>()
                results = response.mapItems.compactMap { item in
                    guard let identifier = item.identifier?.rawValue,
                          seen.insert(identifier).inserted else { return nil }
                    return item
                }
                .prefix(12)
                .map { $0 }
                state = results.isEmpty ? .noResults : .results
            } catch is CancellationError {
                return
            } catch {
                results = []
                state = .offline("Apple Maps search needs a connection. Check your network and try again.")
            }
        }
    }

    func choose(_ item: MKMapItem) {
        selected = item
    }

    func save() throws {
        guard let selected,
              let appleID = selected.identifier?.rawValue,
              let name = selected.name else { return }
        let coordinate = selected.placemark.coordinate
        let selectedList = eligibleLists.first { $0.id == selectedListID }
        let command = ExtensionPendingPlaceImport(
            commandID: UUID(),
            appleMapsPlaceID: appleID,
            name: name,
            address: selected.placemark.title,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            phoneNumber: selected.phoneNumber,
            websiteURL: selected.url?.absoluteString,
            source: source,
            wantToTry: wantToTry,
            destinationListID: selectedList?.id,
            destinationListTitle: selectedList?.title,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            accountContext: selectedList?.accountID ?? eligibleLists.first?.accountID,
            retryState: "queued",
            createdAt: Date()
        )
        try ExtensionImportStore.append(command)
        state = .saved
    }

    private func loadSharedClue() async {
        var sharedURL: URL?
        var sharedText: String?
        var suggestedName: String?

        for item in extensionContext?.inputItems.compactMap({ $0 as? NSExtensionItem }) ?? [] {
            if sharedText == nil { sharedText = item.attributedContentText?.string }
            for provider in item.attachments ?? [] {
                if suggestedName == nil { suggestedName = provider.suggestedName }
                if sharedURL == nil,
                   provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let value = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
                   let url = value as? URL {
                    sharedURL = url
                }
                if sharedText == nil,
                   provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let value = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                    sharedText = value as? String
                        ?? (value as? NSAttributedString)?.string
                }
            }
        }

        let clue = await SharedPlaceClueExtractor.clue(
            url: sharedURL,
            text: sharedText,
            suggestedName: suggestedName
        )
        query = clue.query
        source = clue.source
        if query.isEmpty {
            state = .noResults
        } else {
            search()
        }
    }
}

private struct ShareImportView: View {
    @ObservedObject var model: ShareImportViewModel
    let onFinished: () -> Void

    private let sage = Color(red: 110 / 255, green: 143 / 255, blue: 124 / 255)
    private let espresso = Color(red: 31 / 255, green: 23 / 255, blue: 18 / 255)
    private let cream = Color(red: 250 / 255, green: 246 / 255, blue: 240 / 255)

    var body: some View {
        NavigationStack {
            Group {
                if model.state == .saved {
                    savedState
                } else if let selected = model.selected {
                    saveForm(selected)
                } else {
                    searchResults
                }
            }
            .background(cream.ignoresSafeArea())
            .navigationTitle("Save cafe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.state != .saved {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onFinished)
                    }
                }
            }
        }
        .tint(sage)
    }

    private var searchResults: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search Apple Maps", text: $model.query)
                    .submitLabel(.search)
                    .onSubmit(model.search)
                Button("Search", action: model.search)
                    .font(.system(size: 13, weight: .bold))
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)

            switch model.state {
            case .loading, .searching:
                Spacer()
                ProgressView(model.state == .loading ? "Reading shared place…" : "Searching Apple Maps…")
                Spacer()
            case .offline(let message):
                Spacer()
                ContentUnavailableView(
                    "Apple Maps is unavailable",
                    systemImage: "wifi.exclamationmark",
                    description: Text(message)
                )
                Button("Try again", action: model.search)
                    .buttonStyle(.borderedProminent)
                Spacer()
            case .noResults:
                Spacer()
                ContentUnavailableView(
                    "Choose an Apple Maps result",
                    systemImage: "mappin.and.ellipse",
                    description: Text("Search by cafe name or neighborhood. Mugshot won’t guess from a social link.")
                )
                Spacer()
            case .results:
                List(model.results, id: \.self) { item in
                    Button { model.choose(item) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name ?? "Cafe")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(espresso)
                            Text(item.placemark.title ?? "Apple Maps place")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
            case .saved:
                EmptyView()
            }
        }
        .padding(.top, 12)
    }

    private func saveForm(_ item: MKMapItem) -> some View {
        Form {
            Section("Apple Maps result") {
                HStack(spacing: 12) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(sage)
                        .frame(width: 42, height: 42)
                        .background(sage.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name ?? "Cafe")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(espresso)
                        Text(item.placemark.title ?? "Apple Maps place")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Choose a different result") { model.selected = nil }
            }

            Section("Save") {
                Toggle("Want to Try", isOn: $model.wantToTry)
                if !model.eligibleLists.isEmpty {
                    Picker("Add to list", selection: $model.selectedListID) {
                        Text("No list").tag(UUID?.none)
                        ForEach(model.eligibleLists) { list in
                            Text(list.title).tag(Optional(list.id))
                        }
                    }
                }
                TextField("Private note (optional)", text: $model.note, axis: .vertical)
                    .lineLimit(2 ... 4)
            }

            Section {
                Button {
                    do {
                        try model.save()
                    } catch {
                        model.state = .offline("Mugshot couldn’t save this import. Please try again.")
                    }
                } label: {
                    Text("Save to Mugshot")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.wantToTry && model.selectedListID == nil)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var savedState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(sage)
            Text("Saved to Mugshot")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(espresso)
            Text("It will sync the next time Mugshot opens.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Button("Done", action: onFinished)
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(24)
    }
}
