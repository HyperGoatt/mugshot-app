import SwiftUI

// MARK: - Presentation models

struct TastingLensFlavorLeaf: Identifiable, Hashable {
    let id: String
    let label: String
    var helper: String?

    init(id: String, label: String, helper: String? = nil) {
        self.id = id
        self.label = label
        self.helper = helper
    }
}

struct TastingLensPreferenceChoice: Identifiable, Equatable {
    let id: String
    let label: String
    let value: Int
    var helper: String?
}

struct TastingLensFlavorBranch: Identifiable, Hashable {
    let id: String
    let label: String
    let systemImage: String
    let tint: Color
    let children: [TastingLensFlavorLeaf]

    static func == (lhs: TastingLensFlavorBranch, rhs: TastingLensFlavorBranch) -> Bool {
        lhs.id == rhs.id
            && lhs.label == rhs.label
            && lhs.systemImage == rhs.systemImage
            && lhs.children == rhs.children
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(label)
        hasher.combine(systemImage)
        hasher.combine(children)
    }
}

enum TastingLensCriterionControl: Equatable {
    case freeText
    case intensity
    case duration
    case singleChoice([TastingLensFlavorLeaf])
    case multipleChoice([TastingLensFlavorLeaf])
    case preference([TastingLensPreferenceChoice])
    case confidence
    case quality
}

struct TastingLensCriterionItem: Identifiable, Equatable {
    let id: String
    let title: String
    let dimension: String
    let prompt: String
    let helper: String
    let whyItAppeared: String
    let control: TastingLensCriterionControl
    let scaleAnchors: [TastingLensScaleAnchorItem]
    let supportsNotPresent: Bool
    let supportsNotRelevant: Bool
    let showsInlineConfidence: Bool

    init(
        id: String,
        title: String,
        dimension: String,
        prompt: String,
        helper: String,
        whyItAppeared: String,
        control: TastingLensCriterionControl,
        scaleAnchors: [TastingLensScaleAnchorItem] = [],
        supportsNotPresent: Bool = true,
        supportsNotRelevant: Bool = true,
        showsInlineConfidence: Bool = false
    ) {
        self.id = id
        self.title = title
        self.dimension = dimension
        self.prompt = prompt
        self.helper = helper
        self.whyItAppeared = whyItAppeared
        self.control = control
        self.scaleAnchors = scaleAnchors
        self.supportsNotPresent = supportsNotPresent
        self.supportsNotRelevant = supportsNotRelevant
        self.showsInlineConfidence = showsInlineConfidence
    }
}

struct TastingLensScaleAnchorItem: Identifiable, Equatable {
    let value: Int
    let label: String
    let anchor: String

    var id: Int { value }
}

enum TastingLensAnswerStatus: String, CaseIterable, Equatable {
    case unanswered
    case observed
    case notPresent
    case unsure
    case skipped
    case notRelevant

    var label: String {
        switch self {
        case .unanswered: return "Unanswered"
        case .observed: return "Observed"
        case .notPresent: return "Not present"
        case .unsure: return "Not sure yet"
        case .skipped: return "Skip"
        case .notRelevant: return "Not relevant"
        }
    }
}

enum TastingLensAnswerConfidence: String, CaseIterable, Identifiable, Equatable {
    case learning
    case maybe
    case sure

    var id: String { rawValue }

    var label: String {
        switch self {
        case .learning: return "I'm still learning"
        case .maybe: return "Maybe"
        case .sure: return "I'm sure"
        }
    }
}

struct TastingLensCriterionAnswer: Equatable {
    var status: TastingLensAnswerStatus = .unanswered
    var intensity: Int?
    var duration: SensoryDurationValue?
    var selectedIDs: Set<String> = []
    var preference: Int?
    var quality: Int?
    var confidence: TastingLensAnswerConfidence?
    var customText: String = ""

    var hasResponse: Bool {
        status != .unanswered
    }
}

struct TastingLensLearnedPatternItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let supportCount: Int
    let opportunityCount: Int
    let scope: String
    let confidence: Double

    var supportSummary: String {
        "\(supportCount) of \(opportunityCount) \(scope)"
    }
}

enum TastingLensContentState: Equatable {
    case ready
    case loading(message: String)
    case offline(message: String)
    case notice(message: String)
    case failed(title: String, message: String)

    var showsJourneyBanner: Bool {
        switch self {
        case .offline, .notice: return true
        case .ready, .loading, .failed: return false
        }
    }
}

