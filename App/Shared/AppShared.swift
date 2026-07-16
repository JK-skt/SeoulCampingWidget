import Foundation
import CampingCore

/// 앱과 위젯 익스텐션이 공유하는 설정/캐시 경로.
///
/// App Group을 통해 동일 컨테이너를 공유해야 위젯이 앱이 갱신한
/// 스냅샷을 읽을 수 있다. (Xcode에서 Signing & Capabilities > App Groups 설정 필요)
public enum AppShared {
    /// App Group 식별자. Xcode 프로젝트/entitlements와 반드시 일치시켜야 한다.
    public static let appGroupID = "group.com.seoulcamping.widget"

    /// 공유 컨테이너 디렉터리. App Group 미설정 시 임시 디렉터리로 폴백한다.
    public static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.temporaryDirectory
    }

    /// 공유 파일 캐시.
    public static var cache: FileAvailabilityCache {
        FileAvailabilityCache(directory: containerURL.appendingPathComponent("Caches"))
    }

    /// 기본 저장소. 실제 데이터 소스가 확정되기 전까지 Hybrid(→Mock 폴백)를 사용한다.
    public static func makeRepository(campground: Campground = .nanji) -> ReservationRepository {
        ReservationRepository(
            provider: HybridProvider(campground: campground, fallback: MockProvider()),
            cache: cache
        )
    }
}
