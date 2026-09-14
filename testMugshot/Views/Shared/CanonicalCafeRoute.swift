import SwiftUI

struct CanonicalCafeRoute: Identifiable {
    let cafeID: UUID
    let cafe: Cafe?

    var id: UUID { cafeID }
}

struct CanonicalCafeUnavailableView: View {
    let cafeID: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Cafe unavailable",
                systemImage: "cup.and.saucer",
                description: Text("This cafe can’t be opened from your current account.")
            )
            .navigationTitle("Cafe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
            .accessibilityIdentifier("cafe.unavailable.\(cafeID.uuidString)")
        }
    }
}
