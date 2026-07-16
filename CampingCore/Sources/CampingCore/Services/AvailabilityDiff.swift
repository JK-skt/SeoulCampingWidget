import Foundation

/// 두 스냅샷을 비교해 '새로 열린 자리'를 계산하는 순수 로직.
///
/// 알림 트리거의 근거가 되며, UI/알림 계층과 독립적으로 테스트한다.
public enum AvailabilityDiff {

    /// 특정 사이트가 새로 예약 가능해진 항목.
    public struct Change: Equatable, Sendable {
        public let month: MonthKey
        public let monthLabel: String
        public let site: Campsite
        public let previousCount: Int
        public let currentCount: Int
    }

    /// `current`에서 `previous` 대비 가용 수가 증가한 (월, 사이트) 목록.
    /// `previous`가 nil이면 변화 없음으로 간주(최초 로드시 대량 알림 방지).
    public static func newlyAvailable(previous: AvailabilitySnapshot?,
                                      current: AvailabilitySnapshot) -> [Change] {
        guard let previous else { return [] }
        var changes: [Change] = []
        for month in current.months {
            guard let prevMonth = previous.months.first(where: { $0.month == month.month }) else { continue }
            for site in month.sites {
                let before = prevMonth.count(for: site.site)
                if site.availableCount > before {
                    changes.append(Change(month: month.month,
                                          monthLabel: month.label,
                                          site: site.site,
                                          previousCount: before,
                                          currentCount: site.availableCount))
                }
            }
        }
        return changes
    }
}
