import SwiftUI

struct ClipQueueView: View {
    let queue: ClipQueue
    var onHeightChange: (CGFloat) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let rowHeight: CGFloat = 30
    private let maxVisibleRows = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.6)
            if queue.list.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(width: ClipQueueWindowController.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            VisualEffectBackground(material: colorScheme == .dark ? .hudWindow : .popover)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.75)
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tint)
            Text("Clip Queue")
                .font(.system(size: 13, weight: .semibold))
            if !queue.list.isEmpty {
                Text(verbatim: "\(queue.list.count)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
            Spacer(minLength: 4)
            headerButton(
                systemImage: queue.pastesNewestFirst ? "arrow.up" : "arrow.down",
                help: queue.pastesNewestFirst
                    ? String(localized: "Pasting newest first. Click to paste oldest first.")
                    : String(localized: "Pasting oldest first. Click to paste newest first.")
            ) {
                queue.pastesNewestFirst.toggle()
            }
            headerButton(systemImage: "xmark", help: String(localized: "End Clip Queue")) {
                queue.stop()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
    }

    private func headerButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    // MARK: - Content

    private var emptyState: some View {
        Text("Copy a few things. Each \u{2318}V then pastes the next one in order.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
    }

    private var list: some View {
        let entries = queue.list.pasteOrder
        return ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    row(number: index + 1, entry: entry, isNext: index == 0)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: CGFloat(min(entries.count, maxVisibleRows)) * rowHeight + 8)
    }

    private func row(number: Int, entry: ClipQueueList<ClipboardItem>.Entry, isNext: Bool) -> some View {
        let item = entry.item
        return HStack(spacing: 8) {
            Text(verbatim: "\(number)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(isNext ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .frame(width: 18, alignment: .trailing)
            Image(systemName: item.contentType.systemImage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(verbatim: preview(of: item))
                .font(.system(size: 12, weight: isNext ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isNext ? Color.accentColor.opacity(0.14) : .clear)
        )
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Remove from Queue", role: .destructive) {
                queue.remove(id: entry.id)
            }
        }
    }

    private func preview(of item: ClipboardItem) -> String {
        if let title = item.userTitle, !title.isEmpty { return title }
        if let text = item.textContent?
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespaces),
           !text.isEmpty {
            return text
        }
        return item.contentType.displayName
    }
}
