import SwiftUI
import UIKit

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

    private var yearCurrentlyMatchesMonth: Bool {
        monthly.entryCount > 0 && monthly.entryCount == yearly.entryCount
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
                    reflectionCard(monthly, matchesCurrentMonth: false)
                    reflectionCard(yearly, matchesCurrentMonth: yearCurrentlyMatchesMonth)
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

    private func reflectionCard(
        _ reflection: JournalReflectionSummary,
        matchesCurrentMonth: Bool
    ) -> some View {
        Button { onSelect(reflection) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reflection.period.title.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(.mugshotSage)
                        Text(periodRange(reflection))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.tertiaryText)
                    }
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
                if matchesCurrentMonth {
                    Text("All of this year’s sips are from this month so far.")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.mugshotSage)
                        .lineLimit(2)
                }
            }
            .frame(width: 250, height: 154, alignment: .topLeading)
            .padding(15)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(reflection.period.title) reflection, \(reflection.entryCount) sips")
    }

    private func periodRange(_ reflection: JournalReflectionSummary) -> String {
        if reflection.period == .month {
            return reflection.startDate.formatted(.dateTime.month(.wide).year())
        }
        let effectiveEnd = min(Date(), reflection.endDate.addingTimeInterval(-1))
        let start = reflection.startDate.formatted(.dateTime.month(.abbreviated))
        let end = effectiveEnd.formatted(.dateTime.month(.abbreviated).year())
        return "\(start)–\(end)"
    }
}

struct JournalReflectionDetailView: View {
    let reflection: JournalReflectionSummary
    let entries: [JournalEntryProjection]
    let milestones: [JournalMilestone]
    @Environment(\.dismiss) private var dismiss
    @State private var shareItems: [Any] = []
    @State private var showsShareSheet = false

    private var periodEntries: [JournalEntryProjection] {
        entries
            .filter { $0.date >= reflection.startDate && $0.date < reflection.endDate }
            .sorted { $0.date < $1.date }
    }

    private var photoEntries: [JournalEntryProjection] {
        Array(periodEntries.filter { $0.summary.visit.posterPhotoURL?.remoteTrimmedNonEmpty != nil }.prefix(10))
    }

    private var activeDayCount: Int {
        Set(periodEntries.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    if !photoEntries.isEmpty {
                        photoStory
                    }
                    rhythmPanel
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
            .sheet(isPresented: $showsShareSheet) {
                JournalReflectionActivityView(activityItems: shareItems)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(periodLabel)
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

            Button {
                prepareShare()
            } label: {
                Label("Share this reflection", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.foamWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.mugshotSage, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(reflection.entryCount == 0)
            .accessibilityHint("Creates a Mugshot recap card without private notes")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.sandBeige.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard, style: .continuous))
    }

    private var photoStory: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("The moments")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.espressoBrown)
                Spacer()
                Text("\(reflection.photoCount) \(reflection.photoCount == 1 ? "photo" : "photos")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.mugshotSage)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 9) {
                    ForEach(photoEntries) { entry in
                        RemotePhotoImageView(
                            urlString: entry.summary.visit.posterPhotoURL,
                            placeholderSystemName: "cup.and.saucer.fill",
                            contentMode: .fill
                        )
                        .frame(width: 126, height: 164)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.summary.visit.drinkDisplayName)
                                    .font(.system(size: 11, weight: .bold))
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundColor(.foamWhite)
                            .lineLimit(1)
                            .padding(9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.black.opacity(0.48))
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(entry.summary.visit.drinkDisplayName) on \(entry.date.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var rhythmPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("The rhythm", systemImage: "waveform.path.ecg")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.mugshotSage)
            Text(rhythmHeadline)
                .font(.system(size: 21, weight: .bold, design: .serif))
                .foregroundColor(.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)
            Text(rhythmDetail)
                .font(.system(size: 13))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mugshotMint.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous))
    }

    private var rhythmHeadline: String {
        guard reflection.entryCount > 0 else { return "This chapter is ready when you are" }
        if reflection.cafeCount > 0, reflection.homeExperimentCount > 0 {
            return "Coffee moved between familiar counters and your own setup."
        }
        if reflection.cafeCount > 0 {
            return "Your coffee story unfolded out in the neighborhood."
        }
        return "This was a chapter of making, tuning, and remembering at home."
    }

    private var periodLabel: String {
        reflection.period == .month
            ? reflection.startDate.formatted(.dateTime.month(.wide).year())
            : reflection.startDate.formatted(.dateTime.year())
    }

    private var rhythmDetail: String {
        guard reflection.entryCount > 0 else {
            return "A future sip can start the story without creating a logging streak to maintain."
        }
        var parts = ["You remembered coffee on \(activeDayCount) \(activeDayCount == 1 ? "day" : "days") during this \(reflection.period.rawValue)."]
        if let favoriteDrink = reflection.favoriteDrink {
            parts.append("\(favoriteDrink) was the drink that returned most often.")
        }
        if let change = reflection.ratingChange, abs(change) >= 0.1 {
            parts.append(change > 0
                ? "Ratings felt a little more generous than the previous \(reflection.period.rawValue)."
                : "Ratings became a little more selective than the previous \(reflection.period.rawValue).")
        }
        return parts.joined(separator: " ")
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

    @MainActor
    private func prepareShare() {
        let card = JournalReflectionShareCard(reflection: reflection)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        let caption = "My \(periodLabel) coffee reflection in Mugshot: \(reflection.headline)."
        if let image = renderer.uiImage {
            shareItems = [image, caption]
        } else {
            shareItems = [caption]
        }
        showsShareSheet = true
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

private struct JournalReflectionShareCard: View {
    let reflection: JournalReflectionSummary

    var body: some View {
        ZStack {
            Color.creamWhite

            Circle()
                .fill(Color.mugshotMint.opacity(0.75))
                .frame(width: 340, height: 340)
                .offset(x: 220, y: -285)

            Circle()
                .fill(Color.sandBeige.opacity(0.72))
                .frame(width: 300, height: 300)
                .offset(x: -235, y: 295)

            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("MUGSHOT")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .tracking(2.4)
                    Spacer()
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 22, weight: .bold))
                }
                .foregroundColor(.mugshotSage)

                Spacer(minLength: 0)

                Text(reflection.period == .month ? "MY MONTH IN COFFEE" : "MY YEAR IN COFFEE")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.mugshotSage)

                Text(reflection.headline)
                    .font(.system(size: 43, weight: .bold, design: .serif))
                    .foregroundColor(.espressoBrown)
                    .lineLimit(4)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 10) {
                    shareFact("\(reflection.entryCount)", "SIPS")
                    shareFact("\(reflection.cafeCount)", "CAFES")
                    shareFact("\(reflection.photoCount)", "PHOTOS")
                }

                if let favoriteDrink = reflection.favoriteDrink {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.mugshotSage)
                        Text("\(favoriteDrink) returned most often")
                            .font(.system(size: 19, weight: .semibold, design: .serif))
                            .foregroundColor(.espressoBrown)
                    }
                }

                Spacer(minLength: 0)

                Text(periodLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.secondaryText)
            }
            .padding(42)
        }
        .frame(width: 540, height: 675)
        .clipped()
    }

    private var periodLabel: String {
        reflection.period == .month
            ? reflection.startDate.formatted(.dateTime.month(.wide).year())
            : reflection.startDate.formatted(.dateTime.year())
    }

    private func shareFact(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(.espressoBrown)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.mugshotSage)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.foamWhite.opacity(0.84), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct JournalReflectionActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
