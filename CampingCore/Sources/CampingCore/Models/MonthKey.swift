import Foundation

/// 연/월을 식별하는 값 타입. (일 단위는 다루지 않는다.)
///
/// 위젯은 "이번 달 / 다음 달"의 금·토 예약 가능 수를 보여주므로
/// 월 단위 키가 데이터 조회·캐시의 기본 단위가 된다.
public struct MonthKey: Codable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int // 1...12

    public init(year: Int, month: Int) {
        precondition((1...12).contains(month), "month는 1...12 범위여야 합니다: \(month)")
        self.year = year
        self.month = month
    }

    public static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    /// 다음 달 키. 12월이면 다음 해 1월로 넘어간다.
    public var next: MonthKey {
        month == 12 ? MonthKey(year: year + 1, month: 1)
                    : MonthKey(year: year, month: month + 1)
    }

    /// "2026-07" 형태의 문자열.
    public var iso: String { String(format: "%04d-%02d", year, month) }
}
