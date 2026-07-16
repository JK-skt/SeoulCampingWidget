import WidgetKit
import CampingCore

/// 위젯 타임라인 엔트리.
struct CampingEntry: TimelineEntry {
    let date: Date
    let snapshot: AvailabilitySnapshot
}

/// 위젯 타임라인 공급자.
///
/// 공유 캐시(App Group)에서 앱이 갱신한 스냅샷을 읽는다.
/// 캐시가 없으면 저장소를 통해 즉시 조회(→ Mock 폴백)한다.
struct CampingProvider: TimelineProvider {
    func placeholder(in context: Context) -> CampingEntry {
        CampingEntry(date: Date(), snapshot: .placeholder())
    }

    func getSnapshot(in context: Context, completion: @escaping (CampingEntry) -> Void) {
        Task {
            let snapshot = await loadSnapshot()
            completion(CampingEntry(date: Date(), snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CampingEntry>) -> Void) {
        Task {
            let snapshot = await loadSnapshot()
            let entry = CampingEntry(date: Date(), snapshot: snapshot)
            // 15분 뒤 갱신(적응형 폴링은 앱 본체가 담당).
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func loadSnapshot() async -> AvailabilitySnapshot {
        if let cached = try? WidgetShared.cache.load(campground: .nanji) {
            return cached
        }
        return await WidgetShared.makeRepository().currentSnapshot()
    }
}

/// 위젯 익스텐션에서 사용하는 공유 캐시/저장소.
/// (App 타깃의 AppShared와 동일 App Group을 참조)
enum WidgetShared {
    static let appGroupID = "group.com.seoulcamping.widget"

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.temporaryDirectory
    }

    static var cache: FileAvailabilityCache {
        FileAvailabilityCache(directory: containerURL.appendingPathComponent("Caches"))
    }

    static func makeRepository() -> ReservationRepository {
        ReservationRepository(provider: HybridProvider(fallback: MockProvider()), cache: cache)
    }
}
