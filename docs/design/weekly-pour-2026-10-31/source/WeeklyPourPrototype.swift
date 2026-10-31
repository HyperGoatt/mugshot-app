#if DEBUG
import SwiftUI
import UIKit

// DESIGN PROTOTYPE ONLY. Copied into an isolated fixture checkout by prepare.sh.
// No production target, Auth, network, notification, analytics or journal writes.
private enum WPPage: String, CaseIterable {
    case journal, invitation, cover, moments, highlight, places, usual, ending, share, quiet, single
    case noPhoto = "no-photo"
    static let story: [Self] = [.cover, .moments, .highlight, .places, .usual, .ending]
    var index: Int { Self.story.firstIndex(of: self) ?? 0 }
    var dark: Bool { self == .highlight }
    var background: Color { dark ? .darkRoast : self == .usual ? .mugshotMint : .creamWhite }
}

struct MugshotCompletionPreviewHost: View {
    @State private var page: WPPage = {
        let arg = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--recap-scene=") }
        return WPPage(rawValue: arg?.components(separatedBy: "=").last ?? "cover") ?? .cover
    }()
    @State private var phase: CGFloat = 0
    @State private var flipped = ProcessInfo.processInfo.arguments.contains("--recap-flipped")
    @State private var handledPage: WPPage?
    @State private var filmStarted = false
    @State private var filmCancelled = false
    @State private var includePrivate = false
    @State private var showsShareNotice = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.mugshotReduceMotionOverride) private var motionOverride
    private var reduced: Bool { motionOverride ?? reduceMotion }

    var body: some View {
        WPScene(page: page, phase: phase, flipped: flipped, includePrivate: includePrivate,
                next: next, previous: previous, close: { select(.journal) },
                select: select, flip: { withAnimation(reduced ? nil : .easeInOut(duration: 0.35)) { flipped.toggle() } },
                togglePrivate: { includePrivate.toggle() }, shareAction: { showsShareNotice = true })
            .alert("Design preview", isPresented: $showsShareNotice) { Button("Got it", role: .cancel) {} } message: { Text("iOS sharing opens here after approval. Nothing has been shared.") }
            .preferredColorScheme(.light)
            .simultaneousGesture(DragGesture(minimumDistance: 38).onEnded { value in
                guard WPPage.story.contains(page) else { return }
                if value.translation.width < -45 { next() }
                if value.translation.width > 45 { previous() }
            })
            .contextMenu {
                Button("Full week") { select(.cover) }
                Button("Quiet week") { select(.quiet) }
                Button("One-sip week") { select(.single) }
                Button("Photo-free week") { select(.noPhoto) }
                Button("Journal entry") { select(.journal) }
                Button("Notification invitation") { select(.invitation) }
                Button("Share preview") { select(.share) }
            }
            .onChange(of: scenePhase) { _, value in if value != .active { var transaction = Transaction(); transaction.disablesAnimations = true; withTransaction(transaction) { phase = 1 } } }
            .task(id: "\(page.rawValue):\(scenePhase):\(reduced)") {
                guard scenePhase == .active, handledPage != page else { return }
                handledPage = page
                var transaction = Transaction(); transaction.disablesAnimations = true
                withTransaction(transaction) { phase = reduced ? 1 : 0 }
                guard scenePhase == .active else { return }
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled, scenePhase == .active else { return }
                withAnimation(reduced ? nil : .spring(duration: 0.85, bounce: 0.16)) { phase = 1 }
                do { try await Task.sleep(for: .milliseconds(1000)) } catch { return }
                guard !Task.isCancelled, scenePhase == .active else { return }
                let token = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--recap-run=") } ?? "manual"
                UserDefaults.standard.set("\(page.rawValue)|\(token)", forKey: "WeeklyPourPreview.ready")
            }
            .task(id: scenePhase) { await filmIfRequested() }
    }
    private func select(_ target: WPPage) {
        filmCancelled = true
        applySelection(target)
    }
    private func applySelection(_ target: WPPage) {
        flipped = false
        withAnimation(reduced ? nil : .easeInOut(duration: 0.24)) { page = target }
    }
    private func next() {
        MugshotHaptic.selection.play()
        if page == .journal || page == .invitation { select(.cover); return }
        if page == .quiet || page == .single || page == .noPhoto { select(.journal); return }
        if page == .share { select(.ending); return }
        let index = page.index
        select(index < WPPage.story.count - 1 ? WPPage.story[index + 1] : .journal)
    }
    private func previous() { select(page.index > 0 ? WPPage.story[page.index - 1] : .cover) }
    @MainActor private func filmIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--recap-film"), scenePhase == .active, !filmStarted else { return }
        filmStarted = true
        do {
            for item in [WPPage.invitation, .journal, .cover, .moments, .highlight, .places, .usual, .ending, .share, .quiet, .single, .noPhoto] {
                guard scenePhase == .active, !Task.isCancelled, !filmCancelled else { return }
                applySelection(item)
                try await Task.sleep(for: .seconds(item == .highlight ? 5 : 3))
                if item == .highlight { withAnimation(reduced ? nil : .easeInOut(duration: 0.35)) { flipped = true }; try await Task.sleep(for: .seconds(2)) }
            }
            if !filmCancelled { applySelection(.cover) }
        } catch { }
    }
}

