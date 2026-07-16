import XCTest
@testable import CampingCore

final class DateHelperTests: XCTestCase {

    /// 고정 그레고리력 + UTC 캘린더로 결정론적 테스트를 보장한다.
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        return calendar.date(from: comps)!
    }

    func testCurrentAndNextMonth() {
        let now = date(2026, 12, 15)
        let months = DateHelper.currentAndNextMonth(from: now, calendar: calendar)
        XCTAssertEqual(months.count, 2)
        XCTAssertEqual(months[0], MonthKey(year: 2026, month: 12))
        XCTAssertEqual(months[1], MonthKey(year: 2027, month: 1)) // 연도 넘김
    }

    func testWeekendDetection() {
        // 2026-07-17은 금요일, 07-18은 토요일, 07-19는 일요일.
        XCTAssertTrue(DateHelper.isReservationWeekend(date(2026, 7, 17), calendar: calendar))  // 금
        XCTAssertTrue(DateHelper.isReservationWeekend(date(2026, 7, 18), calendar: calendar))  // 토
        XCTAssertFalse(DateHelper.isReservationWeekend(date(2026, 7, 19), calendar: calendar)) // 일
        XCTAssertFalse(DateHelper.isReservationWeekend(date(2026, 7, 20), calendar: calendar)) // 월
    }

    func testWeekendDaysInMonth() {
        let days = DateHelper.weekendDays(in: MonthKey(year: 2026, month: 7), calendar: calendar)
        // 모든 결과가 금 또는 토여야 한다.
        XCTAssertFalse(days.isEmpty)
        for d in days {
            XCTAssertTrue(DateHelper.isReservationWeekend(d, calendar: calendar))
        }
    }

    func testFixedHoliday() {
        XCTAssertTrue(DateHelper.isFixedPublicHoliday(date(2026, 8, 15), calendar: calendar)) // 광복절
        XCTAssertFalse(DateHelper.isFixedPublicHoliday(date(2026, 8, 16), calendar: calendar))
    }
}
