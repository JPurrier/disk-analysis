import Foundation
import Observation

@Observable
public final class FileNode: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let name: String
    public let url: URL
    public let path: String
    public let isDirectory: Bool
    public let isPackage: Bool
    public var logicalSize: Int64
    public var physicalSize: Int64
    public var itemCount: Int
    public let modifiedDate: Date?
    public let fileExtension: String
    public let kind: FileKind
    
    public var children: [FileNode]
    public weak var parent: FileNode?

    public static func isProtectedPath(_ path: String) -> Bool {
        let normalizedPath = URL(fileURLWithPath: path).standardized.path
        let dataVolume = "/System/Volumes/Data"
        if normalizedPath == dataVolume {
            return true
        }
        // The boot data volume contains the user's files under /Users.
        if normalizedPath.hasPrefix(dataVolume + "/Users/") {
            return false
        }

        let protectedPrefixes = [
            "/",
            "/System",
            "/usr",
            "/bin",
            "/sbin",
            "/Applications",
            "/private/var"
        ]
        return protectedPrefixes.contains { prefix in
            normalizedPath == prefix || normalizedPath.hasPrefix(prefix + "/")
        }
    }

    /// Native SwiftUI outline views use `nil` to mark a leaf node.
    public var outlineChildren: [FileNode]? {
        children.isEmpty ? nil : children
    }

    public init(
        name: String,
        url: URL,
        isDirectory: Bool,
        isPackage: Bool = false,
        logicalSize: Int64 = 0,
        physicalSize: Int64 = 0,
        itemCount: Int = 1,
        modifiedDate: Date? = nil,
        fileExtension: String? = nil,
        children: [FileNode] = [],
        parent: FileNode? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.path = url.path
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.logicalSize = logicalSize
        self.physicalSize = physicalSize
        self.itemCount = itemCount
        self.modifiedDate = modifiedDate
        let ext = fileExtension ?? url.pathExtension
        self.fileExtension = ext
        self.kind = FileKind(extensionName: ext)
        self.children = children
        self.parent = parent

        for child in children {
            child.parent = self
        }
    }

    public var effectiveSize: Int64 {
        // Physical allocation is the primary measure of disk occupancy
        return physicalSize > 0 ? physicalSize : logicalSize
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: effectiveSize, countStyle: .file)
    }

    public var formattedLogicalSize: String {
        ByteCountFormatter.string(fromByteCount: logicalSize, countStyle: .file)
    }

    public var formattedPhysicalSize: String {
        ByteCountFormatter.string(fromByteCount: physicalSize, countStyle: .file)
    }

    public func percentage(of total: Int64) -> Double {
        guard total > 0 else { return 0 }
        return Double(effectiveSize) / Double(total)
    }

    public var breadcrumbs: [FileNode] {
        var trail: [FileNode] = [self]
        var curr = parent
        while let p = curr {
            trail.insert(p, at: 0)
            curr = p.parent
        }
        return trail
    }

    public func sortChildrenBySize() {
        children.sort { $0.effectiveSize > $1.effectiveSize }
        for child in children where child.isDirectory && !child.isPackage {
            child.sortChildrenBySize()
        }
    }

    /// Recursively recalculate aggregated sizes and item counts up the tree
    public func recalculateAggregates() {
        if isDirectory && !isPackage && !children.isEmpty {
            var sumLogical: Int64 = 0
            var sumPhysical: Int64 = 0
            var sumItems = 0
            for child in children {
                child.recalculateAggregates()
                sumLogical += child.logicalSize
                sumPhysical += child.physicalSize
                sumItems += child.itemCount
            }
            self.logicalSize = sumLogical
            self.physicalSize = sumPhysical
            self.itemCount = sumItems
        }
    }

    /// Prune child from tree and update sizes all the way to root
    public func removeChild(withId targetId: UUID) -> FileNode? {
        guard let index = children.firstIndex(where: { $0.id == targetId }) else {
            return nil
        }
        let removed = children.remove(at: index)
        removed.parent = nil
        
        // Propagate size reduction upwards
        var current: FileNode? = self
        while let node = current {
            node.logicalSize = max(0, node.logicalSize - removed.logicalSize)
            node.physicalSize = max(0, node.physicalSize - removed.physicalSize)
            node.itemCount = max(0, node.itemCount - removed.itemCount)
            current = node.parent
        }
        return removed
    }
}
