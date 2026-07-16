import Foundation
import CampingCore
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

/// 메뉴바/윈도우 UI를 위한 뷰모델. (MVVM)
@MainActor
public final class ReservationViewModel: ObservableObject {
    @Published public private(set) var snapshot: AvailabilitySnapshot
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: String?
    @Published public var favorites = Favorites()

    private let repository: ReservationRepository
    private let notifier = NotificationManager.shared
    private var previousSnapshot: AvailabilitySnapshot?
    private var autoRefreshTask: Task<Void, Never>?

    public init(repository: ReservationRepository = AppShared.makeRepository()) {
        self.repository = repository
        self.snapshot = .placeholder(campground: repository.campground)
    }

    /// 수동/자동 새로고침.
    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let fresh = await repository.currentSnapshot()
        // 변화 감지 → 알림(코어 AvailabilityDiff 재사용).
        notifier.notifyChanges(previous: previousSnapshot, current: fresh, favorites: favorites)
        previousSnapshot = fresh
        snapshot = fresh
        lastError = nil
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        Log.app.info("스냅샷 갱신 완료: \(fresh.months.count)개월")
    }

    /// 적응형 폴링 기반 자동 새로고침 시작.
    /// (예약 오픈 시각을 알면 오픈 임박 시 주기가 자동으로 짧아진다.)
    public func startAutoRefresh(openingDate: Date? = nil) {
        autoRefreshTask?.cancel()
        let poller = AdaptivePoller(openingDate: openingDate)
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let interval = poller.interval(at: Date())
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    /// 즐겨찾기가 적용된 표시용 스냅샷.
    public var displayedSnapshot: AvailabilitySnapshot {
        favorites.sites.isEmpty ? snapshot : snapshot.filtered(by: favorites)
    }

    /// CSV 문자열 내보내기.
    public func exportCSV() -> String { SnapshotExporter().csv(snapshot) }

    /// JSON 데이터 내보내기.
    public func exportJSON() -> Data? { try? SnapshotExporter().json(snapshot) }

    /// 메뉴바 타이틀용 요약 문자열. 예: "🏕 A3 B2 C1 D4"
    public var menuBarTitle: String {
        guard let current = snapshot.months.first else { return "🏕 --" }
        let parts = Campsite.allCases.map { "\($0.label)\(current.count(for: $0))" }
        return "🏕 " + parts.joined(separator: " ")
    }
}
