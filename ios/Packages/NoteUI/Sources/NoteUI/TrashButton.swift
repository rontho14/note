import SwiftUI

/// The round trash button on the drawers screen, with how many notes the trash holds under its icon. An empty trash
/// shows no count.
struct TrashButton: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Layout.countGap) {
                TrashIcon()
                    .stroke(Palette.second, style: TrashIcon.style)
                    .frame(width: Layout.icon, height: Layout.icon)
                if count > 0 {
                    Text(count, format: .number)
                        .font(Typeface.label)
                        .foregroundStyle(Palette.second)
                }
            }
            .frame(width: Layout.size, height: Layout.size)
            .background(Circle().fill(Palette.surface))
            .overlay { Circle().stroke(Palette.hairline, lineWidth: 1) }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trash")
        .accessibilityValue(count > 0 ? Text(count, format: .number) : Text(""))
        .accessibilityIdentifier(AccessibilityID.drawersTrash)
    }
}

/// DESIGN.md's Trash numbers.
private enum Layout {
    static let size: CGFloat = 52
    static let icon: CGFloat = 20
    static let countGap: CGFloat = 1
}
