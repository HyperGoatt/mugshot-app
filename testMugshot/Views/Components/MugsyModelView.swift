import SwiftUI

/// Static, layered, code-native Mugsy model.
/// Product motion wraps this value-state renderer; the model itself has no timeline.
struct MugsyModelView: View {
    var configuration = MugsyModelConfiguration()
    var renderMode: MugsyRenderMode = .standard

    var body: some View {
        GeometryReader { proxy in
            let side = max(1, min(proxy.size.width, proxy.size.height))
            let scale = side / MugsyReferenceGeometry.designCanvas.width
            let rendered = MugsyRenderMetrics(renderSize: side)
            let metrics = MugsyDrawingMetrics(
                primary: rendered.primaryStroke / scale,
                detail: rendered.detailStroke / scale,
                micro: rendered.microStroke / scale
            )

            ZStack {
                MugsyLegLayer(configuration: configuration, metrics: metrics)

                ZStack {
                    MugsyHandleLayer(metrics: metrics, renderMode: renderMode)
                    MugsyCeramicLayer(
                        configuration: configuration,
                        metrics: metrics,
                        renderMode: renderMode
                    )
                    MugsyOutfitLayer(configuration: configuration, metrics: metrics)
                    MugsyPropLayer(configuration: configuration, metrics: metrics)
                    MugsyArmLayer(configuration: configuration, metrics: metrics)
                    MugsyFaceLayer(configuration: configuration, metrics: metrics, renderMode: renderMode)
                }
                .offset(
                    x: configuration.legArticulation.bodyOffset.width,
                    y: configuration.legArticulation.bodyOffset.height
                )
            }
            .rotationEffect(configuration.pose.rotation, anchor: .bottom)
            .offset(x: configuration.pose.horizontalOffset)
            .frame(width: 500, height: 500)
            .scaleEffect(scale)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(configuration.accessibilityLabel)
    }
}

private struct MugsyDrawingMetrics {
    let primary: CGFloat
    let detail: CGFloat
    let micro: CGFloat
}

private struct MugsyHandleLayer: View {
    let metrics: MugsyDrawingMetrics
    let renderMode: MugsyRenderMode

    var body: some View {
        ZStack {
            MugsyHandleShape()
                .fill(MugsyStyleTokens.ceramicBase, style: FillStyle(eoFill: true))

            if renderMode == .standard {
                MugsyHandleShadeShape()
                    .fill(MugsyStyleTokens.ceramicShadow.opacity(0.46))
            }

            MugsyHandleShape()
                .stroke(
                    MugsyStyleTokens.ink,
                    style: StrokeStyle(lineWidth: metrics.primary, lineCap: .round, lineJoin: .round)
                )
        }
        .frame(width: 500, height: 500)
    }
}

private struct MugsyLegLayer: View {
    let configuration: MugsyModelConfiguration
    let metrics: MugsyDrawingMetrics

    var body: some View {
        ZStack {
            MugsyLegsShape(articulation: configuration.legArticulation)
                .stroke(
                    MugsyStyleTokens.ink,
                    style: StrokeStyle(lineWidth: metrics.primary, lineCap: .round, lineJoin: .round)
                )

            MugsyFootShape(side: .left)
                .fill(MugsyStyleTokens.ink)
            MugsyFootShape(side: .right)
                .fill(MugsyStyleTokens.ink)
        }
        .frame(width: 500, height: 500)
    }
}

private struct MugsyCeramicLayer: View {
    let configuration: MugsyModelConfiguration
    let metrics: MugsyDrawingMetrics
    let renderMode: MugsyRenderMode

    var body: some View {
        ZStack {
            MugsyBodyShape()
                .fill(MugsyStyleTokens.ceramicBase)

            if renderMode == .standard {
                MugsyBodyShape()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: MugsyStyleTokens.ceramicHighlight.opacity(0.92), location: 0),
                                .init(color: MugsyStyleTokens.ceramicBase.opacity(0.22), location: 0.58),
                                .init(color: MugsyStyleTokens.ceramicShadow.opacity(0.64), location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                MugsyCeramicHighlightShape()
                    .fill(MugsyStyleTokens.ceramicHighlight.opacity(0.72))

                MugsyCeramicShadeShape()
                    .fill(MugsyStyleTokens.ceramicShadow.opacity(0.30))
            }

            MugsyBodyShape()
                .stroke(
                    MugsyStyleTokens.ink,
                    style: StrokeStyle(lineWidth: metrics.primary, lineCap: .round, lineJoin: .round)
                )

            MugsyRimShape()
                .fill(MugsyStyleTokens.ceramicBase)
                .overlay {
                    MugsyRimShape()
                        .stroke(
                            MugsyStyleTokens.ink,
                            style: StrokeStyle(lineWidth: metrics.primary, lineCap: .round, lineJoin: .round)
                        )
                }

            MugsyRimInteriorShape()
                .fill(MugsyStyleTokens.ceramicShadow.opacity(renderMode == .contours ? 0.20 : 0.48))

            if configuration.liquid.fillProgress > 0.001, renderMode == .standard {
                MugsyLiquidSurfaceShape(fillProgress: configuration.liquid.fillProgress)
                    .fill(configuration.liquid.appearance.liquidColor)
                    .clipShape(MugsyRimInteriorShape())
            }

            MugsyRimInteriorShape()
                .fill(Color.clear)
                .overlay {
                    MugsyRimInteriorShape()
                        .stroke(MugsyStyleTokens.ink.opacity(0.64), lineWidth: metrics.detail)
                }

            if configuration.liquid.steamIntensity > 0.001, renderMode == .standard {
                MugsyStaticSteamShape(intensity: configuration.liquid.steamIntensity)
                    .stroke(
                        MugsyStyleTokens.ceramicShadow.opacity(0.76),
                        style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round)
                    )
            }
        }
        .frame(width: 500, height: 500)
    }
}

private struct MugsyArmLayer: View {
    let configuration: MugsyModelConfiguration
    let metrics: MugsyDrawingMetrics

    var body: some View {
        ZStack {
            MugsyArmsShape(pose: configuration.armPose)
                .stroke(
                    MugsyStyleTokens.ink,
                    style: StrokeStyle(lineWidth: metrics.primary, lineCap: .round, lineJoin: .round)
                )

            MugsyHandShape(
                side: .left,
                pose: configuration.armPose
            )
            .fill(MugsyStyleTokens.ink)

            MugsyHandShape(
                side: .right,
                pose: configuration.armPose
            )
            .fill(MugsyStyleTokens.ink)
        }
        .frame(width: 500, height: 500)
    }
}

private struct MugsyFaceLayer: View {
    let configuration: MugsyModelConfiguration
    let metrics: MugsyDrawingMetrics
    let renderMode: MugsyRenderMode

    private var gazeOffset: CGSize {
        CGSize(
            width: (configuration.gaze.x - 0.5) * 18,
            height: (configuration.gaze.y - 0.5) * 13
        )
    }

