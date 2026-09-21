import Foundation

public struct ScanStatistics: Sendable {
    public var filesScanned: Int
    public var foldersScanned: Int
    public var bytesScanned: Int64
    public var currentPath: String
    public var startTime: Date
    public var elapsedTime: TimeInterval
    public var filesPerSecond: Double
    public var isComplete: Bool

    public init(
        filesScanned: Int = 0,
        foldersScanned: Int = 0,
        bytesScanned: Int64 = 0,
        currentPath: String = "",
        startTime: Date = Date(),
        elapsedTime: TimeInterval = 0,
        filesPerSecond: Double = 0,
        isComplete: Bool = false
    ) {
        self.filesScanned = filesScanned
        self.foldersScanned = foldersScanned
        self.bytesScanned = bytesScanned
        self.currentPath = currentPath
        self.startTime = startTime
        self.elapsedTime = elapsedTime
        self.filesPerSecond = filesPerSecond
        self.isComplete = isComplete
    }
}
