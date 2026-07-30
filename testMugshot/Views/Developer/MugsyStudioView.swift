#if DEBUG
import SwiftUI

/// Approval surface for the canonical Mugsy model. This view is intentionally
/// isolated from product flows and contains no character animation timelines.
struct MugsyStudioView: View {
    @State private var expression: MugsyExpression = .neutral
    @State private var prop: MugsyProp = .none
    @State private var outfit: MugsyOutfit = .none
    @State private var liquidProgress = 0.0
    @State private var gaze = UnitPoint.center
    @State private var overlayOpacity = 0.0
    @State private var showsGrid = false
    @State private var showsAnchors = false
    @State private var showsContours = false

    private var configuration: MugsyModelConfiguration {
        MugsyModelConfiguration(
            expression: expression,
            prop: prop,
            outfit: outfit,
            pose: .neutral,
            gaze: gaze,
            liquid: .coffee(fillProgress: liquidProgress)
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                introduction

                MugsyStudioSection(
                    eyebrow: "PRIMARY MASTER",
                    title: "Canonical neutral model",
                    note: "The unobstructed MugsyNoWishlist asset is the proportion master. Glasses and white ceramic remain permanent."
                ) {
                    VStack(spacing: 18) {
                        MugsyInspectionStage(
                            configuration: configuration,
                            referenceOpacity: overlayOpacity,
                            showsGrid: showsGrid,
                            showsAnchors: showsAnchors,
                            renderMode: showsContours ? .contours : .standard
                        )
                        .frame(maxWidth: 430)
                        .frame(maxWidth: .infinity)

                        inspectionControls
                    }
                }

                MugsyExpressionSheet()
                MugsyWishlistCorrectionSheet()
                MugsyPropSheet()
                MugsyOutfitSheet()
                MugsyArmPoseSheet()
                MugsyInteractionSheet()
                MugsyLiquidSheet()
                MugsyScaleMatrix()
                MugsyBackgroundChecks()
                MugsyReferenceComparison()
                MugsyPaletteSheet()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color(red: 0.965, green: 0.956, blue: 0.925))
        .navigationTitle("Mugsy Studio")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODEL SHEET 01")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(MugsyStyleTokens.mintAccent.darker(by: 0.32))

            Text("Faithful normalization, not a redesign.")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.19, green: 0.14, blue: 0.11))

            Text("The approved canonical model now expands through controlled props, outfits, arm poses, coffee states, and product motion without changing Mugsy's identity.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var inspectionControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Picker("Expression", selection: $expression) {
                    ForEach(MugsyExpression.allCases) { expression in
                        Text(expression.title).tag(expression)
                    }
                }
                .pickerStyle(.menu)

                Picker("Prop", selection: $prop) {
                    ForEach(MugsyProp.allCases) { prop in
                        Text(prop.title).tag(prop)
                    }
                }
                .pickerStyle(.menu)

                Picker("Outfit", selection: $outfit) {
                    ForEach(MugsyOutfit.allCases) { outfit in
                        Text(outfit.title).tag(outfit)
                    }
                }
                .pickerStyle(.menu)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Master overlay")
                    Spacer()
                    Text(overlayOpacity, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 13, weight: .semibold))

                Slider(value: $overlayOpacity, in: 0...1)
                    .tint(MugsyStyleTokens.mintAccent.darker(by: 0.28))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Coffee in rim")
                    Spacer()
                    Text(liquidProgress, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 13, weight: .semibold))

                Slider(value: $liquidProgress, in: 0...1)
                    .tint(MugshotDrinkAppearance.coffee.liquidColor)
            }

            HStack(spacing: 18) {
                Toggle("Grid", isOn: $showsGrid)
                Toggle("Anchors", isOn: $showsAnchors)
                Toggle("Contours", isOn: $showsContours)
            }
            .font(.system(size: 13, weight: .medium))
            .toggleStyle(.switch)
            .tint(MugsyStyleTokens.mintAccent.darker(by: 0.24))

            MugsyGazeControl(gaze: $gaze)
        }
    }
}

