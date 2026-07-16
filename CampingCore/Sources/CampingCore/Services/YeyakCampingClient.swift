import Foundation

/// yeyak.seoul.go.kr 캠핑장 카테고리 목록을 직접 조회하는 클라이언트.
///
/// 실측 발견: 캠핑장 카테고리 목록 페이지
///   `/web/search/selectPageListDetailSearchImg.do?code=T500&dCode=T502`
/// 의 **정적 HTML**에 각 서비스의 svc_id·제목·예약상태(접수중/마감)가 포함되어 있어
/// 세션/Playwright 없이 순수 HTTP(GET)만으로 난지캠핑장 서비스 목록을 얻을 수 있다.
///
/// (사이트별 '잔여 좌석 수'는 상세/캘린더 AJAX가 필요하지만,
///  서비스 단위 예약상태는 이 목록만으로 실시간 파악 가능.)
public struct YeyakCampingClient: Sendable {
    public let baseURL: String
    public let categoryCode: String   // T500
    public let detailCode: String     // T502 (캠핑장)
    private let session: URLSession

    public init(baseURL: String = "https://yeyak.seoul.go.kr",
                categoryCode: String = "T500",
                detailCode: String = "T502",
                session: URLSession = .shared) {
        self.baseURL = baseURL
        self.categoryCode = categoryCode
        self.detailCode = detailCode
        self.session = session
    }

    /// 캠핑장 카테고리 목록 HTML을 조회한다.
    public func fetchListingHTML() async throws -> String {
        let path = "/web/search/selectPageListDetailSearchImg.do?code=\(categoryCode)&dCode=\(detailCode)"
        guard let url = URL(string: baseURL + path) else { throw ReservationError.network("잘못된 URL") }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ReservationError.network("HTTP \(http.statusCode)")
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// HTML에서 서비스 목록을 파싱한다(순수 함수 — 테스트 대상).
    /// 각 항목: `onclick="fnDetailPage('SVCID', ...)" title="제목"` + 이후 `status_?>상태<`.
    public static func parseServices(from html: String) -> [YeyakService] {
        let anchorPattern = #"fnDetailPage\('([A-Z0-9]+)'[^"]*"\s*title="([^"]+)""#
        let statusPattern = #"bd_label\s+status\d+"[^>]*>([^<]+)<"#
        guard let anchorRegex = try? NSRegularExpression(pattern: anchorPattern),
              let statusRegex = try? NSRegularExpression(pattern: statusPattern) else { return [] }

        let ns = html as NSString
        let full = NSRange(location: 0, length: ns.length)
        let anchors = anchorRegex.matches(in: html, range: full)

        var services: [YeyakService] = []
        for (i, m) in anchors.enumerated() {
            let svcId = ns.substring(with: m.range(at: 1))
            let title = ns.substring(with: m.range(at: 2))
                .replacingOccurrences(of: "&amp;", with: "&")
            // 다음 앵커 전까지 범위에서 상태 라벨을 찾는다.
            let searchStart = m.range.location + m.range.length
            let searchEnd = (i + 1 < anchors.count) ? anchors[i + 1].range.location : ns.length
            let statusRange = NSRange(location: searchStart, length: max(0, searchEnd - searchStart))
            var status = "?"
            if let sm = statusRegex.firstMatch(in: html, range: statusRange) {
                status = ns.substring(with: sm.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            services.append(YeyakService(svcId: svcId, title: title, status: status))
        }
        return services
    }

    /// 난지캠핑장 서비스만 라이브로 조회한다.
    public func fetchNanjiCamping() async throws -> [YeyakService] {
        let html = try await fetchListingHTML()
        return Self.parseServices(from: html).filter { $0.title.contains("난지캠핑장") }
    }
}

/// yeyak 캠핑장 서비스 1건.
public struct YeyakService: Hashable, Sendable {
    public let svcId: String
    public let title: String
    public let status: String

    public init(svcId: String, title: String, status: String) {
        self.svcId = svcId
        self.title = title
        self.status = status
    }

    public var isOpen: Bool { status.contains("접수중") }

    public var reservationURL: URL? {
        URL(string: "https://yeyak.seoul.go.kr/web/reservation/selectReservView.do?rsv_svc_id=\(svcId)")
    }

    /// 제목에서 캠핑존 구역을 추정한다. (예: "일반캠핑존 A형" → .a)
    public var inferredSite: Campsite? {
        for site in Campsite.allCases {
            if title.contains("\(site.rawValue)형") || title.contains("\(site.rawValue)구역") {
                return site
            }
        }
        return nil
    }

    /// 제목에 "N월"이 포함되는지로 대상 월을 판정한다.
    public func matches(month: MonthKey) -> Bool {
        title.contains("\(month.month)월")
    }
}

/// yeyak 난지캠핑장을 우리 모델로 연결하는 데이터 소스(인증키 불필요).
///
/// availableCount = 해당 월·구역에서 '접수중'인 캠핑존 서비스 수.
public struct YeyakCampingDataSource: MonthlyDataSource {
    private let client: YeyakCampingClient

    public init(client: YeyakCampingClient = YeyakCampingClient()) {
        self.client = client
    }

    public func siteCounts(campground: Campground, month: MonthKey) async throws -> [Campsite: Int] {
        let services = try await client.fetchNanjiCamping()
        if services.isEmpty { throw ReservationError.noData }
        return Self.siteCounts(from: services, month: month)
    }

    /// 순수 매핑(테스트 대상): 월·구역별 접수중 캠핑존 수.
    public static func siteCounts(from services: [YeyakService], month: MonthKey) -> [Campsite: Int] {
        var counts: [Campsite: Int] = [:]
        for s in services where s.isOpen && s.matches(month: month) {
            guard let site = s.inferredSite else { continue }
            counts[site, default: 0] += 1
        }
        return counts
    }
}
