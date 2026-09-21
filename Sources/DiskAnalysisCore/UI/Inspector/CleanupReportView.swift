import SwiftUI

public struct CleanupReportView: View {
    @Bindable var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundColor(.accentColor)
                    Text("Smart Report")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                if state.diskReport.totalItems > 0 {
                    Text("\(state.diskReport.totalItems) items • \(formattedSize(state.diskReport.totalSize)) scanned")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Click an item to reveal it in Finder. Suggestions are for review, not automatic deletion.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(state.isScanning ? "Building report from the scan…" : "Run a scan to build the report.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if state.diskReport.totalItems == 0 {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(state.isScanning ? "Report will be ready when scanning finishes" : "No report yet")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        if state.diskReport.largeFiles.isEmpty {
                            Text("No files larger than 1 GB")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(state.diskReport.largeFiles) { node in
                                SmartReportRow(node: node, reason: nil, state: state)
                            }
                        }
                    } header: {
                        Text("Large files > 1 GB (\(state.diskReport.largeFiles.count))")
                    }

                    Section {
                        if state.diskReport.cleanupCandidates.isEmpty {
                            Text("No obvious review candidates found")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(state.diskReport.cleanupCandidates) { candidate in
                                SmartReportRow(node: candidate.node, reason: candidate.reason, state: state)
                            }
                        }
                    } header: {
                        Text("Potential cleanup (\(state.diskReport.cleanupCandidates.count))")
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private func formattedSize(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

private struct SmartReportRow: View {
    let node: FileNode
    let reason: String?
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: nodeIconName)
                    .foregroundColor(node.kind.color)
                    .frame(width: 14)

                Text(node.name)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(node.name)

                Spacer()

                Text(node.formattedSize)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 5) {
                if let reason {
                    Text(reason)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.orange)
                }
                Text(node.url.deletingLastPathComponent().path)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            state.revealInFinder(node)
        }
        .contextMenu {
            Button("Reveal in Finder") {
                state.revealInFinder(node)
            }
            Button("Open") {
                state.openFile(node)
            }
            Button("Copy Path") {
                state.copyPath(node)
            }
            Button("Get Info") {
                state.showInfo(for: node)
            }
            Divider()
            Button("Move to Trash", role: .destructive) {
                state.promptMoveToTrash(node)
            }
        }
    }

    private var nodeIconName: String {
        if node.isPackage {
            return "app.fill"
        }
        if node.isDirectory {
            return "folder.fill"
        }
        switch node.kind.category {
        case .video: return "film"
        case .audio: return "music.note"
        case .archive: return "archivebox"
        case .image: return "photo"
        case .document: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .diskImage: return "opticaldisc"
        default: return "doc"
        }
    }
}