// MARK: - Shared surfaces

struct TastingLensCard<Content: View>: View {
    var tint: Color = .foamWhite
    var padding: CGFloat = 18
    @ViewBuilder let content: Content

    init(
        tint: Color = .foamWhite,
        padding: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            }
    }
}

struct TastingLensSectionHeading: View {
    let eyebrow: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(Color.mugshotSage)

            Text(title)
                .font(.system(.largeTitle, design: .serif, weight: .regular))
                .foregroundStyle(Color.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct TastingLensStatusBanner: View {
    let state: TastingLensContentState
    var onRetry: (() -> Void)?

    var body: some View {
        switch state {
        case .ready:
            EmptyView()
        case .loading(let message):
            banner(
                icon: "arrow.triangle.2.circlepath",
                title: "Preparing your Lens",
                message: message,
                tint: .mugshotMint
            )
            .redacted(reason: .placeholder)
        case .offline(let message):
            banner(
                icon: "wifi.slash",
                title: "Working offline",
                message: message,
                tint: .sandBeige
            )
        case .notice(let message):
            banner(
                icon: "arrow.triangle.2.circlepath.circle.fill",
                title: "Your Lens was updated",
                message: message,
                tint: .mugshotMint
            )
        case .failed(let title, let message):
            VStack(alignment: .leading, spacing: 10) {
                banner(icon: "exclamationmark.triangle", title: title, message: message, tint: .sandBeige)
                if let onRetry {
                    Button("Try again", action: onRetry)
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("tastingLens2.retry")
                }
            }
        }
    }

    private func banner(icon: String, title: String, message: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.mugshotSage)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.52), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.espressoBrown)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct TastingLensSelectionChip: View {
    let label: String
    var systemImage: String?
    var isSelected = false
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                }
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isSelected ? Color.foamWhite : Color.espressoBrown)
            .padding(.horizontal, 13)
            .frame(minHeight: 44)
            .background(isSelected ? Color.mugshotSage : Color.foamWhite)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        isSelected ? Color.espressoBrown.opacity(0.72) : Color.mugshotLine,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

