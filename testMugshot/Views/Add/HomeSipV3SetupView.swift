import SwiftUI
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

private enum HomeSipSetupSheet: Identifiable {
    case recipes
    case methods
    case quickRecipe
    case adjustSetup

    var id: String {
        switch self {
        case .recipes: "recipes"
        case .methods: "methods"
        case .quickRecipe: "quick-recipe"
        case .adjustSetup: "adjust-setup"
        }
    }
}

struct HomeSipV3SetupView: View {
    @Binding var draft: SipDraft
    var usesV4 = true
    let isRecoveryLocked: Bool
    let onStartMaking: () -> Void
    let onSkipGuidance: () -> Void
    let onQuickLog: () -> Void
    let onResumeSession: (UUID) -> Void

    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var sheet: HomeSipSetupSheet?
    @State private var linkedRecipeDetail: HomeLinkedRecipeSheet?
    @State private var didTrackOpen = false

    private var selectedMethod: HomeBrewMethod? {
        guard draft.brewMethod.remoteTrimmedNonEmpty != nil else { return nil }
        return HomeBrewMethod(storedValue: draft.brewMethod)
    }

    private var selectedRecipe: HomeRecipeRecord? {
        guard let id = draft.launchContext.sourceRecipeIdentityID else { return nil }
        return store.workspace.recipes.first { $0.id == id }
    }

    private var selectedContent: HomeRecipeContent? {
        if let today = draft.homeSetupContent { return today }
        if let versionID = draft.launchContext.homeRecipeVersionID {
            return selectedRecipe?.versions.first(where: { $0.id == versionID })?.content
        }
        return nil
    }

