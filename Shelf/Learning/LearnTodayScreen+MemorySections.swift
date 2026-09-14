import SwiftUI
import ShelfCore

@MainActor
extension LearnTodayScreen {
    var continueSection: some View {
        let recent = Array(model.snapshot.timeline.sorted { $0.occurredAt > $1.occurredAt }.prefix(4))
        return VStack(alignment: .leading, spacing: 16) {
            if let event = recent.first {
                Button {
                    if let source = event.source { model.openSource(source) }
                    else { onOpenProgress() }
                } label: {
                    continueLabel(title: continueTitle(for: event), excerpt: sourceExcerpt(for: event),
                        detail: continueDetail(for: event),
                        action: event.source == nil ? "View progress" : "Continue at source")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("study-continue-populated")
            } else {
                Button { showingRecallSetup = true } label: {
                    continueLabel(title: model.snapshot.sessions.isEmpty ? "No session yet" : "Choose your next source",
                        detail: "Start with Active Recall or open a source you've been reading.",
                        action: "Start recall")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("study-continue-empty")
            }
            if recent.count > 1 {
                DisclosureGroup {
                    ForEach(Array(recent.dropFirst())) { event in
                        if let source = event.source {
                            Button { model.openSource(source) } label: {
                                HStack {
                                    Text(event.title).fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 8)
                                    Image(systemName: "arrow.up.right")
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        } else {
                            Text(event.title).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } label: { Text("Recent activity").font(.subheadline.weight(.semibold)) }
                .foregroundStyle(LeuDesign.studyContinueForeground)
                .tint(LeuDesign.studyContinueForeground)
            }
        }
    }

    private func continueTitle(for event: LearningTimelineEvent) -> String {
        guard let source = event.source else { return event.title }
        if let heading = nonempty(source.sectionTitle) { return heading }
        let page = model.snapshot.analyses[source.documentID]?.pages.first { $0.pageIndex == source.pageIndex }
        if let segment = page?.segments.first(where: {
            !$0.text.isEmpty && !source.sourceText.isEmpty &&
            ($0.text.contains(source.sourceText) || source.sourceText.contains($0.text))
        }), let heading = nonempty(segment.sectionTitle) { return heading }
        if let object = model.snapshot.studyObjects.first(where: { $0.id == event.learningObjectID }),
           object.origin == .userAuthored, let title = nonempty(object.title) { return title }
        return model.library.snapshot.activeBooks.first { $0.id == source.documentID }?.title ?? "Continue reading"
    }

    private func sourceExcerpt(for event: LearningTimelineEvent) -> String? {
        guard let text = nonempty(event.source?.sourceText) else { return nil }
        let compact = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard compact.count > 160 else { return compact }
        let prefix = String(compact.prefix(160))
        return String(prefix.prefix(upTo: prefix.lastIndex(of: " ") ?? prefix.endIndex)) + "…"
    }

    private func continueDetail(for event: LearningTimelineEvent) -> String {
        let date = event.occurredAt.formatted(date: .abbreviated, time: .omitted)
        guard let source = event.source else { return "Last activity · " + date }
        let document = model.library.snapshot.activeBooks.first { $0.id == source.documentID }?.title ?? "Source"
        return "\(document) · p. \(source.pageIndex + 1) · \(date)"
    }

    private func nonempty(_ text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private func continueLabel(title: String, excerpt: String? = nil, detail: String, action: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CONTINUE LEARNING").font(.caption.weight(.bold)).tracking(1.4)
                .foregroundStyle(LeuDesign.studyContinueSecondary)
            Text(title).leuScaledFont(28, weight: .bold, relativeTo: .title)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("study-continue-title")
            if let excerpt {
                Text(excerpt).font(.callout)
                    .foregroundStyle(LeuDesign.studyContinueSecondary)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("study-continue-excerpt")
            }
            Text(detail).font(.subheadline)
                .foregroundStyle(LeuDesign.studyContinueSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(action).font(.body.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.right")
            }.padding(.top, 8)
        }
        .foregroundStyle(LeuDesign.studyContinueForeground)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .contentShape(Rectangle())
        .multilineTextAlignment(.leading)
    }

    var fadingSection: some View {
        reviewField(title: "FADING", items: model.dueObjects, empty: "Nothing due",
                    summary: "ideas need another pass", action: "Review due",
                    surface: LeuDesign.studyFadingSurface, foreground: LeuDesign.studyFadingForeground,
                    secondary: LeuDesign.studyFadingSecondary, minimumHeight: 240, radius: 8,
                    identifier: "study-fading-field")
    }

    var blindSpotsSection: some View {
        reviewField(title: "BLIND SPOTS", items: model.blindSpotObjects, empty: "No confident misses",
                    summary: "ideas with confident misses", action: "Review misses",
                    surface: LeuDesign.studyBlindSpotSurface, foreground: LeuDesign.studyBlindSpotForeground,
                    secondary: LeuDesign.studyBlindSpotSecondary, minimumHeight: 208, radius: 16,
                    identifier: "study-blind-spots-field")
    }

    private func reviewField(title: String, items: [LearningObject], empty: String,
                             summary: String, action: String, surface: Color, foreground: Color,
                             secondary: Color, minimumHeight: CGFloat, radius: CGFloat,
                             identifier: String) -> some View {
        let label = reviewLabel(title: title, items: items, empty: empty, summary: summary,
                                action: action, foreground: foreground, secondary: secondary)
            .frame(maxWidth: .infinity, minHeight: items.isEmpty ? 126 : minimumHeight, alignment: .topLeading)
            .padding(18)
            .background(surface, in: RoundedRectangle(cornerRadius: radius))
            .contentShape(RoundedRectangle(cornerRadius: radius))
        return Group {
            if items.isEmpty {
                label.accessibilityElement(children: .combine)
            } else {
                Button { model.startReview(objectIDs: items.map(\.id)) } label: {
                    label
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func reviewLabel(title: String, items: [LearningObject], empty: String,
                             summary: String, action: String, foreground: Color, secondary: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.caption.weight(.bold)).tracking(1.2)
                .foregroundStyle(secondary)
            if items.isEmpty {
                Text(empty).font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: title == "FADING" ? "clock" : "checkmark")
                    .font(.title2).foregroundStyle(secondary).accessibilityHidden(true)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(items.count)").leuScaledFont(42, weight: .bold, relativeTo: .largeTitle)
                    Text(items.count == 1 ? summary.replacingOccurrences(of: "ideas", with: "idea").replacingOccurrences(of: "need ", with: "needs ") : summary)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(items.prefix(3))) { object in
                    Text(object.title).font(.subheadline)
                        .foregroundStyle(secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Text(action).font(.subheadline.weight(.bold))
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.right")
                }.padding(.top, 6)
            }
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .multilineTextAlignment(.leading)
    }
}