private struct MugsyInspectionStage: View {
    let configuration: MugsyModelConfiguration
    let referenceOpacity: Double
    let showsGrid: Bool
    let showsAnchors: Bool
    let renderMode: MugsyRenderMode

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white)

                if showsGrid {
                    MugsyGridOverlay()
                        .padding(12)
                }

                MugsyModelView(configuration: configuration, renderMode: renderMode)
                    .padding(12)

                if referenceOpacity > 0.001 {
                    Image("MugsyNoWishlist")
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(1.35045)
                        .offset(
                            x: -41.25 * side / 500,
                            y: -55.35 * side / 500
                        )
                        .opacity(referenceOpacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                if showsAnchors {
                    MugsyAnchorOverlay()
                        .padding(12)
                }
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.07), radius: 16, y: 8)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct MugsyGridOverlay: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 500

            for coordinate in stride(from: 0, through: 500, by: 50) {
                var vertical = Path()
                vertical.move(to: CGPoint(x: CGFloat(coordinate) * scale, y: 0))
                vertical.addLine(to: CGPoint(x: CGFloat(coordinate) * scale, y: size.height))

                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 0, y: CGFloat(coordinate) * scale))
                horizontal.addLine(to: CGPoint(x: size.width, y: CGFloat(coordinate) * scale))

                let isMajor = coordinate.isMultiple(of: 100)
                let color = MugsyStyleTokens.mintAccent.opacity(isMajor ? 0.42 : 0.20)
                context.stroke(vertical, with: .color(color), lineWidth: isMajor ? 1 : 0.5)
                context.stroke(horizontal, with: .color(color), lineWidth: isMajor ? 1 : 0.5)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct MugsyAnchorOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 500

            ForEach(MugsyModelAnchor.allCases) { anchor in
                let point = MugsyReferenceGeometry.modelAnchor(anchor)

                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 12, height: 12)
                    Text(anchor.title)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.red)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.9), in: Capsule())
                        .offset(y: -14)
                }
                .position(x: point.x * scale, y: point.y * scale)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct MugsyGazeControl: View {
    @Binding var gaze: UnitPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Static gaze")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 10) {
                ForEach(GazePreset.allCases) { preset in
                    Button {
                        gaze = preset.point
                    } label: {
                        Image(systemName: preset.symbol)
                            .frame(width: 30, height: 26)
                            .background(
                                gaze == preset.point
                                    ? MugsyStyleTokens.mintAccent.opacity(0.64)
                                    : Color.black.opacity(0.05),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.title)
                }
            }
        }
    }

    private enum GazePreset: String, CaseIterable, Identifiable {
        case left
        case center
        case right
        case up

        var id: String { rawValue }
        var title: String { "Look \(rawValue)" }

        var point: UnitPoint {
            switch self {
            case .left: return UnitPoint(x: 0.18, y: 0.5)
            case .center: return .center
            case .right: return UnitPoint(x: 0.82, y: 0.5)
            case .up: return UnitPoint(x: 0.5, y: 0.18)
            }
        }

        var symbol: String {
            switch self {
            case .left: return "arrow.left"
            case .center: return "circle"
            case .right: return "arrow.right"
            case .up: return "arrow.up"
            }
        }
    }
}

private struct MugsyExpressionSheet: View {
    private let columns = [GridItem(.adaptive(minimum: 136), spacing: 12)]

    var body: some View {
        MugsyStudioSection(
            eyebrow: "FACIAL LANGUAGE",
            title: "Six-expression sheet",
            note: "Only brows, eyelids, pupils, gaze, and mouth change. Mugsy's anatomy and glasses do not."
        ) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MugsyExpression.allCases) { expression in
                    MugsySpecimenCard(title: expression.title) {
                        MugsyModelView(configuration: .init(expression: expression))
                            .frame(height: 144)
                    }
                }
            }
        }
    }
}

private struct MugsyWishlistCorrectionSheet: View {
    var body: some View {
        MugsyStudioSection(
            eyebrow: "IDENTITY CORRECTION",
            title: "Wishlist badge with crossed arms",
            note: "This is a bookmark-shaped Wishlist prop beneath Mugsy's crossed arms. It is a prop, never clothing or anatomy."
        ) {
            HStack(spacing: 12) {
                MugsySpecimenCard(title: "Canonical") {
                    MugsyModelView()
                        .frame(height: 170)
                }

                MugsySpecimenCard(title: "Wishlist") {
                    MugsyModelView(configuration: MugsyPlacement.savedWishlist.configuration)
                        .frame(height: 170)
                }
            }
        }
    }
}

