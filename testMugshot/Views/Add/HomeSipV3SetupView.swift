import CoreFoundation
import SwiftUI
import PhotosUI
import UIKit

struct HomeMethodDefinition: Identifiable, Hashable {
    let method: HomeBrewMethod
    let subtitle: String
    let iconAsset: String
    var id: String { method.rawValue }

    static let all: [Self] = [
        .init(method: .espresso, subtitle: "Machine or lever", iconAsset: "HomeMethodEspresso"),
        .init(method: .pourOver, subtitle: "V60, Chemex, Wave", iconAsset: "HomeMethodPourOver"),
        .init(method: .aeroPress, subtitle: "Standard or inverted", iconAsset: "HomeMethodAeroPress"),
        .init(method: .frenchPress, subtitle: "Full immersion", iconAsset: "HomeMethodFrenchPress"),
        .init(method: .immersion, subtitle: "Clever, Switch, steep", iconAsset: "HomeMethodFrenchPress"),
        .init(method: .mokaPot, subtitle: "Stovetop", iconAsset: "HomeMethodMoka"),
        .init(method: .batch, subtitle: "Drip or batch brewer", iconAsset: "HomeMethodBatch"),
        .init(method: .siphon, subtitle: "Vacuum brew", iconAsset: "HomeMethodSiphon"),
        .init(method: .turkishIbrik, subtitle: "Ibrik or cezve", iconAsset: "HomeMethodIbrik"),
        .init(method: .vietnamesePhin, subtitle: "Slow metal filter", iconAsset: "HomeMethodPourOver"),
        .init(method: .pod, subtitle: "Pod or capsule", iconAsset: "HomeMethodPod"),
        .init(method: .coldBrew, subtitle: "Batch or concentrate", iconAsset: "HomeMethodColdBrew"),
        .init(method: .flashBrew, subtitle: "Hot brew over ice", iconAsset: "HomeMethodPourOver"),
        .init(method: .percolator, subtitle: "Stovetop or electric", iconAsset: "HomeMethodBatch"),
        .init(method: .cowboyBoiled, subtitle: "Boiled or camp coffee", iconAsset: "HomeMethodIbrik"),
        .init(method: .instant, subtitle: "Fast and simple", iconAsset: "HomeMethodCustom"),
        .init(method: .traditionalMatcha, subtitle: "Bowl and whisk", iconAsset: "HomeMethodMatcha"),
        .init(method: .shakenMatcha, subtitle: "Cold and shaken", iconAsset: "HomeMethodShaker"),
        .init(method: .matchaLatte, subtitle: "Matcha, milk, assembly", iconAsset: "HomeMethodMatcha"),
        .init(method: .whiskedHojicha, subtitle: "Powder and whisk", iconAsset: "HomeMethodHojicha"),
        .init(method: .steepedHojicha, subtitle: "Roasted tea steep", iconAsset: "HomeMethodHojicha"),
        .init(method: .hojichaLatte, subtitle: "Hojicha, milk, assembly", iconAsset: "HomeMethodHojicha"),
        .init(method: .westernTea, subtitle: "One calm steep", iconAsset: "HomeMethodTea"),
        .init(method: .gongfuTea, subtitle: "A sequence of infusions", iconAsset: "HomeMethodGongfu"),
        .init(method: .coldBrewTea, subtitle: "Long cold infusion", iconAsset: "HomeMethodTea"),
        .init(method: .icedTea, subtitle: "Chilled or flash brewed", iconAsset: "HomeMethodTea"),
        .init(method: .chaiConcentrate, subtitle: "Tea, spices, simmer", iconAsset: "HomeMethodChai"),
        .init(method: .teaLatte, subtitle: "Tea and milk build", iconAsset: "HomeMethodTea"),
        .init(method: .milkFoam, subtitle: "Milk, foam, cold foam", iconAsset: "HomeMethodMilk"),
        .init(method: .syrupSauce, subtitle: "Syrup, sauce, concentrate", iconAsset: "HomeMethodChai"),
        .init(method: .tonicSoda, subtitle: "Sparkling builds", iconAsset: "HomeMethodTonic"),
        .init(method: .blendedFrozen, subtitle: "Blended or frozen", iconAsset: "HomeMethodShaker"),
        .init(method: .completeDrink, subtitle: "Assemble a complete sip", iconAsset: "HomeMethodCustom"),
        .init(method: .other, subtitle: "Name it and add any field", iconAsset: "HomeMethodCustom")
    ]

    static func definition(for method: HomeBrewMethod) -> Self {
        all.first { $0.method == method } ?? all.last!
    }
}

struct HomeMethodIconView: View {
    let method: HomeBrewMethod
    var size: CGFloat = 24

    var body: some View {
        HomeMethodGlyph(method: method)
        .frame(width: size, height: size)
        .foregroundStyle(Color.mugshotSage)
        .accessibilityHidden(true)
    }
}

