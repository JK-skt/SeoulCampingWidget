import WidgetKit
import SwiftUI
import CampingCore

/// 난지 캠핑장 예약 현황 위젯.
///
/// 이번 달/다음 달 금·토 예약 가능 수를 A/B/C/D별로 표시한다.
struct CampingWidget: Widget {
    let kind = "CampingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CampingProvider()) { entry in
            CampingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("난지 캠핑장")
        .description("이번 달/다음 달 금·토 예약 가능 현황")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CampingWidgetView: View {
    let entry: CampingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.snapshot.months) { month in
                VStack(alignment: .leading, spacing: 2) {
                    Text(month.label).font(.caption).bold()
                    HStack(spacing: 8) {
                        ForEach(month.sites) { site in
                            HStack(spacing: 1) {
                                Text(site.site.label).bold()
                                Text("\(site.availableCount)")
                                    .foregroundStyle(site.availableCount > 0 ? .green : .secondary)
                            }
                            .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
