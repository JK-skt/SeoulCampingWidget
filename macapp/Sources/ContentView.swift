import SwiftUI

/// 메인 앱 창 — 2개월 달력 + 요약 카드 + 인스펙터 / 주말 목록. (Handoff 화면 1·2)
struct ContentView: View {
    @ObservedObject var vm: CampViewModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if vm.isBlocked {
                        Label("일시적 접근 제한으로 캐시된 정보를 표시 중입니다 · 자동 재시도됩니다",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Color.availSoon)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.availSoon.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                    controlRow
                    summaryCards
                    if vm.viewMode == .calendar {
                        HStack(alignment: .top, spacing: 14) {
                            calendars
                            InspectorPane(vm: vm).frame(width: 300)
                        }
                    } else {
                        WeekendListPane(vm: vm)
                    }
                }
                .padding(18)
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.137, green: 0.137, blue: 0.149).ignoresSafeArea())  // #232326 다크 창 배경
        .preferredColorScheme(.dark)                          // 다크 네이티브 디자인
    }

    // MARK: 툴바
    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "tent.fill").foregroundStyle(Color.availHigh)
            Text("난지캠핑장 예약 현황").font(.headline)
            LivePill(live: !vm.isBlocked)
            Spacer()
            Text(vm.lastUpdated.map { "갱신 \($0.formatted(date: .omitted, time: .shortened))" } ?? "갱신 전")
                .font(.caption2).foregroundStyle(.secondary)
            Button { Task { await vm.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                    .animation(vm.isLoading ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                               value: vm.isLoading)
            }
            .disabled(vm.isLoading).help("새로고침")
            Picker("자동 갱신", selection: $vm.refreshInterval) {
                Text("끔").tag(0.0); Text("30초").tag(30.0); Text("1분").tag(60.0)
                Text("5분").tag(300.0); Text("15분").tag(900.0)
            }.frame(width: 130).controlSize(.small)
            if #available(macOS 14.0, *) {
                SettingsLink { Image(systemName: "gearshape") }.help("설정")
            } else {
                Button {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                } label: { Image(systemName: "gearshape") }.help("설정")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: 컨트롤 행 (보기 전환 + 필터 + 범례)
    private var controlRow: some View {
        HStack(spacing: 12) {
            Picker("", selection: $vm.viewMode) {
                Text("달력").tag(CampViewModel.ViewMode.calendar)
                Text("주말 목록").tag(CampViewModel.ViewMode.list)
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 160)

            FilterChip(title: "금요일", color: .weekendFri,
                       isOn: vm.filterWeekday == .fri) {
                vm.filterWeekday = vm.filterWeekday == .fri ? .all : .fri; vm.viewMode = .list
            }
            FilterChip(title: "토요일", color: .weekendSat,
                       isOn: vm.filterWeekday == .sat) {
                vm.filterWeekday = vm.filterWeekday == .sat ? .all : .sat; vm.viewMode = .list
            }
            FilterChip(title: "잔여 있음", color: .accentColor, isOn: vm.onlyAvailable) {
                vm.onlyAvailable.toggle()
            }
            Spacer()
            LegendView()
        }
    }

    // MARK: 요약 카드 5열
    private var summaryCards: some View {
        HStack(spacing: 10) {
            SummaryCard(title: "가까운 금요일",
                        value: vm.nearestFriday.map { "\($0.month)/\($0.day)" } ?? "없음",
                        sub: vm.nearestFriday.map { "총 \($0.total)자리 \(Availability.of($0.total).symbol)" } ?? "—",
                        tint: .weekendFri)
            SummaryCard(title: "가까운 토요일",
                        value: vm.nearestSaturday.map { "\($0.month)/\($0.day)" } ?? "없음",
                        sub: vm.nearestSaturday.map { "총 \($0.total)자리 \(Availability.of($0.total).symbol)" } ?? "—",
                        tint: .weekendSat)
            if let m = vm.months.first {
                SummaryCard(title: "이번달 예약가능 주말",
                            value: "\(vm.availableWeekendCount(year: m.0, month: m.1))일",
                            sub: "\(m.1)월 금·토 기준")
            }
            if vm.months.count > 1 {
                let m = vm.months[1]
                SummaryCard(title: "다음달 예약가능 주말",
                            value: "\(vm.availableWeekendCount(year: m.0, month: m.1))일",
                            sub: "\(m.1)월 금·토 기준")
            }
            SummaryCard(title: "잔여 최다 날짜",
                        value: vm.maxAvailabilityDay.map { "\($0.month)/\($0.day)" } ?? "—",
                        sub: vm.maxAvailabilityDay.map { "총 \($0.total)자리" } ?? "—")
        }
    }

    // MARK: 달력(2개월)
    private var calendars: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(vm.months.prefix(2), id: \.1) { ym in
                MonthCalendar(year: ym.0, month: ym.1,
                              title: ym.1 == vm.months.first?.1 ? "이번달" : "다음달", vm: vm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 필터 칩.
struct FilterChip: View {
    let title: String
    let color: Color
    let isOn: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.caption.weight(.medium))
                .foregroundStyle(isOn ? .white : color)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(isOn ? color : color.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
