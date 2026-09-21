import SwiftUI
import AppKit

public struct VolumePickerView: View {
    @Bindable var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 8) {
            Menu {
                Section("Mounted Volumes") {
                    ForEach(state.availableVolumes) { volume in
                        Button {
                            state.selectedVolume = volume
                            state.customTargetURL = nil
                        } label: {
                            HStack {
                                Text(volume.name)
                                if volume.isBootVolume {
                                    Text("(System Boot)")
                                }
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: volume.totalCapacity, countStyle: .file))
                            }
                        }
                    }
                }

                Divider()

                Button("Choose Custom Folder...") {
                    selectCustomFolder()
                }

                Button("Refresh Drives") {
                    state.refreshVolumes()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: targetIconName)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(targetTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        if let vol = state.selectedVolume, state.customTargetURL == nil {
                            Text("\(ByteCountFormatter.string(fromByteCount: vol.availableCapacity, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: vol.totalCapacity, countStyle: .file))")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        } else if let custom = state.customTargetURL {
                            Text(custom.path)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
            }
            .menuStyle(.borderlessButton)

            // Scan / Cancel Button
            if state.isScanning {
                Button(role: .destructive) {
                    state.cancelScan()
                } label: {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        Text("Stop")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button {
                    state.startScan()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Scan")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
    }

    private var targetTitle: String {
        if let custom = state.customTargetURL {
            return custom.lastPathComponent
        }
        if let vol = state.selectedVolume {
            return vol.name
        }
        return "Select Drive"
    }

    private var targetIconName: String {
        if state.customTargetURL != nil {
            return "folder.fill"
        }
        if let vol = state.selectedVolume {
            if vol.isBootVolume {
                return "internaldrive.fill"
            } else if vol.isRemovable {
                return "externaldrive.fill"
            }
        }
        return "internaldrive"
    }

    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select a folder or drive to analyse"

        if panel.runModal() == .OK, let url = panel.url {
            state.customTargetURL = url
            state.selectedVolume = nil
        }
    }
}
