import SwiftUI

struct WeeklyPourStoryView: View {
    let story: WeeklyPourStory
    let onClose: () -> Void
    let onChooseWeek: () -> Void
    let canShare: () -> Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mugshotReduceMotionOverride) private var reduceMotionOverride
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("MugshotSettings.haptics.v1") private var haptics = true
    @State private var chapterIndex = 0
    @State private var showsShare = false
    @State private var flipped = false
    @State private var revealed = false
    @State private var visited = Set<WeeklyPourChapter>()
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 42
    private var chapter: WeeklyPourChapter { story.chapters[min(chapterIndex, story.chapters.count - 1)] }
    private var dark: Bool { chapter == .standout }
    private var reduced: Bool { reduceMotionOverride ?? reduceMotion }
    private var ink: Color { dark ? .creamWhite : .espressoBrown }
    private var supportingInk: Color { dark ? .creamWhite : .roastBrown }
    private var canvas: Color { dark ? .darkRoast : chapter == .repeatOrder ? .mugshotMint : .creamWhite }
    private var quiet: Bool { story.moments.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        chapterContent
                    }
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 24)
                    .id(chapter)
                    .transition(.opacity)
                }
                .onChange(of: chapterIndex) { _, _ in proxy.scrollTo(chapter, anchor: .top) }
            }
            .accessibilityIdentifier("weeklyPour.content")
            .simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                if value.translation.width < -55 { next() }
                else if value.translation.width > 55 { select(chapterIndex - 1) }
            })
            footer
        }
        .foregroundStyle(ink).background(canvas.ignoresSafeArea())
        .preferredColorScheme(dark ? .dark : .light)
        .sheet(isPresented: $showsShare) {
            WeeklyPourSharePreview(story: story, canShare: canShare)
        }
        .task(id: chapter) {
            let shouldAnimate = !visited.contains(chapter) && !reduced && scenePhase == .active
            visited.insert(chapter)
            revealed = !shouldAnimate
            if shouldAnimate {
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.65, bounce: 0.12)) { revealed = true }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { revealed = true; showsShare = false }
        }
        .onChange(of: reduced) { _, value in if value { revealed = true } }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button(action: onChooseWeek) {
                    HStack(spacing: 7) {
                        Text("THE WEEKLY POUR").font(.caption2.weight(.bold)).tracking(1.8)
                        Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                    }.frame(minHeight: 44)
                }
                .accessibilityLabel("Choose a week. Currently \(story.window.title)")
                .accessibilityIdentifier("weeklyPour.archive")
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.body.weight(.semibold))
                        .frame(width: 44, height: 44).background(ink.opacity(0.07), in: Circle())
                }
                .accessibilityLabel("Close Week in review").accessibilityIdentifier("weeklyPour.close")
            }.buttonStyle(.plain)
            HStack(spacing: 5) {
                ForEach(Array(story.chapters.enumerated()), id: \.element) { index, _ in
                    Capsule().fill(ink.opacity(index <= chapterIndex ? 0.85 : 0.15)).frame(height: 3)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Chapter \(chapterIndex + 1) of \(story.chapters.count)")
            .accessibilityValue(chapter.rawValue)
            .accessibilityIdentifier("weeklyPour.progress")
        }
        .padding(.horizontal, 24).padding(.top, 8)
    }

    @ViewBuilder private var chapterContent: some View {
        switch chapter {
        case .cover: cover
        case .moments: moments
        case .standout: if let standout = story.standout { highlight(standout) }
        case .places: places
        case .repeatOrder: if let repeated = story.repeatedDrink { repeatOrder(repeated) }
        case .keepsake: keepsake
        }
    }

    private var cover: some View {
        Group {
            eyebrow("\(story.window.title), \(story.window.yearLabel)")
            headline(quiet ? "A quiet week.\nStill your story." : story.moments.count == 1
                     ? "One sip.\nA whole moment." : "Your week,\nfreshly brewed.")
            ZStack {
                Ellipse().fill(Color.mugshotMint.opacity(0.45)).frame(width: 264, height: 220).offset(y: 30)
                if !quiet, let first = story.photos.first {
                    polaroid(first, width: 123, height: 156)
                        .rotationEffect(.degrees(revealed ? -13 : -3))
                        .offset(x: revealed ? -90 : -24, y: 25)
                }
                if story.photos.count > 1, let last = story.photos.last {
                    polaroid(last, width: 123, height: 156)
                        .rotationEffect(.degrees(revealed ? 12 : 3))
                        .offset(x: revealed ? 92 : 24, y: 43)
                }
                mugsy(quiet ? .cozyRitual : .welcomeWave, size: 228)
                    .offset(y: revealed ? -7 : 3)
            }
            .frame(height: 275).accessibilityHidden(true)
            note(quiet ? "Nothing to recap this time.\nThere’s room here for every pace."
                 : story.moments.count == 1 ? "A little moment you kept.\nLet’s give it another sip."
                 : "\(story.moments.count) little moments.\nLet’s give them another sip.")
            Label(quiet ? "No catching up needed." : "A little story, just for you.",
                  systemImage: quiet ? "leaf" : "lock.fill")
                .font(.caption).foregroundStyle(Color.mugshotSageText).padding(.top, 4)
            if quiet {
                Button("Browse my earlier weeks", action: onChooseWeek)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.mugshotSageText)
                    .frame(minHeight: 44)
            }
        }
    }

    private var moments: some View {
        Group {
            eyebrow("The moments you kept")
            headline("A little coffee.\nA lot of life.")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(story.moments.count)").font(.system(size: titleSize * 1.5, weight: .regular, design: .serif))
                Text("moments\nremembered").font(.headline)
            }.foregroundStyle(Color.mugshotSageText).accessibilityElement(children: .combine)
            ZStack {
                if let first = story.photos.first {
                    polaroid(first, width: 142, height: 174).rotationEffect(.degrees(-9)).offset(x: -68, y: -9)
                }
                if story.photos.count > 1, let last = story.photos.last {
                    polaroid(last, width: 147, height: 178).rotationEffect(.degrees(8)).offset(x: 69, y: 3)
                }
                mugsy(.journalKeeper, size: story.photos.isEmpty ? 210 : 134)
                    .offset(y: story.photos.isEmpty ? 0 : 26)
            }.frame(height: 205).accessibilityHidden(true)
            VStack(spacing: 0) {
                ForEach(story.moments) { moment in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(moment.date.formatted(.dateTime.weekday(.abbreviated).day()))
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.mugshotSageText)
                            .frame(width: 62, alignment: .leading)
                        Text(moment.drink).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        if moment.isAtHome { Image(systemName: "house").font(.caption).accessibilityLabel("At home") }
                    }
                    .padding(.vertical, 11).accessibilityElement(children: .combine)
                    if moment.id != story.moments.last?.id { Divider().overlay(Color.mugshotLine) }
                }
            }
        }
    }

    private func highlight(_ moment: WeeklyPourMoment) -> some View {
        Group {
            eyebrow(story.hasRatedStandout ? "Your highest-rated sip" : "A moment to come back to")
            headline(story.hasRatedStandout ? "That one\nreally good sip." : "The little things\nstay with you.")
            Button {
                guard moment.caption != nil else { return }
                withAnimation(reduced ? nil : .easeInOut(duration: 0.36)) { flipped.toggle() }
                MugshotHaptic.selection.play(isEnabled: haptics)
            } label: {
                WeeklyPourTurningMemory(moment: moment, ownerID: story.ownerID, flipped: flipped,
                                        reduced: reduced)
            }
            .buttonStyle(.plain).disabled(moment.caption == nil)
            .accessibilityLabel(flipped ? "Saved caption: \(moment.caption ?? ""). Return to photo."
                                : "\(moment.drink)\(moment.caption == nil ? "" : ". Read saved caption.")")
            .accessibilityIdentifier("weeklyPour.turnMemory")
            VStack(alignment: .leading, spacing: 7) {
                Text(moment.drink).font(.system(.title2, design: .serif))
                Text("\(moment.location) · \(moment.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
                    .font(.subheadline).foregroundStyle(Color.creamWhite)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            if moment.caption != nil {
                Label(flipped ? "A memory worth turning over." : "Tap the photo. There’s a memory on the back.",
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption).foregroundStyle(Color.mugshotMint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var places: some View {
        Group {
            eyebrow("Out & about. Or right at home.")
            headline(story.places.isEmpty ? "Some good ones\nstay at home." : "Your little\ncoffee circuit.")
            ForEach(story.places) { place in
                HStack(spacing: 14) {
                    if let moment = place.moments.first {
                        WeeklyPourPhotoView(moment: moment, ownerID: story.ownerID)
                            .frame(width: 76, height: 86).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text(place.name).font(.system(.title3, design: .serif))
                        Label("\(place.count) \(place.count == 1 ? "sip" : "sips")", systemImage: "mappin")
                            .font(.subheadline).foregroundStyle(Color.mugshotSageText)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14).background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityElement(children: .combine)
            }
            if story.homeCount > 0 {
                HStack(spacing: 6) {
                    mugsy(.cozyRitual, size: 102)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(story.homeCount) at-home \(story.homeCount == 1 ? "sip" : "sips").")
                            .font(.system(.title3, design: .serif))
                        Text("Your own little ritual.").font(.subheadline).foregroundStyle(Color.roastBrown)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12).background(Color.mugshotMint.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private func repeatOrder(_ repeated: WeeklyPourRepeatedDrink) -> some View {
        Group {
            eyebrow("The repeat order")
            headline("The usual?\n\(repeated.name).")
            ZStack {
                Text("\(repeated.moments.count)")
                    .font(.system(size: 180, weight: .regular, design: .serif))
                    .foregroundStyle(Color.mugshotSageText.opacity(0.22)).offset(x: -82, y: -20)
                if let first = repeated.moments.first {
                    polaroid(first, width: 185, height: 212).rotationEffect(.degrees(-8)).offset(x: 22, y: -12)
                }
                mugsy(.firstSipCelebration, size: 122).offset(x: -94, y: 76)
            }.frame(height: 270).accessibilityHidden(true)
            HStack(spacing: 14) {
                ForEach(repeated.moments.prefix(4)) { moment in
                    Text(moment.date.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.caption.weight(.semibold))
                }
            }.padding(16).background(Color.creamWhite, in: RoundedRectangle(cornerRadius: 12))
            note("You came back to it \(repeated.moments.count == 2 ? "twice" : "\(repeated.moments.count) times").\nSome things just become your thing.")
        }
    }

    private var keepsake: some View {
        Group {
            eyebrow("That was your Weekly Pour")
            headline("A week\nworth keeping.")
            WeeklyPourKeepsakeCard(summary: story.shareSummary(includePrivate: true))
                .rotationEffect(.degrees(reduced ? 0 : -2)).padding(.vertical, 8)
            HStack(spacing: 2) {
                mugsy(.journalKeeper, size: 88)
                Text("The little moments.\nAll here when you want them.")
                    .font(.system(.headline, design: .serif)).foregroundStyle(Color.roastBrown)
            }
            Button {
                if canShare() { showsShare = true }
            } label: {
                Label("Make a share card", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.mugshotSageText)
                    .frame(minHeight: 44)
            }.accessibilityIdentifier("weeklyPour.sharePreview")
            Text("Private until you choose to share.").font(.caption).foregroundStyle(Color.roastBrown)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if chapterIndex > 0 {
                Button { select(chapterIndex - 1) } label: {
                    Image(systemName: "arrow.left").font(.body.weight(.semibold))
                        .frame(width: 52, height: 54).background(ink.opacity(0.07), in: Circle())
                }.accessibilityLabel("Previous chapter").accessibilityIdentifier("weeklyPour.previous")
            }
            Button(action: next) {
                HStack(spacing: 10) {
                    Text(quiet || chapter == .keepsake ? "Back to my journal"
                         : chapter == .cover ? "Let’s rewind" : "Next little moment")
                    if !quiet && chapter != .keepsake { Image(systemName: "arrow.right") }
                }
                .font(.body.weight(.semibold)).padding(.horizontal, 18).padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(dark ? Color.espressoBrown : .foamWhite)
                .background(dark ? Color.mugshotMint : .espressoBrown, in: Capsule())
            }.accessibilityIdentifier("weeklyPour.next")
        }
        .buttonStyle(.plain).padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 14)
        .background(canvas)
    }

    private func select(_ index: Int) {
        guard story.chapters.indices.contains(index), index != chapterIndex else { return }
        flipped = false
        withAnimation(reduced ? nil : .easeOut(duration: 0.2)) { chapterIndex = index }
        MugshotHaptic.selection.play(isEnabled: haptics)
    }
    private func next() {
        if chapterIndex == story.chapters.count - 1 { onClose() }
        else { select(chapterIndex + 1) }
    }
    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption2.weight(.bold)).tracking(1.6)
            .foregroundStyle(dark ? Color.mugshotMint : .mugshotSageText)
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    }
    private func headline(_ text: String) -> some View {
        Text(text).font(.system(size: titleSize, weight: .regular, design: .serif)).tracking(-0.8)
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
    private func note(_ text: String) -> some View {
        Text(text).font(.body).lineSpacing(3).multilineTextAlignment(.center)
            .foregroundStyle(supportingInk).fixedSize(horizontal: false, vertical: true)
    }
    private func mugsy(_ pose: MugsyCatalogPose, size: CGFloat) -> some View {
        MugsyCatalogView(pose: pose, rendering: .artwork).frame(width: size, height: size).accessibilityHidden(true)
    }
    private func polaroid(_ moment: WeeklyPourMoment, width: CGFloat, height: CGFloat) -> some View {
        WeeklyPourPhotoView(moment: moment, ownerID: story.ownerID)
            .frame(width: width - 14, height: height - 25).clipped()
            .padding(.horizontal, 7).padding(.top, 7).padding(.bottom, 18)
            .background(Color.foamWhite)
            .shadow(color: .espressoBrown.opacity(0.1), radius: 9, x: 0, y: 5)
    }
}

private struct WeeklyPourTurningMemory: View {
    let moment: WeeklyPourMoment
    let ownerID: UUID
    let flipped: Bool
    let reduced: Bool

    var body: some View {
        ZStack {
            WeeklyPourPhotoView(moment: moment, ownerID: ownerID)
                .overlay(alignment: .topTrailing) {
                    if let rating = moment.recordedRating {
                        Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                            .font(.headline).padding(.horizontal, 14).padding(.vertical, 10)
                            .foregroundStyle(Color.espressoBrown).background(Color.creamWhite, in: Capsule())
                            .padding(16).accessibilityLabel("\(rating.formatted()) out of 5")
                    }
                }
                .opacity(flipped ? 0 : 1)
            VStack(spacing: 18) {
                Image(systemName: "quote.opening").font(.title).foregroundStyle(Color.mugshotSageText)
                Text(moment.caption ?? "").font(.system(.title2, design: .serif))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Label("YOUR SAVED CAPTION", systemImage: "lock")
                    .font(.caption2.weight(.semibold)).foregroundStyle(Color.roastBrown)
            }
            .padding(24).frame(maxWidth: .infinity, minHeight: 270)
            .background(Color.sandBeige).foregroundStyle(Color.espressoBrown)
            .rotation3DEffect(.degrees(reduced ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            .opacity(flipped ? 1 : 0)
        }
        .frame(minHeight: 270).clipShape(RoundedRectangle(cornerRadius: 20))
        .rotation3DEffect(.degrees(reduced || !flipped ? 0 : 180), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}
