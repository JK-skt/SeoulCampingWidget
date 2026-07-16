import XCTest
@testable import CampingCore

final class ReservationParserTests: XCTestCase {
    private let parser = ReservationParser()

    func testParsesSiteCounts() throws {
        let html = """
        <ul class="camp-list">
          <li data-site="A" data-available="3">A구역</li>
          <li data-site="B" data-available="2">B구역</li>
          <li data-site="C" data-available="0">C구역</li>
          <li data-site="D" data-available="5">D구역</li>
        </ul>
        """
        let counts = try parser.parseSiteCounts(from: html)
        XCTAssertEqual(counts[.a], 3)
        XCTAssertEqual(counts[.b], 2)
        XCTAssertEqual(counts[.c], 0)
        XCTAssertEqual(counts[.d], 5)
    }

    func testParsesReversedAttributeOrder() throws {
        // 속성 순서가 바뀐 경우도 처리.
        let html = #"<div data-available="7" data-site="A"></div>"#
        let counts = try parser.parseSiteCounts(from: html)
        XCTAssertEqual(counts[.a], 7)
    }

    func testThrowsWhenNoMatch() {
        XCTAssertThrowsError(try parser.parseSiteCounts(from: "<html>없음</html>")) { error in
            guard case ReservationError.parsing = error else {
                return XCTFail("parsing 오류를 기대했지만 \(error)")
            }
        }
    }
}
