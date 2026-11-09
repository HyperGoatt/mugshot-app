import SwiftUI

/// Composed editor surfaces share the library's palette and readable cards.
/// The content boundary also keeps large editor view values off the iPhone stack.
struct HomeEditorCanvas: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let detail: String
    let symbol: String
    let eyebrow: String
    private let showsKeyboardDone: Bool
    private let content: AnyView

    init<Content: View>(title: String, detail: String, symbol: String,
                        eyebrow: String = "HOME LIBRARY", showsKeyboardDone: Bool = true,
                        @ViewBuilder content: () -> Content) {
        self.title = title; self.detail = detail; self.symbol = symbol; self.eyebrow = eyebrow
        self.showsKeyboardDone = showsKeyboardDone
        self.content = AnyView(content())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: symbol).font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(Color.mugshotMint.opacity(0.42), in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityHidden(true)
                        Text(eyebrow).font(.caption.weight(.bold)).tracking(1.5)
                    }
                    .foregroundStyle(Color.mugshotSageText)
                    Text(title).font(.system(.largeTitle, design: .serif).weight(.semibold))
                        .foregroundStyle(Color.espressoBrown)
                    Text(detail).font(.subheadline).foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
                content
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 28)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(typeSize.isAccessibilitySize ? "home.editor.layout.accessibility" : "home.editor.layout.regular")
        }
        .background(Color.creamWhite)
        .scrollDismissesKeyboard(.interactively)
        .tint(Color.mugshotSageText)
        .toolbar {
            if showsKeyboardDone {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .accessibilityIdentifier("home.editor.keyboardDone")
                }
            }
        }
    }
}

struct HomeEditorSection: View {
    let title: String
    let symbol: String?
    let detail: String?
    private let content: AnyView

    init<Content: View>(_ title: String, symbol: String? = nil, detail: String? = nil,
                        @ViewBuilder content: () -> Content) {
        self.title = title; self.symbol = symbol; self.detail = detail
        self.content = AnyView(content())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if let symbol { Image(systemName: symbol).foregroundStyle(Color.mugshotSageText).accessibilityHidden(true) }
                    Text(title).font(.headline).foregroundStyle(Color.espressoBrown)
                }
                if let detail { Text(detail).font(.caption).foregroundStyle(Color.secondaryText) }
            }
            content
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.foamWhite, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.mugshotLine))
        .foregroundStyle(Color.espressoBrown)
        .textFieldStyle(.plain)
        .buttonStyle(.borderless)
        .tint(Color.mugshotSageText)
    }
}

struct HomeEditorField: View {
    let title: String
    @Binding var text: String
    var placeholder = ""
    var axis: Axis = .horizontal
    var identifier: String?

    init(_ title: String, text: Binding<String>, placeholder: String = "", axis: Axis = .horizontal,
         identifier: String? = nil) {
        self.title = title; _text = text; self.placeholder = placeholder; self.axis = axis; self.identifier = identifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Color.secondaryText)
            TextField(placeholder, text: $text, axis: axis)
                .font(.body).lineLimit(axis == .vertical ? 3...8 : 1...1)
                .frame(minHeight: 44, alignment: .topLeading)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier ?? title)
        }
    }
}

struct HomeEditorError: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.callout).foregroundStyle(Color.red)
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .combine)
    }
}

struct HomeEditorRowActions: View {
    let label: String
    let removeTitle: String
    let canMoveEarlier: Bool
    let canMoveLater: Bool
    let identifier: String
    let onMoveEarlier: () -> Void
    let onMoveLater: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Menu {
            Button("Move earlier", systemImage: "arrow.up", action: onMoveEarlier).disabled(!canMoveEarlier)
            Button("Move later", systemImage: "arrow.down", action: onMoveLater).disabled(!canMoveLater)
            Button(role: .destructive, action: onRemove) { Label(removeTitle, systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis").font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Color.mugshotMint.opacity(0.28), in: Circle())
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

enum HomeEditorBindings {
    /// Reordering or removing a row cannot redirect a delayed text edit to the
    /// old array position, nor can it recreate a row the user removed.
    static func item<Item: Identifiable>(_ original: Item, in values: Binding<[Item]>) -> Binding<Item> {
        Binding(get: { values.wrappedValue.first { $0.id == original.id } ?? original }, set: { changed in
            guard let index = values.wrappedValue.firstIndex(where: { $0.id == original.id }) else { return }
            values.wrappedValue[index] = changed
        })
    }
}
