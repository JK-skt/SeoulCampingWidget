import Foundation

/// 서울 열린데이터광장 표준 OpenAPI 데이터 소스.
///
/// 서울시 OpenAPI는 공통적으로 다음 URL 패턴을 따른다:
///
///   http://openapi.seoul.go.kr:8088/{KEY}/{TYPE}/{SERVICE}/{START}/{END}/
///
/// 실제 캠핑장 예약 서비스명(SERVICE)과 응답 필드 매핑은 아직 확정되지 않았으므로,
/// URL 구성은 완전 구현하고, 응답 → `[Campsite:Int]` 디코딩만 주입식 클로저로 남긴다.
public struct SeoulOpenAPIDataSource: MonthlyDataSource {
    public let baseURL: String
    public let serviceKey: String?
    public let serviceName: String
    private let session: URLSession
    /// 응답 Data → 사이트별 수량 매핑(서비스 스펙 확정 시 주입).
    private let decode: (@Sendable (Data) throws -> [Campsite: Int])?

    public init(baseURL: String = "http://openapi.seoul.go.kr:8088",
                serviceKey: String? = nil,
                serviceName: String = "TODO_CAMPING_SERVICE",
                session: URLSession = .shared,
                decode: (@Sendable (Data) throws -> [Campsite: Int])? = nil) {
        self.baseURL = baseURL
        self.serviceKey = serviceKey
        self.serviceName = serviceName
        self.session = session
        self.decode = decode
    }

    /// 요청 URL을 구성한다(순수 함수 — 테스트 대상).
    /// start/end는 서울 OpenAPI의 페이지 인덱스(1-based).
    public static func buildURL(baseURL: String, key: String, type: String = "json",
                                service: String, start: Int = 1, end: Int = 100) -> URL? {
        URL(string: "\(baseURL)/\(key)/\(type)/\(service)/\(start)/\(end)/")
    }

    public func siteCounts(campground: Campground, month: MonthKey) async throws -> [Campsite: Int] {
        guard let serviceKey, let decode else {
            // 키 또는 디코더 미주입 → 상위 계층이 크롤러로 폴백.
            throw ReservationError.notImplemented("서울 OpenAPI 키/디코더 미설정")
        }
        guard let url = Self.buildURL(baseURL: baseURL, key: serviceKey, service: serviceName) else {
            throw ReservationError.network("잘못된 URL")
        }
        Log.network.debug("OpenAPI 요청: \(url.absoluteString)")
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ReservationError.network("HTTP \(http.statusCode)")
        }
        do {
            return try decode(data)
        } catch {
            throw ReservationError.parsing("OpenAPI 응답 디코딩 실패: \(error)")
        }
    }
}
