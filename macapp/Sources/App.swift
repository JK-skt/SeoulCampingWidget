import SwiftUI
import AppKit

/// 난지캠핑장 메뉴바 앱.
/// 금·토 예약 가능한 사이트가 있으면 메뉴바에 직접 개수를 표시한다.
@main
struct SeoulCampingApp: App {
    @StateObject private var vm = CampViewModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(vm: vm)
        } label: {
            // 메뉴바 라벨: 상태별 아이콘 전환 + (금·토 가용 시) 개수
            HStack(spacing: 3) {
                Image(systemName: vm.menuBarSymbol)
                if vm.openWeekendCount > 0 { Text("금·토 \(vm.openWeekendCount)") }
            }
        }
        .menuBarExtraStyle(.window)

        // 메인 창 (전체 2개월 달력 + 인스펙터)
        Window("난지캠핑장 예약 현황", id: "main") {
            ContentView(vm: vm)
        }
        .defaultSize(width: 980, height: 680)

        // 설정 (Cmd+, / 툴바 기어)
        Settings {
            SettingsView(vm: vm)
        }
    }
}

@MainActor
final class CampViewModel: ObservableObject {
    @Published var services: [CampService] = []
    @Published var isLoading = false
    @Published var isBlocked = false
    @Published var lastUpdated: Date?
    /// 달력(사이트별 날짜 잔여). 크롤러 출력 → 캐시 → 번들 샘플 순으로 로드.
    @Published var calendar: CalendarData = CalendarStore.loadFresh()

    /// 자동 갱신 주기(초). 사용자가 팝오버에서 변경.
    @Published var refreshInterval: Double = 900 {
        didSet { restartTimer() }
    }

    // 화면 상태 (Handoff "State Management" — 신규 네트워크 요청 없이 파생)
    @Published var selectedKey: String? = nil          // "month-day"
    @Published var viewMode: ViewMode = .calendar
    @Published var filterWeekday: WeekdayFilter = .all
    @Published var onlyAvailable = false

    enum ViewMode { case calendar, list }
    enum WeekdayFilter { case all, fri, sat }

    var grid: [String: [Int: [String: Int]]] { CalendarStore.grid(calendar) }

    /// "month-site" → 예약 URL (달력 칩 클릭 시 이동).
    var siteURL: [String: URL] {
        var m: [String: URL] = [:]
        for svc in calendar.services {
            if let mm = svc.month, let url = svc.reservationURL { m["\(mm)-\(svc.site)"] = url }
        }
        return m
    }

    private var timer: Timer?

    init() {
        // 캐시 즉시 표시(재시작 시 재요청 최소화)
        if let cached = YeyakClient.loadCache() { services = cached }
        Task { await refresh() }
        restartTimer()
        // 디자인 검증용 오프스크린 렌더(환경변수로만 동작).
        if ProcessInfo.processInfo.environment["SEOULCAMP_RENDER"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.renderPreviews() }
        }
    }

    /// ContentView / PopoverView를 PNG로 렌더링(디자인 확인용).
    func renderPreviews() {
        func save(_ view: some View, _ w: CGFloat, _ h: CGFloat, _ path: String) {
            let r = ImageRenderer(content:
                view.frame(width: w, height: h).environment(\.colorScheme, .dark).background(Color.bgWindow))
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation,
               let bm = NSBitmapImageRep(data: tiff), let png = bm.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
            }
        }
        selectedKey = "7-18"   // 인스펙터 표시용 선택
        save(ContentView(vm: self), 980, 680, "/tmp/scr_main.png")
        save(PopoverView(vm: self), 340, 620, "/tmp/scr_popover.png")
        // 본문(달력+인스펙터) — ScrollView 없이 직접 렌더(렌더러 한계 우회)
        let body = HStack(alignment: .top, spacing: 14) {
            MonthCalendar(year: 2026, month: 7, title: "이번달", vm: self)
            MonthCalendar(year: 2026, month: 8, title: "다음달", vm: self)
            InspectorPane(vm: self).frame(width: 300)
        }.padding(18)
        save(body, 1000, 640, "/tmp/scr_body.png")
        exit(0)
    }

    /// 현재 주기로 타이머 재설정.
    func restartTimer() {
        timer?.invalidate()
        guard refreshInterval > 0 else { return }   // 0 = 자동 갱신 끔
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    /// 금·토 예약 가능(접수중) 사이트 수. (캠핑 서비스는 주말 숙박 대상)
    var openWeekendCount: Int { services.filter { $0.isOpen }.count }

    /// 메뉴바 아이콘: 갱신 중=진행, 오류=경고, 빈자리 있음=강조 텐트.
    var menuBarSymbol: String {
        if isBlocked { return "exclamationmark.triangle" }
        if isLoading { return "arrow.triangle.2.circlepath" }
        return openWeekendCount > 0 ? "tent.fill" : "tent"
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        // 달력 데이터도 함께 갱신(크롤러가 새 실측을 저장했으면 즉시 반영).
        calendar = CalendarStore.loadFresh()
        switch await YeyakClient.shared.fetch() {
        case .ok(let list):
            services = list
            isBlocked = false
            lastUpdated = Date()
        case .blocked:
            isBlocked = true          // 차단 감지: 기존/캐시 유지, 다음 주기에 재시도
        case .failed:
            break                     // 실패: 기존 데이터 유지
        }
    }
}