/// Mugshot's method identity family. Ordinary controls still use SF Symbols;
/// these icons are drawn from one rounded vector grammar at any optical size.
private struct HomeMethodGlyph: View {
    let method: HomeBrewMethod

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            context.scaleBy(x: scale, y: scale)
            let ink = Color.mugshotSage
            let stroke = StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round)

            func draw(_ path: Path) { context.stroke(path, with: .color(ink), style: stroke) }
            func line(_ points: [CGPoint]) {
                var path = Path()
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
                draw(path)
            }
            func ellipse(_ rect: CGRect) { draw(Path(ellipseIn: rect)) }
            func rect(_ rect: CGRect, radius: CGFloat = 2) {
                draw(Path(roundedRect: rect, cornerRadius: radius))
            }
            func steam(_ x: CGFloat) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 7))
                path.addCurve(to: CGPoint(x: x + 0.4, y: 2), control1: CGPoint(x: x - 2, y: 5), control2: CGPoint(x: x + 2, y: 4))
                draw(path)
            }

            switch glyph {
            case .espresso:
                rect(CGRect(x: 3, y: 3, width: 18, height: 11), radius: 2.5)
                line([.init(x: 7, y: 8), .init(x: 17, y: 8)])
                line([.init(x: 12, y: 8), .init(x: 12, y: 16)])
                rect(CGRect(x: 8, y: 16, width: 8, height: 5), radius: 2)
            case .pourOver:
                line([.init(x: 5, y: 5), .init(x: 19, y: 5), .init(x: 15.5, y: 14), .init(x: 8.5, y: 14), .init(x: 5, y: 5)])
                line([.init(x: 8, y: 17), .init(x: 8, y: 20), .init(x: 17, y: 20), .init(x: 17, y: 17)])
                ellipse(CGRect(x: 11, y: 8, width: 2, height: 2))
            case .press:
                rect(CGRect(x: 6, y: 7, width: 12, height: 14), radius: 2)
                line([.init(x: 9, y: 3), .init(x: 15, y: 3), .init(x: 15, y: 7)])
                line([.init(x: 12, y: 3), .init(x: 12, y: 16)])
            case .moka:
                line([.init(x: 8, y: 3), .init(x: 16, y: 3), .init(x: 18, y: 9), .init(x: 16, y: 12), .init(x: 18, y: 21), .init(x: 6, y: 21), .init(x: 8, y: 12), .init(x: 6, y: 9), .init(x: 8, y: 3)])
                line([.init(x: 18, y: 10), .init(x: 22, y: 12), .init(x: 19, y: 16)])
            case .batch:
                rect(CGRect(x: 4, y: 2.5, width: 16, height: 19), radius: 3)
                line([.init(x: 8, y: 7), .init(x: 16, y: 7)])
                line([.init(x: 12, y: 7), .init(x: 12, y: 11)])
                line([.init(x: 8, y: 18), .init(x: 9, y: 12), .init(x: 15, y: 12), .init(x: 16, y: 18), .init(x: 8, y: 18)])
            case .siphon:
                ellipse(CGRect(x: 7, y: 2, width: 10, height: 9))
                ellipse(CGRect(x: 6, y: 13, width: 12, height: 9))
                line([.init(x: 12, y: 11), .init(x: 12, y: 15)])
            case .ibrik:
                line([.init(x: 7, y: 5), .init(x: 15, y: 5), .init(x: 17, y: 20), .init(x: 6, y: 20), .init(x: 7, y: 5)])
                line([.init(x: 15, y: 8), .init(x: 21, y: 5)])
                steam(9); steam(13)
            case .pod:
                line([.init(x: 8, y: 3), .init(x: 16, y: 3), .init(x: 18, y: 19), .init(x: 6, y: 19), .init(x: 8, y: 3)])
                line([.init(x: 5, y: 21), .init(x: 19, y: 21)])
            case .coldBrew:
                rect(CGRect(x: 5, y: 5, width: 14, height: 16), radius: 3)
                line([.init(x: 8, y: 3), .init(x: 16, y: 3)])
                ellipse(CGRect(x: 9, y: 11, width: 2, height: 2)); ellipse(CGRect(x: 14, y: 14, width: 2, height: 2))
            case .matcha:
                line([.init(x: 4, y: 12), .init(x: 6, y: 20), .init(x: 18, y: 20), .init(x: 20, y: 12)])
                line([.init(x: 4, y: 12), .init(x: 20, y: 12)])
                line([.init(x: 17, y: 3), .init(x: 12, y: 16)])
                line([.init(x: 14, y: 7), .init(x: 19, y: 9)])
            case .shaker:
                line([.init(x: 8, y: 3), .init(x: 16, y: 3), .init(x: 18, y: 20), .init(x: 6, y: 20), .init(x: 8, y: 3)])
                line([.init(x: 7, y: 7), .init(x: 17, y: 7)]); line([.init(x: 5, y: 22), .init(x: 19, y: 22)])
            case .tea:
                line([.init(x: 5, y: 10), .init(x: 6, y: 19), .init(x: 17, y: 19), .init(x: 18, y: 10), .init(x: 5, y: 10)])
                line([.init(x: 18, y: 12), .init(x: 22, y: 13), .init(x: 18, y: 17)])
                steam(9); steam(14)
            case .gongfu:
                line([.init(x: 5, y: 12), .init(x: 8, y: 7), .init(x: 16, y: 7), .init(x: 19, y: 12), .init(x: 17, y: 18), .init(x: 7, y: 18), .init(x: 5, y: 12)])
                line([.init(x: 10, y: 4), .init(x: 14, y: 4)]); line([.init(x: 19, y: 11), .init(x: 22, y: 9)])
            case .milk:
                line([.init(x: 8, y: 4), .init(x: 17, y: 4), .init(x: 19, y: 20), .init(x: 6, y: 20), .init(x: 8, y: 4)])
                line([.init(x: 8, y: 4), .init(x: 4, y: 8)])
                line([.init(x: 9, y: 12), .init(x: 16, y: 12)])
            case .tonic:
                line([.init(x: 7, y: 3), .init(x: 17, y: 3), .init(x: 15, y: 21), .init(x: 9, y: 21), .init(x: 7, y: 3)])
                ellipse(CGRect(x: 10, y: 9, width: 2, height: 2)); ellipse(CGRect(x: 13.5, y: 6, width: 2, height: 2)); ellipse(CGRect(x: 13, y: 14, width: 2, height: 2))
            case .custom:
                rect(CGRect(x: 5, y: 8, width: 13, height: 12), radius: 3)
                line([.init(x: 18, y: 10), .init(x: 22, y: 12), .init(x: 18, y: 16)])
                line([.init(x: 12, y: 2), .init(x: 12, y: 6)]); line([.init(x: 10, y: 4), .init(x: 14, y: 4)])
            }
        }
    }

    private var glyph: Glyph {
        switch method {
        case .espresso: .espresso
        case .pourOver, .flashBrew, .vietnamesePhin: .pourOver
        case .aeroPress, .frenchPress, .immersion: .press
        case .mokaPot: .moka
        case .batch, .percolator, .instant: .batch
        case .siphon: .siphon
        case .turkishIbrik, .cowboyBoiled: .ibrik
        case .pod: .pod
        case .coldBrew, .coldBrewTea: .coldBrew
        case .traditionalMatcha, .matchaLatte, .whiskedHojicha, .hojichaLatte: .matcha
        case .shakenMatcha, .blendedFrozen: .shaker
        case .steepedHojicha, .westernTea, .icedTea, .chaiConcentrate, .teaLatte: .tea
        case .gongfuTea: .gongfu
        case .milkFoam: .milk
        case .tonicSoda: .tonic
        case .syrupSauce, .completeDrink, .other: .custom
        }
    }

    private enum Glyph { case espresso, pourOver, press, moka, batch, siphon, ibrik, pod, coldBrew, matcha, shaker, tea, gongfu, milk, tonic, custom }
}

private enum HomeSipSetupSheet: String, Identifiable {
    case starters
    case methods
    case adjustSetup
    case captureRecipe

    var id: String { rawValue }
}