    private var recentDrinks: [HomeRecipeRecord] {
        Array(store.workspace.recipes.filter {
            !$0.isArchived && $0.current?.content.template == .drink
        }.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }.prefix(5))
    }

    private var selectedRecipeIsSourceOnly: Bool {
        selectedRecipe != nil && selectedContent?.isActionable == false
    }

    private var inProgress: [HomePreparationSession] {
        store.workspace.sessions.filter { $0.currentPhase == .preparing }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !inProgress.isEmpty {
                    sectionHeader("Continue", detail: "\(inProgress.count) active")
                    VStack(spacing: 0) {
                        ForEach(inProgress) { session in
                            setupRow(
                                method: session.attempt.preparation?.method ?? .other,
                                title: session.attempt.name.isEmpty ? "In-progress Home sip" : session.attempt.name,
                                detail: sessionProgress(session),
                                badge: "Resume"
                            ) { onResumeSession(session.id) }
                            if session.id != inProgress.last?.id { Divider().padding(.leading, 64) }
                        }
                    }
                    .homeSetupCard()
                }

                if let selectedMethod {
                    selectedSetup(method: selectedMethod)
                } else {
                    Text(usesV4 ? "What are you making?" : "Start your Home sip")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                    Text(usesV4 ? "Pick a drink or a method. You can change anything later."
                         : "Use a favorite setup, choose a recipe, or make it your way.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)

                    if usesV4 { ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            starter("Latte", method: .completeDrink, action: selectLatte)
                            starter("Espresso", method: .espresso) { select(method: .espresso) }
                            starter("Pour-over", method: .pourOver) { select(method: .pourOver) }
                            starter("Matcha", method: .traditionalMatcha) { select(method: .traditionalMatcha) }
                            starter("Tea", method: .westernTea) { select(method: .westernTea) }
                        }
                    }
                    .scrollIndicators(.hidden) }

                    if let usual = store.workspace.usuals.first,
                       let version = usual.current {
                        Button { select(usual, version: version) } label: {
                            HStack(spacing: 14) {
                                iconWell(version.content.method, size: 50)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("YOUR USUAL")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.mugshotSage)
                                    Text(version.content.name)
                                        .font(.system(size: 18, weight: .semibold, design: .serif))
                                    Text(version.content.summary)
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.mugshotSage)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.mugshotMint.opacity(0.13))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.card).stroke(Color.mugshotSage.opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 0) {
                        setupRow(systemImage: "magnifyingglass", title: "Choose a recipe",
                                 detail: "Coffee, matcha, tea, components, and drinks",
                                 accessibilityIdentifier: "logASipV3.home.chooseRecipe") { sheet = .recipes }
                        Divider().padding(.leading, 64)
                        setupRow(systemImage: "square.grid.2x2", title: "Choose a method",
                                 detail: "Start with only the useful fields",
                                 accessibilityIdentifier: "logASipV3.home.chooseMethod") { sheet = .methods }
                        Divider().padding(.leading, 64)
                        setupRow(systemImage: "plus", title: "Create a recipe",
                                 detail: "A name and source link are enough") { sheet = .quickRecipe }
                        Divider().padding(.leading, 64)
                        setupRow(method: .other, title: "Brew freely",
                                 detail: "Start blank and add only what matters") {
                            MugshotAnalytics.shared.capture(.homeWorkbench(action: .freeSetupSelected))
                            select(method: .other)
                        }
                    }
                    .homeSetupCard()
                }
            }
            .padding(.horizontal, DesignSystem.Space.md)
            .padding(.top, 8)
            .padding(.bottom, 126)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                Button(action: selectedRecipeIsSourceOnly ? { sheet = .adjustSetup } : onStartMaking) {
                    Label(selectedRecipeIsSourceOnly ? "Add preparation details" : "Start making", systemImage: selectedRecipeIsSourceOnly ? "slider.horizontal.3" : "arrow.right")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedMethod == nil || isRecoveryLocked)
                .accessibilityIdentifier("logASipV3.primaryAction")

                if selectedMethod != nil {
                    Button("Skip guidance", action: onSkipGuidance)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(minHeight: 44)
                        .disabled(isRecoveryLocked)
                }

                Button("Already made it? Quick log instead", action: onQuickLog)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(minHeight: 44)
                    .disabled(isRecoveryLocked)
                    .accessibilityIdentifier("logASipV3.home.quickLog")
            }
            .padding(.horizontal, DesignSystem.Space.md)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .recipes:
                HomeSipRecipePicker(store: store) { recipe, version in
                    select(recipe, version: version)
                    sheet = nil
                }
            case .methods:
                HomeMethodPicker { method in
                    select(method: method)
                    sheet = nil
                }
            case .quickRecipe:
                HomeQuickRecipeSheet(store: store) { recipe, version in
                    select(recipe, version: version)
                    sheet = nil
                }
            case .adjustSetup:
                HomeTodaySetupSheet(draft: $draft)
            }
        }
        .sheet(item: $linkedRecipeDetail) { item in
            HomeLinkedRecipeDetail(store: store, reference: item.reference)
        }
        .onAppear {
            guard !didTrackOpen else { return }
            didTrackOpen = true
            MugshotAnalytics.shared.capture(.homeWorkbench(action: .homeOpened))
        }
    }

    private func selectedSetup(method: HomeBrewMethod) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if usesV4, method == .completeDrink, selectedRecipe == nil, !recentDrinks.isEmpty {
                Text("FROM YOUR RECENT SIPS")
                    .font(.caption.weight(.bold)).foregroundStyle(Color.mugshotSage)
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(recentDrinks, id: \.id) { recipe in
                            if let version = recipe.current {
                                Button { select(recipe, version: version) } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        Group {
                                            if let photo = recentPhoto(for: recipe.id) {
                                                Image(uiImage: photo).resizable().scaledToFill()
                                            } else {
                                                HomeMethodIconView(method: version.content.method, size: 38)
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                    .background(Color.mugshotMint.opacity(0.26))
                                            }
                                        }
                                        .frame(height: 92).frame(maxWidth: .infinity).clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        Text(version.content.name).font(.headline)
                                        Text(version.content.summary).font(.caption)
                                            .foregroundStyle(Color.secondaryText)
                                    }
                                    .frame(width: 220, alignment: .leading)
                                    .frame(minHeight: 70)
                                    .padding(12)
                                    .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mugshotLine))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            HStack(spacing: 14) {
                iconWell(method, size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedRecipe == nil ? method.family.title.uppercased() : "RECIPE SELECTED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                    Text(draft.drinkName.remoteTrimmedNonEmpty ?? method.title)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                    Text(draft.brewDetails.extractionSummary ?? method.title)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer()
                Button("Change") { sheet = selectedRecipe == nil ? .methods : .recipes }
                    .font(.caption.weight(.bold))
            }

            Divider()

            if usesV4, let content = selectedContent, !content.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("What makes this drink").font(.headline)
                        Spacer()
                        Button("Change anything") { sheet = .adjustSetup }
                            .font(.caption.weight(.bold))
                    }
                    ForEach(content.ingredients) { ingredient in
                        Button {
                            if let reference = ingredient.recipe {
                                linkedRecipeDetail = HomeLinkedRecipeSheet(reference: reference)
                            } else { sheet = .adjustSetup }
                        } label: {
                            HStack(spacing: 10) {
                                Text(String(ingredient.name.prefix(2)).uppercased())
                                    .font(.caption.weight(.bold))
                                    .frame(width: 40, height: 40)
                                    .background(Color.mugshotMint.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ingredient.name).font(.subheadline.weight(.semibold))
                                    Text(ingredient.amount.map { "\(HomeRecipeContent.number($0)) \(ingredient.unit)" } ?? "Open details")
                                        .font(.caption).foregroundStyle(Color.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .frame(minHeight: 52)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    metric("Dose", draft.brewDetails.doseGrams.map { "\(HomeRecipeContent.number($0)) g" })
                    metric(method.outputLabel, outputText)
                    metric(draft.brewDetails.homeMethodDetails?.steepSeconds == nil ? "Time" : "Steep",
                           draft.brewDetails.homeMethodDetails?.steepSeconds.map {
                               HomeRecipeContent.durationSummary(Double($0))
                           } ?? draft.brewDetails.brewTimeSeconds.map { "\($0) s" })
                }
            }

            Button("Adjust today’s setup") { sheet = .adjustSetup }
                .buttonStyle(SecondaryButtonStyle())

            Label("Targets are a plan. Mugshot never records them as actual results.", systemImage: "leaf.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryText)
        }
        .padding(16)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.card).stroke(Color.mugshotLine))
    }

    private var outputText: String? {
        let method = selectedMethod ?? .other
        let value = method.usesYield ? draft.brewDetails.yieldGrams : draft.brewDetails.homeMethodDetails?.waterGrams ?? draft.brewDetails.yieldGrams
        return value.map { "\(HomeRecipeContent.number($0)) \(method.outputUnit)" }
    }

    private func recentPhoto(for recipeID: UUID) -> UIImage? {
        store.workspace.attempts
            .filter { $0.recipe?.recipeID == recipeID }
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { $0.photoNames.first.flatMap(store.photo) }
            .first
    }

    private func metric(_ label: String, _ value: String?) -> some View {
        VStack(spacing: 3) {
            Text(value ?? "—").font(.system(size: 15, weight: .bold, design: .serif))
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(Color.creamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func select(_ recipe: HomeRecipeRecord, version: HomeRecipeVersion) {
        draft.homeSipPath = .guided
        draft.launchContext.sourceRecipeIdentityID = recipe.id
        draft.launchContext.sourceRecipeVersion = "v\(version.number)"
        draft.launchContext.homeRecipeVersionID = version.id
        draft.drinkName = version.content.name
        draft.brewMethod = version.content.methodDisplayName
        draft.drinkType = version.content.method.drinkType
        draft.customDrinkType = version.content.method.drinkType == .other ? version.content.methodDisplayName : ""
        draft.brewDetails = version.content.asBrewDetails(
            recipeID: recipe.id, versionNumber: version.number,
            resolveLinked: { store.workspace.version($0)?.content }
        )
        if version.content.template == .drink, version.content.targets.dose != nil {
            draft.brewDetails.yieldGrams = version.content.targets.resolvedOutput
        }
        draft.homeComparisonSource = draft.currentHomeBrewSnapshot
        draft.homeAttemptActuals = HomeAttemptActuals()
        draft.homeSetupContent = nil
        draft.homeKeptIngredientIDs = []
        MugshotAnalytics.shared.capture(.homeWorkbench(action: .recipeSelected))
        MugshotHaptic.selection.play()
    }

    private func select(method: HomeBrewMethod) {
        let content = HomeRecipeContent(
            name: method == .other ? "" : method.title,
            template: .preparation,
            method: method,
            targets: HomeRecipeContent.defaultTargets(for: method),
            ingredients: HomeRecipeContent.defaultIngredients(for: method),
            steps: HomeRecipeContent.defaultSteps(for: method)
        )
        draft.homeSipPath = .guided
        draft.launchContext.sourceRecipeIdentityID = nil
        draft.launchContext.sourceRecipeVersion = nil
        draft.launchContext.homeRecipeVersionID = nil
        draft.brewMethod = method.title
        draft.drinkType = method.drinkType
        draft.customDrinkType = method.drinkType == .other ? method.title : ""
        draft.drinkName = method == .other ? "" : method.title
        draft.brewDetails = content.asBrewDetails()
        draft.homeComparisonSource = draft.currentHomeBrewSnapshot
        draft.homeAttemptActuals = HomeAttemptActuals()
        draft.homeSetupContent = content
        draft.homeKeptIngredientIDs = []
        MugshotAnalytics.shared.capture(.homeWorkbench(action: .methodSelected))
        MugshotHaptic.selection.play()
    }

    private func selectLatte() {
        var content = HomeRecipeContent(name: "Latte", template: .drink, method: .completeDrink)
        content.targets = HomeRecipeContent.defaultTargets(for: .espresso)
        if let preferred = store.workspace.recipes.first(where: {
            $0.isPinned && $0.current?.content.method == .espresso
        }), let version = preferred.current {
            content.ingredients.append(HomeRecipeIngredient(
                name: version.content.name, amount: 1, unit: "serving",
                recipe: HomeRecipeReference(recipeID: preferred.id, versionID: version.id)
            ))
            content.targets = version.content.targets
        } else {
            content.ingredients.append(HomeRecipeIngredient(name: "Espresso", amount: 1, unit: "serving"))
        }
        content.ingredients.append(HomeRecipeIngredient(name: "Milk", amount: 160, unit: "ml"))
        draft.homeSetupContent = content
        draft.launchContext.sourceRecipeIdentityID = nil
        draft.launchContext.homeRecipeVersionID = nil
        draft.launchContext.sourceRecipeVersion = nil
        draft.drinkName = "Latte"
        draft.brewMethod = HomeBrewMethod.completeDrink.title
        draft.drinkType = .coffee
        draft.brewDetails = content.asBrewDetails()
        draft.brewDetails.yieldGrams = content.targets.resolvedOutput
        draft.homeAttemptActuals = HomeAttemptActuals()
        draft.homeKeptIngredientIDs = []
        draft.homeSipPath = .guided
        MugshotHaptic.selection.play()
    }

    private func starter(_ title: String, method: HomeBrewMethod, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HomeMethodIconView(method: method, size: 29)
                Text(title).font(.caption.weight(.bold)).foregroundStyle(Color.espressoBrown)
            }
            .frame(width: 94, alignment: .leading)
            .frame(minHeight: 80)
            .padding(10)
            .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mugshotLine))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("logASipV4.home.starter.\(method.rawValue)")
    }

    private func sessionProgress(_ session: HomePreparationSession) -> String {
        if session.attempt.preparation?.method == .coldBrew {
            let hours = max(0, Date().timeIntervalSince(session.startedAt) / 3600)
            return "\(HomeRecipeContent.number(hours)) hr steeping"
        }
        return "Step \(session.stepIndex + 1)"
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        HStack { Text(title).font(.headline); Spacer(); Text(detail).font(.caption).foregroundStyle(Color.secondaryText) }
    }

    private func iconWell(_ method: HomeBrewMethod, size: CGFloat) -> some View {
        HomeMethodIconView(method: method, size: size * 0.5)
            .frame(width: size, height: size)
            .background(Color.mugshotMint.opacity(0.22), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityLabel(method.title)
    }

    private func setupRow(
        systemImage: String,
        title: String,
        detail: String,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.mugshotSage)
                    .frame(width: 46, height: 46).background(Color.mugshotMint.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(Color.secondaryText) }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(Color.mugshotSage)
            }.padding(12).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }

    private func setupRow(method: HomeBrewMethod, title: String, detail: String, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                iconWell(method, size: 46)
                VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(Color.secondaryText) }
                Spacer()
                if let badge { Text(badge).font(.caption2.weight(.bold)).foregroundStyle(Color.mugshotSage).padding(.horizontal, 8).padding(.vertical, 5).background(Color.mugshotMint.opacity(0.2), in: Capsule()) }
                else { Image(systemName: "chevron.right").foregroundStyle(Color.mugshotSage) }
            }.padding(12).contentShape(Rectangle())
        }.buttonStyle(.plain)
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

