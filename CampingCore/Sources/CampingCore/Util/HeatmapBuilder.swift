import Foundation

/// 캘린더 히트맵/타임라인용 일자별 데이터. (프롬프트: 캘린더/히트맵/스파크라인)
public struct DayCell: Identifiable, Hashable, Sendable {
    public let date: Date
    public let isWeekend: Bool
    public let isHoliday: Bool
    /// 0.0~1.0 정규화 강도(히트맵 색상용).
    public let intensity: Double

    public var id: Date { date }
}

/// 월간 스냅샷 + 날짜 유틸을 결합해 히트맵 셀을 만든다.
///
/// 현재 데이터는 월 단위 집계뿐이므로, 해당 월의 금·토에 균등 분배한
/// 근사 강도를 사용한다. 일자별 실데이터가 들어오면 이 매핑만 교체한다.
public enum HeatmapBuilder {
    public static func weekendCells(month: MonthlyAvailability,
                                    calendar: Calendar = .current) -> [DayCell] {
        let days = DateHelper.weekendDays(in: month.month, calendar: calendar)
        let total = month.sites.reduce(0) { $0 + $1.availableCount }
        let maxPerDay = max(1, total) // 0 나눗셈 방지
        return days.map { day in
            // 근사: 전체 가용을 주말 수로 나눈 값 → 0~1 정규화.
            let approx = days.isEmpty ? 0 : Double(total) / Double(days.count)
            let intensity = min(1.0, approx / Double(maxPerDay))
            return DayCell(date: day,
                           isWeekend: true,
                           isHoliday: DateHelper.isFixedPublicHoliday(day, calendar: calendar),
                           intensity: intensity)
        }
    }
}