struct HomeSipV3SetupView: View {
    @Binding var draft: SipDraft
    var usesV4 = true
    let isRecoveryLocked: Bool
    var statusMessage: String? = nil
    let onStartMaking: () -> Void
    let onSkipGuidance: () -> Void
    let onQuickLog: () -> Void
    let onResumeSession: (UUID) -> Void
    var onResumeSip: ((SipDraft) -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authModel: AppAuthModel
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var libraryPresentation: HomeLibraryPresentation?
    @State private var sheet: HomeSipSetupSheet?
    @State private var didTrackOpen = false
    @State private var showsDrafts = false
    @State private var shelf = HomeLibrarySnapshot.empty
    @State private var sipDrafts: [SipDraft] = []
    @State private var sharedSource: HomeRecipeShareCapture?
    @State private var pendingRecipeShares: [UUID] = []
    @State private var failedRecipeShare: UUID?
    @State private var shouldStartSavedRecipe = false
    @State private var showsMethodsAfterStarters = false
    @FocusState private var nameFocused: Bool

    private var scope: LocalAccountScope { .forUserID(draft.ownerUserID) }
    private var isCurrentOwner: Bool { authModel.authenticatedUser?.id == draft.ownerUserID }
    private var canEdit: Bool { isCurrentOwner && !isRecoveryLocked }
    private var hasActiveScope: Bool { isCurrentOwner && store.scope == scope }

    private var selectedMethod: HomeBrewMethod? {
        guard draft.brewMethod.remoteTrimmedNonEmpty != nil else { return nil }
        return HomeBrewMethod(storedValue: draft.brewMethod)
    }

    private var selectedContent: HomeRecipeContent? {
        if let today = draft.homeSetupContent { return today }
        guard hasActiveScope, let recipeID = draft.launchContext.sourceRecipeIdentityID,
              let versionID = draft.launchContext.homeRecipeVersionID else { return nil }
        return store.workspace.version(HomeRecipeReference(recipeID: recipeID, versionID: versionID))?.content
    }

    private var selectedRecipeIsSourceOnly: Bool {
        guard draft.launchContext.sourceRecipeIdentityID != nil, let selectedContent else { return false }
        if selectedContent.isReadyToMake { return false }
        let steps = HomeDrinkComposition.guidance(for: selectedContent) { reference in
            guard hasActiveScope else { return nil }
            return store.workspace.version(reference)?.content
        }.steps
        return !steps.contains { $0.instruction.remoteTrimmedNonEmpty != nil }
    }

    private var recentDrinks: [HomeRecipeRecord] {
        guard hasActiveScope else { return [] }
        return Array(store.workspace.recipes.compactMap { recipe -> (HomeRecipeRecord, Date)? in
            guard !recipe.isArchived, let usedAt = recipe.lastUsedAt,
                  let content = recipe.current?.content, HomeRecipeUse.suggested(for: content) == .drink else { return nil }
            return (recipe, usedAt)
        }.sorted { $0.1 > $1.1 }.prefix(2).map(\.0))
    }

    private var recipeMatches: [HomeRecipeRecord] {
        guard hasActiveScope, let query = draft.drinkName.remoteTrimmedNonEmpty else { return recentDrinks }
        return Array(HomeLibraryBrowse.recipes(store.workspace.recipes, query: query).filter { recipe in
            guard let content = recipe.current?.content else { return false }
            return HomeRecipeUse.suggested(for: content) != .component
        }.prefix(5))
    }

    private var draftCount: Int {
        guard hasActiveScope else { return 0 }
        return HomeDraftCatalogue(sipDrafts: onResumeSip == nil ? [] : sipDrafts, workspace: store.workspace, excludingSipID: draft.id).count
    }

    private var setupPanel: some View {
        ScrollView {
            if isCurrentOwner {
                VStack(alignment: .leading, spacing: 18) {
                    if let statusMessage {
                        Label(statusMessage, systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(Color.secondaryText)
                    }
                    if usesV4, let next = pendingRecipeShares.first {
                        setupRow(systemImage: "square.and.arrow.down", title: "Continue recipe",
                                 detail: pendingRecipeShares.count == 1 ? "Shared to Mugshot" : "\(pendingRecipeShares.count) shared sources",
                                 accessibilityIdentifier: "home.entry.continueRecipe") { openSharedRecipe(next) }
                            .homeSetupCard()
                    }
                    if draftCount > 0 {
                        HomeDraftSummaryButton(count: draftCount) { showsDrafts = true }
                    }
                    if selectedMethod != nil {
                        selectedSetup
                    } else if usesV4 {
                        drinkEntry
                    } else {
                        freshChoices
                    }
                }
                .padding(.horizontal, DesignSystem.Space.md)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .disabled(!canEdit)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isCurrentOwner && selectedMethod != nil { selectedActions }
        }
    }

    var body: some View {
        AnyView(setupPanel)
        .sheet(item: $sheet, onDismiss: {
            sharedSource = nil
            reloadRecipeShares()
            startSavedRecipeAfterDismissal()
            if showsMethodsAfterStarters {
                showsMethodsAfterStarters = false
                if canEdit { sheet = .methods }
            }
        }) { destination in
            switch destination {
            case .starters:
                HomeStarterPicker(onLatte: { selectLatte(); sheet = nil }, onMoreMethods: {
                    showsMethodsAfterStarters = true
                    sheet = nil
                }) { content in
                    selectStarter(content)
                    sheet = nil
                }
            case .methods:
                HomeMethodPicker { method in
                    select(method: method)
                    sheet = nil
                }
            case .adjustSetup:
                HomeTodaySetupSheet(
                    draft: $draft,
                    editsPlan: selectedMethod != nil,
                    isRecoveryLocked: isRecoveryLocked
                )
            case .captureRecipe:
                HomeQuickRecipeSheet(store: store, sharedSource: sharedSource, onMake: { recipe, version in
                    if canEdit, hasActiveScope {
                        select(recipe, version: version)
                        shouldStartSavedRecipe = true
                    }
                    sheet = nil
                }) { recipe, version in
                    select(recipe, version: version)
                    sheet = nil
                }
                .environment(\.dynamicTypeSize, dynamicTypeSize)
            }
        }
        .sheet(item: $libraryPresentation, onDismiss: {
            reloadHomeControls()
            startSavedRecipeAfterDismissal()
        }) { item in
            HomeLibraryView(
                ownerID: item.ownerID,
                initialSection: item.section,
                onComposeDraft: { selected in
                    libraryPresentation = nil
                    if isCurrentOwner { onResumeSip?(selected) }
                },
                includesSipDrafts: onResumeSip != nil,
                onSelectRecipe: { recipe, version in
                    reloadHomeControls()
                    select(recipe, version: version)
                    libraryPresentation = nil
                },
                onMakeRecipe: { recipe, version in
                    if canEdit, hasActiveScope {
                        select(recipe, version: version)
                        shouldStartSavedRecipe = true
                    }
                    libraryPresentation = nil
                },
                onSelectStarter: { content in
                    reloadHomeControls()
                    selectStarter(content)
                    libraryPresentation = nil
                }
            )
            .environment(\.dynamicTypeSize, dynamicTypeSize)
        }
        .sheet(isPresented: $showsDrafts, onDismiss: { reloadHomeControls() }) {
            HomeDraftManagementView(
                ownerID: draft.ownerUserID,
                includesSipDrafts: onResumeSip != nil,
                excludingSipID: draft.id,
                onResumeSip: { selected in
                    showsDrafts = false
                    if isCurrentOwner { onResumeSip?(selected) }
                },
                onResumeSession: { id in
                    showsDrafts = false
                    if isCurrentOwner { onResumeSession(id) }
                }
            )
            .environment(\.dynamicTypeSize, dynamicTypeSize)
        }
        .onAppear {
            reloadHomeControls(applyDefaultIfFresh: !didTrackOpen)
            reloadRecipeShares()
            guard !didTrackOpen else { return }
            didTrackOpen = true
            MugshotAnalytics.shared.capture(.homeWorkbench(action: .homeOpened))
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { reloadRecipeShares() } }
        .onChange(of: store.scope) { _, _ in reloadRecipeShares() }
        .onChange(of: authModel.authenticatedUser?.id) { _, _ in
            guard !isCurrentOwner else { return }
            sheet = nil
            libraryPresentation = nil
            showsDrafts = false
            shouldStartSavedRecipe = false
            pendingRecipeShares = []
            failedRecipeShare = nil
            shelf = .empty
            sipDrafts = []
        }
        .onChange(of: isRecoveryLocked) { _, locked in
            guard locked else { return }
            sheet = nil
            libraryPresentation = nil
            showsDrafts = false
            shouldStartSavedRecipe = false
        }
        .alert("Couldn’t open shared recipe", isPresented: Binding(
            get: { failedRecipeShare != nil }, set: { if !$0 { failedRecipeShare = nil } }
        ), presenting: failedRecipeShare) { id in
            Button("Try again") { openSharedRecipe(id) }
            Button("Discard shared source", role: .destructive) {
                guard canEdit, hasActiveScope else { return }
                try? PocketSipInbox.shared?.acknowledgeRecipe(id, for: PocketSipOwner(userID: draft.ownerUserID))
                reloadRecipeShares()
            }
            Button("Later", role: .cancel) {}
        } message: { _ in
            Text("The source is still in Mugshot’s private handoff on this device.")
        }
    }

    private func reloadRecipeShares() {
        guard hasActiveScope, let inbox = PocketSipInbox.shared else { pendingRecipeShares = []; return }
        let owner = PocketSipOwner(userID: draft.ownerUserID)
        pendingRecipeShares = ((try? inbox.pendingRecipeIDs(for: owner)) ?? []).filter { id in
            guard store.workspace.recipes.contains(where: { $0.id == id }) else { return true }
            try? inbox.acknowledgeRecipe(id, for: owner)
            return false
        }
    }

    private func startSavedRecipeAfterDismissal() {
        guard shouldStartSavedRecipe else { return }
        shouldStartSavedRecipe = false
        if canEdit, hasActiveScope { onStartMaking() }
    }

    private func openSharedRecipe(_ id: UUID) {
        guard canEdit, hasActiveScope, let inbox = PocketSipInbox.shared else { return }
        nameFocused = false
        do {
            if let capture = try inbox.recipeCapture(id, for: PocketSipOwner(userID: draft.ownerUserID)) {
                sharedSource = capture
                sheet = .captureRecipe
            } else { reloadRecipeShares() }
        } catch { failedRecipeShare = id }
    }

    private var drinkEntry: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What are you making?")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Color.espressoBrown)

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.mugshotSageText)
                        .accessibilityHidden(true)
                    TextField("Search recipes or name this sip", text: $draft.drinkName)
                        .submitLabel(.done)
                        .onSubmit { nameFocused = false }
                        .foregroundStyle(Color.espressoBrown)
                        .focused($nameFocused)
                        .accessibilityIdentifier("home.entry.name")
                    if nameFocused {
                        Button("Done") { nameFocused = false }
                            .foregroundStyle(Color.mugshotSageText)
                            .font(.subheadline.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("home.entry.keyboardDone")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(minHeight: 52)
                .homeSetupCard()

                if let name = draft.drinkName.remoteTrimmedNonEmpty {
                    Button {
                        nameFocused = false
                        onQuickLog()
                    } label: {
                        Label("Rate this sip", systemImage: "star")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint("Log \(name)")
                    .accessibilityIdentifier("home.entry.rate")
                }
            }

            if !recipeMatches.isEmpty {
                Text(draft.drinkName.remoteTrimmedNonEmpty == nil ? "Recently made" : "Saved recipes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                VStack(spacing: 0) {
                    ForEach(recipeMatches) { recipe in
                        if let version = recipe.current {
                            setupRow(systemImage: version.content.method.systemImage, title: version.content.name,
                                     detail: version.content.summary) {
                                nameFocused = false
                                select(recipe, version: version)
                            }
                        }
                    }
                }
                .homeSetupCard()
            }

            VStack(spacing: 0) {
                setupRow(systemImage: "square.and.arrow.down", title: "Save a recipe",
                         detail: "From a link, screenshot or your own notes", accessibilityIdentifier: "home.entry.saveRecipe") {
                    nameFocused = false
                    sheet = .captureRecipe
                }
                Divider().padding(.leading, 64)
                setupRow(systemImage: "book.pages", title: "Browse recipes", detail: "Open your Home library",
                         accessibilityIdentifier: "logASipV3.home.chooseRecipe") {
                    nameFocused = false
                    libraryPresentation = HomeLibraryPresentation(ownerID: draft.ownerUserID)
                }
            }
            .homeSetupCard()

            Button("Try a starter", systemImage: "sparkle") { nameFocused = false; sheet = .starters }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mugshotSageText)
                .frame(minHeight: 44)
                .accessibilityIdentifier("home.start.guidance")
        }
    }

    private var freshChoices: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Make or log a sip")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Color.espressoBrown)

            VStack(spacing: 0) {
                setupRow(systemImage: "play.circle.fill", title: "Help me make it",
                         detail: "Simple steps for coffee, tea and matcha",
                         accessibilityIdentifier: "home.start.guidance") {
                    sheet = .starters
                }
            }
            .homeSetupCard()

            setupRow(systemImage: "slider.horizontal.3", title: "Choose a method",
                     detail: "Browse coffee, tea and more") { sheet = .methods }
                .homeSetupCard()

            if hasActiveScope, let usual = store.workspace.usuals.first, let version = usual.current {
                setupRow(systemImage: "pin.fill", title: "Your usual · \(version.content.name)",
                         detail: version.content.summary) { select(usual, version: version) }
                    .homeSetupCard()
            }

            VStack(spacing: 0) {
                setupRow(systemImage: "book.pages", title: "Choose a recipe",
                         detail: "Open your Home recipe shelf",
                         accessibilityIdentifier: "logASipV3.home.chooseRecipe") {
                    libraryPresentation = HomeLibraryPresentation(ownerID: draft.ownerUserID)
                }
                Divider().padding(.leading, 64)
                setupRow(systemImage: "slider.horizontal.3", title: "Beans, gear & preferences",
                         detail: "Manage your shelf and defaults for next time",
                         accessibilityIdentifier: "home.setup.library") {
                    libraryPresentation = HomeLibraryPresentation(ownerID: draft.ownerUserID, section: .beans)
                }
            }
            .homeSetupCard()

            Label("Made at \(draft.locationName.remoteTrimmedNonEmpty ?? "Home") · nickname and gear are optional", systemImage: "house")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var selectedSetup: some View {
        HomeAppliedSetupSummary(
            draft: draft,
            detail: selectedContent?.summary,
            isRecoveryLocked: !canEdit,
            resolveLinked: { hasActiveScope ? store.workspace.version($0)?.content : nil }
        ) { sheet = .adjustSetup }
    }

    private var selectedActions: some View {
        let needsInstructions = selectedRecipeIsSourceOnly
        return VStack(spacing: 6) {
            Button(action: needsInstructions ? { sheet = .adjustSetup } : onStartMaking) {
                Label(needsInstructions ? "Add preparation details" : (usesV4 ? "Follow steps" : "Start making"), systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(usesV4 ? "home.makeWithGuidance" : "logASipV3.primaryAction")

            if usesV4 {
                Button(action: onQuickLog) {
                    Text("Rate this sip")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.mugshotSageText)
                .accessibilityIdentifier("home.entry.rate")
            }
        }
        .disabled(!canEdit)
        .padding(.horizontal, DesignSystem.Space.md)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func select(_ recipe: HomeRecipeRecord, version: HomeRecipeVersion) {
        guard canEdit, hasActiveScope else { return }
        HomeBrewSetup.applySavedRecipe(recipe, version: version, to: &draft, shelf: shelf, path: .guided) {
            store.workspace.version($0)?.content
        }
        MugshotAnalytics.shared.capture(.homeWorkbench(action: .recipeSelected))
        MugshotHaptic.selection.play()
    }

    private func select(method: HomeBrewMethod) {
        guard canEdit else { return }
        var content = HomeRecipeContent(
            name: method == .other ? "" : method.title,
            template: .preparation,
            method: method,
            targets: HomeRecipeContent.defaultTargets(for: method),
            ingredients: HomeRecipeContent.defaultIngredients(for: method),
            steps: HomeRecipeContent.defaultSteps(for: method)
        )
        let bagID = applyLibraryDefaults(to: &content)
        HomeBrewSetup.applyTodayPlan(content, to: &draft, bagID: bagID)
        MugshotAnalytics.shared.capture(.homeWorkbench(action: .methodSelected))
        MugshotHaptic.selection.play()
    }

    private func selectStarter(_ content: HomeRecipeContent) {
        guard canEdit else { return }
        var plan = content
        plan.equipment = HomeBrewSetup.equipment(in: shelf, ownerID: draft.ownerUserID, locationName: draft.locationName).map(\.snapshot)
        HomeBrewSetup.applyTodayPlan(plan, to: &draft)
        MugshotAnalytics.shared.capture(.homeWorkbench(action: .methodSelected))
        MugshotHaptic.selection.play()
    }

    private func applyLibraryDefaults(to content: inout HomeRecipeContent) -> UUID? {
        let bag = shelf.defaults(for: draft.ownerUserID, method: content.method).bag
        content.coffee = bag?.safeSnapshot
        content.equipment = HomeBrewSetup.equipment(in: shelf, ownerID: draft.ownerUserID, locationName: draft.locationName).map(\.snapshot)
        return bag?.id
    }

    private func reloadHomeControls(applyDefaultIfFresh: Bool = false) {
        guard isCurrentOwner else { return }
        shelf = HomeLibraryStore.shared.load(in: scope)
        sipDrafts = SipDraftStore.shared.allDrafts(in: scope)
        if applyDefaultIfFresh, canEdit {
            let isStoredDraft = sipDrafts.contains { $0.id == draft.id }
            HomeBrewSetup.applyDefaultLocation(to: &draft, from: shelf, isStoredDraft: isStoredDraft)
        }
    }

    private func selectLatte() {
        guard canEdit else { return }
        var content = HomeRecipeContent(name: "Latte", template: .drink, method: .completeDrink)
        content.targets = HomeRecipeContent.defaultTargets(for: .espresso)
        if hasActiveScope, let preferred = store.workspace.recipes.first(where: {
            $0.isPinned && $0.current?.content.method == .espresso
        }), let version = preferred.current {
            content.ingredients.append(HomeRecipeIngredient(
                name: version.content.name, amount: 1, unit: "serving",
                recipe: HomeRecipeReference(recipeID: preferred.id, versionID: version.id)
            ))
            content.targets = version.content.targets
        } else {
            content.ingredients.append(HomeRecipeIngredient(name: "Espresso", amount: 1, unit: "serving"))
            content.steps.append(HomePreparationStep(instruction: "Pull a double shot of espresso."))
        }
        content.ingredients.append(HomeRecipeIngredient(name: "Milk", amount: 160, unit: "ml"))
        content.steps.append(HomePreparationStep(instruction: "Warm and froth the milk, then pour it over the espresso."))
        let bagID = applyLibraryDefaults(to: &content)
        HomeBrewSetup.applyTodayPlan(content, to: &draft, bagID: bagID) {
            store.workspace.version($0)?.content
        }
        MugshotHaptic.selection.play()
    }

    private func setupRow(
        systemImage: String,
        title: String,
        detail: String,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.mugshotSageText)
                    .frame(width: 44, height: 44)
                    .background(Color.mugshotMint.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(Color.espressoBrown)
                    if !detail.isEmpty {
                        Text(detail).font(.subheadline).foregroundStyle(Color.secondaryText)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mugshotSageText)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct HomeAppliedSetupSummary: View {
    let draft: SipDraft
    var detail: String? = nil
    var isRecoveryLocked = false
    var resolveLinked: (HomeRecipeReference) -> HomeRecipeContent? = { _ in nil }
    let onChange: () -> Void

    private var appliedInputs: String {
        let gear = draft.brewDetails.equipmentSnapshots?.map(\.displayName) ?? []
        let names = Array(gear.prefix(2))
        let remainder = gear.count > names.count ? "+\(gear.count - names.count) more" : nil
        let location = draft.locationName.remoteTrimmedNonEmpty ?? "Home"
        let coffee = draft.brewDetails.coffeeBag?.displayName
        return ([location] + [coffee].compactMap { $0 } + names + [remainder].compactMap { $0 })
            .joined(separator: " · ")
    }

    private var sourceLabel: String? {
        if let version = draft.launchContext.sourceRecipeVersion ?? draft.homeSourceRecipeVersion {
            return "Saved recipe \(version)"
        }
        if draft.homeSetupContent?.creatorCredit == "Mugshot starter" { return "Mugshot starter" }
        return nil
    }

    private var drinkParts: [(label: String, value: String)] {
        guard let plan = draft.homeSetupContent else { return [] }
        guard HomeRecipeUse.suggested(for: plan) == .drink else {
            return [("Base", plan.methodDisplayName)]
        }
        let baseID = HomeDrinkComposition.baseID(in: plan, resolve: resolveLinked)
        let ingredients = plan.ingredients.filter { $0.name.remoteTrimmedNonEmpty != nil }
        let base = ingredients.first { $0.id == baseID }
        let milk = ingredients.filter { $0.id != baseID && HomeDrinkComposition.isMilk($0) }
        let addIns = ingredients.filter { $0.id != baseID && !HomeDrinkComposition.isMilk($0) }
        return [
            ("Base", base.map(partLabel) ?? (plan.method == .completeDrink || plan.method == .other ? "—" : plan.methodDisplayName)),
            ("Milk", milk.isEmpty ? "—" : milk.map(partLabel).joined(separator: " · ")),
            ("Add-ins", addIns.isEmpty ? "—" : addIns.map(partLabel).joined(separator: " · "))
        ]
    }

    private func partLabel(_ part: HomeRecipeIngredient) -> String {
        guard let amount = part.amount else { return part.name }
        let unit = part.unit.remoteTrimmedNonEmpty.map { " \($0)" } ?? ""
        return "\(part.name) · \(HomeRecipeContent.number(amount))\(unit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("FOR THIS BREW")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.mugshotSageText)
            if let title = draft.brewDetails.recipeName?.remoteTrimmedNonEmpty ?? draft.brewMethod.remoteTrimmedNonEmpty {
                Text(title)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.espressoBrown)
            }
            Label(appliedInputs, systemImage: "house.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.espressoBrown)
                .accessibilityIdentifier("home.setup.appliedInputs")
            if let detail = detail?.remoteTrimmedNonEmpty {
                Text(detail).font(.caption).foregroundStyle(Color.secondaryText)
            }
            ForEach(drinkParts, id: \.label) { part in
                LabeledContent(part.label, value: part.value)
                    .font(.subheadline)
                    .accessibilityIdentifier("home.setup.part.\(part.label)")
            }
            if let sourceLabel {
                Text(sourceLabel).font(.caption).foregroundStyle(Color.secondaryText)
            } else if draft.brewMethod.remoteTrimmedNonEmpty == nil {
                Text("Nickname and gear are optional.").font(.caption).foregroundStyle(Color.secondaryText)
            }
            Button("Change for this brew", systemImage: "slider.horizontal.3", action: onChange)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mugshotSageText)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
                .disabled(isRecoveryLocked)
                .accessibilityIdentifier("home.setup.changeForThisBrew")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeSetupCard()
    }
}

struct HomeSipRecipePicker: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let onSelect: (HomeRecipeRecord, HomeRecipeVersion) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var family: HomeSipFamily?

    var body: some View {
        NavigationStack {
            List {
                Section { TextField("Search recipes, methods, beans, or tags", text: $query) }
                Section {
                    ScrollView(.horizontal) {
                        HStack {
                            filter("All", nil)
                            filter("Coffee", .coffee)
                            filter("Matcha & tea", .matcha)
                            filter("Components", .component)
                        }
                    }.scrollIndicators(.hidden)
                }
                Section("Your recipes") {
                    ForEach(visibleRecipes) { recipe in
                        if let version = recipe.current {
                            Button { onSelect(recipe, version) } label: {
                                HStack(spacing: 12) {
                                    HomeMethodIconView(method: version.content.method, size: 28).frame(width: 42, height: 42)
                                        .background(Color.mugshotMint.opacity(0.18), in: RoundedRectangle(cornerRadius: 13))
                                    VStack(alignment: .leading) {
                                        Text(version.content.name).font(.headline)
                                        Text(version.content.summary).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                    if visibleRecipes.isEmpty {
                        ContentUnavailableView("No matching recipes", systemImage: "book.closed", description: Text("Choose a method or create a simple recipe instead."))
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Color.creamWhite)
            .navigationTitle("Choose a recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private var visibleRecipes: [HomeRecipeRecord] {
        store.workspace.recipes.filter { recipe in
            guard !recipe.isArchived, let content = recipe.current?.content else { return false }
            let familyMatch: Bool
            if family == .matcha { familyMatch = [.matcha, .hojicha, .tea].contains(content.method.family) }
            else if let family { familyMatch = content.method.family == family }
            else { familyMatch = true }
            return familyMatch && (query.isEmpty || content.searchText.contains(query.lowercased()))
        }.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
    }

    private func filter(_ title: String, _ value: HomeSipFamily?) -> some View {
        Button(title) { family = value }
            .font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundStyle(family == value ? Color.foamWhite : Color.mugshotSageText)
            .background(family == value ? Color.mugshotSage : Color.sandBeige, in: Capsule())
    }
}

private struct HomeMethodPicker: View {
    let onSelect: (HomeBrewMethod) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var family: HomeSipFamily = .coffee
    @State private var query = ""
    @State private var showsAll = false

    private var methods: [HomeMethodDefinition] {
        let filtered = HomeMethodDefinition.all.filter {
            ($0.method.family == family
                || (family == .tea && [.matcha, .hojicha, .tea].contains($0.method.family))
                || (family == .component && $0.method.family == .other))
                && (query.isEmpty || $0.method.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query))
        }
        return query.isEmpty && !showsAll ? Array(filtered.prefix(6)) : filtered
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Search methods", text: $query).textFieldStyle(MugshotTextFieldStyle())
                    Picker("Method family", selection: $family) {
                        Text("Coffee").tag(HomeSipFamily.coffee)
                        Text("Matcha & tea").tag(HomeSipFamily.tea)
                        Text("Other").tag(HomeSipFamily.component)
                    }.pickerStyle(.segmented)

                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        ForEach(methods) { item in
                            Button { onSelect(item.method) } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HomeMethodIconView(method: item.method, size: 30)
                                        .frame(width: 52, height: 52)
                                        .background(Color.mugshotMint.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                                    Text(item.method.title).font(.headline).foregroundStyle(Color.espressoBrown)
                                    Text(item.subtitle).font(.caption).foregroundStyle(Color.secondaryText).lineLimit(2)
                                }
                                .padding(14).frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
                                .background(Color.foamWhite)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                                .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.card).stroke(Color.mugshotLine))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item.method.title), \(item.subtitle)")
                            .accessibilityIdentifier("logASipV3.home.method.\(item.method.rawValue)")
                        }
                    }
                    if query.isEmpty, !showsAll {
                        Button("View the complete method catalog") { showsAll = true }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(maxWidth: .infinity)
                    }
                }.padding(16)
            }
            .background(Color.creamWhite)
            .navigationTitle("Choose a method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct HomeTodaySetupSheet: View {
    @Binding private var liveDraft: SipDraft
    @State private var draft: SipDraft
    let editsPlan: Bool
    let isRecoveryLocked: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authModel: AppAuthModel
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var calculation: HomeRecipeCalculation = .ratio
    @State private var plannedRatio: Double?
    @State private var shelf = HomeLibrarySnapshot.empty
    @State private var showsComponentPicker = false
    @State private var showsGearLibrary = false
    @State private var showsRecipePicker = false
    @State private var showsBasePicker = false
    @State private var showsTodayInstruction = false
    @State private var linkedRecipe: HomeLinkedRecipeSheet?
    @State private var scope: LocalAccountScope
    @State private var draftID: UUID

    init(
        draft: Binding<SipDraft>,
        editsPlan: Bool = true,
        isRecoveryLocked: Bool = false
    ) {
        _liveDraft = draft
        _draft = State(initialValue: draft.wrappedValue)
        self.editsPlan = editsPlan
        self.isRecoveryLocked = isRecoveryLocked
        _scope = State(initialValue: .forUserID(draft.wrappedValue.ownerUserID))
        _draftID = State(initialValue: draft.wrappedValue.id)
    }

    private var canEdit: Bool {
        !isRecoveryLocked && authModel.authenticatedUser?.id == scope.userID && liveDraft.ownerUserID == scope.userID
            && liveDraft.id == draftID && (liveDraft.context == .home || liveDraft.context == .recipe)
    }

    private var method: HomeBrewMethod { HomeBrewMethod(storedValue: draft.brewMethod) }

    private var content: HomeRecipeContent? {
        guard canEdit else { return nil }
        if let today = draft.homeSetupContent { return today }
        guard store.scope == scope, let recipeID = draft.launchContext.sourceRecipeIdentityID,
              let versionID = draft.launchContext.homeRecipeVersionID else { return nil }
        return store.workspace.version(HomeRecipeReference(recipeID: recipeID, versionID: versionID))?.content
    }

    private var effectivePlan: HomeRecipeContent? {
        guard let content else { return nil }
        return HomeDrinkComposition.guidance(for: content) { reference in
            guard store.scope == scope else { return nil }
            return store.workspace.version(reference)?.content
        }.base
    }

    private var planMethod: HomeBrewMethod { effectivePlan?.method ?? method }

    private var projectedRatio: Double? {
        guard let dose = draft.brewDetails.doseGrams, dose > 0,
              let output = draft.brewDetails.yieldGrams else { return nil }
        let ratio = output / dose
        return HomeSetupNumbers.amountRange.contains(ratio) ? ratio : nil
    }

    private var profiles: [HomePlaceProfile] {
        (shelf.preferences?.homeProfiles ?? []).filter { $0.ownerUserID == scope.userID }
    }

    private var equipment: [EquipmentSnapshot] {
        content?.equipment ?? draft.brewDetails.equipmentSnapshots ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if canEdit {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Change for this brew")
                                .font(.system(.title, design: .serif).weight(.semibold))
                                .foregroundStyle(Color.espressoBrown)
                            Text("Adjust the recipe for this sip. Your saved recipe keeps its version.")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                            if let version = draft.launchContext.sourceRecipeVersion {
                                Text("Starting from saved recipe \(version)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.mugshotSageText)
                            }
                        }

                        locationCard
                        planChoices
                        if editsPlan {
                            if showsTodayInstruction { instructionCard }
                            planTargets
                            ingredientEditor
                        }
                        inventoryCard
                        if editsPlan { advancedDetails }
                    }
                    .padding(DesignSystem.Space.md)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.creamWhite)
            .navigationTitle("This brew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Use for this brew", action: applyChanges)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("home.setup.useForThisBrew")
                    .padding(.horizontal, DesignSystem.Space.md).padding(.vertical, 8)
                    .background(Color.creamWhite)
                    .disabled(!canEdit)
            }
            .onAppear {
                reloadShelf()
                refreshPlanControls()
            }
            .onChange(of: authModel.authenticatedUser?.id) { _, _ in
                if !canEdit { dismiss() }
            }
            .onChange(of: liveDraft.ownerUserID) { _, _ in
                if !canEdit { dismiss() }
            }
            .onChange(of: liveDraft.id) { _, _ in if !canEdit { dismiss() } }
            .onChange(of: liveDraft.context) { _, _ in if !canEdit { dismiss() } }
            .onChange(of: isRecoveryLocked) { _, _ in if !canEdit { dismiss() } }
            .sheet(isPresented: $showsGearLibrary, onDismiss: reloadShelf) {
                HomeLibraryView(ownerID: scope.userID, initialSection: .gear)
                    .environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(isPresented: $showsRecipePicker) {
                if canEdit && store.scope == scope {
                    HomeSipRecipePicker(store: store) { recipe, version in
                        guard canEdit, store.scope == scope else { return }
                        HomeBrewSetup.applySavedRecipe(recipe, version: version, to: &draft, shelf: shelf,
                            path: editsPlan ? .guided : .quick, resolveLinked: resolveLinked)
                        refreshPlanControls()
                        showsRecipePicker = false
                    }
                }
            }
            .sheet(isPresented: $showsBasePicker) {
                if canEdit && store.scope == scope {
                    HomeDrinkPartPicker(store: store, selectingBase: true, excluding: draft.launchContext.sourceRecipeIdentityID,
                                        replacingName: nil, blockedReferences: []) { recipe, version in
                        replaceBase { plan in
                            let base = HomeDrinkComposition.baseID(in: plan, resolve: resolveLinked)
                            HomeDrinkComposition.useBase(recipe, version: version, in: &plan, replacing: base)
                        }
                    } onPreset: { method in
                        replaceBase { plan in
                            let base = HomeDrinkComposition.baseID(in: plan, resolve: resolveLinked)
                            HomeDrinkComposition.usePreset(method, in: &plan, replacing: base)
                        }
                    }
                }
            }
            .sheet(isPresented: $showsComponentPicker) {
                if canEdit && store.scope == scope {
                    HomeDrinkPartPicker(store: store, selectingBase: false, excluding: draft.launchContext.sourceRecipeIdentityID,
                                        replacingName: nil, blockedReferences: Set(content?.ingredients.compactMap(\.recipe) ?? [])) { recipe, version in
                        updateContent { HomeDrinkComposition.add(recipe, version: version, to: &$0) }
                    } onPreset: { _ in }
                }
            }
            .sheet(item: $linkedRecipe) { item in
                if canEdit && store.scope == scope {
                    HomeLinkedRecipeDetail(store: store, reference: item.reference)
                }
            }
        }
    }

    private var locationCard: some View {
        HomeEditorSection("Made at Home", symbol: "house.fill",
                          detail: "A nickname like Brew bench is optional. Pick a saved setup to use its tools for this sip.") {
            if !profiles.isEmpty {
                Menu {
                    Button("Home") { selectProfile(nil) }
                    ForEach(profiles) { profile in
                        Button(profile.name) { selectProfile(profile) }
                    }
                } label: {
                    Label("Choose a saved Home setup", systemImage: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("home.profile.choose")
            }
            HomeEditorField("Nickname for this sip", text: nickname, placeholder: "Home", identifier: "home.setup.nickname")
        }
    }

    private var planChoices: some View {
        HomeEditorSection("Recipe", symbol: "book.pages",
                          detail: editsPlan ? "Choose the recipe or change the base for this brew." : "Attach a saved recipe to the sip you already made.") {
            if store.scope == scope {
                Button(editsPlan ? "Choose a different recipe" : "Attach a recipe", systemImage: "book.pages") {
                    showsRecipePicker = true
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("home.setup.chooseRecipe")
            }
            if editsPlan, let content, HomeRecipeUse.suggested(for: content) == .drink {
                Button("Change base", systemImage: "cup.and.saucer") { showsBasePicker = true }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("home.setup.changeBase")
            }
        }
    }

    private var instructionCard: some View {
        HomeEditorSection("One step for this brew", symbol: "list.number",
                          detail: "Write a short step to follow as you make this idea.") {
            HomeEditorField("Preparation step", text: Binding(
                get: { content?.visibleSteps.first?.instruction ?? "" },
                set: { instruction in
                    guard canEdit, let plan = content else { return }
                    HomeBrewSetup.updateFirstInstruction(instruction, in: &draft, plan: plan)
                }
            ), placeholder: "Stir the syrup into the latte.", axis: .vertical, identifier: "home.setup.todayInstruction")
        }
    }

    @ViewBuilder private var planTargets: some View {
        if planMethod.usesYield {
            HomeEditorSection("Espresso base", symbol: "cup.and.saucer") {
                Picker("Calculate by", selection: $calculation) {
                    Text("Ratio").tag(HomeRecipeCalculation.ratio)
                    Text("Yield").tag(HomeRecipeCalculation.output)
                }
                .pickerStyle(.segmented)
                HomeV4SetupDecimalRow("Coffee in", unit: "g", value: doseBinding)
                if calculation == .ratio {
                    HomeV4SetupDecimalRow("Brew ratio · 1 to", unit: "", value: ratioBinding)
                    if let yield = draft.brewDetails.yieldGrams {
                        Text("Target yield \(HomeRecipeContent.number(yield)) g")
                            .font(.subheadline).foregroundStyle(Color.mugshotSageText)
                    }
                } else {
                    HomeV4SetupDecimalRow("Target yield", unit: "g", value: yieldBinding)
                    if let ratio = projectedRatio {
                        Text("Brew ratio 1:\(HomeRecipeContent.number(ratio))")
                            .font(.subheadline).foregroundStyle(Color.mugshotSageText)
                    }
                }
                HomeV4SetupDecimalRow("Target time", unit: "sec", value: timeBinding,
                                      allowed: HomeSetupNumbers.durationInputRange())
            }
        } else {
            let brewingMethod = planMethod
            HomeEditorSection(brewingMethod.title, symbol: brewingMethod.systemImage) {
                HomeV4SetupDecimalRow(brewingMethod.inputLabel, unit: "g", value: doseBinding)
                HomeV4SetupDecimalRow(brewingMethod.outputLabel, unit: brewingMethod.outputUnit, value: waterBinding)
                if brewingMethod == .coldBrew || brewingMethod == .coldBrewTea {
                    HomeV4SetupDecimalRow("Steep duration", unit: "hr", value: steepHoursBinding,
                                          allowed: HomeSetupNumbers.durationInputRange(secondsPerUnit: 3_600))
                } else if content?.targets.steepSeconds != nil {
                    HomeV4SetupDecimalRow("Steep duration", unit: "min", value: steepMinutesBinding,
                                          allowed: HomeSetupNumbers.durationInputRange(secondsPerUnit: 60))
                } else {
                    HomeV4SetupDecimalRow("Target time", unit: "sec", value: timeBinding,
                                          allowed: HomeSetupNumbers.durationInputRange())
                }
            }
        }
    }

    @ViewBuilder private var ingredientEditor: some View {
        if let content, !content.ingredients.isEmpty || content.template == .drink {
            HomeEditorSection("In this drink", symbol: "cup.and.saucer",
                              detail: "Adjust the amounts for the sip you’re making.") {
                ForEach(content.ingredients) { ingredient in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("Ingredient name", text: ingredientNameBinding(ingredient.id))
                                .font(.subheadline.weight(.semibold))
                                .textInputAutocapitalization(.words)
                            Button {
                                updateContent { $0.ingredients.removeAll { $0.id == ingredient.id } }
                            } label: { Image(systemName: "minus.circle") }
                                .frame(width: 44, height: 44)
                                .accessibilityLabel("Remove \(ingredient.name) from this drink")
                                .accessibilityIdentifier("home.setup.removePart.\(ingredient.id)")
                        }
                        HomeV4SetupDecimalRow("Amount", unit: ingredient.unit, value: ingredientBinding(ingredient.id))
                        if let reference = ingredient.recipe, store.scope == scope {
                            Button("Open linked recipe", systemImage: "book.pages") {
                                linkedRecipe = HomeLinkedRecipeSheet(reference: reference)
                            }
                            .font(.subheadline)
                            .frame(minHeight: 44)
                        }
                    }
                    if ingredient.id != content.ingredients.last?.id { Divider() }
                }
                if store.scope == scope {
                    Button("Add a saved add-in", systemImage: "books.vertical") { showsComponentPicker = true }
                        .frame(minHeight: 44)
                }
                Button("Add a simple ingredient", systemImage: "plus") {
                    updateContent { $0.ingredients.append(HomeRecipeIngredient(name: "")) }
                }
                .frame(minHeight: 44)
            }
        }
    }

    private var inventoryCard: some View {
        HomeEditorSection("Beans and gear", symbol: "kettle", detail: "Choose the bag or tools you used, if you want to remember them.") {
            if planMethod.family == .coffee || planMethod == .completeDrink || planMethod == .other || draft.brewDetails.coffeeBag != nil {
                HomeCoffeeBagPicker(scope: scope, selection: draft.brewDetails.coffeeBag) { bag in
                    guard canEdit, bag == nil || bag?.ownerUserID == scope.userID else { return }
                    draft.homeCoffeeBagID = bag?.id
                    draft.brewDetails.coffeeBag = bag?.safeSnapshot
                    updateContent { $0.coffee = bag?.safeSnapshot }
                }
            }
            ForEach(shelf.activeEquipment.filter { $0.ownerUserID == scope.userID }) { gear in
                Toggle(gear.displayName, isOn: Binding(
                    get: { equipment.contains(gear.snapshot) },
                    set: { selected in
                        var updated = equipment.filter { $0 != gear.snapshot }
                        if selected { updated.append(gear.snapshot) }
                        setEquipment(updated)
                    }
                ))
                .frame(minHeight: 44)
            }
            Button("Open Home gear library", systemImage: "slider.horizontal.3") { showsGearLibrary = true }
                .frame(minHeight: 44)
        }
    }

    private var advancedDetails: some View {
        DisclosureGroup("More brewing details") {
            VStack(alignment: .leading, spacing: 10) {
                HomeV4SetupDecimalRow("Temperature", unit: "°C", value: temperatureBinding,
                                      allowed: HomeSetupNumbers.temperatureRange)
                TextField("Grind or texture", text: optionalText(\.grindSetting))
                    .textFieldStyle(.roundedBorder)
                TextField("Notes for today", text: methodNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.top, 10)
        }
        .tint(Color.mugshotSageText)
        .padding(14)
        .homeSetupCard()
    }

    private var nickname: Binding<String> {
        Binding(get: { draft.locationName }, set: { value in
            guard canEdit else { return }
            let oneLine = value.components(separatedBy: .controlCharacters).joined()
            draft.locationName = String(oneLine.prefix(60))
        })
    }

    private func selectProfile(_ profile: HomePlaceProfile?) {
        guard canEdit else { return }
        draft.locationName = profile?.name ?? "Home"
        let gear = HomeBrewSetup.equipment(in: shelf, ownerID: scope.userID, locationName: draft.locationName)
        setEquipment(gear.map(\.snapshot))
    }

    private func setEquipment(_ value: [EquipmentSnapshot]) {
        guard canEdit else { return }
        draft.brewDetails.equipmentSnapshots = value
        draft.equipment = value.map(\.displayName).joined(separator: ", ")
        updateContent { $0.equipment = value }
    }

    private func reloadShelf() {
        guard canEdit else { return }
        shelf = HomeLibraryStore.shared.load(in: scope)
    }

    private func updateContent(_ update: (inout HomeRecipeContent) -> Void) {
        guard var changed = content else { return }
        update(&changed)
        draft.homeSetupContent = changed
    }

    private func discardUnnamedIngredients() {
        guard editsPlan else { return }
        updateContent {
            $0.ingredients.removeAll { $0.recipe == nil && $0.name.remoteTrimmedNonEmpty == nil }
        }
    }

    private func refreshPlanControls() {
        let targets = effectivePlan?.targets
        calculation = targets?.calculation ?? .ratio
        plannedRatio = targets?.resolvedRatio ?? projectedRatio
        showsTodayInstruction = editsPlan && content?.isReadyToMake == false
    }

    private func resolveLinked(_ reference: HomeRecipeReference) -> HomeRecipeContent? {
        store.scope == scope ? store.workspace.version(reference)?.content : nil
    }

    private func replaceBase(_ update: (inout HomeRecipeContent) -> Void) {
        guard var plan = content else { return }
        update(&plan)
        let bagID = shelf.bags.first { $0.ownerUserID == scope.userID && $0.safeSnapshot == plan.coffee }?.id
        HomeBrewSetup.replaceTodayBase(in: &draft, with: plan, bagID: bagID, resolveLinked: resolveLinked)
        refreshPlanControls()
    }

    private func applyChanges() {
        guard canEdit else { return }
        discardUnnamedIngredients()
        var result = liveDraft
        result.locationName = draft.locationName
        result.drinkName = draft.drinkName
        result.brewDetails = draft.brewDetails
        result.homeSetupContent = draft.homeSetupContent
        result.homeCoffeeBagID = draft.homeCoffeeBagID
        result.equipment = draft.equipment
        result.brewMethod = draft.brewMethod
        result.drinkType = draft.drinkType
        result.customDrinkType = draft.customDrinkType
        result.homeSipPath = draft.homeSipPath
        result.homeComparisonSource = draft.homeComparisonSource
        result.homeAttemptActuals = draft.homeAttemptActuals
        result.homeKeptIngredientIDs = draft.homeKeptIngredientIDs
        result.launchContext.sourceRecipeIdentityID = draft.launchContext.sourceRecipeIdentityID
        result.launchContext.homeRecipeVersionID = draft.launchContext.homeRecipeVersionID
        result.launchContext.sourceRecipeVersion = draft.launchContext.sourceRecipeVersion
        liveDraft = result
        dismiss()
    }

    private var doseBinding: Binding<Double?> {
        Binding(get: { draft.brewDetails.doseGrams }, set: { newValue in
            guard canEdit else { return }
            let usesYield = planMethod.usesYield
            if usesYield && calculation == .ratio {
                applyRatio(dose: newValue, ratio: plannedRatio)
                return
            }
            draft.brewDetails.doseGrams = newValue
            updateContent {
                $0.targets.dose = newValue
                if usesYield {
                    $0.targets.output = draft.brewDetails.yieldGrams
                    $0.targets.ratio = nil
                    $0.targets.calculation = .output
                }
            }
            if usesYield { plannedRatio = projectedRatio }
        })
    }

    private var ratioBinding: Binding<Double?> {
        Binding(get: { plannedRatio }, set: { ratio in
            applyRatio(dose: draft.brewDetails.doseGrams, ratio: ratio)
        })
    }

    private func applyRatio(dose: Double?, ratio: Double?) {
        guard canEdit, planMethod.usesYield else { return }
        var plan = content
        guard let targets = HomeSetupNumbers.ratioTargets(plan?.targets ?? HomeRecipeTargets(), dose: dose, ratio: ratio)
        else { return }
        plan?.targets = targets
        var updated = draft
        updated.brewDetails.doseGrams = targets.dose
        updated.brewDetails.yieldGrams = targets.output
        updated.brewDetails.homeMethodDetails?.waterGrams = nil
        if let plan { updated.homeSetupContent = plan }
        draft = updated
        plannedRatio = ratio
    }

    private var yieldBinding: Binding<Double?> {
        Binding(get: { draft.brewDetails.yieldGrams }, set: { newValue in
            guard canEdit else { return }
            draft.brewDetails.yieldGrams = newValue
            plannedRatio = projectedRatio
            updateContent {
                $0.targets.output = newValue
                $0.targets.ratio = nil
                $0.targets.calculation = .output
            }
        })
    }

    private func ingredientBinding(_ id: UUID) -> Binding<Double?> {
        Binding(get: { content?.ingredients.first { $0.id == id }?.amount }, set: { amount in
            updateContent { changed in
                guard let index = changed.ingredients.firstIndex(where: { $0.id == id }) else { return }
                changed.ingredients[index].amount = amount
            }
        })
    }

    private func ingredientNameBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { content?.ingredients.first { $0.id == id }?.name ?? "" }, set: { name in
            updateContent { changed in
                guard let index = changed.ingredients.firstIndex(where: { $0.id == id }) else { return }
                changed.ingredients[index].name = name
            }
        })
    }

    private var temperatureBinding: Binding<Double?> {
        Binding(get: { draft.brewDetails.waterTemperatureCelsius }, set: { value in
            guard canEdit else { return }
            draft.brewDetails.waterTemperatureCelsius = value
            updateContent { $0.targets.temperature = value }
        })
    }

    private var waterBinding: Binding<Double?> {
        Binding(
            get: { draft.brewDetails.homeMethodDetails?.waterGrams },
            set: { value in
                guard canEdit else { return }
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details.waterGrams = value
                draft.brewDetails.homeMethodDetails = details
                updateContent { $0.targets.output = value; $0.targets.calculation = .output }
            }
        )
    }

    private var timeBinding: Binding<Double?> {
        Binding(
            get: { content?.targets.seconds ?? draft.brewDetails.brewTimeSeconds.map(Double.init) },
            set: { value in
                guard canEdit else { return }
                draft.brewDetails.brewTimeSeconds = HomeSetupNumbers.wholeSeconds(value)
                updateContent { $0.targets.seconds = value }
            }
        )
    }

    private var steepHoursBinding: Binding<Double?> {
        steepBinding(secondsPerUnit: 3_600)
    }

    private var steepMinutesBinding: Binding<Double?> {
        steepBinding(secondsPerUnit: 60)
    }

    private func steepBinding(secondsPerUnit: Double) -> Binding<Double?> {
        Binding(
            get: {
                (content?.targets.steepSeconds ?? draft.brewDetails.homeMethodDetails?.steepSeconds.map(Double.init))
                    .map { $0 / secondsPerUnit }
            },
            set: { value in
                guard canEdit else { return }
                let seconds = value.map { $0 * secondsPerUnit }
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details.steepSeconds = HomeSetupNumbers.wholeSeconds(seconds)
                details.coldBrewSteepHours = planMethod == .coldBrew ? seconds.map { $0 / 3_600 } : nil
                draft.brewDetails.homeMethodDetails = details
                updateContent { $0.targets.steepSeconds = seconds }
            }
        )
    }

    private func optionalText(_ keyPath: WritableKeyPath<BrewDetails, String?>) -> Binding<String> {
        Binding(
            get: { draft.brewDetails[keyPath: keyPath] ?? "" },
            set: { value in
                guard canEdit else { return }
                draft.brewDetails[keyPath: keyPath] = value.remoteTrimmedNonEmpty
                if keyPath == \.grindSetting { updateContent { $0.targets.grind = value } }
            }
        )
    }

    private var methodNotes: Binding<String> {
        Binding(
            get: { draft.brewDetails.homeMethodDetails?.customNotes ?? "" },
            set: { value in
                guard canEdit else { return }
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details.customNotes = value.remoteTrimmedNonEmpty
                draft.brewDetails.homeMethodDetails = details
                updateContent { $0.notes = value }
            }
        )
    }
}

private struct HomeV4SetupDecimalRow: View {
    let title: String
    let unit: String
    let allowed: ClosedRange<Double>
    @Binding var value: Double?
    @Environment(\.locale) private var locale
    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(_ title: String, unit: String, value: Binding<Double?>,
         allowed: ClosedRange<Double> = HomeSetupNumbers.amountRange) {
        self.title = title
        self.unit = unit
        self.allowed = allowed
        _value = value
    }

    private var editableText: Binding<String> {
        Binding(get: { text }, set: { newText in
            let edit = HomeSetupNumbers.edit(newText, replacing: text, locale: locale, allowed: allowed)
            text = newText
            switch edit {
            case .unchanged: break
            case .clear: if value != nil { value = nil }
            case .set(let newValue): if value != newValue { value = newValue }
            }
        })
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline)
            Spacer(minLength: 4)
            TextField("—", text: editableText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 58, height: 44)
                .focused($isFocused)
                .accessibilityLabel(title)
            if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(Color.secondaryText) }
        }
        .onAppear { text = HomeSetupNumbers.display(value, locale: locale) }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            text = HomeSetupNumbers.display(newValue, locale: locale)
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { text = HomeSetupNumbers.display(value, locale: locale) }
        }
    }
}

enum HomeSetupNumbers {
    enum Edit: Equatable {
        case unchanged, clear, set(Double)
    }

    static let amountRange = Double.leastNonzeroMagnitude...1_000_000
    static let temperatureRange = (-273.15).nextUp...1_000
    private static let maximumDuration: Double = 30 * 24 * 60 * 60

    static func durationInputRange(secondsPerUnit: Double = 1) -> ClosedRange<Double> {
        Double.leastNonzeroMagnitude...(maximumDuration / secondsPerUnit)
    }

    static func display(_ value: Double?, locale: Locale) -> String {
        guard let value, value.isFinite else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }

    static func edit(_ text: String, replacing previousText: String, locale: Locale,
                     allowed: ClosedRange<Double> = amountRange) -> Edit {
        guard text != previousText else { return .unchanged }
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return .clear }
        guard let formatter = CFNumberFormatterCreate(nil, locale as CFLocale, .decimalStyle) else { return .unchanged }
        var parsedRange = CFRange(location: 0, length: input.utf16.count)
        guard let parsed = CFNumberFormatterCreateNumberFromString(nil, formatter, input as CFString, &parsedRange, 0),
              parsedRange.location == 0, parsedRange.length == input.utf16.count else { return .unchanged }
        var value = Double.zero
        guard CFNumberGetValue(parsed, .doubleType, &value), value.isFinite, allowed.contains(value) else { return .unchanged }
        return .set(value)
    }

    static func boundedSeconds(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0...maximumDuration).contains(value) else { return nil }
        return value
    }

