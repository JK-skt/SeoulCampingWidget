import Foundation

/// 공급자 + 캐시를 묶어 앱/위젯에 단일 진입점을 제공하는 저장소.
///
/// - 네트워크 조회 성공 시 캐시에 저장 후 반환.
/// - 조회 실패 시 캐시된 스냅샷으로 폴백.
/// - 캐시도 없으면 placeholder 반환(오류를 전파하지 않아 UI가 항상 렌더 가능).
public struct ReservationRepository: Sendable {
    private let provider: any ReservationProvider
    private let cache: any AvailabilityCache

    public init(provider: any ReservationProvider = MockProvider(),
                cache: any AvailabilityCache = InMemoryCache()) {
        self.provider = provider
        self.cache = cache
    }

    public var campground: Campground { provider.campground }

    /// 최신 스냅샷을 가져온다(네트워크 → 캐시 폴백 → placeholder).
    public func snapshot(months: [MonthKey], now: Date = Date()) async -> AvailabilitySnapshot {
        do {
            let fresh = try await provider.fetchSnapshot(months: months)
            try? cache.save(fresh)
            return fresh
        } catch {
            Log.network.error("스냅샷 조회 실패: \(String(describing: error))")
            if let cached = try? cache.load(campground: provider.campground) {
                return cached
            }
            return .placeholder(campground: provider.campground, now: now)
        }
    }

    /// 이번 달/다음 달 기준 편의 조회.
    public func currentSnapshot(now: Date = Date(), calendar: Calendar = .current) async -> AvailabilitySnapshot {
        let months = DateHelper.currentAndNextMonth(from: now, calendar: calendar)
        return await snapshot(months: months, now: now)
    }
}
