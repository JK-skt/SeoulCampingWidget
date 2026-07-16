import SwiftUI
import CampingCore

/// 앱 진입점. 메뉴바 앱(MenuBarExtra) + 설정/캘린더 윈도우.
///
/// Info.plist의 `LSUIElement = YES`로 Dock 아이콘 없이 메뉴바에만 상주한다.
@main
struct SeoulCampingWidgetApp: App {
    @StateObject private var viewModel = ReservationViewModel()

    var body: some Scene {
        // 메뉴바 상주 UI.
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Text(viewModel.menuBarTitle)
        }
        .menuBarExtraStyle(.window)

        // 캘린더/상세 윈도우.
        WindowGroup("서울 캠핑 위젯", id: "main") {
            ContentView(viewModel: viewModel)
                .task {
                    await NotificationManager.shared.requestAuthorization()
                    viewModel.startAutoRefresh()   // 적응형 폴링 시작
                }
        }

        // 설정 윈도우.
        Settings {
            SettingsView()
        }
    }
}
