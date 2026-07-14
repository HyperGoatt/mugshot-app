import SwiftUI

struct CapturePreferencesView: View {
    @EnvironmentObject private var authModel: AppAuthModel
    @Environment(\.dismiss) private var dismiss

    let allowsSkipping: Bool

    @State private var usualDrinkFamilies: Set<String> = []
    @State private var cafeHomeHabit: String?
    @State private var discoveryIntents: Set<String> = []
    @State private var hasLoaded = false

    private let drinkFamilies = ["Espresso", "Filter coffee", "Cold coffee", "Matcha", "Tea", "Other"]
    private let habits = [
        PreferenceOption(id: "cafe", title: "Mostly cafe", icon: "cup.and.saucer.fill"),
        PreferenceOption(id: "home", title: "Mostly Home", icon: "house.fill"),
        PreferenceOption(id: "both", title: "A mix of both", icon: "arrow.left.arrow.right")
    ]
    private let intents = [
        PreferenceOption(id: "nearby", title: "Find nearby cafes", icon: "location.fill"),
        PreferenceOption(id: "friends", title: "Follow friends’ finds", icon: "person.2.fill"),
        PreferenceOption(id: "taste", title: "Understand my taste", icon: "sparkles"),
        PreferenceOption(id: "home", title: "Improve home brewing", icon: "scalemass.fill")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    drinkSection
                    habitSection
                    discoverySection

                    if let error = authModel.capturePreferencesError {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.roastBrown)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Preference save error. \(error)")
                    }

                    saveButton

                    if allowsSkipping {
                        Button("Skip for now") {
                            Task {
                                if await authModel.skipCapturePreferences() {
                                    dismiss()
                                }
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.roastBrown)
                        .frame(maxWidth: .infinity)
                        .disabled(authModel.isSavingCapturePreferences)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
            .background(Color.creamWhite)
            .toolbar {
                if !allowsSkipping {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(authModel.isSavingCapturePreferences)
        .onAppear(perform: loadStoredPreferences)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(allowsSkipping ? "Make Mugshot yours" : "Your coffee preferences")
                .mugshotDisplay(size: 34)
                .foregroundColor(.espressoBrown)
                .fixedSize(horizontal: false, vertical: true)

            Text("Three optional choices help shape Your Mix and suggested journal details. Change them anytime.")
                .font(.system(size: 15))
                .foregroundColor(.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var drinkSection: some View {
        preferenceCard(number: "01", title: "What do you usually drink?", subtitle: "Choose any that feel familiar.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(drinkFamilies, id: \.self) { family in
                    selectionChip(
                        title: family,
                        isSelected: usualDrinkFamilies.contains(family)
                    ) {
                        toggle(family, in: &usualDrinkFamilies)
                    }
                }
            }
        }
    }

    private var habitSection: some View {
        preferenceCard(number: "02", title: "Where does coffee fit?", subtitle: "This only changes useful defaults.") {
            VStack(spacing: 9) {
                ForEach(habits) { option in
                    optionRow(option, isSelected: cafeHomeHabit == option.id) {
                        cafeHomeHabit = cafeHomeHabit == option.id ? nil : option.id
                    }
                }
            }
        }
    }

    private var discoverySection: some View {
        preferenceCard(number: "03", title: "What would you like to discover?", subtitle: "Choose any, or leave this open.") {
            VStack(spacing: 9) {
                ForEach(intents) { option in
                    optionRow(option, isSelected: discoveryIntents.contains(option.id)) {
                        toggle(option.id, in: &discoveryIntents)
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                let preferences = CapturePreferences(
                    usualDrinkFamilies: Array(usualDrinkFamilies),
                    cafeHomeHabit: cafeHomeHabit,
                    discoveryIntents: Array(discoveryIntents),
                    setupCompletedAt: authModel.capturePreferences.setupCompletedAt
                )
                if await authModel.saveCapturePreferences(preferences) {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if authModel.isSavingCapturePreferences {
                    ProgressView().tint(.foamWhite)
                }
                Text("Save preferences")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(authModel.isSavingCapturePreferences)
    }

    private func preferenceCard<Content: View>(
        number: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Text(number)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.mugshotSage)
                    .frame(width: 38, height: 38)
                    .background(Color.mugshotSage.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.espressoBrown)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.tertiaryText)
                }
            }

            content()
        }
        .padding(16)
        .cardStyle()
    }

    private func selectionChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .foamWhite : .espressoBrown)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
                .background(isSelected ? Color.mugshotSage : Color.sandBeige.opacity(0.58))
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(isSelected ? Color.clear : Color.roastBrown.opacity(0.12), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func optionRow(_ option: PreferenceOption, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .foamWhite : .mugshotSage)
                    .frame(width: 34, height: 34)
                    .background(isSelected ? Color.mugshotSage : Color.mugshotSage.opacity(0.13))
                    .clipShape(Circle())

                Text(option.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.espressoBrown)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? .mugshotSage : .tertiaryText.opacity(0.6))
            }
            .frame(minHeight: 48)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.mugshotMint.opacity(0.45) : Color.sandBeige.opacity(0.46))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggle(_ value: String, in values: inout Set<String>) {
        if values.contains(value) {
            values.remove(value)
        } else {
            values.insert(value)
        }
    }

    private func loadStoredPreferences() {
        guard !hasLoaded else { return }
        hasLoaded = true
        usualDrinkFamilies = Set(authModel.capturePreferences.usualDrinkFamilies)
        cafeHomeHabit = authModel.capturePreferences.cafeHomeHabit
        discoveryIntents = Set(authModel.capturePreferences.discoveryIntents)
    }
}

private struct PreferenceOption: Identifiable {
    let id: String
    let title: String
    let icon: String
}
