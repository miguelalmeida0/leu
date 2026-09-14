import SwiftUI

/// Opaque, bounded, scrollable menu. The system owns placement and dismissal,
/// while Leu owns every pixel behind readable content, including the popover arrow.
struct LeuMenu<Content: View, Label: View>: View {
    @ViewBuilder let content: () -> Content
    @ViewBuilder let label: () -> Label
    @State private var presented = false

    var body: some View {
        Button { presented = true } label: { label() }
            .buttonStyle(.plain)
            .popover(isPresented: $presented) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        content()
                        Button("Close menu", systemImage: "xmark") { presented = false }
                    }
                    .padding(16)
                }
                .frame(idealWidth: 320, maxWidth: 380, idealHeight: 420, maxHeight: 560)
                .foregroundStyle(LeuDesign.menuForeground)
                .background(LeuDesign.menuSurface)
                .tint(LeuDesign.signal)
                .buttonStyle(LeuMenuActionStyle())
                .pickerStyle(.inline)
                .preferredColorScheme(.dark)
                .presentationBackground(LeuDesign.menuSurface)
                .presentationCompactAdaptation(.popover)
                .accessibilityAction(.escape) { presented = false }
            }
    }
}

extension LeuMenu where Label == Text {
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.label = { Text(title) }
    }
}

/// Actions close only their presenting menu/dialog, after invoking the original callback.
private struct LeuMenuActionStyle: PrimitiveButtonStyle {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.trigger()
            dismiss()
        } label: {
            configuration.label
                .font(.body)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .foregroundStyle(enabled ? (configuration.role == .destructive ? LeuDesign.danger : LeuDesign.menuForeground) : LeuDesign.disabledForeground)
                .padding(.horizontal, 10)
                .background(LeuDesign.menuSurface)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Explicit placeholder and focus contrast, independent of the surrounding color scheme.
struct LeuTextField: View {
    let title: String
    @Binding var text: String
    @FocusState private var focused: Bool

    init(_ title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }

    var body: some View {
        TextField(title, text: $text, prompt: Text(title).foregroundStyle(LeuDesign.fieldPlaceholder))
            .textFieldStyle(.plain)
            .foregroundStyle(LeuDesign.fieldForeground)
            .tint(LeuDesign.signal)
            .focused($focused)
            .padding(10)
            .frame(minHeight: 44)
            .background(LeuDesign.fieldSurface, in: RoundedRectangle(cornerRadius: LeuDesign.smallRadius))
            .overlay {
                RoundedRectangle(cornerRadius: LeuDesign.smallRadius)
                    .stroke(focused ? LeuDesign.signal : LeuDesign.separator, lineWidth: focused ? 2 : 1)
            }
    }
}

extension View {
    func leuContextMenu<Actions: View>(@ViewBuilder actions: @escaping () -> Actions) -> some View {
        padding(.trailing, 48)
            .overlay(alignment: .trailing) {
                LeuMenu(content: actions) {
                    Image(systemName: "ellipsis").leuTapTarget()
                        .foregroundStyle(LeuDesign.textPrimary)
                }
                .accessibilityLabel("Stop actions")
            }
    }

    func leuDialog<Actions: View, Message: View>(
        _ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder message: @escaping () -> Message
    ) -> some View {
        sheet(isPresented: isPresented) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    message().foregroundStyle(LeuDesign.menuSecondary)
                    actions()
                    Button("Close", role: .cancel) { isPresented.wrappedValue = false }
                }.padding(24)
            }
            .foregroundStyle(LeuDesign.menuForeground)
            .background(LeuDesign.menuSurface)
            .buttonStyle(LeuMenuActionStyle())
            .tint(LeuDesign.signal)
            .preferredColorScheme(.dark)
            .presentationBackground(LeuDesign.menuSurface)
            .presentationDetents([.medium, .large])
            .accessibilityAction(.escape) { isPresented.wrappedValue = false }
        }
    }

    func leuDialog<Actions: View>(
        _ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        leuDialog(title, isPresented: isPresented, titleVisibility: titleVisibility,
                  actions: actions, message: { EmptyView() })
    }

    func leuDialog<Data, Actions: View, Message: View>(
        _ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
        presenting data: Data?, @ViewBuilder actions: @escaping (Data) -> Actions,
        @ViewBuilder message: @escaping (Data) -> Message
    ) -> some View {
        leuDialog(title, isPresented: isPresented, titleVisibility: titleVisibility) {
            if let data { actions(data) }
        } message: {
            if let data { message(data) }
        }
    }

    func leuDialog<Data, Actions: View>(
        _ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
        presenting data: Data?, @ViewBuilder actions: @escaping (Data) -> Actions
    ) -> some View {
        leuDialog(title, isPresented: isPresented, titleVisibility: titleVisibility,
                  presenting: data, actions: actions, message: { _ in EmptyView() })
    }
}