    var body: some View {
        ZStack {
            MugsyCheeksShape()
                .fill(MugsyStyleTokens.blush.opacity(configuration.expression == .focused ? 0.46 : 0.72))

            eye(center: CGPoint(x: 126, y: 174), mirror: false)
            eye(center: CGPoint(x: 222, y: 175), mirror: true)

            MugsyEyebrowsShape(expression: configuration.expression)
                .stroke(
                    MugsyStyleTokens.ink,
                    style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round, lineJoin: .round)
                )

            if configuration.expression == .delighted {
                MugsyOpenMouthShape()
                    .fill(MugsyStyleTokens.ink)
                MugsyTongueShape()
                    .fill(MugsyStyleTokens.blush)
            } else if configuration.expression == .curious {
                MugsyCuriousMouthShape()
                    .fill(MugsyStyleTokens.ceramicHighlight)
                    .overlay {
                        MugsyCuriousMouthShape()
                            .stroke(MugsyStyleTokens.ink, lineWidth: metrics.detail)
                    }
            } else {
                MugsyMouthShape(expression: configuration.expression)
                    .stroke(
                        MugsyStyleTokens.ink,
                        style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round, lineJoin: .round)
                    )
            }

            MugsyGlassesShape()
                .stroke(
                    MugsyStyleTokens.ink,
                    style: StrokeStyle(lineWidth: metrics.primary * 1.12, lineCap: .round, lineJoin: .round)
                )

            if renderMode == .standard {
                MugsyLensHighlightsShape()
                    .stroke(
                        MugsyStyleTokens.ceramicHighlight.opacity(0.92),
                        style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round)
                    )
            }
        }
        .frame(width: 500, height: 500)
    }

    private func eye(center: CGPoint, mirror: Bool) -> some View {
        let layout = MugsyEyeLayout(expression: configuration.expression)
        let x = center.x
        let y = center.y + layout.verticalOffset

        return ZStack {
            MugsyEyeWhiteShape()
                .fill(MugsyStyleTokens.ceramicHighlight)
                .overlay {
                    MugsyEyeOutlineShape()
                        .stroke(
                            MugsyStyleTokens.ink,
                            style: StrokeStyle(
                                lineWidth: metrics.detail * 0.82,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }
                .frame(width: layout.eyeWidth, height: layout.eyeHeight)

            ZStack {
                MugsyPupilShape()
                    .fill(MugsyStyleTokens.ink)
                    .frame(width: layout.pupilWidth, height: layout.pupilHeight)

                MugsyEyeHighlightShape(mirror: mirror)
                    .fill(MugsyStyleTokens.ceramicHighlight)
                    .frame(width: layout.pupilWidth, height: layout.pupilHeight)
            }
            .offset(
                x: gazeOffset.width + (mirror ? -1 : 1),
                y: gazeOffset.height + 1
            )

            if layout.showsLid {
                MugsyEyelidShape()
                    .stroke(
                        MugsyStyleTokens.ink,
                        style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round)
                    )
                    .frame(width: layout.eyeWidth + 5, height: layout.eyeHeight)
                    .offset(y: -layout.eyeHeight * 0.16)
            }
        }
        .position(x: x, y: y)
    }
}

private struct MugsyPropLayer: View {
    let configuration: MugsyModelConfiguration
    let metrics: MugsyDrawingMetrics

