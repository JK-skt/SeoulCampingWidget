import Foundation

/// 서울 공공서비스예약 실 API를 우리 모델(`[Campsite:Int]`)로 변환하는 데이터 소스.
///
/// 이 API는 '사이트별 잔여 좌석 수'가 아니라 서비스 단위의 예약 상태
/// (SVCSTATNM = 접수중/마감)를 제공한다. 따라서 availableCount는
/// **해당 월·구역에서 '접수중'인 예약 슬롯 수**로 해석한다(현실적으로 가능한 실지표).
/// 진짜 잔여 좌석 수는 yeyak.seoul.go.kr 상세 페이지 크롤이 필요하다(로드맵).
public struct SeoulReservationDataSource: MonthlyDataSource {
    private let client: SeoulReservationClient

    public init(client: SeoulReservationClient = SeoulReservationClient()) {
        self.client = client
    }

    public func siteCounts(campground: Campground, month: MonthKey) async throws -> [Campsite: Int] {
        let services = try await client.fetchNanjiCamping()
        if services.isEmpty { throw ReservationError.noData }
        return Self.siteCounts(from: services, month: month)
    }

    /// 순수 매핑 함수(테스트 대상): 월에 해당하는 '접수중' 서비스를 구역별로 집계.
    public static func siteCounts(from services: [ReservationService], month: MonthKey) -> [Campsite: Int] {
        var counts: [Campsite: Int] = [:]
        for svc in services where svc.isOpen && matchesMonth(svc, month) {
            guard let site = svc.inferredSite else { continue }
            counts[site, default: 0] += 1
        }
        return counts
    }

    /// 서비스가 해당 월과 관련 있는지: 접수 기간이 월과 겹치거나 이름에 연도가 포함.
    static func matchesMonth(_ svc: ReservationService, _ month: MonthKey) -> Bool {
        if let begin = parseDate(svc.receiptBegin), let end = parseDate(svc.receiptEnd) {
            let (mStart, mEnd) = monthBounds(month)
            if begin <= mEnd && end >= mStart { return true }
        }
        // 폴백: 서비스명에 "YYYY" 포함.
        return svc.name.contains(String(month.year))
    }

    /// "2026-07-01 00:00:00.0" 형태 앞부분(yyyy-MM-dd)만 파싱.
    static func parseDate(_ s: String?) -> Date? {
        guard let s, s.count >= 10 else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(s.prefix(10)))
    }

    static func monthBounds(_ month: MonthKey) -> (Date, Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        var c = DateComponents(); c.year = month.year; c.month = month.month; c.day = 1
        let start = cal.date(from: c)!
        let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        return (start, end)
    }
}
