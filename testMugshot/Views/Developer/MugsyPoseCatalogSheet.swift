#if DEBUG
import SwiftUI

struct MugsyPoseCatalogSheet: View {
    @State private var rendering = MugsyCatalogRendering.native
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 145), spacing: 16)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("One Mugsy. Eighteen moments.")
                .font(.title2)
                .foregroundStyle(Color.espressoBrown)

            Text("Every pose shares the immutable body, handle, glasses, palette, and attachment rig. Switch between native geometry and its generated artwork.")
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Character rendering", selection: $rendering) {
                ForEach(MugsyCatalogRendering.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(MugsyCatalogPose.allCases) { pose in
                    VStack(spacing: 8) {
                        MugsyCatalogView(pose: pose, rendering: rendering)
                            .frame(height: 170)
                        Text(pose.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.espressoBrown)
                            .multilineTextAlignment(.center)
                    }
                    .padding(12)
                    .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
#endif
