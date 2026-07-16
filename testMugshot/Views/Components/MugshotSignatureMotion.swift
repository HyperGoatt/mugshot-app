import SwiftUI

struct MugshotPullProgressReader: View {
    let coordinateSpace: String
    var restingOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: MugshotPullDistancePreferenceKey.self,
                value: max(0, proxy.frame(in: .named(coordinateSpace)).minY - restingOffset)
            )
        }
        .frame(height: 0)
        .accessibilityHidden(true)
    }
}

struct MugshotPullDistancePreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MugshotSipProgressMug: View {
    let progress: CGFloat
    let drinkName: String
    let rating: Double
    var isSaving = false
    var isComplete = false

    private var action: MugsyActionState {
        if isComplete { return .success }
        if isSaving { return .saving }
        return .composing(progress: progress)
    }

    private var configuration: MugsyModelConfiguration {
        MugsyModelConfiguration(
            expression: .neutral,
            gaze: .center,
            liquid: MugsyLiquidState(
                appearance: .infer(from: drinkName),
                fillProgress: 0.16,
                steamIntensity: progress > 0.48 ? CGFloat(0.26 + min(rating / 5, 1) * 0.64) : 0.08
            )
        )
    }

    var body: some View {
        MugsyAnimatedView(configuration: configuration, action: action)
        .accessibilityLabel("Sip log \(Int((progress * 100).rounded())) percent complete")
    }
}

struct MugshotPullRefreshIndicator: View {
    let progress: CGFloat
    var isRefreshing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var reduceMotionOverride

    private var normalizedProgress: CGFloat { MugshotMotion.normalized(progress) }
    private var isVisible: Bool {
        MugsyRefreshPresentation.shouldRender(
            progress: normalizedProgress,
            isRefreshing: isRefreshing
        )
    }
    private var revealProgress: CGFloat {
        isRefreshing ? 1 : MugshotMotion.normalized((normalizedProgress - 0.025) / 0.16)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if isVisible {
                MugshotCoffeePourStream(
                    progress: normalizedProgress,
                    isRefreshing: isRefreshing
                )

                MugsyAnimatedView(
                    action: isRefreshing ? .refreshing : .pulling(progress: normalizedProgress),
                    isPaused: !isRefreshing
                )
                .frame(width: 96, height: 108)
                .offset(y: 34)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 144, alignment: .top)
        .scaleEffect((reduceMotionOverride ?? reduceMotion) ? 1 : 0.92 + revealProgress * 0.08, anchor: .top)
        .opacity(isVisible ? revealProgress : 0)
        .animation(.easeOut(duration: 0.14), value: isVisible)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            MugsyRefreshPresentation.accessibilityLabel(
                progress: normalizedProgress,
                isRefreshing: isRefreshing
            )
        )
    }

}

private struct MugshotCoffeePourStream: View {
    let progress: CGFloat
    let isRefreshing: Bool

    private var pourProgress: CGFloat {
        MugshotMotion.normalized((progress - 0.08) / 0.92)
    }

    private var streamProgress: CGFloat {
        MugshotMotion.normalized((pourProgress - 0.42) / 0.58)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(MugshotDrinkAppearance.coffee.liquidColor)
                .frame(width: 5, height: max(3, 45 * streamProgress))
                .opacity(streamProgress)

            Circle()
                .fill(MugshotDrinkAppearance.coffee.liquidColor)
                .frame(width: 9, height: 9)
                .scaleEffect(0.72 + pourProgress * 0.28)
                .offset(y: 3 + pourProgress * 39)

            Circle()
                .fill(MugshotDrinkAppearance.coffee.liquidColor.opacity(0.88))
                .frame(width: 5, height: 5)
                .offset(x: 5, y: max(0, pourProgress * 28 - 4))
                .opacity(MugshotMotion.normalized((pourProgress - 0.18) / 0.28) * (1 - streamProgress))
        }
        .frame(width: 22, height: 50, alignment: .top)
        .opacity(isRefreshing ? 0 : pourProgress)
        .animation(.easeOut(duration: 0.16), value: isRefreshing)
        .accessibilityHidden(true)
    }
}