struct TastingLensFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0

        for subview in subviews {
            let size = measuredSize(for: subview, maxWidth: maxWidth)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                measuredWidth = max(measuredWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalHeight += rowHeight
        measuredWidth = max(measuredWidth, rowWidth)
        return CGSize(width: min(maxWidth, measuredWidth), height: totalHeight)
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
            let size = measuredSize(for: subview, maxWidth: bounds.width)
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

    private func measuredSize(for subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let idealSize = subview.sizeThatFits(.unspecified)
        guard maxWidth.isFinite else { return idealSize }

        let constrainedWidth = min(idealSize.width, max(maxWidth, 0))
        return subview.sizeThatFits(
            ProposedViewSize(width: constrainedWidth, height: nil)
        )
    }
}

// MARK: - Adaptive flavor web

struct TastingLensFlavorExplorer: View {
    enum Presentation: String, CaseIterable, Identifiable {
        case map
        case list

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var systemImage: String { self == .map ? "circle.hexagongrid" : "list.bullet" }
    }

    let branches: [TastingLensFlavorBranch]
    @Binding var selectedLeafIDs: Set<String>
    @Binding var customFlavor: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var expandedBranchID: String?
    @State private var presentation: Presentation = .map

    private var usesList: Bool {
        presentation == .list || dynamicTypeSize >= .xLarge
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text("Broad first. Specific when it helps.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                Spacer(minLength: 8)
                Picker("Flavor explorer layout", selection: $presentation) {
                    ForEach(Presentation.allCases) { option in
                        Label(option.label, systemImage: option.systemImage)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(.mugshotSage)
                .accessibilityIdentifier("tastingLens2.flavor.presentation")
            }

            if usesList {
                accessibleList
            } else {
                flavorMap
            }

            if !usesList, let branch = expandedBranch {
                childChoices(for: branch)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Something else")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.espressoBrown)
                TextField("Use your own words", text: $customFlavor, axis: .vertical)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.sentences)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.foamWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.mugshotLine, lineWidth: 1)
                    }
                    .accessibilityIdentifier("tastingLens2.flavor.custom")
            }
        }
        .animation(reduceMotion ? nil : DesignSystem.Motion.base, value: expandedBranchID)
        .accessibilityElement(children: .contain)
    }

    private var expandedBranch: TastingLensFlavorBranch? {
        guard let expandedBranchID else { return nil }
        return branches.first(where: { $0.id == expandedBranchID })
    }

    private var flavorMap: some View {
        GeometryReader { proxy in
            let mapSize = min(proxy.size.width, 330)
            let center = CGPoint(x: proxy.size.width / 2, y: mapSize / 2)
            let radius = max(104, min(mapSize * 0.36, 124))

            ZStack {
                TastingLensWebConnections(
                    count: branches.count,
                    center: center,
                    radius: radius,
                    selectedIndex: expandedBranchID.flatMap { id in branches.firstIndex(where: { $0.id == id }) }
                )
                .accessibilityHidden(true)

                Circle()
                    .fill(Color.foamWhite)
                    .frame(width: 82, height: 82)
                    .overlay {
                        VStack(spacing: 3) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.mugshotSage)
                            Text(selectedLeafIDs.isEmpty ? "This sip" : "\(selectedLeafIDs.count) found")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.espressoBrown)
                        }
                    }
                    .overlay(Circle().stroke(Color.mugshotLine, lineWidth: 1))
                    .position(center)
                    .accessibilityHidden(true)

                ForEach(Array(branches.enumerated()), id: \.element.id) { index, branch in
                    let angle = -Double.pi / 2 + (Double(index) / Double(max(branches.count, 1))) * Double.pi * 2
                    let point = CGPoint(
                        x: center.x + CGFloat(cos(angle)) * radius,
                        y: center.y + CGFloat(sin(angle)) * radius
                    )

                    flavorNode(branch, index: index)
                        .position(point)
                }
            }
            .frame(width: proxy.size.width, height: mapSize)
        }
        .frame(height: 330)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Flavor map")
        .accessibilityHint("Choose a broad family, then choose any specific impressions that fit.")
    }

    private func flavorNode(_ branch: TastingLensFlavorBranch, index: Int) -> some View {
        let isExpanded = expandedBranchID == branch.id
        let selectedCount = branch.children.filter { selectedLeafIDs.contains($0.id) }.count

        return Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.12)) {
                expandedBranchID = isExpanded ? nil : branch.id
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: selectedCount > 0 ? "checkmark" : branch.systemImage)
                    .font(.system(size: 12, weight: .black))
                    .accessibilityHidden(true)
                Text(branch.label)
                    .font(.caption2.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(isExpanded || selectedCount > 0 ? Color.foamWhite : Color.espressoBrown)
            .frame(width: 76, height: 62)
            .background(
                isExpanded || selectedCount > 0
                    ? branch.tint
                    : branch.tint.opacity(0.18),
                in: RoundedRectangle(cornerRadius: 23, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(
                        isExpanded ? Color.espressoBrown.opacity(0.76) : branch.tint.opacity(0.7),
                        lineWidth: isExpanded ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(branch.label)
        .accessibilityValue(selectedCount == 0 ? "No details selected" : "\(selectedCount) details selected")
        .accessibilityHint(isExpanded ? "Collapses this family" : "Shows specific impressions")
        .accessibilityAddTraits(isExpanded ? .isSelected : [])
        .accessibilityIdentifier("tastingLens2.flavor.branch.\(branch.id)")
    }

    private var accessibleList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(branches) { branch in
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedBranchID == branch.id },
                    set: { expandedBranchID = $0 ? branch.id : nil }
                )) {
                    childChoices(for: branch)
                        .padding(.top, 10)
                } label: {
                    Label(branch.label, systemImage: branch.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.espressoBrown)
                        .frame(minHeight: 44)
                }
                .tint(.mugshotSage)
                .padding(.horizontal, 14)
                .background(Color.foamWhite)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.mugshotLine, lineWidth: 1)
                }
            }
        }
        .accessibilityIdentifier("tastingLens2.flavor.list")
    }

    private func childChoices(for branch: TastingLensFlavorBranch) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text(branch.label)
                    .font(.headline)
                    .foregroundStyle(Color.espressoBrown)
                Spacer()
                Text("Choose any that fit")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.tertiaryText)
            }

            TastingLensFlowLayout(spacing: 8) {
                ForEach(branch.children) { leaf in
                    TastingLensSelectionChip(
                        label: leaf.label,
                        isSelected: selectedLeafIDs.contains(leaf.id)
                    ) {
                        if selectedLeafIDs.contains(leaf.id) {
                            selectedLeafIDs.remove(leaf.id)
                        } else {
                            selectedLeafIDs.insert(leaf.id)
                        }
                    }
                    .accessibilityHint(leaf.helper ?? "A possible impression, not a required answer")
                    .accessibilityIdentifier("tastingLens2.flavor.leaf.\(leaf.id)")
                }
            }
        }
        .padding(14)
        .background(branch.tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(branch.tint.opacity(0.5), lineWidth: 1)
        }
    }
}

