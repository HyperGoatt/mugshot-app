import PhotosUI
import SwiftUI
import UIKit

private enum HomeWorkbenchStartSource: String, CaseIterable, Identifiable {
    case recentAttempt
    case savedRecipe
    case blank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentAttempt: return "Recent attempt"
        case .savedRecipe: return "Saved recipe"
        case .blank: return "Blank"
        }
    }
}

struct HomeWorkbenchView: View {
    @Binding var draft: SipDraft
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var library = HomeLibrarySnapshot.empty
    @State private var presentedSheet: HomeWorkbenchSheet?
    @State private var dialInExpanded = false
    @State private var syncMessage: String?
    @State private var hasTrackedView = false
    @State private var startSource: HomeWorkbenchStartSource

    private let store: HomeLibraryStore

    init(
        draft: Binding<SipDraft>,
        store: HomeLibraryStore = .shared,
        initiallyShowsDialInDetails: Bool = false
    ) {
        _draft = draft
        _dialInExpanded = State(initialValue: initiallyShowsDialInDetails)
        _startSource = State(
            initialValue: draft.wrappedValue.homeSourceRecipeVersion == nil
                ? .recentAttempt
                : .savedRecipe
        )
        self.store = store
    }

    private var scope: LocalAccountScope {
        .forUserID(draft.ownerUserID)
    }

    private var selectedMethod: HomeBrewMethod {
        HomeBrewMethod(storedValue: draft.brewMethod)
    }

