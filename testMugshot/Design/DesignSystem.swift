//
//  DesignSystem.swift
//  testMugshot
//
//  Created by Joseph Rosso on 11/14/25.
//

import SwiftUI

// Native translation of the Claude Design Mugshot handoff.
struct DesignSystem {
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 8
        static let control: CGFloat = 12
        static let card: CGFloat = 16
        static let heroCard: CGFloat = 20
        static let sheet: CGFloat = 24
        static let pill: CGFloat = 999
    }

    enum Motion {
        static let fast = Animation.easeOut(duration: 0.15)
        static let base = Animation.easeOut(duration: 0.20)
        static let slow = Animation.easeOut(duration: 0.25)
        static let pressScale: CGFloat = 0.98
    }

    // Legacy aliases used throughout the existing app.
    static let cornerRadius: CGFloat = Radius.control
    static let smallCornerRadius: CGFloat = Radius.small
    static let largeCornerRadius: CGFloat = Radius.card
    static let padding: CGFloat = Space.md
    static let smallPadding: CGFloat = Space.xs
    static let largePadding: CGFloat = Space.xl

    static let cardShadow = Shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    static let subtleShadow = Shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    static let overlayShadow = Shadow(color: .black.opacity(0.12), radius: 30, x: 0, y: 12)
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

struct MugshotDisplayText: ViewModifier {
    let size: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .regular, design: .serif))
            .tracking(-0.2)
    }
}

struct CardStyle: ViewModifier {
    var radius: CGFloat = DesignSystem.Radius.card
    var shadow: DesignSystem.Shadow = DesignSystem.cardShadow

    func body(content: Content) -> some View {
        content
            .background(Color.foamWhite)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
}

struct MugshotGlassSurfaceStyle: ViewModifier {
    var radius: CGFloat = DesignSystem.Radius.card
    var tint: Color = .foamWhite
    var stroke: Color = Color.foamWhite.opacity(0.42)
    var shadow: DesignSystem.Shadow = DesignSystem.cardShadow
    var interactive = false

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if #available(iOS 26.0, *) {
            if interactive {
                content
                    .background(tint.opacity(0.24), in: shape)
                    .glassEffect(.regular.tint(tint.opacity(0.18)).interactive(), in: .rect(cornerRadius: radius))
                    .overlay(shape.stroke(stroke, lineWidth: 1))
                    .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
            } else {
                content
                    .background(tint.opacity(0.24), in: shape)
                    .glassEffect(.regular.tint(tint.opacity(0.18)), in: .rect(cornerRadius: radius))
                    .overlay(shape.stroke(stroke, lineWidth: 1))
                    .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
            }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(tint.opacity(0.18), in: shape)
                .overlay(shape.stroke(Color.mugshotLine.opacity(0.82), lineWidth: 1))
                .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
        }
    }
}

struct MugshotGlassCircleStyle: ViewModifier {
    var tint: Color = .mugshotSage
    var stroke: Color = Color.foamWhite.opacity(0.54)
    var shadow: DesignSystem.Shadow = DesignSystem.cardShadow
    var interactive = true

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                content
                    .background(tint.opacity(0.34), in: Circle())
                    .glassEffect(.regular.tint(tint.opacity(0.34)).interactive(), in: .circle)
                    .overlay(Circle().stroke(stroke, lineWidth: 1))
                    .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
            } else {
                content
                    .background(tint.opacity(0.34), in: Circle())
                    .glassEffect(.regular.tint(tint.opacity(0.34)), in: .circle)
                    .overlay(Circle().stroke(stroke, lineWidth: 1))
                    .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
            }
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .background(tint.opacity(0.82), in: Circle())
                .overlay(Circle().stroke(stroke, lineWidth: 1))
                .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
        }
    }
}

extension View {
    func mugshotDisplay(size: CGFloat) -> some View {
        modifier(MugshotDisplayText(size: size))
    }

    func cardStyle(
        radius: CGFloat = DesignSystem.Radius.card,
        shadow: DesignSystem.Shadow = DesignSystem.cardShadow
    ) -> some View {
        modifier(CardStyle(radius: radius, shadow: shadow))
    }

    func mugshotGlassSurface(
        radius: CGFloat = DesignSystem.Radius.card,
        tint: Color = .foamWhite,
        stroke: Color = Color.foamWhite.opacity(0.42),
        shadow: DesignSystem.Shadow = DesignSystem.cardShadow,
        interactive: Bool = false
    ) -> some View {
        modifier(MugshotGlassSurfaceStyle(
            radius: radius,
            tint: tint,
            stroke: stroke,
            shadow: shadow,
            interactive: interactive
        ))
    }

    func mugshotGlassCircle(
        tint: Color = .mugshotSage,
        stroke: Color = Color.foamWhite.opacity(0.54),
        shadow: DesignSystem.Shadow = DesignSystem.cardShadow,
        interactive: Bool = true
    ) -> some View {
        modifier(MugshotGlassCircleStyle(
            tint: tint,
            stroke: stroke,
            shadow: shadow,
            interactive: interactive
        ))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, DesignSystem.largePadding)
            .padding(.vertical, 13)
            .background(configuration.isPressed ? Color.mugshotSage.opacity(0.92) : Color.mugshotSage)
            .foregroundColor(Color.foamWhite)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? DesignSystem.Motion.pressScale : 1.0)
            .animation(DesignSystem.Motion.fast, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, DesignSystem.largePadding)
            .padding(.vertical, 12)
            .background(configuration.isPressed ? Color.sandBeige : Color.foamWhite)
            .foregroundColor(Color.espressoBrown)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.mugshotLine, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? DesignSystem.Motion.pressScale : 1.0)
            .animation(DesignSystem.Motion.fast, value: configuration.isPressed)
    }
}

