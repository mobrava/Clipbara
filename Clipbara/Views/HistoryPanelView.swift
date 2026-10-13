import SwiftUI
import AppKit
import SwiftData

struct HistoryPanelView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \ClipboardItem.copiedAt, order: .reverse)
    private var items: [ClipboardItem]
    @State private var showsIPhoneNotice = IPhoneAppNotice.shouldShow(syncEnabled: Self.syncEnabled)

    private static var syncEnabled: Bool {
        #if APPSTORE
        ClipSync.shared.isEnabled
        #else
        false
        #endif
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(
                material: colorScheme == .dark ? .hudWindow : .popover
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                NavigationBarView()

                if showsIPhoneNotice {
                    IPhoneAppBanner {
                        IPhoneAppNotice.dismiss()
                        withAnimation(.easeOut(duration: 0.16)) {
                            showsIPhoneNotice = false
                        }
                    }
                    .transition(.opacity)
                }

                ZStack {
                    // Cards layer
                    Group {
                        CardGridView()
                            .opacity(appState.selectedTab == .history ? 1 : 0)
                            .allowsHitTesting(appState.selectedTab == .history)

                        if case .pinboard(let id) = appState.selectedTab {
                            PinboardGridView(pinboardId: id)
                                .id(id)
                        }
                    }
                    .opacity(appState.previewItem == nil ? 1 : 0)

                    // Preview layer (replaces cards)
                    if let previewItem = appState.previewItem {
                        PreviewView(
                            item: previewItem,
                            onClose: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    appState.searchState.selectedIndex = nil
                                    appState.selectForPreview(nil)
                                }
                            },
                            onPaste: {
                                appState.paste(previewItem)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .bottom))
                        ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onChange(of: appState.selectedTab) { _, _ in
                appState.selectForPreview(nil)
            }
            .onChange(of: appState.panelPresentationID) { _, _ in
                // Sync may have been turned on in Settings since the panel last opened.
                showsIPhoneNotice = IPhoneAppNotice.shouldShow(syncEnabled: Self.syncEnabled)
            }

            if let toast = appState.panelToast {
                PanelToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.16), value: appState.panelToast)
    }
}

private struct IPhoneAppBanner: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("Clipbara for iPhone is here.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.9))
                .layoutPriority(1)

            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .truncationMode(.tail)
                .help(detail)

            Spacer(minLength: 8)

            Button(action: primaryAction) {
                Text(primaryTitle)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background(Capsule().fill(Color.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.16)))
            }
            .buttonStyle(.plain)
            .fixedSize()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Don't show again")
        }
        .lineLimit(1)
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 0.75)
        )
        .padding(.horizontal, DesignTokens.Nav.horizontalPadding)
        .padding(.bottom, 2)
    }

    #if APPSTORE
    private var detail: String {
        String(localized: "Search for “Clipbara” in the App Store on your iPhone, then turn on sync. Your purchase covers both.")
    }
    private var primaryTitle: String { String(localized: "Sync Settings") }
    private func primaryAction() {
        appState.openSettings()
    }
    #else
    private var detail: String {
        String(localized: "Sync works with the Mac App Store edition, and one purchase covers Mac and iPhone. If you got that edition before Oct 6, it's already unlocked. To move your clips, export a backup in Settings > General.")
    }
    private var primaryTitle: String { String(localized: "View in App Store") }
    private func primaryAction() {
        NSWorkspace.shared.open(IPhoneAppNotice.appStoreURL)
        appState.hidePanel()
    }
    #endif
}

private struct PanelToastView: View {
    let toast: PanelToast

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: toast.systemImage)
                .font(.system(size: 12, weight: .semibold))

            Text(toast.message)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.primary.opacity(0.86))
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, DesignTokens.Nav.height + 8)
        .allowsHitTesting(false)
    }
}
