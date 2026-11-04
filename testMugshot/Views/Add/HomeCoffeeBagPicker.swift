import SwiftUI

/// Uses the same account-scoped shelf and editor as the Home workbench.
struct HomeCoffeeBagPicker: View {
    let scope: LocalAccountScope
    let selection: CoffeeBagSnapshot?
    let onSelect: (CoffeeBag?) -> Void

    @EnvironmentObject private var authModel: AppAuthModel
    @State private var library = HomeLibrarySnapshot.empty
    @State private var editor: HomeBagEditorConfiguration?

    private var isCurrentOwner: Bool {
        LocalAccountScope.forUserID(authModel.authenticatedUser?.id) == scope
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Menu(selection?.displayName ?? "Choose beans") {
                Button("None") { if isCurrentOwner { onSelect(nil) } }
                ForEach(library.currentBags) { bag in
                    Button(bag.displayName) { if isCurrentOwner { onSelect(bag) } }
                }
            }
            .accessibilityIdentifier("home.today.beans.select")

            HStack(spacing: 20) {
                Button("Add manually", systemImage: "plus") { editor = .manual }
                    .accessibilityIdentifier("home.today.beans.addManually")
                Button("Scan bag", systemImage: "viewfinder") { editor = .scan }
                    .accessibilityIdentifier("home.today.beans.scan")
            }
            .font(.subheadline)
        }
        .disabled(!isCurrentOwner)
        .onAppear(perform: reload)
        .onChange(of: scope) { _, _ in editor = nil; reload() }
        .onChange(of: authModel.authenticatedUser?.id) { _, _ in editor = nil; reload() }
        .sheet(item: $editor) { configuration in
            HomeCoffeeBagEditorSheet(
                configuration: configuration,
                scope: scope,
                existingBags: library.bags,
                store: .shared
            ) { bag in
                guard isCurrentOwner, bag.ownerUserID == scope.userID else { return }
                reload()
                onSelect(bag)
            }
        }
    }

    private func reload() {
        library = isCurrentOwner ? HomeLibraryStore.shared.load(in: scope) : .empty
    }
}
