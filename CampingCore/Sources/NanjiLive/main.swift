import Foundation
import CampingCore

// 난지캠핑장 라이브 조회 (yeyak.seoul.go.kr, 인증키 불필요).
//
// 실측: 캠핑장 카테고리 목록(code=T500&dCode=T502)의 정적 HTML에
// svc_id·제목·예약상태(접수중/마감)가 포함되어 세션/Playwright 없이 조회된다.

func run() async {
    print("== 난지캠핑장 라이브 조회 (yeyak.seoul.go.kr) ==")
    let client = YeyakCampingClient()
    do {
        let services = try await client.fetchNanjiCamping()
        print("난지캠핑장 서비스: \(services.count)건\n")

        for s in services {
            let zone = s.inferredSite.map { "구역 \($0.label)" } ?? "-"
            print("  [\(s.status)] \(s.title)")
            print("       \(zone)  |  svc_id=\(s.svcId)")
        }

        // 구역(형)별 접수중 집계 → 앱 모델(AvailabilitySnapshot)로 매핑 데모
        var counts: [Campsite: Int] = [:]
        for s in services where s.isOpen {
            if let site = s.inferredSite { counts[site, default: 0] += 1 }
        }
        let open = services.filter(\.isOpen).count
        print("\n▶ 접수중 \(open)/\(services.count)건  |  일반캠핑존 구역별: " +
              Campsite.allCases.map { "\($0.label)형=\(counts[$0] ?? 0)" }.joined(separator: " "))
        print("\n예약: https://yeyak.seoul.go.kr/web/reservation/selectReservView.do?rsv_svc_id=<svc_id>")
    } catch {
        print("조회 실패: \(error)")
    }
}

await run()
