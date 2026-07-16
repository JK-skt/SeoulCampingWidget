import SwiftUI

// MARK: - 디자인 토큰 (Handoff README "Design Tokens")
// 하드코딩 대신 시맨틱 토큰으로 정의하고 macOS 시스템 컬러에 매핑한다.

extension Color {
    // 가용성
    static let availHigh = Color.green            // 여유 (#30d158)
    static let availSoon = Color.orange           // 임박 (#ff9f0a)
    static let availClosed = Color.secondary      // 마감 (#8e8e93)
    static let campError = Color.red              // 오류·일요일 (#ff453a)
    // 주말 강조
    static let weekendFri = Color.blue            // 금요일 (#0a84ff)
    static let weekendSat = Color.green           // 토요일 (#30d158)
    // 배경(다크 기준값 → 시스템 컬러)
    static let bgWindow = Color(nsColor: .windowBackgroundColor)
    static let bgElevated = Color(nsColor: .controlBackgroundColor)
    static let bgCard = Color(nsColor: .underPageBackgroundColor)
    static let separatorWeak = Color.white.opacity(0.09)
    static let separatorStrong = Color.white.opacity(0.16)
}

// MARK: - 가용성 상태 판정 (색상만으로 구분 금지 — 텍스트+기호 병기)

enum Availability {
    case closed   // total == 0
    case soon     // 1...10
    case plenty   // > 10

    static func of(_ total: Int) -> Availability {
        total == 0 ? .closed : (total <= 10 ? .soon : .plenty)
    }
    var color: Color {
        switch self {
        case .closed: return .availClosed
        case .soon:   return .availSoon
        case .plenty: return .availHigh
        }
    }
    /// 색맹 대응 기호.
    var symbol: String {
        switch self {
        case .closed: return "—"
        case .soon:   return "▲"
        case .plenty: return "●"
        }
    }
    var label: String {
        switch self {
        case .closed: return "마감"
        case .soon:   return "임박"
        case .plenty: return "여유"
        }
    }
}

/// 사이트별 칩 색: 0 회색(흐림), 1~3 주황, >3 초록.
func siteChipColor(_ remain: Int) -> Color {
    remain == 0 ? Color.availClosed.opacity(0.75) : (remain <= 3 ? .availSoon : .availHigh)
}

// MARK: - 공통 컴포넌트

/// 상태 pill: dot + 기호 + 라벨. (여유●/임박▲/마감—)
struct StatusPill: View {
    let total: Int
    var compact = false
    private var a: Availability { .of(total) }
    var body: some View {
        HStack(spacing: 4) {
            Text(a.symbol).font(.system(size: compact ? 9 : 11, weight: .bold))
            if !compact { Text(a.label).font(.caption2.bold()) }
        }
        .foregroundStyle(a.color)
        .padding(.horizontal, compact ? 5 : 7).padding(.vertical, 2)
        .background(a.color.opacity(0.14), in: Capsule())
        .accessibilityLabel("\(a.label), 총 \(total)자리")
    }
}

/// "실시간" 상태 pill (초록 dot).
struct LivePill: View {
    var live: Bool = true
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(live ? Color.availHigh : Color.availClosed).frame(width: 6, height: 6)
            Text(live ? "실시간" : "오프라인").font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(live ? Color.availHigh : Color.secondary)
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background((live ? Color.availHigh : Color.secondary).opacity(0.14), in: Capsule())
    }
}

/// 사이트별 잔여 칩 (코드 + 수량, 모노 숫자).
struct SiteAvailabilityChip: View {
    let site: String
    let remain: Int
    var url: URL? = nil
    private var body0: some View {
        HStack(spacing: 2) {
            Text(site).font(.system(size: 9, weight: .semibold))
            Text("\(remain)").font(.system(size: 9.5, weight: .bold)).monospacedDigit()
        }
        .foregroundStyle(siteChipColor(remain))
        .padding(.horizontal, 4).padding(.vertical, 1)
        .background(siteChipColor(remain).opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
        .accessibilityLabel("\(site) \(remain)자리")
    }
    var body: some View {
        if let url {
            Link(destination: url) { body0 }.buttonStyle(.plain).help("\(site) 예약 페이지 열기")
        } else { body0 }
    }
}

/// 인라인 범례 (여유●/임박▲/마감— + 금/토 색).
struct LegendView: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach([Availability.plenty, .soon, .closed], id: \.label) { a in
                HStack(spacing: 3) {
                    Text(a.symbol).font(.system(size: 9, weight: .bold)).foregroundStyle(a.color)
                    Text(a.label).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2).fill(Color.weekendFri).frame(width: 8, height: 8)
                Text("금").font(.system(size: 9)).foregroundStyle(.secondary)
                RoundedRectangle(cornerRadius: 2).fill(Color.weekendSat).frame(width: 8, height: 8)
                Text("토").font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
    }
}

/// 요약 카드 (제목 + 큰 값 + 보조). tint로 금(파랑)/토(초록) 구분.
struct SummaryCard: View {
    let title: String
    let value: String
    let sub: String
    var tint: Color? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.title2.bold()).monospacedDigit()
                .foregroundStyle(tint ?? .primary)
            Text(sub).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background((tint ?? Color.bgElevated).opacity(tint == nil ? 1 : 0.14),
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke((tint ?? .separatorWeak).opacity(tint == nil ? 1 : 0.28), lineWidth: 1))
    }
}
