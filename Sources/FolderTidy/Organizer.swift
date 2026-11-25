import Foundation
import Combine

enum OrganizerError: LocalizedError {
    case invalidFolder, collision(URL), inaccessible(URL)
    var errorDescription: String? {
        switch self { case .invalidFolder: return "Choose a readable folder."
        case .collision(let url): return "A file already exists at \(url.lastPathComponent)."
        case .inaccessible(let url): return "Cannot access \(url.lastPathComponent)." }
    }
}

actor FolderOrganizer {
    private let fm = FileManager.default

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
            if groupByDate, let date = values.creationDate {
                let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM"
                folderName += "/" + formatter.string(from: date)
            }
            let target = uniqueDestination(in: folder.appending(path: folderName), filename: url.lastPathComponent)
            return PlannedMove(source: url, destination: target, category: category)
        }
    }

    func organize(_ moves: [PlannedMove]) throws -> OrganizationJournal {
        let chosen = moves.filter(\.selected)
        for move in chosen {
            guard fm.fileExists(atPath: move.source.path) else { throw OrganizerError.inaccessible(move.source) }
            if fm.fileExists(atPath: move.destination.path) { throw OrganizerError.collision(move.destination) }
        }
        var completed: [PlannedMove] = []
        do {
            for move in chosen {
                try fm.createDirectory(at: move.destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(at: move.source, to: move.destination); completed.append(move)
            }
            return OrganizationJournal(root: chosen.first?.source.deletingLastPathComponent() ?? URL(fileURLWithPath: "/"), moves: chosen, completed: true)
        } catch {
            for move in completed.reversed() { try? fm.moveItem(at: move.destination, to: move.source) }
            throw error
        }
    }

    func undo(_ journal: OrganizationJournal) throws {
        for move in journal.moves.reversed() {
            guard fm.fileExists(atPath: move.destination.path) else { continue }
            guard !fm.fileExists(atPath: move.source.path) else { throw OrganizerError.collision(move.source) }
            try fm.moveItem(at: move.destination, to: move.source)
        }
    }

    private func uniqueDestination(in folder: URL, filename: String) -> URL {
        var candidate = folder.appending(path: filename); var n = 2
        while fm.fileExists(atPath: candidate.path) { candidate = folder.appending(path: "\(candidate.deletingPathExtension().lastPathComponent) \(n).\(candidate.pathExtension)"); n += 1 }
        return candidate
    }
}

final class JournalStore {
    private let key = "FolderTidy.journals"
    func load() -> [OrganizationJournal] { guard let data = UserDefaults.standard.data(forKey: key) else { return [] }; return (try? JSONDecoder().decode([OrganizationJournal].self, from: data)) ?? [] }
    func save(_ journals: [OrganizationJournal]) { UserDefaults.standard.set(try? JSONEncoder().encode(journals), forKey: key) }
}

final class RuleStore: ObservableObject {
    @Published var rules: [TidyRule] { didSet { UserDefaults.standard.set(try? JSONEncoder().encode(rules), forKey: "FolderTidy.rules") } }
    init() { rules = (UserDefaults.standard.data(forKey: "FolderTidy.rules").flatMap { try? JSONDecoder().decode([TidyRule].self, from: $0) }) ?? [] }
}
