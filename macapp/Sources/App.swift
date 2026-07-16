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
            // 메뉴바 라벨: 아이콘 + (금·토 가용 시) 개수
            HStack(spacing: 3) {
                Image(systemName: vm.openWeekendCount > 0 ? "tent.fill" : "tent")
                if vm.openWeekendCount > 0 {
                    Text("금·토 \(vm.openWeekendCount)")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class CampViewModel: ObservableObject {
    @Published var services: [CampService] = []
    @Published var isLoading = false
    @Published var isBlocked = false
    @Published var lastUpdated: Date?
    /// 달력(사이트별 날짜 잔여). 라이브 미가용 시 번들 샘플.
    @Published var calendar: CalendarData = CalendarStore.loadBundled()

    /// 자동 갱신 주기(초). 사용자가 팝오버에서 변경.
    @Published var refreshInterval: Double = 900 {
        didSet { restartTimer() }
    }

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

    /// 구역(A~D)별 접수중 여부.
    var zoneCounts: [(String, Int)] {
        ["A", "B", "C", "D"].map { z in
            (z, services.filter { $0.isOpen && $0.zone == z }.count)
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
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
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tent.fill").foregroundStyle(.green)
                Text("난지캠핑장").font(.headline)
                Spacer()
                if vm.isLoading { ProgressView().controlSize(.small) }
                Button { Task { await vm.refresh() } } label: {
                    Label("갱신", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
            }

            // 갱신 주기 설정
            HStack(spacing: 8) {
                let open = vm.openWeekendCount
                Circle().fill(open > 0 ? .green : .secondary).frame(width: 8, height: 8)
                Text(open > 0 ? "금·토 예약 가능 \(open)곳" : "금·토 예약 가능 없음")
                    .font(.subheadline).bold()
                Spacer()
                Text("자동 갱신").font(.caption2).foregroundStyle(.secondary)
                Picker("", selection: $vm.refreshInterval) {
                    Text("끔").tag(0.0)
                    Text("30초").tag(30.0)
                    Text("1분").tag(60.0)
                    Text("5분").tag(300.0)
                    Text("15분").tag(900.0)
                }
                .labelsHidden()
                .frame(width: 74)
                .controlSize(.small)
            }

            Divider()

            // 2개월 달력(날짜별 사이트별 잔여)
            Text("이번달 · 다음달 · 사이트별 잔여").font(.caption).bold()
            ScrollView {
                VStack(spacing: 10) {
                    MiniMonth(year: 2026, month: 7, title: "이번달", grid: vm.grid, siteURL: vm.siteURL)
                    MiniMonth(year: 2026, month: 8, title: "다음달", grid: vm.grid, siteURL: vm.siteURL)
                }
            }
            .frame(maxHeight: 320)
            if vm.calendar.services.contains(where: { $0.site == "C" }) && vm.calendar.generatedAt.contains("예시") {
                Text("※ C형=실측 · A/B/D 등=예시 · 차단 해제 시 전 사이트 라이브")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }

            if vm.isBlocked {
                Text("⚠︎ 일시적 접근 제한 — 캐시된 정보 표시 중")
                    .font(.caption2).foregroundStyle(.orange)
            }

            Divider()
            HStack {
                if let d = vm.lastUpdated {
                    Text("갱신 \(d.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    let p = "/Users/jhkoo/SeoulCampingWidget/webwidget/dist/calendar.html"
                    if FileManager.default.fileExists(atPath: p) {
                        openURL(URL(fileURLWithPath: p))
                    } else {
                        openURL(URL(string: "https://yeyak.seoul.go.kr")!)
                    }
                } label: { Text("웹 크게 보기").font(.caption2) }
                .buttonStyle(.plain)
                Link("예약", destination: URL(string: "https://yeyak.seoul.go.kr")!).font(.caption2)
                Button("종료") { NSApplication.shared.terminate(nil) }.font(.caption2)
            }
        }
        .padding(14)
        .frame(width: 460)
    }
}

/// 한 달 미니 달력: 각 날짜에 총 잔여 + 사이트별 잔여 칩(클릭 시 예약 페이지).
struct MiniMonth: View {
    let year: Int
    let month: Int
    let title: String
    let grid: [String: [Int: [String: Int]]]
    /// "month-site" → 예약 URL.
    let siteURL: [String: URL]

    private let order = ["프리", "A", "B", "C", "D", "바비큐", "캠파"]
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var monthGrid: [Int: [String: Int]] { grid["\(year)-\(month)"] ?? [:] }

    private func chipColor(_ r: Int) -> Color { r == 0 ? .secondary : (r <= 3 ? .orange : .green) }

    /// 1일의 요일(0=일)과 총 일수.
    private var layout: (lead: Int, days: Int) {
        var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = 1
        let cal = Calendar(identifier: .gregorian)
        let first = cal.date(from: comps)!
        let lead = cal.component(.weekday, from: first) - 1   // 0=일
        let days = cal.range(of: .day, in: .month, for: first)!.count
        return (lead, days)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(title) \(year).\(String(format: "%02d", month))").font(.caption).bold()
            LazyVGrid(columns: cols, spacing: 2) {
                ForEach(["일","월","화","수","목","금","토"], id: \.self) { w in
                    Text(w).font(.system(size: 8)).foregroundStyle(.secondary)
                }
                ForEach(0..<layout.lead, id: \.self) { _ in Color.clear.frame(height: 1) }
                ForEach(1...layout.days, id: \.self) { day in
                    cell(day)
                }
            }
        }
    }

    private func chipSites(_ rec: [String: Int]) -> [String] {
        Array(order.filter { rec[$0] != nil }.prefix(4))
    }

    /// 사이트별 잔여 칩. URL 있으면 클릭 시 예약 페이지로 이동.
    @ViewBuilder private func chip(site: String, remain: Int) -> some View {
        let label = Text("\(site)\(remain)")
            .font(.system(size: 7))
            .foregroundStyle(chipColor(remain))
            .frame(maxWidth: .infinity, alignment: .leading)
        if let url = siteURL["\(month)-\(site)"] {
            Link(destination: url) { label }.buttonStyle(.plain)
        } else {
            label
        }
    }

    @ViewBuilder private func cell(_ day: Int) -> some View {
        let rec = monthGrid[day] ?? [:]
        let total = rec.values.map { max(0, $0) }.reduce(0, +)
        VStack(spacing: 1) {
            HStack(spacing: 2) {
                Text("\(day)").font(.system(size: 8)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if !rec.isEmpty {
                    Text("\(total)").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(total > 0 ? .green : .secondary)
                }
            }
            ForEach(chipSites(rec), id: \.self) { s in
                chip(site: s, remain: max(0, rec[s] ?? 0))
            }
        }
        .frame(height: 44, alignment: .top)
        .padding(2)
        .background(rec.isEmpty ? Color.clear : Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 3))
    }
}