struct HomeQuickRecipeSheet: View {
    @ObservedObject var store: HomeRecipeWorkspaceStore
    let onSaved: (HomeRecipeRecord, HomeRecipeVersion) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var source = ""
    @State private var sourceText = ""
    @State private var creatorCredit = ""
    @State private var error: String?
    @State private var showsFullEditor = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Save a recipe idea") {
                    TextField("Recipe name", text: $name)
                    TextField("Paste the caption or instructions", text: $sourceText, axis: .vertical)
                        .lineLimit(4...10)
                    TextField("Instagram, TikTok, or website", text: $source)
                        .textInputAutocapitalization(.never).keyboardType(.URL)
                    TextField("Creator credit", text: $creatorCredit)
                }
                Section {
                    Text("Keep the idea as you found it. Add ingredients, amounts, and steps only when you want to. Saving never starts making.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Build a full recipe instead", systemImage: "slider.horizontal.3") {
                        showsFullEditor = true
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .scrollContentBackground(.hidden).background(Color.creamWhite)
            .navigationTitle("Save a simple recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            var content = HomeRecipeContent()
                            content.template = .preparation
                            content.method = .other
                            content.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            content.sourceURL = source.trimmingCharacters(in: .whitespacesAndNewlines)
                            content.sourceText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                            content.creatorCredit = creatorCredit.trimmingCharacters(in: .whitespacesAndNewlines)
                            let id = try store.saveRecipe(HomeRecipeEditorDraft(content: content))
                            guard let recipe = store.workspace.recipes.first(where: { $0.id == id }), let version = recipe.current else { return }
                            onSaved(recipe, version)
                        } catch { self.error = error.localizedDescription }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .fullScreenCover(isPresented: $showsFullEditor) {
            HomeRecipeCreationFlow(store: store) { id in
                guard let recipe = store.workspace.recipes.first(where: { $0.id == id }),
                      let version = recipe.current else { return }
                showsFullEditor = false
                onSaved(recipe, version)
            }
        }
    }
}

