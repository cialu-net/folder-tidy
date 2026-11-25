import Foundation

func localized(_ key: String) -> String {
    let language = UserDefaults.standard.string(forKey: "language") ?? "system"
    let base = Bundle.main
    let bundle = language == "system" ? base : (base.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? base)
    return bundle.localizedString(forKey: key, value: key, table: nil)
}

enum FileCategory: String, CaseIterable, Codable, Identifiable {
    case images, documents, audio, video, archives, applications, other
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    static func category(for url: URL) -> FileCategory {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff": return .images
        case "pdf", "doc", "docx", "txt", "rtf", "pages", "xls", "xlsx", "ppt", "pptx": return .documents
        case "mp3", "m4a", "wav", "aiff", "flac": return .audio
        case "mov", "mp4", "mkv", "avi", "m4v": return .video
        case "zip", "rar", "7z", "tar", "gz", "dmg": return .archives
        case "app", "pkg": return .applications
        default: return .other
        }
    }
}

struct TidyRule: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var extensions: [String]
    var destination: String
    var isEnabled = true
    func matches(_ url: URL) -> Bool { isEnabled && extensions.contains(url.pathExtension.lowercased()) }
}

struct PlannedMove: Identifiable, Codable, Hashable {
    var id = UUID()
    var source: URL
    var destination: URL
    var category: FileCategory
    var selected = true
    var fileNumber: UInt64? = nil
    var deviceNumber: UInt64? = nil
}

struct OrganizationJournal: Identifiable, Codable {
    var id = UUID()
    var performedAt = Date()
    var root: URL
    var moves: [PlannedMove]
    var completed = false
    var bookmark: Data? = nil
}