    @ViewBuilder
    var body: some View {
        ZStack {
            switch configuration.prop {
            case .none:
                EmptyView()
            case .wishlistBadge:
                MugsyWishlistBadgeShape()
                    .fill(MugsyStyleTokens.ceramicHighlight)
                    .overlay {
                        MugsyWishlistBadgeShape()
                            .stroke(
                                MugsyStyleTokens.ink,
                                style: StrokeStyle(
                                    lineWidth: metrics.detail,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                    }
            case .favoriteHeart:
                MugsyHeartShape()
                    .fill(MugsyStyleTokens.blush)
                    .overlay {
                        MugsyHeartShape()
                            .stroke(MugsyStyleTokens.ink, lineWidth: metrics.detail)
                    }
            case .guidebookAndPen:
                MugsyGuidebookShape()
                    .fill(MugsyStyleTokens.ceramicHighlight)
                    .overlay {
                        MugsyGuidebookShape()
                            .stroke(
                                MugsyStyleTokens.ink,
                                style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round, lineJoin: .round)
                            )
                    }
                MugsyGuidebookDetailsShape()
                    .stroke(
                        MugsyStyleTokens.ink.opacity(0.72),
                        style: StrokeStyle(lineWidth: metrics.micro, lineCap: .round)
                    )
                MugsyPenShape()
                    .stroke(
                        MugsyStyleTokens.ink,
                        style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round)
                    )
            case .friendsPhone:
                MugsyPhoneShape()
                    .fill(MugsyStyleTokens.ink)
                MugsyPhoneScreenShape()
                    .fill(MugsyStyleTokens.mintAccent)
                MugsyPhoneFriendsShape()
                    .fill(MugsyStyleTokens.ceramicHighlight)
            case .camera:
                MugsyCameraShape()
                    .fill(MugsyStyleTokens.ink)
                MugsyCameraFaceShape()
                    .fill(MugsyStyleTokens.mintAccent)
                MugsyCameraLensShape()
                    .fill(MugsyStyleTokens.ceramicHighlight)
                    .overlay {
                        MugsyCameraLensShape()
                            .stroke(MugsyStyleTokens.ink, lineWidth: metrics.micro)
                    }
            case .journalNotebook:
                MugsyJournalShape()
                    .fill(MugsyStyleTokens.ceramicHighlight)
                    .overlay {
                        MugsyJournalShape()
                            .stroke(
                                MugsyStyleTokens.ink,
                                style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round, lineJoin: .round)
                            )
                    }
                MugsyJournalDetailsShape()
                    .stroke(
                        MugsyStyleTokens.ink.opacity(0.72),
                        style: StrokeStyle(lineWidth: metrics.micro, lineCap: .round)
                    )
            case .builderTools:
                MugsyHammerShape()
                    .fill(MugsyStyleTokens.ink)
                MugsyWrenchShape()
                    .stroke(
                        MugsyStyleTokens.ink.opacity(0.82),
                        style: StrokeStyle(lineWidth: metrics.detail * 1.7, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .frame(width: 500, height: 500)
    }
}

private struct MugsyOutfitLayer: View {
    let configuration: MugsyModelConfiguration
    let metrics: MugsyDrawingMetrics

    @ViewBuilder
    var body: some View {
        ZStack {
            switch configuration.outfit {
            case .none:
                EmptyView()
            case .builder:
                MugsyHardHatShape()
                    .fill(MugsyStyleTokens.mintAccent)
                    .overlay {
                        MugsyHardHatShape()
                            .stroke(
                                MugsyStyleTokens.ink,
                                style: StrokeStyle(lineWidth: metrics.primary, lineCap: .round, lineJoin: .round)
                            )
                    }
                MugsyHardHatDetailsShape()
                    .stroke(
                        MugsyStyleTokens.ink.opacity(0.78),
                        style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round, lineJoin: .round)
                    )
                MugsyBuilderApronShape()
                    .fill(MugsyStyleTokens.mintAccent.opacity(0.88))
                    .overlay {
                        MugsyBuilderApronShape()
                            .stroke(
                                MugsyStyleTokens.ink,
                                style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round, lineJoin: .round)
                            )
                    }
                MugsyBuilderApronDetailsShape()
                    .stroke(
                        MugsyStyleTokens.ink.opacity(0.78),
                        style: StrokeStyle(lineWidth: metrics.micro, lineCap: .round, lineJoin: .round)
                    )
            case .cafeScout:
                MugsyScoutHatShape()
                    .fill(MugsyStyleTokens.mintAccent)
                    .overlay {
                        MugsyScoutHatShape()
                            .stroke(
                                MugsyStyleTokens.ink,
                                style: StrokeStyle(lineWidth: metrics.primary, lineCap: .round, lineJoin: .round)
                            )
                    }
                MugsyScoutHatDetailsShape()
                    .stroke(
                        MugsyStyleTokens.ink.opacity(0.78),
                        style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round, lineJoin: .round)
                    )
            case .cameraCompanion:
                MugsyCameraStrapShape()
                    .stroke(
                        MugsyStyleTokens.ink,
                        style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round)
                    )
            case .cozyRitual:
                MugsyCozyWrapShape()
                    .fill(MugsyStyleTokens.mintAccent.opacity(0.78))
                    .overlay {
                        MugsyCozyWrapShape()
                            .stroke(
                                MugsyStyleTokens.ink,
                                style: StrokeStyle(lineWidth: metrics.detail, lineCap: .round, lineJoin: .round)
                            )
                    }
                MugsyCozyWrapDetailsShape()
                    .stroke(
                        MugsyStyleTokens.ink.opacity(0.56),
                        style: StrokeStyle(lineWidth: metrics.micro, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .frame(width: 500, height: 500)
    }
}

private struct MugsyEyeLayout {
    let eyeWidth: CGFloat
    let eyeHeight: CGFloat
    let pupilWidth: CGFloat
    let pupilHeight: CGFloat
    let verticalOffset: CGFloat
    let showsLid: Bool

    init(expression: MugsyExpression) {
        switch expression {
        case .neutral:
            self.init(eyeWidth: 42, eyeHeight: 46, pupilWidth: 27, pupilHeight: 36, verticalOffset: 0, showsLid: false)
        case .curious:
            self.init(eyeWidth: 43, eyeHeight: 49, pupilWidth: 28, pupilHeight: 38, verticalOffset: -1, showsLid: false)
        case .delighted:
            self.init(eyeWidth: 45, eyeHeight: 51, pupilWidth: 30, pupilHeight: 40, verticalOffset: -1, showsLid: false)
        case .focused:
            self.init(eyeWidth: 42, eyeHeight: 35, pupilWidth: 27, pupilHeight: 28, verticalOffset: 4, showsLid: true)
        case .tender:
            self.init(eyeWidth: 42, eyeHeight: 41, pupilWidth: 28, pupilHeight: 32, verticalOffset: 4, showsLid: true)
        case .concerned:
            self.init(eyeWidth: 42, eyeHeight: 44, pupilWidth: 27, pupilHeight: 35, verticalOffset: 3, showsLid: false)
        }
    }

    private init(
        eyeWidth: CGFloat,
        eyeHeight: CGFloat,
        pupilWidth: CGFloat,
        pupilHeight: CGFloat,
        verticalOffset: CGFloat,
        showsLid: Bool
    ) {
        self.eyeWidth = eyeWidth
        self.eyeHeight = eyeHeight
        self.pupilWidth = pupilWidth
        self.pupilHeight = pupilHeight
        self.verticalOffset = verticalOffset
        self.showsLid = showsLid
    }
}

private enum MugsySide {
    case left
    case right
}

private struct MugsyBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(72, 89))
        path.addCurve(
            to: rect.mugsyPoint(339, 88),
            control1: rect.mugsyPoint(132, 71),
            control2: rect.mugsyPoint(286, 72)
        )
        path.addCurve(
            to: rect.mugsyPoint(342, 328),
            control1: rect.mugsyPoint(344, 158),
            control2: rect.mugsyPoint(348, 273)
        )
        path.addCurve(
            to: rect.mugsyPoint(304, 363),
            control1: rect.mugsyPoint(341, 348),
            control2: rect.mugsyPoint(328, 358)
        )
        path.addCurve(
            to: rect.mugsyPoint(112, 366),
            control1: rect.mugsyPoint(255, 373),
            control2: rect.mugsyPoint(158, 373)
        )
        path.addCurve(
            to: rect.mugsyPoint(73, 329),
            control1: rect.mugsyPoint(86, 360),
            control2: rect.mugsyPoint(73, 347)
        )
        path.addCurve(
            to: rect.mugsyPoint(72, 89),
            control1: rect.mugsyPoint(67, 252),
            control2: rect.mugsyPoint(69, 151)
        )
        path.closeSubpath()
        return path
    }
}

private struct MugsyRimShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(69, 84))
        path.addCurve(
            to: rect.mugsyPoint(340, 82),
            control1: rect.mugsyPoint(126, 46),
            control2: rect.mugsyPoint(284, 48)
        )
        path.addCurve(
            to: rect.mugsyPoint(69, 84),
            control1: rect.mugsyPoint(293, 116),
            control2: rect.mugsyPoint(126, 116)
        )
        path.closeSubpath()
        return path
    }
}

private struct MugsyRimInteriorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(86, 81))
        path.addCurve(
            to: rect.mugsyPoint(324, 79),
            control1: rect.mugsyPoint(138, 56),
            control2: rect.mugsyPoint(278, 57)
        )
        path.addCurve(
            to: rect.mugsyPoint(86, 81),
            control1: rect.mugsyPoint(280, 101),
            control2: rect.mugsyPoint(137, 103)
        )
        path.closeSubpath()
        return path
    }
}

private struct MugsyLiquidSurfaceShape: Shape {
    let fillProgress: CGFloat

    func path(in rect: CGRect) -> Path {
        let progress = MugshotMotion.normalized(fillProgress)
        let horizontalInset = 34 * (1 - progress)
        let verticalInset = 14 * (1 - progress)
        let liquidRect = rect.mugsyRect(
            x: 86 + horizontalInset,
            y: 79 + verticalInset,
            width: 238 - horizontalInset * 2,
            height: 24 - verticalInset
        )
        var path = Path()
        path.addEllipse(in: liquidRect)
        return path
    }
}

private struct MugsyStaticSteamShape: Shape {
    let intensity: CGFloat

    func path(in rect: CGRect) -> Path {
        let progress = MugshotMotion.normalized(intensity)
        var path = Path()
        let columns = progress > 0.7 ? [155.0, 205.0, 255.0] : [175.0, 230.0]
        for (index, x) in columns.enumerated() {
            let height = 24 + progress * CGFloat(24 + index * 4)
            path.move(to: rect.mugsyPoint(x, 63))
            path.addCurve(
                to: rect.mugsyPoint(x + (index.isMultiple(of: 2) ? 5 : -5), 63 - height),
                control1: rect.mugsyPoint(x - 11, 55 - height * 0.24),
                control2: rect.mugsyPoint(x + 12, 47 - height * 0.70)
            )
        }
        return path
    }
}