private struct TastingLensWebConnections: View {
    let count: Int
    let center: CGPoint
    let radius: CGFloat
    let selectedIndex: Int?

    var body: some View {
        Canvas { context, size in
            for index in 0..<count {
                let angle = -Double.pi / 2 + (Double(index) / Double(max(count, 1))) * Double.pi * 2
                let point = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * radius,
                    y: center.y + CGFloat(sin(angle)) * radius
                )
                var path = Path()
                path.move(to: center)
                let bend = CGPoint(
                    x: (center.x + point.x) / 2 + CGFloat(sin(angle)) * 9,
                    y: (center.y + point.y) / 2 - CGFloat(cos(angle)) * 9
                )
                path.addQuadCurve(to: point, control: bend)
                context.stroke(
                    path,
                    with: .color(
                        selectedIndex == index
                            ? Color.mugshotSage.opacity(0.75)
                            : Color.mugshotLine.opacity(0.9)
                    ),
                    style: StrokeStyle(lineWidth: selectedIndex == index ? 2 : 1, dash: [4, 5])
                )
            }

            for ring in 1...3 {
                let ringRadius = radius * CGFloat(ring) / 3
                let rect = CGRect(
                    x: center.x - ringRadius,
                    y: center.y - ringRadius,
                    width: ringRadius * 2,
                    height: ringRadius * 2
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(Color.mugshotSage.opacity(0.08)),
                    lineWidth: 1
                )
            }
        }
    }
}

// MARK: - Typed response controls

struct TastingLensCriterionControlView: View {
    let criterion: TastingLensCriterionItem
    @Binding var answer: TastingLensCriterionAnswer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            mainControl

            if answer.status == .observed,
               criterion.showsInlineConfidence,
               criterion.control != .confidence {
                confidenceControl
                    .transition(.opacity)
            }

            Divider()