private struct MugsyPropSheet: View {
    private let columns = [GridItem(.adaptive(minimum: 136), spacing: 12)]

    var body: some View {
        MugsyStudioSection(
            eyebrow: "CONTEXT OBJECTS",
            title: "Prop library",
            note: "Props attach to stable hands and remain subordinate to Mugsy's glasses, face, and ceramic silhouette."
        ) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MugsyProp.allCases) { prop in
                    MugsySpecimenCard(title: prop.title) {
                        MugsyModelView(configuration: .init(prop: prop))
                            .frame(height: 144)
                    }
                }
            }
        }
    }
}

private struct MugsyOutfitSheet: View {
    private let columns = [GridItem(.adaptive(minimum: 136), spacing: 12)]

    var body: some View {
        MugsyStudioSection(
            eyebrow: "WARDROBE",
            title: "Occasional outfit library",
            note: "Outfits are reserved for meaningful contexts. They never recolor the ceramic, cover the glasses, or redefine Mugsy's anatomy."
        ) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MugsyOutfit.allCases) { outfit in
                    MugsySpecimenCard(title: outfit.title) {
                        MugsyModelView(configuration: outfitConfiguration(outfit))
                            .frame(height: 144)
                    }
                }
            }
        }
    }

    private func outfitConfiguration(_ outfit: MugsyOutfit) -> MugsyModelConfiguration {
        switch outfit {
        case .none:
            return .init()
        case .builder:
            return MugsyPlacement.comingSoon.configuration
        case .cafeScout:
            return MugsyPlacement.discoveryEmpty.configuration
        case .cameraCompanion:
            return MugsyPlacement.camera.configuration
        case .cozyRitual:
            return MugsyPlacement.ritual.configuration
        }
    }
}

private struct MugsyArmPoseSheet: View {
    private let columns = [GridItem(.adaptive(minimum: 136), spacing: 12)]

    var body: some View {
        MugsyStudioSection(
            eyebrow: "ARTICULATION",
            title: "Arm-pose inspection",
            note: "Every pose uses the same shoulder origins and stable hand attachment region. The crossed pose is reserved for the Wishlist badge."
        ) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MugsyArmPose.allCases) { pose in
                    MugsySpecimenCard(title: pose.title) {
                        MugsyModelView(configuration: .init(armPose: pose))
                            .frame(height: 144)
                    }
                }
            }
        }
    }
}

private struct MugsyInteractionSheet: View {
    private let columns = [GridItem(.adaptive(minimum: 136), spacing: 12)]

    var body: some View {
        MugsyStudioSection(
            eyebrow: "PLAYFUL RESPONSE",
            title: "Touch and accomplishment motion",
            note: "Tap reactions are reserved for welcoming and empty-state moments. The looping dance belongs only to a real save or milestone."
        ) {
            LazyVGrid(columns: columns, spacing: 12) {
                MugsySpecimenCard(title: "Tap to wave") {
                    MugsyAnimatedView(
                        configuration: .init(expression: .tender),
                        tapBehavior: .wave
                    )
                    .frame(height: 150)
                }

                MugsySpecimenCard(title: "Tap for surprises") {
                    MugsyAnimatedView(
                        configuration: .init(expression: .curious),
                        tapBehavior: .playfulCycle
                    )
                    .frame(height: 150)
                }

                MugsySpecimenCard(title: "Saved dance") {
                    MugsyCelebrationLoopView(
                        configuration: .init(
                            expression: .delighted,
                            liquid: .coffee(fillProgress: 0.94, steamIntensity: 0.8)
                        )
                    )
                    .frame(height: 150)
                }
            }
        }
    }
}

private struct MugsyLiquidSheet: View {
    private let progressValues: [CGFloat] = [0.16, 0.42, 0.68, 1]

