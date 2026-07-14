import AVFoundation
import CoreLocation
import MapKit
import SwiftUI
import Supabase
import UIKit

struct LogVisitView: View {
    @ObservedObject var dataManager: DataManager
    var preselectedCafe: Cafe? = nil
    private let explicitLaunchDraft: SipDraft?

    @EnvironmentObject private var tabCoordinator: TabCoordinator
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SipComposerExperience.storageKey) private var composerExperienceRaw = SipComposerExperience.defaultExperience.rawValue

    @StateObject private var composerModel: SipComposerModel
    @State private var photoImages: [UIImage] = []
    @State private var didRestoreDraft = false
    @State private var suppressContextDefaults = false
    @State private var showCriteriaEditor = false
    @State private var showPhotoSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showCameraPermissionRecovery = false
    @State private var showTextOnlyConfirmation = false
    @State private var confirmedTextOnlyEveryone = false
    @State private var isSaving = false
    @State private var showSavedConfirmation = false
    @State private var errorMessage: String?
    @State private var pendingSubmission: PendingVisitSubmissionRecord?
    @State private var uploadRecoveryMessage: String?
    @State private var servingVolumeUnit: ServingVolumeUnit = .preferredForCurrentLocale

    @StateObject private var searchService = MapSearchService()
    @StateObject private var locationManager = LocationManager()
    @State private var searchText = ""
    @State private var isCafeSearchActive = false
    @State private var cafeSearchRegion = Self.defaultSearchRegion

    private static let defaultSearchRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    private var composerExperience: SipComposerExperience {
#if DEBUG
        SipComposerExperience(rawValue: composerExperienceRaw) ?? .defaultExperience
#else
        .guided
#endif
    }

    private var draft: SipDraft {
        get { composerModel.draft }
        nonmutating set { composerModel.draft = newValue }
    }

    private var primaryContext: Binding<JournalEntryContext> {
        Binding(
            get: { draft.context == .cafe ? .cafe : .home },
            set: { draft.context = $0 }
        )
    }

    private var homeUsesRecipe: Binding<Bool> {
        Binding(
            get: { draft.context == .recipe },
            set: { draft.context = $0 ? .recipe : .home }
        )
    }

    init(
        dataManager: DataManager,
        preselectedCafe: Cafe? = nil,
        initialDraft: SipDraft? = nil
    ) {
        self.dataManager = dataManager
        self.preselectedCafe = preselectedCafe
        self.explicitLaunchDraft = initialDraft
        let restoredImages = initialDraft.flatMap { SipDraftStore.shared.load(id: $0.id)?.images } ?? []
        _photoImages = State(initialValue: restoredImages)
        _composerModel = StateObject(wrappedValue: SipComposerModel(
            draft: initialDraft ?? Self.initialDraft(
                dataManager: dataManager,
                preselectedCafe: preselectedCafe
            )
        ))
    }

    private static func initialDraft(
        dataManager: DataManager,
        preselectedCafe: Cafe?,
        ownerUserID: UUID? = nil
    ) -> SipDraft {
        var draft = SipDraft(
            ownerUserID: ownerUserID,
            launchContext: SipComposerLaunchContext(
                source: preselectedCafe == nil ? .centralAdd : .cafeDetail,
                preselectedCafe: preselectedCafe
            ),
            cafe: preselectedCafe,
            visibility: CafeVisibilityPreferenceStore.shared.defaultCafeVisibility
        )
        draft.refreshRatingCriteria(from: dataManager.appData.ratingTemplate)
        return draft
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamWhite.ignoresSafeArea()

                Group {
                    if composerExperience == .longForm {
                        longFormComposer
                    } else {
                        guidedComposer
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                if showSavedConfirmation {
                    savedConfirmation
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
                        .zIndex(5)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { cancelComposer() }
                        .foregroundColor(.espressoBrown)
                        .accessibilityHint("Keeps this sip as a draft")
                }

                ToolbarItem(placement: .principal) {
                    Text("LOG A SIP")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(.roastBrown)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Label("Draft saved", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundColor(.mugshotSage)
                        .accessibilityLabel("Draft saved automatically")
                }
            }
            .toolbarBackground(Color.creamWhite, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) { composerFooter }
            .sheet(isPresented: $showCriteriaEditor) {
                SipCriteriaEditor(
                    criteria: $composerModel.draft.ratingCriteria,
                    onSaveTemplate: savePersonalCriteria
                )
            }
            .confirmationDialog(
                "Add a photo",
                isPresented: $showPhotoSourceDialog,
                titleVisibility: .visible
            ) {
                Button("Take Photo") { requestCamera() }
                Button("Choose from Library") { showPhotoLibrary = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Photos are optional for Private and Friends sips.")
            }
            .sheet(isPresented: $showCamera) {
                CameraCaptureView(
                    image: Binding(
                        get: { nil },
                        set: { image in
                            if let image { appendPhotos([image]) }
                        }
                    ),
                    isPresented: $showCamera
                )
            }
            .sheet(isPresented: $showPhotoLibrary) {
                PhotoLibraryPickerView(
                    images: Binding(
                        get: { [] },
                        set: { appendPhotos($0) }
                    ),
                    isPresented: $showPhotoLibrary,
                    maximumSelectionCount: max(1, 10 - photoImages.count)
                )
            }
            .alert("Camera access is off", isPresented: $showCameraPermissionRecovery) {
                Button("Choose from Library") { showPhotoLibrary = true }
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow Camera access in Settings, or choose a photo from your library.")
            }
            .alert("Publish without a photo?", isPresented: $showTextOnlyConfirmation) {
                Button("Publish Text Only") {
                    confirmedTextOnlyEveryone = true
                    saveSip()
                }
                Button("Add Photo") { showPhotoSourceDialog = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Everyone posts usually include a photo. Confirm that you want this tasting note to be text only.")
            }
            .onAppear { restoreDraftIfNeeded() }
            .onChange(of: draft) { _, _ in persistDraft() }
            .onChange(of: draft.drinkName) { _, _ in refreshDrinkAnalysis() }
            .onChange(of: draft.brewDetails.servingVolumeMilliliters) { _, _ in refreshDrinkAnalysis() }
            .onChange(of: draft.brewDetails.espressoShotCount) { _, _ in refreshDrinkAnalysis() }
            .onChange(of: composerExperienceRaw) { _, _ in
                draft.composerExperience = composerExperience
                persistDraft()
            }
            .onChange(of: draft.context) { oldContext, newContext in
                guard oldContext != newContext, !suppressContextDefaults else { return }
                draft.applyContextDefaults(using: .shared)
                confirmedTextOnlyEveryone = false
            }
            .onChange(of: draft.visibility) { _, _ in
                confirmedTextOnlyEveryone = false
            }
            .onChange(of: locationManager.location) { _, location in
                if let location { updateSearchRegion(for: location) }
            }
            .onChange(of: authModel.authenticatedUser?.id) { _, userID in
                guard let userID else { return }
                if draft.ownerUserID == nil { draft.ownerUserID = userID }
                if let pending = PendingVisitSubmissionStore.shared.load(userId: userID) {
                    pendingSubmission = pending
                    uploadRecoveryMessage = "An earlier save was interrupted. Retry continues the same sip without making a duplicate."
                }
            }
        }
        .background(Color.creamWhite.ignoresSafeArea())
    }

    private var longFormComposer: some View {
        ScrollView {
            VStack(spacing: 16) {
                composerHeader
                contextCard
                locationCard
                drinkCard
                overallRatingCard
                addToMemoryCard

                if draft.isMemoryExpanded {
                    memoryCard
                    detailContent
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    visibilityCard
                }

                recoveryAndValidationContent
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .containerRelativeFrame(.horizontal)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var guidedComposer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                guidedHeader
                guidedProgress

                switch draft.resolvedGuidedStep {
                case .context:
                    contextCard
                    locationCard
                case .drink:
                    drinkCard
                    memoryCard
                    if draft.context == .cafe {
                        guidedCafeContextCard
                    }
                case .rating:
                    if draft.launchContext.source == .repeatSip || draft.launchContext.source == .brewAgain {
                        repeatedSipContext
                    }
                    overallRatingCard
                    Button(action: openMemoryStep) {
                        Label("Add optional details", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                case .memory:
                    guidedDetailContent
                    visibilityCard
                }

                recoveryAndValidationContent
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .containerRelativeFrame(.horizontal)
        }
        .scrollDismissesKeyboard(.interactively)
        .id(draft.resolvedGuidedStep)
    }

    private var repeatedSipContext: some View {
        HStack(spacing: 12) {
            Image(systemName: draft.launchContext.source == .brewAgain
                ? "arrow.clockwise.circle.fill"
                : "plus.square.on.square")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.mugshotSage)
                .frame(width: 36, height: 36)
                .background(Color.mugshotMint.opacity(0.6), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.launchContext.source == .brewAgain ? "Brewing again" : "Repeating this sip")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.mugshotSage)
                Text(draft.drinkName.remoteTrimmedNonEmpty ?? "Saved sip")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(1)
                Text(draft.context == .cafe ? draft.cafe?.name ?? "Cafe" : draft.locationName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var recoveryAndValidationContent: some View {
        if let uploadRecoveryMessage {
            recoveryCard(uploadRecoveryMessage)
        }
        if let errorMessage {
            ValidationErrorCard(errors: [errorMessage])
        }
    }

    private var composerHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Remember this sip.")
                .mugshotDisplay(size: 36)
                .foregroundColor(.espressoBrown)

            Text("Capture what you drank, where it happened, and what stood out.")
                .font(.system(size: 15))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var guidedHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(guidedTitle)
                .mugshotDisplay(size: 38)
                .foregroundColor(.espressoBrown)

            Text(guidedSubtitle)
                .font(.system(size: 15))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var guidedProgress: some View {
        HStack(spacing: 7) {
            ForEach(SipGuidedStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.number <= draft.resolvedGuidedStep.number ? Color.mugshotSage : Color.sandBeige)
                    .frame(height: 6)
                    .animation(reduceMotion ? nil : DesignSystem.Motion.base, value: draft.resolvedGuidedStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(draft.resolvedGuidedStep.number) of 4")
        .accessibilityRespondsToUserInteraction(false)
    }

    private var contextCard: some View {
        SipComposerCard(step: "01", title: "Where are you sipping?", subtitle: contextSubtitle) {
            MugshotSegmentedControl(
                options: [.cafe, .home],
                selection: primaryContext,
                title: { $0.rawValue },
                icon: { $0.systemImage }
            )

            if draft.context != .cafe {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How are you brewing?")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.espressoBrown)

                    MugshotSegmentedControl(
                        options: [false, true],
                        selection: homeUsesRecipe,
                        title: { $0 ? "Recipe" : "One-time brew" },
                        icon: { $0 ? "book.pages.fill" : "clock.arrow.circlepath" }
                    )
                }

                contextExplainer(
                    icon: draft.context == .recipe ? "book.pages.fill" : "clock.arrow.circlepath",
                    title: draft.context == .recipe ? "Recipe is a reusable blueprint" : "Home is an attempt",
                    text: draft.context == .recipe
                        ? "Save this sip with a named version you can brew again later."
                        : "Keep this brew independent so you can compare it with every other try."
                )
            }
        }
    }

    @ViewBuilder
    private var locationCard: some View {
        if draft.context == .cafe {
            CafeLocationSection(
                selectedCafe: $composerModel.draft.cafe,
                searchText: $searchText,
                isSearchActive: $isCafeSearchActive,
                searchService: searchService,
                dataManager: dataManager,
                searchRegion: cafeSearchRegion,
                searchAreaDescription: searchAreaDescription,
                locationActionTitle: locationActionTitle,
                onLocationAction: useCurrentLocation
            )
        } else {
            SipComposerCard(step: nil, title: "Brew context", subtitle: "Home is remembered, but you can rename this setup.") {
                TextField("Home", text: $composerModel.draft.locationName)
                    .textInputAutocapitalization(.words)
                    .mugshotFormField()
            }
        }
    }

    private var drinkCard: some View {
        SipComposerCard(step: "02", title: "What did you drink?", subtitle: "Say it naturally. Mugshot organizes the details for your journal.") {
            TextField(
                "Iced cinnamon and orange cortado",
                text: $composerModel.draft.drinkName,
                axis: .vertical
            )
                .textInputAutocapitalization(.sentences)
                .submitLabel(.continue)
                .lineLimit(1...3)
                .accessibilityIdentifier("sipComposer.drinkName")
                .mugshotFormField()

            Text("Try the full order name—temperature, milk, flavor, preparation, or shot count can all live here.")
                .font(.system(size: 12))
                .foregroundColor(.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var overallRatingCard: some View {
        SipComposerCard(step: "03", title: "How was it?", subtitle: ratingSubtitle) {
            ratingModeControl

            if draft.captureMode == .quickSip {
                HalfStepStarRating(value: $composerModel.draft.overallScore, label: "Overall sip rating")
                    .accessibilityIdentifier("sipComposer.overallRating")

                HStack {
                    Text(draft.overallScore > 0 ? scoreLabel : "Tap a half or whole star")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondaryText)
                    Spacer()
                    Text(draft.overallScore > 0 ? String(format: "%.1f", draft.overallScore) : "—")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.espressoBrown)
                }
            } else {
                personalRatingContent
            }
        }
    }

    private var ratingModeControl: some View {
        HStack(spacing: 8) {
            ratingModeButton(
                title: "Quick rating",
                subtitle: "One score",
                systemImage: "star.fill",
                mode: .quickSip
            )
            ratingModeButton(
                title: "Use my tasting lens",
                subtitle: "What matters to you",
                systemImage: "sparkles",
                mode: .addDetails
            )
        }
    }

    private func ratingModeButton(
        title: String,
        subtitle: String,
        systemImage: String,
        mode: SipCaptureMode
    ) -> some View {
        let selected = draft.captureMode == mode
        return Button {
            withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
                draft.captureMode = mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selected ? Color.foamWhite.opacity(0.78) : Color.tertiaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .padding(.horizontal, 12)
            .foregroundColor(selected ? .foamWhite : .espressoBrown)
            .background(selected ? Color.mugshotSage : Color.sandBeige.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("sipComposer.ratingMode.\(mode == .quickSip ? "quick" : "lens")")
    }

    private var personalRatingContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Your criteria", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.mugshotSage)
                Spacer()
                Button("Customize") { showCriteriaEditor = true }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.mugshotSage)
            }

            ForEach(Array(draft.ratingCriteria.sorted { $0.sortOrder < $1.sortOrder }.enumerated()), id: \.element.id) { _, criterion in
                if let index = draft.ratingCriteria.firstIndex(where: { $0.id == criterion.id }) {
                    DetailedCriterionRow(criterion: $composerModel.draft.ratingCriteria[index])
                }
            }

            if draft.ratingCriteria.isEmpty {
                Button("Add your first criterion") { showCriteriaEditor = true }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.mugshotSage)
            }

            if draft.resolvedOverallScore > 0 {
                HStack {
                    Text("Tasting lens overall")
                    Spacer()
                    Text(String(format: "%.1f", draft.resolvedOverallScore))
                        .font(.system(size: 22, weight: .bold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .padding(.top, 4)
            }

            Text("The criteria you rate are shared with this sip. Criteria marked not relevant are left out.")
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var addToMemoryCard: some View {
        Button {
            withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
                draft.memoryDetailsExpanded = !draft.isMemoryExpanded
            }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 42, height: 42)
                    .background(Color.mugshotMint.opacity(0.25))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Add to the memory")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Text("Photo, thought, tasting context, and private notes")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: draft.isMemoryExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.mugshotSage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.mugshotLine))
        }
        .buttonStyle(.plain)
    }

    private var memoryCard: some View {
        SipComposerCard(step: nil, title: "Make it memorable", subtitle: "A photo and one-line thought are optional.") {
            HStack(alignment: .top, spacing: 12) {
                Button { showPhotoSourceDialog = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: photoImages.isEmpty ? "camera.fill" : "photo.stack.fill")
                        Text(photoImages.isEmpty ? "Add photo" : "\(photoImages.count) photo\(photoImages.count == 1 ? "" : "s")")
                            .lineLimit(1)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.espressoBrown)
                    .padding(.horizontal, 13)
                    .frame(height: 46)
                    .background(Color.sandBeige.opacity(0.72))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                TextField("One-line thought", text: $composerModel.draft.socialCaption, axis: .vertical)
                    .lineLimit(1...2)
                    .fixedSize(horizontal: false, vertical: true)
                    .mugshotFormField()
                    .accessibilityIdentifier("sipComposer.socialCaption")
            }

            if !photoImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photoImages.indices, id: \.self) { index in
                            Image(uiImage: photoImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    Button { removePhoto(at: index) } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color.foamWhite, Color.espressoBrown.opacity(0.72))
                                    }
                                    .offset(x: 5, y: -5)
                                    .accessibilityLabel("Remove photo \(index + 1)")
                                }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var guidedCafeContextCard: some View {
        SipComposerCard(
            step: nil,
            title: "Tags and company",
            subtitle: "Optional context that helps this sip feel like yours."
        ) {
            TextField("Tags, separated by commas", text: arrayBinding(\.tags))
                .mugshotFormField()

            TextField("Who you shared it with, separated by commas", text: arrayBinding(\.companions))
                .mugshotFormField()
        }
    }

    @ViewBuilder
    private var guidedDetailContent: some View {
        servingDetailsCard

        switch draft.context {
        case .cafe:
            EmptyView()
        case .home:
            homeDetailsCard(includeRecipe: false)
        case .recipe:
            homeDetailsCard(includeRecipe: true)
        }

        privateNotesCard
    }

    @ViewBuilder
    private var detailContent: some View {
        servingDetailsCard

        switch draft.context {
        case .cafe:
            cafeDetailsCard
        case .home:
            homeDetailsCard(includeRecipe: false)
        case .recipe:
            homeDetailsCard(includeRecipe: true)
        }

        privateNotesCard
    }

    private var servingDetailsCard: some View {
        SipComposerCard(
            step: nil,
            title: "Serving details",
            subtitle: "Optional size and espresso-base details for your journal."
        ) {
            HStack(spacing: 10) {
                TextField("Serving size", text: servingVolumeBinding)
                    .keyboardType(.decimalPad)
                    .mugshotFormField()

                Picker("Serving unit", selection: $servingVolumeUnit) {
                    ForEach(ServingVolumeUnit.allCases) { unit in
                        Text(unit.shortTitle).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 112)
            }

            Picker("Espresso base", selection: espressoShotCountBinding) {
                Text("Not specified").tag(nil as Int?)
                Text("Single shot").tag(1 as Int?)
                Text("Double shot").tag(2 as Int?)
                Text("Triple shot").tag(3 as Int?)
                Text("Quad shot").tag(4 as Int?)
            }
            .pickerStyle(.menu)
            .tint(.mugshotSage)
        }
    }

    private var cafeDetailsCard: some View {
        SipComposerCard(step: nil, title: "Tags and company", subtitle: "Optional context that helps this sip feel like yours.") {
            TextField("Tags, separated by commas", text: arrayBinding(\.tags))
                .mugshotFormField()

            TextField("Who you shared it with, separated by commas", text: arrayBinding(\.companions))
                .mugshotFormField()
        }
    }

    private func homeDetailsCard(includeRecipe: Bool) -> some View {
        SipComposerCard(
            step: nil,
            title: includeRecipe ? "Recipe blueprint" : "Brew details",
            subtitle: includeRecipe
                ? "Save this version without overwriting the brews that came before it."
                : "Record only the variables that help your next attempt."
        ) {
            if includeRecipe {
                HStack(spacing: 10) {
                    TextField("Recipe name", text: optionalText(\.recipeName))
                        .mugshotFormField()
                    TextField("Version", text: optionalText(\.recipeVersion))
                        .frame(maxWidth: 105)
                        .mugshotFormField()
                }
            }

            TextField("Beans", text: optionalText(\.beans))
                .mugshotFormField()

            HStack(spacing: 10) {
                TextField("Dose (g)", text: optionalDouble(\.doseGrams))
                    .keyboardType(.decimalPad)
                    .mugshotFormField()
                TextField("Yield (g)", text: optionalDouble(\.yieldGrams))
                    .keyboardType(.decimalPad)
                    .mugshotFormField()
                TextField("Time (s)", text: optionalInt(\.brewTimeSeconds))
                    .keyboardType(.numberPad)
                    .mugshotFormField()
            }

            HStack(spacing: 10) {
                TextField("Origin", text: optionalText(\.beanOrigin))
                    .mugshotFormField()
                TextField("Roast", text: optionalText(\.roastLevel))
                    .mugshotFormField()
            }

            HStack(spacing: 10) {
                TextField("Grind", text: optionalText(\.grindSetting))
                    .mugshotFormField()
                TextField("Water °C", text: optionalDouble(\.waterTemperatureCelsius))
                    .keyboardType(.decimalPad)
                    .mugshotFormField()
            }

            TextField("Brew method", text: $composerModel.draft.brewMethod)
                .mugshotFormField()
            TextField("Equipment", text: $composerModel.draft.equipment)
                .mugshotFormField()
            TextField("Water notes", text: optionalText(\.waterNotes))
                .mugshotFormField()
            TextField("Additions", text: optionalText(\.additions))
                .mugshotFormField()

            if includeRecipe {
                recipeSteps
            }
        }
    }

    private var recipeSteps: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reusable steps")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Spacer()
                Button {
                    var steps = draft.brewDetails.steps ?? []
                    steps.append(BrewRecipeStep())
                    draft.brewDetails.steps = steps
                } label: {
                    Label("Add step", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.mugshotSage)
            }

            ForEach(Array((draft.brewDetails.steps ?? []).enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.foamWhite)
                        .frame(width: 26, height: 26)
                        .background(Color.mugshotSage)
                        .clipShape(Circle())

                    TextField("Step instruction", text: recipeStepBinding(step.id), axis: .vertical)
                        .lineLimit(1...3)
                        .mugshotFormField()
                }
            }

            Label("Brew this again will create a new Home draft from this exact version.", systemImage: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var privateNotesCard: some View {
        SipComposerCard(
            step: nil,
            title: "Private notes",
            subtitle: "Owner-only journal space. This is stored separately and can never appear in Feed or sharing."
        ) {
            TextField("What do you want only yourself to remember?", text: $composerModel.draft.privateNotes, axis: .vertical)
                .lineLimit(3...7)
                .mugshotFormField()
                .accessibilityIdentifier("sipComposer.privateNotes")

            Label("Only you", systemImage: "lock.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.mugshotSage)
        }
    }

    private var visibilityCard: some View {
        SipComposerCard(step: nil, title: "Who can see this sip?", subtitle: visibilitySubtitle) {
            MugshotSegmentedControl(
                options: [VisitVisibility.private, .friends, .everyone],
                selection: $composerModel.draft.visibility,
                title: { $0.rawValue },
                icon: { visibilityIcon($0) }
            )

            if draft.visibility == .everyone && photoImages.isEmpty {
                Label("Text-only Everyone posts ask for confirmation before publishing.", systemImage: "exclamationmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var saveFooter: some View {
        VStack(spacing: 7) {
            Button { saveSip() } label: {
                HStack(spacing: 9) {
                    if isSaving {
                        ProgressView().tint(.foamWhite)
                    } else {
                        Image(systemName: "checkmark")
                    }
                    Text(saveButtonTitle)
                    Spacer()
                    Text(draft.visibility.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.foamWhite.opacity(0.14))
                        .clipShape(Capsule())
                }
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSaving)

            Text("Context, drink, and one rating path are all you need.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().overlay(Color.mugshotLine) }
    }

    private var savedConfirmation: some View {
        VStack(spacing: 12) {
            Image("MugsyComingSoon")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text("Sip remembered")
                .mugshotDisplay(size: 26)
                .foregroundColor(.espressoBrown)
            Text("Back to your day.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondaryText)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .mugshotGlassSurface(radius: 26, tint: .foamWhite, interactive: false)
        .padding(28)
    }

    private func recoveryCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundColor(.mugshotSage)
            VStack(alignment: .leading, spacing: 3) {
                Text("Your sip is safe")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.sandBeige.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func contextExplainer(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.mugshotSage)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.sandBeige.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var contextSubtitle: String {
        switch draft.context {
        case .cafe: return "Attach the real place so Map and discovery stay useful."
        case .home: return "A single brew attempt, kept independent in your history."
        case .recipe: return "A sip plus a versioned blueprint you can brew again."
        }
    }

    private var guidedTitle: String {
        switch draft.resolvedGuidedStep {
        case .context: return "Where did this happen?"
        case .drink: return "Name the sip."
        case .rating: return "Make it yours."
        case .memory: return "Keep what mattered."
        }
    }

    private var guidedSubtitle: String {
        switch draft.resolvedGuidedStep {
        case .context: return "Start with Cafe or Home. Recipes live inside Home when you need one."
        case .drink: return "Use the order name you will recognize later."
        case .rating: return "Choose one quick score or open your personal tasting lens."
        case .memory: return "Everything here is optional. Save only the details worth remembering."
        }
    }

    private var ratingSubtitle: String {
        draft.captureMode == .quickSip
            ? "One honest score in half-star steps."
            : "Rate the qualities that define this sip for you."
    }

    private var visibilitySubtitle: String {
        switch draft.context {
        case .cafe: return "Cafe sips remember your last audience choice."
        case .home, .recipe: return "Home sips begin Private every time."
        }
    }

    private var scoreLabel: String {
        switch draft.overallScore {
        case 4.5...5: return "One to remember"
        case 3.5..<4.5: return "A good sip"
        case 2.5..<3.5: return "Mixed feelings"
        default: return "Part of the journey"
        }
    }

    private var saveButtonTitle: String {
        if isSaving { return photoImages.isEmpty ? "Saving sip…" : "Saving photos…" }
        if pendingSubmission != nil { return "Retry same sip" }
        if uploadRecoveryMessage != nil { return "Retry save" }
        return "Save sip"
    }

    @ViewBuilder
    private var composerFooter: some View {
        if composerExperience == .guided {
            guidedFooter
        } else {
            saveFooter
        }
    }

    private var guidedFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if draft.resolvedGuidedStep != .context {
                    Button(action: moveToPreviousGuidedStep) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel("Previous step")
                }

                Button(action: performGuidedPrimaryAction) {
                    HStack(spacing: 9) {
                        if isSaving {
                            ProgressView().tint(.foamWhite)
                        } else {
                            Image(systemName: guidedPrimaryIcon)
                        }
                        Text(guidedPrimaryTitle)
                        Spacer()
                        if draft.resolvedGuidedStep == .rating || draft.resolvedGuidedStep == .memory {
                            Text(guidedSaveVisibility.rawValue)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.foamWhite.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving || !canPerformGuidedPrimaryAction)
                .accessibilityIdentifier("sipComposer.primaryAction")
            }

            Text(guidedFooterHint)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().overlay(Color.mugshotLine) }
    }

    private func visibilityIcon(_ visibility: VisitVisibility) -> String {
        switch visibility {
        case .private: return "lock.fill"
        case .friends: return "person.2.fill"
        case .everyone: return "globe.americas.fill"
        }
    }

    private func restoreDraftIfNeeded() {
        guard !didRestoreDraft else { return }
        didRestoreDraft = true

        if explicitLaunchDraft == nil,
           let stored = SipDraftStore.shared.load(),
           shouldResume(stored.draft) {
            suppressContextDefaults = true
            draft = stored.draft
            photoImages = stored.images
            DispatchQueue.main.async { suppressContextDefaults = false }
        } else {
            draft.ownerUserID = authModel.authenticatedUser?.id
            draft.refreshRatingCriteria(from: dataManager.appData.ratingTemplate)
        }
#if DEBUG
        if MugshotLaunchEnvironment.shouldSeedUITestPhoto, photoImages.isEmpty {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96))
            let fixturePhoto = renderer.image { context in
                UIColor(red: 0.36, green: 0.49, blue: 0.40, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: CGSize(width: 96, height: 96)))
            }
            photoImages = [fixturePhoto]
        }
#endif
        draft.composerExperience = composerExperience
        if draft.guidedStep == nil { draft.guidedStep = .context }
        refreshDrinkAnalysis()

        if draft.uploadState == .failed, uploadRecoveryMessage == nil {
            uploadRecoveryMessage = "Your last save was interrupted. Retry continues the same sip and photos."
        }

        if let userID = authModel.authenticatedUser?.id,
           let pending = PendingVisitSubmissionStore.shared.load(userId: userID) {
            pendingSubmission = pending
            uploadRecoveryMessage = "An earlier save was interrupted. Retry continues the same sip without making a duplicate."
        }

        initializeLocationIfAvailable()
        persistDraft()
    }

    private func shouldResume(_ storedDraft: SipDraft) -> Bool {
        guard explicitLaunchDraft == nil else { return false }
        guard let preselectedCafe else { return true }
        guard storedDraft.context == .cafe, let storedCafe = storedDraft.cafe else { return false }
        if storedCafe.id == preselectedCafe.id { return true }
        if let storedRemoteID = storedCafe.remoteCafeId,
           let selectedRemoteID = preselectedCafe.remoteCafeId,
           storedRemoteID == selectedRemoteID {
            return true
        }
        return false
    }

    private func persistDraft() {
        guard didRestoreDraft, draft.hasMeaningfulContent || !photoImages.isEmpty else { return }
        do {
            let stored = try SipDraftStore.shared.save(draft, images: photoImages)
            if draft.localPhotoNames != stored.localPhotoNames {
                draft.localPhotoNames = stored.localPhotoNames
                draft.posterPhotoIndex = stored.posterPhotoIndex
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelComposer() {
        persistDraft()
        tabCoordinator.returnFromComposer()
        dismiss()
    }

    private func saveSip() {
        SipSaveDiagnostics.record(.requested, draftID: draft.id, visitID: pendingSubmission?.id)
        errorMessage = validationMessage
        guard errorMessage == nil else {
            SipSaveDiagnostics.record(.validationBlocked, draftID: draft.id, visitID: pendingSubmission?.id)
            return
        }

        if SipPublicationPolicy.requirement(
            visibility: draft.visibility,
            photoCount: photoImages.count,
            socialCaption: draft.socialCaption,
            confirmedTextOnlyEveryone: confirmedTextOnlyEveryone
        ) == .needsTextOnlyConfirmation {
            SipSaveDiagnostics.record(.awaitingTextOnlyConfirmation, draftID: draft.id, visitID: pendingSubmission?.id)
            showTextOnlyConfirmation = true
            return
        }

#if DEBUG
        if MugshotLaunchEnvironment.consumeAuthenticationInterruption() {
            persistDraft()
            errorMessage = "Sign back in to save. Your draft will stay here."
            return
        }
        if MugshotLaunchEnvironment.consumeForcedSaveFailure() {
            draft.uploadState = .failed
            persistDraft()
            uploadRecoveryMessage = "The network interrupted this save. Retry continues the same sip and photos."
            errorMessage = "We couldn’t finish this save. Your sip is safe—try again."
            return
        }
#endif

        if draft.context == .cafe {
            CafeVisibilityPreferenceStore.shared.rememberCafeVisibility(draft.visibility)
        }

        if let authenticatedUser = authModel.authenticatedUser {
            Task { await saveRemote(authenticatedUser: authenticatedUser) }
        } else {
            saveLocal()
        }
    }

    private var validationMessage: String? {
        if let ownerUserID = draft.ownerUserID,
           let authenticatedUserID = authModel.authenticatedUser?.id,
           ownerUserID != authenticatedUserID {
            return "This draft belongs to the account that started it. Sign back into that account to save it."
        }
        if draft.context == .cafe && draft.cafe == nil {
            return "Choose a cafe before saving this sip."
        }
        if draft.context != .cafe && draft.locationName.remoteTrimmedNonEmpty == nil {
            return "Name this home context before saving."
        }
        if draft.drinkName.remoteTrimmedNonEmpty == nil {
            return "Add the drink you want to remember."
        }
        if draft.resolvedOverallScore < 0.5 || draft.resolvedOverallScore > 5 {
            return draft.captureMode == .addDetails
                ? "Rate at least one relevant tasting criterion."
                : "Add one overall How was it? rating."
        }
        if SipPublicationPolicy.requirement(
            visibility: draft.visibility,
            photoCount: photoImages.count,
            socialCaption: draft.socialCaption,
            confirmedTextOnlyEveryone: confirmedTextOnlyEveryone
        ) == .needsTextOrPhoto {
            return "Add a one-line thought or photo before sharing this sip with Everyone."
        }
        if authModel.authenticatedUser == nil && dataManager.appData.currentUser == nil {
            return "Sign back in to save. Your draft will stay here."
        }
        return nil
    }

    private func saveLocal() {
        guard let userID = dataManager.appData.currentUser?.id else { return }
        isSaving = true
        SipSaveDiagnostics.record(.localSaveStarted, draftID: draft.id)

        let cafe = draft.cafe ?? dataManager.findOrCreateCafe(
            named: draft.locationName.remoteTrimmedNonEmpty ?? draft.context.locationFallback
        )
        let photoPaths = photoImages.enumerated().map { index, image in
            let path = "photo_\(UUID().uuidString)_\(index)"
            PhotoCache.shared.store(image, forKey: path)
            return path
        }
        let visit = Visit(
            cafeId: cafe.id,
            userId: userID,
            drinkType: draft.drinkType,
            customDrinkType: draft.drinkType == .other ? draft.customDrinkType : nil,
            caption: draft.socialCaption,
            notes: draft.privateNotes.remoteTrimmedNonEmpty,
            context: draft.context,
            locationName: draft.context == .cafe ? draft.cafe?.name : draft.locationName,
            brewMethod: draft.brewMethod.remoteTrimmedNonEmpty,
            equipment: draft.equipment.remoteTrimmedNonEmpty,
            brewDetails: submissionBrewDetails,
            drinkAnalysis: draft.drinkAnalysis,
            photos: photoPaths,
            posterPhotoIndex: draft.posterPhotoIndex,
            ratings: draft.ratingsDictionary,
            ratingCriteria: draft.ratingCriteria,
            overallScore: draft.resolvedOverallScore,
            visibility: draft.visibility,
            mentions: MentionParser.parseMentions(from: draft.socialCaption)
        )
        dataManager.addVisit(visit)
        completeSuccessfulSave(visitID: visit.id)
    }

    @MainActor
    private func saveRemote(authenticatedUser: AuthenticatedUser) async {
        isSaving = true
        errorMessage = nil
        SipSaveDiagnostics.record(.remoteSaveStarted, draftID: draft.id, visitID: pendingSubmission?.id)

        do {
            let client = try SupabaseClientProvider.shared.client()
            let service = VisitService(client: client)
            let pendingStore = PendingVisitSubmissionStore.shared
            var submission: PendingVisitSubmissionRecord

            if let pendingSubmission {
                submission = pendingSubmission
            } else {
                submission = try pendingStore.prepare(
                    userId: authenticatedUser.id,
                    cafe: draft.cafe,
                    entryContext: draft.context,
                    locationName: draft.locationName,
                    drinkType: draft.drinkType,
                    customDrinkType: draft.customDrinkType,
                    drinkSubtype: draft.drinkName,
                    caption: draft.socialCaption,
                    notes: draft.privateNotes.remoteTrimmedNonEmpty,
                    brewMethod: draft.brewMethod,
                    equipment: draft.equipment,
                    brewDetails: submissionBrewDetails,
                    visibility: draft.visibility,
                    ratings: draft.ratingsDictionary,
                    overallScore: draft.resolvedOverallScore,
                    ratingTemplate: draft.ratingTemplateSnapshot,
                    images: photoImages,
                    posterPhotoIndex: draft.posterPhotoIndex
                )
                self.pendingSubmission = submission
                SipSaveDiagnostics.record(.submissionPrepared, draftID: draft.id, visitID: submission.id)
            }

            if submission.phase == .prepared {
                _ = try await service.createVisit(
                    visitId: submission.id,
                    userId: submission.userId,
                    cafe: submission.cafe,
                    entryContext: submission.resolvedEntryContext,
                    locationName: submission.locationName,
                    drinkType: submission.drinkType,
                    customDrinkType: submission.customDrinkType,
                    drinkSubtype: submission.drinkSubtype,
                    brewMethod: submission.brewMethod,
                    equipment: submission.equipment,
                    brewDetails: submission.resolvedBrewDetails,
                    caption: submission.caption,
                    notes: submission.notes,
                    visibility: .private,
                    ratings: submission.ratings,
                    overallScore: submission.resolvedOverallScore,
                    ratingTemplate: submission.ratingTemplate,
                    uploadState: .uploading
                )
                submission.phase = .visitCreated
                try pendingStore.save(submission)
                self.pendingSubmission = submission
                SipSaveDiagnostics.record(.visitCreated, draftID: draft.id, visitID: submission.id)
            }

            if submission.phase < .photosUploaded {
#if DEBUG
                if !submission.objectPaths.isEmpty,
                   MugshotLaunchEnvironment.consumeRemotePhotoUploadFailure() {
                    throw URLError(.networkConnectionLost)
                }
#endif
                let images = try pendingStore.loadImages(for: submission)
                let result = try await VisitPhotoUploadService(client: client).uploadPhotos(
                    userId: submission.userId,
                    visitId: submission.id,
                    images: images,
                    posterPhotoIndex: submission.posterPhotoIndex,
                    plannedObjectPaths: submission.objectPaths,
                    replacingExisting: true
                )
                submission.uploadedPhotoURLs = result.publicURLs
                submission.phase = .photosUploaded
                try pendingStore.save(submission)
                self.pendingSubmission = submission
                SipSaveDiagnostics.record(.photosUploaded, draftID: draft.id, visitID: submission.id)
            }

            let urls = submission.uploadedPhotoURLs ?? []
            let attached = try await service.attachPhotoURLs(
                visitId: submission.id,
                photoURLs: urls,
                posterPhotoIndex: submission.posterPhotoIndex
            )
            _ = try await service.finalizeVisit(
                visitId: submission.id,
                userId: submission.userId,
                visibility: submission.visibility
            )
            SipSaveDiagnostics.record(.visitFinalized, draftID: draft.id, visitID: submission.id)

            DrinkAnalysisRetryStore.shared.enqueue(
                visitId: submission.id,
                userId: submission.userId
            )
            Task {
                await DrinkAnalysisService(client: client).requestAnalysisDurably(
                    visitId: submission.id,
                    userId: submission.userId
                )
            }
            SipSaveDiagnostics.record(.analysisQueued, draftID: draft.id, visitID: submission.id)

            if let cafeID = attached.cafe?.id {
                try? await CafeStateService(client: client).clearWantToTryAfterVisit(
                    userId: submission.userId,
                    cafeId: cafeID
                )
            }

            pendingStore.remove(submission)
            self.pendingSubmission = nil
            uploadRecoveryMessage = nil
            dataManager.noteJournalMutation()
            completeSuccessfulSave(visitID: submission.id)
        } catch {
            isSaving = false
            SipSaveDiagnostics.record(.failed, draftID: draft.id, visitID: pendingSubmission?.id)
            draft.uploadState = .failed
            persistDraft()
            if let pendingSubmission {
                let client = try? SupabaseClientProvider.shared.client()
                if let client, pendingSubmission.phase >= .visitCreated {
                    try? await VisitService(client: client).markVisitUploadFailed(
                        visitId: pendingSubmission.id,
                        userId: pendingSubmission.userId
                    )
                }
                uploadRecoveryMessage = "The network interrupted this save. Retry continues the same sip and photos."
            }
            errorMessage = MugshotUserFacingError.message(for: error, context: .photoUpload)
        }
    }

    @MainActor
    private func completeSuccessfulSave(visitID: UUID) {
        isSaving = false
        SipSaveDiagnostics.record(.completed, draftID: draft.id, visitID: visitID)
        if draft.context == .cafe {
            CafeVisibilityPreferenceStore.shared.rememberCafeVisibility(draft.visibility)
        }
        SipDraftStore.shared.remove(draft)
        var replacement = Self.initialDraft(
            dataManager: dataManager,
            preselectedCafe: nil,
            ownerUserID: authModel.authenticatedUser?.id ?? dataManager.appData.currentUser?.id
        )
        replacement.composerExperience = composerExperience
        composerModel.draft = replacement
        photoImages.removeAll()
        searchText = ""
        isCafeSearchActive = false
        confirmedTextOnlyEveryone = false
        showTextOnlyConfirmation = false
        pendingSubmission = nil
        uploadRecoveryMessage = nil
        withAnimation(DesignSystem.Motion.base) { showSavedConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            tabCoordinator.returnFromComposer(fallback: 4)
            dismiss()
        }
    }

    private var submissionBrewDetails: BrewDetails {
        var details = draft.brewDetails
        details.orderNotes = draft.orderNotes.remoteTrimmedNonEmpty
        details.tags = draft.tags.isEmpty ? nil : draft.tags
        details.companions = draft.companions.isEmpty ? nil : draft.companions
        if draft.context == .recipe {
            if details.recipeIdentityID == nil { details.recipeIdentityID = UUID() }
        }
        return details
    }

    private func refreshDrinkAnalysis() {
        composerModel.refreshDrinkAnalysis()
    }

    private func openMemoryStep() {
        draft.memoryDetailsExpanded = true
        moveToGuidedStep(.memory)
    }

    private func moveToPreviousGuidedStep() {
        let prior: SipGuidedStep
        switch draft.resolvedGuidedStep {
        case .context: return
        case .drink: prior = .context
        case .rating: prior = .drink
        case .memory: prior = .rating
        }
        moveToGuidedStep(prior)
    }

    private func performGuidedPrimaryAction() {
        switch draft.resolvedGuidedStep {
        case .context:
            guard hasCompletedContext else { return }
            moveToGuidedStep(.drink)
        case .drink:
            guard draft.drinkName.remoteTrimmedNonEmpty != nil else { return }
            moveToGuidedStep(.rating)
        case .rating:
            draft.visibility = .private
            confirmedTextOnlyEveryone = false
            saveSip()
        case .memory:
            saveSip()
        }
    }

    private func moveToGuidedStep(_ step: SipGuidedStep) {
        errorMessage = nil
        withAnimation(reduceMotion ? nil : DesignSystem.Motion.base) {
            draft.guidedStep = step
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private var hasCompletedContext: Bool {
        draft.context == .cafe ? draft.cafe != nil : draft.locationName.remoteTrimmedNonEmpty != nil
    }

    private var canPerformGuidedPrimaryAction: Bool {
        switch draft.resolvedGuidedStep {
        case .context: return hasCompletedContext
        case .drink: return draft.drinkName.remoteTrimmedNonEmpty != nil
        case .rating: return draft.resolvedOverallScore >= 0.5 && draft.resolvedOverallScore <= 5
        case .memory: return draft.hasRequiredCore
        }
    }

    private var guidedPrimaryTitle: String {
        switch draft.resolvedGuidedStep {
        case .context, .drink: return "Continue"
        case .rating:
            return isSaving || pendingSubmission != nil ? saveButtonTitle : "Save privately now"
        case .memory: return saveButtonTitle
        }
    }

    private var guidedPrimaryIcon: String {
        switch draft.resolvedGuidedStep {
        case .context, .drink: return "arrow.right"
        case .rating: return "lock.fill"
        case .memory: return "checkmark"
        }
    }

    private var guidedSaveVisibility: VisitVisibility {
        draft.resolvedGuidedStep == .rating ? .private : draft.visibility
    }

    private var guidedFooterHint: String {
        switch draft.resolvedGuidedStep {
        case .context: return "Your draft is saved as you go."
        case .drink: return "Mugshot will organize this in the background."
        case .rating: return "Save this privately now, or add details and choose an audience."
        case .memory: return "Optional details never block a private save."
        }
    }

    private func savePersonalCriteria() {
        let categories = draft.ratingCriteria
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { criterion -> RatingCategory? in
                guard let name = criterion.name.remoteTrimmedNonEmpty else { return nil }
                return RatingCategory(id: criterion.id, name: name, weight: max(criterion.weight, 0.25))
            }
        dataManager.updateRatingTemplate(RatingTemplate(categories: categories))
    }

    private func appendPhotos(_ images: [UIImage]) {
        let remaining = max(0, 10 - photoImages.count)
        photoImages.append(contentsOf: images.prefix(remaining))
        persistDraft()
    }

    private func removePhoto(at index: Int) {
        guard photoImages.indices.contains(index) else { return }
        photoImages.remove(at: index)
        if draft.localPhotoNames.indices.contains(index) {
            draft.localPhotoNames.remove(at: index)
        }
        draft.posterPhotoIndex = min(draft.posterPhotoIndex, max(photoImages.count - 1, 0))
        persistDraft()
    }

    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true }
                    else { showCameraPermissionRecovery = true }
                }
            }
        case .denied, .restricted:
            showCameraPermissionRecovery = true
        @unknown default:
            showCameraPermissionRecovery = true
        }
    }

    private var searchAreaDescription: String {
        if locationManager.location != nil { return "Searching around your current location" }
        switch locationManager.authorizationStatus {
        case .denied, .restricted: return "Location is off — search by cafe or neighborhood"
        case .notDetermined: return "Search nearby or type a cafe name"
        default: return "Finding your current location…"
        }
    }

    private var locationActionTitle: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted: return "Settings"
        case .authorizedAlways, .authorizedWhenInUse: return locationManager.location == nil ? "Find me" : "Near me"
        case .notDetermined: return "Near me"
        @unknown default: return "Near me"
        }
    }

    private func initializeLocationIfAvailable() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        locationManager.startUpdatingLocation()
        if let location = locationManager.location { updateSearchRegion(for: location) }
    }

    private func useCurrentLocation() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestCurrentLocation()
            if let location = locationManager.location { updateSearchRegion(for: location) }
        case .notDetermined:
            locationManager.requestLocationPermission()
        case .denied, .restricted:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        @unknown default:
            break
        }
    }

    private func updateSearchRegion(for location: CLLocation) {
        cafeSearchRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        if !searchText.isEmpty { searchService.search(query: searchText, region: cafeSearchRegion) }
    }

    private func optionalText(_ keyPath: WritableKeyPath<BrewDetails, String?>) -> Binding<String> {
        Binding(
            get: { draft.brewDetails[keyPath: keyPath] ?? "" },
            set: { draft.brewDetails[keyPath: keyPath] = $0 }
        )
    }

    private func optionalDouble(_ keyPath: WritableKeyPath<BrewDetails, Double?>) -> Binding<String> {
        Binding(
            get: {
                guard let value = draft.brewDetails[keyPath: keyPath] else { return "" }
                return value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
            },
            set: { draft.brewDetails[keyPath: keyPath] = Double($0.replacingOccurrences(of: ",", with: ".")) }
        )
    }

    private func optionalInt(_ keyPath: WritableKeyPath<BrewDetails, Int?>) -> Binding<String> {
        Binding(
            get: { draft.brewDetails[keyPath: keyPath].map(String.init) ?? "" },
            set: { draft.brewDetails[keyPath: keyPath] = Int($0) }
        )
    }

    private var servingVolumeBinding: Binding<String> {
        Binding(
            get: {
                guard let milliliters = draft.brewDetails.servingVolumeMilliliters else { return "" }
                let value = servingVolumeUnit.displayValue(fromMilliliters: milliliters)
                return value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
            },
            set: { value in
                guard let number = Double(value.replacingOccurrences(of: ",", with: ".")), number > 0 else {
                    draft.brewDetails.servingVolumeMilliliters = nil
                    return
                }
                draft.brewDetails.servingVolumeMilliliters = servingVolumeUnit.milliliters(fromDisplayValue: number)
            }
        )
    }

    private var espressoShotCountBinding: Binding<Int?> {
        Binding(
            get: { draft.brewDetails.espressoShotCount },
            set: { draft.brewDetails.espressoShotCount = $0 }
        )
    }

    private func arrayBinding(_ keyPath: WritableKeyPath<SipDraft, [String]>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath].joined(separator: ", ") },
            set: { value in
                draft[keyPath: keyPath] = value
                    .split(separator: ",")
                    .compactMap { String($0).remoteTrimmedNonEmpty }
            }
        )
    }

    private func recipeStepBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { draft.brewDetails.steps?.first(where: { $0.id == id })?.instruction ?? "" },
            set: { value in
                guard let index = draft.brewDetails.steps?.firstIndex(where: { $0.id == id }) else { return }
                draft.brewDetails.steps?[index].instruction = value
            }
        )
    }
}

private struct SipComposerCard<Content: View>: View {
    let step: String?
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(step: String?, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.step = step
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                if let step {
                    Text(step)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.mugshotSage)
                        .frame(width: 30, height: 30)
                        .background(Color.mugshotMint.opacity(0.35))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.045), radius: 12, x: 0, y: 5)
    }
}

struct HalfStepStarRating: View {
    @Binding var value: Double
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { index in
                GeometryReader { proxy in
                    Image(systemName: symbol(for: index))
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundColor(value >= Double(index) - 0.5 ? .mugshotSage : .espressoBrown.opacity(0.18))
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { gesture in
                                    value = Self.ratingValue(
                                        starIndex: index,
                                        tapX: gesture.location.x,
                                        starWidth: proxy.size.width
                                    )
                                }
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 42)
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value > 0 ? "\(String(format: "%.1f", value)) out of 5" : "Not rated")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(5, max(0.5, value + 0.5))
            case .decrement: value = max(0.5, value - 0.5)
            @unknown default: break
            }
        }
    }

    private func symbol(for index: Int) -> String {
        let threshold = Double(index)
        if value >= threshold { return "star.fill" }
        if value >= threshold - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }

    static func ratingValue(starIndex: Int, tapX: CGFloat, starWidth: CGFloat) -> Double {
        let clampedIndex = min(max(starIndex, 1), 5)
        let isLeadingHalf = tapX < max(starWidth, 1) / 2
        return Double(clampedIndex) - (isLeadingHalf ? 0.5 : 0)
    }
}