            explicitStateActions
        }
        .animation(reduceMotion ? nil : DesignSystem.Motion.base, value: answer.status)
    }

    @ViewBuilder
    private var mainControl: some View {
        switch criterion.control {
        case .freeText:
            freeTextControl
        case .intensity:
            intensityControl
        case .duration:
            durationControl
        case .singleChoice(let choices):
            choiceControl(choices, allowsMultiple: false)
        case .multipleChoice(let choices):
            choiceControl(choices, allowsMultiple: true)
        case .preference(let choices):
            preferenceControl(choices)
        case .confidence:
            confidenceControl
        case .quality:
            numberedControl(
                options: [
                    (1, "Didn't work for the style"),
                    (2, "Partly worked"),
                    (3, "Mostly worked"),
                    (4, "Worked well"),
                    (5, "Worked beautifully")
                ],
                selection: $answer.quality,
                accessibilityPrefix: "Personal style impression"
            )
        }
    }

    private var freeTextControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Use the words that feel natural")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.espressoBrown)
            TextField(
                "Type what you notice",
                text: Binding(
                    get: { answer.customText },
                    set: { value in
                        answer.customText = value
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            answer.status = .observed
                        } else if answer.status == .observed {
                            answer.status = .unanswered
                        }
                    }
                ),
                axis: .vertical
            )
            .lineLimit(2...6)
            .textInputAutocapitalization(.sentences)
            .padding(13)
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            }
            .accessibilityIdentifier("tastingLens2.criterion.freeText")
        }
    }

    private var intensityControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How strong is it?")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.espressoBrown)

            ForEach(intensityAnchors) { scaleAnchor in
                Button {
                    answer.status = .observed
                    answer.intensity = scaleAnchor.value
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(answer.intensity == scaleAnchor.value ? Color.espressoBrown : Color.mugshotLine, lineWidth: answer.intensity == scaleAnchor.value ? 2 : 1)
                                .frame(width: 24, height: 24)
                            if answer.intensity == scaleAnchor.value {
                                Circle()
                                    .fill(Color.mugshotSage)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(scaleAnchor.label)
                                .font(.subheadline.weight(.bold))
                            Text(scaleAnchor.anchor)
                                .font(.caption)
                                .foregroundStyle(answer.intensity == scaleAnchor.value ? Color.foamWhite.opacity(0.82) : Color.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(answer.intensity == scaleAnchor.value ? Color.foamWhite : Color.espressoBrown)
                    .padding(13)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .background(answer.intensity == scaleAnchor.value ? Color.mugshotSage : Color.foamWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(answer.intensity == scaleAnchor.value ? Color.espressoBrown.opacity(0.7) : Color.mugshotLine, lineWidth: answer.intensity == scaleAnchor.value ? 2 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(answer.intensity == scaleAnchor.value ? .isSelected : [])
                .accessibilityLabel("\(scaleAnchor.label). \(scaleAnchor.anchor)")
                .accessibilityIdentifier("tastingLens2.criterion.intensity.\(scaleAnchor.value)")
            }

            Label("High intensity is not automatically better.", systemImage: "equal.circle")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var intensityAnchors: [TastingLensScaleAnchorItem] {
        if !criterion.scaleAnchors.isEmpty { return criterion.scaleAnchors }
        return [
            TastingLensScaleAnchorItem(value: 1, label: "Low", anchor: "Subtle; I notice it when I look for it."),
            TastingLensScaleAnchorItem(value: 2, label: "Medium", anchor: "Clear; it shares the sip with other sensations."),
            TastingLensScaleAnchorItem(value: 3, label: "High", anchor: "It leads the sip or lingers.")
        ]
    }

    private var durationControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How long does it stay?")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.espressoBrown)

            ForEach(criterion.scaleAnchors) { scaleAnchor in
                let duration = SensoryDurationValue(rawValue: scaleAnchor.value)
                Button {
                    answer.status = .observed
                    answer.duration = duration
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: answer.duration == duration ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(answer.duration == duration ? Color.mugshotSage : Color.tertiaryText)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scaleAnchor.label)
                                .font(.subheadline.weight(.bold))
                            Text(scaleAnchor.anchor)
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color.espressoBrown)
                    .padding(13)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .background(Color.foamWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(answer.duration == duration ? Color.mugshotSage : Color.mugshotLine, lineWidth: answer.duration == duration ? 2 : 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(duration == nil)
                .accessibilityAddTraits(answer.duration == duration ? .isSelected : [])
                .accessibilityLabel("\(scaleAnchor.label). \(scaleAnchor.anchor)")
                .accessibilityIdentifier("tastingLens2.criterion.duration.\(scaleAnchor.value)")
            }

            Label("Longer is not automatically better.", systemImage: "equal.circle")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
    }

    private func choiceControl(_ choices: [TastingLensFlavorLeaf], allowsMultiple: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(allowsMultiple ? "Choose any that fit" : "Choose the closest fit")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.espressoBrown)

            TastingLensFlowLayout(spacing: 8) {
                ForEach(choices) { choice in
                    TastingLensSelectionChip(
                        label: choice.label,
                        isSelected: answer.selectedIDs.contains(choice.id)
                    ) {
                        answer.status = .observed
                        if allowsMultiple {
                            if answer.selectedIDs.contains(choice.id) {
                                answer.selectedIDs.remove(choice.id)
                            } else {
                                answer.selectedIDs.insert(choice.id)
                            }
                            if answer.selectedIDs.isEmpty { answer.status = .unanswered }
                        } else {
                            answer.selectedIDs = [choice.id]
                        }
                    }
                    .accessibilityHint(choice.helper ?? "An observation, not a quality score")
                    .accessibilityIdentifier("tastingLens2.criterion.choice.\(choice.id)")
                }
            }
        }
    }

    private func numberedControl(
        options: [(Int, String)],
        selection: Binding<Int?>,
        accessibilityPrefix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options, id: \.0) { value, label in
                Button {
                    selection.wrappedValue = value
                    answer.status = .observed
                } label: {
                    HStack {
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if selection.wrappedValue == value {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.mugshotSage)
                        }
                    }
                    .foregroundStyle(Color.espressoBrown)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Color.foamWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selection.wrappedValue == value ? Color.mugshotSage : Color.mugshotLine, lineWidth: selection.wrappedValue == value ? 2 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(accessibilityPrefix): \(label)")
                .accessibilityAddTraits(selection.wrappedValue == value ? .isSelected : [])
            }
        }
    }

    private func preferenceControl(_ choices: [TastingLensPreferenceChoice]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(choices) { choice in
                Button {
                    answer.preference = choice.value
                    answer.selectedIDs = [choice.id]
                    answer.status = .observed
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(choice.label)
                                .font(.subheadline.weight(.semibold))
                            if let helper = choice.helper, !helper.isEmpty {
                                Text(helper)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 8)
                        if answer.preference == choice.value {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.mugshotSage)
                                .accessibilityHidden(true)
                        }
                    }
                    .foregroundStyle(Color.espressoBrown)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .background(Color.foamWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                answer.preference == choice.value ? Color.mugshotSage : Color.mugshotLine,
                                lineWidth: answer.preference == choice.value ? 2 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Preference: \(choice.label)")
                .accessibilityAddTraits(answer.preference == choice.value ? .isSelected : [])
            }
        }
    }

    private var confidenceControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How sure are you?")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.espressoBrown)
            Text("This changes how cautiously Mugshot phrases patterns. It never grades your palate.")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)

            TastingLensFlowLayout(spacing: 8) {
                ForEach(TastingLensAnswerConfidence.allCases) { confidence in
                    TastingLensSelectionChip(
                        label: confidence.label,
                        isSelected: answer.confidence == confidence
                    ) {
                        answer.confidence = confidence
                        if criterion.control == .confidence { answer.status = .observed }
                    }
                    .accessibilityIdentifier("tastingLens2.criterion.confidence.\(confidence.rawValue)")
                }
            }
        }
    }

    private var explicitStateActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Another answer is valid")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.espressoBrown)

            TastingLensFlowLayout(spacing: 8) {
                if criterion.supportsNotPresent {
                    stateButton(.notPresent, icon: "circle.slash")
                }
                stateButton(.unsure, icon: "questionmark.circle")
                stateButton(.skipped, icon: "forward")
                if criterion.supportsNotRelevant {
                    stateButton(.notRelevant, icon: "minus.circle")
                }
            }

            Text("Not sure, Skip, and Not relevant are never stored as zero or used against your rating.")
                .font(.caption2)
                .foregroundStyle(Color.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stateButton(_ status: TastingLensAnswerStatus, icon: String) -> some View {
        TastingLensSelectionChip(
            label: status.label,
            systemImage: icon,
            isSelected: answer.status == status
        ) {
            if answer.status == status {
                answer = TastingLensCriterionAnswer()
            } else {
                answer = TastingLensCriterionAnswer(status: status)
            }
        }
        .accessibilityIdentifier("tastingLens2.criterion.state.\(status.rawValue)")
    }
}

