import SwiftUI

struct JournalReflectionsSection: View {
    let entries: [JournalEntryProjection]
    let onSelect: (JournalReflectionSummary) -> Void

    private var monthly: JournalReflectionSummary {
        JournalReflectionEngine.summary(for: .month, entries: entries)
    }

    private var yearly: JournalReflectionSummary {
        JournalReflectionEngine.summary(for: .year, entries: entries)
    }

    private var milestones: [JournalMilestone] {
        JournalReflectionEngine.milestones(entries: entries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Reflections")
                    .mugshotDisplay(size: 28)
                    .foregroundColor(.espressoBrown)
                Text("Memory and learning—not a consumption scorecard.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    reflectionCard(monthly)
                    reflectionCard(yearly)
                }
                .padding(.horizontal, 16)
            }

            if let milestone = milestones.first {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestone.title)
                            .font(.system(size: 14, weight: .bold))
                        Text(milestone.detail)
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                } icon: {
                    Image(systemName: milestone.systemImage)
                        .foregroundColor(.mugshotSage)
                }
                .foregroundColor(.espressoBrown)
                .padding(14)
                .cardStyle()
                .padding(.horizontal, 16)
            }
        }
    }

    private func reflectionCard(_ reflection: JournalReflectionSummary) -> some View {
        Button { onSelect(reflection) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(reflection.period.title.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.mugshotSage)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.tertiaryText)
                }
                Text(reflection.headline)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(3)
                HStack(spacing: 12) {
                    Label("\(reflection.entryCount) sips", systemImage: "cup.and.saucer.fill")
                    if reflection.cafeCount > 0 {
                        Label("\(reflection.cafeCount) cafes", systemImage: "mappin.circle.fill")
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondaryText)
            }
            .frame(width: 240, height: 126, alignment: .topLeading)
            .padding(15)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(reflection.period.title) reflection, \(reflection.entryCount) sips")
    }
}

struct JournalReflectionDetailView: View {
    let reflection: JournalReflectionSummary
    let milestones: [JournalMilestone]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    memoryHighlights
                    if let caffeine = reflection.caffeine {
                        caffeinePanel(caffeine)
                    }
                    if !milestones.isEmpty {
                        milestonePanel
                    }
                    Text("Your reflection is built from your journal. It stays useful even when you take a break from logging.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(Color.creamWhite)
            .navigationTitle(reflection.period == .month ? "Monthly reflection" : "Yearly reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(reflection.startDate.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.mugshotSage)
            Text(reflection.headline)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundColor(.espressoBrown)
            if let average = reflection.averageRating {
                Text("Your journal average was \(average.formatted(.number.precision(.fractionLength(1)))) stars.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
            }
            if let change = reflection.ratingChange, abs(change) >= 0.1 {
                Text(change > 0
                     ? "You rated sips a little more generously than the previous \(reflection.period.rawValue)."
                     : "Your ratings became a little more selective than the previous \(reflection.period.rawValue).")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.mugshotSage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.sandBeige.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
    }

    private var memoryHighlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your coffee story")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.espressoBrown)
            reflectionRow("Sips remembered", "\(reflection.entryCount)", "cup.and.saucer.fill")
            reflectionRow("Cafes explored", "\(reflection.cafeCount)", "map.fill")
            reflectionRow("Home experiments", "\(reflection.homeExperimentCount)", "house.fill")
            reflectionRow("Recipes practiced", "\(reflection.recipeCount)", "book.pages.fill")
            reflectionRow("Meaningful memories", "\(reflection.meaningfulMemoryCount)", "heart.text.square.fill")
            if let favoriteCafe = reflection.favoriteCafe {
                reflectionRow("Favorite cafe", favoriteCafe, "sparkles")
            }
            if !reflection.neighborhoods.isEmpty {
                reflectionRow("Places explored", reflection.neighborhoods.joined(separator: " · "), "mappin.and.ellipse")
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func caffeinePanel(_ caffeine: JournalCaffeineEstimate) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Deep journal data")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.espressoBrown)
            Text("About \(caffeine.roundedTotal) mg estimated caffeine")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.espressoBrown)
            Text(caffeine.coverageText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.mugshotSage)
            Text("Calculated from traditional preparation averages (\(caffeine.referenceVersions.joined(separator: ", "))) using parser \(caffeine.parserVersions.joined(separator: ", ")). Unknown drinks are excluded. This is a personal journal estimate, not medical guidance.")
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
        }
        .padding(16)
        .cardStyle()
    }

    private var milestonePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal milestones")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.espressoBrown)
            ForEach(milestones) { milestone in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestone.title).font(.system(size: 14, weight: .bold))
                        Text(milestone.detail).font(.system(size: 12)).foregroundColor(.secondaryText)
                    }
                } icon: {
                    Image(systemName: milestone.systemImage).foregroundColor(.mugshotSage)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func reflectionRow(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.mugshotSage)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.espressoBrown)
                .multilineTextAlignment(.trailing)
        }
    }
}
