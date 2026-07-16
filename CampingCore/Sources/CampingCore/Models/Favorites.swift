import Foundation

/// 사용자의 즐겨찾기(관심) 설정. (프롬프트 요구사항: 즐겨찾기 사이트/날짜)
public struct Favorites: Codable, Equatable, Sendable {
    /// 관심 사이트. 비어 있으면 '전체'로 간주.
    public var sites: Set<Campsite>
    /// 주말(금·토)만 관심.
    public var weekendOnly: Bool

    public init(sites: Set<Campsite> = [], weekendOnly: Bool = true) {
        self.sites = sites
        self.weekendOnly = weekendOnly
    }

    /// 해당 사이트가 관심 대상인지. (sites가 비면 모두 대상)
    public func includes(_ site: Campsite) -> Bool {
        sites.isEmpty || sites.contains(site)
    }
}

public extension AvailabilitySnapshot {
    /// 즐겨찾기 사이트만 남긴 스냅샷.
    func filtered(by favorites: Favorites) -> AvailabilitySnapshot {
        let months = self.months.map { month in
            MonthlyAvailability(
                month: month.month,
                label: month.label,
                sites: month.sites.filter { favorites.includes($0.site) }
            )
        }
        return AvailabilitySnapshot(campground: campground, generatedAt: generatedAt, months: months)
    }
}
