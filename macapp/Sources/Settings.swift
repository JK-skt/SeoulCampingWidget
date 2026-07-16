import SwiftUI

// MARK: - 설정 (System Settings 스타일 그룹 리스트) — Handoff 화면 5

struct SettingsView: View {
    @ObservedObject var vm: CampViewModel
    @AppStorage("notifyNewSpot") private var notifyNewSpot = true
    @AppStorage("interestFri") private var interestFri = true
    @AppStorage("interestSat") private var interestSat = true
    @AppStorage("minRemain") private var minRemain = 1
    @AppStorage("menuBarStyle") private var menuBarStyle = "count"   // count / iconOnly
    @AppStorage("theme") private var theme = "system"

    var body: some View {
        Form {
            Section("갱신") {
                Toggle("자동 갱신", isOn: Binding(
                    get: { vm.refreshInterval > 0 },
                    set: { vm.refreshInterval = $0 ? 900 : 0 }))
                Picker("갱신 주기", selection: $vm.refreshInterval) {
                    Text("30초").tag(30.0); Text("1분").tag(60.0)
                    Text("5분").tag(300.0); Text("15분").tag(900.0)
                }.disabled(vm.refreshInterval == 0)
            }
            Section("관심 조건") {
                HStack {
                    Text("관심 요일")
                    Spacer()
                    Toggle("금", isOn: $interestFri).toggleStyle(.button).controlSize(.small)
                    Toggle("토", isOn: $interestSat).toggleStyle(.button).controlSize(.small)
                }
                Stepper("최소 잔여 수량: \(minRemain)자리 이상", value: $minRemain, in: 1...20)
            }
            Section("알림 · 표시") {
                Toggle("새 빈자리 알림", isOn: $notifyNewSpot)
                Picker("메뉴바 표시", selection: $menuBarStyle) {
                    Text("가능한 날짜 수").tag("count")
                    Text("아이콘만").tag("iconOnly")
                }
                Picker("테마", selection: $theme) {
                    Text("시스템").tag("system"); Text("라이트").tag("light"); Text("다크").tag("dark")
                }.pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 360)
    }
}

// MARK: - 상태 화면 (P6)

/// 로딩 스켈레톤(shimmer).
struct LoadingSkeleton: View {
    @State private var shimmer = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 54)
                    .overlay(
                        LinearGradient(colors: [.clear, .white.opacity(0.10), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .offset(x: shimmer ? 300 : -300))
                    .clipped()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { shimmer = true }
        }
        .accessibilityLabel("불러오는 중")
    }
}

/// 오류/캐시 상태.
struct ErrorStateView: View {
    var lastUpdated: Date?
    var retry: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle).foregroundStyle(Color.availSoon)
            Text("예약 정보를 가져오지 못했습니다").font(.callout.bold())
            Text(lastUpdated.map { "마지막 확인 \($0.formatted(date: .omitted, time: .shortened)) 데이터 표시" }
                 ?? "네트워크를 확인해 주세요")
                .font(.footnote).foregroundStyle(.secondary)
            Button("다시 시도", action: retry).controlSize(.small).padding(.top, 2)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
    }
}

/// 전체 마감 상태.
struct AllClosedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.secondary)
            Text("현재 금·토 빈자리 없음").font(.callout.bold())
            Text("취소가 나오면 알림으로 알려드릴 수 있어요").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
    }
}
