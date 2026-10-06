import ShelfCore
import SwiftUI

/// Home: "We kept your spot warm."
///
/// The book you were in the middle of, one way back into it, and the evening nook. On wide
/// screens (iPad landscape) it follows the desktop composition: words on the left, the
/// window and daybed to the right. Everywhere else, and at accessibility text sizes, it
/// reflows into a single column so nothing ever overlaps.
@MainActor
struct HomeScreen: View {
    let library: LibraryModel
    let openLibrary: () -> Void
    @State private var rain = RainSound()
    @AppStorage(WelcomeScreen.intentionKey) private var intention = ""
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if library.snapshot.activeBooks.isEmpty && library.importLabel == nil {
                WelcomeScreen(library: library)
            } else {
                GeometryReader { proxy in
                    let size = proxy.size
                    if size.width >= 820, size.width > size.height * 1.05, !dynamicTypeSize.isAccessibilitySize {
                        wide(size)
                    } else {
                        stacked(size)
                    }
                }
            }
        }
        .background(LeuDesign.felt.ignoresSafeArea())
        .onDisappear { rain.stop() }
        .accessibilityIdentifier("home-screen")
    }

    // MARK: - Layouts

    /// The desktop composition, scaled to fit. The scene keeps its proportions; the words
    /// keep their Dynamic Type sizes.
    private func wide(_ size: CGSize) -> some View {
        let scale = min(size.width / 1440, size.height / 840)
        let inset = (size.width - 1440 * scale) / 2
        return ZStack(alignment: .topLeading) {
            lampGlow(center: CGPoint(x: inset + 250 * scale, y: 230 * scale), radius: 470 * scale)
            HomeNookScene(scale: scale)
                .offset(x: inset + 270 * scale, y: 6 * scale)
            intro(titleSize: 46)
                .frame(width: max(300, 390 * scale), alignment: .leading)
                .offset(x: inset + max(40, 64 * scale), y: max(24, 96 * scale))
            rainToggle
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, max(28, 64 * scale))
                .padding(.bottom, 22)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func stacked(_ size: CGSize) -> some View {
        let sceneWidth = min(size.width - 24, 720)
        let scale = sceneWidth / HomeNookScene.designSize.width
        return ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                intro(titleSize: size.width < 400 ? 36 : 42)
                    .padding(.horizontal, LeuDesign.gutter)
                    .padding(.top, 24)
                HomeNookScene(scale: scale)
                    .frame(maxWidth: .infinity)
                rainToggle
                    .padding(.horizontal, LeuDesign.gutter)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .topLeading) {
                lampGlow(center: CGPoint(x: 80, y: 120), radius: 380).allowsHitTesting(false)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func lampGlow(center: CGPoint, radius: CGFloat) -> some View {
        RadialGradient(colors: [Color(hex: 0xFFE2A0, opacity: 0.38), Color(hex: 0xFFE2A0, opacity: 0)],
                       center: .center, startRadius: 0, endRadius: radius)
            .frame(width: radius * 2, height: radius * 2)
            .offset(x: center.x - radius, y: center.y - radius)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Words

    private var lastBook: Book? {
        let books = library.snapshot.activeBooks
        return books.filter { $0.lastOpenedAt != nil }.max { ($0.lastOpenedAt ?? .distantPast) < ($1.lastOpenedAt ?? .distantPast) }
            ?? books.max { $0.importedAt < $1.importedAt }
    }

    private func intro(titleSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Self.greeting(for: Date()).uppercased())
                .font(LeuDesign.eyebrow(11))
                .tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(LeuDesign.secondary)
            Text("We kept your spot warm.")
                .font(LeuType.sans(titleSize, weight: .heavy))
                .tracking(-titleSize * 0.045)
                .lineSpacing(-titleSize * 0.08)
                .foregroundStyle(LeuDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .accessibilityAddTraits(.isHeader)
            Text(lastBook == nil ? "Bring a PDF and it will be waiting here." : "Quilt, tea and rain.")
                .font(LeuType.sans(18, weight: .medium))
                .foregroundStyle(LeuDesign.secondary)
                .padding(.top, 16)
            if let book = lastBook {
                bookLine(book).padding(.top, 34)
            }
            actions.padding(.top, 30)
            if !intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                intentionLine.padding(.top, 26)
            }
        }
    }

    private func bookLine(_ book: Book) -> some View {
        let progress = book.pageCount > 0 ? Double(book.currentPageNumber) / Double(book.pageCount) : 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(CoverColors(book.palette).background)
                    .frame(width: 10, height: 14)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                Text(book.title)
                    .font(.leu(.subheadline, weight: .bold))
                    .foregroundStyle(LeuDesign.ink)
                    .lineLimit(2)
                Text("page \(book.currentPageNumber) of \(book.pageCount)")
                    .font(.leu(.subheadline, weight: .medium).monospacedDigit())
                    .foregroundStyle(LeuDesign.tertiary)
            }
            Capsule()
                .fill(LeuDesign.ink.opacity(0.12))
                .frame(width: 240, height: 3)
                .overlay(alignment: .leading) {
                    Capsule().fill(LeuDesign.ink).frame(width: 240 * min(max(progress, 0.02), 1), height: 3)
                }
                .padding(.leading, 22)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.title), page \(book.currentPageNumber) of \(book.pageCount)")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent read")
    }

    private var actions: some View {
        HStack(alignment: .center, spacing: 22) {
            if let book = lastBook {
                Button("Keep reading") { library.open(book) }
                    .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
                    .accessibilityIdentifier("home-keep-reading")
                Button(action: openLibrary) {
                    Text("Something else")
                        .font(.leu(.subheadline, weight: .semibold))
                        .foregroundStyle(LeuDesign.secondary)
                        .padding(.bottom, 2)
                        .overlay(alignment: .bottom) { Rectangle().fill(LeuDesign.ink.opacity(0.3)).frame(height: 1.5) }
                        .leuTapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens your library")
            } else {
                Button("Bring a PDF", action: openLibrary)
                    .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
            }
        }
    }

    /// What you said on the welcome screen you came to understand, until you say you're done.
    private var intentionLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("You came to understand \(Text(intention).font(.leu(.footnote, serif: true)).italic()).")
                .font(.leu(.footnote, weight: .medium))
                .foregroundStyle(LeuDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Got it") { withAnimation(.easeInOut(duration: 0.6)) { intention = "" } }
                .font(.leu(.footnote, weight: .bold))
                .underline()
                .foregroundStyle(LeuDesign.ink)
                .frame(minHeight: LeuDesign.touchTarget)
                .accessibilityHint("Stops showing this reminder")
        }
    }

    private var rainToggle: some View {
        Button { rain.toggle() } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(rain.isPlaying ? LeuDesign.butter : LeuDesign.untested)
                    .frame(width: 8, height: 8)
                    .overlay { Circle().stroke(LeuDesign.ink.opacity(0.25), lineWidth: 0.5) }
                Text("Rain sound")
                    .font(.leu(.footnote, weight: .bold))
                    .foregroundStyle(LeuDesign.ink)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: LeuDesign.touchTarget)
            .background(LeuDesign.feltLight, in: Capsule(style: .continuous))
            .overlay { Capsule(style: .continuous).stroke(LeuDesign.line, lineWidth: LeuDesign.hairline) }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rain sound")
        .accessibilityValue(rain.isPlaying ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
        .accessibilityIdentifier("home-rain-sound")
    }

    static func greeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night"
        }
    }
}
