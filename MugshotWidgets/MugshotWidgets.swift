import SwiftUI
import WidgetKit

@main
struct MugshotWidgets: WidgetBundle {
    var body: some Widget {
        MugshotQuickSipWidget()
    }
}

private struct MugshotWidgetEntry: TimelineEntry {
    let date: Date
}

private struct MugshotWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MugshotWidgetEntry { MugshotWidgetEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (MugshotWidgetEntry) -> Void) {
        completion(MugshotWidgetEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MugshotWidgetEntry>) -> Void) {
        completion(Timeline(entries: [MugshotWidgetEntry(date: Date())], policy: .never))
    }
}

private struct MugshotQuickSipWidget: Widget {
    let kind = "MugshotQuickSipWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MugshotWidgetProvider()) { _ in
            MugshotWidgetView()
                .containerBackground(for: .widget) { WidgetPalette.cream }
        }
        .configurationDisplayName("Quick Sip")
        .description("Open Mugshot to remember a Cafe or Home sip.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct MugshotWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemSmall {
            Link(destination: URL(string: "mugshot://cafe-sip")!) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(WidgetPalette.sage)
                    Spacer(minLength: 0)
                    Text("Quick Sip")
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(WidgetPalette.espresso)
                    Text("Remember this coffee")
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.espresso.opacity(0.68))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("MUGSHOT")
                    .font(.caption2.bold())
                    .tracking(1.3)
                    .foregroundStyle(WidgetPalette.sage)
                Text("Where does this sip begin?")
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(WidgetPalette.espresso)
                HStack(spacing: 8) {
                    widgetAction("Cafe", icon: "mappin.and.ellipse", route: "cafe-sip")
                    widgetAction("Home", icon: "house.fill", route: "home-sip")
                    widgetAction("Repeat", icon: "arrow.clockwise", route: "repeat-sip")
                    widgetAction("Camera", icon: "camera.fill", route: "camera")
                }
            }
        }
    }

    private func widgetAction(_ title: String, icon: String, route: String) -> some View {
        Link(destination: URL(string: "mugshot://\(route)")!) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold)).lineLimit(1)
            }
            .foregroundStyle(WidgetPalette.espresso)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(WidgetPalette.sage.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private enum WidgetPalette {
    static let cream = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let sage = Color(red: 0.38, green: 0.53, blue: 0.45)
    static let espresso = Color(red: 0.24, green: 0.16, blue: 0.12)
}
