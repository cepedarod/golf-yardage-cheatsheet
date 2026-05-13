import XCTest
@testable import GolfYardageCheatsheet

final class FileGolfBagStoreTests: XCTestCase {
    func testLoadReturnsEmptyDataWhenFileDoesNotExist() throws {
        let store = FileGolfBagStore(fileURL: temporaryStoreURL())

        XCTAssertEqual(try store.load(), .empty)
    }

    func testLoadThrowsWhenStoredDataIsCorrupt() throws {
        let fileURL = temporaryStoreURL()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: fileURL)

        XCTAssertThrowsError(try FileGolfBagStore(fileURL: fileURL).load())
    }

    func testSaveCreatesMissingDirectoryAndPersistsData() throws {
        let fileURL = temporaryStoreURL()
        let store = FileGolfBagStore(fileURL: fileURL)
        let now = Date(timeIntervalSince1970: 100)
        let profile = GolferProfile(name: "Rod", createdAt: now, updatedAt: now)
        let data = GolfBagData(profiles: [profile], selectedProfileID: profile.id)

        try store.save(data)

        XCTAssertEqual(try FileGolfBagStore(fileURL: fileURL).load(), data)
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("golf-bag-data.json")
    }
}