private struct MugsyHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(334, 120))
        path.addCurve(
            to: rect.mugsyPoint(430, 130),
            control1: rect.mugsyPoint(370, 118),
            control2: rect.mugsyPoint(411, 111)
        )
        path.addCurve(
            to: rect.mugsyPoint(419, 278),
            control1: rect.mugsyPoint(443, 172),
            control2: rect.mugsyPoint(444, 239)
        )
        path.addCurve(
            to: rect.mugsyPoint(336, 312),
            control1: rect.mugsyPoint(403, 304),
            control2: rect.mugsyPoint(370, 316)
        )
        path.closeSubpath()

        path.move(to: rect.mugsyPoint(350, 154))
        path.addCurve(
            to: rect.mugsyPoint(400, 161),
            control1: rect.mugsyPoint(371, 151),
            control2: rect.mugsyPoint(393, 150)
        )
        path.addCurve(
            to: rect.mugsyPoint(398, 259),
            control1: rect.mugsyPoint(411, 188),
            control2: rect.mugsyPoint(411, 233)
        )
        path.addCurve(
            to: rect.mugsyPoint(348, 273),
            control1: rect.mugsyPoint(388, 272),
            control2: rect.mugsyPoint(369, 276)
        )
        path.closeSubpath()
        return path
    }
}

private struct MugsyHandleShadeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(410, 128))
        path.addCurve(
            to: rect.mugsyPoint(405, 286),
            control1: rect.mugsyPoint(439, 174),
            control2: rect.mugsyPoint(440, 249)
        )
        path.addCurve(
            to: rect.mugsyPoint(377, 303),
            control1: rect.mugsyPoint(396, 294),
            control2: rect.mugsyPoint(387, 300)
        )
        path.addCurve(
            to: rect.mugsyPoint(410, 128),
            control1: rect.mugsyPoint(421, 247),
            control2: rect.mugsyPoint(421, 174)
        )
        path.closeSubpath()
        return path
    }
}

private struct MugsyCeramicHighlightShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(91, 126))
        path.addCurve(
            to: rect.mugsyPoint(119, 331),
            control1: rect.mugsyPoint(75, 195),
            control2: rect.mugsyPoint(81, 293)
        )
        path.addCurve(
            to: rect.mugsyPoint(154, 345),
            control1: rect.mugsyPoint(131, 340),
            control2: rect.mugsyPoint(143, 344)
        )
        path.addCurve(
            to: rect.mugsyPoint(124, 119),
            control1: rect.mugsyPoint(126, 275),
            control2: rect.mugsyPoint(126, 174)
        )
        path.closeSubpath()
        return path
    }
}

private struct MugsyCeramicShadeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(304, 106))
        path.addCurve(
            to: rect.mugsyPoint(329, 329),
            control1: rect.mugsyPoint(330, 165),
            control2: rect.mugsyPoint(335, 273)
        )
        path.addCurve(
            to: rect.mugsyPoint(287, 354),
            control1: rect.mugsyPoint(321, 342),
            control2: rect.mugsyPoint(306, 349)
        )
        path.addCurve(
            to: rect.mugsyPoint(304, 106),
            control1: rect.mugsyPoint(306, 286),
            control2: rect.mugsyPoint(309, 178)
        )
        path.closeSubpath()
        return path
    }
}

private struct MugsyLegsShape: Shape {
    let articulation: MugsyLegArticulation

    func path(in rect: CGRect) -> Path {
        let bend = articulation.bendProgress
        var path = Path()

        guard bend > 0.001 else {
            path.move(to: rect.mugsyPoint(145, 356))
            path.addCurve(
                to: rect.mugsyPoint(145, 425),
                control1: rect.mugsyPoint(143, 379),
                control2: rect.mugsyPoint(151, 403)
            )
            path.move(to: rect.mugsyPoint(257, 356))
            path.addCurve(
                to: rect.mugsyPoint(257, 425),
                control1: rect.mugsyPoint(259, 379),
                control2: rect.mugsyPoint(251, 404)
            )
            return path
        }

        let shift = articulation.bodyOffset
        let weight = articulation.weightShift
        // The leading knee takes the beat while the supporting knee stays softly
        // flexed. Keeping a meaningful difference between them makes the motion
        // read as a dance step at celebration-card scale instead of a wobble.
        let leftBend = bend * (0.42 + 0.58 * ((1 - weight) / 2))
        let rightBend = bend * (0.42 + 0.58 * ((1 + weight) / 2))
        let leftHip = CGPoint(x: 145 + shift.width, y: 356 + shift.height)
        let rightHip = CGPoint(x: 257 + shift.width, y: 356 + shift.height)
        let leftAnkle = CGPoint(x: 145, y: 425)
        let rightAnkle = CGPoint(x: 257, y: 425)
        let leftKnee = CGPoint(
            x: (leftHip.x + leftAnkle.x) / 2 - 32 * leftBend,
            y: leftHip.y + (leftAnkle.y - leftHip.y) * 0.52
        )
        let rightKnee = CGPoint(
            x: (rightHip.x + rightAnkle.x) / 2 + 32 * rightBend,
            y: rightHip.y + (rightAnkle.y - rightHip.y) * 0.52
        )

        path.move(to: rect.mugsyPoint(leftHip.x, leftHip.y))
        path.addCurve(
            to: rect.mugsyPoint(leftKnee.x, leftKnee.y),
            control1: rect.mugsyPoint(leftHip.x - 3 * leftBend, leftHip.y + 10),
            control2: rect.mugsyPoint(leftKnee.x + 3, leftKnee.y - 9)
        )
        path.addCurve(
            to: rect.mugsyPoint(leftAnkle.x, leftAnkle.y),
            control1: rect.mugsyPoint(leftKnee.x - 2, leftKnee.y + 10),
            control2: rect.mugsyPoint(leftAnkle.x - 5 * leftBend, leftAnkle.y - 10)
        )

        path.move(to: rect.mugsyPoint(rightHip.x, rightHip.y))
        path.addCurve(
            to: rect.mugsyPoint(rightKnee.x, rightKnee.y),
            control1: rect.mugsyPoint(rightHip.x + 3 * rightBend, rightHip.y + 10),
            control2: rect.mugsyPoint(rightKnee.x - 3, rightKnee.y - 9)
        )
        path.addCurve(
            to: rect.mugsyPoint(rightAnkle.x, rightAnkle.y),
            control1: rect.mugsyPoint(rightKnee.x + 2, rightKnee.y + 10),
            control2: rect.mugsyPoint(rightAnkle.x + 5 * rightBend, rightAnkle.y - 10)
        )
        return path
    }
}

private struct MugsyFootShape: Shape {
    let side: MugsySide

    func path(in rect: CGRect) -> Path {
        let origin = side == .left ? CGPoint(x: 130, y: 422) : CGPoint(x: 247, y: 422)
        var path = Path()
        path.move(to: rect.mugsyPoint(origin.x + 4, origin.y + 2))
        path.addCurve(
            to: rect.mugsyPoint(origin.x + 26, origin.y + 7),
            control1: rect.mugsyPoint(origin.x + 11, origin.y - 2),
            control2: rect.mugsyPoint(origin.x + 22, origin.y + 1)
        )
        path.addCurve(
            to: rect.mugsyPoint(origin.x + 2, origin.y + 13),
            control1: rect.mugsyPoint(origin.x + 22, origin.y + 15),
            control2: rect.mugsyPoint(origin.x + 9, origin.y + 17)
        )
        path.closeSubpath()
        return path
    }
}

