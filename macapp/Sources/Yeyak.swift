import Foundation

/// 난지캠핑장 예약 서비스 1건 (yeyak.seoul.go.kr).
struct CampService: Identifiable, Hashable {
    let id: String        // svc_id
    let title: String
    let status: String    // 접수중 / 예약마감 / ...
    var isOpen: Bool { status.contains("접수중") }

    /// 제목에서 캠핑존 구역(일반캠핑존 A/B/C/D형).
    var zone: String? {
        for z in ["A", "B", "C", "D"] where title.contains("일반캠핑존 \(z)형") || title.contains("\(z)구역") {
            return z
        }
        return nil
    }

    /// 존 종류 라벨(프리/일반 A~D/바비큐/캠프파이어).
    var zoneLabel: String {
        if let z = zone { return "일반 \(z)형" }
        if title.contains("프리캠핑") { return "프리" }
        if title.contains("바비큐") { return "바비큐" }
        if title.contains("캠프파이어") { return "캠프파이어" }
        return "기타"
    }

    /// 제목의 "N월".
    var month: Int? {
        guard let r = title.range(of: #"(\d+)월"#, options: .regularExpression) else { return nil }
        return Int(title[r].dropLast())
    }

    var reservationURL: URL {
        URL(string: "https://yeyak.seoul.go.kr/web/reservation/selectReservView.do?rsv_svc_id=\(id)")!
    }
}

/// yeyak 캠핑장 카테고리 목록에서 난지캠핑장을 조회한다(순수 HTTP, 인증 불필요).
enum YeyakClient {
    static let listURL = URL(string:
        "https://yeyak.seoul.go.kr/web/search/selectPageListDetailSearchImg.do?code=T500&dCode=T502")!

    static func fetchNanji() async -> [CampService] {
        var request = URLRequest(url: listURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return [] }
        return parse(String(decoding: data, as: UTF8.self))
    }

    static func parse(_ html: String) -> [CampService] {
        var out: [CampService] = []
        let ns = html as NSString
        let anchor = try! NSRegularExpression(pattern: #"<a\b[^>]*fnDetailPage\(['\"]([A-Za-z0-9]+)['\"][^>]*title=\"([^\"]*)\"[^>]*>"#)
        let status = try! NSRegularExpression(pattern: #"bd_label\s+status\d+\"[^>]*>([^<]+)<"#)
        let full = NSRange(location: 0, length: ns.length)
        let ms = anchor.matches(in: html, range: full)
        for (i, m) in ms.enumerated() {
            let id = ns.substring(with: m.range(at: 1))
            let title = ns.substring(with: m.range(at: 2))
            guard title.contains("난지캠핑장") else { continue }
            let from = m.range.location + m.range.length
            let to = (i + 1 < ms.count) ? ms[i + 1].range.location : ns.length
            var st = "?"
            if let sm = status.firstMatch(in: html, range: NSRange(location: from, length: max(0, to - from))) {
                st = ns.substring(with: sm.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            out.append(CampService(id: id, title: title, status: st))
        }
        return out
    }
}
