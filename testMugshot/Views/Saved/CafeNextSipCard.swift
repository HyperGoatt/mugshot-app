import SwiftUI

enum CafeDetailEntry {
    case map
    case saved

    var title: String {
        switch self {
        case .map: "Map"
        case .saved: "Saved"
        }
    }
}

struct CafeNextSipCard: View {
    let order: CafeNextSipOrder
    let heroPhotoPath: String?
    let onOpen: () -> Void
    let onRepeat: () -> Void
    let onLog: () -> Void

    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        VStack(spacing: 10) {
            lastOrderCard
            if order.canRepeat {
                Button(action: onLog) {
                    Label("Log a different sip", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mugshotSageText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var lastOrderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    eyebrow
                    Spacer(minLength: 8)
                    orderDate
                }
                VStack(alignment: .leading, spacing: 5) {
                    eyebrow
                    orderDate
                }
            }

            Button(action: onOpen) {
                HStack(spacing: 12) {
                    if !textSize.isAccessibilitySize {
                        orderPhoto
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.drinkName)
                            .mugshotDisplay(size: 23)
                            .foregroundStyle(Color.espressoBrown)
                        if !order.orderNotes.isEmpty {
                            Text(order.orderNotes)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.mugshotSageText)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your previous sip")
            .accessibilityIdentifier("cafe.nextSip.original")

            if order.canRepeat {
                if order.reorderIntention == .yes {
                    Label("You’d order it again", systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.mugshotSageText)
                }
                Button(action: onRepeat) {
                    Label("Log this again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityHint("Starts a new private draft with this order")
                .accessibilityIdentifier("cafe.nextSip.repeat")

            } else {
                Label("You’d try a different order", systemImage: "arrow.turn.down.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.secondaryText)
                Button(action: onLog) {
                    Label("Log a Sip", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mugshotMint.opacity(0.31), in: .rect(cornerRadius: DesignSystem.Radius.heroCard))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.heroCard)
                .strokeBorder(Color.mugshotLine)
                .allowsHitTesting(false)
        }
    }

    private var eyebrow: some View {
        Text("Last time here")
            .textCase(.uppercase)
            .font(.caption2.weight(.bold))
            .tracking(1.3)
            .foregroundStyle(Color.mugshotSageText)
            .accessibilityAddTraits(.isHeader)
    }

    private var orderDate: some View {
        Text(order.date, format: .dateTime.month(.abbreviated).day().year())
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
    }

    @ViewBuilder
    private var orderPhoto: some View {
        let paths: [String] = switch order.source {
        case .local(let visit): [visit.posterImagePath].compactMap { $0 } + visit.photos
        case .remote(let summary): summary.photoURLs
        }
        if let path = paths.first(where: { $0 != heroPhotoPath }) {
            Group {
                if CafePhotoSelection.isRemotePhotoReference(path) {
                    RemotePhotoImageView(urlString: path, placeholderSystemName: "cup.and.saucer", contentMode: .fill)
                } else {
                    PhotoImageView(photoPath: path, contentMode: .fill)
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(.rect(cornerRadius: 12))
            .accessibilityHidden(true)
        }
    }
}
