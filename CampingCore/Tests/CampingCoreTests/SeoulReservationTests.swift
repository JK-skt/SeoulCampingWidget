import XCTest
@testable import CampingCore

final class SeoulReservationTests: XCTestCase {

    /// 서울 API 실제 응답과 동일한 형태의 픽스처(실 호출로 확인한 스키마).
    private let realJSON = """
    {
      "ListPublicReservationSport": {
        "list_total_count": 599,
        "RESULT": { "CODE": "INFO-000", "MESSAGE": "정상 처리되었습니다" },
        "row": [
          { "SVCID": "S1", "SVCNM": "난지캠핑장 A구역 2026년", "SVCSTATNM": "접수중",
            "PLACENM": "난지한강공원", "AREANM": "마포구",
            "RCPTBGNDT": "2026-06-01 09:00:00.0", "RCPTENDDT": "2026-07-31 17:00:00.0",
            "SVCURL": "https://yeyak.seoul.go.kr/x" },
          { "SVCID": "S2", "SVCNM": "난지캠핑장 B구역 2026년", "SVCSTATNM": "예약마감",
            "PLACENM": "난지한강공원", "AREANM": "마포구",
            "RCPTBGNDT": "2026-06-01 09:00:00.0", "RCPTENDDT": "2026-07-31 17:00:00.0",
            "SVCURL": "https://yeyak.seoul.go.kr/y" }
        ]
      }
    }
    """

    private struct Wrapper: Decodable { let row: [ReservationService]? }

    func testDecodeRealSchema() throws {
        let data = Data(realJSON.utf8)
        let dict = try JSONDecoder().decode([String: Wrapper].self, from: data)
        let rows = dict["ListPublicReservationSport"]?.row ?? []
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].name, "난지캠핑장 A구역 2026년")
        XCTAssertEqual(rows[0].status, "접수중")
        XCTAssertTrue(rows[0].isOpen)
        XCTAssertFalse(rows[1].isOpen)          // 예약마감
        XCTAssertTrue(rows[0].isNanjiCamping)
        XCTAssertEqual(rows[0].inferredSite, .a)
        XCTAssertEqual(rows[1].inferredSite, .b)
    }

    func testSiteCountsMapping() throws {
        let data = Data(realJSON.utf8)
        let rows = try JSONDecoder().decode([String: Wrapper].self, from: data)["ListPublicReservationSport"]!.row!
        // 2026-07: A구역은 접수중(1), B구역은 예약마감(0)
        let counts = SeoulReservationDataSource.siteCounts(from: rows, month: MonthKey(year: 2026, month: 7))
        XCTAssertEqual(counts[.a], 1)
        XCTAssertNil(counts[.b])   // 마감이라 집계 제외
    }

    func testMonthMatchingByReceiptWindow() {
        let svc = ReservationService(
            id: "S", name: "난지캠핑장 A구역", status: "접수중",
            place: "난지", area: "마포구",
            receiptBegin: "2026-06-01 00:00:00.0", receiptEnd: "2026-07-31 00:00:00.0", url: nil)
        XCTAssertTrue(SeoulReservationDataSource.matchesMonth(svc, MonthKey(year: 2026, month: 7)))
        XCTAssertFalse(SeoulReservationDataSource.matchesMonth(svc, MonthKey(year: 2026, month: 9)))
    }
}
