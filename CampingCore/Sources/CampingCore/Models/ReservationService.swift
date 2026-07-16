import Foundation

/// 서울 공공서비스예약 OpenAPI의 실제 응답 1행.
///
/// 실 스키마(ListPublicReservationSport/Culture/...)의 필드명을 그대로 매핑한다.
/// 확인된 필드: GUBUN, SVCID, SVCNM, SVCSTATNM, PLACENM, AREANM,
/// RCPTBGNDT, RCPTENDDT, SVCURL, X, Y, V_MIN, V_MAX 등.
public struct ReservationService: Codable, Hashable, Sendable {
    public let id: String            // SVCID
    public let name: String          // SVCNM
    public let status: String        // SVCSTATNM (접수중 / 접수마감 / 예약마감 / 안내 ...)
    public let place: String?        // PLACENM
    public let area: String?         // AREANM
    public let receiptBegin: String? // RCPTBGNDT
    public let receiptEnd: String?   // RCPTENDDT
    public let url: String?          // SVCURL

    public init(id: String, name: String, status: String, place: String? = nil,
                area: String? = nil, receiptBegin: String? = nil,
                receiptEnd: String? = nil, url: String? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.place = place
        self.area = area
        self.receiptBegin = receiptBegin
        self.receiptEnd = receiptEnd
        self.url = url
    }

    enum CodingKeys: String, CodingKey {
        case id = "SVCID"
        case name = "SVCNM"
        case status = "SVCSTATNM"
        case place = "PLACENM"
        case area = "AREANM"
        case receiptBegin = "RCPTBGNDT"
        case receiptEnd = "RCPTENDDT"
        case url = "SVCURL"
    }

    /// 예약 접수 가능 상태인가.
    public var isOpen: Bool {
        status.contains("접수중") || status.contains("예약중")
    }

    /// 서비스명에서 사이트 구역(A~D)을 추출한다. (예: "난지캠핑장 A구역 ...")
    public var inferredSite: Campsite? {
        for site in Campsite.allCases {
            if name.contains("\(site.rawValue)구역") || name.contains("\(site.rawValue) 구역") {
                return site
            }
        }
        return nil
    }

    /// 난지/캠핑 관련 서비스인지.
    public var isNanjiCamping: Bool {
        let hay = name + (place ?? "")
        return (hay.contains("난지") || hay.contains("캠핑"))
    }
}
