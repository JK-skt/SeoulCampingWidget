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
    @Published var lastUpdated: Date?

    private var timer: Timer?

    init() {
        Task { await refresh() }
        // 15분마다 자동 새로고침
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
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
        let list = await YeyakClient.fetchNanji()
        if !list.isEmpty { services = list }   // 간헐적 빈 응답 시 기존 유지
        lastUpdated = Date()
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
                Button { Task { await vm.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
            }

            // 금·토 요약
            let open = vm.openWeekendCount
            HStack(spacing: 6) {
                Circle().fill(open > 0 ? .green : .secondary).frame(width: 8, height: 8)
                Text(open > 0 ? "금·토 예약 가능 \(open)곳" : "현재 금·토 예약 가능 없음")
                    .font(.subheadline).bold()
            }

            // 일반캠핑존 구역별
            HStack(spacing: 10) {
                ForEach(vm.zoneCounts, id: \.0) { z, n in
                    VStack(spacing: 2) {
                        Text(z).font(.caption).bold()
                        Text("\(n)").font(.body).foregroundStyle(n > 0 ? .green : .secondary)
                    }
                    .frame(width: 34).padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Divider()

            // 서비스 목록
            if vm.services.isEmpty {
                Text("불러오는 중…").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(vm.services) { s in
                    Button {
                        openURL(s.reservationURL)
                    } label: {
                        HStack(spacing: 6) {
                            Text(s.isOpen ? "접수중" : s.status)
                                .font(.caption2).bold()
                                .foregroundStyle(s.isOpen ? .green : .secondary)
                                .frame(width: 44, alignment: .leading)
                            Text(s.zoneLabel).font(.caption).frame(width: 60, alignment: .leading)
                            Text(s.title.replacingOccurrences(of: "26년 한강공원 난지캠핑장", with: "").trimmingCharacters(in: .whitespaces))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()
            HStack {
                if let d = vm.lastUpdated {
                    Text("갱신 \(d.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Link("예약 페이지", destination: URL(string: "https://yeyak.seoul.go.kr")!).font(.caption2)
                Button("종료") { NSApplication.shared.terminate(nil) }.font(.caption2)
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
