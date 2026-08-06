import SwiftUI

enum MugsyLogoTransformationState: Equatable {
    case mugsy
    case logo

    var progress: CGFloat {
        switch self {
        case .mugsy: return 0
        case .logo: return 1
        }
    }

    var opposite: MugsyLogoTransformationState {
        switch self {
        case .mugsy: return .logo
        case .logo: return .mugsy
        }
    }
}

/// A deterministic, reversible brand transition driven by one normalized
/// progress value. Intermediate frames stay vector-native; the completed logo
/// locks to the approved `MugshotAppIcon` asset.
struct MugsyLogoTransformationView: View {
    var target: MugsyLogoTransformationState = .logo
    var duration: TimeInterval = 3
    var playsOnAppear = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var reduceMotionOverride
    @State private var displayedProgress: CGFloat

    init(
        target: MugsyLogoTransformationState = .logo,
        duration: TimeInterval = 3,
        playsOnAppear: Bool = true
    ) {
        self.target = target
        self.duration = duration
        self.playsOnAppear = playsOnAppear
        _displayedProgress = State(
            initialValue: playsOnAppear ? target.opposite.progress : target.progress
        )
    }

    private var effectiveReduceMotion: Bool {
        reduceMotionOverride ?? reduceMotion
    }

    var body: some View {
        MugsyLogoTransformationRenderer(progress: displayedProgress)
            .aspectRatio(1, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(target == .logo ? "Mugshot logo" : "Mugsy, the Mugshot mascot")
            .task {
                guard playsOnAppear else { return }
                await Task.yield()
                transition(to: target)
            }
            .onChange(of: target) { _, newTarget in
                transition(to: newTarget)
            }
            .onChange(of: effectiveReduceMotion) { _, shouldReduceMotion in
                if shouldReduceMotion {
                    displayedProgress = target.progress
                }
            }
    }

    @MainActor
    private func transition(to newTarget: MugsyLogoTransformationState) {
        guard !effectiveReduceMotion else {
            displayedProgress = newTarget.progress
            return
        }

        withAnimation(.linear(duration: max(0.1, duration))) {
            displayedProgress = newTarget.progress
        }
    }
}

private struct MugsyLogoTransformationRenderer: View, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var normalizedProgress: CGFloat {
        progress.mugshotClamped(to: 0...1)
    }

    private var presentation: MugsyModelPresentation {
        let value = normalizedProgress
        let waveLift = MugsyLogoTimeline.smoothWindow(
            value,
            fadeIn: 0.025...0.09,
            fadeOut: 0.22...0.29
        )
        let wavePosition = ((value - 0.07) / 0.15).mugshotClamped(to: 0...1)
        let blinkPosition = ((value - 0.09) / 0.075).mugshotClamped(to: 0...1)
        let blinkClosure = value >= 0.09 && value <= 0.165
            ? sin(blinkPosition * .pi)
            : 0

        return MugsyModelPresentation(
            waveLift: waveLift,
            waveSwing: sin(wavePosition * .pi * 2) * 10 * waveLift,
            limbRetraction: MugsyLogoTimeline.smoothStep(value, from: 0.27, to: 0.47),
            faceOpacity: 1 - MugsyLogoTimeline.smoothStep(value, from: 0.39, to: 0.56),
            eyeOpenness: 1 - blinkClosure * 0.94,
            ceramicOpacity: 1 - MugsyLogoTimeline.smoothStep(value, from: 0.55, to: 0.80)
        )
    }

