import SwiftUI
import AppKit
import CampingCore

/// 메뉴바 팝오버 내용.
struct MenuBarView: View {
    @ObservedObject var viewModel: ReservationViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.snapshot.campground.displayName)
                .font(.headline)

            ForEach(viewModel.snapshot.months) { month in
                MonthSummaryView(month: month)
            }

            Divider()

            HStack {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)

                Spacer()

                Button("캘린더") { openWindow(id: "main") }
            }

            HStack {
                Menu("내보내기") {
                    Button("CSV로 저장") { export(data: Data(viewModel.exportCSV().utf8), ext: "csv") }
                    Button("JSON으로 저장") { if let d = viewModel.exportJSON() { export(data: d, ext: "json") } }
                }
                .font(.caption)
                Spacer()
                Link("예약 페이지", destination: URL(string: "https://yeyak.seoul.go.kr")!)
                    .font(.caption)
                Button("종료") { NSApplication.shared.terminate(nil) }
                    .font(.caption)
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    /// NSSavePanel로 파일 저장.
    private func export(data: Data, ext: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "seoul-camping.\(ext)"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}

/// 월별 A/B/C/D 요약.
struct MonthSummaryView: View {
    let month: MonthlyAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(month.label).font(.subheadline).bold()
            HStack(spacing: 10) {
                ForEach(month.sites) { site in
                    HStack(spacing: 2) {
                        Text(site.site.label).bold()
                        Text("\(site.availableCount)")
                            .foregroundStyle(site.availableCount > 0 ? .green : .secondary)
                    }
                    .font(.system(.body, design: .monospaced))
                }
            }
        }
    }
}
