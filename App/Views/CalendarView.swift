import SwiftUI
import CampingCore

/// 월간 사이트별 가용 현황 + 주말 히트맵.
struct CalendarView: View {
    let month: MonthlyAvailability

    private let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]

    private var heatmapCells: [DayCell] {
        HeatmapBuilder.weekendCells(month: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 사이트별 가용 카드.
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(month.sites) { site in
                    VStack(spacing: 4) {
                        Text(site.site.label).font(.title3).bold()
                        Text("\(site.availableCount)")
                            .font(.title2)
                            .foregroundStyle(site.availableCount > 0 ? .green : .secondary)
                        Text("가능").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            // 주말 히트맵.
            if !heatmapCells.isEmpty {
                Text("주말 히트맵").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(heatmapCells) { cell in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green.opacity(0.15 + 0.85 * cell.intensity))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Text(dayNumber(cell.date))
                                    .font(.system(size: 9))
                                    .foregroundStyle(cell.isHoliday ? .red : .primary)
                            )
                            .help(cell.isHoliday ? "공휴일" : "주말")
                    }
                }
            }
        }
        .padding(4)
    }

    private func dayNumber(_ date: Date) -> String {
        "\(Calendar.current.component(.day, from: date))"
    }
}