private struct MugsyArmsShape: Shape {
    let pose: MugsyArmPose

    func path(in rect: CGRect) -> Path {
        let endpoints = MugsyArmGeometry.endpoints(for: pose)
        var path = Path()
        if pose == .relaxed {
            path.move(to: rect.mugsyPoint(75, 251))
            path.addCurve(
                to: rect.mugsyPoint(endpoints.left.x, endpoints.left.y),
                control1: rect.mugsyPoint(58, 270),
                control2: rect.mugsyPoint(49, 299)
            )
            path.move(to: rect.mugsyPoint(339, 252))
            path.addCurve(
                to: rect.mugsyPoint(endpoints.right.x, endpoints.right.y),
                control1: rect.mugsyPoint(352, 273),
                control2: rect.mugsyPoint(358, 300)
            )
        } else if pose == .waving {
            path.move(to: rect.mugsyPoint(75, 251))
            path.addCurve(
                to: rect.mugsyPoint(endpoints.left.x, endpoints.left.y),
                control1: rect.mugsyPoint(58, 270),
                control2: rect.mugsyPoint(49, 299)
            )
            path.move(to: rect.mugsyPoint(338, 259))
            path.addCurve(
                to: rect.mugsyPoint(endpoints.right.x, endpoints.right.y),
                control1: rect.mugsyPoint(359, 244),
                control2: rect.mugsyPoint(358, 201)
            )
        } else {
            path.move(to: rect.mugsyPoint(76, 257))
            path.addCurve(
                to: rect.mugsyPoint(endpoints.left.x, endpoints.left.y),
                control1: rect.mugsyPoint(92, 279),
                control2: rect.mugsyPoint(endpoints.left.x - 28, endpoints.left.y + 4)
            )
            path.move(to: rect.mugsyPoint(338, 259))
            path.addCurve(
                to: rect.mugsyPoint(endpoints.right.x, endpoints.right.y),
                control1: rect.mugsyPoint(304, 286),
                control2: rect.mugsyPoint(endpoints.right.x + 35, endpoints.right.y + 5)
            )
        }
        return path
    }
}

private struct MugsyHandShape: Shape {
    let side: MugsySide
    let pose: MugsyArmPose

    func path(in rect: CGRect) -> Path {
        let endpoints = MugsyArmGeometry.endpoints(for: pose)
        let center = side == .left ? endpoints.left : endpoints.right
        var path = Path()
        path.move(to: rect.mugsyPoint(center.x - 8, center.y - 2))
        path.addCurve(
            to: rect.mugsyPoint(center.x + 8, center.y - 3),
            control1: rect.mugsyPoint(center.x - 7, center.y - 12),
            control2: rect.mugsyPoint(center.x + 6, center.y - 12)
        )
        path.addCurve(
            to: rect.mugsyPoint(center.x + 7, center.y + 9),
            control1: rect.mugsyPoint(center.x + 13, center.y + 1),
            control2: rect.mugsyPoint(center.x + 11, center.y + 7)
        )
        path.addCurve(
            to: rect.mugsyPoint(center.x - 8, center.y - 2),
            control1: rect.mugsyPoint(center.x - 1, center.y + 13),
            control2: rect.mugsyPoint(center.x - 11, center.y + 8)
        )
        path.closeSubpath()
        return path
    }
}

private enum MugsyArmGeometry {
    static func endpoints(for pose: MugsyArmPose) -> (left: CGPoint, right: CGPoint) {
        switch pose {
        case .relaxed:
            return (CGPoint(x: 49, y: 322), CGPoint(x: 355, y: 323))
        case .waving:
            return (CGPoint(x: 49, y: 322), CGPoint(x: 333, y: 177))
        case .crossedOverProp:
            return (CGPoint(x: 147, y: 291), CGPoint(x: 191, y: 291))
        case .cradling:
            return (CGPoint(x: 151, y: 300), CGPoint(x: 197, y: 301))
        case .reading:
            return (CGPoint(x: 133, y: 317), CGPoint(x: 232, y: 316))
        case .holdingCenter:
            return (CGPoint(x: 154, y: 294), CGPoint(x: 205, y: 295))
        case .holdingCamera:
            return (CGPoint(x: 143, y: 302), CGPoint(x: 221, y: 302))
        case .writing:
            return (CGPoint(x: 137, y: 314), CGPoint(x: 220, y: 292))
        case .presenting:
            return (CGPoint(x: 139, y: 307), CGPoint(x: 242, y: 300))
        }
    }
}

private struct MugsyCheeksShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect.mugsyRect(x: 98, y: 207, width: 31, height: 15))
        path.addEllipse(in: rect.mugsyRect(x: 220, y: 208, width: 32, height: 15))
        return path
    }
}

private struct MugsyGlassesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(84, 143))
        path.addCurve(to: rect.mugsyPoint(164, 140), control1: rect.mugsyPoint(106, 137), control2: rect.mugsyPoint(142, 136))
        path.addCurve(to: rect.mugsyPoint(164, 202), control1: rect.mugsyPoint(170, 155), control2: rect.mugsyPoint(170, 186))
        path.addCurve(to: rect.mugsyPoint(89, 207), control1: rect.mugsyPoint(144, 210), control2: rect.mugsyPoint(109, 211))
        path.addCurve(to: rect.mugsyPoint(84, 143), control1: rect.mugsyPoint(81, 188), control2: rect.mugsyPoint(79, 158))
        path.closeSubpath()

        path.move(to: rect.mugsyPoint(178, 141))
        path.addCurve(to: rect.mugsyPoint(270, 144), control1: rect.mugsyPoint(203, 137), control2: rect.mugsyPoint(247, 139))
        path.addCurve(to: rect.mugsyPoint(267, 205), control1: rect.mugsyPoint(277, 159), control2: rect.mugsyPoint(276, 190))
        path.addCurve(to: rect.mugsyPoint(175, 202), control1: rect.mugsyPoint(243, 210), control2: rect.mugsyPoint(201, 207))
        path.addCurve(to: rect.mugsyPoint(178, 141), control1: rect.mugsyPoint(170, 185), control2: rect.mugsyPoint(170, 154))
        path.closeSubpath()

        path.move(to: rect.mugsyPoint(164, 166))
        path.addCurve(to: rect.mugsyPoint(178, 168), control1: rect.mugsyPoint(168, 162), control2: rect.mugsyPoint(174, 162))
        path.move(to: rect.mugsyPoint(84, 157))
        path.addLine(to: rect.mugsyPoint(69, 155))
        path.move(to: rect.mugsyPoint(270, 160))
        path.addLine(to: rect.mugsyPoint(342, 163))
        return path
    }
}

private struct MugsyLensHighlightsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(97, 151))
        path.addCurve(to: rect.mugsyPoint(113, 148), control1: rect.mugsyPoint(102, 149), control2: rect.mugsyPoint(108, 148))
        path.move(to: rect.mugsyPoint(193, 150))
        path.addCurve(to: rect.mugsyPoint(210, 151), control1: rect.mugsyPoint(198, 149), control2: rect.mugsyPoint(205, 150))
        return path
    }
}

private struct MugsyEyebrowsShape: Shape {
    let expression: MugsyExpression

