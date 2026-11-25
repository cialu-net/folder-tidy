import XCTest
@testable import FolderTidy

final class FolderTidyTests: XCTestCase {
    func testRecoveryAfterInterruptedMove() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("one".utf8).write(to: root.appending(path: "one.pdf"))
        try Data("two".utf8).write(to: root.appending(path: "two.pdf"))
        let store = JournalStore(url: root.appending(path: ".journal"))
        let engine = FolderOrganizer(store: store, makeBookmark: { _ in nil })
        let moves = try await engine.preview(folder: root, rules: [], groupByDate: false)
        let journal = OrganizationJournal(root: root, moves: moves)
        try store.persist([journal])
        let first = try XCTUnwrap(moves.first)
        try FileManager.default.createDirectory(at: first.destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: first.source, to: first.destination)
        let reloaded = try XCTUnwrap(store.loadChecked().first)
        try await engine.undo(reloaded)
        for move in moves { XCTAssertTrue(FileManager.default.fileExists(atPath: move.source.path)) }
    }
    func testOrganizeAndUndoPreservesFile() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appending(path: "report.pdf"); try Data("hello".utf8).write(to: source)
        let store = JournalStore(url: root.appending(path: "journal.json"))
        let engine = FolderOrganizer(store: store, makeBookmark: { _ in nil })
        let plan = try await engine.preview(folder: root, rules: [], groupByDate: false).filter { $0.source.lastPathComponent == source.lastPathComponent }
        let journal = try await engine.organize(plan)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try store.loadChecked().count, 1)
        try await engine.undo(journal)
        XCTAssertEqual(try Data(contentsOf: source), Data("hello".utf8))
    }
    func testUndoRejectsReplacedFile() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appending(path: "report.pdf"); try Data("original".utf8).write(to: source)
        let engine = FolderOrganizer(store: JournalStore(url: root.appending(path: ".journal")), makeBookmark: { _ in nil })
        let plan = try await engine.preview(folder: root, rules: [], groupByDate: false)
        let journal = try await engine.organize(plan)
        let target = try XCTUnwrap(journal.moves.first?.destination)
        try FileManager.default.moveItem(at: target, to: root.appending(path: "original-backup"))
        try Data("replacement".utf8).write(to: target)
        do { try await engine.undo(journal); XCTFail("Undo must reject a replacement") } catch { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: target), Data("replacement".utf8))
    }
    func testCategoryRecognition() { XCTAssertEqual(FileCategory.category(for: URL(fileURLWithPath: "/tmp/photo.JPG")), .images); XCTAssertEqual(FileCategory.category(for: URL(fileURLWithPath: "/tmp/report.pdf")), .documents) }
    func testRuleMatchingIsCaseInsensitive() { let rule = TidyRule(name: "Photos", extensions: ["jpg"], destination: "Photos"); XCTAssertTrue(rule.matches(URL(fileURLWithPath: "/tmp/A.JPG"))) }
    func testPreviewExcludesHiddenFiles() async throws { let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: dir) }; try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true); FileManager.default.createFile(atPath: dir.appending(path: "visible.pdf").path, contents: Data()); FileManager.default.createFile(atPath: dir.appending(path: ".hidden.pdf").path, contents: Data()); let moves = try await FolderOrganizer().preview(folder: dir, rules: [], groupByDate: false); XCTAssertEqual(moves.count, 1); XCTAssertEqual(moves.first?.category, .documents) }
}
