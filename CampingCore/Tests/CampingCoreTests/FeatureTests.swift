import XCTest
@testable import CampingCore

final class FeatureTests: XCTestCase {

    private func snapshot(_ counts: [Campsite: Int], label: String = "이번달") -> AvailabilitySnapshot {
        let month = MonthKey(year: 2026, month: 7)
        let sites = Campsite.allCases.map { SiteAvailability(site: $0, availableCount: counts[$0] ?? 0) }
        return AvailabilitySnapshot(campground: .nanji,
                                    generatedAt: Date(timeIntervalSince1970: 0),
                                    months: [MonthlyAvailability(month: month, label: label, sites: sites)])
    }

    // MARK: 내보내기

    func testCSVExport() {
        let csv = SnapshotExporter().csv(snapshot([.a: 3, .b: 0]))
        XCTAssertTrue(csv.hasPrefix("month,label,site,available"))
        XCTAssertTrue(csv.contains("2026-07,이번달,A,3"))
        XCTAssertTrue(csv.contains("2026-07,이번달,B,0"))
    }

    func testJSONExportRoundTrip() throws {
        let original = snapshot([.a: 5])
        let data = try SnapshotExporter().json(original)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AvailabilitySnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testExcelCSVHasBOM() {
        let data = SnapshotExporter().excelCompatibleCSV(snapshot([.a: 1]))
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
    }

    // MARK: 변화 감지

    func testNewlyAvailableDetectsIncrease() {
        let prev = snapshot([.a: 1, .b: 2])
        let curr = snapshot([.a: 3, .b: 2]) // A만 증가
        let changes = AvailabilityDiff.newlyAvailable(previous: prev, current: curr)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.site, .a)
        XCTAssertEqual(changes.first?.currentCount, 3)
    }

    func testNoChangeWhenPreviousNil() {
        let changes = AvailabilityDiff.newlyAvailable(previous: nil, current: snapshot([.a: 9]))
        XCTAssertTrue(changes.isEmpty)
    }

    // MARK: 즐겨찾기 필터

    func testFavoritesFilter() {
        let favorites = Favorites(sites: [.a, .c])
        let filtered = snapshot([.a: 1, .b: 2, .c: 3, .d: 4]).filtered(by: favorites)
        let sites = filtered.months[0].sites.map(\.site)
        XCTAssertEqual(Set(sites), [.a, .c])
    }

    func testEmptyFavoritesIncludesAll() {
        let filtered = snapshot([.a: 1, .b: 2]).filtered(by: Favorites(sites: []))
        XCTAssertEqual(filtered.months[0].sites.count, 4)
    }

    // MARK: 히트맵

    func testHeatmapWeekendCells() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let cells = HeatmapBuilder.weekendCells(month: snapshot([.a: 4, .b: 4]).months[0], calendar: cal)
        XCTAssertFalse(cells.isEmpty)
        XCTAssertTrue(cells.allSatisfy { $0.isWeekend })
        XCTAssertTrue(cells.allSatisfy { (0.0...1.0).contains($0.intensity) })
    }
}
