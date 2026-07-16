import Foundation

/// 적응형 폴링 주기 계산기(순수 함수).
///
/// 프롬프트 요구사항:
///  - 평상시: 15분마다
///  - 예약 오픈 10분 전: 1분마다
///  - 오픈 진행 중(오픈 시각 ~ +N분): 10초마다
public struct AdaptivePoller: Sendable {
    /// 예약 오픈 시각.
    public var openingDate: Date?
    /// 오픈 '진행 중'으로 간주하는 지속 시간(초). 기본 5분.
    public var openWindow: TimeInterval

    public init(openingDate: Date? = nil, openWindow: TimeInterval = 300) {
        self.openingDate = openingDate
        self.openWindow = openWindow
    }

    public enum Phase: Equatable, Sendable {
        case idle       // 평상시
        case preOpen    // 오픈 10분 전
        case opening    // 오픈 진행 중
    }

    /// 현재 시각 기준 폴링 단계.
    public func phase(at now: Date) -> Phase {
        guard let openingDate else { return .idle }
        let delta = openingDate.timeIntervalSince(now) // 양수면 아직 오픈 전
        if delta <= 0 && -delta <= openWindow {
            return .opening
        } else if delta > 0 && delta <= 600 { // 10분(600초) 전
            return .preOpen
        } else {
            return .idle
        }
    }

    /// 다음 폴링까지의 권장 간격(초).
    public func interval(at now: Date) -> TimeInterval {
        switch phase(at: now) {
        case .idle:    return 15 * 60
        case .preOpen: return 60
        case .opening: return 10
        }
    }
}