// MARK: - Enjoyment

struct TastingLensEnjoymentRating: View {
    @Binding var value: Double
    @AppStorage("MugshotSettings.haptics.v1") private var ratingHaptics = true

    static let anchors = PersonalEnjoymentRating.anchors

    var currentAnchor: String {
        Self.anchors.first(where: { $0.0 == value })?.1 ?? "Choose a personal rating"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    GeometryReader { proxy in
                        Image(systemName: symbol(for: index))
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundStyle(value >= Double(index) - 0.5 ? Color.mugshotSage : Color.espressoBrown.opacity(0.16))
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
            .frame(height: 46)
            .sensoryFeedback(.selection, trigger: value) { _, _ in ratingHaptics }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Personal enjoyment")
            .accessibilityValue(value > 0 ? "\(value.formatted()) out of 5. \(currentAnchor)" : "Not rated")
            .accessibilityHint("Swipe up or down to change by half a star")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: value = value <= 0 ? 1 : min(5, value + 0.5)
                case .decrement: value = max(1, value - 0.5)
                @unknown default: break
                }
            }
            .accessibilityIdentifier("tastingLens2.enjoyment.stars")

            HStack(alignment: .firstTextBaseline) {
                Text(currentAnchor)
                    .font(.headline)
                    .foregroundStyle(Color.espressoBrown)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Text(value > 0 ? value.formatted(.number.precision(.fractionLength(1))) : "—")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.mugshotSage)
            }

            DisclosureGroup("See every rating anchor") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Self.anchors, id: \.0) { anchor in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(anchor.0.formatted(.number.precision(.fractionLength(1))))
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(Color.mugshotSage)
                                .frame(width: 26, alignment: .trailing)
                            Text(anchor.1)
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .font(.caption.weight(.semibold))
            .tint(.mugshotSage)

            Label("This is how the drink was for you—not an objective quality score.", systemImage: "person.fill.checkmark")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
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
        return max(1, Double(clampedIndex) - (tapX < max(starWidth, 1) / 2 ? 0.5 : 0))
    }
}

