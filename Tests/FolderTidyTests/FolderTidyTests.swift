import XCTest
@testable import FolderTidy

final class FolderTidyTests: XCTestCase {
    func testCategoryRecognition() { XCTAssertEqual(FileCategory.category(for: URL(fileURLWithPath: "/tmp/photo.JPG")), .images); XCTAssertEqual(FileCategory.category(for: URL(fileURLWithPath: "/tmp/report.pdf")), .documents) }
    func testRuleMatchingIsCaseInsensitive() { let rule = TidyRule(name: "Photos", extensions: ["jpg"], destination: "Photos"); XCTAssertTrue(rule.matches(URL(fileURLWithPath: "/tmp/A.JPG"))) }
    func testPreviewExcludesHiddenFiles() async throws { let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: dir) }; try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true); FileManager.default.createFile(atPath: dir.appending(path: "visible.pdf").path, contents: Data()); FileManager.default.createFile(atPath: dir.appending(path: ".hidden.pdf").path, contents: Data()); let moves = try await FolderOrganizer().preview(folder: dir, rules: [], groupByDate: false); XCTAssertEqual(moves.count, 1); XCTAssertEqual(moves.first?.category, .documents) }
}