private struct WPScene: View {
    let page: WPPage
    let phase: CGFloat
    let flipped: Bool
    let includePrivate: Bool
    var next: () -> Void = {}
    var previous: () -> Void = {}
    var close: () -> Void = {}
    var select: (WPPage) -> Void = { _ in }
    var flip: () -> Void = {}
    var togglePrivate: () -> Void = {}
    var shareAction: () -> Void = {}
    @ScaledMetric(relativeTo: .largeTitle) private var titleUnit: CGFloat = 43
    @ScaledMetric(relativeTo: .body) private var bodyUnit: CGFloat = 16
    private var ink: Color { page.dark ? .creamWhite : .espressoBrown }

    var body: some View {
        VStack(spacing: 0) {
            if page == .journal { journal }
            else if page == .invitation { invitation }
            else if page == .share { share }
            else {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch page {
                        case .cover: cover
                        case .moments: moments
                        case .highlight: highlight
                        case .places: places
                        case .usual: usual
                        case .ending: ending
                        case .quiet: quiet
                        case .single: single
                        case .noPhoto: noPhoto
                        default: EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                }
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(page.background)
        .foregroundStyle(ink)
    }

    private var chapterCount: Int { WPPage.story.contains(page) ? 6 : 1 }
    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                Text("THE WEEKLY POUR").font(.system(size: 11, weight: .bold)).tracking(2)
                Spacer()
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).frame(width: 40, height: 40).background(ink.opacity(0.06), in: Circle()) }
                    .accessibilityLabel("Close recap")
            }
            HStack(spacing: 5) {
                ForEach(0..<chapterCount) { index in Capsule().fill(ink.opacity(index <= page.index ? 0.85 : 0.13)).frame(height: 3) }
            }.accessibilityElement(children: .ignore).accessibilityLabel("Chapter \(page.index + 1) of \(chapterCount)")
        }
        .padding(.horizontal, 24).padding(.top, 12)
    }
    private func eyebrow(_ title: String) -> some View {
        Text(title.uppercased()).font(.system(size: 10, weight: .bold)).tracking(1.8).foregroundStyle(page.dark ? Color.mugshotMint : (page == .usual || page == .journal) ? Color.espressoBrown : .mugshotSageText)
    }
    private func headline(_ title: String, size: CGFloat = 43) -> some View {
        Text(title).font(.system(size: size * titleUnit / 43, weight: .bold, design: .serif)).tracking(-1.3).lineSpacing(-2)
            .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
    private func note(_ title: String) -> some View {
        Text(title).font(.system(.subheadline)).lineSpacing(3).multilineTextAlignment(.center)
            .foregroundStyle(ink.opacity(0.76)).fixedSize(horizontal: false, vertical: true)
    }
    private var cover: some View {
        VStack(spacing: 14) {
            eyebrow("October 18 – 25, 2026")
            headline("Your week,\nfreshly brewed.", size: 45)
            ZStack {
                Ellipse().fill(Color.mugshotMint.opacity(0.52)).frame(width: 285, height: 225).offset(y: 28)
                photo("V3QuietCafeCorner", width: 125, height: 151).rotationEffect(.degrees(-13 * phase)).offset(x: -98 * phase, y: 16)
                photo("V3CreamyLatte", width: 127, height: 155).rotationEffect(.degrees(12 * phase)).offset(x: 96 * phase, y: 34)
                WPMugsy(progress: phase, kind: .welcome).frame(width: 245, height: 245).offset(y: -8)
            }.frame(height: 270).padding(.top, 6)
            note("Five little coffee moments.\nLet’s give them another sip.")
            HStack(spacing: 7) {
                Image(systemName: "lock.fill").font(.system(size: 9))
                Text("A little story, just for you.").font(.system(size: 11, weight: .medium))
            }.foregroundStyle(Color.mugshotSageText).padding(.top, 4)
        }
    }
    private var moments: some View {
        VStack(spacing: 13) {
            eyebrow("The moments you kept")
            headline("A little coffee.\nA lot of life.")
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("5").font(.system(size: 70, weight: .bold, design: .serif)).tracking(-5)
                Text("moments\nremembered").font(.system(size: 18, weight: .medium)).lineSpacing(2)
            }.foregroundStyle(Color.mugshotSageText).padding(.top, 1)
            ZStack {
                photo("V3QuietCafeCorner", width: 135, height: 159).rotationEffect(.degrees(-10 * phase)).offset(x: -86, y: -16)
                photo("V3CreamyLatte", width: 156, height: 181).rotationEffect(.degrees(8 * phase)).offset(x: 77, y: 0)
                WPMugsy(progress: phase, kind: .journal).frame(width: 145, height: 145).offset(y: 28)
            }.frame(height: 195)
            HStack(spacing: 0) {
                ForEach(["MON 19", "WED 21", "THU 22", "SAT 24", "SUN 25"], id: \.self) { day in
                    VStack(spacing: 8) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 17)).foregroundStyle(Color.mugshotSageText)
                        Text(day).font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.secondaryText)
                    }.frame(maxWidth: .infinity)
                }
            }.padding(.horizontal, 6)
            note("The familiar stops. The slow mornings.\nThe one you’re still thinking about.").padding(.top, 8)
        }
    }
    private var highlight: some View {
        VStack(spacing: 15) {
            eyebrow("Your highest-rated sip")
            headline("That one\nreally good sip.", size: 42)
            Button(action: flip) {
                WPFlippingMemory(turn: flipped ? 1 : 0)
                .frame(height: 270)
                .rotationEffect(.degrees(flipped ? 0 : -2 * phase))
                .overlay(alignment: .bottomTrailing) { if !flipped { WPMugsy(progress: phase, kind: .delight).frame(width: 116, height: 116).offset(x: 9, y: 36) } }
            }.buttonStyle(.plain).accessibilityLabel(flipped ? "Found my new favorite corner. Your saved caption. Tap to return to photo." : "Vanilla latte, rated 4.5. Tap to read your saved caption.")
            VStack(alignment: .leading, spacing: 5) {
                Text("Vanilla latte").font(.system(size: 26, weight: .bold, design: .serif))
                Text("Little Window · Saturday, Oct 24").font(.system(size: 13)).foregroundStyle(Color.creamWhite.opacity(0.72))
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 13)
            Label(flipped ? "A memory worth turning over." : "Tap the photo. There’s a memory on the back.", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 11)).foregroundStyle(Color.mugshotMint).padding(.top, 3)
        }
    }
    private var places: some View {
        VStack(spacing: 16) {
            eyebrow("Out & about. Or right at home.")
            headline("Your little\ncoffee circuit.")
            HStack(alignment: .top, spacing: 12) {
                placeTicket(title: "Noonday", detail: "2 sips", image: "V3QuietCafeCorner", tilt: -4)
                placeTicket(title: "Little Window", detail: "1 sip", image: nil, tilt: 4)
            }.padding(.top, 8)
            HStack(spacing: 4) {
                WPMugsy(progress: phase, kind: .cozy).frame(width: 100, height: 100)
                VStack(alignment: .leading, spacing: 6) {
                    Text("And 2 at-home sips.").font(.system(size: 20, weight: .bold, design: .serif))
                    Text("Some good ones never\nleft the house.").font(.system(size: 13)).foregroundStyle(Color.secondaryText)
                }
                Spacer(minLength: 0)
            }.padding(12).background(Color.mugshotMint.opacity(0.35), in: RoundedRectangle(cornerRadius: 20)).padding(.top, 14)
        }
    }
    private var usual: some View {
        VStack(spacing: 16) {
            eyebrow("The repeat order")
            headline("The usual?\nFlat white.", size: 48)
            ZStack {
                Text("2").font(.system(size: 200, weight: .bold, design: .serif)).tracking(-10).foregroundStyle(Color.mugshotSageText.opacity(0.23)).offset(x: -87, y: -12)
                photo("V3CreamyLatte", width: 177, height: 202).rotationEffect(.degrees(-9 * phase)).offset(x: 17, y: -14)
                VStack(spacing: 7) {
                    Text("BACK FOR A SECOND SIP").font(.system(size: 9, weight: .bold)).tracking(1.2)
                    HStack(spacing: 28) { Text("MON 19"); Text("THU 22") }.font(.system(size: 11, weight: .semibold))
                }.padding(.horizontal, 18).padding(.vertical, 13).background(Color.creamWhite, in: RoundedRectangle(cornerRadius: 10)).rotationEffect(.degrees(4 * phase)).offset(y: 116)
                WPMugsy(progress: phase, kind: .delight).frame(width: 140, height: 140).offset(x: -104, y: 80)
            }.frame(height: 280)
            note("You came back to it twice.\nSome things just become your thing.")
        }
    }
    private var ending: some View {
        VStack(spacing: 12) {
            eyebrow("That was your Weekly Pour")
            headline("A week\nworth keeping.", size: 45)
            postcard(includePrivate: true, compact: true).rotationEffect(.degrees(-3 * phase)).padding(.top, 11)
            HStack(spacing: 6) {
                WPMugsy(progress: phase, kind: .delight).frame(width: 72, height: 72)
                Text("Same time next week?\nI’ll bring the memories.").font(.system(size: 17, weight: .medium, design: .serif)).lineSpacing(3)
            }.padding(.top, 8)
            Button { select(.share) } label: { Label("Make a share card", systemImage: "square.and.arrow.up").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.mugshotSageText).frame(minHeight: 44) }
        }
    }
    private var quiet: some View {
        VStack(spacing: 18) {
            eyebrow("October 4 – 11, 2026")
            headline("A quiet week.\nStill your story.", size: 43)
            ZStack {
                Circle().fill(Color.mugshotMint.opacity(0.30)).frame(width: 240, height: 240)
                WPMugsy(progress: phase, kind: .cozy).frame(width: 230, height: 230)
            }.frame(height: 250).padding(.top, 10)
            note("Nothing to recap this time.\nThere’s room here for every pace.")
            Text("No catching up needed.").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.mugshotSageText).padding(.top, 6)
        }
    }
    private var single: some View {
        VStack(spacing: 17) {
            eyebrow("One-sip week")
            headline("One sip.\nA whole moment.", size: 42)
            photo("V3CreamyLatte", width: 269, height: 246).rotationEffect(.degrees(-4 * phase)).overlay(alignment: .bottomTrailing) { WPMugsy(progress: phase, kind: .journal).frame(width: 123, height: 123).offset(x: 28, y: 25) }.padding(.vertical, 10)
            Text("Saturday’s vanilla latte").font(.system(size: 24, weight: .bold, design: .serif))
            note("No big numbers. Just a good moment\nyou can come back to.")
        }
    }
    private var noPhoto: some View {
        VStack(spacing: 18) {
            eyebrow("A photo-free memory")
            headline("No photo.\nStill a moment.", size: 43)
            ZStack {
                Circle().fill(Color.mugshotMint.opacity(0.40)).frame(width: 250, height: 250)
                WPMugsy(progress: phase, kind: .journal).frame(width: 250, height: 250)
            }.frame(height: 260)
            Text("Wednesday’s filter coffee").font(.system(size: 24, weight: .bold, design: .serif))
            Text("At home · October 21").font(.system(size: 13)).foregroundStyle(Color.secondaryText)
            note("A little home ritual, remembered.\nThe memory counts, picture or not.")
        }
    }
    private var footer: some View {
        HStack(spacing: 12) {
            if page.index > 0 && WPPage.story.contains(page) {
                Button(action: previous) { Image(systemName: "arrow.left").font(.system(size: 17, weight: .semibold)).frame(width: 52, height: 52).background(ink.opacity(0.06), in: Circle()) }.accessibilityLabel("Previous chapter")
            }
            Button(action: next) {
                HStack { Spacer(); Text(page == .cover ? "Let’s rewind" : page == .ending || page == .quiet || page == .single || page == .noPhoto ? "Back to my journal" : "Next little moment"); if page != .ending && page != .quiet && page != .single && page != .noPhoto { Image(systemName: "arrow.right") }; Spacer() }
                    .font(.system(size: bodyUnit, weight: .semibold)).frame(minHeight: 54)
                    .foregroundStyle(page.dark ? Color.darkRoast : Color.foamWhite)
                    .background(page.dark ? Color.mugshotMint : Color.espressoBrown, in: Capsule())
            }.accessibilityIdentifier("weeklyPour.next")
        }.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 20)
    }
    private func photo(_ asset: String, width: CGFloat, height: CGFloat) -> some View {
        Image(asset).resizable().scaledToFill().frame(width: width - 14, height: height - 25).clipped()
            .padding(.horizontal, 7).padding(.top, 7).padding(.bottom, 18)
            .background(Color.foamWhite).shadow(color: .espressoBrown.opacity(0.12), radius: 10, x: 0, y: 6).accessibilityHidden(true)
    }
    private func placeTicket(title: String, detail: String, image: String?, tilt: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image { Image(image).resizable().scaledToFill().frame(height: 150).clipped() }
            else { WPMugsy(progress: phase, kind: .scout).frame(height: 150).frame(maxWidth: .infinity).background(Color.mugshotMint.opacity(0.3)) }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 19, weight: .bold, design: .serif))
                HStack { Image(systemName: "mappin.circle.fill"); Text(detail) }.font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.mugshotSageText)
            }.padding(.horizontal, 11).padding(.bottom, 13)
        }.frame(maxWidth: .infinity).background(Color.foamWhite).clipShape(RoundedRectangle(cornerRadius: 14)).rotationEffect(.degrees(tilt * phase)).shadow(color: .espressoBrown.opacity(0.06), radius: 5, y: 4)
    }
    private func postcard(includePrivate: Bool, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("MUGSHOT").font(.system(size: 10, weight: .heavy)).tracking(2); Spacer(); Text("OCT 18–25").font(.system(size: 9, weight: .semibold)).tracking(1) }
            HStack(spacing: 8) {
                Image("V3CreamyLatte").resizable().scaledToFill().frame(width: compact ? 140 : 164, height: compact ? 100 : 145).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                Image("V3QuietCafeCorner").resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: compact ? 100 : 145).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text("The little things,\nfreshly remembered.").font(.system(size: compact ? 22 : 26, weight: .bold, design: .serif)).tracking(-0.6)
            HStack(spacing: 10) {
                Label(includePrivate ? "5 moments" : "3 moments", systemImage: "cup.and.saucer")
                Label("2 cafes", systemImage: "mappin")
                if includePrivate { Label("2 at home", systemImage: "house") }
            }.font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondaryText)
        }.padding(16).background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16)).shadow(color: .espressoBrown.opacity(0.08), radius: 10, y: 6)
    }
    private var share: some View {
        VStack(spacing: 0) {
            HStack { Text("Your share card").font(.system(size: 21, weight: .bold, design: .serif)); Spacer(); Button { select(.ending) } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Close share preview") }.padding(.horizontal, 24).padding(.top, 20)
            ScrollView {
                VStack(spacing: 20) {
                    Text("A little window into your week.").font(.system(size: 14)).foregroundStyle(Color.secondaryText)
                    postcard(includePrivate: includePrivate)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield").foregroundStyle(Color.mugshotSageText)
                        VStack(alignment: .leading, spacing: 6) { Text("Yours to choose").font(.system(size: 15, weight: .semibold)); Text("Private notes and captions never go on this card.").font(.system(size: 13)).foregroundStyle(Color.secondaryText) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Toggle(isOn: Binding(get: { includePrivate }, set: { _ in togglePrivate() })) { Text("Include my private Home sips").font(.system(size: 14)) }.tint(.mugshotSageText)
                    Text("This preview includes \(includePrivate ? "all 5" : "3 non-private") moments. Check the card before sharing.").font(.system(size: 12)).foregroundStyle(Color.secondaryText).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(24)
            }
            Button(action: shareAction) { Text("Share image").font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 54).foregroundStyle(Color.foamWhite).background(Color.espressoBrown, in: Capsule()) }.padding(24)
        }
    }
    private var journal: some View {
        ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) { Text("Journal").font(.system(size: 36, weight: .bold, design: .serif)).tracking(-1); Spacer(); Image(systemName: "line.3.horizontal.decrease").font(.system(size: 18)) }
            Text("A home for your coffee moments.").font(.system(size: 14)).foregroundStyle(Color.secondaryText)
            Button { select(.cover) } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { eyebrow("Freshly brewed for you"); Spacer(); Image(systemName: "arrow.up.right") }
                    HStack {
                        VStack(alignment: .leading, spacing: 9) { Text("Your Weekly\nPour is ready.").font(.system(size: 33, weight: .bold, design: .serif)).tracking(-0.7).lineLimit(nil).fixedSize(horizontal: false, vertical: true); Text("Oct 18–25 · 5 moments").font(.system(size: 12)).foregroundStyle(Color.secondaryText) }
                        Spacer(minLength: 0); WPMugsy(progress: phase, kind: .welcome).frame(width: 116, height: 150)
                    }
                    Text("Open my week  →").font(.system(size: 15, weight: .bold)).padding(.vertical, 10)
                }.padding(20).background(Color.mugshotMint.opacity(0.5), in: RoundedRectangle(cornerRadius: 24))
            }.buttonStyle(.plain)
            HStack { Text("The archive").font(.system(size: 23, weight: .bold, design: .serif)); Spacer(); Text("Week · Month · Year").font(.system(size: 11)).foregroundStyle(Color.secondaryText) }
            Button { select(.single) } label: { archiveRow("Oct 11–18", "One sip. A whole moment.", photo: true) }.buttonStyle(.plain)
            Divider()
            Button { select(.quiet) } label: { archiveRow("Oct 4–11", "A slower kind of week.", photo: false) }.buttonStyle(.plain)
            Spacer(minLength: 0)
            HStack { Image(systemName: "bell.badge"); Text("Your Sunday reminder"); Spacer(); Text("6 PM").fontWeight(.semibold) }.font(.system(size: 12)).foregroundStyle(Color.mugshotSageText).padding(.vertical, 15).padding(.horizontal, 16).background(Color.mugshotMint.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
        }.padding(24)
        }
    }
    private func archiveRow(_ date: String, _ title: String, photo: Bool) -> some View {
        HStack(spacing: 13) {
            if photo { Image("V3CreamyLatte").resizable().scaledToFill().frame(width: 68, height: 75).clipped().clipShape(RoundedRectangle(cornerRadius: 10)) }
            else { WPMugsy(progress: 1, kind: .cozy).frame(width: 68, height: 75).background(Color.sandBeige, in: RoundedRectangle(cornerRadius: 10)) }
            VStack(alignment: .leading, spacing: 6) { Text(date).font(.system(size: 11)).foregroundStyle(Color.secondaryText); Text(title).font(.system(size: 18, weight: .semibold, design: .serif)) }
            Spacer(); Image(systemName: "chevron.right").font(.system(size: 12))
        }
    }
    private var invitation: some View {
        GeometryReader { geometry in
        ZStack {
            Image("V3QuietCafeCorner").resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).blur(radius: 20).overlay(Color.espressoBrown.opacity(0.25)).clipped()
            VStack(spacing: 30) {
                Text("Sunday, October 25").font(.system(size: 18, weight: .medium)).foregroundStyle(Color.foamWhite)
                Text("6:00").font(.system(size: 90, weight: .light, design: .rounded)).foregroundStyle(Color.foamWhite)
                Button { select(.cover) } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image("MugshotAppIcon").resizable().frame(width: 25, height: 25).clipShape(RoundedRectangle(cornerRadius: 6)); Text("MUGSHOT").font(.system(size: 11, weight: .semibold)); Spacer(); Text("now").font(.system(size: 11)).foregroundStyle(Color.secondaryText) }
                        VStack(alignment: .leading, spacing: 5) { Text("Your Weekly Pour is ready.").font(.system(size: 17, weight: .bold)); Text("A little coffee. A few good memories.\nCome take a look back with Mugsy.").font(.system(size: 15)).lineSpacing(3) }
                    }.foregroundStyle(Color.espressoBrown).padding(18).background(Color.creamWhite.opacity(0.94), in: RoundedRectangle(cornerRadius: 25))
                }.buttonStyle(.plain)
                Text("DESIGN PREVIEW · NO NOTIFICATION SENT").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(Color.foamWhite.opacity(0.8))
                Spacer()
            }.padding(.horizontal, 20).padding(.top, 54).frame(width: geometry.size.width)
        }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
    }
}

