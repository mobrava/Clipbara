import SwiftUI

/// iCloud sync controls, shared by the Mac settings window and the iOS settings sheet.
struct SyncSettingsSection: View {
    private let sync = ClipSync.shared

    @State private var confirmEnable = false
    @State private var confirmDelete = false
    @State private var estimate = ClipSync.UploadEstimate()

    var body: some View {
        Section {
            Toggle(isOn: toggleBinding) {
                // Rows in the Mac Settings carry no icons; iOS settings rows do.
                #if os(macOS)
                Text("iCloud Sync")
                #else
                Label("iCloud Sync", systemImage: "icloud")
                #endif
            }
            .disabled(sync.phase == .starting)

            Toggle(isOn: imagesBinding) {
                #if os(macOS)
                Text("Sync Images")
                #else
                Label("Sync Images", systemImage: "photo")
                #endif
            }

            if sync.isEnabled || sync.phase == .needsAccount || isFailure {
                HStack(spacing: 8) {
                    statusIcon
                    Text(statusText)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if sync.isEnabled {
                        Button("Sync Now") {
                            Task { await sync.syncNow() }
                        }
                        .disabled(sync.phase == .syncing || sync.phase == .starting)
                    }
                }
                .font(.callout)
            }

            if sync.isEnabled {
                Button("Delete iCloud Data…", role: .destructive) {
                    confirmDelete = true
                }
            }
        } header: {
            Text("Sync")
        } footer: {
            Text("Your history and pinboards sync between your Mac and iPhone through your private iCloud database, and use your iCloud storage. Clip contents are encrypted. Images over 10 MB and copied files stay on the device where you copied them.")
        }
        .confirmationDialog("Turn On iCloud Sync?", isPresented: $confirmEnable, titleVisibility: .visible) {
            Button("Turn On") {
                Task { await sync.enable() }
            }
        } message: {
            if estimate.images > 0 {
                Text("\(estimate.clips) clips, \(estimate.images) images (about \(imageSize)), and \(estimate.pinboards) pinboards on this device will be uploaded to your iCloud account.")
            } else {
                Text("\(estimate.clips) clips and \(estimate.pinboards) pinboards on this device will be uploaded to your iCloud account.")
            }
        }
        .confirmationDialog("Delete iCloud Data?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete iCloud Data", role: .destructive) {
                Task { await sync.deleteCloudData() }
            }
        } message: {
            Text("Clipbara's data in iCloud is deleted and sync turns off on every device. Clips already on each device stay there.")
        }
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { sync.isEnabled },
            set: { on in
                if on {
                    estimate = sync.uploadEstimate()
                    confirmEnable = true
                } else {
                    sync.disable()
                }
            }
        )
    }

    private var imagesBinding: Binding<Bool> {
        Binding(
            get: {
                _ = sync.imageSettingVersion
                return sync.includesImages
            },
            set: { sync.setIncludesImages($0) }
        )
    }

    private var imageSize: String {
        Int64(estimate.imageBytes).formatted(.byteCount(style: .file))
    }

    private var isFailure: Bool {
        if case .failed = sync.phase { return true }
        return false
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch sync.phase {
        case .syncing, .starting:
            ProgressView().controlSize(.small)
        case .upToDate:
            Image(systemName: "checkmark.icloud").foregroundStyle(.green)
        case .needsAccount:
            Image(systemName: "person.crop.circle.badge.exclamationmark").foregroundStyle(.orange)
        case .failed:
            Image(systemName: "exclamationmark.icloud").foregroundStyle(.red)
        case .off:
            Image(systemName: "icloud.slash").foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        switch sync.phase {
        case .off:
            return String(localized: "Off")
        case .starting:
            return String(localized: "Connecting to iCloud…")
        case .syncing:
            return String(localized: "Syncing…")
        case .upToDate:
            if let date = sync.lastSyncedAt {
                let relative = date.formatted(.relative(presentation: .named))
                return String(localized: "Up to date, synced \(relative)")
            }
            return String(localized: "Up to date")
        case .needsAccount:
            return String(localized: "Sign in to iCloud to sync.")
        case .failed(let message):
            return message
        }
    }
}
