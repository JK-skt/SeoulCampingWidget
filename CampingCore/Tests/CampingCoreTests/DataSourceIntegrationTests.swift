import XCTest
@testable import CampingCore

final class DataSourceIntegrationTests: XCTestCase {

    func testSeoulOpenAPIURLBuilder() {
        let url = SeoulOpenAPIDataSource.buildURL(
            baseURL: "http://openapi.seoul.go.kr:8088",
            key: "TESTKEY", service: "CampSvc", start: 1, end: 50)
        XCTAssertEqual(url?.absoluteString,
                       "http://openapi.seoul.go.kr:8088/TESTKEY/json/CampSvc/1/50/")
    }

    func testSeoulOpenAPIThrowsWithoutKey() async {
        let ds = SeoulOpenAPIDataSource() // 키/디코더 없음
        do {
            _ = try await ds.siteCounts(campground: .nanji, month: MonthKey(year: 2026, month: 7))
            XCTFail("notImplemented 오류를 기대")
        } catch {
            guard case ReservationError.notImplemented = error else {
                return XCTFail("notImplemented 기대, 실제 \(error)")
            }
        }
    }

    #if os(macOS)
    func testProcessCrawlerParsesShellOutput() async throws {
        // node 대신 /bin/sh로 계약 HTML을 출력해 파이프라인 검증.
        let ds = ProcessCrawlerDataSource(
            launchPath: "/bin/sh",
            argumentsBuilder: { _, _ in
                ["-c", #"printf '<i data-site="A" data-available="8"></i><i data-site="D" data-available="1"></i>'"#]
            })
        let counts = try await ds.siteCounts(campground: .nanji, month: MonthKey(year: 2026, month: 7))
        XCTAssertEqual(counts[.a], 8)
        XCTAssertEqual(counts[.d], 1)
    }

    func testProcessCrawlerThrowsOnNonZeroExit() async {
        let ds = ProcessCrawlerDataSource(
            launchPath: "/bin/sh",
            argumentsBuilder: { _, _ in ["-c", "exit 3"] })
        do {
            _ = try await ds.siteCounts(campground: .nanji, month: MonthKey(year: 2026, month: 7))
            XCTFail("실패를 기대")
        } catch {
            // network 오류(종료 코드) 기대
            guard case ReservationError.network = error else {
                return XCTFail("network 오류 기대, 실제 \(error)")
            }
        }
    }
    #endif
}
