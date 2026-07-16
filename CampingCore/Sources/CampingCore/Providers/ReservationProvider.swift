import Foundation

/// 예약 가능 데이터를 가져오는 공급자 추상화.
///
/// 실제 데이터 소스(서울 OpenAPI / Playwright 크롤러)를 알 수 없는 현 시점에서는
/// 이 프로토콜 뒤에 Mock을 두고, 추후 실제 구현으로 교체할 수 있게 한다.
public protocol ReservationProvider: Sendable {
    /// 이 공급자가 담당하는 캠핑장.
    var campground: Campground { get }

    /// 주어진 월들에 대한 예약 가능 스냅샷을 조회한다.
    func fetchSnapshot(months: [MonthKey]) async throws -> AvailabilitySnapshot
}

/// 공급자/저장소 계층에서 발생하는 오류.
public enum ReservationError: Error, Equatable, Sendable {
    case network(String)
    case parsing(String)
    case notImplemented(String)
    case noData
}
