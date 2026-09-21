import SwiftUI
import AppKit

public struct FileHierarchyOutlineView: View {
    @Bindable var state: AppState
    @State private var expandedNodeIDs: Set<UUID> = []

    private struct VisibleNode: Identifiable {
        let node: FileNode
        let children: [VisibleNode]?

        var id: UUID { node.id }
    }

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("File Hierarchy")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if let current = state.currentDrillDownNode {
                    Text("\(current.children.count) items")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Keep the completed scan tree in memory so expansion changes
            // only visibility; expanding a folder never rescans it.
            if let root = state.currentDrillDownNode ?? state.rootNode {
                let rows = treeRows(for: root)

                List(selection: Binding(
                    get: { state.selectedNode?.id },
                    set: { newId in
                        if let id = newId {
                            state.selectedNode = findNode(withId: id, in: root)
                        } else {
                            state.selectedNode = nil
                        }
                    }
                )) {
                    ForEach(rows) { visibleRow in
                        HStack(spacing: 0) {
                            if visibleRow.hasChildren {
                                Button {
                                    toggleExpansion(of: visibleRow.node)
                                } label: {
                                    Image(systemName: visibleRow.isExpanded ? "minus.square.fill" : "plus.square.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 18, height: 18)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    visibleRow.isExpanded
                                        ? "Collapse \(visibleRow.node.name)"
                                        : "Expand \(visibleRow.node.name)"
                                )
                            } else {
                                Color.clear
                                    .frame(width: 18, height: 18)
                            }

                            row(for: visibleRow.node, root: root)
                        }
                        .padding(.leading, CGFloat(visibleRow.depth * 16))
                        .tag(visibleRow.node.id)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No directory scanned")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: state.rootNode?.id) { _, _ in
            expandedNodeIDs.removeAll()
        }
    }

    private var hasActiveFilter: Bool {
        state.minSizeThreshold != .all || !state.searchQuery.isEmpty
    }

    private struct TreeRow: Identifiable {
        let node: FileNode
        let depth: Int
        let hasChildren: Bool
        let isExpanded: Bool

        var id: UUID { node.id }
    }

    private func treeRows(for root: FileNode) -> [TreeRow] {
        if hasActiveFilter {
            return flattenedRows(from: filteredNodes(of: root), depth: 0)
        }
        return flattenedRows(from: root.children, depth: 0)
    }

    private func flattenedRows(from nodes: [FileNode], depth: Int) -> [TreeRow] {
        nodes.flatMap { node in
            let hasChildren = !node.children.isEmpty
            var rows = [TreeRow(
                node: node,
                depth: depth,
                hasChildren: hasChildren,
                isExpanded: expandedNodeIDs.contains(node.id)
            )]
            if expandedNodeIDs.contains(node.id) {
                rows.append(contentsOf: flattenedRows(from: node.children, depth: depth + 1))
            }
            return rows
        }
    }

    private func flattenedRows(from nodes: [VisibleNode], depth: Int) -> [TreeRow] {
        nodes.flatMap { visible in
            let children = visible.children ?? []
            var rows = [TreeRow(
                node: visible.node,
                depth: depth,
                hasChildren: !children.isEmpty,
                isExpanded: expandedNodeIDs.contains(visible.id)
            )]
            if expandedNodeIDs.contains(visible.id) {
                rows.append(contentsOf: flattenedRows(from: children, depth: depth + 1))
            }
            return rows
        }
    }

    private func toggleExpansion(of node: FileNode) {
        if expandedNodeIDs.contains(node.id) {
            expandedNodeIDs.remove(node.id)
        } else {
            expandedNodeIDs.insert(node.id)
        }
    }

    private func row(for node: FileNode, root: FileNode) -> some View {
        FileRowView(
            node: node,
            totalParentSize: node.parent?.effectiveSize ?? root.effectiveSize,
            state: state
        )
    }

    private func filteredNodes(of node: FileNode) -> [VisibleNode] {
        node.children.compactMap { child in
            let descendants = filteredNodes(of: child)
            guard matchesActiveFilter(child) || !descendants.isEmpty else { return nil }
            return VisibleNode(node: child, children: descendants.isEmpty ? nil : descendants)
        }
    }

    private func matchesActiveFilter(_ node: FileNode) -> Bool {
        if state.minSizeThreshold != .all && node.effectiveSize < state.minSizeThreshold.rawValue {
            return false
        }

        if !state.searchQuery.isEmpty {
            let query = state.searchQuery.lowercased()
            guard node.name.lowercased().contains(query) || node.fileExtension.lowercased().contains(query) else {
                return false
            }
        }

        return true
    }

    private func findNode(withId id: UUID, in root: FileNode) -> FileNode? {
        if root.id == id { return root }
        for child in root.children {
            if let found = findNode(withId: id, in: child) {
                return found
            }
        }
        return nil
    }
}

struct FileRowView: View {
    let node: FileNode
    let totalParentSize: Int64
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 6) {
            // Icon
            Image(systemName: nodeIconName)
                .foregroundColor(node.kind.color)
                .frame(width: 14)

            // Name
            Text(node.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(node.name)

            Spacer()

            // Percentage Bar
            let fraction = node.percentage(of: totalParentSize)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(node.kind.color)
                        .frame(width: max(2, geo.size.width * CGFloat(fraction)), height: 6)
                }
                .frame(height: 6)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .frame(width: 45)

            // Size
            Text(node.formattedSize)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
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
