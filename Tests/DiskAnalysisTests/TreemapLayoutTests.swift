import Testing
import Foundation
import CoreGraphics
@testable import DiskAnalysisCore

@Suite("Treemap Layout Tests")
struct TreemapLayoutTests {
    @Test("Squarified layout tiles within bounds")
    func testSquarifiedLayoutBounds() throws {
        let root = FileNode(name: "Root", url: URL(fileURLWithPath: "/test"), isDirectory: true)

        let child1 = FileNode(name: "video.mp4", url: URL(fileURLWithPath: "/test/video.mp4"), isDirectory: false, logicalSize: 50_000_000, physicalSize: 50_000_000)
        let child2 = FileNode(name: "archive.zip", url: URL(fileURLWithPath: "/test/archive.zip"), isDirectory: false, logicalSize: 30_000_000, physicalSize: 30_000_000)
        let child3 = FileNode(name: "doc.pdf", url: URL(fileURLWithPath: "/test/doc.pdf"), isDirectory: false, logicalSize: 20_000_000, physicalSize: 20_000_000)

        root.children = [child1, child2, child3]
        child1.parent = root
        child2.parent = root
        child3.parent = root
        root.recalculateAggregates()

        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let rects = TreemapLayoutEngine.shared.computeLayout(for: root, in: bounds)

        #expect(rects.count == 3)
        for r in rects {
            #expect(r.rect.minX >= bounds.minX - 0.01)
            #expect(r.rect.maxX <= bounds.maxX + 0.01)
            #expect(r.rect.minY >= bounds.minY - 0.01)
            #expect(r.rect.maxY <= bounds.maxY + 0.01)
            #expect(r.rect.width > 0)
            #expect(r.rect.height > 0)
        }
    }

    @Test("FileNode removeChild propagates size decrease")
    func testNodePruning() throws {
        let root = FileNode(name: "Root", url: URL(fileURLWithPath: "/test"), isDirectory: true)
        let child1 = FileNode(name: "file1.dat", url: URL(fileURLWithPath: "/test/file1.dat"), isDirectory: false, logicalSize: 1000, physicalSize: 1000)
        let child2 = FileNode(name: "file2.dat", url: URL(fileURLWithPath: "/test/file2.dat"), isDirectory: false, logicalSize: 2000, physicalSize: 2000)

        root.children = [child1, child2]
        child1.parent = root
        child2.parent = root
        root.recalculateAggregates()

        #expect(root.logicalSize == 3000)
        #expect(root.itemCount == 2)

        let removed = root.removeChild(withId: child1.id)
        #expect(removed?.id == child1.id)
        #expect(root.logicalSize == 2000)
        #expect(root.itemCount == 1)
    }

    @Test("FileNode outline children distinguish folders from leaves")
    func testOutlineChildren() throws {
        let leaf = FileNode(
            name: "file.txt",
            url: URL(fileURLWithPath: "/test/file.txt"),
            isDirectory: false,
            logicalSize: 100,
            physicalSize: 100
        )
        let folder = FileNode(
            name: "Folder",
            url: URL(fileURLWithPath: "/test/Folder"),
            isDirectory: true,
            children: [leaf]
        )

        #expect(leaf.outlineChildren == nil)
        #expect(folder.outlineChildren?.map(\.id) == [leaf.id])
        #expect(leaf.parent === folder)

        folder.recalculateAggregates()
        #expect(leaf.percentage(of: folder.effectiveSize) == 1)
    }

