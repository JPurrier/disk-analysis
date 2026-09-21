import Foundation

public struct DiskReport {
    public struct CleanupCandidate: Identifiable {
        public let node: FileNode
        public let reason: String

        public var id: UUID { node.id }
    }

    public let totalItems: Int
    public let totalSize: Int64
    public let largeFiles: [FileNode]
    public let cleanupCandidates: [CleanupCandidate]

    public init(
        totalItems: Int = 0,
        totalSize: Int64 = 0,
        largeFiles: [FileNode] = [],
        cleanupCandidates: [CleanupCandidate] = []
    ) {
        self.totalItems = totalItems
        self.totalSize = totalSize
        self.largeFiles = largeFiles
        self.cleanupCandidates = cleanupCandidates
    }

    public static func build(from root: FileNode) -> DiskReport {
        let largeFileThreshold: Int64 = 1_073_741_824
        let minimumCandidateSize: Int64 = 50 * 1_048_576
        let archiveThreshold: Int64 = 1_073_741_824
        let cacheNames: Set<String> = [
            ".cache", "cache", "caches", "deriveddata", "temporaryitems", "tmp", "temp"
        ]
        let reviewExtensions: Set<String> = ["log", "tmp", "temp", "bak", "old", "dmp", "crash"]
        let archiveExtensions: Set<String> = [
            "zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "dmg", "iso", "img", "pkg"
        ]

        var leaves: [FileNode] = []
        var rawCandidates: [CleanupCandidate] = []

        func candidateReason(for node: FileNode) -> String? {
            guard node.effectiveSize >= minimumCandidateSize,
                  !FileNode.isProtectedPath(node.path) else {
                return nil
            }

            let name = node.name.lowercased()
            let extensionName = node.fileExtension.lowercased()

            if node.isDirectory && cacheNames.contains(name) {
                return "Cache or temporary folder"
            }
            if name.contains("backup") || name.contains("archive") {
                return "Backup or archive for review"
            }
            if !node.isDirectory && reviewExtensions.contains(extensionName) {
                return "Log or temporary file"
            }
            if !node.isDirectory,
               archiveExtensions.contains(extensionName),
               node.effectiveSize >= archiveThreshold {
                return "Large archive or installer for review"
            }
            return nil
        }

        func visit(_ node: FileNode) {
            if node.isDirectory && !node.isPackage {
                if let reason = candidateReason(for: node) {
                    rawCandidates.append(CleanupCandidate(node: node, reason: reason))
                }
                for child in node.children {
                    visit(child)
                }
            } else {
                leaves.append(node)
                if let reason = candidateReason(for: node) {
                    rawCandidates.append(CleanupCandidate(node: node, reason: reason))
                }
            }
        }

        for child in root.children {
            visit(child)
        }

        let largeFiles = leaves
            .filter { $0.effectiveSize >= largeFileThreshold }
            .sorted { $0.effectiveSize > $1.effectiveSize }

        let sortedCandidates = rawCandidates.sorted { $0.node.effectiveSize > $1.node.effectiveSize }
        var cleanupCandidates: [CleanupCandidate] = []
        for candidate in sortedCandidates {
            let isNested = cleanupCandidates.contains { existing in
                candidate.node.path.hasPrefix(existing.node.path + "/")
            }
            if !isNested {
                cleanupCandidates.append(candidate)
            }
        }

        return DiskReport(
            totalItems: root.itemCount,
            totalSize: root.effectiveSize,
            largeFiles: largeFiles,
            cleanupCandidates: cleanupCandidates
        )
    }
}