// MARK: - Mugsy and learned evidence

struct TastingLensMugsyMoment: View {
    private struct Option: Identifiable {
        let id: String
        let label: String
    }

    let identity: SensoryDrinkIdentity
    @Binding var leadingSensation: String?
    @Binding var distinction: String?
    @State private var showsWhy = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var prompt: String {
        switch identity.family {
        case .matcha, .matchaLatte, .greenTea:
            return "Take a sip. Which tea sensation arrives first?"
        case .hojichaLeaf, .hojichaPowder, .hojichaLatte:
            return "Take a sip. What leads: roast, sweetness, green character, or texture?"
        case .blackTea, .whiteTea, .oolongTea, .herbalInfusion, .milkTea:
            return "Take a sip. Which tea sensation arrives first?"
        default:
            return "Take a sip. Which sensation arrives first?"
        }
    }

    private var sensations: [Option] {
        switch identity.family {
        case .matcha, .matchaLatte, .greenTea:
            return [
                Option(id: "mugsy.umami", label: "Umami or savory"),
                Option(id: "mugsy.fresh_green", label: "Fresh green"),
                Option(id: "mugsy.bitter", label: "Bitter"),
                Option(id: "mugsy.texture", label: "Texture"),
                Option(id: "mugsy.unsure", label: "Not sure yet")
            ]
        case .hojichaLeaf, .hojichaPowder, .hojichaLatte:
            return [
                Option(id: "mugsy.toasted", label: "Toasted"),
                Option(id: "mugsy.sweet", label: "Sweet"),
                Option(id: "mugsy.green", label: "Green"),
                Option(id: "mugsy.texture", label: "Texture"),
                Option(id: "mugsy.unsure", label: "Not sure yet")
            ]
        case .blackTea, .whiteTea, .oolongTea, .herbalInfusion, .milkTea:
            return [
                Option(id: "mugsy.aromatic", label: "Aromatic"),
                Option(id: "mugsy.sweet", label: "Sweet"),
                Option(id: "mugsy.brisk_dry", label: "Brisk or dry"),
                Option(id: "mugsy.body", label: "Body"),
                Option(id: "mugsy.unsure", label: "Not sure yet")
            ]
        default:
            return [
                Option(id: "mugsy.sweet", label: "Sweet"),
                Option(id: "mugsy.bright", label: "Bright"),
                Option(id: "mugsy.bitter", label: "Bitter"),
                Option(id: "mugsy.texture", label: "Texture"),
                Option(id: "mugsy.unsure", label: "Not sure yet")
            ]
        }
    }

    private var followUp: (prompt: String, options: [Option])? {
        switch leadingSensation {
        case "mugsy.bright":
            return ("Bright can feel juicy or sharp. Which is closer?", [
                Option(id: "mugsy.juicy", label: "Juicy"),
                Option(id: "mugsy.sharp", label: "Sharp"),
                Option(id: "mugsy.both", label: "Both"),
                Option(id: "mugsy.followup_unsure", label: "Not sure yet")
            ])
        case "mugsy.bitter":
            return ("Does the bitterness feel cocoa-like, roasty, or sharp?", [
                Option(id: "mugsy.cocoa_like", label: "Cocoa-like"),
                Option(id: "mugsy.roasty", label: "Roasty"),
                Option(id: "mugsy.sharp", label: "Sharp"),
                Option(id: "mugsy.followup_unsure", label: "Not sure yet")
            ])
        case "mugsy.sweet":
            return ("Is the sweetness from the base drink, an addition, or hard to separate?", [
                Option(id: "mugsy.base_drink", label: "Base drink"),
                Option(id: "mugsy.added", label: "Added ingredient"),
                Option(id: "mugsy.both", label: "Both"),
                Option(id: "mugsy.followup_unsure", label: "Not sure yet")
            ])
        case "mugsy.texture", "mugsy.body":
            return ("Is it more about smoothness, particles, dryness, or coating?", [
                Option(id: "mugsy.smoothness", label: "Smoothness"),
                Option(id: "mugsy.particles", label: "Particles"),
                Option(id: "mugsy.dryness", label: "Dryness"),
                Option(id: "mugsy.coating", label: "Coating")
            ])
        case "mugsy.toasted":
            return ("Is the roast closer to sweet toast, clear roast, or dark char?", [
                Option(id: "mugsy.roast_sweet", label: "Sweet toast"),
                Option(id: "mugsy.roasty", label: "Clear roast"),
                Option(id: "mugsy.roast_dark", label: "Dark char"),
                Option(id: "mugsy.followup_unsure", label: "Not sure yet")
            ])
        case "mugsy.umami":
            return ("Does it feel more brothy, green, or hard to separate?", [
                Option(id: "mugsy.marine", label: "Brothy or marine"),
                Option(id: "mugsy.fresh_green", label: "Fresh green"),
                Option(id: "mugsy.both", label: "Both"),
                Option(id: "mugsy.followup_unsure", label: "Not sure yet")
            ])
        case "mugsy.brisk_dry":
            return ("Does it feel lively, drying, or both?", [
                Option(id: "mugsy.bright", label: "Lively"),
                Option(id: "mugsy.dryness", label: "Drying"),
                Option(id: "mugsy.both", label: "Both"),
                Option(id: "mugsy.followup_unsure", label: "Not sure yet")
            ])
        default: return nil
        }
    }

