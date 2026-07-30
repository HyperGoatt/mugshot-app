import SwiftUI

struct SafetyReportDetailsSheet: View {
    private static let maximumDetailsLength = 2_000

    let targetLabel: String
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var details = ""

    private var trimmedDetails: String {
        details.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Tell us what happened",
                        text: $details,
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                    .accessibilityLabel("Report details")
                    .onChange(of: details) { _, value in
                        guard value.count > Self.maximumDetailsLength else { return }
                        details = String(value.prefix(Self.maximumDetailsLength))
                    }
                    Text("\(details.count) of \(Self.maximumDetailsLength.formatted()) characters")
                        .font(.caption)
                        .foregroundStyle(Color.tertiaryText)
                        .accessibilityLabel(
                            "\(details.count) of \(Self.maximumDetailsLength) report detail characters used"
                        )
                } header: {
                    Text("Report \(targetLabel)")
                } footer: {
                    Text("Add enough context to identify the concern. Do not include passwords or private account credentials. Reports are limited to 2,000 characters.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Add report details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        let value = trimmedDetails
                        dismiss()
                        onSubmit(value)
                    }
                    .disabled(trimmedDetails.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(.mugshotSage)
    }
}

struct EditCommentSheet: View {
    let initialText: String
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(
        initialText: String,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (String) -> Void
    ) {
        self.initialText = initialText
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Comment") {
                    TextField("Comment", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityLabel("Comment text")
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.red)
                            .accessibilityElement(children: .combine)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.creamWhite)
            .navigationTitle("Edit comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        onSave(trimmedText)
                    }
                    .disabled(
                        isSaving
                            || trimmedText.isEmpty
                            || trimmedText == initialText.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .presentationDetents([.medium])
        .tint(.mugshotSage)
    }
}
