import Testing
import Foundation
@testable import DiskAnalysisCore

@Suite("Disk Scanner Tests")
struct ScannerTests {
    @Test("DarwinBulkScanner reads temporary directory")
    func testBulkScannerReadsDir() throws {
        let tempDir = FileManager.default.temporaryDirectory.path
        let entries = DarwinBulkScanner.shared.readDirectory(at: tempDir)
        #expect(!entries.isEmpty)
    }

    @Test("DiskScannerEngine scans synthetic test hierarchy")
    func testScannerEngine() async throws {
        let fileManager = FileManager.default
        let testDir = fileManager.temporaryDirectory.appendingPathComponent("DiskAnalysisTest_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: testDir) }

        // Create test files
        let subDir = testDir.appendingPathComponent("SubFolder")
        try fileManager.createDirectory(at: subDir, withIntermediateDirectories: true)

        let file1 = testDir.appendingPathComponent("test1.txt")
        let file2 = subDir.appendingPathComponent("test2.mp4")
        let data1 = Data(repeating: 65, count: 1024) // 1KB
        let data2 = Data(repeating: 66, count: 4096) // 4KB

        try data1.write(to: file1)
        try data2.write(to: file2)

        let engine = DiskScannerEngine()
        let rootNode = try await engine.scan(rootURL: testDir, treatPackagesAsFiles: true) { _ in }

        #expect(rootNode.children.count == 2)
        #expect(rootNode.logicalSize >= 5120)
        #expect(rootNode.itemCount == 2)
        #expect(rootNode.children.first(where: { $0.name == "SubFolder" })?.children.map(\.name) == ["test2.mp4"])
    }

    @Test("DiskScannerEngine keeps mounted volumes as separate scan targets")
    func testVolumeBoundary() {
        #expect(DiskScannerEngine.shouldScanDirectory(rootDevice: 1, directoryDevice: 1))
        #expect(!DiskScannerEngine.shouldScanDirectory(rootDevice: 1, directoryDevice: 2))
        #expect(!DiskScannerEngine.shouldScanDirectory(rootDevice: 1, directoryDevice: nil))
        #expect(DiskScannerEngine.shouldScanDirectory(rootDevice: nil, directoryDevice: 1))
        #expect(DiskScannerEngine.shouldScanDirectory(rootDevice: -1, directoryDevice: -1))
        #expect(!DiskScannerEngine.shouldScanDirectory(rootDevice: -1, directoryDevice: 1))
    }

    @Test("DiskScannerEngine scans real system path with fast throughput")
    func testRealSystemScan() async throws {
        let targetURL = URL(fileURLWithPath: "/Library/Fonts")
        guard FileManager.default.fileExists(atPath: targetURL.path) else { return }

        let engine = DiskScannerEngine()
        let rootNode = try await engine.scan(rootURL: targetURL, treatPackagesAsFiles: true) { _ in }

        #expect(rootNode.children.count > 0)
        #expect(rootNode.effectiveSize > 0)
        #expect(rootNode.itemCount > 0)
    }
}