struct TasteBloomSample: Identifiable, Equatable {
    let label: String
    let value: Double
    let support: Int

    var id: String { label }
}

struct MugshotTasteBloom: View {
    let samples: [TasteBloomSample]
    let confidence: Double
    var size: CGFloat = 108

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var reduceMotionOverride
    @State private var reveal: CGFloat = 0

    private var displaySamples: [TasteBloomSample] {
        if samples.isEmpty {
            return [
                TasteBloomSample(label: "Taste forming", value: 0.28, support: 0),
                TasteBloomSample(label: "Ritual forming", value: 0.22, support: 0),
                TasteBloomSample(label: "Places forming", value: 0.25, support: 0),
                TasteBloomSample(label: "Lens forming", value: 0.20, support: 0),
                TasteBloomSample(label: "Memory forming", value: 0.24, support: 0)
            ]
        }
        return Array(samples.prefix(8))
    }

    var body: some View {
        ZStack {
            ForEach(1...3, id: \.self) { ring in
                Circle()
                    .stroke(Color.mugshotSage.opacity(0.10), lineWidth: 1)
                    .frame(width: size * CGFloat(ring) / 3, height: size * CGFloat(ring) / 3)
            }

            TasteBloomShape(values: displaySamples.map(\.value), reveal: reveal)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.mugshotMint.opacity(0.86),
                            Color.mugshotSage.opacity(0.46),
                            Color.mugshotLatte.opacity(0.34)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: size * 0.58
                    )
                )
                .overlay {
                    TasteBloomShape(values: displaySamples.map(\.value), reveal: reveal)
                        .stroke(Color.mugshotSage.opacity(0.75), lineWidth: 1.4)
                }

            Circle()
                .fill(Color.foamWhite)
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.mugshotSage)
                }
                .shadow(color: Color.espressoBrown.opacity(0.10), radius: 4, y: 2)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(MugshotMotion.animation(.easeOut(duration: 0.72), reduceMotion: reduceMotionOverride ?? reduceMotion)) {
                reveal = 1
            }
        }
        .onChange(of: displaySamples) { _, _ in
            reveal = (reduceMotionOverride ?? reduceMotion) ? 1 : 0.76
            withAnimation(MugshotMotion.animation(MugshotMotion.settle, reduceMotion: reduceMotionOverride ?? reduceMotion)) {
                reveal = 1
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let evidence = Int((MugshotMotion.normalized(confidence) * 100).rounded())
        let labels = displaySamples.prefix(4).map(\.label).joined(separator: ", ")
        return "Taste Bloom. \(labels). Evidence confidence \(evidence) percent."
    }
}

private struct TasteBloomShape: Shape {
    let values: [Double]
    var reveal: CGFloat

