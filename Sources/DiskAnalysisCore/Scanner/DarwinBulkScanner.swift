import Foundation
import Darwin

public struct RawDirEntry: Sendable {
    public let name: String
    public let isDirectory: Bool
    public let isPackage: Bool
    public let logicalSize: Int64
    public let physicalSize: Int64
    public let modifiedDate: Date?

    public init(
        name: String,
        isDirectory: Bool,
        isPackage: Bool = false,
        logicalSize: Int64 = 0,
        physicalSize: Int64 = 0,
        modifiedDate: Date? = nil
    ) {
        self.name = name
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.logicalSize = logicalSize
        self.physicalSize = physicalSize
        self.modifiedDate = modifiedDate
    }
}

public final class DarwinBulkScanner: Sendable {
    public static let shared = DarwinBulkScanner()

    public init() {}

    func deviceNumber(at path: String) -> Int64? {
        var statBuffer = stat()
        guard stat(path, &statBuffer) == 0 else { return nil }
        return Int64(statBuffer.st_dev)
    }

    /// Reads directory entries using Darwin getattrlistbulk for maximum speed, with fallback to readdir/stat
    public func readDirectory(at path: String, treatPackagesAsFiles: Bool = true) -> [RawDirEntry] {
        var entries: [RawDirEntry] = []

        let dirfd = open(path, O_RDONLY | O_DIRECTORY)
        guard dirfd >= 0 else {
            // Permission denied or unreadable; return empty
            return []
        }
        defer { close(dirfd) }

        // Setup attrlist for getattrlistbulk
        var alist = attrlist()
        alist.bitmapcount = UInt16(ATTR_BIT_MAP_COUNT)
        alist.commonattr = attrgroup_t(ATTR_CMN_NAME | ATTR_CMN_OBJTYPE | ATTR_CMN_MODTIME)
        alist.fileattr = attrgroup_t(ATTR_FILE_TOTALSIZE | ATTR_FILE_ALLOCSIZE)

        let bufferSize = 64 * 1024 // 64KB buffer
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: MemoryLayout<Int>.alignment)
        defer { buffer.deallocate() }

        var count: Int32 = 0
        repeat {
            count = getattrlistbulk(dirfd, &alist, buffer, bufferSize, 0)
            if count > 0 {
                var currentPtr = buffer
                for _ in 0..<count {
                    let entryLength = currentPtr.load(as: UInt32.self)
                    guard entryLength > 0 else { break }

                    // Parse entry
                    var fieldPtr = currentPtr.advanced(by: MemoryLayout<UInt32>.stride)

                    // attrreference for name
                    let nameRef = fieldPtr.load(as: attrreference_t.self)
                    let nameOffset = Int(nameRef.attr_dataoffset)
                    let namePtr = fieldPtr.advanced(by: nameOffset).assumingMemoryBound(to: CChar.self)
                    let name = String(cString: namePtr)
                    fieldPtr = fieldPtr.advanced(by: MemoryLayout<attrreference_t>.stride)

                    // obj_type
                    let objType = fieldPtr.load(as: fsobj_type_t.self)
                    let isDir = (objType == VDIR.rawValue)
                    fieldPtr = fieldPtr.advanced(by: MemoryLayout<fsobj_type_t>.stride)

                    // mod_time (struct timespec)
                    let modTime = fieldPtr.load(as: timespec.self)
                    let date = Date(timeIntervalSince1970: TimeInterval(modTime.tv_sec))
                    fieldPtr = fieldPtr.advanced(by: MemoryLayout<timespec>.stride)

                    var logical: Int64 = 0
                    var physical: Int64 = 0

                    if !isDir {
                        // total_size (off_t)
                        let totalSize = fieldPtr.load(as: off_t.self)
                        logical = Int64(max(0, totalSize))
                        fieldPtr = fieldPtr.advanced(by: MemoryLayout<off_t>.stride)

                        // alloc_size (off_t)
                        let allocSize = fieldPtr.load(as: off_t.self)
                        physical = Int64(max(0, allocSize))
                    }

                    // Ignore "." and ".."
                    if name != "." && name != ".." {
                        let isPackage = isDir && treatPackagesAsFiles && Self.isPackageName(name)

                        entries.append(RawDirEntry(
                            name: name,
                            isDirectory: isDir,
                            isPackage: isPackage,
                            logicalSize: logical,
                            physicalSize: physical,
                            modifiedDate: date
                        ))
                    }

                    currentPtr = currentPtr.advanced(by: Int(entryLength))
                }
            }
        } while count > 0

        // If getattrlistbulk returned no entries (e.g. network filesystem or virtual mount), fallback to POSIX opendir
        if entries.isEmpty {
            entries = readDirectoryFallback(at: path, treatPackagesAsFiles: treatPackagesAsFiles)
        }

        return entries
    }

    private func readDirectoryFallback(at path: String, treatPackagesAsFiles: Bool) -> [RawDirEntry] {
        var entries: [RawDirEntry] = []
        guard let dir = opendir(path) else { return [] }
        defer { closedir(dir) }

        while let entry = readdir(dir) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { rawPtr -> String in
                guard let base = rawPtr.baseAddress?.assumingMemoryBound(to: CChar.self) else { return "" }
                return String(cString: base)
            }

            if name == "." || name == ".." || name.isEmpty { continue }

            let isDir = entry.pointee.d_type == DT_DIR
            let fullPath = (path as NSString).appendingPathComponent(name)

            var statBuf = stat()
            var logical: Int64 = 0
            var physical: Int64 = 0
            var date: Date? = nil

            if lstat(fullPath, &statBuf) == 0 {
                if !isDir {
                    logical = Int64(statBuf.st_size)
                    physical = Int64(statBuf.st_blocks) * 512
                }
                date = Date(timeIntervalSince1970: TimeInterval(statBuf.st_mtimespec.tv_sec))
            }

            let isPackage = isDir && treatPackagesAsFiles && Self.isPackageName(name)

            entries.append(RawDirEntry(
                name: name,
                isDirectory: isDir,
                isPackage: isPackage,
                logicalSize: logical,
                physicalSize: physical,
                modifiedDate: date
            ))
        }

        return entries
    }

    public static func isPackageName(_ name: String) -> Bool {
        let packageExtensions: Set<String> = [
            "app", "framework", "bundle", "kext", "plugin", "photoslibrary", "photolibrary",
            "aplibrary", "migratedphotolibrary", "imovielibrary", "fcpbundle", "logicx", "band", "scptd"
        ]
        let ext = (name as NSString).pathExtension.lowercased()
        return packageExtensions.contains(ext)
    }
}
