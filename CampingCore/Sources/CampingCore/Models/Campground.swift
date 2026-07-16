import Foundation

/// 서울시 공공 예약 캠핑장 식별자.
///
/// 다중 캠핑장 Provider 확장을 위해 열거형으로 정의한다.
/// (프롬프트 요구사항: 난지/노을/중랑/강동/초안산)
public enum Campground: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case nanji      // 난지
    case noeul      // 노을
    case jungnang   // 중랑
    case gangdong   // 강동
    case choansan   // 초안산

    public var id: String { rawValue }

    /// 한글 표시명.
    public var displayName: String {
        switch self {
        case .nanji: return "난지 캠핑장"
        case .noeul: return "노을 캠핑장"
        case .jungnang: return "중랑 캠핑장"
        case .gangdong: return "강동 캠핑장"
        case .choansan: return "초안산 캠핑장"
        }
    }

    /// 해당 캠핑장이 제공하는 사이트 구역 목록.
    /// 지금은 A~D 공통이지만, 캠핑장별로 달라질 수 있어 분기해 둔다.
    public var sites: [Campsite] {
        switch self {
        case .nanji: return Campsite.allCases
        default: return Campsite.allCases
        }
    }
}