    func path(in rect: CGRect) -> Path {
        let layout = MugsyBrowLayout(expression: expression)
        var path = Path()
        path.move(to: rect.mugsyPoint(117, layout.leftStartY))
        path.addCurve(
            to: rect.mugsyPoint(141, layout.leftEndY),
            control1: rect.mugsyPoint(124, layout.leftControlY),
            control2: rect.mugsyPoint(134, layout.leftControlY)
        )
        path.move(to: rect.mugsyPoint(209, layout.rightStartY))
        path.addCurve(
            to: rect.mugsyPoint(235, layout.rightEndY),
            control1: rect.mugsyPoint(216, layout.rightControlY),
            control2: rect.mugsyPoint(227, layout.rightControlY)
        )
        return path
    }
}

private struct MugsyBrowLayout {
    let leftStartY: CGFloat
    let leftEndY: CGFloat
    let leftControlY: CGFloat
    let rightStartY: CGFloat
    let rightEndY: CGFloat
    let rightControlY: CGFloat

    init(expression: MugsyExpression) {
        switch expression {
        case .neutral:
            self.init(132, 125, 125, 125, 133, 125)
        case .curious:
            self.init(131, 121, 121, 131, 137, 128)
        case .delighted:
            self.init(128, 121, 119, 121, 129, 119)
        case .focused:
            self.init(121, 133, 123, 133, 122, 123)
        case .tender:
            self.init(131, 123, 121, 123, 132, 121)
        case .concerned:
            self.init(136, 124, 125, 124, 137, 125)
        }
    }

    private init(_ ls: CGFloat, _ le: CGFloat, _ lc: CGFloat, _ rs: CGFloat, _ re: CGFloat, _ rc: CGFloat) {
        leftStartY = ls
        leftEndY = le
        leftControlY = lc
        rightStartY = rs
        rightEndY = re
        rightControlY = rc
    }
}

private struct MugsyEyeWhiteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control1: CGPoint(x: rect.maxX * 0.82, y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.height * 0.24))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.height * 0.82), control2: CGPoint(x: rect.width * 0.76, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.midY), control1: CGPoint(x: rect.width * 0.22, y: rect.maxY), control2: CGPoint(x: rect.minX, y: rect.height * 0.76))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY), control1: CGPoint(x: rect.minX, y: rect.height * 0.20), control2: CGPoint(x: rect.width * 0.26, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct MugsyPupilShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control1: CGPoint(x: rect.maxX * 0.84, y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.height * 0.26))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.height * 0.80), control2: CGPoint(x: rect.width * 0.72, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.midY), control1: CGPoint(x: rect.width * 0.24, y: rect.maxY), control2: CGPoint(x: rect.minX, y: rect.height * 0.73))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY), control1: CGPoint(x: rect.minX, y: rect.height * 0.21), control2: CGPoint(x: rect.width * 0.28, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct MugsyEyeOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.08))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.14, y: rect.height * 0.62),
            control1: CGPoint(x: rect.width * 0.11, y: rect.height * 0.24),
            control2: CGPoint(x: rect.width * 0.10, y: rect.height * 0.46)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.53, y: rect.height * 0.96),
            control1: CGPoint(x: rect.width * 0.22, y: rect.height * 0.88),
            control2: CGPoint(x: rect.width * 0.38, y: rect.height * 0.98)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.87, y: rect.height * 0.58),
            control1: CGPoint(x: rect.width * 0.72, y: rect.height * 0.94),
            control2: CGPoint(x: rect.width * 0.84, y: rect.height * 0.82)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.79, y: rect.height * 0.09),
            control1: CGPoint(x: rect.width * 0.91, y: rect.height * 0.39),
            control2: CGPoint(x: rect.width * 0.88, y: rect.height * 0.20)
        )
        return path
    }
}

private struct MugsyEyeHighlightShape: Shape {
    let mirror: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let largeX = mirror ? rect.width * 0.64 : rect.width * 0.36
        let smallX = mirror ? rect.width * 0.35 : rect.width * 0.66
        path.addEllipse(in: CGRect(x: largeX - 2.4, y: rect.height * 0.15, width: 4.8, height: 6.4))
        path.addEllipse(in: CGRect(x: smallX - 1.4, y: rect.height * 0.53, width: 2.8, height: 3.4))
        return path
    }
}

private struct MugsyEyelidShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.42))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.35),
            control1: CGPoint(x: rect.width * 0.28, y: rect.height * 0.18),
            control2: CGPoint(x: rect.width * 0.70, y: rect.height * 0.20)
        )
        return path
    }
}

private struct MugsyMouthShape: Shape {
    let expression: MugsyExpression

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch expression {
        case .neutral:
            path.move(to: rect.mugsyPoint(151, 219))
            path.addCurve(to: rect.mugsyPoint(193, 220), control1: rect.mugsyPoint(163, 229), control2: rect.mugsyPoint(181, 229))
        case .focused:
            path.move(to: rect.mugsyPoint(154, 221))
            path.addCurve(to: rect.mugsyPoint(190, 220), control1: rect.mugsyPoint(166, 218), control2: rect.mugsyPoint(178, 218))
        case .tender:
            path.move(to: rect.mugsyPoint(156, 220))
            path.addCurve(to: rect.mugsyPoint(189, 220), control1: rect.mugsyPoint(166, 227), control2: rect.mugsyPoint(179, 227))
        case .concerned:
            path.move(to: rect.mugsyPoint(153, 226))
            path.addCurve(to: rect.mugsyPoint(191, 226), control1: rect.mugsyPoint(164, 213), control2: rect.mugsyPoint(180, 213))
        case .curious, .delighted:
            break
        }
        return path
    }
}

private struct MugsyCuriousMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(162, 210))
        path.addCurve(to: rect.mugsyPoint(186, 220), control1: rect.mugsyPoint(174, 206), control2: rect.mugsyPoint(189, 211))
        path.addCurve(to: rect.mugsyPoint(166, 231), control1: rect.mugsyPoint(184, 230), control2: rect.mugsyPoint(173, 234))
        path.addCurve(to: rect.mugsyPoint(162, 210), control1: rect.mugsyPoint(157, 228), control2: rect.mugsyPoint(156, 215))
        path.closeSubpath()
        return path
    }
}

private struct MugsyOpenMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(141, 208))
        path.addCurve(to: rect.mugsyPoint(204, 208), control1: rect.mugsyPoint(159, 200), control2: rect.mugsyPoint(186, 200))
        path.addCurve(to: rect.mugsyPoint(173, 245), control1: rect.mugsyPoint(201, 230), control2: rect.mugsyPoint(188, 244))
        path.addCurve(to: rect.mugsyPoint(141, 208), control1: rect.mugsyPoint(156, 244), control2: rect.mugsyPoint(142, 230))
        path.closeSubpath()
        return path
    }
}

private struct MugsyTongueShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(156, 232))
        path.addCurve(to: rect.mugsyPoint(189, 231), control1: rect.mugsyPoint(164, 224), control2: rect.mugsyPoint(181, 224))
        path.addCurve(to: rect.mugsyPoint(173, 243), control1: rect.mugsyPoint(185, 240), control2: rect.mugsyPoint(180, 243))
        path.addCurve(to: rect.mugsyPoint(156, 232), control1: rect.mugsyPoint(165, 243), control2: rect.mugsyPoint(160, 239))
        path.closeSubpath()
        return path
    }
}

