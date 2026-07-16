import Foundation
import CampingCore

// 서울 공공서비스예약 실 API 라이브 호출.
// - 인증키: 환경변수 SEOUL_API_KEY (없으면 "sample" → 카테고리당 5행 제한)
// - 실제 발급 키(무료, data.seoul.go.kr)를 넣으면 전체를 조회해 난지 캠핑을 필터한다.

func run() async {
    let client = SeoulReservationClient()
    print("== 서울 공공서비스예약 라이브 호출 ==")
    print("인증키: \(client.isSampleKey ? "sample(5행 제한)" : "실키")")

    // 1) 실 스키마 라이브 디코딩 검증 (Sport 5행)
    do {
        let (total, rows) = try await client.fetchPage(.sport, start: 1, end: 5)
        print("\n[Sport] 전체 \(total)건 중 \(rows.count)행 디코딩:")
        for r in rows.prefix(5) {
            print("  • \(r.name)")
            print("     상태=\(r.status) 장소=\(r.place ?? "-") 지역=\(r.area ?? "-") 접수=\(r.receiptBegin ?? "-")~\(r.receiptEnd ?? "-")")
        }
    } catch {
        print("  ❌ Sport 조회 실패: \(error)")
    }

    // 2) 난지/캠핑 필터 (sample 키면 15행만 스캔되어 못 찾을 수 있음)
    let camping = (try? await client.fetchNanjiCamping()) ?? []
    print("\n[난지/캠핑 매칭] \(camping.count)건")
    for c in camping.prefix(20) {
        print("  • \(c.name) | \(c.status) | 구역=\(c.inferredSite?.label ?? "?")")
    }

    // 3) 이번 달 구역별 '접수중' 집계
    let months = DateHelper.currentAndNextMonth(from: Date())
    if let m = months.first {
        let counts = SeoulReservationDataSource.siteCounts(from: camping, month: m)
        print("\n[\(m.iso)] 구역별 접수중 슬롯: " +
              Campsite.allCases.map { "\($0.label)=\(counts[$0] ?? 0)" }.joined(separator: " "))
    }

    if client.isSampleKey {
        print("\n※ sample 키라 5행/카테고리 제한 → 난지 캠핑 전체 조회 불가.")
        print("  실제 키 발급 후:  SEOUL_API_KEY=발급키 swift run CampingLive")
    }
}

await run()
