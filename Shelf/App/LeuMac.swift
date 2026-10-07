import SwiftUI
import UIKit

/// Where Leu is running, in the words the interface uses.
enum LeuPlatform {
    static var isMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return ProcessInfo.processInfo.isiOSAppOnMac
        #endif
    }

    /// "iPhone", "iPad" or "Mac", for sentences like "Everything stays on this Mac."
    static var deviceName: String { isMac ? "Mac" : UIDevice.current.localizedModel }
}

extension Notification.Name {
    static let leuNavigate = Notification.Name("leu.navigate")
    static let leuImportPDF = Notification.Name("leu.importPDF")
    static let leuPresentPDFPicker = Notification.Name("leu.presentPDFPicker")
}

/// The Mac menu bar: Go to each place with ⌘1–⌘6, and bring a PDF with ⌘O.
struct LeuCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Bring a PDF…") { NotificationCenter.default.post(name: .leuImportPDF, object: nil) }
                .keyboardShortcut("o")
        }
        CommandMenu("Go") {
            ForEach(Array(PrimaryArea.allCases.enumerated()), id: \.element) { index, area in
                Button(area.title) { NotificationCenter.default.post(name: .leuNavigate, object: area) }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
            }
        }
    }
}

/// Answers the menu commands inside the window.
struct LeuCommandReceiver: ViewModifier {
    @Binding var area: PrimaryArea

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .leuNavigate)) { note in
                if let next = note.object as? PrimaryArea { area = next }
            }
            .onReceive(NotificationCenter.default.publisher(for: .leuImportPDF)) { _ in
                area = .shelf
                // Let the Library appear before it is asked to open the picker.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    NotificationCenter.default.post(name: .leuPresentPDFPicker, object: nil)
                }
            }
            .modifier(MacWindowChrome())
    }
}

/// On the Mac the felt runs edge to edge: no title bar or toolbar strip, the traffic
/// lights sit on the felt, and the window opens at a size the desktop layouts were drawn for.
struct MacWindowChrome: ViewModifier {
    func body(content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        content.background(MacWindowConfigurator().frame(width: 0, height: 0))
        #else
        content
        #endif
    }
}

#if targetEnvironment(macCatalyst)
private struct MacWindowConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async { Self.configure(view.window?.windowScene) }
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async { Self.configure(view.window?.windowScene) }
    }

    @MainActor private static var sized = Set<ObjectIdentifier>()

    @MainActor static func configure(_ scene: UIWindowScene?) {
        guard let scene else { return }
        if let titlebar = scene.titlebar {
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
            titlebar.separatorStyle = .none
        }
        scene.title = "Leu"
        scene.sizeRestrictions?.minimumSize = CGSize(width: 1080, height: 720)
        // Open once at the 1440 × 900 composition the desktop screens were designed at.
        let id = ObjectIdentifier(scene)
        guard !sized.contains(id) else { return }
        sized.insert(id)
        let current = scene.effectiveGeometry.systemFrame
        guard current.width < 1300 else { return }
        let target = CGRect(x: current.midX - 720, y: current.midY - 450, width: 1440, height: 900)
        scene.requestGeometryUpdate(.Mac(systemFrame: target)) { _ in }
    }
}
#endif
