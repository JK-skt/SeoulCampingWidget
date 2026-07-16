import XCTest
@testable import CampingCore

final class YeyakCampingTests: XCTestCase {

    /// 실제 yeyak 캠핑장 목록 HTML과 동일 구조의 픽스처.
    private let fixture = """
    <ul class="img_board">
      <li>
        <a href="#" onclick="fnDetailPage('S260702152441583868', '', ''); return false;"
           title="8월 일반캠핑존 A형(2인용, 자갈형) 26년 한강공원 난지캠핑장">
          <span class="bd_label status1">접수중</span>
        </a>
      </li>
      <li>
        <a href="#" onclick="fnDetailPage('S260702154942790151', '', ''); return false;"
           title="8월 일반캠핑존 B형(4인용, 자갈형) 26년 한강공원 난지캠핑장">
          <span class="bd_label status4">예약마감</span>
        </a>
      </li>
      <li>
        <a href="#" onclick="fnDetailPage('S999', '', ''); return false;"
           title="8월 프리캠핑존 (4인용, 잔디형) 26년 한강공원 난지캠핑장">
          <span class="bd_label status1">접수중</span>
        </a>
      </li>
    </ul>
    """

    func testParsesServices() {
        let services = YeyakCampingClient.parseServices(from: fixture)
        XCTAssertEqual(services.count, 3)
        XCTAssertEqual(services[0].svcId, "S260702152441583868")
        XCTAssertTrue(services[0].title.contains("일반캠핑존 A형"))
        XCTAssertEqual(services[0].status, "접수중")
        XCTAssertTrue(services[0].isOpen)
        XCTAssertFalse(services[1].isOpen)   // 예약마감
        XCTAssertEqual(services[0].inferredSite, .a)
        XCTAssertEqual(services[1].inferredSite, .b)
        XCTAssertNil(services[2].inferredSite) // 프리캠핑존 = 구역 없음
    }

    func testReservationURL() {
        let s = YeyakService(svcId: "S123", title: "x", status: "접수중")
        XCTAssertEqual(s.reservationURL?.absoluteString,
                       "https://yeyak.seoul.go.kr/web/reservation/selectReservView.do?rsv_svc_id=S123")
    }

    func testSiteCountsForMonth() {
        let services = YeyakCampingClient.parseServices(from: fixture)
        // 8월: A형 접수중(1), B형 마감(제외), 프리캠핑존(구역 없음 제외)
        let counts = YeyakCampingDataSource.siteCounts(from: services, month: MonthKey(year: 2026, month: 8))
        XCTAssertEqual(counts[.a], 1)
        XCTAssertNil(counts[.b])
        // 7월엔 8월 서비스가 매칭되지 않아 비어야 한다.
        let july = YeyakCampingDataSource.siteCounts(from: services, month: MonthKey(year: 2026, month: 7))
        XCTAssertTrue(july.isEmpty)
    }
}