    @Test("Disk report ranks large files and conservative cleanup candidates")
    func testDiskReport() throws {
        let root = FileNode(name: "Root", url: URL(fileURLWithPath: "/Users/test"), isDirectory: true)
        let largeFile = FileNode(
            name: "large.bin",
            url: URL(fileURLWithPath: "/Users/test/large.bin"),
            isDirectory: false,
            logicalSize: 3_000_000_000,
            physicalSize: 3_000_000_000
        )
        let cacheFile = FileNode(
            name: "cache.db",
            url: URL(fileURLWithPath: "/Users/test/.cache/cache.db"),
            isDirectory: false,
            logicalSize: 2_000_000_000,
            physicalSize: 2_000_000_000
        )
        let cache = FileNode(
            name: ".cache",
            url: URL(fileURLWithPath: "/Users/test/.cache"),
            isDirectory: true,
            children: [cacheFile]
        )
        let systemCache = FileNode(
            name: "Caches",
            url: URL(fileURLWithPath: "/System/Library/Caches"),
            isDirectory: true,
            logicalSize: 2_000_000_000,
            physicalSize: 2_000_000_000
        )
        root.children = [largeFile, cache, systemCache]
        largeFile.parent = root
        cache.parent = root
        systemCache.parent = root
        root.recalculateAggregates()

        let report = DiskReport.build(from: root)

        #expect(report.largeFiles.map(\.name) == ["large.bin", "cache.db"])
        #expect(report.cleanupCandidates.map(\.node.name) == [".cache"])
        #expect(report.cleanupCandidates.first?.reason == "Cache or temporary folder")
        #expect(FileNode.isProtectedPath("/System/Library/Caches"))
        #expect(FileNode.isProtectedPath("/System/Volumes/Data/System/Library/Caches"))
        #expect(!FileNode.isProtectedPath("/System/Volumes/Data/Users/test/.cache"))
        #expect(!FileNode.isProtectedPath("/Users/test/.cache"))
    }

    @Test("Disk report collapses filesystem aliases and prefers user-facing paths")
    func testDiskReportDeduplicatesAliases() throws {
        let fileManager = FileManager.default
        let testDir = fileManager.temporaryDirectory.appendingPathComponent("DiskAnalysisAliases_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: testDir) }

        let hardLink = testDir.appendingPathComponent("hardlink.bin")
        let hardLinkAlias = testDir.appendingPathComponent("hardlink-alias.bin")
        try Data([1]).write(to: hardLink)
        try fileManager.linkItem(at: hardLink, to: hardLinkAlias)

        let dataVolumeAlias = FileNode(
            name: "alias.bin",
            url: URL(fileURLWithPath: "/System/Volumes/Data/Users/test/alias.bin"),
            isDirectory: false,
            logicalSize: 2_000_000_000,
            physicalSize: 2_000_000_000
        )
        let userFacingPath = FileNode(
            name: "alias.bin",
            url: URL(fileURLWithPath: "/Users/test/alias.bin"),
            isDirectory: false,
            logicalSize: 2_000_000_000,
            physicalSize: 2_000_000_000
        )
        let hardLinkNode = FileNode(
            name: hardLink.lastPathComponent,
            url: hardLink,
            isDirectory: false,
            logicalSize: 2_000_000_000,
            physicalSize: 2_000_000_000
        )
        let hardLinkAliasNode = FileNode(
            name: hardLinkAlias.lastPathComponent,
            url: hardLinkAlias,
            isDirectory: false,
            logicalSize: 2_000_000_000,
            physicalSize: 2_000_000_000
        )
        let dataVolumeCacheAlias = FileNode(
            name: ".cache",
            url: URL(fileURLWithPath: "/System/Volumes/Data/Users/test/.cache"),
            isDirectory: true,
            logicalSize: 2_000_000_000,
            physicalSize: 2_000_000_000
        )
        let userFacingCachePath = FileNode(
            name: ".cache",
            url: URL(fileURLWithPath: "/Users/test/.cache"),
            isDirectory: true,
            logicalSize: 2_000_000_000,
            physicalSize: 2_000_000_000
        )
        let root = FileNode(name: "Root", url: testDir, isDirectory: true)
        root.children = [
            dataVolumeAlias,
            userFacingPath,
            hardLinkNode,
            hardLinkAliasNode,
            dataVolumeCacheAlias,
            userFacingCachePath
        ]
        for child in root.children {
            child.parent = root
        }
        root.recalculateAggregates()

        let report = DiskReport.build(from: root)

        #expect(report.largeFiles.count == 2)
        #expect(report.largeFiles.contains(where: { $0.path == userFacingPath.path }))
        #expect(!report.largeFiles.contains(where: { $0.path == dataVolumeAlias.path }))
        #expect(report.largeFiles.contains(where: { $0.path == hardLink.path }))
        #expect(!report.largeFiles.contains(where: { $0.path == hardLinkAlias.path }))
        #expect(report.cleanupCandidates.count == 1)
        #expect(report.cleanupCandidates.first?.node.path == userFacingCachePath.path)
    }
}
