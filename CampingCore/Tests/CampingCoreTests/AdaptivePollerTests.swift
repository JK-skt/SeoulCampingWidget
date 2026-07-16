import XCTest
@testable import CampingCore

final class AdaptivePollerTests: XCTestCase {

    private let opening = Date(timeIntervalSince1970: 1_800_000_000)

    func testIdleWhenNoOpening() {
        let poller = AdaptivePoller(openingDate: nil)
        XCTAssertEqual(poller.phase(at: opening), .idle)
        XCTAssertEqual(poller.interval(at: opening), 15 * 60)
    }

    func testPreOpenWithinTenMinutes() {
        let poller = AdaptivePoller(openingDate: opening)
        let fiveMinBefore = opening.addingTimeInterval(-5 * 60)
        XCTAssertEqual(poller.phase(at: fiveMinBefore), .preOpen)
        XCTAssertEqual(poller.interval(at: fiveMinBefore), 60)
    }

    func testOpeningWindow() {
        let poller = AdaptivePoller(openingDate: opening, openWindow: 300)
        let justAfter = opening.addingTimeInterval(30)
        XCTAssertEqual(poller.phase(at: justAfter), .opening)
        XCTAssertEqual(poller.interval(at: justAfter), 10)
    }

    func testIdleWellBeforeOpening() {
        let poller = AdaptivePoller(openingDate: opening)
        let oneHourBefore = opening.addingTimeInterval(-3600)
        XCTAssertEqual(poller.phase(at: oneHourBefore), .idle)
    }
}
