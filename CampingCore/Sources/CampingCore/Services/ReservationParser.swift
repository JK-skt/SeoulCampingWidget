import Foundation

/// HTML/문자열에서 사이트별 예약 가능 수를 추출하는 파서.
///
/// 실제 예약 사이트의 DOM 구조를 알 수 없으므로, 이 파서는
/// **문서화된 계약(contract)** 을 기준으로 동작한다:
///
///   `data-site="A" data-available="3"` 형태의 속성을 가진 요소를 찾는다.
///
/// 외부 라이브러리(SwiftSoup 등) 없이 순수 정규식으로 구현해 테스트 가능하며,
/// 추후 CSS 셀렉터/XPath 기반 구현으로 교체할 수 있도록 프로토콜로 분리한다.
public protocol ReservationParsing: Sendable {
    /// HTML 문자열에서 사이트→가용수 매핑을 추출한다.
    func parseSiteCounts(from html: String) throws -> [Campsite: Int]
}

public struct ReservationParser: ReservationParsing {
    public init() {}

    public func parseSiteCounts(from html: String) throws -> [Campsite: Int] {
        // 예: <div data-site="A" data-available="3">...</div>
        // 순서에 상관없이 두 속성이 같은 태그 안에 있으면 매칭한다.
        let pattern = #"data-site=\"([A-D])\"[^>]*?data-available=\"(\d+)\""#
        let altPattern = #"data-available=\"(\d+)\"[^>]*?data-site=\"([A-D])\""#

        var result: [Campsite: Int] = [:]

        func apply(_ regexPattern: String, siteGroup: Int, countGroup: Int) throws {
            let regex = try NSRegularExpression(pattern: regexPattern, options: [])
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                guard let match,
                      let sr = Range(match.range(at: siteGroup), in: html),
                      let cr = Range(match.range(at: countGroup), in: html),
                      let site = Campsite(rawValue: String(html[sr])),
                      let count = Int(html[cr]) else { return }
                // 이미 채워진 값은 덮어쓰지 않는다(첫 매칭 우선).
                if result[site] == nil { result[site] = count }
            }
        }

        try apply(pattern, siteGroup: 1, countGroup: 2)
        try apply(altPattern, siteGroup: 2, countGroup: 1)

        if result.isEmpty {
            throw ReservationError.parsing("사이트 가용수를 찾지 못했습니다.")
        }
        return result
    }
}
