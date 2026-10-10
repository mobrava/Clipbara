import SwiftUI
import SwiftData
import KeyboardShortcuts

extension Notification.Name {
    /// Mirrors KeyboardShortcuts' internal change notification so the keycap
    /// display can refresh live while the user records a new shortcut.
    static let clipbaraShortcutDidChange = Self("KeyboardShortcuts_shortcutByNameDidChange")
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var step = 0
    @State private var panelShortcutRefresh = 0
    @State private var transferMessage = ""
    @State private var showTransferAlert = false

    private let accent = Color(red: 0.145, green: 0.388, blue: 0.922) // #2563EB

    var body: some View {
        VStack(spacing: 0) {
            hero
            content
            footer
        }
        .frame(width: 560, height: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .clipbaraShortcutDidChange)) { _ in
            panelShortcutRefresh += 1
        }
        .alert("Import Backup", isPresented: $showTransferAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(transferMessage)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            heroBackground
            switch step {
            case 0:
                ZStack {
                    decorativeCards
                    appIcon(size: 108)
                }
                .transition(.opacity)
            case 1:
                appIcon(size: 84).transition(.opacity)
            default:
                doneBadge.transition(.opacity)
            }
        }
        .frame(height: step == 0 ? 240 : 190)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var heroBackground: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(white: 0.14), Color(white: 0.11)]
                    : [Color(red: 0.957, green: 0.973, blue: 1.0), Color(red: 0.992, green: 0.996, blue: 1.0)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [accent.opacity(colorScheme == .dark ? 0.22 : 0.16), .clear],
                center: .init(x: 0.18, y: -0.1), startRadius: 0, endRadius: 420
            )
            RadialGradient(
                colors: [accent.opacity(colorScheme == .dark ? 0.14 : 0.10), .clear],
                center: .init(x: 0.85, y: 0.0), startRadius: 0, endRadius: 380
            )
        }
    }

    private func appIcon(size: CGFloat) -> some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .shadow(color: accent.opacity(0.35), radius: 16, y: 10)
    }

    private var doneBadge: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.353, green: 0.576, blue: 0.980), accent],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 72, height: 72)
                .shadow(color: accent.opacity(0.4), radius: 14, y: 8)
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var decorativeCards: some View {
        ZStack {
            miniCard(tag: String(localized: "TEXT"), tint: accent, width: 120)
                .rotationEffect(.degrees(-7))
                .offset(x: -180, y: -42)
            miniCard(tag: String(localized: "LINK"), tint: Color(red: 0.0, green: 0.588, blue: 0.533), width: 132)
                .rotationEffect(.degrees(6))
                .offset(x: 182, y: -30)
            miniCard(tag: nil, tint: .clear, width: 104)
                .rotationEffect(.degrees(4))
                .offset(x: -150, y: 68)
                .opacity(0.75)
            miniCard(tag: nil, tint: .clear, width: 96)
                .rotationEffect(.degrees(-5))
                .offset(x: 150, y: 74)
                .opacity(0.75)
        }
    }

    private func miniCard(tag: String?, tint: Color, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let tag {
                Text(tag)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(tint.opacity(0.12)))
            }
            barLine(widthRatio: 1.0)
            barLine(widthRatio: 0.6)
        }
        .padding(10)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.10), radius: 9, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }

    private func barLine(widthRatio: CGFloat) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.primary.opacity(0.10))
                .frame(width: proxy.size.width * widthRatio, height: 4)
        }
        .frame(height: 4)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch step {
            case 0: welcomeStep.transition(stepTransition)
            case 1: shortcutStep.transition(stepTransition)
            default: readyStep.transition(stepTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Text("Welcome to \(Text(verbatim: "Clipbara").foregroundStyle(accent))")
                .font(.system(size: 27, weight: .bold))
                .padding(.top, 28)
            Text("Everything you copy, saved automatically.\nFind it and paste it again whenever you need.")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 9)

            VStack(spacing: 6) {
                featureRow(
                    symbol: "square.on.square",
                    title: "Clipboard history as cards",
                    detail: "Text, links, images, files & colors. One click to copy back."
                )
                featureRow(
                    symbol: "star",
                    title: "Pinboards for keepers",
                    detail: "Drag frequently used clips to boards so they never expire."
                )
                #if APPSTORE
                featureRow(
                    symbol: "lock",
                    title: "Local unless you choose",
                    detail: "No account, no telemetry. Stays on this Mac until you turn on sync."
                )
                #else
                featureRow(
                    symbol: "lock",
                    title: "100% local & private",
                    detail: "No account, no cloud, no telemetry. Your data stays on this Mac."
                )
                #endif
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, 44)
    }

    private func featureRow(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 9)
                .fill(accent.opacity(colorScheme == .dark ? 0.18 : 0.09))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(accent)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Step 2: Shortcuts

    private var shortcutStep: some View {
        VStack(spacing: 0) {
            Text("One shortcut away")
                .font(.system(size: 27, weight: .bold))
                .padding(.top, 24)
            Text("Press this anywhere, in any app,\nto open your clipboard history.")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 9)

            HStack(spacing: 12) {
                ForEach(panelShortcutKeycaps, id: \.symbol) { cap in
                    keycap(symbol: cap.symbol, name: cap.name)
                }
            }
            .padding(.top, 22)
            .id(panelShortcutRefresh)

            VStack(spacing: 10) {
                shortcutRow(
                    title: "Open Clipbara",
                    detail: "Works globally, in any app.",
                    info: "Combine at least one of \u{2318}, \u{2325} or \u{2303} with a key, like \u{2325}V or \u{2303}\u{21e7}P. Function keys (F1\u{2013}F12) work on their own. Shift alone isn't supported by macOS."
                ) {
                    KeyboardShortcuts.Recorder(for: .toggleHistoryPanel)
                }
                shortcutRow(
                    title: "Preview a clip",
                    detail: "Full-screen Quick Look for the selected card.",
                    info: "A single key with no modifiers. It only works while the Clipbara panel is open, so it won't clash with other apps."
                ) {
                    LocalKeyRecorderView()
                }
                shortcutRow(
                    title: "Clip Queue",
                    detail: "Copy several things, then paste them in order.",
                    info: "Optional. While the queue is on, everything you copy joins it, and each \u{2318}V pastes the next item in order."
                ) {
                    KeyboardShortcuts.Recorder(for: .toggleClipQueue)
                }
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 44)
    }

    private var panelShortcutKeycaps: [(symbol: String, name: String)] {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .toggleHistoryPanel) else {
            return [("⌘", "command"), ("⇧", "shift"), ("V", "")]
        }
        var caps: [(String, String)] = []
        let modifiers = shortcut.modifiers
        if modifiers.contains(.control) { caps.append(("⌃", "control")) }
        if modifiers.contains(.option) { caps.append(("⌥", "option")) }
        if modifiers.contains(.shift) { caps.append(("⇧", "shift")) }
        if modifiers.contains(.command) { caps.append(("⌘", "command")) }
        let keyLabel = shortcut.description.drop { "⌃⌥⇧⌘⇪".contains($0) }
        caps.append((String(keyLabel), ""))
        return caps
    }

    private func keycap(symbol: String, name: String) -> some View {
        VStack(spacing: 5) {
            Text(symbol)
                .font(.system(size: symbol.count > 1 ? 17 : 26, weight: name.isEmpty ? .semibold : .medium))
                .foregroundStyle(name.isEmpty ? accent : Color.primary)
            if !name.isEmpty {
                Text(name)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 66, height: 66)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.12))
        )
    }

    private func shortcutRow<Control: View>(
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        info: LocalizedStringKey? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    if let info {
                        InfoHoverButton(text: info)
                    }
                }
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }

    // MARK: - Step 3: Ready

    private var readyStep: some View {
        VStack(spacing: 0) {
            Text("You're all set")
                .font(.system(size: 27, weight: .bold))
                .padding(.top, 28)
            Text("Copy something, press \(Text(verbatim: currentPanelShortcutText).bold().foregroundStyle(Color.primary)), and it'll be there.\nClipbara runs quietly in your menu bar.")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 9)

            VStack(spacing: 10) {
                hintRow(symbol: "clipboard") {
                    Text("Find Clipbara anytime via the \(Text("clipboard icon").bold().foregroundStyle(Color.primary)) in your menu bar. History, pinboards and settings live there.")
                } action: { EmptyView() }
                hintRow(symbol: "square.and.arrow.down") {
                    HStack(spacing: 5) {
                        Text("Coming from \(Text(verbatim: "PasteClip").bold().foregroundStyle(Color.primary)) or another Mac?\nRestore your clips from a backup file.")
                        InfoHoverButton(text: "In your previous app, go to Settings > General > Backup > Export to save a JSON backup file. Then click Import and select that file. Existing clips are kept and duplicates are skipped.")
                    }
                } action: {
                    Button("Import…") { importBackup() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(accent.opacity(colorScheme == .dark ? 0.18 : 0.09))
                        )
                }
                #if APPSTORE
                hintRow(symbol: "icloud") {
                    Text("Using Clipbara on iPhone too?\nSync your history and pinboards through iCloud.")
                } action: {
                    Toggle("iCloud Sync", isOn: syncBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(ClipSync.shared.phase == .starting)
                }
                #endif
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, 44)
    }

    #if APPSTORE
    private var syncBinding: Binding<Bool> {
        Binding(
            get: { ClipSync.shared.isEnabled || ClipSync.shared.phase == .starting },
            set: { on in
                if on {
                    Task { await ClipSync.shared.enable() }
                } else {
                    ClipSync.shared.disable()
                }
            }
        )
    }
    #endif

    private var currentPanelShortcutText: String {
        KeyboardShortcuts.getShortcut(for: .toggleHistoryPanel)?.description ?? "⌘⇧V"
    }

    private func hintRow<Content: View, Action: View>(
        symbol: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder action: () -> Action
    ) -> some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 9)
                .fill(accent.opacity(colorScheme == .dark ? 0.18 : 0.09))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(accent)
                )
            content()
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            action()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }

    private func importBackup() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = String(localized: "Import Clipbara Backup")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let summary = try TransferService.importDocument(data, context: modelContext)
            transferMessage = summary.localizedMessage
        } catch {
            transferMessage = String(localized: "Import failed: \(error.localizedDescription)")
        }
        showTransferAlert = true
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == step ? accent : Color.primary.opacity(0.14))
                        .frame(width: 7, height: 7)
                }
            }
            Button(action: advance) {
                (step == 2 ? Text("Start Using Clipbara") : Text("Continue"))
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.231, green: 0.443, blue: 0.953), accent],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .shadow(color: accent.opacity(0.30), radius: 8, y: 4)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)

            Button("Back") {
                withAnimation { step -= 1 }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.secondary)
            .opacity(step > 0 ? 1 : 0)
            .disabled(step == 0)
        }
        .padding(.horizontal, 44)
        .padding(.bottom, 20)
    }

    private func advance() {
        if step < 2 {
            withAnimation { step += 1 }
        } else {
            onFinish()
        }
    }
}
