import XCTest
@testable import CampingCore

final class ProviderAndRepositoryTests: XCTestCase {

    private let months = [MonthKey(year: 2026, month: 7), MonthKey(year: 2026, month: 8)]

    func testMockProviderIsDeterministic() async throws {
        let a = try await MockProvider(seed: 7).fetchSnapshot(months: months)
        let b = try await MockProvider(seed: 7).fetchSnapshot(months: months)
        XCTAssertEqual(a, b, "동일 seed는 동일 스냅샷을 만들어야 한다")
        XCTAssertEqual(a.months.count, 2)
        XCTAssertEqual(a.months[0].sites.count, 4)
    }

    func testHybridFallsBackToMockWhenNoLiveSource() async throws {
        // primary/secondary 모두 미구현 → fallback(Mock)로 대체되어야 한다.
        let hybrid = HybridProvider(
            primary: OpenAPIDataSource(),
            secondary: CrawlerDataSource(),
            fallback: MockProvider(seed: 1)
        )
        let snap = try await hybrid.fetchSnapshot(months: months)
        XCTAssertEqual(snap.campground, .nanji)
        XCTAssertEqual(snap.months.count, 2)
    }

    func testHybridUsesCrawlerWhenHTMLAvailable() async throws {
        // 크롤러가 HTML을 제공하면 파싱 결과가 반영된다.
        let crawler = CrawlerDataSource(htmlProvider: { _, _ in
            #"<i data-site="A" data-available="9"></i><i data-site="B" data-available="1"></i>"#
        })
        let hybrid = HybridProvider(primary: OpenAPIDataSource(), secondary: crawler, fallback: nil)
        let snap = try await hybrid.fetchSnapshot(months: [months[0]])
        XCTAssertEqual(snap.months[0].count(for: .a), 9)
        XCTAssertEqual(snap.months[0].count(for: .b), 1)
    }

    func testRepositoryCachesAndFallsBack() async throws {
        let cache = InMemoryCache()
        let repo = ReservationRepository(provider: MockProvider(seed: 3), cache: cache)
        let snap = await repo.snapshot(months: months)
        // 캐시에 저장되었는지 확인.
        let cached = try cache.load(campground: .nanji)
        XCTAssertEqual(cached, snap)
    }

    func testRepositoryPlaceholderWhenProviderFailsAndNoCache() async throws {
        struct FailingProvider: ReservationProvider {
            let campground = Campground.nanji
            func fetchSnapshot(months: [MonthKey]) async throws -> AvailabilitySnapshot {
                throw ReservationError.noData
            }
        }
        let repo = ReservationRepository(provider: FailingProvider(), cache: InMemoryCache())
        let snap = await repo.snapshot(months: months)
        // placeholder는 모든 사이트 0.
        XCTAssertTrue(snap.months.allSatisfy { $0.sites.allSatisfy { $0.availableCount == 0 } })
    }
}