private struct WPFlippingMemory: View, Animatable {
    var turn: CGFloat
    var animatableData: CGFloat { get { turn } set { turn = newValue } }
    var body: some View {
        ZStack {
            if turn < 0.5 {
                Image("V3CreamyLatte").resizable().scaledToFill().frame(height: 270).clipped()
                VStack { HStack { Spacer(); Label("4.5", systemImage: "star.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(Color.espressoBrown).padding(.horizontal, 16).padding(.vertical, 10).background(Color.creamWhite, in: Capsule()) }; Spacer() }.padding(17)
            } else {
                Color.sandBeige
                VStack(spacing: 18) {
                    Image(systemName: "quote.opening").font(.system(size: 32)).foregroundStyle(Color.mugshotSageText)
                    Text("Found my new\nfavorite corner.").font(.system(size: 30, weight: .medium, design: .serif)).multilineTextAlignment(.center).foregroundStyle(Color.espressoBrown)
                    Text("YOUR SAVED CAPTION · SAT 24").font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundStyle(Color.secondaryText)
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 16)).foregroundStyle(Color.mugshotSageText)
                }.padding(22).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }.clipShape(RoundedRectangle(cornerRadius: 24))
            .rotation3DEffect(.degrees(Double(turn) * 180), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
    }
}

private struct WPMugsy: View, Animatable {
    enum Kind { case welcome, journal, delight, cozy, scout }
    var progress: CGFloat
    var kind: Kind
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    var body: some View {
        let pose = MugsyCompletionPose.sample(progress)
        let prop: MugsyProp = kind == .journal || kind == .cozy ? .journalNotebook : kind == .scout ? .guidebookAndPen : .none
        MugsyModelView(configuration: MugsyModelConfiguration(
            expression: kind == .cozy ? .curious : .delighted, prop: prop,
            outfit: kind == .cozy ? .cozyRitual : .none,
            armPose: prop == .none ? .presenting : nil,
            legArticulation: .init(bendProgress: pose.bend * 0.45, weightShift: pose.wave * 0.15),
            gaze: .center, liquid: .coffee(fillProgress: 0.78, steamIntensity: 0.12)),
            presentation: MugsyModelPresentation(waveLift: prop == .none ? pose.wave : 0, waveSwing: prop == .none ? pose.swing * 0.4 : 0, eyeOpenness: pose.eyeOpenness))
            .accessibilityHidden(true)
    }
}
#endif
