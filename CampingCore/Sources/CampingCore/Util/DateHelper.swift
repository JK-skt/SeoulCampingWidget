import Foundation

/// 날짜 관련 순수 함수 모음. (주말/공휴일/월키 계산)
///
/// 모든 함수는 `Calendar`를 주입받아 테스트 가능하도록 설계했다.
public enum DateHelper {

    /// 이번 달과 다음 달의 `MonthKey`를 반환한다.
    public static func currentAndNextMonth(from now: Date, calendar: Calendar = .current) -> [MonthKey] {
        let comps = calendar.dateComponents([.year, .month], from: now)
        guard let y = comps.year, let m = comps.month else { return [] }
        let current = MonthKey(year: y, month: m)
        return [current, current.next]
    }

    /// 주말(금/토) 여부. 예약 대상은 금요일·토요일 숙박이다.
    public static func isReservationWeekend(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date) // 1=일 ... 7=토
        return weekday == 6 || weekday == 7 // 금(6), 토(7)
    }

    /// 지정한 월(MonthKey)에 속한 금요일·토요일 날짜 목록.
    public static func weekendDays(in month: MonthKey, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        var comps = DateComponents()
        comps.year = month.year
        comps.month = month.month
        comps.day = 1
        guard let first = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        for day in range {
            comps.day = day
            if let d = calendar.date(from: comps), isReservationWeekend(d, calendar: calendar) {
                result.append(d)
            }
        }
        return result
    }

    /// 대한민국 고정 공휴일(양력) 간이 판정.
    /// 음력 기반 공휴일(설/추석)은 별도 데이터가 필요하므로 여기서는 제외한다.
    /// 실제 서비스에서는 공휴일 API/데이터셋으로 대체할 수 있도록 seam을 열어 둔다.
    public static func isFixedPublicHoliday(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.month, .day], from: date)
        guard let m = c.month, let d = c.day else { return false }
        let fixed: Set<[Int]> = [
            [1, 1],   // 신정
            [3, 1],   // 삼일절
            [5, 5],   // 어린이날
            [6, 6],   // 현충일
            [8, 15],  // 광복절
            [10, 3],  // 개천절
            [10, 9],  // 한글날
            [12, 25]  // 성탄절
        ]
        return fixed.contains([m, d])
    }

    /// 금~일(또는 공휴일 연계)로 이어지는 '연휴' 여부의 간이 판정.
    /// 토요일 + (일요일이 공휴일이거나 월요일이 공휴일)일 때 연휴로 본다.
    public static func isLongWeekend(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard isReservationWeekend(date, calendar: calendar) else { return false }
        guard let plus1 = calendar.date(byAdding: .day, value: 1, to: date),
              let plus2 = calendar.date(byAdding: .day, value: 2, to: date) else { return false }
        return isFixedPublicHoliday(plus1, calendar: calendar)
            || isFixedPublicHoliday(plus2, calendar: calendar)
    }
}
