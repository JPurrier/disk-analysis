import SwiftUI

public enum FileCategory: String, CaseIterable, Sendable {
    case application = "Applications & Bundles"
    case video = "Videos"
    case audio = "Audio"
    case archive = "Archives"
    case image = "Images"
    case document = "Documents"
    case code = "Source Code & Scripts"
    case diskImage = "Disk Images & Installers"
    case database = "Databases & Data"
    case system = "System & Library"
    case other = "Other"
}

public struct FileKind: Hashable, Identifiable, Sendable {
    public var id: String { extensionName }
    public let extensionName: String
    public let category: FileCategory
    public let color: Color

    public init(extensionName: String) {
        let ext = extensionName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.extensionName = ext.isEmpty ? "no extension" : ext
        self.category = FileKind.determineCategory(for: ext)
        self.color = FileKind.colorForExtension(ext, category: self.category)
    }

    private static func determineCategory(for ext: String) -> FileCategory {
        switch ext {
        case "app", "framework", "bundle", "plugin", "kext":
            return .application
        case "mp4", "mov", "mkv", "avi", "m4v", "wmv", "flv", "webm", "m2ts":
            return .video
        case "mp3", "m4a", "flac", "wav", "aac", "aiff", "ogg", "wma":
            return .audio
        case "zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "zst":
            return .archive
        case "png", "jpg", "jpeg", "heic", "gif", "tiff", "webp", "svg", "bmp", "raw", "cr2", "nef":
            return .image
        case "pdf", "doc", "docx", "pages", "txt", "rtf", "md", "csv", "xlsx", "numbers", "ppt", "pptx", "key":
            return .document
        case "swift", "c", "cpp", "h", "hpp", "m", "mm", "py", "js", "ts", "jsx", "tsx", "html", "css", "json", "yaml", "yml", "toml", "sh", "zsh", "go", "rs", "java", "kt", "rb", "php":
            return .code
        case "dmg", "iso", "img", "pkg":
            return .diskImage
        case "sqlite", "sqlite3", "db", "realm", "parquet", "arrow", "sql":
            return .database
        case "dylib", "so", "a", "plist", "log", "car", "nib", "strings":
            return .system
        default:
            return .other
        }
    }

    public static func colorForExtension(_ ext: String, category: FileCategory) -> Color {
        // High-contrast, vibrant palette keyed to categories, with hue variation per extension
        if ext.isEmpty || ext == "no extension" {
            return Color(red: 0.55, green: 0.55, blue: 0.6)
        }

        // Hash the extension string to derive unique hue within category band
        var hash: UInt32 = 5381
        for byte in ext.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt32(byte)
        }
        let variation = Double(hash % 100) / 300.0 - 0.16 // +/- 0.16 hue variation

        var baseHue: Double
        var saturation: Double = 0.78
        var brightness: Double = 0.88

        switch category {
        case .application:
            baseHue = 0.58 // Deep Blue
        case .video:
            baseHue = 0.38 // Green / Emerald
            saturation = 0.85
        case .audio:
            baseHue = 0.08 // Orange / Amber
        case .archive:
            baseHue = 0.14 // Yellow / Gold
            saturation = 0.90
            brightness = 0.92
        case .image:
            baseHue = 0.85 // Magenta / Pink
        case .document:
            baseHue = 0.52 // Cyan / Teal
        case .code:
            baseHue = 0.76 // Purple / Violet
        case .diskImage:
            baseHue = 0.02 // Red / Crimson
        case .database:
            baseHue = 0.46 // Aqua
        case .system:
            baseHue = 0.65 // Slate / Indigo
            saturation = 0.55
        case .other:
            baseHue = 0.28 // Lime / Olive
            saturation = 0.60
        }

        let finalHue = (baseHue + variation).truncatingRemainder(dividingBy: 1.0)
        let positiveHue = finalHue < 0 ? finalHue + 1.0 : finalHue
        return Color(hue: positiveHue, saturation: saturation, brightness: brightness)
    }
}
