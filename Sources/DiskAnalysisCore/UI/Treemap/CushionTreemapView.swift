import SwiftUI
import CoreGraphics

public struct CushionTreemapView: View {
    @Bindable var state: AppState
    @State private var hoveredPoint: CGPoint? = nil
    @State private var treemapRects: [TreemapRect] = []
    @State private var lastSize: CGSize = .zero

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack(alignment: .topLeading) {
                // Background
                Color.black.opacity(0.85)

                if treemapRects.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text(state.isScanning ? "Generating Treemap..." : "No data to display. Click Scan to start.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Hardware-accelerated Canvas rendering
                    Canvas { context, canvasSize in
                        for rect in treemapRects {
                            let isSelected = (rect.node === state.selectedNode)
                            let isHovered = (rect.node === state.hoveredNode)
                            let isDimmed = shouldDim(node: rect.node)

                            CushionShadingEngine.shared.drawTile(
                                in: &context,
                                rect: rect.rect,
                                baseColor: rect.color,
                                isSelected: isSelected,
                                isHovered: isHovered,
                                isDimmed: isDimmed
                            )
                        }
                    }
                    .gesture(
                        SpatialTapGesture(count: 2)
                            .onEnded { value in
                                if let target = findNode(at: value.location) {
                                    if target.isDirectory && !target.isPackage {
                                        state.drillDown(to: target)
                                    }
                                }
                            }
                            .exclusively(
                                before: SpatialTapGesture(count: 1)
                                    .onEnded { value in
                                        if let target = findNode(at: value.location) {
                                            state.selectedNode = target
                                        } else {
                                            state.selectedNode = nil
                                        }
                                    }
                            )
                    )
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoveredPoint = location
                            state.hoveredNode = findNode(at: location)
                        case .ended:
                            hoveredPoint = nil
                            state.hoveredNode = nil
                        }
                    }
                    .contextMenu {
                        if let selected = state.selectedNode {
                            Button("Reveal in Finder") {
                                state.revealInFinder(selected)
                            }
                            Button("Open") {
                                state.openFile(selected)
                            }
                            Button("Copy Path") {
                                state.copyPath(selected)
                            }
                            Button("Get Info") {
                                state.showInfo(for: selected)
                            }
                            Divider()
                            Button("Move to Trash", role: .destructive) {
                                state.promptMoveToTrash(selected)
                            }
                        }
                    }
                }

                // Hover HUD overlay
                if let hoverNode = state.hoveredNode, let point = hoveredPoint {
                    TreemapTooltipOverlay(node: hoverNode, position: point)
                }
            }
            .onChange(of: size) { _, newSize in
                updateLayout(for: newSize)
            }
            .onChange(of: state.currentDrillDownNode?.id) { _, _ in
                updateLayout(for: size)
            }
            .onChange(of: state.rootNode?.id) { _, _ in
                updateLayout(for: size)
            }
            .onAppear {
                updateLayout(for: size)
            }
        }
    }

    private func updateLayout(for size: CGSize) {
        guard size.width > 10 && size.height > 10 else { return }
        lastSize = size

        guard let currentRoot = state.currentDrillDownNode ?? state.rootNode else {
            treemapRects = []
            return
        }

        let bounds = CGRect(origin: .zero, size: size)
        treemapRects = TreemapLayoutEngine.shared.computeLayout(for: currentRoot, in: bounds)
    }

    private func findNode(at point: CGPoint) -> FileNode? {
        // Find matching leaf rectangle containing point
        for r in treemapRects.reversed() {
            if r.rect.contains(point) {
                return r.node
            }
        }
        return nil
    }

    private func shouldDim(node: FileNode) -> Bool {
        // Dim if min size threshold is active
        if state.minSizeThreshold != .all && node.effectiveSize < state.minSizeThreshold.rawValue {
            return true
        }

        // Dim if search query is active and doesn't match
        if !state.searchQuery.isEmpty {
            let q = state.searchQuery.lowercased()
            let matchName = node.name.lowercased().contains(q)
            let matchExt = node.fileExtension.lowercased().contains(q)
            if !matchName && !matchExt {
                return true
            }
        }

        return false
    }
}
