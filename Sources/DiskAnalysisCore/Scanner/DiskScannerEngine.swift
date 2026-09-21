import Foundation
import Observation

public actor DiskScannerEngine {
    private var isCancelled: Bool = false
    private let scanner = DarwinBulkScanner.shared
    private var treatPackagesAsFiles: Bool = true

    public init() {}

    public func cancel() {
        isCancelled = true
    }

    /// Performs a full scan of the target root URL, streaming progress updates
    public func scan(
        rootURL: URL,
        treatPackagesAsFiles: Bool = true,
        onProgress: @Sendable @escaping (ScanStatistics) -> Void
    ) async throws -> FileNode {
        self.isCancelled = false
        self.treatPackagesAsFiles = treatPackagesAsFiles

        var stats = ScanStatistics(
            currentPath: rootURL.path,
            startTime: Date()
        )

        var lastReportTime = Date()

        let rootNode = FileNode(
            name: rootURL.lastPathComponent.isEmpty ? rootURL.path : rootURL.lastPathComponent,
            url: rootURL,
            isDirectory: true
        )

        // Queue of directories to scan: (URL, parent FileNode)
        var pendingDirs: [(URL, FileNode)] = [(rootURL, rootNode)]

        while !pendingDirs.isEmpty && !isCancelled {
            let (dirURL, parentNode) = pendingDirs.removeFirst()
            stats.foldersScanned += 1
            stats.currentPath = dirURL.path

            let entries = scanner.readDirectory(at: dirURL.path, treatPackagesAsFiles: treatPackagesAsFiles)

            for entry in entries {
                if isCancelled { break }

                let itemURL = dirURL.appendingPathComponent(entry.name)

                if entry.isDirectory && !entry.isPackage {
                    let dirNode = FileNode(
                        name: entry.name,
                        url: itemURL,
                        isDirectory: true,
                        modifiedDate: entry.modifiedDate,
                        parent: parentNode
                    )
                    parentNode.children.append(dirNode)
                    pendingDirs.append((itemURL, dirNode))
                } else if entry.isPackage {
                    // It's a package bundle (.app, etc.)
                    // Calculate its inner contents size
                    let (pkgLogical, pkgPhysical, pkgItems) = scanPackageTotalSize(at: itemURL.path)
                    let pkgNode = FileNode(
                        name: entry.name,
                        url: itemURL,
                        isDirectory: true,
                        isPackage: true,
                        logicalSize: pkgLogical,
                        physicalSize: pkgPhysical,
                        itemCount: pkgItems,
                        modifiedDate: entry.modifiedDate,
                        parent: parentNode
                    )
                    parentNode.children.append(pkgNode)
                    stats.filesScanned += pkgItems
                    stats.bytesScanned += pkgPhysical > 0 ? pkgPhysical : pkgLogical
                } else {
                    // Regular file
                    let fileNode = FileNode(
                        name: entry.name,
                        url: itemURL,
                        isDirectory: false,
                        logicalSize: entry.logicalSize,
                        physicalSize: entry.physicalSize,
                        itemCount: 1,
                        modifiedDate: entry.modifiedDate,
                        fileExtension: (entry.name as NSString).pathExtension,
                        parent: parentNode
                    )
                    parentNode.children.append(fileNode)
                    stats.filesScanned += 1
                    stats.bytesScanned += entry.physicalSize > 0 ? entry.physicalSize : entry.logicalSize
                }

                // Throttle progress callback to every 100ms
                let now = Date()
                if now.timeIntervalSince(lastReportTime) >= 0.1 {
                    lastReportTime = now
                    let elapsed = max(0.001, now.timeIntervalSince(stats.startTime))
                    stats.elapsedTime = elapsed
                    stats.filesPerSecond = Double(stats.filesScanned) / elapsed
                    onProgress(stats)
                }
            }
        }

        if isCancelled {
            throw CancellationError()
        }

        // Post-scan: compute aggregated sizes up the tree and sort children descending
        rootNode.recalculateAggregates()
        rootNode.sortChildrenBySize()

        let elapsed = max(0.001, Date().timeIntervalSince(stats.startTime))
        stats.elapsedTime = elapsed
        stats.filesPerSecond = Double(stats.filesScanned) / elapsed
        stats.isComplete = true
        onProgress(stats)

        return rootNode
    }

    /// Fast recursive traversal to sum size of an application or library bundle
    private func scanPackageTotalSize(at packagePath: String) -> (logical: Int64, physical: Int64, items: Int) {
        var totalLogical: Int64 = 0
        var totalPhysical: Int64 = 0
        var totalItems = 0

        var dirsToVisit = [packagePath]

        while !dirsToVisit.isEmpty && !isCancelled {
            let current = dirsToVisit.removeFirst()
            let entries = scanner.readDirectory(at: current, treatPackagesAsFiles: false)
            for entry in entries {
                let subPath = (current as NSString).appendingPathComponent(entry.name)
                if entry.isDirectory {
                    dirsToVisit.append(subPath)
                } else {
                    totalLogical += entry.logicalSize
                    totalPhysical += entry.physicalSize
                    totalItems += 1
                }
            }
        }

        return (totalLogical, totalPhysical, max(1, totalItems))
    }
}
