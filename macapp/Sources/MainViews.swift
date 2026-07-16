import SwiftUI

// MARK: - 월 달력 (선택 가능, 금·토 강조)

struct MonthCalendar: View {
    let year: Int
    let month: Int
    let title: String
    @ObservedObject var vm: CampViewModel

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private var monthGrid: [Int: [String: Int]] { vm.grid["\(year)-\(month)"] ?? [:] }

    private var layout: (lead: Int, days: Int) {
        var c = DateComponents(); c.year = year; c.month = month; c.day = 1
        let cal = Calendar(identifier: .gregorian)
        let first = cal.date(from: c)!
        return (cal.component(.weekday, from: first) - 1, cal.range(of: .day, in: .month, for: first)!.count)
    }
    private func weekday(_ day: Int) -> Int { (layout.lead + day - 1) % 7 }  // 0=일
    private func isPast(_ day: Int) -> Bool {
        var c = DateComponents(); c.year = year; c.month = month; c.day = day
        let cal = Calendar(identifier: .gregorian)
        return (cal.date(from: c) ?? .distantFuture) < cal.startOfDay(for: Date())
    }
    private func isToday(_ day: Int) -> Bool {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: Date())
        return c.year == year && c.month == month && c.day == day
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(verbatim: "\(year)년 \(month)월").font(.title3.bold())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(Array(["일","월","화","수","목","금","토"].enumerated()), id: \.offset) { i, w in
                    Text(w).font(.caption2)
                        .foregroundStyle(i == 0 ? Color.campError : (i == 6 ? Color.weekendFri : .secondary))
                }
                ForEach(0..<layout.lead, id: \.self) { _ in Color.clear.frame(height: 1) }
                ForEach(1...layout.days, id: \.self) { cell($0) }
            }
        }
        .padding(12)
        .background(Color.bgCard, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func cell(_ day: Int) -> some View {
        let rec = monthGrid[day] ?? [:]
        let total = rec.values.map { max(0, $0) }.reduce(0, +)
        let w = weekday(day)
        let isWeekend = (w == 5 || w == 6)         // 금·토 입실
        let key = "\(month)-\(day)"
        let selected = vm.selectedKey == key

        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Text(verbatim: "\(day)").font(.caption.bold()).monospacedDigit()
                    .lineLimit(1).fixedSize()
                    .foregroundStyle(isToday(day) ? .white : (w == 0 ? Color.campError : (w == 6 ? Color.weekendFri : .primary)))
                    .padding(.horizontal, isToday(day) ? 4 : 0).padding(.vertical, isToday(day) ? 1 : 0)
                    .background(isToday(day) ? Color.accentColor : .clear, in: Capsule())
                Spacer(minLength: 0)
                if !rec.isEmpty {
                    Text(verbatim: "\(total)").font(.caption.bold()).monospacedDigit()
                        .lineLimit(1).fixedSize()
                        .foregroundStyle(Availability.of(total).color)
                }
            }
            if !rec.isEmpty {
                Text(Availability.of(total).label).font(.system(size: 8))
                    .foregroundStyle(Availability.of(total).color)
                if isWeekend {
                    HStack(spacing: 2) {
                        ForEach(["A","B","C","D"], id: \.self) { s in
                            if let r = rec[s] {
                                SiteAvailabilityChip(site: s, remain: r, url: vm.url(month: month, site: s))
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: isWeekend ? 84 : 58, alignment: .topLeading)
        .padding(5)
        .background(cellBG(w: w, hasData: !rec.isEmpty))
        .overlay(RoundedRectangle(cornerRadius: 9)
            .stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
        .opacity(isPast(day) ? 0.4 : 1)
        .contentShape(Rectangle())
        .onTapGesture { vm.selectedKey = key }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(month)월 \(day)일, 총 \(total)자리")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func cellBG(w: Int, hasData: Bool) -> some View {
        let color: Color = w == 5 ? Color.weekendFri.opacity(0.10)
            : (w == 6 ? Color.weekendSat.opacity(0.09) : (hasData ? Color.white.opacity(0.04) : .clear))
        return RoundedRectangle(cornerRadius: 9).fill(color)
    }
}

// MARK: - 인스펙터 (선택 날짜 상세)

struct InspectorPane: View {
    @ObservedObject var vm: CampViewModel
    @Environment(\.openURL) private var openURL

    private var day: DayInfo? { vm.selectedDay ?? vm.nearestFriday ?? vm.maxAvailabilityDay }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let d = day {
                Text("선택한 날짜").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(d.label).font(.title3.bold())
                    Spacer()
                    StatusPill(total: d.total)
                }
                // 총 잔여 큰 카드
                VStack(alignment: .leading, spacing: 2) {
                    Text("총 잔여").font(.caption2).foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(d.total)").font(.system(size: 30, weight: .heavy)).monospacedDigit()
                            .foregroundStyle(d.availability.color)
                        Text("자리").font(.callout).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(Color.bgElevated, in: RoundedRectangle(cornerRadius: 12))

                Text("사이트 유형별 잔여").font(.caption).foregroundStyle(.secondary)
                ForEach(vm.sitesForDay(d), id: \.site) { row in
                    siteRow(month: d.month, row: row)
                }

                Spacer(minLength: 0)
                Button {
                    openURL(vm.url(month: d.month, site: d.sites.keys.first ?? "A")
                            ?? URL(string: "https://yeyak.seoul.go.kr")!)
                } label: {
                    Label("예약 페이지 열기", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                HStack {
                    Button { } label: { Label("즐겨찾기", systemImage: "star") }
                    Button { } label: { Label("알림", systemImage: "bell") }
                    Spacer()
                }.controlSize(.small).foregroundStyle(.secondary)
                Text(vm.lastUpdated.map { "마지막 확인 \($0.formatted(date: .omitted, time: .shortened))" } ?? "")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                EmptyStateView()
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.bgCard, in: RoundedRectangle(cornerRadius: 12))
    }

    private func siteRow(month: Int, row: (site: String, remain: Int, cap: Int)) -> some View {
        HStack(spacing: 8) {
            Text(row.site).font(.caption.bold()).frame(width: 40, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(siteChipColor(row.remain))
                        .frame(width: row.cap > 0 ? geo.size.width * CGFloat(row.remain) / CGFloat(row.cap) : 0)
                }
            }.frame(height: 6)
            Text(row.cap > 0 ? "\(row.remain)/\(row.cap)" : "\(row.remain)")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)
        }
    }
}

// MARK: - 주말 목록 보기

struct WeekendListPane: View {
    @ObservedObject var vm: CampViewModel
    var body: some View {
        VStack(spacing: 8) {
            if vm.filteredWeekends.isEmpty {
                EmptyStateView()
            } else {
                ForEach(vm.filteredWeekends) { d in
                    HStack(spacing: 12) {
                        VStack {
                            Text("\(d.day)").font(.title2.bold()).monospacedDigit()
                            Text(d.weekdayKo).font(.caption)
                                .foregroundStyle(d.isFriday ? Color.weekendFri : Color.weekendSat)
                        }.frame(width: 44)
                        Divider().frame(height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(d.month)월 \(d.day)일").font(.subheadline.bold())
                            HStack(spacing: 6) {
                                Text("총 \(d.total)자리").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                StatusPill(total: d.total, compact: true)
                            }
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(["A","B","C","D"], id: \.self) { s in
                                VStack(spacing: 1) {
                                    Text(s).font(.system(size: 9)).foregroundStyle(.secondary)
                                    Text("\(d.sites[s] ?? 0)").font(.caption.bold()).monospacedDigit()
                                        .foregroundStyle(siteChipColor(d.sites[s] ?? 0))
                                }
                                .frame(width: 28).padding(.vertical, 4)
                                .background(Color.bgElevated, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(Color.bgCard, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                    .onTapGesture { vm.selectedKey = d.key; vm.viewMode = .calendar }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(d.a11y)
                }
            }
        }
    }
}

// MARK: - 상태 화면

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar").font(.largeTitle).foregroundStyle(.secondary)
            Text("표시할 예약 정보가 없습니다").font(.callout.bold())
            Text("데이터를 불러오면 이곳에 표시됩니다").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}
