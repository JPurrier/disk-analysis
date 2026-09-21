import Foundation
import SwiftUI
import Observation

public enum SizeFilterThreshold: Int64, CaseIterable, Identifiable, Sendable {
    case all = 0
    case over10MB = 10_485_760
    case over100MB = 104_857_600
    case over1GB = 1_073_741_824
    case over5GB = 5_368_709_120

    public var id: Int64 { rawValue }

    public var title: String {
        switch self {
        case .all: return "All Sizes"
        case .over10MB: return "> 10 MB"
        case .over100MB: return "> 100 MB"
        case .over1GB: return "> 1 GB"
        case .over5GB: return "> 5 GB"
        }
    }
}

@Observable
@MainActor
public final class AppState {
    public static let shared = AppState()

    // Volumes
    public var availableVolumes: [VolumeInfo] = []
    public var selectedVolume: VolumeInfo?
    public var customTargetURL: URL?

    // Scanner
    public var isScanning: Bool = false
    public var scanStats: ScanStatistics = ScanStatistics()
    private var scannerEngine = DiskScannerEngine()

    // Data tree
    public var rootNode: FileNode?
    public var currentDrillDownNode: FileNode?
    
    // Selection & Hover
    public var selectedNode: FileNode?
    public var hoveredNode: FileNode?

    // Filters
    public var searchQuery: String = ""
    public var minSizeThreshold: SizeFilterThreshold = .all
    public var treatPackagesAsFiles: Bool = true

    // File Actions & Modal State
    public var nodeToTrash: FileNode?
    public var showTrashConfirmation: Bool = false
    public var infoNode: FileNode?
    public var statusMessage: String = "Ready"

    // Inspector
    public var isInspectorVisible: Bool = true
    public var diskReport = DiskReport()

    public init() {
        refreshVolumes()
    }

    public func refreshVolumes() {
        let volumes = VolumeManager.shared.discoverVolumes()
        self.availableVolumes = volumes
        if self.selectedVolume == nil {
            self.selectedVolume = volumes.first(where: { $0.isBootVolume }) ?? volumes.first
        }
    }

    public var activeTargetURL: URL {
        if let custom = customTargetURL {
            return custom
        }
        if let vol = selectedVolume {
            return vol.url
        }
        return VolumeManager.shared.defaultScanTarget()
    }

    public func startScan() {
        guard !isScanning else { return }

        let target = activeTargetURL
        isScanning = true
        selectedNode = nil
        hoveredNode = nil
        rootNode = nil
        currentDrillDownNode = nil
        diskReport = DiskReport()
        statusMessage = "Scanning \(target.path)..."

        scannerEngine = DiskScannerEngine()

        Task {
            do {
                let node = try await scannerEngine.scan(
                    rootURL: target,
                    treatPackagesAsFiles: treatPackagesAsFiles
                ) { [weak self] stats in
                    Task { @MainActor [weak self] in
                        self?.scanStats = stats
                    }
                }

                self.rootNode = node
                self.currentDrillDownNode = node
                self.isScanning = false
                self.diskReport = DiskReport.build(from: node)
                self.statusMessage = "Scan complete: \(node.formattedSize), \(node.itemCount) items"
            } catch is CancellationError {
                self.isScanning = false
                self.statusMessage = "Scan cancelled"
            } catch {
                self.isScanning = false
                self.statusMessage = "Scan failed: \(error.localizedDescription)"
            }
        }
    }

    public func cancelScan() {
        guard isScanning else { return }
        Task {
            await scannerEngine.cancel()
        }
    }

    public func drillDown(to node: FileNode) {
        guard node.isDirectory && !node.isPackage else { return }
        self.currentDrillDownNode = node
        self.selectedNode = node
    }

    public func navigateToBreadcrumb(_ node: FileNode) {
        self.currentDrillDownNode = node
        self.selectedNode = node
    }

    public func resetDrillDown() {
        self.currentDrillDownNode = self.rootNode
    }

    public func promptMoveToTrash(_ node: FileNode) {
        // Prevent deleting root or anything beneath protected system paths.
        if FileNode.isProtectedPath(node.path) {
            self.statusMessage = "Cannot delete system protected directory: \(node.name)"
            return
        }
        self.nodeToTrash = node
        self.showTrashConfirmation = true
    }

    public func confirmMoveToTrash() {
        guard let node = nodeToTrash else { return }
        self.showTrashConfirmation = false
        self.nodeToTrash = nil

        do {
            try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
            statusMessage = "Moved to Trash: \(node.name)"

            // Prune node from parent in-memory tree
            if let parent = node.parent {
                _ = parent.removeChild(withId: node.id)
            } else if node === rootNode {
                rootNode = nil
                currentDrillDownNode = nil
            }

            if selectedNode === node {
                selectedNode = nil
            }
            diskReport = rootNode.map(DiskReport.build) ?? DiskReport()
        } catch {
            statusMessage = "Failed to move to Trash: \(error.localizedDescription)"
        }
    }

    public func revealInFinder(_ node: FileNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    public func openFile(_ node: FileNode) {
        NSWorkspace.shared.open(node.url)
    }

    public func copyPath(_ node: FileNode) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(node.path, forType: .string)
        statusMessage = "Copied path: \(node.path)"
    }

    public func showInfo(for node: FileNode) {
        infoNode = node
    }
}
