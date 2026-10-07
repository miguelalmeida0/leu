import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Welcome (01): what an empty library looks like. A knitting basket with a loose strand of
/// yarn that sways very slowly, an invitation to say what you have been meaning to
/// understand, and two ways in: bring your own PDF, or start with a sample book.
///
/// What you type is kept on this device and shown on Home as the thing you came for.
@MainActor
struct WelcomeScreen: View {
    let library: LibraryModel
    @AppStorage(WelcomeScreen.intentionKey) private var intention = ""
    @State private var importing = false
    @FocusState private var writing: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    static let intentionKey = "leu.welcome.intention"
    private static let suggestions = ["the book I gave up on", "my thesis papers", "how money actually works", "lecture notes from this term"]

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 900 && proxy.size.width > proxy.size.height && !typeSize.isAccessibilitySize
            ScrollView {
                if wide {
                    HStack(alignment: .center, spacing: 40) {
                        KnittingBasket().frame(maxWidth: proxy.size.width * 0.52)
                        words.frame(maxWidth: 540, alignment: .leading)
                    }
                    .padding(.horizontal, 40)
                    .frame(minHeight: proxy.size.height)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        KnittingBasket().frame(maxWidth: 560).frame(maxWidth: .infinity)
                        words.padding(.horizontal, 22).padding(.bottom, 30)
                    }
                    .frame(maxWidth: 640).frame(maxWidth: .infinity)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(LeuDesign.felt.ignoresSafeArea())
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            library.importPickerResult(result)
        }
        .accessibilityIdentifier("welcome-screen")
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text("HELLO, AND WELCOME")
                    .font(LeuDesign.eyebrow(11)).tracking(LeuDesign.eyebrowTracking)
                    .foregroundStyle(LeuDesign.eyebrowOnFelt)
                Text("Make yourself comfortable.")
                    .font(LeuDesign.display(52)).tracking(-1.8)
                    .foregroundStyle(LeuDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Leu is a quiet place to read the things you actually want to understand. It keeps you company, remembers where you got stuck, and always takes you back to the page.")
                    .font(.leu(.body, weight: .medium))
                    .foregroundStyle(LeuDesign.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("SOMETHING YOU'VE BEEN MEANING TO UNDERSTAND")
                    .font(LeuDesign.eyebrow(10)).tracking(LeuDesign.eyebrowTracking)
                    .foregroundStyle(LeuDesign.eyebrowOnFelt)
                TextField("", text: $intention)
                    .font(.leu(.title3, serif: true))
                    .foregroundStyle(LeuDesign.ink)
                    .tint(LeuDesign.redThread)
                    .focused($writing)
                    .submitLabel(.done)
                    .onSubmit { writing = false }
                    .overlay(alignment: .leading) {
                        // A drawn placeholder: the system prompt is easy to lose on custom fills.
                        if intention.isEmpty {
                            Text("why the sky is blue")
                                .font(.leu(.title3, serif: true))
                                .foregroundStyle(LeuDesign.fieldPlaceholder)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                    .background(LeuDesign.cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(writing ? LeuDesign.ink : LeuDesign.line, lineWidth: writing ? 1.5 : 1)
                    }
                    .accessibilityLabel("Something you've been meaning to understand")
                    .accessibilityHint("Optional. Leu keeps it on this device and reminds you of it on Home.")
                    .accessibilityIdentifier("welcome-intention")
                SentenceFlow(spacing: 8, lineSpacing: 8) {
                    ForEach(Self.suggestions, id: \.self) { suggestion in
                        Button(suggestion) { intention = suggestion }
                            .font(.leu(.footnote, weight: .semibold))
                            .foregroundStyle(LeuDesign.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(LeuDesign.feltLight, in: Capsule())
                            .frame(minHeight: 44)
                            .contentShape(Capsule())
                            .buttonStyle(.plain)
                    }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { primary; sample }
                VStack(alignment: .leading, spacing: 8) { primary; sample }
            }
            Text("Everything stays on this \(LeuPlatform.deviceName), including Leu's thinking.")
                .font(.leu(.footnote))
                .foregroundStyle(LeuDesign.secondary)
        }
    }

    private var trimmed: String { intention.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var primary: some View {
        Button(trimmed.isEmpty ? "Bring a PDF" : "Bring a PDF about it") { importing = true }
            .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
            .accessibilityIdentifier("welcome-import-pdf")
    }

    private var sample: some View {
        Button("or start with a sample book") {
            guard let url = Bundle.main.url(forResource: "Computer Science Essentials", withExtension: "pdf") else { return }
            library.enqueue([url])
        }
        .font(.leu(.subheadline, weight: .bold))
        .underline()
        .foregroundStyle(LeuDesign.ink)
        .frame(minHeight: LeuDesign.touchTarget)
        .accessibilityHint("Adds a short book about computer science to your library")
        .accessibilityIdentifier("welcome-sample")
    }
}

/// The basket render with a strand of yarn drawn live from the needle to the loose ball.
/// It sways a few points over many seconds; Reduce Motion holds it still.
struct KnittingBasket: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // In the asset's unit space: the right needle's tip, and the upper-left edge of the loose ball.
    private static let tip = CGPoint(x: 0.5535, y: 0.0356)
    private static let ball = CGPoint(x: 0.662, y: 0.624)
    static let aspect: CGFloat = 1559.0 / 1147.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.draw(Image("Welcome/Basket"), in: rect)
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let sway = CGFloat(sin(t * 0.45) * 0.006 + sin(t * 0.21 + 1.3) * 0.004)
                let tip = CGPoint(x: Self.tip.x * size.width, y: Self.tip.y * size.height)
                let ball = CGPoint(x: Self.ball.x * size.width, y: Self.ball.y * size.height)
                var yarn = Path()
                yarn.move(to: tip)
                yarn.addCurve(to: ball,
                              control1: CGPoint(x: (Self.tip.x + 0.008 + sway) * size.width, y: 0.42 * size.height),
                              control2: CGPoint(x: (Self.ball.x - 0.07 - sway * 0.6) * size.width, y: (Self.ball.y + 0.012) * size.height))
                context.stroke(yarn, with: .color(Color(hex: 0xC98476)), lineWidth: max(1.5, size.width * 0.0024))
                context.stroke(yarn, with: .color(Color(hex: 0xEBB5A3)), lineWidth: max(0.8, size.width * 0.0012))
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("A knitting basket with yarn and a half-finished striped blanket")
        .accessibilityAddTraits(.isImage)
    }
}