    var body: some View {
        let value = normalizedProgress
        let simplification = MugsyLogoTimeline.smoothStep(value, from: 0.47, to: 0.80)
        let backdropProgress = MugsyLogoTimeline.smoothStep(value, from: 0.56, to: 0.84)
        let glyphProgress = MugsyLogoTimeline.smoothStep(value, from: 0.54, to: 0.80)
        let exactLogoOpacity = MugsyLogoTimeline.smoothStep(value, from: 0.86, to: 0.94)

        GeometryReader { proxy in
            let side = max(1, min(proxy.size.width, proxy.size.height))

            ZStack {
                MugshotLogoBackdrop(progress: backdropProgress)

                MugsyModelView(
                    configuration: MugsyModelConfiguration(
                        expression: .neutral,
                        armPose: .relaxed,
                        gaze: .center
                    ),
                    presentation: presentation
                )
                .scaleEffect(MugsyLogoTimeline.interpolate(from: 1, to: 0.68, progress: simplification))

                MugshotLogoGlyph()
                    .scaleEffect(MugsyLogoTimeline.interpolate(from: 1.08, to: 1, progress: glyphProgress))
                    .opacity(glyphProgress)

                Image("MugshotAppIcon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .opacity(exactLogoOpacity)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .clipped()
    }
}

private struct MugshotLogoBackdrop: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let side = max(1, min(proxy.size.width, proxy.size.height))

            RoundedRectangle(cornerRadius: side * 0.155, style: .continuous)
                .fill(MugshotLogoPalette.mint)
                .frame(width: side * 0.72, height: side * 0.703)
                .scaleEffect(MugsyLogoTimeline.interpolate(from: 0.78, to: 1, progress: progress))
                .opacity(progress)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

private struct MugshotLogoGlyph: View {
    var body: some View {
        ZStack {
            MugshotLogoHandleShape()
                .fill(MugshotLogoPalette.glyph, style: FillStyle(eoFill: true))

            MugshotLogoBodyShape()
                .fill(MugshotLogoPalette.glyph)

            MugshotLogoRimShape()
                .fill(MugshotLogoPalette.glyph)

            MugshotLogoRimInteriorShape()
                .fill(MugshotLogoPalette.mint)
        }
    }
}

private struct MugshotLogoBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(137, 173))
        path.addLine(to: rect.mugsyPoint(137, 310))
        path.addCurve(
            to: rect.mugsyPoint(183, 355),
            control1: rect.mugsyPoint(137, 335),
            control2: rect.mugsyPoint(157, 355)
        )
        path.addLine(to: rect.mugsyPoint(261, 355))
        path.addCurve(
            to: rect.mugsyPoint(307, 310),
            control1: rect.mugsyPoint(287, 355),
            control2: rect.mugsyPoint(307, 335)
        )
        path.addLine(to: rect.mugsyPoint(307, 173))
        path.closeSubpath()
        return path
    }
}

private struct MugshotLogoHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.mugsyPoint(306, 181))
        path.addLine(to: rect.mugsyPoint(319, 181))
        path.addCurve(
            to: rect.mugsyPoint(365, 226),
            control1: rect.mugsyPoint(345, 181),
            control2: rect.mugsyPoint(365, 201)
        )
        path.addLine(to: rect.mugsyPoint(365, 250))
        path.addCurve(
            to: rect.mugsyPoint(319, 296),
            control1: rect.mugsyPoint(365, 276),
            control2: rect.mugsyPoint(345, 296)
        )
        path.addLine(to: rect.mugsyPoint(306, 296))
        path.closeSubpath()

        path.move(to: rect.mugsyPoint(306, 201))
        path.addLine(to: rect.mugsyPoint(318, 201))
        path.addCurve(
            to: rect.mugsyPoint(345, 228),
            control1: rect.mugsyPoint(333, 201),
            control2: rect.mugsyPoint(345, 213)
        )
        path.addLine(to: rect.mugsyPoint(345, 249))
        path.addCurve(
            to: rect.mugsyPoint(318, 276),
            control1: rect.mugsyPoint(345, 264),
            control2: rect.mugsyPoint(333, 276)
        )
        path.addLine(to: rect.mugsyPoint(306, 276))
        path.closeSubpath()
        return path
    }
}

private struct MugshotLogoRimShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect.mugsyRect(x: 137, y: 146, width: 170, height: 55))
    }
}

private struct MugshotLogoRimInteriorShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect.mugsyRect(x: 151, y: 160, width: 141, height: 28))
    }
}

private enum MugshotLogoPalette {
    static let mint = Color(red: 148.0 / 255, green: 195.0 / 255, blue: 172.0 / 255)
    static let glyph = Color(red: 253.0 / 255, green: 254.0 / 255, blue: 249.0 / 255)
}

private enum MugsyLogoTimeline {
    static func smoothStep(_ value: CGFloat, from start: CGFloat, to end: CGFloat) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        let amount = ((value - start) / (end - start)).mugshotClamped(to: 0...1)
        return amount * amount * (3 - 2 * amount)
    }

    static func smoothWindow(
        _ value: CGFloat,
        fadeIn: ClosedRange<CGFloat>,
        fadeOut: ClosedRange<CGFloat>
    ) -> CGFloat {
        smoothStep(value, from: fadeIn.lowerBound, to: fadeIn.upperBound)
            * (1 - smoothStep(value, from: fadeOut.lowerBound, to: fadeOut.upperBound))
    }

    static func interpolate(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress.mugshotClamped(to: 0...1)
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

#Preview("Mugsy to logo") {
    MugsyLogoTransformationPreview()
        .padding(20)
        .background(Color.creamWhite)
}

private struct MugsyLogoTransformationPreview: View {
    @State private var target = MugsyLogoTransformationState.logo

    var body: some View {
        VStack(spacing: 18) {
            MugsyLogoTransformationView(target: target)
                .frame(width: 280, height: 280)

            Button(target == .logo ? "Transform to Mugsy" : "Transform to logo") {
                target = target.opposite
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