struct PopoverView: View {
    @ObservedObject var vm: CampViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ① 헤더
            HStack(spacing: 8) {
                Image(systemName: "tent.fill").foregroundStyle(Color.availHigh)
                Text("난지캠핑장").font(.headline)
                LivePill(live: !vm.isBlocked)
                Spacer()
                Button { Task { await vm.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                        .animation(vm.isLoading ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                                   value: vm.isLoading)
                }
                .buttonStyle(.borderless).disabled(vm.isLoading)
                .help("새로고침")
            }

            // ②③ 가까운 금/토 카드
            WeekendCard(day: vm.nearestFriday, tint: .weekendFri, kind: "가까운 금요일", vm: vm)
            WeekendCard(day: vm.nearestSaturday, tint: .weekendSat, kind: "가까운 토요일", vm: vm)

            // ④ 다가오는 주말
            Text("다가오는 주말").font(.caption).foregroundStyle(.secondary)
            let upcoming = Array(vm.upcomingWeekends.prefix(5))
            if upcoming.isEmpty {
                Text("표시할 주말 데이터가 없습니다").font(.caption2).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(upcoming) { d in
                        UpcomingRow(day: d)
                        if d.id != upcoming.last?.id { Divider().opacity(0.35) }
                    }
                }
            }

            if vm.isBlocked {
                Label("일시적 접근 제한 — 캐시 표시 중", systemImage: "exclamationmark.triangle")
                    .font(.caption2).foregroundStyle(.orange)
            }

            // ⑤ 액션
            HStack(spacing: 8) {
                Button { openWindow(id: "main") } label: { Label("앱 열기", systemImage: "arrow.up.right.square") }
                    .controlSize(.small).buttonStyle(.borderedProminent)
                Spacer()
                Text("자동").font(.caption2).foregroundStyle(.secondary)
                Picker("", selection: $vm.refreshInterval) {
                    Text("끔").tag(0.0); Text("30초").tag(30.0); Text("1분").tag(60.0)
                    Text("5분").tag(300.0); Text("15분").tag(900.0)
                }.labelsHidden().frame(width: 66).controlSize(.small)
            }

            // ⑥ 하단
            Divider()
            HStack {
                Text(vm.lastUpdated.map { "갱신 \($0.formatted(date: .omitted, time: .shortened))" } ?? "갱신 전")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Link("예약", destination: URL(string: "https://yeyak.seoul.go.kr")!).font(.caption2)
                Button("종료") { NSApplication.shared.terminate(nil) }.font(.caption2)
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}

/// 가까운 금/토 요약 카드 (Control Center 스타일).
struct WeekendCard: View {
    let day: DayInfo?
    let tint: Color
    let kind: String
    @ObservedObject var vm: CampViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind).font(.system(size: 10)).foregroundStyle(.secondary)
                if let d = day {
                    Text("\(d.month)/\(d.day)").font(.title3.bold()).monospacedDigit().foregroundStyle(tint)
                    Text("\(d.weekdayKo)요일").font(.system(size: 10)).foregroundStyle(.secondary)
                } else {
                    Text("없음").font(.title3.bold()).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                if let d = day {
                    HStack(spacing: 6) {
                        Text("총 \(d.total)자리").font(.subheadline.bold()).monospacedDigit()
                        StatusPill(total: d.total, compact: true)
                    }
                    HStack(spacing: 5) {
                        ForEach(["A","B","C","D"], id: \.self) { s in
                            SiteAvailabilityChip(site: s, remain: d.sites[s] ?? 0, url: vm.url(month: d.month, site: s))
                        }
                    }
                } else {
                    Text("총 0자리 —").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.28), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(day?.a11y ?? "\(kind) 없음")
    }
}

/// 다가오는 주말 1행.
struct UpcomingRow: View {
    let day: DayInfo
    var body: some View {
        HStack(spacing: 8) {
            Text("\(day.month).\(day.day)").font(.caption.monospacedDigit())
                .frame(width: 40, alignment: .leading)
            Text(day.weekdayKo).font(.caption.bold())
                .foregroundStyle(day.isFriday ? Color.weekendFri : Color.weekendSat).frame(width: 18)
            Spacer()
            Text("\(day.total)자리").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text(day.availability.symbol).font(.system(size: 10, weight: .bold))
                .foregroundStyle(day.availability.color)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(day.a11y)
    }
}

