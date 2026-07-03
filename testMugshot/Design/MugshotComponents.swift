//
//  MugshotComponents.swift
//  testMugshot
//
//  Reusable design-system primitives shared across every tab:
//  screen headers, segmented pills, chips, score badges, section
//  headers, and loading/error state views.
//

import SwiftUI

// MARK: - Screen Header

/// Large warm screen title with optional subtitle and trailing accessory,
/// used at the top of Feed, Saved, and other tab roots.
struct MugScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    let trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.espressoBrown)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.espressoBrown.opacity(0.65))
                }
            }

            Spacer(minLength: 8)

            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension MugScreenHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

/// Round tappable icon used as a header accessory (search, filter, share).
struct MugIconButton: View {
    let systemImage: String
    var accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.espressoBrown)
                .frame(width: 44, height: 44)
                .background(Color.creamWhite)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.sandBeige.opacity(0.8), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Segmented Pill Control

/// Design-system segmented control: a sand track with a floating cream pill
/// for the selected segment. Generic over any hashable option set.
struct MugSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    var icon: ((Option) -> String?)? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = option
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let iconName = icon?(option) {
                            Image(systemName: iconName)
                                .font(.system(size: 12, weight: .semibold))
                        }

                        Text(label(option))
                            .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundColor(isSelected ? .espressoBrown : .espressoBrown.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 17)
                                    .fill(Color.creamWhite)
                                    .shadow(color: Color.espressoBrown.opacity(0.08), radius: 4, x: 0, y: 1)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Color.sandBeige.opacity(0.5))
        .cornerRadius(21)
    }
}

// MARK: - Chips

/// Filter chip: pill with optional icon. Selected state fills deep forest.
struct MugFilterChip: View {
    let title: String
    var systemImage: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .creamWhite : .espressoBrown.opacity(0.75))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(isSelected ? Color.mugshotForest : Color.creamWhite)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.sandBeige.opacity(0.9), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Soft sage tag pill ("cozy", "matcha favorite", "would order again").
struct MugTagChip: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.mugshotForest)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.mugshotSageSoft)
        .clipShape(Capsule())
    }
}

// MARK: - Score Badge

/// Star + score pill in the design-system style (forest star on soft sage).
struct MugScoreBadge: View {
    let score: Double
    var size: BadgeSize = .regular

    enum BadgeSize {
        case compact
        case regular

        var starSize: CGFloat { self == .compact ? 10 : 12 }
        var textSize: CGFloat { self == .compact ? 12 : 14 }
        var hPadding: CGFloat { self == .compact ? 8 : 10 }
        var vPadding: CGFloat { self == .compact ? 4 : 6 }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: size.starSize, weight: .semibold))
                .foregroundColor(.mugshotForest)

            Text(String(format: "%.1f", score))
                .font(.system(size: size.textSize, weight: .bold))
                .foregroundColor(.espressoBrown)
        }
        .padding(.horizontal, size.hPadding)
        .padding(.vertical, size.vPadding)
        .background(Color.mugshotSageSoft)
        .clipShape(Capsule())
        .accessibilityLabel(String(format: "Rated %.1f out of 5", score))
    }
}

// MARK: - Section Header

/// "Top drinks    See all >" style section header used inside screens.
struct MugSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.espressoBrown)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionTitle)
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.mugshotForest)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Avatar

/// Circular initial avatar in brand colors, used for authors and friends.
struct MugAvatarView: View {
    let name: String
    var diameter: CGFloat = 40

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }

    var body: some View {
        Circle()
            .fill(Color.mugshotSageSoft)
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(initial.isEmpty ? "?" : initial)
                    .font(.system(size: diameter * 0.42, weight: .semibold))
                    .foregroundColor(.mugshotForest)
            )
            .overlay(Circle().stroke(Color.sandBeige.opacity(0.7), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

// MARK: - State Views

/// Consistent inline loading state.
struct MugLoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.mugshotForest)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.espressoBrown.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

/// Consistent inline error card with retry.
struct MugErrorStateView: View {
    let title: String
    let message: String
    var retryTitle: String = "Try Again"
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.4))
                .frame(width: 56, height: 56)
                .background(Color.sandBeige.opacity(0.5))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.espressoBrown)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.espressoBrown.opacity(0.64))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let onRetry {
                Button(action: onRetry) {
                    Text(retryTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.creamWhite)
                        .padding(.horizontal, 22)
                        .frame(height: 40)
                        .background(Color.mugshotForest)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .cardStyle()
    }
}

// MARK: - Stat Tile

/// Compact stat tile for profile stats and cafe details.
struct MugStatTile: View {
    let value: String
    let title: String
    var systemImage: String? = nil

    var body: some View {
        VStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.mugshotForest)
            }

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.espressoBrown)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.espressoBrown.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(Color.creamWhite)
        .cornerRadius(DesignSystem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .stroke(Color.sandBeige.opacity(0.7), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Taste Category Bar

/// Horizontal progress bar row for the taste identity card
/// ("Matcha 48%" with a sage bar), per the design system.
struct MugTasteCategoryRow: View {
    let name: String
    let systemImage: String
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(name, systemImage: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)

                Spacer()

                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.espressoBrown)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.sandBeige.opacity(0.55))

                    Capsule()
                        .fill(Color.mugshotForest.opacity(0.75))
                        .frame(width: max(6, proxy.size.width * fraction))
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(Int((fraction * 100).rounded())) percent of your sips")
    }
}
