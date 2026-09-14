import SwiftUI
import ShelfCore

@MainActor
struct ReaderBottomBar: View {
    @Bindable var model: ReaderModel
    @State private var scrubValue: Double = 0
    @State private var scrubbing = false
    @State private var showJump = false
    @State private var jumpText = ""
    @State private var lastChapterDetent: Int?

    var body: some View {
        VStack(spacing: 10) {
            if let plan = model.activeTimedPlan { timedPlanStatus(plan) }
            if let origin = model.searchReturnPage { searchReturnStatus(origin) }
            else if let message = model.savedMessage { savedStatus(message) }
            pageNavigation
            if model.speech.isSpeaking || model.speech.isPaused { VoicePlayerStrip(speech: model.speech) }
            if model.book.pageCount > 1 { scrubber }
            toolRow
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .foregroundStyle(ShelfTheme.text)
        .background(ShelfTheme.background.ignoresSafeArea(edges: .bottom))
        .background(UITestFrameProbe(identifier: "reader-bottom-bar-frame"))
        .overlay(alignment: .top) { ShelfTheme.line.frame(height: 0.5) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-bottom-bar")
        .disabled(model.isSaving)
        .onAppear { scrubValue = Double(model.pageIndex) }
        .onChange(of: model.pageIndex) { _, index in if !scrubbing { scrubValue = Double(index) } }
        .onChange(of: scrubValue) { _, value in
            guard scrubbing else { return }
            let page = Int(value.rounded())
            guard page != lastChapterDetent,
                  model.outline.contains(where: { $0.pageIndex == page && $0.isStructuralBoundary }) else { return }
            lastChapterDetent = page
            model.playHaptic(.chapterBoundary)
        }
        .leuDialog("Go to page", isPresented: $showJump) {
            LeuTextField("Page number", text: $jumpText)
                .keyboardType(.numberPad)
            Button("Go") {
                if let page = Int(jumpText), (1...model.book.pageCount).contains(page) {
                    model.go(to: page - 1)
                } else {
                    model.errorMessage = "Enter a page from 1 to \(model.book.pageCount)."
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var pageNavigation: some View {
        HStack(spacing: 8) {
            IconButton(symbol: "chevron.left", label: "Previous page", accessibilityID: "previous-page") {
                model.go(to: model.pageIndex - 1)
            }
            .disabled(model.pageIndex == 0)
            

            Button {
                jumpText = String(model.pageNumber)
                showJump = true
            } label: {
                VStack(spacing: 1) {
                    Text("\(scrubbing ? Int(scrubValue.rounded()) + 1 : model.pageNumber) / \(model.book.pageCount)")
                        .font(.callout.monospacedDigit().weight(.semibold))
                    if let section = scrubbing ? previewSectionTitle : model.currentOutlineTitle {
                        Text(section)
                            .font(.caption2)
                            .foregroundStyle(ShelfTheme.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("reader-page-count")
            .accessibilityLabel("Page \(model.pageNumber) of \(model.book.pageCount)")
            .accessibilityHint("Double tap to jump to a page")

            IconButton(symbol: "chevron.right", label: "Next page", accessibilityID: "next-page") {
                model.go(to: model.pageIndex + 1)
            }
            .disabled(model.pageNumber >= model.book.pageCount)
            

            Button { model.toggleSpeech() } label: {
                Image(systemName: model.speech.isSpeaking && !model.speech.isPaused ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(LeuDesign.onSignal)
                    .background(model.speech.isSpeaking ? ShelfTheme.olive : ShelfTheme.action, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.speech.isPaused ? "Resume reading" : (model.speech.isSpeaking ? "Pause reading" : "Read page aloud"))
            .accessibilityValue(model.speech.isPaused ? "Paused" : (model.speech.isSpeaking ? "Playing" : "Stopped"))
            .accessibilityIdentifier("speech-control")

            IconButton(
                symbol: model.isBookmarked ? "bookmark.fill" : "bookmark",
                label: "Bookmark",
                active: model.isBookmarked,
                accessibilityID: "bookmark-page"
            ) {
                Task { await model.toggleBookmark() }
            }
        }
        .frame(minHeight: 56)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-transport-row")
    }

    private var scrubber: some View {
        ReaderTrackingSlider(value: $scrubValue,
            range: 0...Double(max(1, model.book.pageCount - 1)), step: 1,
            label: "Page scrubber", identifier: "reader-scrubber",
            valueDescription: { "Page \(Int($0.rounded()) + 1) of \(model.book.pageCount)" }) { editing in
                if editing && !scrubbing {
                    scrubbing = true
                    lastChapterDetent = nil
                }
                if !editing {
                    scrubbing = false
                    lastChapterDetent = nil
                    model.go(to: Int(scrubValue.rounded()))
                }
            }
            .frame(height: 44)
    }

    private var previewSectionTitle: String? {
        let page = Int(scrubValue.rounded())
        return model.outline.last(where: { $0.pageIndex <= page && $0.source != .landmark })?.title
    }

    private var toolRow: some View {
        HStack(spacing: 0) {
            tool("list.bullet", "Contents", accessibilityID: "reader-tool-contents") { model.panel = .contents }
            tool("magnifyingglass", "Search", accessibilityID: "reader-tool-search") { model.panel = .search }
            annotationMenu
            tool("graduationcap", "Study", active: model.showLearningActions, accessibilityID: "reader-tool-learn") {
                model.showLearningActions = true
            }
        }
    }

    private var annotationMenu: some View {
        LeuMenu {
            if model.displayMode == .original {
                Button("Highlight selection", systemImage: "highlighter") {
                    Task { await model.highlight(kind: .highlight) }
                }
                .disabled(!model.hasSelection)
                Button("Underline selection", systemImage: "underline") {
                    Task { await model.highlight(kind: .underline) }
                }
                .disabled(!model.hasSelection)
                Divider()
            }
            Button(model.displayMode == .read ? "Add page note" : "Add note", systemImage: "square.and.pencil") {
                model.prepareNote()
            }
            Divider()
            Button("Important", systemImage: "exclamationmark.circle.fill") { Task { await model.quickStudyMark(.important) } }
            Button("Review later", systemImage: "arrow.clockwise.circle.fill") { Task { await model.quickStudyMark(.review) } }
            Button("Confusing", systemImage: "questionmark.circle.fill") { Task { await model.quickStudyMark(.confusing) } }
            Divider()
            Button("Your Marks", systemImage: "highlighter") { model.showStudyDrawer = true }
        } label: {
            toolLabel("pencil.tip", "Mark", active: model.hasSelection)
        }
        .accessibilityLabel("Mark important parts")
        .accessibilityIdentifier("reader-tool-mark")
    }

    private func timedPlanStatus(_ plan: TimedReadingPlan) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill").foregroundStyle(ShelfTheme.accent)
            Text("\(plan.requestedMinutes) min · through p. \(plan.endPage + 1)")
                .font(.caption.weight(.semibold))
            Spacer()
            Button("End") { model.activeTimedPlan = nil }.font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ShelfTheme.raised, in: Capsule())
    }

    private func searchReturnStatus(_ page: Int) -> some View {
        Button { model.returnToSearchOrigin() } label: {
            HStack(spacing: 9) {
                Image(systemName: "arrow.uturn.backward")
                Text("Back to p. \(page + 1)")
                    .font(.system(.caption, design: .serif).weight(.semibold))
                Spacer()
                Text("Return")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(ShelfTheme.action)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: ShelfTheme.smallRadius))
            .overlay { RoundedRectangle(cornerRadius: ShelfTheme.smallRadius).stroke(LeuDesign.separator, lineWidth: 0.7) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reader-search-return")
    }

    private func savedStatus(_ message: String) -> some View {
        HStack {
            Text(message)
                .font(.caption)
                .foregroundStyle(ShelfTheme.accent)
            Spacer()
            if model.canUndo {
                Button("Undo") { Task { await model.undo() } }
                    .font(.caption)
            }
            Button { model.savedMessage = nil } label: {
                Image(systemName: "xmark").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Dismiss status")
        }
        .padding(.horizontal, 8)
    }

    private func tool(_ symbol: String, _ title: String, active: Bool = false, accessibilityID: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolLabel(symbol, title, active: active) }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityIdentifier(accessibilityID)
    }

    private func toolLabel(_ symbol: String, _ title: String, active: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 18))
            Text(title).font(.system(size: 11, weight: .medium, design: .serif))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 53)
        .foregroundStyle(active ? ShelfTheme.accent : ShelfTheme.secondary)
    }
}
