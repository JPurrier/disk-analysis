import Foundation

public struct VolumeInfo: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let name: String
    public let url: URL
    public let totalCapacity: Int64
    public let availableCapacity: Int64
    public let isBootVolume: Bool
    public let isRemovable: Bool
    public let isInternal: Bool
    public let fileSystemType: String

    public var isExternal: Bool {
        !isInternal || isRemovable
    }

    public var usedCapacity: Int64 {
        max(0, totalCapacity - availableCapacity)
    }

    public var usedPercentage: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(usedCapacity) / Double(totalCapacity)
    }

    public init(
        name: String,
        url: URL,
        totalCapacity: Int64,
        availableCapacity: Int64,
        isBootVolume: Bool,
        isRemovable: Bool,
        isInternal: Bool,
        fileSystemType: String
    ) {
        self.name = name
        self.url = url
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
        self.isBootVolume = isBootVolume
        self.isRemovable = isRemovable
        self.isInternal = isInternal
        self.fileSystemType = fileSystemType
    }
}
