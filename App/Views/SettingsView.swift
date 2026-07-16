import SwiftUI
import CampingCore

/// 설정 화면. 새로고침 주기·알림·캠핑장·즐겨찾기 사이트 설정.
struct SettingsView: View {
    @AppStorage("refreshIntervalMinutes") private var refreshInterval = 15
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("selectedCampground") private var selectedCampground = Campground.nanji.rawValue
    /// 즐겨찾기 사이트를 rawValue 문자열 집합으로 저장(예: "A,C").
    @AppStorage("favoriteSites") private var favoriteSitesRaw = ""

    var body: some View {
        Form {
            Section("데이터") {
                Picker("캠핑장", selection: $selectedCampground) {
                    ForEach(Campground.allCases) { cg in
                        Text(cg.displayName).tag(cg.rawValue)
                    }
                }
                Stepper("새로고침 주기: \(refreshInterval)분",
                        value: $refreshInterval, in: 5...60, step: 5)
            }
            Section("즐겨찾기 사이트") {
                ForEach(Campsite.allCases) { site in
                    Toggle("\(site.label)구역", isOn: binding(for: site))
                }
            }
            Section("알림") {
                Toggle("예약 가능 알림 받기", isOn: $notificationsEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 380)
        .padding()
    }

    /// 즐겨찾기 사이트 토글 바인딩(문자열 집합 ↔ Bool).
    private func binding(for site: Campsite) -> Binding<Bool> {
        Binding(
            get: { favoriteSet.contains(site.rawValue) },
            set: { isOn in
                var set = favoriteSet
                if isOn { set.insert(site.rawValue) } else { set.remove(site.rawValue) }
                favoriteSitesRaw = set.sorted().joined(separator: ",")
            }
        )
    }

    private var favoriteSet: Set<String> {
        Set(favoriteSitesRaw.split(separator: ",").map(String.init))
    }
}
