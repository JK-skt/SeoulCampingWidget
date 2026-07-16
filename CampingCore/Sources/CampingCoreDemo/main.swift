import Foundation
import CampingCore

// CampingCore 로직 스모크 테스트.
// 정식 Xcode(XCTest)가 없는 환경에서도 핵심 로직이 실제로 동작하는지 검증한다.
// 실패 시 프로세스를 비정상 종료(exit 1)한다.

func runSmokeTests() async -> Int {
    var failures = 0
    func check(_ condition: Bool, _ message: String) {
        if condition {
            print("  ✅ \(message)")
        } else {
            print("  ❌ \(message)")
            failures += 1
        }
    }

    print("== CampingCore 스모크 테스트 ==")

    // 1) 날짜 유틸
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return cal.date(from: c)!
    }
    let months = DateHelper.currentAndNextMonth(from: date(2026, 12, 15), calendar: cal)
    check(months == [MonthKey(year: 2026, month: 12), MonthKey(year: 2027, month: 1)],
          "이번달/다음달 계산(연도 넘김)")
    check(DateHelper.isReservationWeekend(date(2026, 7, 17), calendar: cal), "금요일=주말")
    check(!DateHelper.isReservationWeekend(date(2026, 7, 19), calendar: cal), "일요일≠예약주말")
    check(DateHelper.isFixedPublicHoliday(date(2026, 8, 15), calendar: cal), "광복절 공휴일")

    // 2) 파서
    let parser = ReservationParser()
    let html = #"<li data-site="A" data-available="3"></li><li data-site="B" data-available="2"></li>"#
    if let counts = try? parser.parseSiteCounts(from: html) {
        check(counts[.a] == 3 && counts[.b] == 2, "HTML 파싱")
    } else {
        check(false, "HTML 파싱")
    }

    // 3) 적응형 폴러
    let opening = Date(timeIntervalSince1970: 1_800_000_000)
    let poller = AdaptivePoller(openingDate: opening)
    check(poller.interval(at: opening.addingTimeInterval(-5 * 60)) == 60, "오픈 5분 전 = 1분 주기")
    check(poller.interval(at: opening.addingTimeInterval(30)) == 10, "오픈 직후 = 10초 주기")
    check(poller.interval(at: opening.addingTimeInterval(-3600)) == 15 * 60, "평상시 = 15분 주기")

    // 4) 저장소 + 하이브리드 폴백
    let repo = ReservationRepository(provider: HybridProvider(fallback: MockProvider(seed: 7)),
                                     cache: InMemoryCache())
    let snap = await repo.snapshot(months: months)
    check(snap.months.count == 2, "저장소 스냅샷 2개월")
    check(snap.months[0].sites.count == 4, "사이트 4구역(A~D)")

    // 5) 내보내기
    let exporter = SnapshotExporter()
    check(exporter.csv(snap).hasPrefix("month,label,site,available"), "CSV 헤더")
    check((try? exporter.json(snap)) != nil, "JSON 직렬화")
    check(Array(exporter.excelCompatibleCSV(snap).prefix(3)) == [0xEF, 0xBB, 0xBF], "Excel CSV BOM")

    // 6) 변화 감지
    let prev = AvailabilitySnapshot(campground: .nanji, generatedAt: Date(), months: [
        MonthlyAvailability(month: months[0], label: "이번달",
                            sites: [SiteAvailability(site: .a, availableCount: 0)])])
    let curr = AvailabilitySnapshot(campground: .nanji, generatedAt: Date(), months: [
        MonthlyAvailability(month: months[0], label: "이번달",
                            sites: [SiteAvailability(site: .a, availableCount: 2)])])
    check(AvailabilityDiff.newlyAvailable(previous: prev, current: curr).count == 1, "새 가용 자리 감지")
    check(AvailabilityDiff.newlyAvailable(previous: nil, current: curr).isEmpty, "최초 로드 무알림")

    // 7) 즐겨찾기 필터
    let filtered = snap.filtered(by: Favorites(sites: [.a, .c]))
    check(Set(filtered.months[0].sites.map(\.site)) == [.a, .c], "즐겨찾기 필터(A,C)")

    // 8) 히트맵
    let cells = HeatmapBuilder.weekendCells(month: snap.months[0], calendar: cal)
    check(!cells.isEmpty && cells.allSatisfy { $0.isWeekend }, "히트맵 주말 셀 생성")

    // 9) 실 연동 스캐폴드
    check(SeoulOpenAPIDataSource.buildURL(baseURL: "http://openapi.seoul.go.kr:8088",
            key: "K", service: "S")?.absoluteString == "http://openapi.seoul.go.kr:8088/K/json/S/1/100/",
          "Seoul OpenAPI URL 빌더")
    #if os(macOS)
    let crawler = ProcessCrawlerDataSource(launchPath: "/bin/sh", argumentsBuilder: { _, _ in
        ["-c", #"printf '<i data-site="A" data-available="8"></i>'"#]
    })
    let crawled = (try? await crawler.siteCounts(campground: .nanji, month: months[0])) ?? [:]
    check(crawled[.a] == 8, "Process 크롤러 브리지(/bin/sh)")
    #endif

    print("== 결과: \(failures == 0 ? "전체 통과 🎉" : "\(failures)건 실패") ==")
    return failures
}

let failureCount = await runSmokeTests()
exit(failureCount == 0 ? 0 : 1)