private struct MugsyWishlistBadgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(154, 299))
        path.addLine(to: rect.mugsyPoint(153, 333))
        path.addLine(to: rect.mugsyPoint(171, 318))
        path.addLine(to: rect.mugsyPoint(188, 333))
        path.addLine(to: rect.mugsyPoint(188, 299))
        path.addCurve(
            to: rect.mugsyPoint(154, 299),
            control1: rect.mugsyPoint(179, 306),
            control2: rect.mugsyPoint(163, 306)
        )
        path.closeSubpath()
        return path
    }
}

private struct MugsyHeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(174, 327))
        path.addCurve(
            to: rect.mugsyPoint(139, 294),
            control1: rect.mugsyPoint(159, 315),
            control2: rect.mugsyPoint(139, 307)
        )
        path.addCurve(
            to: rect.mugsyPoint(174, 286),
            control1: rect.mugsyPoint(141, 275),
            control2: rect.mugsyPoint(163, 276)
        )
        path.addCurve(
            to: rect.mugsyPoint(208, 294),
            control1: rect.mugsyPoint(184, 276),
            control2: rect.mugsyPoint(207, 276)
        )
        path.addCurve(
            to: rect.mugsyPoint(174, 327),
            control1: rect.mugsyPoint(209, 307),
            control2: rect.mugsyPoint(190, 315)
        )
        path.closeSubpath()
        return path
    }
}

private struct MugsyGuidebookShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(113, 286))
        path.addCurve(
            to: rect.mugsyPoint(173, 299),
            control1: rect.mugsyPoint(132, 282),
            control2: rect.mugsyPoint(157, 289)
        )
        path.addCurve(
            to: rect.mugsyPoint(234, 286),
            control1: rect.mugsyPoint(190, 289),
            control2: rect.mugsyPoint(216, 282)
        )
        path.addLine(to: rect.mugsyPoint(234, 337))
        path.addCurve(to: rect.mugsyPoint(173, 345), control1: rect.mugsyPoint(214, 334), control2: rect.mugsyPoint(190, 338))
        path.addCurve(to: rect.mugsyPoint(113, 337), control1: rect.mugsyPoint(156, 338), control2: rect.mugsyPoint(132, 334))
        path.closeSubpath()
        return path
    }
}

private struct MugsyGuidebookDetailsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(173, 299))
        path.addLine(to: rect.mugsyPoint(173, 344))
        path.move(to: rect.mugsyPoint(126, 305))
        path.addCurve(to: rect.mugsyPoint(159, 311), control1: rect.mugsyPoint(137, 302), control2: rect.mugsyPoint(148, 305))
        path.move(to: rect.mugsyPoint(188, 311))
        path.addCurve(to: rect.mugsyPoint(221, 305), control1: rect.mugsyPoint(199, 305), control2: rect.mugsyPoint(210, 302))
        return path
    }
}

private struct MugsyPenShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(228, 281))
        path.addLine(to: rect.mugsyPoint(245, 326))
        path.move(to: rect.mugsyPoint(224, 286))
        path.addLine(to: rect.mugsyPoint(233, 282))
        return path
    }
}

private struct MugsyPhoneShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(148, 268))
        path.addCurve(to: rect.mugsyPoint(205, 268), control1: rect.mugsyPoint(151, 260), control2: rect.mugsyPoint(201, 260))
        path.addCurve(to: rect.mugsyPoint(205, 344), control1: rect.mugsyPoint(213, 273), control2: rect.mugsyPoint(213, 338))
        path.addCurve(to: rect.mugsyPoint(148, 344), control1: rect.mugsyPoint(201, 352), control2: rect.mugsyPoint(152, 352))
        path.addCurve(to: rect.mugsyPoint(148, 268), control1: rect.mugsyPoint(140, 338), control2: rect.mugsyPoint(140, 273))
        path.closeSubpath()
        return path
    }
}

private struct MugsyPhoneScreenShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.mugsyRect(x: 155, y: 276, width: 43, height: 56))
    }
}

private struct MugsyPhoneFriendsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect.mugsyRect(x: 164, y: 287, width: 10, height: 10))
        path.addEllipse(in: rect.mugsyRect(x: 180, y: 287, width: 10, height: 10))
        path.addCurve(
            to: rect.mugsyPoint(174, 318),
            control1: rect.mugsyPoint(160, 302),
            control2: rect.mugsyPoint(160, 317)
        )
        path.addCurve(
            to: rect.mugsyPoint(194, 318),
            control1: rect.mugsyPoint(180, 302),
            control2: rect.mugsyPoint(194, 303)
        )
        return path
    }
}

private struct MugsyCameraShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(124, 286))
        path.addLine(to: rect.mugsyPoint(148, 286))
        path.addLine(to: rect.mugsyPoint(158, 274))
        path.addLine(to: rect.mugsyPoint(196, 274))
        path.addLine(to: rect.mugsyPoint(207, 286))
        path.addLine(to: rect.mugsyPoint(231, 286))
        path.addCurve(to: rect.mugsyPoint(238, 333), control1: rect.mugsyPoint(239, 287), control2: rect.mugsyPoint(241, 329))
        path.addCurve(to: rect.mugsyPoint(124, 333), control1: rect.mugsyPoint(232, 340), control2: rect.mugsyPoint(130, 340))
        path.addCurve(to: rect.mugsyPoint(124, 286), control1: rect.mugsyPoint(117, 329), control2: rect.mugsyPoint(117, 290))
        path.closeSubpath()
        return path
    }
}

private struct MugsyCameraFaceShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.mugsyRect(x: 132, y: 293, width: 97, height: 33))
    }
}

private struct MugsyCameraLensShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect.mugsyRect(x: 165, y: 291, width: 42, height: 42))
        path.addEllipse(in: rect.mugsyRect(x: 177, y: 302, width: 18, height: 18))
        return path
    }
}

private struct MugsyJournalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(119, 284))
        path.addCurve(to: rect.mugsyPoint(226, 280), control1: rect.mugsyPoint(150, 277), control2: rect.mugsyPoint(199, 277))
        path.addLine(to: rect.mugsyPoint(231, 340))
        path.addCurve(to: rect.mugsyPoint(123, 344), control1: rect.mugsyPoint(200, 349), control2: rect.mugsyPoint(151, 349))
        path.closeSubpath()
        return path
    }
}

private struct MugsyJournalDetailsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<3 {
            let y = CGFloat(299 + index * 13)
            path.move(to: rect.mugsyPoint(143, y))
            path.addLine(to: rect.mugsyPoint(211, y - 2))
        }
        path.move(to: rect.mugsyPoint(130, 288))
        path.addLine(to: rect.mugsyPoint(134, 338))
        return path
    }
}

private struct MugsyHammerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect.mugsyRect(x: 142, y: 280, width: 16, height: 69))
        path.move(to: rect.mugsyPoint(122, 270))
        path.addLine(to: rect.mugsyPoint(177, 270))
        path.addLine(to: rect.mugsyPoint(185, 289))
        path.addLine(to: rect.mugsyPoint(121, 289))
        path.closeSubpath()
        return path
    }
}

