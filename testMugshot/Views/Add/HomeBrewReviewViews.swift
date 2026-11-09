import SwiftUI
import UIKit

struct HomeBrewReviewPresentation {
    let comparison: HomeAttemptComparison
    let versionNumber: Int?
    let onMakeAgain: () -> Void
}

struct HomeBrewReviewCard: View {
    let review: HomeBrewReviewPresentation
    @Environment(\.dynamicTypeSize) private var typeSize

    private var comparison: HomeAttemptComparison { review.comparison }
    private var showsLast: Bool { comparison.hasPriorReadings }

    var body: some View {
        HomeEditorSection("Compare your brew", symbol: "chart.bar.xaxis", detail: review.versionNumber.map { "Recipe v\($0)" }) {
            if !comparison.rows.isEmpty {
                if !typeSize.isAccessibilitySize {
                    HStack(spacing: 6) {
                        Text("Measurement").frame(maxWidth: .infinity, alignment: .leading)
                        column("Plan")
                        column("Actual")
                        if showsLast { column("Last time") }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.mugshotSageText)
                    .accessibilityHidden(true)
                }
                ForEach(comparison.rows) { row in
                    Divider()
                    measurement(row)
                }
                if showsLast, let date = comparison.priorDate {
                    Text("Last time: \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                Text(showsLast
                     ? "Blank values weren’t recorded."
                     : "Blank values weren’t recorded. Last time appears after a comparable brew has measurements.")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            } else {
                Text("No measurements were recorded for this sip.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }

            Button(action: review.onMakeAgain) {
                Label("Make again", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("home.brewReview.makeAgain")
        }
    }

    private func measurement(_ row: HomeAttemptComparison.Row) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 5) {
                    Text(row.title).font(.subheadline.weight(.semibold))
                    LabeledContent("Plan", value: row.planned?.display ?? "")
                    LabeledContent("Actual", value: row.actual?.display ?? "")
                    if showsLast { LabeledContent("Last time", value: row.last?.display ?? "") }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(row.title).font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    column(row.planned?.display ?? "")
                    column(row.actual?.display ?? "").foregroundStyle(Color.mugshotSageText)
                    if showsLast { column(row.last?.display ?? "") }
                }
            }
        }
        .font(.caption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([
            row.title,
            "Plan: \(row.planned?.display ?? "Not recorded")",
            "Actual: \(row.actual?.display ?? "Not recorded")",
            showsLast ? "Last time: \(row.last?.display ?? "Not recorded")" : nil
        ].compactMap { $0 }.joined(separator: ", "))
    }

    private func column(_ value: String) -> some View {
        Text(value).monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HomeBrewRepeatSheet: View {
    let choices: [HomeAttemptComparison.Row]
    let onSamePlan: () -> Void
    let onChange: (HomeBrewPlanChange) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var selection: HomeAttemptComparison.Key?
    @State private var input = ""

    private var chosen: HomeAttemptComparison.Row? { choices.first { $0.key == selection } }
    private var change: HomeBrewPlanChange? {
        guard let chosen, let expected = chosen.planned?.amount,
              case .set(let amount) = HomeSetupNumbers.edit(input, replacing: "", locale: locale,
                  allowed: HomeBrewPlanChange.range(for: chosen.key)), amount != expected else { return nil }
        return HomeBrewPlanChange(key: chosen.key, expected: expected, amount: amount)
    }

    var body: some View {
        NavigationStack {
            HomeEditorCanvas(title: "Make it again.", detail: "Start with the same plan, or change one thing and see how it tastes.",
                             symbol: "arrow.counterclockwise", eyebrow: "NEXT BREW", showsKeyboardDone: false) {
                Button(action: onSamePlan) {
                    Label("Use the same plan", systemImage: "cup.and.saucer")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("home.repeat.samePlan")

                HomeEditorSection("Change one thing", symbol: "slider.horizontal.3",
                                  detail: "This change applies to the next brew. Your saved recipe and earlier sip stay as they were.") {
                    Menu {
                        ForEach(choices) { row in
                            Button(row.title) { selection = row.key; input = "" }
                        }
                    } label: {
                        Label(chosen?.title ?? "Choose a measurement", systemImage: "chevron.up.chevron.down")
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("home.repeat.chooseMeasurement")

                    if let chosen, let planned = chosen.planned {
                        Text("Current plan: \(planned.display)")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                        VStack(alignment: .leading, spacing: 5) {
                            let label = chosen.unit.isEmpty ? "New amount" : "New amount (\(chosen.unit))"
                            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
                            HomeBrewAmountField(text: $input, label: label, acceptsNegative: chosen.key == .temperature)
                                .frame(minHeight: 44)
                                .id(chosen.key)
                        }
                        Button {
                            if let change { onChange(change) }
                        } label: {
                            Text("Start with this change").frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(change == nil)
                        .accessibilityIdentifier("home.repeat.apply")
                    }
                }
            }
            .navigationTitle("Make again")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

/// Let the native field own its live buffer. SwiftUI field refreshes during
/// keyboard dismissal can otherwise restore a value from the previous digit.
private struct HomeBrewAmountField: UIViewRepresentable {
    @Binding var text: String
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17
    let label: String
    let acceptsNegative: Bool

    func makeCoordinator() -> Coordinator { Coordinator($text) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = "Enter a value"
        field.keyboardType = acceptsNegative ? .numbersAndPunctuation : .decimalPad
        field.returnKeyType = .done
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.tintColor = UIColor(Color.mugshotSageText)
        field.textColor = UIColor(Color.espressoBrown)
        field.accessibilityIdentifier = "home.repeat.amount"
        field.delegate = context.coordinator
        context.coordinator.field = field
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        let toolbar = UIToolbar()
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(Coordinator.done))
        done.accessibilityIdentifier = "home.repeat.keyboardDone"
        toolbar.items = [UIBarButtonItem(systemItem: .flexibleSpace), done]
        toolbar.sizeToFit()
        field.inputAccessoryView = toolbar
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.text = $text
        field.accessibilityLabel = label
        if field.font?.pointSize != fontSize { field.font = .systemFont(ofSize: fontSize) }
        if !field.isFirstResponder && field.text != text { field.text = text }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        weak var field: UITextField?

        init(_ text: Binding<String>) { self.text = text }

        @objc func changed(_ field: UITextField) {
            let updated = field.text ?? ""
            if text.wrappedValue != updated { text.wrappedValue = updated }
        }

        @objc func done() {
            guard let field else { return }
            changed(field)
            field.resignFirstResponder()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool { done(); return false }
    }
}
