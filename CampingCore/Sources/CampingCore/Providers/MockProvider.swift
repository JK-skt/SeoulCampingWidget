import Foundation

/// 결정론적 목(Mock) 공급자.
///
/// 실제 데이터 소스가 확정되기 전까지 앱/위젯/테스트가 동작하도록 한다.
/// `seed`를 고정하면 항상 동일한 값을 만들어 스냅샷 테스트에 적합하다.
public struct MockProvider: ReservationProvider {
    public let campground: Campground
    private let seed: UInt64

    public init(campground: Campground = .nanji, seed: UInt64 = 42) {
        self.campground = campground
        self.seed = seed
    }

    public func fetchSnapshot(months: [MonthKey]) async throws -> AvailabilitySnapshot {
        let labels = ["이번달", "다음달", "다다음달", "+3", "+4"]
        var rng = SplitMix64(seed: seed)
        let monthly: [MonthlyAvailability] = months.enumerated().map { index, month in
            let sites = campground.sites.map { site -> SiteAvailability in
                // 0...9 범위의 결정론적 값.
                let value = Int(rng.next() % 10)
                return SiteAvailability(site: site, availableCount: value)
            }
            let label = index < labels.count ? labels[index] : month.iso
            return MonthlyAvailability(month: month, label: label, sites: sites)
        }
        return AvailabilitySnapshot(campground: campground,
                                    generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                    months: monthly)
    }
}

/// 외부 의존성 없는 결정론적 난수(SplitMix64).
/// 테스트 재현성을 위해 자체 구현한다.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