    var body: some View {
        MugsyStudioSection(
            eyebrow: "COFFEE STATE",
            title: "Pull-to-refresh fill sequence",
            note: "The selected feed pill pours coffee into Mugsy as the pull grows. Release removes the stream and starts steam—without status copy or a resting ghost."
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(progressValues, id: \.self) { progress in
                        MugsyRefreshStudioSpecimen(progress: progress, isRefreshing: false)
                    }

                    MugsyRefreshStudioSpecimen(progress: 1, isRefreshing: true)
                }
            }
        }
    }
}

private struct MugsyRefreshStudioSpecimen: View {
    let progress: CGFloat
    let isRefreshing: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == 0 ? Color.mugshotSage : Color.sandBeige)
                        .frame(width: 31, height: 12)
                }
            }
            .frame(height: 24)

            MugshotPullRefreshIndicator(progress: progress, isRefreshing: isRefreshing)
        }
        .frame(width: 156, height: 178, alignment: .top)
        .padding(.top, 10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRefreshing ? "Released and steaming" : "Coffee pour at \(Int((progress * 100).rounded())) percent")
    }
}

private struct MugsyScaleMatrix: View {
    private let sizes: [CGFloat] = [44, 72, 120, 200]

    var body: some View {
        MugsyStudioSection(
            eyebrow: "RECOGNITION",
            title: "44 / 72 / 120 / 200 points",
            note: "Contour floors protect Mugsy's silhouette, glasses, eyes, and feet at every approved size."
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 18) {
                    ForEach(sizes, id: \.self) { size in
                        VStack(spacing: 10) {
                            MugsyModelView()
                                .frame(width: size, height: size)
                                .frame(width: max(size, 72), height: 210, alignment: .bottom)

                            Text("\(Int(size)) pt")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

private struct MugsyBackgroundChecks: View {
    var body: some View {
        MugsyStudioSection(
            eyebrow: "SURFACE CHECK",
            title: "Light and dark backgrounds",
            note: "Mugsy remains white ceramic on every surface. Dark mode never recolors the character."
        ) {
            HStack(spacing: 12) {
                backgroundCard(title: "Light", color: Color.white, titleColor: .secondary)
                backgroundCard(
                    title: "Dark",
                    color: Color(red: 0.30, green: 0.25, blue: 0.22),
                    titleColor: Color.white.opacity(0.72)
                )
            }
        }
    }

    private func backgroundCard(title: String, color: Color, titleColor: Color) -> some View {
        VStack(spacing: 2) {
            MugsyModelView(configuration: .init(expression: .tender))
                .frame(height: 172)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(titleColor)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct MugsyReferenceComparison: View {
    private let references = [
        MugsyReferenceAsset(
            asset: "MugsyNoWishlist",
            title: "No wishlist",
            scale: 1.35045,
            designOffset: CGSize(width: -41.25, height: -55.35),
            configuration: MugsyPlacement.savedWishlist.configuration
        ),
        MugsyReferenceAsset(
            asset: "MugsyNoFavorites",
            title: "No favorites",
            scale: 0.824,
            designOffset: CGSize(width: -1.65, height: 6.18),
            configuration: MugsyPlacement.savedFavorites.configuration
        ),
        MugsyReferenceAsset(
            asset: "MugsyNoCafes",
            title: "No cafes",
            scale: 1.083,
            designOffset: CGSize(width: 4.33, height: 6.50),
            configuration: MugsyPlacement.savedCafes.configuration
        ),
        MugsyReferenceAsset(
            asset: "MugsyNoFriends",
            title: "No friends",
            scale: 1.356,
            designOffset: CGSize(width: 0, height: 19.66),
            configuration: MugsyPlacement.friendsEmpty.configuration
        ),
        MugsyReferenceAsset(
            asset: "MugsyComingSoon",
            title: "Coming soon",
            scale: 0.745,
            designOffset: .zero,
            configuration: MugsyPlacement.comingSoon.configuration
        )
    ]

    var body: some View {
        MugsyStudioSection(
            eyebrow: "LINEAGE",
            title: "Approved asset comparison",
            note: "The canonical model sits beside every existing Mugsy to check silhouette, personality, and identity continuity."
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(references) { reference in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 4) {
                                MugsyNormalizedReferenceImage(reference: reference)
                                    .frame(width: 142, height: 166)
                                    .accessibilityLabel("Existing \(reference.title) Mugsy")

                                MugsyModelView(configuration: reference.configuration)
                                    .frame(width: 142, height: 166)
                            }

                            HStack {
                                Text(reference.title)
                                Spacer()
                                Text("CANONICAL")
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(width: 320)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.black.opacity(0.07), lineWidth: 1)
                        }
                    }
                }
            }
        }
    }
}

private struct MugsyReferenceAsset: Identifiable {
    let asset: String
    let title: String
    let scale: CGFloat
    let designOffset: CGSize
    let configuration: MugsyModelConfiguration
    var id: String { asset }
}

private struct MugsyNormalizedReferenceImage: View {
    let reference: MugsyReferenceAsset

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            Image(reference.asset)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
                .scaleEffect(reference.scale)
                .offset(
                    x: reference.designOffset.width * side / 500,
                    y: reference.designOffset.height * side / 500
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct MugsyPaletteSheet: View {
    private let swatches = [
        Swatch(name: "Ink", hex: MugsyStyleTokens.inkHex, color: MugsyStyleTokens.ink),
        Swatch(name: "Ceramic", hex: MugsyStyleTokens.ceramicBaseHex, color: MugsyStyleTokens.ceramicBase),
        Swatch(name: "Highlight", hex: MugsyStyleTokens.ceramicHighlightHex, color: MugsyStyleTokens.ceramicHighlight),
        Swatch(name: "Shadow", hex: MugsyStyleTokens.ceramicShadowHex, color: MugsyStyleTokens.ceramicShadow),
        Swatch(name: "Blush", hex: MugsyStyleTokens.blushHex, color: MugsyStyleTokens.blush),
        Swatch(name: "Mint", hex: MugsyStyleTokens.mintAccentHex, color: MugsyStyleTokens.mintAccent)
    ]

    var body: some View {
        MugsyStudioSection(
            eyebrow: "LOCKED TOKENS",
            title: "Canonical palette",
            note: "These values come from the approved artwork and are invariant across expressions, props, outfits, and surfaces."
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 10)], spacing: 10) {
                ForEach(swatches) { swatch in
                    HStack(spacing: 9) {
                        Circle()
                            .fill(swatch.color)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(Color.black.opacity(0.14), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(swatch.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text("#\(swatch.hex)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(9)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private struct Swatch: Identifiable {
        let name: String
        let hex: String
        let color: Color
        var id: String { name }
    }
}

private struct MugsySpecimenCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 2) {
            content
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        }
    }
}

private struct MugsyStudioSection<Content: View>: View {
    let eyebrow: String
    let title: String
    let note: String
    @ViewBuilder let content: Content

    init(
        eyebrow: String,
        title: String,
        note: String,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(MugsyStyleTokens.mintAccent.darker(by: 0.32))
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.19, green: 0.14, blue: 0.11))
                Text(note)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
    }
}

private extension Color {
    func darker(by amount: Double) -> Color {
        Color(
            red: max(0, 0.72 * (1 - amount)),
            green: max(0, 0.88 * (1 - amount)),
            blue: max(0, 0.75 * (1 - amount))
        )
    }
}

#Preview("Mugsy Studio") {
    NavigationStack {
        MugsyStudioView()
    }
}

#Preview("Expression Sheet") {
    ScrollView {
        MugsyExpressionSheet()
            .padding(20)
    }
    .background(Color(red: 0.965, green: 0.956, blue: 0.925))
}

#Preview("Scale Matrix") {
    ScrollView {
        MugsyScaleMatrix()
            .padding(20)
    }
    .background(Color(red: 0.965, green: 0.956, blue: 0.925))
}

#Preview("Reference Sheet") {
    ScrollView {
        VStack(spacing: 24) {
            MugsyWishlistCorrectionSheet()
            MugsyPropSheet()
            MugsyOutfitSheet()
            MugsyLiquidSheet()
            MugsyBackgroundChecks()
            MugsyReferenceComparison()
        }
        .padding(20)
    }
    .background(Color(red: 0.965, green: 0.956, blue: 0.925))
}
#endif
