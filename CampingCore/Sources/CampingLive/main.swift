import Foundation
import CampingCore

// 서울 공공서비스예약 실 API 라이브 조회 + 가용 요약.
// - 인증키:  환경변수 SEOUL_API_KEY (없으면 "sample" → 카테고리당 5행)
// - 키워드:  환경변수 SEOUL_KEYWORD (기본 "난지,캠핑" — 쉼표 구분, OR 매칭)
//
// 실측 참고: 난지 '오토캠핑장'은 공개 API에 없고 yeyak 세션 크롤이 필요하다.
// 공개 API의 실존 캠핑 데이터는 중랑캠핑숲/관악 캠핑숲 등이며, 이 도구는
// 임의 키워드로 실시간 예약 상태(접수중/마감)를 집계해 보여준다.

func run() async {
    let client = SeoulReservationClient()
    let keywords = (ProcessInfo.processInfo.environment["SEOUL_KEYWORD"] ?? "난지,캠핑")
        .split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

    print("== 서울 공공서비스예약 라이브 요약 ==")
    print("인증키: \(client.isSampleKey ? "sample(5행 제한)" : "실키")  |  키워드: \(keywords.joined(separator: ", "))")

    let services = (try? await client.search(keywords: keywords, matchAny: true)) ?? []
    print("\n매칭 서비스: \(services.count)건")

    // 상태 분포
    let byStatus = Dictionary(grouping: services, by: { $0.status }).mapValues(\.count)
    print("상태 분포: " + byStatus.sorted { $0.value > $1.value }
        .map { "\($0.key)=\($0.value)" }.joined(separator: "  "))

    // '접수중'(예약 가능) 서비스만
    let open = services.filter { $0.isOpen }
    print("\n▶ 예약 가능(접수중): \(open.count)건")
    for s in open.prefix(20) {
        let site = s.inferredSite.map { " [\($0.label)구역]" } ?? ""
        print("   • \(s.name.prefix(50))\(site)")
    }
    if open.count > 20 { print("   … 외 \(open.count - 20)건") }

    if client.isSampleKey {
        print("\n※ sample 키(5행/카테고리) — 실키:  SEOUL_API_KEY=키 swift run CampingLive")
    }
    print("\n(사이트 A~D 구역별 잔여 좌석은 공개 API 미제공 → yeyak 세션 크롤 필요)")
}

await run()
