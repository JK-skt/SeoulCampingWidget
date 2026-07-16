import Foundation

/// 하이브리드 공급자: OpenAPI 우선 → 실패 시 크롤러 폴백.
///
/// 두 데이터 소스를 순서대로 시도하고, 둘 다 실패하면 `fallback`
/// 공급자(기본 Mock)로 최종 폴백한다. 이렇게 하면 실제 소스가
/// 준비되기 전에도 앱이 항상 유효한 스냅샷을 얻는다.
public struct HybridProvider: ReservationProvider {
    public let campground: Campground
    private let primary: MonthlyDataSource
    private let secondary: MonthlyDataSource
    private let fallback: (any ReservationProvider)?

    public init(campground: Campground = .nanji,
                primary: MonthlyDataSource = OpenAPIDataSource(),
                secondary: MonthlyDataSource = CrawlerDataSource(),
                fallback: (any ReservationProvider)? = MockProvider()) {
        self.campground = campground
        self.primary = primary
        self.secondary = secondary
        self.fallback = fallback
    }

    public func fetchSnapshot(months: [MonthKey]) async throws -> AvailabilitySnapshot {
        var monthly: [MonthlyAvailability] = []
        let labels = ["이번달", "다음달", "다다음달"]
        var anyLiveData = false

        for (index, month) in months.enumerated() {
            let counts = await resolveCounts(month: month)
            if counts != nil { anyLiveData = true }
            let resolved = counts ?? [:]
            let sites = campground.sites.map {
                SiteAvailability(site: $0, availableCount: resolved[$0] ?? 0)
            }
            let label = index < labels.count ? labels[index] : month.iso
            monthly.append(MonthlyAvailability(month: month, label: label, sites: sites))
        }

        // 라이브 데이터가 하나도 없으면 fallback 공급자로 전체 대체.
        if !anyLiveData, let fallback {
            Log.network.info("HybridProvider: 라이브 데이터 없음 → fallback 사용")
            return try await fallback.fetchSnapshot(months: months)
        }

        return AvailabilitySnapshot(campground: campground,
                                    generatedAt: Date(),
                                    months: monthly)
    }

    /// primary → secondary 순으로 시도. 둘 다 실패하면 nil.
    private func resolveCounts(month: MonthKey) async -> [Campsite: Int]? {
        do {
            return try await primary.siteCounts(campground: campground, month: month)
        } catch {
            Log.network.debug("primary 실패(\(String(describing: error))) → secondary 시도")
        }
        do {
            return try await secondary.siteCounts(campground: campground, month: month)
        } catch {
            Log.network.debug("secondary 실패(\(String(describing: error)))")
            return nil
        }
    }
}
