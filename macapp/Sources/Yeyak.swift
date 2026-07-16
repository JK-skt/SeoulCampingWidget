import Foundation

/// 난지캠핑장 예약 서비스 1건 (yeyak.seoul.go.kr).
struct CampService: Identifiable, Hashable, Codable {
    let id: String        // svc_id
    let title: String
    let status: String    // 접수중 / 예약마감 / ...
    var isOpen: Bool { status.contains("접수중") }

    var zone: String? {
        for z in ["A", "B", "C", "D"] where title.contains("일반캠핑존 \(z)형") || title.contains("\(z)구역") {
            return z
        }
        return nil
    }

    var zoneLabel: String {
        if let z = zone { return "일반 \(z)형" }
        if title.contains("프리캠핑") { return "프리" }
        if title.contains("바비큐") { return "바비큐" }
        if title.contains("캠프파이어") { return "캠프파이어" }
        return "기타"
    }

    var reservationURL: URL {
        URL(string: "https://yeyak.seoul.go.kr/web/reservation/selectReservView.do?rsv_svc_id=\(id)")!
    }
}

/// 날짜별 잔여(사이트별).
struct DayAvail: Codable, Hashable, Sendable {
    let ymd: String       // yyyyMMdd
    let remain: Int       // 예약가능수(총모집수-신청수)
    let cap: Int          // 총모집수
    var reg: Int { max(0, cap - remain) }
    var year: Int { Int(ymd.prefix(4)) ?? 0 }
    var month: Int { Int(ymd.dropFirst(4).prefix(2)) ?? 0 }
    var day: Int { Int(ymd.suffix(2)) ?? 0 }
}

/// 조회 결과 상태.
enum FetchResult {
    case ok([CampService])
    case blocked          // anti-bot 차단 페이지 감지
    case failed
}

/// 유연 정수 디코딩(JSON에서 숫자/문자열 혼용 대응).
struct FlexInt: Decodable {
    let value: Int
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if let i = try? c.decode(Int.self) { value = i }
        else if let s = try? c.decode(String.self), let i = Int(s) { value = i }
        else { value = 0 }
    }
}

/// 사이트별 날짜 잔여를 담는 달력 서비스.
struct CalendarService: Codable, Hashable {
    let title: String
    let days: [DayAvail]
    var id: String = ""       // svc_id (예약 페이지 링크용)
    /// 제목 → 사이트 라벨.
    var site: String {
        for z in ["A", "B", "C", "D"] where title.contains("일반캠핑존 \(z)형") { return z }
        if title.contains("프리캠핑") { return "프리" }
        if title.contains("바비큐") { return "바비큐" }
        if title.contains("캠프파이어") { return "캠파" }
        return "기타"
    }
    var month: Int? { days.first.map(\.month) }
    var reservationURL: URL? {
        id.isEmpty ? URL(string: "https://yeyak.seoul.go.kr")
                   : URL(string: "https://yeyak.seoul.go.kr/web/reservation/selectReservView.do?rsv_svc_id=\(id)")
    }
}

struct CalendarData: Codable {
    var generatedAt: String = ""
    var services: [CalendarService] = []
}

/// 달력 데이터 소스: 라이브 실패/차단 시 번들 샘플로 폴백.
enum CalendarStore {
    /// (year,month) → day → site → remain
    static func grid(_ data: CalendarData) -> [String: [Int: [String: Int]]] {
        var g: [String: [Int: [String: Int]]] = [:]
        for svc in data.services {
            for d in svc.days {
                let key = "\(d.year)-\(d.month)"
                g[key, default: [:]][d.day, default: [:]][svc.site] = d.remain
            }
        }
        return g
    }

    /// 앱 번들의 sample_calendar.json 로드(라이브 미가용 시 표시용).
    static func loadBundled() -> CalendarData {
        guard let url = Bundle.main.url(forResource: "sample_calendar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(CalendarData.self, from: data) else {
            return CalendarData()
        }
        return decoded
    }
}

/// yeyak 캠핑장 목록에서 난지캠핑장을 조회한다.
///
/// **예의 있는 접근**(비상업 개인 모니터링용)으로 anti-bot 차단을 유발하지 않도록:
///  - 현실적인 브라우저 헤더(UA/Accept/Accept-Language/Referer)
///  - 최초 1회 메인 페이지 방문으로 세션 쿠키 확보(정상 사용자 흐름 모방)
///  - 요청 간 최소 간격 강제(과도한 반복 방지)
///  - 결과 디스크 캐시(재시작 시 재요청 최소화)
///  - 차단 감지 시 백오프(기존 캐시 유지)
actor YeyakClient {
    static let shared = YeyakClient()

    private let base = "https://yeyak.seoul.go.kr"
    private var listURL: URL { URL(string: "\(base)/web/search/selectPageListDetailSearchImg.do?code=T500&dCode=T502")! }
    private let session: URLSession
    private var warmedUp = false
    private var lastRequest = Date.distantPast
    private let minInterval: TimeInterval = 60        // 요청 간 최소 60초
    private var backoffUntil = Date.distantPast

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = .shared
        cfg.httpAdditionalHeaders = [
            "Accept-Language": "ko-KR,ko;q=0.9",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        ]
        cfg.timeoutIntervalForRequest = 15
        session = URLSession(configuration: cfg)
    }

    private func browserRequest(_ url: URL, referer: String? = nil) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15",
                   forHTTPHeaderField: "User-Agent")
        r.setValue("ko-KR,ko;q=0.9", forHTTPHeaderField: "Accept-Language")
        r.setValue("keep-alive", forHTTPHeaderField: "Connection")
        if let referer { r.setValue(referer, forHTTPHeaderField: "Referer") }
        return r
    }

    /// 난지캠핑장 목록 조회(예의 있는 접근). 차단/실패 시 캐시로 폴백.
    func fetch() async -> FetchResult {
        // 백오프 중이면 캐시 반환
        if Date() < backoffUntil, let cached = Self.loadCache() { return .ok(cached) }
        // 최소 간격 준수
        let since = Date().timeIntervalSince(lastRequest)
        if since < minInterval {
            try? await Task.sleep(nanoseconds: UInt64((minInterval - since) * 1_000_000_000))
        }
        lastRequest = Date()

        // 세션 워밍업(최초 1회 메인 방문)
        if !warmedUp {
            _ = try? await session.data(for: browserRequest(URL(string: "\(base)/web/main.do")!))
            warmedUp = true
        }

        guard let (data, _) = try? await session.data(for: browserRequest(listURL, referer: "\(base)/web/main.do")) else {
            if let cached = Self.loadCache() { return .ok(cached) }
            return .failed
        }
        let html = String(decoding: data, as: UTF8.self)

        // 차단 페이지 감지 → 백오프(10분) + 캐시 폴백
        if html.contains("비정상 접근") || html.contains("접근이 차단") {
            backoffUntil = Date().addingTimeInterval(600)
            warmedUp = false   // 다음엔 세션 새로 확립
            if let cached = Self.loadCache() { return .ok(cached) }
            return .blocked
        }

        let list = Self.parse(html)
        if list.isEmpty {
            if let cached = Self.loadCache() { return .ok(cached) }
            return .failed
        }
        Self.saveCache(list)
        return .ok(list)
    }

    // MARK: HTML 파싱
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

    // MARK: 디스크 캐시
    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SeoulCamping", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("nanji.json")
    }
    static func saveCache(_ s: [CampService]) {
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: cacheURL) }
    }
    static func loadCache() -> [CampService]? {
        guard let d = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode([CampService].self, from: d)
    }
}