    var body: some View {
        TastingLensCard(tint: Color.mugshotMint.opacity(0.14)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image("MugsyNoWishlist")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 82)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("A quick lens from Mugsy")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.mugshotSage)
                        Text(prompt)
                            .font(.system(.title3, design: .serif, weight: .regular))
                            .foregroundStyle(Color.espressoBrown)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                TastingLensFlowLayout(spacing: 8) {
                    ForEach(sensations) { sensation in
                        TastingLensSelectionChip(
                            label: sensation.label,
                            isSelected: leadingSensation == sensation.id
                        ) {
                            leadingSensation = sensation.id
                            distinction = nil
                        }
                        .accessibilityIdentifier("tastingLens2.mugsy.lead.\(sensation.id)")
                    }
                }

                if let followUp {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(followUp.prompt)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.espressoBrown)
                            .fixedSize(horizontal: false, vertical: true)
                        TastingLensFlowLayout(spacing: 8) {
                            ForEach(followUp.options) { option in
                                TastingLensSelectionChip(
                                    label: option.label,
                                    isSelected: distinction == option.id
                                ) { distinction = option.id }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.foamWhite.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button(showsWhy ? "Hide why this helps" : "Why this question?") {
                    showsWhy.toggle()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.mugshotSage)
                .buttonStyle(.plain)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityIdentifier("tastingLens2.mugsy.why")

                if showsWhy {
                    Text("Taste and mouthfeel can arrive together. Naming the first sensation helps Mugshot ask one useful follow-up without telling you what you should find.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? nil : DesignSystem.Motion.base, value: leadingSensation)
        .animation(reduceMotion ? nil : DesignSystem.Motion.base, value: showsWhy)
        .accessibilityElement(children: .contain)
    }
}

struct TastingLensLearnedPatternCard: View {
    let pattern: TastingLensLearnedPatternItem
    let onDismiss: () -> Void
    var onMarkLatestMistake: (() -> Void)?

    @State private var showsEvidence = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.mugshotSage)
                    .frame(width: 34, height: 34)
                    .background(Color.mugshotMint.opacity(0.28), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pattern.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.espressoBrown)
                    Text(pattern.detail)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Menu {
                    Button("Show the evidence") { showsEvidence = true }
                    if let onMarkLatestMistake {
                        Button("Latest selection was a mistake", role: .destructive, action: onMarkLatestMistake)
                    }
                    Button("This isn't useful", role: .destructive, action: onDismiss)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.espressoBrown)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Pattern options")
            }

            HStack(spacing: 8) {
                Label(pattern.supportSummary, systemImage: "checkmark.circle")
                Label("Personal pattern", systemImage: "person.crop.circle")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.mugshotSage)

            if showsEvidence {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Why Mugshot noticed this")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.espressoBrown)
                    Text("This appeared in \(pattern.supportCount) of \(pattern.opportunityCount) confirmed \(pattern.scope). Mugshot requires repeated, same-scope evidence and phrases the result as a possibility—not a rule about your palate.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let onMarkLatestMistake {
                        Button("My latest supporting selection was a mistake", role: .destructive, action: onMarkLatestMistake)
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.plain)
                            .frame(minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                            .accessibilityHint("Removes the latest supporting snapshot from this pattern without rewriting the saved sip")
                    }
                    Button("Hide evidence") { showsEvidence = false }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.mugshotSage)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .padding(12)
                .background(Color.sandBeige.opacity(0.46))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(15)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tastingLens2.pattern.\(pattern.id)")
    }
}
