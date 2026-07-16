import WidgetKit
import SwiftUI
import CampingCore

/// 난지 캠핑장 예약 현황 위젯 (Apple 네이티브 다크 리디자인).
/// 이번 달/다음 달 금·토 예약 가능 수를 A/B/C/D별로 표시한다. (Small/Medium/Large)
struct CampingWidget: Widget {
    let kind = "CampingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CampingProvider()) { entry in
            CampingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("난지 캠핑장")
        .description("이번 달/다음 달 금·토 예약 가능 현황")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - 상태 판정 (색상만으로 구분 금지 — 텍스트+기호 병기)

private enum WStatus {
    case closed, soon, plenty
    static func of(_ total: Int) -> WStatus { total == 0 ? .closed : (total <= 10 ? .soon : .plenty) }
    var color: Color { self == .closed ? .secondary : (self == .soon ? .orange : .green) }
    var symbol: String { self == .closed ? "—" : (self == .soon ? "▲" : "●") }
    var label: String { self == .closed ? "마감" : (self == .soon ? "임박" : "여유") }
}

private func total(_ m: MonthlyAvailability) -> Int { m.sites.reduce(0) { $0 + $1.availableCount } }

/// 사이트별 잔여 색: 0 회색, 1~3 주황, >3 초록.
private func siteColor(_ n: Int) -> Color { n == 0 ? .secondary : (n <= 3 ? .orange : .green) }

// MARK: - 위젯 뷰 (패밀리별 레이아웃)

struct CampingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CampingEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallView(entry: entry)
        case .systemLarge:  LargeView(entry: entry)
        default:            MediumView(entry: entry)
        }
    }
}

/// Small — 텐트 + 가까운 달 총 잔여 큰 숫자 + 상태.
private struct SmallView: View {
    let entry: CampingEntry
    var body: some View {
        let m = entry.snapshot.months.first
        let t = m.map(total) ?? 0
        let s = WStatus.of(t)
        return VStack(alignment: .leading, spacing: 4) {
            Label("난지캠핑", systemImage: "tent.fill")
                .font(.caption.bold()).foregroundStyle(.green).labelStyle(.titleAndIcon)
            Spacer()
            Text(m?.label ?? "").font(.caption2).foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("\(t)").font(.system(size: 34, weight: .heavy)).monospacedDigit().foregroundStyle(s.color)
                Text("자리").font(.caption2).foregroundStyle(.secondary)
            }
            Text("\(s.symbol) \(s.label)").font(.caption2.bold()).foregroundStyle(s.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Medium — 이번달/다음달 2개 카드 (총잔여/상태/ABCD 모노).
private struct MediumView: View {
    let entry: CampingEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("난지캠핑장", systemImage: "tent.fill").font(.caption.bold()).foregroundStyle(.green)
                Spacer()
                Text(entry.snapshot.generatedAt, style: .time).font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(entry.snapshot.months.prefix(2)) { m in monthCard(m) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func monthCard(_ m: MonthlyAvailability) -> some View {
        let t = total(m), s = WStatus.of(t)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(m.label).font(.caption2.bold())
                Spacer()
                Text("\(s.symbol) \(t)").font(.caption.bold()).monospacedDigit().foregroundStyle(s.color)
            }
            HStack(spacing: 6) {
                ForEach(m.sites) { site in
                    HStack(spacing: 1) {
                        Text(site.site.label).font(.system(size: 9, weight: .semibold))
                        Text("\(site.availableCount)").font(.system(size: 9, weight: .bold)).monospacedDigit()
                    }
                    .foregroundStyle(siteColor(site.availableCount))
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(s.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Large — 월별 상세 리스트.
private struct LargeView: View {
    let entry: CampingEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("난지캠핑장 · 예약 현황", systemImage: "tent.fill").font(.subheadline.bold()).foregroundStyle(.green)
                Spacer()
                Text(entry.snapshot.generatedAt, style: .time).font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(entry.snapshot.months) { m in
                let t = total(m), s = WStatus.of(t)
                HStack {
                    Text(m.label).font(.callout.bold()).frame(width: 60, alignment: .leading)
                    HStack(spacing: 8) {
                        ForEach(m.sites) { site in
                            VStack(spacing: 1) {
                                Text(site.site.label).font(.system(size: 9)).foregroundStyle(.secondary)
                                Text("\(site.availableCount)").font(.caption.bold()).monospacedDigit()
                                    .foregroundStyle(siteColor(site.availableCount))
                            }.frame(width: 30)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(t)").font(.title3.bold()).monospacedDigit().foregroundStyle(s.color)
                        Text("\(s.symbol) \(s.label)").font(.caption2).foregroundStyle(s.color)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
            Spacer()
            Text("App Group 공유 저장소 기반").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
