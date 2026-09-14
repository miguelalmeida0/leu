import SwiftUI

@MainActor
struct TimedReadingSheet: View {
    @Bindable var model: ReaderModel
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 7

    private var plan: TimedReadingPlan? { model.readingWindow(minutes: minutes) }

    var body: some View {
        ShelfSheet(title: "Reading session") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How much time do you have?")
                            .leuScaledFont(27, weight: .semibold, design: .serif)
                        Text("Leu estimates a nearby stopping point from the PDF text and prefers a detected section boundary when one is close.")
                            .foregroundStyle(ShelfTheme.secondary)
                    }

                    HStack(spacing: 10) {
                        ForEach([3, 7, 15], id: \.self) { value in
                            Button { minutes = value } label: {
                                VStack(spacing: 2) {
                                    Text("\(value)").font(.title2.weight(.semibold))
                                    Text("min").font(.caption)
                                }
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .foregroundStyle(minutes == value ? ShelfTheme.background : ShelfTheme.text)
                                .background(minutes == value ? ShelfTheme.accent : ShelfTheme.surface,
                                            in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(minutes == value ? .isSelected : [])
                        }
                    }

                    if let plan {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(plan.summary)
                                .font(.title3.weight(.semibold))
                            Text("Estimated from text length at a 220 wpm baseline.")
                                .font(.caption)
                                .foregroundStyle(ShelfTheme.secondary)
                            if let boundary = plan.boundaryTitle {
                                Label("Ends before \"\(boundary)\"", systemImage: "bookmark")
                                    .font(.callout)
                                    .foregroundStyle(ShelfTheme.secondary)
                            } else {
                                Text("Ends at a complete PDF page near your target time.")
                                    .font(.callout)
                                    .foregroundStyle(ShelfTheme.secondary)
                            }
                            Button("Start reading session") {
                                model.startReadingWindow(plan)
                                dismiss()
                            }
                            .buttonStyle(ShelfButtonStyle(filled: true))
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .background(ShelfTheme.raised, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(20)
            }
        }
    }
}
