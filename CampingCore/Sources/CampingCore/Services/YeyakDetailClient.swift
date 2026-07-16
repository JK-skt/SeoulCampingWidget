import Foundation

/// yeyak 서비스 상세의 **일자별 잔여 좌석**을 조회하는 클라이언트(설계 + 시도).
///
/// 실측: 상세 페이지는 잔여 수치를 정적 HTML에 담지 않고
/// `selectListReservCalAjax.do`(캘린더 AJAX)로 로드한다. 이 AJAX는 세션 쿠키만으로는
/// 부족해(직접 호출 시 302) JS가 구성하는 파라미터/토큰이 필요하다.
/// 따라서 완전한 일자별 잔여는 브라우저 세션(Playwright, `crawler/crawl.mjs`)이 필요하다.
///
/// 이 클라이언트는 세션 확립 → AJAX 호출을 순수 URLSession으로 시도하고,
/// 데이터가 오면 파싱, 302/빈 응답이면 `.notImplemented`로 명확히 실패한다.
public struct YeyakDetailClient: Sendable {
    public let baseURL: String
    private let session: URLSession

    public init(baseURL: String = "https://yeyak.seoul.go.kr", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// 일자별 잔여 항목.
    public struct DayRemaining: Hashable, Sendable {
        public let date: String   // yyyy-MM-dd
        public let remaining: Int
    }

    /// 상세 페이지로 세션을 확립한 뒤 캘린더 AJAX를 호출한다.
    public func availabilityCalendar(svcId: String) async throws -> [DayRemaining] {
        // 1) 상세 페이지 GET → 세션 쿠키(URLSession이 자동 저장)
        if let detailURL = URL(string: "\(baseURL)/web/reservation/selectReservView.do?rsv_svc_id=\(svcId)") {
            _ = try? await session.data(from: detailURL)
        }
        // 2) 캘린더 AJAX POST
        guard let ajaxURL = URL(string: "\(baseURL)/web/reservation/selectListReservCalAjax.do") else {
            throw ReservationError.network("잘못된 URL")
        }
        var request = URLRequest(url: ajaxURL)
        request.httpMethod = "POST"
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("rsv_svc_id=\(svcId)".utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ReservationError.network("응답 없음")
        }
        // 302(로그인/세션) 또는 비-JSON이면 Playwright 경로 필요.
        guard http.statusCode == 200, !data.isEmpty else {
            throw ReservationError.notImplemented(
                "캘린더 AJAX 세션 필요(HTTP \(http.statusCode)) — Playwright(crawl.mjs) 경로 사용")
        }
        return Self.parseCalendar(data)
    }

    /// 캘린더 JSON → 일자별 잔여 파싱(응답 스펙 확정 시 매핑 보완).
    static func parseCalendar(_ data: Data) -> [DayRemaining] {
        // TODO: 실제 JSON 필드 확정 후 매핑. (예: [{ rcptDe, posbCnt }])
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = obj["row"] as? [[String: Any]] else { return [] }
        return rows.compactMap { r in
            guard let date = r["rcptDe"] as? String,
                  let cnt = r["posbCnt"] as? Int else { return nil }
            return DayRemaining(date: date, remaining: cnt)
        }
    }
}
