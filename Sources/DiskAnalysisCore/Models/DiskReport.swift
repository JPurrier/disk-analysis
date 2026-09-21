import Foundation

public struct DiskReport {
    private enum ReportIdentity: Hashable {
        case filesystem(device: UInt64, inode: UInt64)
        case path(String)
    }

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

        let largeFiles = deduplicated(
            leaves.filter { $0.effectiveSize >= largeFileThreshold }
        )

        let sortedCandidates = rawCandidates.sorted { $0.node.effectiveSize > $1.node.effectiveSize }
        var uniqueCandidates: [ReportIdentity: CleanupCandidate] = [:]
        for candidate in sortedCandidates {
            let identity = reportIdentity(for: candidate.node)
            if let existing = uniqueCandidates[identity] {
                if shouldPrefer(candidate.node, over: existing.node) {
                    uniqueCandidates[identity] = candidate
                }
            } else {
                uniqueCandidates[identity] = candidate
            }
        }

        let deduplicatedCandidates = uniqueCandidates.values.sorted {
            if $0.node.effectiveSize != $1.node.effectiveSize {
                return $0.node.effectiveSize > $1.node.effectiveSize
            }
            return $0.node.path < $1.node.path
        }
        var cleanupCandidates: [CleanupCandidate] = []
        for candidate in deduplicatedCandidates {
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

    private static func deduplicated(_ nodes: [FileNode]) -> [FileNode] {
        var uniqueNodes: [ReportIdentity: FileNode] = [:]
        for node in nodes {
            let identity = reportIdentity(for: node)
            if let existing = uniqueNodes[identity] {
                if shouldPrefer(node, over: existing) {
                    uniqueNodes[identity] = node
                }
            } else {
                uniqueNodes[identity] = node
            }
        }

        return uniqueNodes.values.sorted {
            if $0.effectiveSize != $1.effectiveSize {
                return $0.effectiveSize > $1.effectiveSize
            }
            return $0.path < $1.path
        }
    }

    private static func reportIdentity(for node: FileNode) -> ReportIdentity {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: node.path),
           let device = (attributes[.systemNumber] as? NSNumber)?.uint64Value,
           let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value {
            return .filesystem(device: device, inode: inode)
        }

        let standardizedPath = URL(fileURLWithPath: node.path).standardized.path
        let dataVolumePrefix = "/System/Volumes/Data"
        let canonicalPath: String
        if standardizedPath == dataVolumePrefix {
            canonicalPath = "/"
        } else if standardizedPath.hasPrefix(dataVolumePrefix + "/") {
            canonicalPath = String(standardizedPath.dropFirst(dataVolumePrefix.count))
        } else {
            canonicalPath = standardizedPath
        }
        return .path(canonicalPath)
    }

    private static func shouldPrefer(_ candidate: FileNode, over existing: FileNode) -> Bool {
        let candidateIsDataVolumePath = candidate.path.hasPrefix("/System/Volumes/Data/")
        let existingIsDataVolumePath = existing.path.hasPrefix("/System/Volumes/Data/")
        if candidateIsDataVolumePath != existingIsDataVolumePath {
            return !candidateIsDataVolumePath
        }
        if candidate.path.count != existing.path.count {
            return candidate.path.count < existing.path.count
        }
        return candidate.path < existing.path
    }
}