struct MugshotIconButton: View {
    let systemName: String
    var size: CGFloat = 38
    var isActive = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isActive ? .foamWhite : .espressoBrown)
                .frame(width: size, height: size)
                .background(isActive ? Color.mugshotSage : Color.foamWhite)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.mugshotLine, lineWidth: isActive ? 0 : 1)
                )
                .shadow(
                    color: DesignSystem.subtleShadow.color,
                    radius: DesignSystem.subtleShadow.radius,
                    x: DesignSystem.subtleShadow.x,
                    y: DesignSystem.subtleShadow.y
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName)
    }
}

struct MugshotScreenHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .mugshotDisplay(size: 30)
                    .foregroundColor(.espressoBrown)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.tertiaryText)
                }
            }

            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, DesignSystem.Space.md)
        .padding(.top, DesignSystem.Space.sm)
        .padding(.bottom, DesignSystem.Space.xs)
    }
}

struct MugshotSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var icon: ((Option) -> String?)? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(DesignSystem.Motion.base) {
                        selection = option
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let iconName = icon?(option) {
                            Image(systemName: iconName)
                                .font(.system(size: 12, weight: .semibold))
                        }

                        Text(title(option))
                            .font(.system(size: 13, weight: selection == option ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)
                    }
                    .foregroundColor(selection == option ? .espressoBrown : .roastBrown.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(selection == option ? Color.foamWhite : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.sandBeige.opacity(0.78))
        .clipShape(Capsule())
    }
}

struct MugshotStatPill: View {
    let icon: String
    let value: String
    let label: String
    var accent = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(value)
                .font(.system(size: 13, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(accent ? .foamWhite.opacity(0.86) : .tertiaryText)
        }
        .foregroundColor(accent ? .foamWhite : .espressoBrown)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(accent ? Color.mugshotSage : Color.foamWhite)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(accent ? Color.clear : Color.mugshotLine, lineWidth: 1)
        )
        .shadow(
            color: DesignSystem.subtleShadow.color,
            radius: DesignSystem.subtleShadow.radius,
            x: DesignSystem.subtleShadow.x,
            y: DesignSystem.subtleShadow.y
        )
    }
}

struct MugshotTagChip: View {
    let title: String
    var icon: String?
    var isActive = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.roastBrown)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(isActive ? Color.mugshotMint.opacity(0.34) : Color.sandBeige.opacity(0.55))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isActive ? Color.mugshotSage.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }
}

struct MugshotRatingBadge: View {
    let score: Double
    var onPhoto = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(String(format: "%.1f", score))
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(onPhoto ? .creamWhite : .espressoBrown)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(onPhoto ? Color.espressoBrown.opacity(0.72) : Color.mugshotMint.opacity(0.38))
        .clipShape(Capsule())
    }
}

struct MugshotAvatar: View {
    let name: String
    var size: CGFloat = 36

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "U").uppercased()
    }

    var body: some View {
        Circle()
            .fill(Color.mugshotMint)
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: max(12, size * 0.42), weight: .semibold))
                    .foregroundColor(.espressoBrown)
            )
    }
}

struct MugshotSectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.espressoBrown)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MugshotActionTile: View {
    let title: String
    let systemImage: String
    var isSelected = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? Color.mugshotMint.opacity(0.34) : Color.sandBeige.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                        .stroke(isSelected ? Color.mugshotSage.opacity(0.72) : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

struct MugshotStatusCard: View {
    let title: String
    let message: String
    let systemImage: String
    var tone: Color = .mugshotSage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(tone)
                .frame(width: 34, height: 34)
                .background(tone.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.foamWhite)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .stroke(Color.mugshotLine, lineWidth: 1)
        )
    }
}

struct MugshotSheetContainer<Content: View>: View {
    let maxHeightFraction: CGFloat
    @ViewBuilder var content: Content

    init(maxHeightFraction: CGFloat = 0.78, @ViewBuilder content: () -> Content) {
        self.maxHeightFraction = maxHeightFraction
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.espressoBrown.opacity(0.2))
                .frame(width: 52, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)

            content
        }
        .background(Color.creamWhite)
        .clipShape(RoundedCorner(radius: DesignSystem.Radius.sheet, corners: [.topLeft, .topRight]))
        .shadow(
            color: DesignSystem.overlayShadow.color,
            radius: DesignSystem.overlayShadow.radius,
            x: DesignSystem.overlayShadow.x,
            y: DesignSystem.overlayShadow.y
        )
        .frame(maxHeight: UIScreen.main.bounds.height * maxHeightFraction)
    }
}

struct MugshotFormFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(.inputText)
            .tint(.mugshotSage)
            .padding(13)
            .background(Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous)
                    .stroke(Color.inputBorder, lineWidth: 1)
            )
    }
}

extension View {
    func mugshotFormField() -> some View {
        modifier(MugshotFormFieldStyle())
    }

    func mugshotSunkenPanel(radius: CGFloat = DesignSystem.Radius.card) -> some View {
        background(Color.sandBeige.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Custom text field style for Mugshot
struct MugshotTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.inputText)
            .tint(.mugshotSage)
    }
}

extension TextField {
    func mugshotStyle() -> some View {
        self
            .foregroundColor(.inputText)
            .tint(.mugshotSage)
            .accentColor(.mugshotSage)
    }
}
