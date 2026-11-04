import SwiftUI

/// One short, explicit account choice instead of a consent form for every request.
struct LunaPermissionControl: View {
    let ownerID: UUID?
    var onEnabled: (() -> Void)? = nil
    @ObservedObject private var permission = CoffeeAssistancePermissionStore.shared

    var body: some View {
        if let ownerID, !permission.isEnabled(ownerID: ownerID) {
            VStack(alignment: .leading, spacing: 10) {
                Text("A little help from Luna").font(.headline)
                Text("Use OpenAI to read the photos and recipe text you choose, and help with selected saved sips. You control what gets saved. Turn it off anytime in Home preferences.")
                    .font(.subheadline).foregroundStyle(Color.secondaryText)
                Button("Enable Luna", systemImage: "sparkles") {
                    permission.setEnabled(true, ownerID: ownerID)
                    onEnabled?()
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("coffeeAssistance.enable")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