    static func wholeSeconds(_ value: Double?) -> Int? {
        boundedSeconds(value).flatMap { Int(exactly: $0.rounded()) }
    }

    static func ratioTargets(_ targets: HomeRecipeTargets, dose: Double?, ratio: Double?) -> HomeRecipeTargets? {
        var result = targets
        result.calculation = .ratio
        result.dose = dose
        result.ratio = ratio
        result.output = result.resolvedOutput
        if let output = result.output, !amountRange.contains(output) { return nil }
        return result
    }
}

extension HomeRecipeContent {
    func asBrewDetails(
        recipeID: UUID? = nil,
        versionNumber: Int? = nil,
        resolveLinked: (HomeRecipeReference) -> HomeRecipeContent? = { _ in nil }
    ) -> BrewDetails {
        let base = HomeDrinkComposition.guidance(for: self, resolve: resolveLinked).base
        let baseMethod = base.method
        let baseTargets = base.targets
        var methodDetails = HomeMethodDetails.empty
        if baseMethod.usesYield { methodDetails.waterGrams = nil }
        else { methodDetails.waterGrams = baseTargets.resolvedOutput }
        methodDetails.preinfusionSeconds = HomeSetupNumbers.wholeSeconds(baseTargets.preinfusion)
        methodDetails.pressureBars = baseTargets.pressure
        let steep = HomeSetupNumbers.boundedSeconds(baseTargets.steepSeconds)
        methodDetails.steepSeconds = HomeSetupNumbers.wholeSeconds(steep)
        methodDetails.coldBrewSteepHours = baseMethod == .coldBrew ? steep.map { $0 / 3_600 } : nil
        methodDetails.customNotes = notes.remoteTrimmedNonEmpty
        var details = BrewDetails.empty
        details.doseGrams = baseTargets.dose
        details.yieldGrams = baseMethod.usesYield ? baseTargets.resolvedOutput : nil
        details.brewTimeSeconds = HomeSetupNumbers.wholeSeconds(baseTargets.seconds)
        details.grindSetting = baseTargets.grind.remoteTrimmedNonEmpty
        details.waterTemperatureCelsius = baseTargets.temperature
        details.recipeName = name.remoteTrimmedNonEmpty
        details.recipeVersion = versionNumber.map { "v\($0)" }
        details.sourceRecipeIdentityID = recipeID
        details.sourceRecipeVersion = versionNumber.map { "v\($0)" }
        details.steps = visibleSteps.map {
            BrewRecipeStep(instruction: $0.instruction, durationSeconds: HomeSetupNumbers.wholeSeconds($0.waitSeconds))
        }
        details.tags = tags
        details.coffeeBag = coffee
        details.equipmentSnapshots = equipment
        details.homeMethodDetails = methodDetails
        return details
    }
}

private extension View {
    func homeSetupCard() -> some View {
        background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.card).stroke(Color.mugshotLine))
    }
}
