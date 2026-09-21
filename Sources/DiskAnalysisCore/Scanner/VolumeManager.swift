import Foundation

public final class VolumeManager: Sendable {
    public static let shared = VolumeManager()

    public init() {}

    /// Discovers all mounted volumes eligible for scanning
    public func discoverVolumes() -> [VolumeInfo] {
        var volumes: [VolumeInfo] = []
        let fileManager = FileManager.default

        // Standard mounted volume keys
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsInternalKey,
            .volumeIsRemovableKey,
            .volumeIsRootFileSystemKey,
            .volumeTypeNameKey
        ]

        if let volumeURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) {
            for url in volumeURLs {
                if let resourceValues = try? url.resourceValues(forKeys: Set(keys)),
                   let name = resourceValues.volumeName,
                   let totalCapacity = resourceValues.volumeTotalCapacity {
                    let available = resourceValues.volumeAvailableCapacity ?? 0
                    let isRoot = resourceValues.volumeIsRootFileSystem ?? false
                    let isInternal = resourceValues.volumeIsInternal ?? true
                    let isRemovable = resourceValues.volumeIsRemovable ?? false
                    let typeName = resourceValues.volumeTypeName ?? "APFS"

                    // Check if this is the boot data volume
                    let isBoot = isRoot || url.path == "/System/Volumes/Data" || url.path == "/"

                    volumes.append(VolumeInfo(
                        name: name,
                        url: url,
                        totalCapacity: Int64(totalCapacity),
                        availableCapacity: Int64(available),
                        isBootVolume: isBoot,
                        isRemovable: isRemovable,
                        isInternal: isInternal,
                        fileSystemType: typeName
                    ))
                }
            }
        }

        // Add direct system data volume if not explicitly in mounted list
        let dataVolumeURL = URL(fileURLWithPath: "/System/Volumes/Data")
        if !volumes.contains(where: { $0.url.path == dataVolumeURL.path }) && fileManager.fileExists(atPath: dataVolumeURL.path) {
            if let values = try? dataVolumeURL.resourceValues(forKeys: Set(keys)) {
                volumes.insert(VolumeInfo(
                    name: "Macintosh HD (System & Data)",
                    url: dataVolumeURL,
                    totalCapacity: Int64(values.volumeTotalCapacity ?? 0),
                    availableCapacity: Int64(values.volumeAvailableCapacity ?? 0),
                    isBootVolume: true,
                    isRemovable: false,
                    isInternal: true,
                    fileSystemType: values.volumeTypeName ?? "APFS"
                ), at: 0)
            }
        }

        // Ensure default boot volume is at index 0
        volumes.sort { (a, b) -> Bool in
            if a.isBootVolume && !b.isBootVolume { return true }
            if !a.isBootVolume && b.isBootVolume { return false }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        return volumes
    }

    /// Returns the recommended default scan target URL
    public func defaultScanTarget() -> URL {
        let dataVolume = URL(fileURLWithPath: "/System/Volumes/Data")
        if FileManager.default.fileExists(atPath: dataVolume.path) {
            return dataVolume
        }
        return URL(fileURLWithPath: "/")
    }
}