private struct MugsyWrenchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(210, 342))
        path.addLine(to: rect.mugsyPoint(230, 287))
        path.addCurve(to: rect.mugsyPoint(244, 276), control1: rect.mugsyPoint(233, 279), control2: rect.mugsyPoint(239, 276))
        path.move(to: rect.mugsyPoint(238, 273))
        path.addLine(to: rect.mugsyPoint(249, 282))
        return path
    }
}

private struct MugsyHardHatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(119, 76))
        path.addCurve(to: rect.mugsyPoint(278, 75), control1: rect.mugsyPoint(143, 45), control2: rect.mugsyPoint(252, 43))
        path.addLine(to: rect.mugsyPoint(294, 88))
        path.addCurve(to: rect.mugsyPoint(104, 91), control1: rect.mugsyPoint(250, 101), control2: rect.mugsyPoint(150, 102))
        path.closeSubpath()
        return path
    }
}

private struct MugsyHardHatDetailsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(105, 88))
        path.addCurve(to: rect.mugsyPoint(294, 86), control1: rect.mugsyPoint(151, 98), control2: rect.mugsyPoint(250, 97))
        path.move(to: rect.mugsyPoint(198, 48))
        path.addCurve(to: rect.mugsyPoint(197, 88), control1: rect.mugsyPoint(192, 60), control2: rect.mugsyPoint(193, 77))
        return path
    }
}

private struct MugsyBuilderApronShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(114, 278))
        path.addCurve(to: rect.mugsyPoint(284, 278), control1: rect.mugsyPoint(160, 267), control2: rect.mugsyPoint(239, 268))
        path.addLine(to: rect.mugsyPoint(299, 354))
        path.addCurve(to: rect.mugsyPoint(103, 356), control1: rect.mugsyPoint(252, 369), control2: rect.mugsyPoint(151, 371))
        path.closeSubpath()
        return path
    }
}

private struct MugsyBuilderApronDetailsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(114, 286))
        path.addCurve(to: rect.mugsyPoint(286, 285), control1: rect.mugsyPoint(161, 296), control2: rect.mugsyPoint(239, 295))
        path.addRoundedRect(in: rect.mugsyRect(x: 158, y: 317, width: 82, height: 29), cornerSize: CGSize(width: 7, height: 7))
        path.move(to: rect.mugsyPoint(199, 318))
        path.addLine(to: rect.mugsyPoint(199, 345))
        return path
    }
}

private struct MugsyScoutHatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(123, 77))
        path.addCurve(to: rect.mugsyPoint(269, 72), control1: rect.mugsyPoint(146, 43), control2: rect.mugsyPoint(245, 39))
        path.addCurve(to: rect.mugsyPoint(283, 88), control1: rect.mugsyPoint(278, 76), control2: rect.mugsyPoint(282, 82))
        path.addCurve(to: rect.mugsyPoint(302, 94), control1: rect.mugsyPoint(293, 89), control2: rect.mugsyPoint(299, 91))
        path.addCurve(to: rect.mugsyPoint(94, 98), control1: rect.mugsyPoint(251, 112), control2: rect.mugsyPoint(144, 115))
        path.addCurve(to: rect.mugsyPoint(123, 77), control1: rect.mugsyPoint(102, 88), control2: rect.mugsyPoint(112, 82))
        path.closeSubpath()
        return path
    }
}

private struct MugsyScoutHatDetailsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(116, 80))
        path.addCurve(to: rect.mugsyPoint(279, 78), control1: rect.mugsyPoint(157, 91), control2: rect.mugsyPoint(235, 90))
        path.move(to: rect.mugsyPoint(212, 50))
        path.addLine(to: rect.mugsyPoint(207, 83))
        path.addEllipse(in: rect.mugsyRect(x: 239, y: 61, width: 13, height: 13))
        return path
    }
}

private struct MugsyCameraStrapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(107, 236))
        path.addCurve(to: rect.mugsyPoint(133, 302), control1: rect.mugsyPoint(111, 264), control2: rect.mugsyPoint(120, 289))
        path.move(to: rect.mugsyPoint(288, 238))
        path.addCurve(to: rect.mugsyPoint(229, 302), control1: rect.mugsyPoint(277, 267), control2: rect.mugsyPoint(254, 292))
        return path
    }
}

private struct MugsyCozyWrapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(90, 292))
        path.addCurve(to: rect.mugsyPoint(316, 290), control1: rect.mugsyPoint(146, 276), control2: rect.mugsyPoint(260, 275))
        path.addLine(to: rect.mugsyPoint(308, 352))
        path.addCurve(to: rect.mugsyPoint(104, 358), control1: rect.mugsyPoint(260, 369), control2: rect.mugsyPoint(154, 373))
        path.closeSubpath()
        return path
    }
}

private struct MugsyCozyWrapDetailsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for x in stride(from: 121.0, through: 285.0, by: 41.0) {
            path.move(to: rect.mugsyPoint(x, 302))
            path.addCurve(
                to: rect.mugsyPoint(x + 18, 349),
                control1: rect.mugsyPoint(x + 22, 313),
                control2: rect.mugsyPoint(x - 3, 337)
            )
        }
        path.move(to: rect.mugsyPoint(100, 318))
        path.addCurve(to: rect.mugsyPoint(311, 315), control1: rect.mugsyPoint(155, 328), control2: rect.mugsyPoint(255, 326))
        return path
    }
}

private extension CGRect {
    func mugsyPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(
            x: minX + width * (x / 500),
            y: minY + height * (y / 500)
        )
    }

    func mugsyRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            x: minX + self.width * (x / 500),
            y: minY + self.height * (y / 500),
            width: self.width * (width / 500),
            height: self.height * (height / 500)
        )
    }
}

#Preview("Mugsy expression sheet") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
            ForEach(MugsyExpression.allCases) { expression in
                VStack(spacing: 6) {
                    MugsyModelView(configuration: MugsyModelConfiguration(expression: expression))
                        .frame(width: 150, height: 150)
                    Text(expression.title)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding()
    }
    .background(Color.creamWhite)
}

#Preview("Mugsy scale matrix") {
    HStack(alignment: .bottom, spacing: 18) {
        ForEach([44.0, 72.0, 120.0, 200.0], id: \.self) { size in
            MugsyModelView()
                .frame(width: size, height: size)
        }
    }
    .padding()
    .background(Color.creamWhite)
}

#Preview("Mugsy planted knee articulation") {
    HStack(alignment: .bottom, spacing: 12) {
        MugsyModelView(
            configuration: .init(
                expression: .delighted,
                armPose: .presenting,
                legArticulation: .neutral
            )
        )
        MugsyModelView(
            configuration: .init(
                expression: .delighted,
                armPose: .presenting,
                legArticulation: .init(bendProgress: 0.62, weightShift: -0.72)
            )
        )
        MugsyModelView(
            configuration: .init(
                expression: .delighted,
                armPose: .presenting,
                legArticulation: .init(bendProgress: 1, weightShift: 0.82)
            )
        )
    }
    .frame(height: 180)
    .padding()
    .background(Color.creamWhite)
}
