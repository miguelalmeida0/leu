import SwiftUI
import UIKit

struct ShelfButtonStyle: ButtonStyle {
    var filled = false
    func makeBody(configuration: Configuration) -> some View {
        LeuPrimaryButtonStyle(filled: filled).makeBody(configuration: configuration)
    }
}

@MainActor
struct IconButton: View {
    let symbol: String
    let label: String
    var active = false
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        if let accessibilityID {
            button.accessibilityIdentifier(accessibilityID)
        } else {
            button
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(active ? ShelfTheme.accent : ShelfTheme.text)
                .background(active ? ShelfTheme.raised : Color.clear, in: Circle())
                .overlay { Circle().stroke(active ? ShelfTheme.line : Color.clear, lineWidth: 0.8) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A non-interactive geometry marker used only by XCUITest.
/// It is absent from the production accessibility tree, so VoiceOver never sees test scaffolding.
@MainActor
struct UITestFrameProbe: UIViewRepresentable {
    let identifier: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        configure(view)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        configure(view)
    }

    private func configure(_ view: UIView) {
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
        view.isAccessibilityElement = testing
        view.accessibilityIdentifier = testing ? identifier : nil
        view.accessibilityLabel = testing ? identifier : nil
        view.accessibilityTraits = []
    }
}


/// UIKit-backed switch used for settings that must react on the first physical tap.
/// SwiftUI still owns the binding; UISwitch owns touch tracking and native accessibility state.
@MainActor
struct ShelfSwitch: UIViewRepresentable {
    @Binding var isOn: Bool
    let identifier: String
    let label: String
    var onChange: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UISwitch {
        let control = UISwitch(frame: .zero)
        control.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        configure(control)
        control.setOn(isOn, animated: false)
        return control
    }

    func updateUIView(_ control: UISwitch, context: Context) {
        context.coordinator.parent = self
        configure(control)
        if !control.isTracking, control.isOn != isOn {
            control.setOn(isOn, animated: false)
        }
    }

    private func configure(_ control: UISwitch) {
        control.onTintColor = UIColor(LeuDesign.signal)
        control.thumbTintColor = UIColor(LeuDesign.onSignal)
        control.isAccessibilityElement = true
        control.accessibilityIdentifier = identifier
        control.accessibilityLabel = label
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: ShelfSwitch

        init(parent: ShelfSwitch) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: UISwitch) {
            let newValue = sender.isOn
            if parent.isOn != newValue {
                parent.isOn = newValue
            }
            parent.onChange?(newValue)
        }
    }
}

@MainActor
struct EmptyLibraryState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: symbol).font(.system(size: 37, weight: .ultraLight))
                .foregroundStyle(ShelfTheme.accent).padding(.bottom, 8)
            Text(title).leuScaledFont(27, weight: .regular, design: .serif).multilineTextAlignment(.center)
            Text(message).font(.body).foregroundStyle(ShelfTheme.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 300)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(ShelfButtonStyle(filled: true)).padding(.top, 8)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 70).padding(.horizontal, 24)
    }
}

@MainActor
struct ShelfSheet<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            content().scrollContentBackground(.hidden).background(ShelfTheme.background)
                .foregroundStyle(LeuDesign.textPrimary)
                .pickerStyle(.inline)
                .toolbarBackground(LeuDesign.surfacePrimary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
        }.tint(ShelfTheme.accent).preferredColorScheme(.dark)
            .presentationBackground(LeuDesign.surfacePrimary)
    }
}
