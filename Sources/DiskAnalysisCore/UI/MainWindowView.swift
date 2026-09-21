import SwiftUI
import AppKit

public struct MainWindowView: View {
    @State private var appState = AppState.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Breadcrumbs & Sub-header
            HStack {
                BreadcrumbBarView(state: appState)
                Spacer()
                FilterSearchBarView(state: appState)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // 3-Pane Layout
            HSplitView {
                // Left: File Tree Outline
                FileHierarchyOutlineView(state: appState)
                    .frame(minWidth: 240, idealWidth: 320, maxWidth: 450)

                // Center/Bottom: Interactive Cushion Treemap
                CushionTreemapView(state: appState)
                    .frame(minWidth: 350, maxWidth: .infinity, maxHeight: .infinity)

                // Right: Smart disk report
                if appState.isInspectorVisible {
                    CleanupReportView(state: appState)
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
                }
            }

            Divider()

            // Bottom Status & Performance Bar
            HStack(spacing: 12) {
                if appState.isScanning {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)

                    Text("Scanning: \(appState.scanStats.filesScanned) files (\(Int(appState.scanStats.filesPerSecond)) files/s) — \(appState.scanStats.currentPath)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let selected = appState.selectedNode {
                    Image(systemName: selected.isDirectory ? "folder.fill" : "doc.fill")
                        .foregroundColor(selected.kind.color)
                        .font(.system(size: 11))

                    Text("\(selected.name) — \(selected.formattedSize)")
                        .font(.system(size: 11, weight: .semibold))

                    Text(selected.path)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let root = appState.currentDrillDownNode ?? appState.rootNode {
                    Text("\(root.name): \(root.formattedSize) total in \(root.itemCount) items")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text(appState.statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Keyboard hint badges
                HStack(spacing: 8) {
                    Text("Space: Quick Look")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("⌘⌫: Trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                VolumePickerView(state: appState)
            }
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: $appState.showTrashConfirmation,
            presenting: appState.nodeToTrash
        ) { node in
            Button("Move to Trash (\(node.formattedSize))", role: .destructive) {
                appState.confirmMoveToTrash()
            }
            Button("Cancel", role: .cancel) {
                appState.nodeToTrash = nil
            }
        } message: { node in
            Text("Are you sure you want to move '\(node.name)' (\(node.formattedSize), \(node.itemCount) items) to the macOS Trash?")
        }
        .sheet(item: $appState.infoNode) { node in
            FileInfoView(node: node)
        }
        .onKeyPress(.space) {
            if let selected = appState.selectedNode {
                QuickLookCoordinator.shared.togglePreview(for: selected.url)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete, phases: .down) { keyPress in
            if keyPress.modifiers.contains(.command), let selected = appState.selectedNode {
                appState.promptMoveToTrash(selected)
                return .handled
            }
            return .ignored
        }
    }
}
