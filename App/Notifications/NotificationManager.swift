import Foundation
import UserNotifications
import CampingCore

/// 로컬 알림 관리자. (예약 가능/오픈 알림)
public final class NotificationManager: NSObject, @unchecked Sendable {
    public static let shared = NotificationManager()

    /// 알림 권한 요청.
    public func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            Log.app.info("알림 권한: \(granted)")
        } catch {
            Log.app.error("알림 권한 요청 실패: \(String(describing: error))")
        }
    }

    /// 특정 사이트가 예약 가능해졌을 때 알림.
    public func notifyAvailability(site: Campsite, count: Int, monthLabel: String) {
        let content = UNMutableNotificationContent()
        content.title = "예약 가능 알림"
        content.body = "\(monthLabel) \(site.label)구역 \(count)자리 예약 가능!"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// 이전/현재 스냅샷을 비교해 새로 열린 자리에 대해 알림을 보낸다.
    /// 비교 로직은 코어의 `AvailabilityDiff`(테스트 완료)를 재사용한다.
    public func notifyChanges(previous: AvailabilitySnapshot?, current: AvailabilitySnapshot,
                              favorites: Favorites = Favorites()) {
        let changes = AvailabilityDiff.newlyAvailable(previous: previous, current: current)
        for change in changes where favorites.includes(change.site) {
            notifyAvailability(site: change.site, count: change.currentCount, monthLabel: change.monthLabel)
        }
    }
}
