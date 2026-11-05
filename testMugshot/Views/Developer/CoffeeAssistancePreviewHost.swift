#if DEBUG
import SwiftUI
import UIKit

/// Synthetic, network-free acceptance of the actual consent and review surface.
struct CoffeeAssistancePreviewHost: View {
    private let owner = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    @State private var origin = "Original origin"
    @State private var presentation: CoffeeAssistancePresentation?
    init() {
        if MugshotLaunchEnvironment.shouldResetUITestState {
            CoffeeAssistancePermissionStore.shared.removeAll(ownerID: owner)
        }
    }
    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-auto-bag-scan") {
            AutomaticBagScanPreviewHost()
        } else { helperBody }
    }
    private var helperBody: some View {
        NavigationStack {
            Form {
                Section("Original editable details") {
                    Text(origin).accessibilityIdentifier("coffeeAssistance.fixture.origin")
                    Button("Inspect bag helper") {
                        presentation = CoffeeAssistancePresentation(ownerID: owner, task: .bagScan,
                            query: "Read the printed origin",
                            evidence: [CoffeeAssistanceEvidence(id: "bag-1", title: "Fictional bag", detail: "Origin: Colombia")],
                            image: nil, allowsPhoto: false)
                    }.accessibilityIdentifier("coffeeAssistance.fixture.open")
                }
            }
            .navigationTitle("Optional helper inspection")
            .sheet(item: $presentation) { item in
                CoffeeAssistanceReviewSheet(presentation: item, onAccepted: { result in
                    if let selected = result.fields.first(where: { $0.key == "origin" }) { origin = selected.value }
                }, transport: FixtureTransport(), currentOwner: { owner })
            }
        }
    }
    private struct FixtureTransport: CoffeeAssistanceTransport {
        func suggest(_ request: CoffeeAssistanceRequest) async throws -> CoffeeAssistanceResult {
            try await Task.sleep(for: .milliseconds(100))
            if ProcessInfo.processInfo.arguments.contains("--ui-testing-coffee-assistance-failure") {
                throw CoffeeAssistanceError.unavailable
            }
            return CoffeeAssistanceResult(text: "The printed origin is Colombia. Check it before using.",
                evidenceIDs: ["bag-1"], fields: [CoffeeAssistanceField(key: "origin", value: "Colombia", sourceQuote: "Origin: Colombia")], searchTerms: [])
        }
    }
}
private struct AutomaticBagScanPreviewHost: View {
    private let owner = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    @State private var showsEditor = false
    @State private var savedOrigin = "Not saved"
    private let store = HomeLibraryStore(baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("AutomaticBagFixture"))
    var body: some View {
        NavigationStack {
            Form {
                Button("Load a bag photo") { showsEditor = true }.accessibilityIdentifier("home.bag.fixture.open")
                Text(savedOrigin).accessibilityIdentifier("home.bag.fixture.savedOrigin")
            }
            .sheet(isPresented: $showsEditor) {
                HomeCoffeeBagEditorSheet(configuration: .scan, scope: .user(owner), existingBags: [], store: store,
                    transport: ScanTransport(), currentOwner: { owner }, initialScanImage: fixtureImage) { bag in
                    savedOrigin = bag.origin
                    showsEditor = false
                }
            }
        }
    }
    private var fixtureImage: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 600, height: 480)).image { context in
            UIColor.white.setFill(); context.cgContext.fill(CGRect(x: 0, y: 0, width: 600, height: 480))
            let text = "ROASTER: Fixture Roaster\nCOFFEE: Fixture Coffee\nORIGIN: Colombia\nPROCESS: Washed"
            text.draw(in: CGRect(x: 40, y: 40, width: 520, height: 400), withAttributes: [.font: UIFont.systemFont(ofSize: 30), .foregroundColor: UIColor.black])
        }
    }
    private struct ScanTransport: CoffeeAssistanceTransport {
        func suggest(_ request: CoffeeAssistanceRequest) async throws -> CoffeeAssistanceResult {
            try await Task.sleep(for: .milliseconds(200))
            if ProcessInfo.processInfo.arguments.contains("--ui-testing-coffee-assistance-failure") { throw CoffeeAssistanceError.unavailable }
            return CoffeeAssistanceResult(text: "Printed bag details", evidenceIDs: [], fields: [
                CoffeeAssistanceField(key: "roaster", value: "Fixture Roaster", sourceQuote: "Fixture Roaster"),
                CoffeeAssistanceField(key: "name", value: "Fixture Coffee", sourceQuote: "Fixture Coffee"),
                CoffeeAssistanceField(key: "origin", value: "Colombia", sourceQuote: "Colombia")
            ], searchTerms: [])
        }
    }
}
#endif
