import Foundation

/// 월 단위 원시 데이터 조회 추상화.
///
/// 하이브리드(API 우선 → 크롤러 폴백) 아키텍처의 각 경로를 이 프로토콜로 표준화한다.
public protocol MonthlyDataSource: Sendable {
    func siteCounts(campground: Campground, month: MonthKey) async throws -> [Campsite: Int]
}

/// 서울 열린데이터 OpenAPI 클라이언트(스텁).
///
/// 실제 엔드포인트/서비스키가 확정되면 `endpoint`, `decode`를 채운다.
/// 현재는 미구현 오류를 던져 상위 계층이 크롤러로 폴백하도록 유도한다.
public struct OpenAPIDataSource: MonthlyDataSource {
    public let baseURL: URL
    public let serviceKey: String?
    private let session: URLSession

    public init(baseURL: URL = URL(string: "https://openapi.seoul.go.kr")!,
                serviceKey: String? = nil,
                session: URLSession = .shared) {
        self.baseURL = baseURL
        self.serviceKey = serviceKey
        self.session = session
    }

    public func siteCounts(campground: Campground, month: MonthKey) async throws -> [Campsite: Int] {
        // TODO: 실제 서울 OpenAPI 스펙 확정 시 요청/응답 매핑 구현.
        //   1) URL 구성: baseURL + serviceKey + 캠핑장/월 파라미터
        //   2) URLSession으로 조회
        //   3) 응답(JSON/XML) → [Campsite: Int] 디코딩
        Log.network.debug("OpenAPIDataSource: 미구현 — 크롤러 폴백 필요")
        throw ReservationError.notImplemented("서울 OpenAPI 스펙 미확정")
    }
}

/// Playwright 크롤러 브리지(스텁).
///
/// macOS 앱에서 Node 기반 Playwright를 서브프로세스로 구동하거나,
/// 사전 수집된 HTML을 파일로 받아 파싱하는 두 가지 방식을 지원하도록 설계한다.
/// 현재는 주입된 `htmlProvider`가 있으면 파서로 파싱하고, 없으면 미구현 처리한다.
public struct CrawlerDataSource: MonthlyDataSource {
    public typealias HTMLProvider = @Sendable (Campground, MonthKey) async throws -> String

    private let parser: ReservationParsing
    private let htmlProvider: HTMLProvider?

    public init(parser: ReservationParsing = ReservationParser(),
                htmlProvider: HTMLProvider? = nil) {
        self.parser = parser
        self.htmlProvider = htmlProvider
    }

    public func siteCounts(campground: Campground, month: MonthKey) async throws -> [Campsite: Int] {
        guard let htmlProvider else {
            throw ReservationError.notImplemented("Playwright 크롤러 브리지 미연결")
        }
        let html = try await htmlProvider(campground, month)
        return try parser.parseSiteCounts(from: html)
    }
}
