import SwiftUI
import ShelfCore

/// One real unresolved draft; no predicted weakness, overdue state or engagement score.
@MainActor struct ThoughtContinuationView: View {
    @Bindable var learning: LearningModel
    let documentID: UUID
    @State private var resumed: ReaderIntelligenceModel?
    @State private var presented = false
    var body: some View {
        if let thought = UnderstandingTimeline.thought(documentID: documentID,
            attempts: learning.snapshot.understandingAttempts, analyses: learning.snapshot.analyses) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("A thought you left here").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                    Text(thought.learnerExplanation).font(.system(.callout, design: .serif)).lineLimit(2)
                }
                Spacer(minLength: 8)
                Button("Resume") {
                    resumed = ReaderIntelligenceModel(learning: learning, source: thought.source, attempt: thought)
                    presented = true
                }.frame(minHeight: 44).accessibilityIdentifier("resume-understanding-thought")
            }.padding(16).background(ShelfTheme.background)
                .accessibilityIdentifier("understanding-thought")
                .sheet(isPresented: $presented) { if let resumed { TeachLeuSheet(model: resumed) } }
        }
    }
}