private struct HomeTodaySetupSheet: View {
    @Binding var draft: SipDraft
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = HomeRecipeWorkspaceStore.shared
    @State private var calculation: HomeRecipeCalculation = .ratio
    @State private var showsComponentPicker = false

    private var method: HomeBrewMethod { HomeBrewMethod(storedValue: draft.brewMethod) }
    private var content: HomeRecipeContent? {
        if let today = draft.homeSetupContent { return today }
        guard let recipeID = draft.launchContext.sourceRecipeIdentityID,
              let versionID = draft.launchContext.homeRecipeVersionID else { return nil }
        return store.workspace.recipes.first(where: { $0.id == recipeID })?
            .versions.first(where: { $0.id == versionID })?.content
    }
    private var isEspresso: Bool {
        method == .espresso || content?.template == .drink && content?.targets.dose != nil
    }
    private var currentRatio: Double? {
        guard let dose = draft.brewDetails.doseGrams, dose > 0,
              let output = draft.brewDetails.yieldGrams else { return nil }
        return output / dose
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Change anything")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                    Text("Only for today. Your saved recipe stays the same unless you choose what to keep after tasting.")
                        .font(.subheadline).foregroundStyle(Color.secondaryText)

                    if isEspresso {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Espresso base").font(.headline)
                            Picker("Calculate by", selection: $calculation) {
                                Text("Ratio").tag(HomeRecipeCalculation.ratio)
                                Text("Yield").tag(HomeRecipeCalculation.output)
                            }
                            .pickerStyle(.segmented)
                            HomeV4SetupDecimalRow("Coffee in", unit: "g", value: doseBinding)
                            if calculation == .ratio {
                                HomeV4SetupDecimalRow("Brew ratio · 1 to", unit: "", value: ratioBinding)
                            } else {
                                HomeV4SetupDecimalRow("Target yield", unit: "g", value: yieldBinding)
                            }
                            HStack {
                                Text(calculation == .ratio ? "Target yield" : "Brew ratio")
                                Spacer()
                                Text(calculation == .ratio
                                     ? draft.brewDetails.yieldGrams.map { "\(HomeRecipeContent.number($0)) g" } ?? "—"
                                     : currentRatio.map { "1:\(HomeRecipeContent.number($0))" } ?? "—")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.mugshotSageText)
                            HomeV4SetupDecimalRow("Target time", unit: "sec", value: timeBinding)
                        }
                        .padding(16)
                        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 18))
                        if let ratio = currentRatio,
                           let yield = draft.brewDetails.yieldGrams {
                            HStack(spacing: 12) {
                                MugsyModelView(configuration: .init(prop: .journalNotebook))
                                    .frame(width: 42, height: 42)
                                    .accessibilityHidden(true)
                                Text("That’s a 1:\(HomeRecipeContent.number(ratio)) ratio — aiming for \(HomeRecipeContent.number(yield)) g out. You can change either number.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.mugshotSageText)
                            }
                            .padding(14)
                            .background(Color.mugshotMint.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(method.title).font(.headline)
                            HomeV4SetupDecimalRow(method.inputLabel, unit: "g", value: doseBinding)
                            HomeV4SetupDecimalRow(method.outputLabel, unit: method.outputUnit, value: method.usesYield ? yieldBinding : waterBinding)
                            if method == .coldBrew || method == .coldBrewTea {
                                HomeV4SetupDecimalRow("Steep duration", unit: "hr", value: steepHoursBinding)
                            } else if content?.targets.steepSeconds != nil {
                                HomeV4SetupDecimalRow("Steep duration", unit: "min", value: steepMinutesBinding)
                            } else {
                                HomeV4SetupDecimalRow("Target time", unit: "sec", value: timeBinding)
                            }
                        }
                        .padding(16)
                        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 18))
                    }

                    if let content, !content.ingredients.isEmpty || content.template == .drink {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("In this drink").font(.headline)
                            ForEach(content.ingredients) { ingredient in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        TextField("Ingredient name", text: ingredientNameBinding(ingredient.id))
                                            .font(.subheadline.weight(.semibold))
                                            .textInputAutocapitalization(.words)
                                        Spacer(minLength: 8)
                                        Button {
                                            updateContent { $0.ingredients.removeAll { $0.id == ingredient.id } }
                                        } label: { Image(systemName: "minus.circle") }
                                            .frame(width: 44, height: 44)
                                            .accessibilityLabel("Remove \(ingredient.name)")
                                    }
                                    HomeV4SetupDecimalRow("Amount", unit: ingredient.unit,
                                        value: ingredientBinding(ingredient.id))
                                }
                                if ingredient.id != content.ingredients.last?.id { Divider() }
                            }
                            Button("Add a saved recipe", systemImage: "books.vertical") {
                                showsComponentPicker = true
                            }
                            Button("Add a simple ingredient", systemImage: "plus") {
                                updateContent { $0.ingredients.append(HomeRecipeIngredient(name: "")) }
                            }
                        }
                        .padding(16)
                        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 18))
                    }

                    DisclosureGroup("Beans, gear, and more") {
                        let library = HomeLibraryStore.shared.load(in: store.scope)
                        VStack(alignment: .leading, spacing: 12) {
                            Menu(draft.brewDetails.coffeeBag?.displayName ?? "Choose beans") {
                                Button("None") { draft.brewDetails.coffeeBag = nil; updateContent { $0.coffee = nil } }
                                ForEach(library.bags.filter { $0.status.isCurrent }) { bag in
                                    Button(bag.displayName) {
                                        draft.brewDetails.coffeeBag = bag.safeSnapshot
                                        updateContent { $0.coffee = bag.safeSnapshot }
                                    }
                                }
                            }
                            ForEach(library.equipment.filter { $0.archivedAt == nil }) { gear in
                                Toggle(gear.displayName, isOn: Binding(
                                    get: { content?.equipment.contains(gear.snapshot) == true },
                                    set: { chosen in
                                        updateContent {
                                            $0.equipment.removeAll { $0 == gear.snapshot }
                                            if chosen { $0.equipment.append(gear.snapshot) }
                                            draft.brewDetails.equipmentSnapshots = $0.equipment
                                        }
                                    }
                                ))
                            }
                            HomeV4SetupDecimalRow("Temperature", unit: "°C", value: temperatureBinding)
                            TextField("Grind or texture", text: optionalText(\.grindSetting))
                                .textFieldStyle(.roundedBorder)
                            TextField("Notes for today", text: methodNotes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.top, 12)
                    }
                    .tint(Color.mugshotSage)
                    .padding(16)
                    .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(DesignSystem.Space.md)
            }
            .background(Color.creamWhite)
            .navigationTitle("Today's setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        discardUnnamedIngredients()
                        dismiss()
                    }.fontWeight(.bold)
                }
            }
            .onAppear { calculation = content?.targets.calculation ?? .ratio }
            .onDisappear { discardUnnamedIngredients() }
            .sheet(isPresented: $showsComponentPicker) {
                HomeSipRecipePicker(store: store) { recipe, version in
                    updateContent { $0.ingredients.append(HomeRecipeIngredient(
                        name: version.content.name,
                        amount: 1,
                        unit: "serving",
                        recipe: HomeRecipeReference(recipeID: recipe.id, versionID: version.id)
                    )) }
                    showsComponentPicker = false
                }
            }
        }
    }

    private func updateContent(_ update: (inout HomeRecipeContent) -> Void) {
        guard var changed = content else { return }
        update(&changed)
        draft.homeSetupContent = changed
    }

    private func discardUnnamedIngredients() {
        updateContent {
            $0.ingredients.removeAll { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    private var doseBinding: Binding<Double?> {
        Binding(get: { draft.brewDetails.doseGrams }, set: { newValue in
            let ratio = currentRatio
            draft.brewDetails.doseGrams = newValue
            if calculation == .ratio, let newValue, let ratio { draft.brewDetails.yieldGrams = newValue * ratio }
            updateContent {
                $0.targets.dose = newValue
                $0.targets.output = draft.brewDetails.yieldGrams
                $0.targets.ratio = calculation == .ratio ? ratio : nil
                $0.targets.calculation = calculation
            }
        })
    }

    private var ratioBinding: Binding<Double?> {
        Binding(get: { currentRatio }, set: { ratio in
            if let dose = draft.brewDetails.doseGrams, let ratio, ratio > 0 {
                draft.brewDetails.yieldGrams = dose * ratio
            } else { draft.brewDetails.yieldGrams = nil }
            updateContent { $0.targets.ratio = ratio; $0.targets.output = draft.brewDetails.yieldGrams; $0.targets.calculation = .ratio }
        })
    }

    private var yieldBinding: Binding<Double?> {
        Binding(get: { draft.brewDetails.yieldGrams }, set: { newValue in
            draft.brewDetails.yieldGrams = newValue
            updateContent { $0.targets.output = newValue; $0.targets.calculation = .output }
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
            draft.brewDetails.waterTemperatureCelsius = value
            updateContent { $0.targets.temperature = value }
        })
    }

    private var waterBinding: Binding<Double?> {
        Binding(
            get: { draft.brewDetails.homeMethodDetails?.waterGrams },
            set: { value in
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
                draft.brewDetails.brewTimeSeconds = value.map { Int($0.rounded()) }
                updateContent { $0.targets.seconds = value }
            }
        )
    }

    private var steepHoursBinding: Binding<Double?> {
        Binding(
            get: { content?.targets.steepSeconds.map { $0 / 3_600 } },
            set: { hours in
                let seconds = hours.map { $0 * 3_600 }
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details.steepSeconds = seconds.map { Int($0.rounded()) }
                details.coldBrewSteepHours = method == .coldBrew ? hours : nil
                draft.brewDetails.homeMethodDetails = details
                updateContent { $0.targets.steepSeconds = seconds }
            }
        )
    }

    private var steepMinutesBinding: Binding<Double?> {
        Binding(
            get: { content?.targets.steepSeconds.map { $0 / 60 } },
            set: { minutes in
                let seconds = minutes.map { $0 * 60 }
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details.steepSeconds = seconds.map { Int($0.rounded()) }
                draft.brewDetails.homeMethodDetails = details
                updateContent { $0.targets.steepSeconds = seconds }
            }
        )
    }

    private func optionalText(_ keyPath: WritableKeyPath<BrewDetails, String?>) -> Binding<String> {
        Binding(
            get: { draft.brewDetails[keyPath: keyPath] ?? "" },
            set: { value in
                draft.brewDetails[keyPath: keyPath] = value.remoteTrimmedNonEmpty
                if keyPath == \.grindSetting { updateContent { $0.targets.grind = value } }
            }
        )
    }

    private var methodNotes: Binding<String> {
        Binding(
            get: { draft.brewDetails.homeMethodDetails?.customNotes ?? "" },
            set: { value in
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
    @Binding var value: Double?
    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(_ title: String, unit: String, value: Binding<Double?>) {
        self.title = title
        self.unit = unit
        _value = value
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline)
            Spacer(minLength: 4)
            TextField("—", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 58, height: 44)
                .focused($isFocused)
                .accessibilityLabel(title)
            if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(Color.secondaryText) }
        }
        .onAppear { text = value.map { HomeRecipeContent.number($0) } ?? "" }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            let updated = newValue.map { HomeRecipeContent.number($0) } ?? ""
            if Double(text) != newValue { text = updated }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { text = value.map { HomeRecipeContent.number($0) } ?? "" }
        }
        .onChange(of: text) { _, newText in
            let normalized = newText.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
            let parsed = Double(normalized)
            if parsed != value { value = parsed }
        }
    }
}

extension HomeRecipeContent {
    func asBrewDetails(
        recipeID: UUID? = nil,
        versionNumber: Int? = nil,
        resolveLinked: (HomeRecipeReference) -> HomeRecipeContent? = { _ in nil }
    ) -> BrewDetails {
        let linkedBase = template == .drink
            ? ingredients.compactMap(\.recipe).compactMap(resolveLinked)
                .first(where: { [.coffee, .matcha, .hojicha, .tea].contains($0.method.family) })
            : nil
        let baseMethod = linkedBase?.method ?? method
        let baseTargets = linkedBase?.targets.applying(targets) ?? targets
        var methodDetails = HomeMethodDetails.empty
        if baseMethod.usesYield { methodDetails.waterGrams = nil }
        else { methodDetails.waterGrams = baseTargets.resolvedOutput }
        methodDetails.preinfusionSeconds = baseTargets.preinfusion.map(Int.init)
        methodDetails.pressureBars = baseTargets.pressure
        methodDetails.steepSeconds = baseTargets.steepSeconds.map(Int.init)
        methodDetails.coldBrewSteepHours = baseMethod == .coldBrew ? baseTargets.steepSeconds.map { $0 / 3600 } : nil
        methodDetails.customNotes = notes.remoteTrimmedNonEmpty
        var details = BrewDetails.empty
        details.doseGrams = baseTargets.dose
        details.yieldGrams = baseMethod.usesYield ? baseTargets.resolvedOutput : nil
        details.brewTimeSeconds = baseTargets.seconds.map(Int.init)
        details.grindSetting = baseTargets.grind.remoteTrimmedNonEmpty
        details.waterTemperatureCelsius = baseTargets.temperature
        details.recipeName = name.remoteTrimmedNonEmpty
        details.recipeVersion = versionNumber.map { "v\($0)" }
        details.sourceRecipeIdentityID = recipeID
        details.sourceRecipeVersion = versionNumber.map { "v\($0)" }
        details.steps = visibleSteps.map { BrewRecipeStep(instruction: $0.instruction, durationSeconds: $0.waitSeconds.map(Int.init)) }
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
