import AppIntents
import CampingCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// 예약 현황 새로고침 App Intent. (Siri / 단축어 / Spotlight)
///
/// "난지 캠핑장 새로고침" 등으로 실행되며, 저장소를 갱신하고 위젯을 리로드한다.
@available(macOS 14.0, *)
struct RefreshAvailabilityIntent: AppIntent {
    static var title: LocalizedStringResource = "예약 현황 새로고침"
    static var description = IntentDescription("난지 캠핑장 예약 가능 현황을 새로고침합니다.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let repository = AppShared.makeRepository()
        let snapshot = await repository.currentSnapshot()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        let first = snapshot.months.first
        let summary = first.map { month in
            Campsite.allCases.map { "\($0.label)\(month.count(for: $0))" }.joined(separator: " ")
        } ?? "데이터 없음"
        return .result(dialog: "현재 예약 가능: \(summary)")
    }
}

/// 앱 단축어 등록(사용자가 별도 설정 없이 Siri/Spotlight에서 사용).
@available(macOS 14.0, *)
struct CampingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshAvailabilityIntent(),
            phrases: [
                "\(.applicationName) 새로고침",
                "난지 캠핑 예약 확인 \(.applicationName)"
            ],
            shortTitle: "새로고침",
            systemImageName: "arrow.clockwise"
        )
    }
}
