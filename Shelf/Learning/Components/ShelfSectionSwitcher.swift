import SwiftUI

/// Secondary navigation inside Shelf. All five destinations remain directly reachable
/// on iPhone; none are hidden beyond a horizontal-scroll affordance.
@MainActor
struct ShelfSectionSwitcher: View {
    @Binding var selection: ShelfTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ShelfTab.allCases) { tab in
                Button {
                    selection = tab
                    ShelfHaptics.shared.play(.selectionChanged)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: symbol(for: tab))
                            .font(.system(size: 16, weight: selection == tab ? .semibold : .regular))
                            .frame(height: 20)
                        Text(tab.title)
                            .font(.caption.weight(selection == tab ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)
                    }
                    .foregroundStyle(selection == tab ? ShelfTheme.accent : ShelfTheme.secondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(selection == tab ? ShelfTheme.accent : Color.clear)
                            .frame(width: 22, height: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityIdentifier("tab-" + tab.rawValue)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ShelfTheme.background)
        .overlay(alignment: .bottom) { ShelfTheme.line.opacity(0.55).frame(height: 0.5) }
    }

    private func symbol(for tab: ShelfTab) -> String {
        guard selection == tab, tab != .settings, tab != .recents else { return tab.symbol }
        return tab.symbol + ".fill"
    }
}
