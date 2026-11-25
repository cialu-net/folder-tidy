import Foundation
import Combine

enum OrganizerError: LocalizedError {
    case invalidFolder, invalidDestination, collision(URL), inaccessible(URL), pendingRecovery, fileChanged(URL)
    var errorDescription: String? {
        switch self { case .invalidFolder: return localized("Choose a readable folder.")
        case .pendingRecovery: return localized("Recover the interrupted operation before organizing more files.")
        case .fileChanged(let url): return String(format: localized("The file has changed since the preview: %@."), url.lastPathComponent)
        case .invalidDestination: return localized("The destination must be a safe folder name inside the selected folder.")
        case .collision(let url): return String(format: localized("A file already exists at %@."), url.lastPathComponent)
        case .inaccessible(let url): return String(format: localized("Cannot access %@."), url.lastPathComponent) }
    }
}

actor FolderOrganizer {
    private let fm = FileManager.default
    private let store: JournalStore
    private let makeBookmark: (URL) throws -> Data?
    init(store: JournalStore = JournalStore(), makeBookmark: @escaping (URL) throws -> Data? = { try $0.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) }) { self.store = store; self.makeBookmark = makeBookmark }

    private func identity(_ url: URL) throws -> (UInt64, UInt64) {
        let attributes = try fm.attributesOfItem(atPath: url.path)
        guard let number = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
              let device = (attributes[.systemNumber] as? NSNumber)?.uint64Value else { throw OrganizerError.inaccessible(url) }
        return (number, device)
    }

    func preview(folder: URL, rules: [TidyRule], groupByDate: Bool) throws -> [PlannedMove] {
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw OrganizerError.invalidFolder }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isHiddenKey, .isSymbolicLinkKey, .creationDateKey]
        let files = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        return try files.compactMap { url in
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true, values.isSymbolicLink != true, values.isHidden != true else { return nil }
            let category = FileCategory.category(for: url)
            let rule = rules.first { $0.matches(url) }
            var folderName = rule?.destination ?? category.title
            guard !folderName.isEmpty, folderName != ".", folderName != "..", !folderName.contains("/"), !folderName.hasPrefix(".") else { throw OrganizerError.invalidDestination }
            if groupByDate, let date = values.creationDate {
                let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM"
                folderName += "/" + formatter.string(from: date)
            }
            let target = uniqueDestination(in: folder.appending(path: folderName), filename: url.lastPathComponent)
            let (number, device) = try identity(url)
            return PlannedMove(source: url, destination: target, category: category, fileNumber: number, deviceNumber: device)
        }
    }

    func organize(_ moves: [PlannedMove]) throws -> OrganizationJournal {
        let chosen = moves.filter(\.selected)
        guard let root = chosen.first?.source.deletingLastPathComponent(), !chosen.isEmpty else { throw OrganizerError.invalidFolder }
        for move in chosen {
            guard move.source.deletingLastPathComponent().standardizedFileURL.path == root.standardizedFileURL.path,
                  move.destination.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/"),
                  move.destination.deletingLastPathComponent().standardizedFileURL.path != root.standardizedFileURL.path,
                  !move.destination.pathComponents.contains(".."),
                  !move.destination.lastPathComponent.isEmpty else { throw OrganizerError.invalidDestination }
            let sourceValues = try move.source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isHiddenKey])
            guard sourceValues.isRegularFile == true, sourceValues.isSymbolicLink != true, sourceValues.isHidden != true else { throw OrganizerError.inaccessible(move.source) }
            let (number, device) = try identity(move.source)
            guard move.fileNumber == number, move.deviceNumber == device else { throw OrganizerError.fileChanged(move.source) }
            var parent = move.destination.deletingLastPathComponent()
            while parent.standardizedFileURL.path != root.standardizedFileURL.path && parent.path != "/" {
                if (try? parent.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { throw OrganizerError.invalidDestination }
                parent.deleteLastPathComponent()
            }
        }
        for move in chosen {
            guard fm.fileExists(atPath: move.source.path) else { throw OrganizerError.inaccessible(move.source) }
            if fm.fileExists(atPath: move.destination.path) { throw OrganizerError.collision(move.destination) }
        }
        let bookmark = try makeBookmark(root)
        var journal = OrganizationJournal(root: root, moves: chosen, bookmark: bookmark)
        var journals = try store.loadChecked(); guard !journals.contains(where: { !$0.completed }) else { throw OrganizerError.pendingRecovery }; journals.insert(journal, at: 0); try store.persist(journals)
        for move in chosen {
            try fm.createDirectory(at: move.destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: move.source, to: move.destination)
        }
        journal.completed = true; journals[0] = journal; try store.persist(journals)
        return journal
    }

    func undo(_ journal: OrganizationJournal) throws {
        var stale = false
        let root = try journal.bookmark.map { try URL(resolvingBookmarkData: $0, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) } ?? journal.root
        guard !stale else { throw OrganizerError.inaccessible(root) }
        let access = root.startAccessingSecurityScopedResource()
        defer { if access { root.stopAccessingSecurityScopedResource() } }
        for move in journal.moves.reversed() {
            let sourceExists = fm.fileExists(atPath: move.source.path)
            let destinationExists = fm.fileExists(atPath: move.destination.path)
            if sourceExists && !destinationExists {
                let (number, device) = try identity(move.source)
                guard move.fileNumber == number, move.deviceNumber == device else { throw OrganizerError.fileChanged(move.source) }
                continue
            }
            guard destinationExists else { throw OrganizerError.inaccessible(move.destination) }
            guard !sourceExists else { throw OrganizerError.collision(move.source) }
            let (number, device) = try identity(move.destination)
            guard move.fileNumber == number, move.deviceNumber == device else { throw OrganizerError.fileChanged(move.destination) }
            try fm.moveItem(at: move.destination, to: move.source)
        }
    }

    private func uniqueDestination(in folder: URL, filename: String) -> URL {
        let original = URL(fileURLWithPath: filename)
        let stem = original.deletingPathExtension().lastPathComponent
        let ext = original.pathExtension
        var candidate = folder.appending(path: filename); var n = 2
        while fm.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(stem) \(n)" : "\(stem) \(n).\(ext)"
            candidate = folder.appending(path: name); n += 1
        }
        return candidate
    }
}

final class JournalStore {
    private let url: URL
    init(url: URL? = nil) { self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "FolderTidy/journal.json") }
    func loadChecked() throws -> [OrganizationJournal] { guard FileManager.default.fileExists(atPath: url.path) else { return [] }; return try JSONDecoder().decode([OrganizationJournal].self, from: Data(contentsOf: url)) }
    func load() -> [OrganizationJournal] { (try? loadChecked()) ?? [] }
    func persist(_ journals: [OrganizationJournal]) throws { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try JSONEncoder().encode(journals).write(to: url, options: .atomic) }
    func save(_ journals: [OrganizationJournal]) { try? persist(journals) }
}

final class RuleStore: ObservableObject {
    @Published var rules: [TidyRule] { didSet { UserDefaults.standard.set(try? JSONEncoder().encode(rules), forKey: "FolderTidy.rules") } }
    init() { rules = (UserDefaults.standard.data(forKey: "FolderTidy.rules").flatMap { try? JSONDecoder().decode([TidyRule].self, from: $0) }) ?? [] }
}
