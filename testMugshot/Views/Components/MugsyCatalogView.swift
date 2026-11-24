import SwiftUI

enum MugsyCatalogRendering: String, CaseIterable, Identifiable {
    case native
    case artwork

    var id: String { rawValue }
    var title: String { self == .native ? "Native character" : "Generated artwork" }
}

/// Choose code-native geometry for product motion, or its named generated
/// artwork for a static illustration. Both use the same typed pose contract.
struct MugsyCatalogView: View {
    let pose: MugsyCatalogPose
    var rendering: MugsyCatalogRendering = .native

    var body: some View {
        Group {
            switch rendering {
            case .native:
                MugsyModelView(configuration: pose.configuration)
            case .artwork:
                GeometryReader { proxy in
                    let bounds = pose.artworkBounds
                    let side = min(proxy.size.width / bounds.width, proxy.size.height / bounds.height) * 0.84
                    Image(pose.assetName)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: side, height: side)
                        .position(
                            x: proxy.size.width / 2 + (0.5 - bounds.midX) * side,
                            y: proxy.size.height / 2 + (0.5 - bounds.midY) * side
                        )
                }
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(pose.configuration.accessibilityLabel)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