    private var brewColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.md) {
            startFromSection
            coffeeSection
            methodAndGearSection
            brewSection

            if let syncMessage {
                Label(syncMessage, systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .bag(let configuration):
                HomeCoffeeBagEditorSheet(
                    configuration: configuration,
                    scope: scope,
                    existingBags: library.bags,
                    store: store
                ) { bag in
                    library = store.load(in: scope)
                    select(bag)
                }
                .presentationBackground(Color.creamWhite)
            case .equipment(let configuration):
                HomeEquipmentEditorSheet(
                    configuration: configuration,
                    scope: scope,
                    store: store
                ) { equipment in
                    library = store.load(in: scope)
                    select(equipment)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.creamWhite)
            }
        }
        .task(id: scope) {
            library = store.load(in: scope)
            await synchronizeLibrary()
        }
        .onAppear {
            if draft.brewDetails.homeMethodDetails == nil {
                draft.brewDetails.homeMethodDetails = .empty
            }
            if !hasTrackedView {
                hasTrackedView = true
                MugshotAnalytics.shared.capture(.homeWorkbench(action: .viewed))
            }
        }
        .onChange(of: dialInExpanded) { _, isExpanded in
            guard isExpanded else { return }
            MugshotAnalytics.shared.capture(.homeWorkbench(action: .advancedFieldsOpened))
        }
    }

    private var startFromSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeWorkbenchSectionHeader(
                title: "Start from",
                subtitle: "Reuse the setup. Change only today."
            )

            Picker("Start from", selection: $startSource) {
                ForEach(HomeWorkbenchStartSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("logASipV3.home.startFrom")

            if let baseline = draft.homeComparisonSource {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(Color.mugshotSage)
                        .frame(width: 34, height: 34)
                        .background(Color.mugshotMint.opacity(0.25), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Comparing with \(baseline.title)")
                            .font(.system(size: 13, weight: .bold))
                        Text(baseline.subtitle.remoteTrimmedNonEmpty ?? "Saved setup")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.tertiaryText)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Clear") {
                        draft.homeComparisonSource = nil
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .padding(12)
                .background(Color.mugshotMint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            }

            if startSource == .blank {
                Button {
                    clearSetup()
                    MugshotHaptic.selection.play()
                } label: {
                    Label("Start a blank attempt", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.sandBeige.opacity(0.38))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if !availableStartingPoints.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(availableStartingPoints.prefix(6)) { setup in
                            Button {
                                draft.applyHomeBrewTemplate(setup)
                                MugshotHaptic.selection.play()
                                MugshotAnalytics.shared.capture(.homeWorkbench(action: .templateReused))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(
                                        setup.brewDetails.recipeName?.remoteTrimmedNonEmpty != nil
                                            ? "Saved recipe"
                                            : (setup.makeAgain == .yes ? "Last winner" : "Recent"),
                                        systemImage: setup.brewDetails.recipeName?.remoteTrimmedNonEmpty != nil
                                            ? "book.pages.fill"
                                            : (setup.makeAgain == .yes ? "checkmark.seal.fill" : "clock.fill")
                                    )
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.mugshotSage)
                                    Text(setup.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.espressoBrown)
                                        .lineLimit(1)
                                    Text(setup.subtitle.remoteTrimmedNonEmpty ?? "Home setup")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.tertiaryText)
                                        .lineLimit(1)
                                }
                                .frame(width: 154, alignment: .leading)
                                .padding(12)
                                .background(Color.foamWhite)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                                        .stroke(Color.mugshotLine, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Label(
                    startSource == .savedRecipe
                        ? "Saved recipes will appear here after your first winner."
                        : "Recent Home attempts will appear here.",
                    systemImage: startSource == .savedRecipe ? "book.pages" : "clock"
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.secondaryText)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.sandBeige.opacity(0.32))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var availableStartingPoints: [HomeBrewSnapshot] {
        library.recentSetups.filter { setup in
            let isRecipe = setup.brewDetails.recipeName?.remoteTrimmedNonEmpty != nil
                || setup.brewDetails.recipeVersion?.remoteTrimmedNonEmpty != nil
            return startSource == .savedRecipe ? isRecipe : !isRecipe
        }
    }

    private var coffeeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeWorkbenchSectionHeader(
                title: "Coffee",
                subtitle: "Pick an open bag or capture it once."
            )

            if library.currentBags.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(width: 42, height: 42)
                        .background(Color.mugshotMint.opacity(0.22), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your coffee shelf is empty")
                            .font(.system(size: 13, weight: .bold))
                        Text("Scanning is optional. You can also brew without a bag.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.tertiaryText)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(library.currentBags) { bag in
                            HomeCoffeeBagCard(
                                bag: bag,
                                image: store.bagPhoto(relativePath: bag.localPhotoPath, in: scope),
                                isSelected: draft.homeCoffeeBagID == bag.id,
                                action: { select(bag) },
                                editAction: {
                                    presentedSheet = .bag(.edit(bag))
                                }
                            )
                        }

                        Button {
                            draft.homeCoffeeBagID = nil
                            draft.brewDetails.coffeeBag = nil
                        } label: {
                            VStack(spacing: 7) {
                                Image(systemName: "nosign")
                                Text("No bag")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(Color.secondaryText)
                            .frame(width: 94, height: 116)
                            .background(Color.sandBeige.opacity(0.38))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    presentedSheet = .bag(.scan)
                } label: {
                    Label("Scan bag", systemImage: "viewfinder")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("logASipV3.home.scanBag")

                Button {
                    presentedSheet = .bag(.manual)
                } label: {
                    Label("Add manually", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.mugshotSage)
                .buttonStyle(.plain)
                .accessibilityIdentifier("logASipV3.home.addBagManually")

                if !library.bags.isEmpty {
                    Menu {
                        ForEach(library.bags.sorted { $0.updatedAt > $1.updatedAt }) { bag in
                            Button {
                                presentedSheet = .bag(.edit(bag))
                            } label: {
                                Label(
                                    "\(bag.displayName) · \(bag.status.title)",
                                    systemImage: "shippingbox"
                                )
                            }
                        }
                    } label: {
                        Label("Manage", systemImage: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.mugshotSage)
                            .frame(minHeight: 44)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var methodAndGearSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeWorkbenchSectionHeader(
                title: "Method & gear",
                subtitle: "Mugshot remembers the tools, not another score."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HomeBrewMethod.allCases) { method in
                        let selected = selectedMethod == method && draft.brewMethod.remoteTrimmedNonEmpty != nil
                        Button {
                            draft.brewMethod = method.title
                            if draft.brewDetails.homeMethodDetails == nil {
                                draft.brewDetails.homeMethodDetails = .empty
                            }
                            MugshotHaptic.selection.play()
                        } label: {
                            Label(method.title, systemImage: method.systemImage)
                                .font(.system(size: 11, weight: selected ? .bold : .semibold))
                                .foregroundStyle(selected ? Color.espressoBrown : Color.secondaryText)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 42)
                                .background(selected ? Color.mugshotMint.opacity(0.35) : Color.foamWhite, in: Capsule())
                                .overlay(Capsule().stroke(selected ? Color.mugshotSage : Color.mugshotLine, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("logASipV3.home.method.\(method.rawValue)")
                    }
                }
            }

            if !library.activeEquipment.isEmpty {
                FlexibleHomeChipLayout(spacing: 8) {
                    ForEach(library.activeEquipment) { profile in
                        let selected = isSelected(profile)
                        Button {
                            toggle(profile)
                        } label: {
                            Label(profile.displayName, systemImage: profile.role.systemImage)
                                .font(.system(size: 11, weight: selected ? .bold : .semibold))
                                .foregroundStyle(selected ? Color.espressoBrown : Color.secondaryText)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 40)
                                .background(selected ? Color.sandBeige : Color.foamWhite, in: Capsule())
                                .overlay(Capsule().stroke(selected ? Color.mugshotSage : Color.mugshotLine, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }

            HStack(spacing: 18) {
                Button {
                    presentedSheet = .equipment(.new)
                } label: {
                    Label("Add gear", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("logASipV3.home.addGear")

                if !library.equipment.isEmpty {
                    Menu {
                        ForEach(library.equipment.sorted { $0.updatedAt > $1.updatedAt }) { profile in
                            Button {
                                presentedSheet = .equipment(
                                    HomeEquipmentEditorConfiguration(equipment: profile)
                                )
                            } label: {
                                Label(
                                    profile.archivedAt == nil
                                        ? profile.displayName
                                        : "\(profile.displayName) · Archived",
                                    systemImage: profile.role.systemImage
                                )
                            }
                        }
                    } label: {
                        Label("Manage gear", systemImage: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.mugshotSage)
                            .frame(minHeight: 44)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var brewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                HomeWorkbenchSectionHeader(
                    title: "Today’s brew",
                    subtitle: "Only the useful evidence."
                )
                Spacer()
                if let ratio = draft.brewDetails.brewRatio {
                    Text("1:\(ratio.formatted(.number.precision(.fractionLength(1))))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.mugshotSage)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Color.mugshotMint.opacity(0.25), in: Capsule())
                        .accessibilityLabel("Brew ratio 1 to \(ratio.formatted(.number.precision(.fractionLength(1))))")
                }
            }

            LazyVGrid(
                columns: brewColumns,
                spacing: 10
            ) {
                HomeMeasurementField(
                    title: "Dose",
                    accessibilityIdentifier: "logASipV3.home.dose",
                    placeholder: "18",
                    unit: "g",
                    value: $draft.brewDetails.doseGrams,
                    previous: draft.homeComparisonSource?.brewDetails.doseGrams
                )

                if selectedMethod.usesYield {
                    HomeMeasurementField(
                        title: "Yield",
                        accessibilityIdentifier: "logASipV3.home.yield",
                        placeholder: "36",
                        unit: "g",
                        value: $draft.brewDetails.yieldGrams,
                        previous: draft.homeComparisonSource?.brewDetails.yieldGrams
                    )
                } else {
                    HomeMeasurementField(
                        title: "Water",
                        accessibilityIdentifier: "logASipV3.home.water",
                        placeholder: "300",
                        unit: "g",
                        value: homeDoubleBinding(\.waterGrams),
                        previous: draft.homeComparisonSource?.brewDetails.homeMethodDetails?.waterGrams
                    )
                }

                HomeTextValueField(
                    title: "Grind",
                    accessibilityIdentifier: "logASipV3.home.grind",
                    placeholder: "Setting",
                    text: optionalTextBinding(\.grindSetting),
                    previous: draft.homeComparisonSource?.brewDetails.grindSetting
                )

                HomeMeasurementField(
                    title: "Temperature",
                    accessibilityIdentifier: "logASipV3.home.temperature",
                    placeholder: "94",
                    unit: "°C",
                    value: $draft.brewDetails.waterTemperatureCelsius,
                    previous: draft.homeComparisonSource?.brewDetails.waterTemperatureCelsius
                )

                HomeIntegerField(
                    title: "Total time",
                    accessibilityIdentifier: "logASipV3.home.totalTime",
                    placeholder: "180",
                    unit: "sec",
                    value: $draft.brewDetails.brewTimeSeconds,
                    previous: draft.homeComparisonSource?.brewDetails.brewTimeSeconds
                )
            }

            DisclosureGroup(isExpanded: $dialInExpanded) {
                methodDetails
                    .padding(.top, 12)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Color.mugshotSage)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dial-in details")
                            .font(.system(size: 13, weight: .bold))
                        Text("Optional · tuned to \(selectedMethod.title.lowercased())")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.tertiaryText)
                    }
                }
            }
            .tint(Color.mugshotSage)
            .padding(14)
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var methodDetails: some View {
        HomeMethodDetailsEditor(draft: $draft, method: selectedMethod)
    }

    private func select(_ bag: CoffeeBag) {
        draft.homeCoffeeBagID = bag.id
        draft.brewDetails.coffeeBag = bag.safeSnapshot
        draft.brewDetails.beans = bag.displayName
        draft.brewDetails.beanOrigin = bag.origin.remoteTrimmedNonEmpty
        draft.brewDetails.roastLevel = bag.roastLevel.remoteTrimmedNonEmpty
        MugshotHaptic.selection.play()
    }

    private func select(_ profile: EquipmentProfile) {
        var snapshots = draft.brewDetails.equipmentSnapshots ?? []
        snapshots.removeAll { $0.role == profile.role && $0.displayName == profile.displayName }
        snapshots.append(profile.snapshot)
        draft.brewDetails.equipmentSnapshots = snapshots
        draft.equipment = snapshots.map(\.displayName).joined(separator: " · ")
    }

    private func toggle(_ profile: EquipmentProfile) {
        var snapshots = draft.brewDetails.equipmentSnapshots ?? []
        if isSelected(profile) {
            snapshots.removeAll { $0.role == profile.role && $0.displayName == profile.displayName }
        } else {
            snapshots.append(profile.snapshot)
        }
        draft.brewDetails.equipmentSnapshots = snapshots.isEmpty ? nil : snapshots
        draft.equipment = snapshots.map(\.displayName).joined(separator: " · ")
        MugshotHaptic.selection.play()
    }

    private func isSelected(_ profile: EquipmentProfile) -> Bool {
        (draft.brewDetails.equipmentSnapshots ?? []).contains {
            $0.role == profile.role && $0.displayName == profile.displayName
        }
    }

    private func clearSetup() {
        draft.homeCoffeeBagID = nil
        draft.homeComparisonSource = nil
        draft.brewMethod = ""
        draft.equipment = ""
        draft.brewDetails = .empty
        draft.contextNotes = ""
        draft.homeMakeAgain = nil
    }

    private func optionalTextBinding(_ keyPath: WritableKeyPath<BrewDetails, String?>) -> Binding<String> {
        Binding(
            get: { draft.brewDetails[keyPath: keyPath] ?? "" },
            set: { draft.brewDetails[keyPath: keyPath] = $0.remoteTrimmedNonEmpty }
        )
    }

    private func homeDoubleBinding(_ keyPath: WritableKeyPath<HomeMethodDetails, Double?>) -> Binding<Double?> {
        Binding(
            get: { draft.brewDetails.homeMethodDetails?[keyPath: keyPath] },
            set: { value in
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details[keyPath: keyPath] = value
                draft.brewDetails.homeMethodDetails = details
            }
        )
    }

    private func homeIntegerBinding(_ keyPath: WritableKeyPath<HomeMethodDetails, Int?>) -> Binding<Int?> {
        Binding(
            get: { draft.brewDetails.homeMethodDetails?[keyPath: keyPath] },
            set: { value in
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details[keyPath: keyPath] = value
                draft.brewDetails.homeMethodDetails = details
            }
        )
    }

    private func homeTextBinding(_ keyPath: WritableKeyPath<HomeMethodDetails, String?>) -> Binding<String> {
        Binding(
            get: { draft.brewDetails.homeMethodDetails?[keyPath: keyPath] ?? "" },
            set: { value in
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details[keyPath: keyPath] = value.remoteTrimmedNonEmpty
                draft.brewDetails.homeMethodDetails = details
            }
        )
    }

    private var stepsBinding: Binding<[BrewRecipeStep]> {
        Binding(
            get: { draft.brewDetails.steps ?? [] },
            set: { draft.brewDetails.steps = $0.isEmpty ? nil : $0 }
        )
    }

    private func synchronizeLibrary() async {
        guard let userID = draft.ownerUserID,
              let client = try? SupabaseClientProvider.shared.client() else { return }
        let service = HomeLibraryService(client: client)
        do {
            let remote = try await service.fetch(userID: userID)
            library = try store.mergeRemote(
                bags: remote.bags,
                equipment: remote.equipment,
                in: scope
            )

            for bag in library.bags where bag.ownerUserID == userID {
                _ = try await service.upsert(bag, userID: userID)
            }
            for equipment in library.equipment where equipment.ownerUserID == userID {
                _ = try await service.upsert(equipment, userID: userID)
            }
            syncMessage = nil
        } catch {
            syncMessage = "Saved on this device. Mugshot will sync your shelf when it can."
        }
    }
}

/// Post-brew entry keeps planned values visible, records only what changed,
/// and never tells the user that a variable caused the outcome.
struct HomeBrewActualsView: View {
    @Binding var draft: SipDraft
    @State private var dialInExpanded = false

    private var method: HomeBrewMethod {
        HomeBrewMethod(storedValue: draft.brewMethod)
    }

    private var comparison: HomeBrewComparison {
        .compare(current: draft.currentHomeBrewSnapshot, with: draft.homeComparisonSource)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: method.systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(width: 46, height: 46)
                    .background(Color.mugshotMint.opacity(0.24), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(draft.brewDetails.coffeeBag?.name ?? draft.drinkName.remoteTrimmedNonEmpty ?? "Today’s brew")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                    Text(method.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                }
                Spacer()
                if let version = draft.homeSourceRecipeVersion {
                    Text(version)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.mugshotMint.opacity(0.22), in: Capsule())
                }
            }

            if let source = draft.homeComparisonSource {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Compared with")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.tertiaryText)
                        .textCase(.uppercase)
                    Text([source.title, source.capturedAt.formatted(date: .abbreviated, time: .omitted)].joined(separator: " · "))
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.control).stroke(Color.mugshotLine, lineWidth: 1))
            }

            HomeWorkbenchSectionHeader(
                title: "Actual brew",
                subtitle: "Correct only what happened differently."
            )

            LazyVGrid(columns: [GridItem(.flexible())], spacing: 10) {
                HomeMeasurementField(
                    title: "Dose",
                    accessibilityIdentifier: "logASipV3.home.actuals.dose",
                    placeholder: "18",
                    unit: "g",
                    value: $draft.brewDetails.doseGrams,
                    previous: draft.homeComparisonSource?.brewDetails.doseGrams
                )
                if method.usesYield {
                    HomeMeasurementField(
                        title: "Yield",
                        accessibilityIdentifier: "logASipV3.home.actuals.yield",
                        placeholder: "36",
                        unit: "g",
                        value: $draft.brewDetails.yieldGrams,
                        previous: draft.homeComparisonSource?.brewDetails.yieldGrams
                    )
                } else {
                    HomeMeasurementField(
                        title: "Water",
                        accessibilityIdentifier: "logASipV3.home.actuals.water",
                        placeholder: "300",
                        unit: "g",
                        value: homeDoubleBinding(\.waterGrams),
                        previous: draft.homeComparisonSource?.brewDetails.homeMethodDetails?.waterGrams
                    )
                }
                HomeTextValueField(
                    title: "Grind",
                    accessibilityIdentifier: "logASipV3.home.actuals.grind",
                    placeholder: "Setting",
                    text: optionalTextBinding(\.grindSetting),
                    previous: draft.homeComparisonSource?.brewDetails.grindSetting
                )
                HomeMeasurementField(
                    title: "Temperature",
                    accessibilityIdentifier: "logASipV3.home.actuals.temperature",
                    placeholder: "94",
                    unit: "°C",
                    value: $draft.brewDetails.waterTemperatureCelsius,
                    previous: draft.homeComparisonSource?.brewDetails.waterTemperatureCelsius
                )
                HomeIntegerField(
                    title: "Total time",
                    accessibilityIdentifier: "logASipV3.home.actuals.totalTime",
                    placeholder: "30",
                    unit: "sec",
                    value: $draft.brewDetails.brewTimeSeconds,
                    previous: draft.homeComparisonSource?.brewDetails.brewTimeSeconds
                )
            }

            if let ratio = draft.brewDetails.brewRatio {
                HStack {
                    Label("Ratio", systemImage: "viewfinder")
                    Spacer()
                    Text("1:\(ratio.formatted(.number.precision(.fractionLength(1))))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.mugshotSage)
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(14)
                .background(Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.control).stroke(Color.mugshotLine, lineWidth: 1))
            }

            DisclosureGroup(isExpanded: $dialInExpanded) {
                HomeMethodDetailsEditor(draft: $draft, method: method)
                    .padding(.top, 12)
            } label: {
                Label("Dial-in actuals", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
            }
            .tint(Color.mugshotSage)
            .padding(14)
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.control).stroke(Color.mugshotLine, lineWidth: 1))

            comparisonSummary

            VStack(alignment: .leading, spacing: 7) {
                Label("Add my own change note", systemImage: "pencil")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                TextField("Anything the numbers missed", text: $draft.contextNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .padding(12)
                    .background(Color.foamWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mugshotLine, lineWidth: 1))
            }
        }
        .onChange(of: dialInExpanded) { _, expanded in
            if expanded {
                MugshotAnalytics.shared.capture(.homeWorkbench(action: .advancedFieldsOpened))
            }
        }
    }

    @ViewBuilder
    private var comparisonSummary: some View {
        if draft.homeComparisonSource == nil {
            Label("This is the first attempt in this line.", systemImage: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.secondaryText)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.sandBeige.opacity(0.36))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Mugshot noticed", systemImage: "leaf.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                    Spacer()
                    Label("Private", systemImage: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.tertiaryText)
                }
                Text(comparison.summary ?? "The recorded setup stayed the same.")
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text("This describes the difference. It does not claim what caused the result.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.tertiaryText)
            }
            .padding(14)
            .background(Color.mugshotMint.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.control).stroke(Color.mugshotLine, lineWidth: 1))
        }
    }

    private func optionalTextBinding(_ keyPath: WritableKeyPath<BrewDetails, String?>) -> Binding<String> {
        Binding(
            get: { draft.brewDetails[keyPath: keyPath] ?? "" },
            set: { draft.brewDetails[keyPath: keyPath] = $0.remoteTrimmedNonEmpty }
        )
    }

    private func homeDoubleBinding(_ keyPath: WritableKeyPath<HomeMethodDetails, Double?>) -> Binding<Double?> {
        Binding(
            get: { draft.brewDetails.homeMethodDetails?[keyPath: keyPath] },
            set: { value in
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details[keyPath: keyPath] = value
                draft.brewDetails.homeMethodDetails = details
            }
        )
    }
}

private struct HomeMethodDetailsEditor: View {
    @Binding var draft: SipDraft
    let method: HomeBrewMethod

    var body: some View {
        VStack(spacing: 10) {
            switch method {
            case .espresso:
                HomeIntegerField(title: "Preinfusion", accessibilityIdentifier: "logASipV3.home.preinfusion", placeholder: "5", unit: "sec", value: integerBinding(\.preinfusionSeconds), previous: previous(\.preinfusionSeconds))
                HomeMeasurementField(title: "Pressure", accessibilityIdentifier: "logASipV3.home.pressure", placeholder: "9", unit: "bar", value: doubleBinding(\.pressureBars), previous: previous(\.pressureBars))
                HomeTextValueField(title: "Flow note", accessibilityIdentifier: "logASipV3.home.flowNote", placeholder: "How the shot moved", text: textBinding(\.pressureFlowNotes), previous: previous(\.pressureFlowNotes))
            case .pourOver:
                HomeMeasurementField(title: "Bloom water", accessibilityIdentifier: "logASipV3.home.bloomWater", placeholder: "45", unit: "g", value: doubleBinding(\.bloomGrams), previous: previous(\.bloomGrams))
                HomeIntegerField(title: "Bloom time", accessibilityIdentifier: "logASipV3.home.bloomTime", placeholder: "45", unit: "sec", value: integerBinding(\.bloomSeconds), previous: previous(\.bloomSeconds))
                HomeTextValueField(title: "Pour pattern", accessibilityIdentifier: "logASipV3.home.pourPattern", placeholder: "Three gentle pours", text: textBinding(\.pourPattern), previous: previous(\.pourPattern))
                HomeRecipeStepsEditor(steps: stepsBinding, title: "Pour stages")
            case .aeroPress, .frenchPress, .immersion:
                HomeIntegerField(title: "Steep", accessibilityIdentifier: "logASipV3.home.steepTime", placeholder: "120", unit: "sec", value: integerBinding(\.steepSeconds), previous: previous(\.steepSeconds))
                HomeIntegerField(title: "Press", accessibilityIdentifier: "logASipV3.home.pressTime", placeholder: "30", unit: "sec", value: integerBinding(\.pressSeconds), previous: previous(\.pressSeconds))
                HomeTextValueField(title: "Agitation", accessibilityIdentifier: "logASipV3.home.agitation", placeholder: "Stir, swirl, or leave still", text: textBinding(\.agitationNotes), previous: previous(\.agitationNotes))
            case .mokaPot:
                HomeTextValueField(title: "Heat", accessibilityIdentifier: "logASipV3.home.heat", placeholder: "Low, lid open", text: textBinding(\.heatNotes), previous: previous(\.heatNotes))
            case .coldBrew:
                HomeMeasurementField(title: "Steep", accessibilityIdentifier: "logASipV3.home.coldBrewSteep", placeholder: "12", unit: "hr", value: doubleBinding(\.coldBrewSteepHours), previous: previous(\.coldBrewSteepHours))
                HomeTextValueField(title: "Serving note", accessibilityIdentifier: "logASipV3.home.servingNote", placeholder: "Dilution, ice, milk…", text: textBinding(\.customNotes), previous: previous(\.customNotes))
            case .batch, .pod, .other:
                HomeTextValueField(title: "Useful detail", accessibilityIdentifier: "logASipV3.home.customDetail", placeholder: "Anything future you needs", text: textBinding(\.customNotes), previous: previous(\.customNotes))
            }
        }
    }

    private func doubleBinding(_ keyPath: WritableKeyPath<HomeMethodDetails, Double?>) -> Binding<Double?> {
        Binding(
            get: { draft.brewDetails.homeMethodDetails?[keyPath: keyPath] },
            set: { value in
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details[keyPath: keyPath] = value
                draft.brewDetails.homeMethodDetails = details
            }
        )
    }

    private func integerBinding(_ keyPath: WritableKeyPath<HomeMethodDetails, Int?>) -> Binding<Int?> {
        Binding(
            get: { draft.brewDetails.homeMethodDetails?[keyPath: keyPath] },
            set: { value in
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details[keyPath: keyPath] = value
                draft.brewDetails.homeMethodDetails = details
            }
        )
    }

    private func textBinding(_ keyPath: WritableKeyPath<HomeMethodDetails, String?>) -> Binding<String> {
        Binding(
            get: { draft.brewDetails.homeMethodDetails?[keyPath: keyPath] ?? "" },
            set: { value in
                var details = draft.brewDetails.homeMethodDetails ?? .empty
                details[keyPath: keyPath] = value.remoteTrimmedNonEmpty
                draft.brewDetails.homeMethodDetails = details
            }
        )
    }

    private func previous<Value>(_ keyPath: KeyPath<HomeMethodDetails, Value?>) -> Value? {
        draft.homeComparisonSource?.brewDetails.homeMethodDetails?[keyPath: keyPath]
    }

    private var stepsBinding: Binding<[BrewRecipeStep]> {
        Binding(
            get: { draft.brewDetails.steps ?? [] },
            set: { draft.brewDetails.steps = $0.isEmpty ? nil : $0 }
        )
    }
}

private enum HomeWorkbenchSheet: Identifiable {
    case bag(HomeBagEditorConfiguration)
    case equipment(HomeEquipmentEditorConfiguration)

    var id: String {
        switch self {
        case .bag(let configuration): return "bag-\(configuration.id)"
        case .equipment(let configuration): return "equipment-\(configuration.id)"
        }
    }
}

private struct HomeBagEditorConfiguration: Identifiable {
    enum Mode { case scan, manual, edit }
    let id = UUID()
    let mode: Mode
    let bag: CoffeeBag?

    static let scan = HomeBagEditorConfiguration(mode: .scan, bag: nil)
    static let manual = HomeBagEditorConfiguration(mode: .manual, bag: nil)
    static func edit(_ bag: CoffeeBag) -> Self { HomeBagEditorConfiguration(mode: .edit, bag: bag) }
}

private struct HomeEquipmentEditorConfiguration: Identifiable {
    let id = UUID()
    let equipment: EquipmentProfile?

    static let new = HomeEquipmentEditorConfiguration(equipment: nil)
}

private struct HomeWorkbenchSectionHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundStyle(Color.espressoBrown)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.tertiaryText)
            }
        }
    }
}

private struct HomeCoffeeBagCard: View {
    let bag: CoffeeBag
    let image: UIImage?
    let isSelected: Bool
    let action: () -> Void
    let editAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 7) {
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.sandBeige.opacity(0.62)
                                .overlay(
                                    Image(systemName: "shippingbox.fill")
                                        .foregroundStyle(Color.mugshotSage)
                                )
                        }
                    }
                    .frame(width: 138, height: 66)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text(bag.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    HStack {
                        Text(bag.roaster.remoteTrimmedNonEmpty ?? bag.status.title)
                            .lineLimit(1)
                        Spacer()
                        Text(bag.status.title)
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.tertiaryText)
                }
                .foregroundStyle(Color.espressoBrown)
                .padding(8)
                .frame(width: 154, alignment: .leading)
                .background(isSelected ? Color.mugshotMint.opacity(0.25) : Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                        .stroke(isSelected ? Color.mugshotSage : Color.mugshotLine, lineWidth: isSelected ? 1.5 : 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Button(action: editAction) {
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(bag.displayName)")
            .padding(12)
        }
    }
}

private struct HomeMeasurementField: View {
    let title: String
    let accessibilityIdentifier: String
    let placeholder: String
    let unit: String
    @Binding var value: Double?
    let previous: Double?

    var body: some View {
        HomeValueFieldShell(title: title, previous: previous.map(format)) {
            HStack(spacing: 4) {
                TextField(placeholder, value: $value, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(accessibilityIdentifier)
                Text(unit)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.tertiaryText)
            }
        }
    }

    private func format(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
    }
}

private struct HomeIntegerField: View {
    let title: String
    let accessibilityIdentifier: String
    let placeholder: String
    let unit: String
    @Binding var value: Int?
    let previous: Int?

    var body: some View {
        HomeValueFieldShell(title: title, previous: previous.map { "\($0) \(unit)" }) {
            HStack(spacing: 4) {
                TextField(placeholder, value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(accessibilityIdentifier)
                Text(unit)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.tertiaryText)
            }
        }
    }
}

private struct HomeTextValueField: View {
    let title: String
    let accessibilityIdentifier: String
    let placeholder: String
    @Binding var text: String
    let previous: String?

    var body: some View {
        HomeValueFieldShell(title: title, previous: previous?.remoteTrimmedNonEmpty) {
            TextField(placeholder, text: $text)
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(title)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}

private struct HomeValueFieldShell<Content: View>: View {
    let title: String
    let previous: String?
    @ViewBuilder let content: Content

    init(title: String, previous: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.previous = previous
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                if let previous {
                    Text("was \(previous)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                        .lineLimit(1)
                }
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
    }
}

private struct HomeRecipeStepsEditor: View {
    @Binding var steps: [BrewRecipeStep]
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Button {
                    steps.append(BrewRecipeStep())
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .frame(minHeight: 44)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.mugshotSage)
                .buttonStyle(.plain)
            }

            ForEach($steps) { $step in
                HStack(spacing: 8) {
                    TextField("Pour to 150 g", text: $step.instruction)
                    TextField("sec", value: $step.durationSeconds, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 54)
                    Button(role: .destructive) {
                        steps.removeAll { $0.id == step.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove stage")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.leading, 10)
                .background(Color.sandBeige.opacity(0.32))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

private struct HomeCoffeeBagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let configuration: HomeBagEditorConfiguration
    let scope: LocalAccountScope
    let existingBags: [CoffeeBag]
    let store: HomeLibraryStore
    let onSaved: (CoffeeBag) -> Void

    @State private var bag: CoffeeBag
    @State private var image: UIImage?
    @State private var cameraImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var presentedCamera = false
    @State private var isScanning = false
    @State private var scanValues: [CoffeeBagScanFieldKey: CoffeeBagScanValue] = [:]
    @State private var errorMessage: String?
    @State private var showsMore = false

    init(
        configuration: HomeBagEditorConfiguration,
        scope: LocalAccountScope,
        existingBags: [CoffeeBag],
        store: HomeLibraryStore,
        onSaved: @escaping (CoffeeBag) -> Void
    ) {
        self.configuration = configuration
        self.scope = scope
        self.existingBags = existingBags
        self.store = store
        self.onSaved = onSaved
        _bag = State(initialValue: configuration.bag ?? CoffeeBag(ownerUserID: scope.userID))
    }

    private var canSave: Bool {
        bag.roaster.remoteTrimmedNonEmpty != nil || bag.name.remoteTrimmedNonEmpty != nil
    }

    private var duplicate: CoffeeBag? {
        existingBags.first { candidate in
            candidate.id != bag.id &&
                candidate.roaster.remoteTrimmedNonEmpty?.lowercased() == bag.roaster.remoteTrimmedNonEmpty?.lowercased() &&
                candidate.name.remoteTrimmedNonEmpty?.lowercased() == bag.name.remoteTrimmedNonEmpty?.lowercased()
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if configuration.mode == .scan {
                        scanCard
                    }

                    if let duplicate {
                        Label(
                            "This looks like \(duplicate.displayName), already on your shelf.",
                            systemImage: "square.on.square"
                        )
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.mugshotSage)
                        .padding(12)
                        .background(Color.mugshotMint.opacity(0.20))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    bagField(.roaster, title: "Roaster", text: $bag.roaster, placeholder: "Who roasted it?")
                    bagField(.name, title: "Coffee", text: $bag.name, placeholder: "Bag or lot name")
                    bagField(.origin, title: "Origin", text: $bag.origin, placeholder: "Country or region")
                    bagField(.process, title: "Process", text: $bag.process, placeholder: "Washed, natural, honey…")
                    bagField(.tastingNotes, title: "Tasting notes", text: $bag.tastingNotes, placeholder: "What the roaster noticed")

                    DisclosureGroup("More bag details", isExpanded: $showsMore) {
                        VStack(spacing: 12) {
                            bagField(.producer, title: "Producer", text: $bag.producer, placeholder: "Farm or washing station")
                            bagField(.variety, title: "Variety", text: $bag.variety, placeholder: "Coffee variety")
                            bagField(.roastLevel, title: "Roast", text: $bag.roastLevel, placeholder: "Light, medium, dark…")
                            DatePicker(
                                "Roast date",
                                selection: Binding(
                                    get: { bag.roastDate ?? .now },
                                    set: { bag.roastDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .font(.system(size: 12, weight: .semibold))

                            HStack(spacing: 10) {
                                HomeMeasurementField(
                                    title: "Bag size",
                                    accessibilityIdentifier: "logASipV3.home.bagStartingWeight",
                                    placeholder: "250",
                                    unit: "g",
                                    value: $bag.startingWeightGrams,
                                    previous: nil
                                )
                                HomeMeasurementField(
                                    title: "Estimated left",
                                    accessibilityIdentifier: "logASipV3.home.bagRemainingWeight",
                                    placeholder: "180",
                                    unit: "g",
                                    value: $bag.remainingWeightGrams,
                                    previous: nil
                                )
                            }
                        }
                        .padding(.top, 12)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .tint(Color.mugshotSage)

                    Picker("Bag status", selection: $bag.status) {
                        ForEach(CoffeeBagStatus.allCases.filter {
                            configuration.mode == .edit || $0 != .archived
                        }) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.mugshotSage)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.red)
                    }
                }
                .padding(16)
            }
            .background(Color.creamWhite)
            .navigationTitle(configuration.mode == .edit ? "Edit coffee" : "Add coffee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.bold)
                        .disabled(!canSave || isScanning)
                }
            }
            .fullScreenCover(isPresented: $presentedCamera) {
                CameraCaptureView(image: $cameraImage, isPresented: $presentedCamera)
            }
            .onChange(of: cameraImage) { _, image in
                guard let image else { return }
                self.image = image
                Task { await scan(image) }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        errorMessage = "Mugshot couldn’t open that image."
                        return
                    }
                    self.image = image
                    await scan(image)
                }
            }
        }
    }

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.sandBeige.opacity(0.52)
                            .overlay(Image(systemName: "viewfinder").foregroundStyle(Color.mugshotSage))
                    }
                }
                .frame(width: 72, height: 84)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(isScanning ? "Reading the bag…" : "Scan once. Check before saving.")
                        .font(.system(size: 13, weight: .bold))
                    Text("Everything is read on this iPhone. Uncertain fields are marked.")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if isScanning {
                        ProgressView().tint(Color.mugshotSage)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    presentedCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("logASipV3.home.scan.takePhoto")

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose photo", systemImage: "photo.on.rectangle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("logASipV3.home.scan.choosePhoto")
            }
        }
        .padding(14)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
    }

    private func bagField(
        _ key: CoffeeBagScanFieldKey,
        title: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        let scanValue = scanValues[key]
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                if scanValue?.isLowConfidence == true {
                    Label("Check this", systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.orange)
                }
            }
            TextField(placeholder, text: text, axis: key == .tastingNotes ? .vertical : .horizontal)
                .lineLimit(key == .tastingNotes ? 2...4 : 1...1)
                .font(.system(size: 14, weight: .semibold))
                .accessibilityLabel(title)
                .accessibilityIdentifier("logASipV3.home.bag.\(key.rawValue)")
                .padding(12)
                .background(Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(scanValue?.isLowConfidence == true ? Color.orange.opacity(0.7) : Color.mugshotLine, lineWidth: 1)
                )
        }
    }

    private func scan(_ image: UIImage) async {
        isScanning = true
        errorMessage = nil
        do {
            let proposal = try await CoffeeBagScanService().scan(image)
            guard !proposal.values.isEmpty else {
                throw CoffeeBagScanError.noText
            }
            scanValues = Dictionary(uniqueKeysWithValues: proposal.values.map { ($0.key, $0) })
            apply(proposal)
            MugshotAnalytics.shared.capture(.homeWorkbench(action: .scanSucceeded))
        } catch {
            errorMessage = error.localizedDescription
            MugshotAnalytics.shared.capture(.homeWorkbench(action: .scanFallback))
        }
        isScanning = false
    }

    private func apply(_ proposal: CoffeeBagScanProposal) {
        if let value = proposal[.roaster]?.value { bag.roaster = value }
        if let value = proposal[.name]?.value { bag.name = value }
        if let value = proposal[.producer]?.value { bag.producer = value }
        if let value = proposal[.origin]?.value { bag.origin = value }
        if let value = proposal[.process]?.value { bag.process = value }
        if let value = proposal[.variety]?.value { bag.variety = value }
        if let value = proposal[.roastLevel]?.value { bag.roastLevel = value }
        if let value = proposal[.tastingNotes]?.value { bag.tastingNotes = value }
        if let rawDate = proposal[.roastDate]?.value {
            bag.roastDate = HomeBagDateParser.date(from: rawDate)
        }
    }

    private func save() {
        guard canSave else { return }
        do {
            bag.ownerUserID = scope.userID
            bag.updatedAt = .now
            if let image {
                bag.localPhotoPath = try store.saveBagPhoto(image, bagID: bag.id, in: scope)
            }
            _ = try store.upsert(bag, in: scope)
            onSaved(bag)

            if let userID = scope.userID,
               let client = try? SupabaseClientProvider.shared.client() {
                let savedBag = bag
                Task {
                    var remoteBag = savedBag
                    let service = HomeLibraryService(client: client)
                    if let image {
                        remoteBag.privatePhotoPath = try? await service.uploadBagPhoto(
                            image,
                            bagID: savedBag.id,
                            userID: userID
                        )
                    }
                    if let persisted = try? await service.upsert(remoteBag, userID: userID) {
                        var merged = persisted
                        merged.localPhotoPath = savedBag.localPhotoPath
                        _ = try? store.upsert(merged, in: scope)
                    }
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum HomeBagDateParser {
    static func date(from raw: String) -> Date? {
        let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "MMM d yyyy", "MMMM d yyyy"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }
}

private struct HomeEquipmentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let configuration: HomeEquipmentEditorConfiguration
    let scope: LocalAccountScope
    let store: HomeLibraryStore
    let onSaved: (EquipmentProfile) -> Void

    @State private var equipment: EquipmentProfile
    @State private var errorMessage: String?

    init(
        configuration: HomeEquipmentEditorConfiguration,
        scope: LocalAccountScope,
        store: HomeLibraryStore,
        onSaved: @escaping (EquipmentProfile) -> Void
    ) {
        self.configuration = configuration
        self.scope = scope
        self.store = store
        self.onSaved = onSaved
        _equipment = State(initialValue: configuration.equipment ?? EquipmentProfile(ownerUserID: scope.userID))
    }

    private var canSave: Bool {
        equipment.nickname.remoteTrimmedNonEmpty != nil ||
            equipment.brand.remoteTrimmedNonEmpty != nil ||
            equipment.model.remoteTrimmedNonEmpty != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Role", selection: $equipment.role) {
                    ForEach(EquipmentRole.allCases) { role in
                        Label(role.title, systemImage: role.systemImage).tag(role)
                    }
                }
                TextField("Nickname", text: $equipment.nickname)
                TextField("Brand", text: $equipment.brand)
                TextField("Model", text: $equipment.model)
                TextField("Private notes", text: $equipment.notes, axis: .vertical)
                    .lineLimit(2...4)

                if configuration.equipment != nil {
                    Toggle(
                        "Archived",
                        isOn: Binding(
                            get: { equipment.archivedAt != nil },
                            set: { equipment.archivedAt = $0 ? .now : nil }
                        )
                    )
                    .tint(Color.mugshotSage)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Color.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle(configuration.equipment == nil ? "Add gear" : "Edit gear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        do {
            equipment.ownerUserID = scope.userID
            equipment.updatedAt = .now
            _ = try store.upsert(equipment, in: scope)
            onSaved(equipment)
            if let userID = scope.userID,
               let client = try? SupabaseClientProvider.shared.client() {
                let savedEquipment = equipment
                Task {
                    _ = try? await HomeLibraryService(client: client)
                        .upsert(savedEquipment, userID: userID)
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// A compact wrapping layout keeps optional gear and delta chips readable
/// without turning the Home workbench into a grid of form rows.
private struct FlexibleHomeChipLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HomeFlowLayout(spacing: spacing) { content }
    }
}

private struct HomeFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#if DEBUG
struct HomeWorkbenchLabGallery: View {
    private enum LabState: String, CaseIterable, Identifiable {
        case espresso = "Espresso"
        case pourOver = "Pour-over"
        case casual = "Casual"
        case comparison = "Compare"
        case empty = "Empty"
        case scanning = "Scanning"

        var id: String { rawValue }
    }

    @State private var state: LabState
    @State private var draft: SipDraft
    private let populatedStore: HomeLibraryStore
    private let emptyStore: HomeLibraryStore

    init(initialState: String? = nil) {
        let startingState = initialState.flatMap(LabState.init(rawValue:)) ?? .espresso
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MugshotHomeWorkbenchLab",
            isDirectory: true
        )
        let populatedStore = HomeLibraryStore(
            baseDirectory: root.appendingPathComponent("Populated", isDirectory: true)
        )
        let emptyStore = HomeLibraryStore(
            baseDirectory: root.appendingPathComponent("Empty", isDirectory: true)
        )
        self.populatedStore = populatedStore
        self.emptyStore = emptyStore
        _state = State(initialValue: startingState)
        _draft = State(initialValue: Self.fixture(for: startingState))

        let bag = CoffeeBag(
            id: UUID(uuidString: "b8a11d51-7143-46de-b633-20fd72a0a822")!,
            roaster: "Little Wolf",
            name: "Shantawene",
            origin: "Ethiopia",
            process: "Washed",
            roastLevel: "Light",
            status: .open
        )
        _ = try? populatedStore.upsert(bag, in: .guest)
        _ = try? populatedStore.upsert(
            EquipmentProfile(
                id: UUID(uuidString: "cd307cbf-d098-4593-b571-2e8041dd454e")!,
                role: .grinder,
                nickname: "Niche Zero"
            ),
            in: .guest
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Workbench state", selection: $state) {
                ForEach(LabState.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            if state == .scanning {
                HomeWorkbenchScanningLabState()
            } else {
                ScrollView {
                    HomeWorkbenchView(
                        draft: $draft,
                        store: state == .empty ? emptyStore : populatedStore,
                        initiallyShowsDialInDetails: state == .pourOver
                    )
                    .id(state)
                    .padding(16)
                }
            }
        }
        .background(Color.creamWhite)
        .navigationTitle("Home Workbench Lab")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: state) { _, state in
            draft = Self.fixture(for: state)
        }
    }

    private static func fixture(for state: LabState) -> SipDraft {
        switch state {
        case .espresso:
            return SipDraft(
                context: .home,
                drinkName: "Shantawene espresso",
                brewMethod: HomeBrewMethod.espresso.title,
                brewDetails: BrewDetails(
                    doseGrams: 18.5,
                    yieldGrams: 40,
                    brewTimeSeconds: 29,
                    grindSetting: "17",
                    waterTemperatureCelsius: 94,
                    homeMethodDetails: HomeMethodDetails(preinfusionSeconds: 5, pressureBars: 9)
                )
            )
        case .pourOver:
            return SipDraft(
                context: .home,
                drinkName: "Morning V60",
                brewMethod: HomeBrewMethod.pourOver.title,
                brewDetails: BrewDetails(
                    doseGrams: 20,
                    brewTimeSeconds: 185,
                    grindSetting: "5.2",
                    waterTemperatureCelsius: 96,
                    steps: [
                        BrewRecipeStep(instruction: "Bloom to 60 g"),
                        BrewRecipeStep(instruction: "Pour to 200 g"),
                        BrewRecipeStep(instruction: "Finish at 320 g")
                    ],
                    homeMethodDetails: HomeMethodDetails(
                        waterGrams: 320,
                        bloomSeconds: 45
                    )
                )
            )
        case .casual:
            return SipDraft(
                context: .home,
                drinkName: "Sunday coffee",
                brewMethod: HomeBrewMethod.pod.title
            )
        case .comparison:
            let baseline = HomeBrewSnapshot(
                drinkName: "Yesterday’s best",
                brewMethod: HomeBrewMethod.espresso.title,
                equipment: "Niche Zero",
                brewDetails: BrewDetails(
                    doseGrams: 18,
                    yieldGrams: 38,
                    brewTimeSeconds: 31,
                    grindSetting: "16"
                ),
                makeAgain: .yes
            )
            return SipDraft(
                context: .home,
                drinkName: "Dial-in attempt",
                brewMethod: HomeBrewMethod.espresso.title,
                brewDetails: BrewDetails(
                    doseGrams: 18.5,
                    yieldGrams: 40,
                    brewTimeSeconds: 29,
                    grindSetting: "17"
                ),
                homeComparisonSource: baseline
            )
        case .empty, .scanning:
            return SipDraft(context: .home, drinkName: "New home coffee")
        }
    }
}

private struct HomeWorkbenchScanningLabState: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MugshotScreenHeader(
                    "Check this coffee",
                    subtitle: "Nothing saves until you confirm it."
                )
                Label("Read on this iPhone", systemImage: "lock.shield.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)

                ForEach([
                    ("Roaster", "Little Wolf", false),
                    ("Coffee", "Shantawene", false),
                    ("Origin", "Ethiopia", false),
                    ("Process", "Washed", true),
                    ("Roast date", "AUG 14 2026", true)
                ], id: \.0) { field in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(field.0).font(.system(size: 11, weight: .bold))
                            Spacer()
                            if field.2 {
                                Label("Check this", systemImage: "exclamationmark.circle.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.orange)
                            }
                        }
                        Text(field.1)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.foamWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Label(
                    "Possible match: Shantawene · open bag",
                    systemImage: "rectangle.on.rectangle"
                )
                .font(.system(size: 11, weight: .semibold))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.sandBeige.opacity(0.52))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
        }
    }
}

#Preview("Home workbench · espresso") {
    ScrollView {
        HomeWorkbenchView(
            draft: .constant(SipDraft(
                context: .home,
                locationName: "Home",
                drinkName: "Ethiopia Shantawene",
                overallScore: 4.5,
                brewMethod: "Espresso",
                equipment: "Linea Mini · Niche Zero",
                brewDetails: BrewDetails(
                    beans: "Ethiopia Shantawene",
                    doseGrams: 18.5,
                    yieldGrams: 40,
                    brewTimeSeconds: 29,
                    grindSetting: "17",
                    waterTemperatureCelsius: 94,
                    equipmentSnapshots: [
                        EquipmentSnapshot(role: .espressoMachine, displayName: "Linea Mini"),
                        EquipmentSnapshot(role: .grinder, displayName: "Niche Zero")
                    ],
                    homeMethodDetails: HomeMethodDetails(preinfusionSeconds: 5, pressureBars: 9)
                )
            ))
        )
        .padding(16)
    }
    .background(Color.creamWhite)
}
#endif
