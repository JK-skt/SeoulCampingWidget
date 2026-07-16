import Foundation

/// 난지 캠핑장의 사이트 구역(A/B/C/D).
///
/// 향후 다른 캠핑장이 다른 구역 체계를 가질 수 있으므로
/// `rawValue`는 표시용 문자열로만 취급하고, 비교/식별에는 case 자체를 사용한다.
public enum Campsite: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    public var id: String { rawValue }

    /// UI 표시용 라벨(예: "A").
    public var label: String { rawValue }
}