    var animatableData: CGFloat {
        get { reveal }
        set { reveal = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard values.count >= 3 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) * 0.47
        var points: [CGPoint] = []
        for (index, rawValue) in values.enumerated() {
            let angle = -Double.pi / 2 + Double(index) / Double(values.count) * Double.pi * 2
            let normalizedValue = MugshotMotion.normalized(rawValue)
            let radiusFactor = CGFloat(0.30 + normalizedValue * 0.70)
            let radius = maxRadius * radiusFactor * reveal
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius
            points.append(CGPoint(x: x, y: y))
        }

        var path = Path()
        let firstMidpoint = midpoint(points.last!, points[0])
        path.move(to: firstMidpoint)
        for index in points.indices {
            let point = points[index]
            let next = points[(index + 1) % points.count]
            path.addQuadCurve(to: midpoint(point, next), control: point)
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}

enum MugshotRitualTone: Equatable {
    case new
    case warm
    case yesterday
    case returning
    case milestone(Int)
}

struct MugshotRitualSnapshot: Equatable {
    let consecutiveDays: Int
    let totalDays: Int
    let tone: MugshotRitualTone

    static func make(
        dates: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MugshotRitualSnapshot {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else {
            return MugshotRitualSnapshot(consecutiveDays: 0, totalDays: 0, tone: .new)
        }

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let anchor: Date?
        if days.contains(today) {
            anchor = today
        } else if days.contains(yesterday) {
            anchor = yesterday
        } else {
            anchor = nil
        }

        var count = 0
        if var cursor = anchor {
            while days.contains(cursor) {
                count += 1
                guard let prior = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prior
            }
        }

        let milestones = [100, 50, 30, 14, 7, 3]
        let tone: MugshotRitualTone
        if let milestone = milestones.first(where: { count == $0 && days.contains(today) }) {
            tone = .milestone(milestone)
        } else if days.contains(today) {
            tone = .warm
        } else if days.contains(yesterday) {
            tone = .yesterday
        } else {
            tone = .returning
        }

        return MugshotRitualSnapshot(consecutiveDays: count, totalDays: days.count, tone: tone)
    }
}

struct MugshotRitualCard: View {
    let dates: [Date]
    var now = Date()

    private var snapshot: MugshotRitualSnapshot {
        MugshotRitualSnapshot.make(dates: dates, now: now)
    }

    var body: some View {
        HStack(spacing: 14) {
            MugsyAnimatedView(
                configuration: MugsyModelConfiguration(
                    expression: expression,
                    prop: .journalNotebook,
                    outfit: .cozyRitual,
                    liquid: MugsyLiquidState(
                        appearance: .chai,
                        fillProgress: snapshot.consecutiveDays == 0 ? 0.28 : 0.72,
                        steamIntensity: snapshot.consecutiveDays == 0 ? 0.14 : 0.62
                    )
                ),
                action: isMilestone ? .celebrating : .resting,
                tapBehavior: isMilestone ? .playfulCycle : .wave
            )
            .frame(width: 68, height: 78)

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(.mugshotSage)
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(.espressoBrown)
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if snapshot.consecutiveDays > 0 {
                Text("\(snapshot.consecutiveDays)")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundColor(.espressoBrown)
                    .monospacedDigit()
                    .accessibilityLabel("\(snapshot.consecutiveDays) consecutive days")
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.mugshotLatte.opacity(0.28), Color.foamWhite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var isMilestone: Bool {
        if case .milestone = snapshot.tone { return true }
        return false
    }

    private var expression: MugsyExpression {
        switch snapshot.tone {
        case .milestone: return .delighted
        case .warm, .yesterday: return .neutral
        case .returning, .new: return .curious
        }
    }

    private var eyebrow: String {
        switch snapshot.tone {
        case .milestone: return "Ritual milestone"
        case .returning: return "Welcome back"
        default: return "Your ritual"
        }
    }

    private var title: String {
        switch snapshot.tone {
        case .new: return "A seat is ready"
        case .warm: return snapshot.consecutiveDays == 1 ? "Today joined the story" : "The table is warm"
        case .yesterday: return "Yesterday still counts"
        case .returning: return "Every return belongs"
        case .milestone(let days): return "\(days) days at the table"
        }
    }

    private var message: String {
        switch snapshot.tone {
        case .new: return "Your first sip can begin whenever it feels right."
        case .warm: return "A gentle record of showing up, never a debt to repay."
        case .yesterday: return "Your ritual can rest. The memories do not disappear."
        case .returning: return "Nothing was lost. This sip simply starts the next chapter."
        case .milestone: return "A lot of small moments became a meaningful collection."
        }
    }
}

#Preview("Signature motion") {
    ScrollView {
        VStack(spacing: 24) {
            MugshotSipProgressMug(progress: 0.72, drinkName: "Iced matcha", rating: 4.5)
                .frame(width: 120, height: 136)
            MugshotTasteBloom(
                samples: [
                    TasteBloomSample(label: "Milk drinks", value: 0.84, support: 8),
                    TasteBloomSample(label: "Cold drinks", value: 0.72, support: 6),
                    TasteBloomSample(label: "Bean clarity", value: 0.58, support: 4),
                    TasteBloomSample(label: "Cafe ritual", value: 0.66, support: 7),
                    TasteBloomSample(label: "Home brews", value: 0.42, support: 3)
                ],
                confidence: 0.71,
                size: 160
            )
            MugshotRitualCard(dates: (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) })
        }
        .padding()
    }
    .background(Color.creamWhite)
}
