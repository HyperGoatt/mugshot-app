import SwiftUI
import UIKit

/// The renderer receives only aggregate counts and a date range. Personal text,
/// identity and media cannot accidentally enter the exported view.
struct WeeklyPourKeepsakeCard: View {
    let summary: WeeklyPourShareSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Mugshot").font(.system(.title2, design: .serif))
                Spacer(minLength: 4)
                Text("THE WEEKLY POUR").font(.system(size: 9, weight: .bold)).tracking(1.4)
            }
            Rectangle().fill(Color.mugshotLine).frame(height: 1)
            HStack(spacing: 8) {
                Text("The little things,\nfreshly remembered.")
                    .font(.system(size: 27, weight: .regular, design: .serif)).tracking(-0.4)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                MugsyCatalogView(pose: .journalKeeper, rendering: .artwork)
                    .frame(width: 90, height: 112).accessibilityHidden(true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(summary.momentCount)").font(.system(size: 52, weight: .regular, design: .serif))
                Text(summary.momentCount == 1 ? "moment kept" : "moments kept").font(.subheadline)
            }
            HStack(spacing: 14) {
                if summary.cafeCount > 0 {
                    Label("\(summary.cafeCount) \(summary.cafeCount == 1 ? "cafe" : "cafes")", systemImage: "mappin")
                }
                if summary.homeCount > 0 { Label("\(summary.homeCount) at home", systemImage: "house") }
            }.font(.caption).foregroundStyle(Color.roastBrown)
            Rectangle().fill(Color.mugshotLine).frame(height: 1)
            Text("\(summary.window.title) · \(summary.window.yearLabel)")
                .font(.caption.weight(.medium)).foregroundStyle(Color.roastBrown)
        }
        .padding(22).foregroundStyle(Color.espressoBrown)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.mugshotLine, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct WeeklyPourSharePreview: View {
    let story: WeeklyPourStory
    let canShare: () -> Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var includePrivate = false
    @State private var activity: WeeklyPourActivityPayload?
    @State private var renderFailed = false
    private var summary: WeeklyPourShareSummary { story.shareSummary(includePrivate: includePrivate) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("A little window into your week.")
                            .font(.body).foregroundStyle(Color.roastBrown)
                        WeeklyPourKeepsakeCard(summary: summary)
                            .accessibilityIdentifier("weeklyPour.shareCard")
                        Label {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("Yours to choose").font(.headline)
                                Text("Only the dates and counts shown here go on this card. Photos, places, captions and private notes stay in your journal.")
                                    .font(.subheadline).foregroundStyle(Color.roastBrown)
                            }
                        } icon: { Image(systemName: "lock.shield").foregroundStyle(Color.mugshotSageText) }
                        if story.privateCount > 0 {
                            Toggle("Include counts from my private memories", isOn: $includePrivate)
                                .font(.body).tint(.mugshotSageText)
                                .accessibilityIdentifier("weeklyPour.includePrivate")
                        }
                        Text(summary.momentCount == 0
                             ? "Your memories this week are private. Include their counts to make a share card."
                             : "This card includes \(summary.momentCount) \(summary.momentCount == 1 ? "moment" : "moments"). Check the preview before sharing.")
                            .font(.caption).foregroundStyle(Color.roastBrown)
                        if renderFailed {
                            Text("The card couldn’t be prepared. Try sharing again.")
                                .font(.subheadline).foregroundStyle(Color.roastBrown)
                                .accessibilityIdentifier("weeklyPour.shareError")
                        }
                    }.padding(24).frame(maxWidth: 480)
                        .frame(maxWidth: .infinity)
                }
                Button(action: prepareShare) {
                    Label("Share image", systemImage: "square.and.arrow.up")
                        .font(.body.weight(.semibold)).frame(maxWidth: .infinity)
                        .padding(16).foregroundStyle(Color.foamWhite)
                        .background(summary.momentCount > 0 ? Color.mugshotSageText : Color.roastBrown, in: Capsule())
                }
                .disabled(summary.momentCount == 0)
                .accessibilityIdentifier("weeklyPour.shareImage")
                .padding(.horizontal, 24).padding(.vertical, 16)
            }
            .background(Color.creamWhite).foregroundStyle(Color.espressoBrown)
            .navigationTitle("Your share card").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $activity) { payload in
                WeeklyPourActivityView(payload: payload)
            }
            .onChange(of: includePrivate) { _, _ in activity = nil; renderFailed = false }
            .onChange(of: authModel.authenticatedUser?.id) { _, _ in
                if !canShare() { activity = nil; dismiss() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .mugshotSafetyAccessChanged)) { _ in
                activity = nil; dismiss()
            }
        }
        .preferredColorScheme(.light)
    }

    @MainActor private func prepareShare() {
        guard canShare(), scenePhase == .active, summary.momentCount > 0, activity == nil else { return }
        renderFailed = false
        let renderer = ImageRenderer(content: WeeklyPourKeepsakeCard(summary: summary)
            .frame(width: 340).padding(20).background(Color.creamWhite)
            .environment(\.dynamicTypeSize, .large).environment(\.colorScheme, .light))
        renderer.scale = 3
        renderer.isOpaque = true
        guard let image = renderer.uiImage, canShare() else { renderFailed = true; return }
        activity = WeeklyPourActivityPayload(image: image)
    }
}

private struct WeeklyPourActivityPayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct WeeklyPourActivityView: UIViewControllerRepresentable {
    let payload: WeeklyPourActivityPayload
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [payload.image], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
