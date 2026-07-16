import Foundation

/// 사이트 1개의 월간 예약 가능 요약.
public struct SiteAvailability: Codable, Hashable, Identifiable, Sendable {
    public let site: Campsite
    /// 해당 월의 금·토 중 예약 가능한 자리 수(합계).
    public let availableCount: Int

    public var id: String { site.id }

    public init(site: Campsite, availableCount: Int) {
        self.site = site
        self.availableCount = max(0, availableCount)
    }
}

/// 한 달치 요약(이번 달 / 다음 달 각각 하나씩).
public struct MonthlyAvailability: Codable, Hashable, Identifiable, Sendable {
    public let month: MonthKey
    /// "이번달" / "다음달" 등 표시 라벨.
    public let label: String
    public let sites: [SiteAvailability]

    public var id: String { month.iso }

    public init(month: MonthKey, label: String, sites: [SiteAvailability]) {
        self.month = month
        self.label = label
        self.sites = sites
    }

    /// 특정 사이트의 가용 수를 조회한다. 없으면 0.
    public func count(for site: Campsite) -> Int {
        sites.first(where: { $0.site == site })?.availableCount ?? 0
    }
}

/// 위젯/메뉴바가 렌더링하는 최상위 스냅샷.
public struct AvailabilitySnapshot: Codable, Hashable, Sendable {
    public let campground: Campground
    public let generatedAt: Date
    public let months: [MonthlyAvailability]

    public init(campground: Campground, generatedAt: Date, months: [MonthlyAvailability]) {
        self.campground = campground
        self.generatedAt = generatedAt
        self.months = months
    }

    /// 데이터가 비어 있을 때 표시할 플레이스홀더 스냅샷.
    public static func placeholder(campground: Campground = .nanji,
                                   now: Date = Date(),
                                   calendar: Calendar = .current) -> AvailabilitySnapshot {
        let comps = calendar.dateComponents([.year, .month], from: now)
        let current = MonthKey(year: comps.year ?? 2026, month: comps.month ?? 1)
        let next = current.next
        func sites() -> [SiteAvailability] {
            campground.sites.map { SiteAvailability(site: $0, availableCount: 0) }
        }
        return AvailabilitySnapshot(
            campground: campground,
            generatedAt: now,
            months: [
                MonthlyAvailability(month: current, label: "이번달", sites: sites()),
                MonthlyAvailability(month: next, label: "다음달", sites: sites())
            ]
        )
    }
}
