import XCTest
@testable import GolfYardageCheatsheet

final class AnalysisDateRangeTests: XCTestCase {
    func testAllTimeIncludesEveryShot() {
        let range = AnalysisDateRange.allTime
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertTrue(range.contains(Date(timeIntervalSince1970: 0), now: now))
        XCTAssertTrue(range.contains(Date(timeIntervalSince1970: 20_000), now: now))
    }

    func testLastMonthIncludesOnlyRecentShots() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let range = AnalysisDateRange(kind: .lastMonth)
        let includedDate = calendar.date(byAdding: .day, value: -20, to: now)!
        let excludedDate = calendar.date(byAdding: .day, value: -45, to: now)!

        XCTAssertTrue(range.contains(includedDate, now: now, calendar: calendar))
        XCTAssertFalse(range.contains(excludedDate, now: now, calendar: calendar))
    }

    func testCustomRangeIncludesFullEndDate() {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31))!
        let range = AnalysisDateRange(
            kind: .custom,
            customStartDate: startDate,
            customEndDate: endDate
        )
        let includedDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 23, minute: 59))!
        let excludedDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!

        XCTAssertTrue(range.contains(includedDate, calendar: calendar))
        XCTAssertFalse(range.contains(excludedDate, calendar: calendar))
    }

    func testFilteredUsesShotCreatedAt() {
        let calendar = Calendar(identifier: .gregorian)
        let clubID = UUID()
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31))!
        let includedRecord = ShotRecord(
            profileID: UUID(),
            clubID: clubID,
            category: .normal,
            power: .full,
            distance: 150,
            strikeQuality: .pure,
            direction: .straight,
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 5, day: 12))!
        )
        let excludedRecord = ShotRecord(
            profileID: UUID(),
            clubID: clubID,
            category: .normal,
            power: .full,
            distance: 145,
            strikeQuality: .pure,
            direction: .straight,
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        )

        let range = AnalysisDateRange(
            kind: .custom,
            customStartDate: startDate,
            customEndDate: endDate
        )

        XCTAssertEqual(range.filtered([includedRecord, excludedRecord], calendar: calendar), [includedRecord])
    }
}
