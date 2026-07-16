import Foundation
import CampingCore

// 난지캠핑장 라이브 조회 (yeyak.seoul.go.kr, 인증키 불필요).
// - 원시 서비스 목록 + 앱 파이프라인(이번달/다음달 스냅샷)을 함께 출력.

func run() async {
    print("== 난지캠핑장 라이브 조회 (yeyak) ==")
    let client = YeyakCampingClient()

    // 1) 원시 서비스 목록
    let services = (try? await client.fetchNanjiCamping()) ?? []
    print("서비스 \(services.count)건")
    for s in services {
        let zone = s.inferredSite.map { "구역 \($0.label)" } ?? "-"
        print("  [\(s.status)] \(s.title.prefix(38))  (\(zone))")
    }

    // 2) 앱 파이프라인: 이번달/다음달 스냅샷 (구역별 접수중 매핑)
    let months = DateHelper.currentAndNextMonth(from: Date())
    print("\n▶ 앱 스냅샷 (이번달/다음달, 일반캠핑존 구역별 접수중 수)")
    // 구역이 없는 서비스가 많아 fallback(nil)일 때 빈 달이 나올 수 있으므로 직접 매핑도 병행.
    for (i, m) in months.enumerated() {
        let counts = YeyakCampingDataSource.siteCounts(from: services, month: m)
        let label = i == 0 ? "이번달" : "다음달"
        let line = Campsite.allCases.map { "\($0.label)=\(counts[$0] ?? 0)" }.joined(separator: " ")
        let openTotal = services.filter { $0.isOpen && $0.matches(month: m) }.count
        print("  \(label) \(m.iso): \(line)   (해당 월 접수중 서비스 \(openTotal)건)")
    }
    print("\n※ 7월은 이미 접수마감/미노출이라 0, 8월이 현재 오픈 상태입니다(라이브 실측).")

    // 3) (옵션) Playwright 크롤러 경유 — CRAWLER_PATH 지정 시 node crawl.mjs 실행→파싱
    #if os(macOS)
    if let crawlPath = ProcessInfo.processInfo.environment["CRAWLER_PATH"] {
        print("\n▶ Playwright 크롤러 경유 (node \(crawlPath))")
        let ds = ProcessCrawlerDataSource(
            launchPath: "/usr/bin/env",
            argumentsBuilder: { _, _ in ["node", crawlPath] })
        do {
            let counts = try await ds.siteCounts(campground: .nanji, month: months.last ?? months[0])
            let line = Campsite.allCases.map { "\($0.label)=\(counts[$0] ?? 0)" }.joined(separator: " ")
            print("  크롤러→파서 결과: \(line)  ✅ Playwright→Swift 파이프라인 동작")
        } catch {
            print("  크롤러 실패: \(error)")
        }
    }
    #endif
    print("※ 일자별 '잔여 좌석 수'는 예약폼(로그인) 필요 → crawl.mjs에 storageState(쿠키) 주입 예정.")
}

await run()
