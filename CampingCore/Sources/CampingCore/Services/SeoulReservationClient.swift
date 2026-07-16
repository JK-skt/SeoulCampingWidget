import Foundation

/// 서울 공공서비스예약 OpenAPI 실 클라이언트.
///
/// 표준 URL: `http://openapi.seoul.go.kr:8088/{KEY}/json/{CATEGORY}/{START}/{END}/`
/// - 인증키가 "sample"이면 한 번에 5행까지만 조회 가능(테스트용).
/// - 실제 발급 키(무료, data.seoul.go.kr)를 넣으면 전체 페이지 조회가 가능하다.
public struct SeoulReservationClient: Sendable {
    public enum Category: String, CaseIterable, Sendable {
        case sport = "ListPublicReservationSport"
        case culture = "ListPublicReservationCulture"
        case education = "ListPublicReservationEducation"
    }

    public let apiKey: String
    public let baseURL: String
    private let session: URLSession

    public init(apiKey: String = ProcessInfo.processInfo.environment["SEOUL_API_KEY"] ?? "sample",
                baseURL: String = "http://openapi.seoul.go.kr:8088",
                session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session
    }

    /// 사용 중인 키가 sample(5행 제한)인지.
    public var isSampleKey: Bool { apiKey == "sample" }

    private struct Wrapper: Decodable {
        let list_total_count: Int?
        let row: [ReservationService]?
    }

    /// 한 페이지 조회. (start/end는 1-based, 최대 1000건/요청; sample은 1~5)
    public func fetchPage(_ category: Category, start: Int, end: Int) async throws -> (total: Int, rows: [ReservationService]) {
        guard let url = URL(string: "\(baseURL)/\(apiKey)/json/\(category.rawValue)/\(start)/\(end)/") else {
            throw ReservationError.network("잘못된 URL")
        }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ReservationError.network("HTTP \(http.statusCode)")
        }
        // 성공 응답은 { "<Category>": {list_total_count, RESULT, row} } 형태.
        do {
            let dict = try JSONDecoder().decode([String: Wrapper].self, from: data)
            guard let payload = dict[category.rawValue] else {
                throw ReservationError.parsing("응답에 \(category.rawValue) 없음(오류 응답일 수 있음)")
            }
            return (payload.list_total_count ?? 0, payload.row ?? [])
        } catch let e as ReservationError {
            throw e
        } catch {
            let body = String(decoding: data.prefix(200), as: UTF8.self)
            throw ReservationError.parsing("JSON 디코딩 실패: \(body)")
        }
    }

    /// 전체 페이지를 모아 조회한다. (sample 키면 첫 5행만)
    public func fetchAll(_ category: Category, pageSize: Int = 1000, maxRows: Int = 5000) async throws -> [ReservationService] {
        if isSampleKey {
            return try await fetchPage(category, start: 1, end: 5).rows
        }
        var all: [ReservationService] = []
        var start = 1
        let (total, first) = try await fetchPage(category, start: start, end: min(pageSize, maxRows))
        all += first
        start += pageSize
        while all.count < min(total, maxRows) {
            let end = start + pageSize - 1
            let page = try await fetchPage(category, start: start, end: end).rows
            if page.isEmpty { break }
            all += page
            start += pageSize
        }
        return all
    }

    /// 여러 카테고리에서 난지/캠핑 서비스만 모은다.
    public func fetchNanjiCamping() async throws -> [ReservationService] {
        try await search(keywords: ["난지", "캠핑"], matchAny: true)
    }

    /// 키워드(서비스명/장소)로 전 카테고리를 검색한다.
    /// - matchAny: true면 키워드 중 하나라도 포함, false면 모두 포함.
    public func search(keywords: [String], matchAny: Bool = true) async throws -> [ReservationService] {
        var result: [ReservationService] = []
        for category in Category.allCases {
            let rows = (try? await fetchAll(category)) ?? []
            result += rows.filter { svc in
                let hay = svc.name + (svc.place ?? "")
                return matchAny ? keywords.contains { hay.contains($0) }
                                : keywords.allSatisfy { hay.contains($0) }
            }
        }
        return result
    }
}
