import SwiftUI
import PDFKit
import ShelfCore

@MainActor
struct DiagramMaskEditor: View {
    @Bindable var model: LearningModel
    let object: LearningObject
    @Environment(\.dismiss) private var dismiss
    @State private var normalizedRegions: [CGRect] = []
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var label = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Drag over one or more regions you want hidden during recall.")
                    .font(.callout).foregroundStyle(ShelfTheme.secondary).padding(.horizontal, ShelfTheme.gutter)
                pageCanvas
                LeuTextField("Optional label", text: $label).textFieldStyle(.roundedBorder)
                    .padding(.horizontal, ShelfTheme.gutter)
                HStack {
                    Button("Clear") { normalizedRegions.removeAll() }.buttonStyle(ShelfButtonStyle())
                    Spacer()
                    Button("Save mask") { save() }.buttonStyle(ShelfButtonStyle(filled: true)).disabled(normalizedRegions.isEmpty)
                }.padding(.horizontal, ShelfTheme.gutter).padding(.bottom, 12)
            }
            .background(ShelfTheme.background).navigationTitle("Diagram Mask").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }.preferredColorScheme(.dark).tint(ShelfTheme.accent)
    }

    private var pageCanvas: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if let image = pageImage(size: proxy.size) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else { Text("Source page unavailable.").foregroundStyle(ShelfTheme.secondary) }
                ForEach(Array(normalizedRegions.enumerated()), id: \.offset) { _, rect in
                    maskRect(pixelRect(rect, size: proxy.size))
                }
                if let start = dragStart, let current = dragCurrent { maskRect(pixelBounds(start, current)) }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 3)
                .onChanged { value in
                    if dragStart == nil { dragStart = clamp(value.startLocation, to: proxy.size) }
                    dragCurrent = clamp(value.location, to: proxy.size)
                }
                .onEnded { value in
                    guard let start = dragStart else { return }
                    let pixel = pixelBounds(start, clamp(value.location, to: proxy.size))
                    let normalized = normalize(pixel, size: proxy.size)
                    if normalized.width > 0.04 && normalized.height > 0.025 {
                        normalizedRegions.append(normalized); model.play(.snapToTarget)
                    }
                    dragStart = nil; dragCurrent = nil
                })
        }
        .aspectRatio(0.72, contentMode: .fit).padding(.horizontal, ShelfTheme.gutter)
    }

    private func pageImage(size: CGSize) -> UIImage? {
        guard let book = model.library.snapshot.activeBooks.first(where: { $0.id == object.source.documentID }),
              let document = PDFDocument(url: model.library.originalURL(book)),
              let page = document.page(at: object.source.pageIndex) else { return nil }
        return page.thumbnail(of: CGSize(width: max(700, size.width * 2), height: max(900, size.height * 2)), for: .cropBox)
    }
    private func pixelBounds(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(a.x-b.x), height: abs(a.y-b.y))
    }
    private func normalize(_ rect: CGRect, size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGRect(x: rect.minX / size.width, y: rect.minY / size.height,
                      width: rect.width / size.width, height: rect.height / size.height)
    }
    private func pixelRect(_ rect: CGRect, size: CGSize) -> CGRect {
        CGRect(x: rect.minX * size.width, y: rect.minY * size.height,
               width: rect.width * size.width, height: rect.height * size.height)
    }
    private func maskRect(_ rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 6).fill(ShelfTheme.ink)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ShelfTheme.accent, lineWidth: 1))
            .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
    }
    private func clamp(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: min(max(0, point.x), size.width), y: min(max(0, point.y), size.height))
    }
    private func save() {
        Task {
            do { try await model.saveMask(object: object, normalizedRegions: normalizedRegions, label: label); dismiss() }
            catch { model.errorMessage = error.localizedDescription }
        }
    }
}
