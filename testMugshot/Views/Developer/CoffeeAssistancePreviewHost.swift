#if DEBUG
import SwiftUI

/// Synthetic, network-free acceptance of the actual consent and review surface.
struct CoffeeAssistancePreviewHost: View {
    private let owner = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    @State private var origin = "Original origin"
    @State private var presentation: CoffeeAssistancePresentation?
    var body: some View {
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
#endif