private struct DetailedCriterionRow: View {
    @Binding var criterion: SipRatingCriterionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(criterion.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
                if criterion.weight != 1 {
                    Text("\(formatWeight(criterion.weight)) influence")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.mugshotSage)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.mugshotMint.opacity(0.25))
                        .clipShape(Capsule())
                }
                Spacer()
                Button(criterion.isRelevant ? "Mark N/A" : "Include") {
                    criterion.isRelevant.toggle()
                    if !criterion.isRelevant { criterion.score = 0 }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.mugshotSage)
                .buttonStyle(.plain)

                Text(criterion.isRelevant && criterion.score > 0 ? String(format: "%.1f", criterion.score) : "—")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondaryText)
            }
            HalfStepStarRating(value: $criterion.score, label: criterion.name)
                .frame(height: 34)
                .disabled(!criterion.isRelevant)
                .opacity(criterion.isRelevant ? 1 : 0.32)
        }
        .padding(.vertical, 4)
    }

    private func formatWeight(_ value: Double) -> String {
        value.rounded() == value ? String(format: "%.0fx", value) : String(format: "%.1fx", value)
    }
}

private struct SipCriteriaEditor: View {
    @Binding var criteria: [SipRatingCriterionSnapshot]
    let onSaveTemplate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($criteria) { $criterion in
                        HStack(spacing: 10) {
                            TextField("Criterion", text: $criterion.name)
                            Spacer()
                            Picker("Influence", selection: $criterion.weight) {
                                Text("0.5x").tag(0.5)
                                Text("1x").tag(1.0)
                                Text("1.5x").tag(1.5)
                                Text("2x").tag(2.0)
                            }
                            .pickerStyle(.menu)
                            .tint(.mugshotSage)
                        }
                    }
                    .onDelete { criteria.remove(atOffsets: $0) }
                    .onMove { source, destination in
                        criteria.move(fromOffsets: source, toOffset: destination)
                        for index in criteria.indices { criteria[index].sortOrder = index }
                    }
                } header: {
                    Text("Your criteria")
                } footer: {
                    Text("Order and influence are snapshotted with every sip, so changing this later never rewrites your history.")
                }

                Section("Add another") {
                    HStack {
                        TextField("Aroma, clarity, freshness…", text: $newName)
                        Button("Add") { addCriterion() }
                            .disabled(newName.remoteTrimmedNonEmpty == nil)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Tasting lens")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        normalizeCriteria()
                        onSaveTemplate()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func addCriterion() {
        guard let name = newName.remoteTrimmedNonEmpty else { return }
        criteria.append(SipRatingCriterionSnapshot(name: name, sortOrder: criteria.count))
        newName = ""
    }

    private func normalizeCriteria() {
        criteria = criteria.enumerated().compactMap { index, criterion in
            guard let name = criterion.name.remoteTrimmedNonEmpty else { return nil }
            var copy = criterion
            copy.name = name
            copy.sortOrder = index
            return copy
        }
    }
}
