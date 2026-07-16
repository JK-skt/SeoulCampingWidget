import SwiftUI

/// 달력 하루 정보 (파생 계산용).
struct DayInfo: Identifiable, Hashable {
    let year: Int
    let month: Int
    let day: Int
    let weekday: Int          // 1=일 … 7=토
    let sites: [String: Int]  // 사이트→잔여

    var id: String { "\(year)-\(month)-\(day)" }
    var key: String { "\(month)-\(day)" }
    var total: Int { sites.values.map { max(0, $0) }.reduce(0, +) }
    var isFriday: Bool { weekday == 6 }
    var isSaturday: Bool { weekday == 7 }
    var isWeekendCheckin: Bool { isFriday || isSaturday }   // 금·토 입실
    var availability: Availability { .of(total) }

    var date: Date {
        var c = DateComponents(); c.year = year; c.month = month; c.day = day
        return Calendar(identifier: .gregorian).date(from: c) ?? .distantPast
    }
    var weekdayKo: String { ["", "일", "월", "화", "수", "목", "금", "토"][weekday] }
    var label: String { "\(month)월 \(day)일 \(weekdayKo)요일" }

    /// VoiceOver 라벨: "7월 24일 금요일, 총 8자리 남음, A 3, B 2 …"
    var a11y: String {
        let sitesTxt = ["프리","A","B","C","D","바비큐","캠파"]
            .compactMap { s in sites[s].map { "\(s) \($0)" } }.joined(separator: ", ")
        return "\(label), 총 \(total)자리 남음" + (sitesTxt.isEmpty ? "" : ", \(sitesTxt)")
    }
}

extension CampViewModel {
    private var cal: Calendar { Calendar(identifier: .gregorian) }
    private var today: Date { cal.startOfDay(for: Date()) }

    /// 달력에 존재하는 (year, month) 목록 — 오름차순.
    var months: [(Int, Int)] {
        grid.keys.compactMap { k -> (Int, Int)? in
            let p = k.split(separator: "-"); guard p.count == 2, let y = Int(p[0]), let m = Int(p[1]) else { return nil }
            return (y, m)
        }.sorted { ($0.0, $0.1) < ($1.0, $1.1) }
    }

    /// 특정 월의 하루 정보들.
    private func days(inYear y: Int, month m: Int) -> [DayInfo] {
        let recs = grid["\(y)-\(m)"] ?? [:]
        return recs.keys.sorted().map { d in
            var c = DateComponents(); c.year = y; c.month = m; c.day = d
            let wd = cal.component(.weekday, from: cal.date(from: c)!)
            return DayInfo(year: y, month: m, day: d, weekday: wd, sites: recs[d] ?? [:])
        }
    }

    /// 전체(이번달+다음달) 하루 정보.
    var allDays: [DayInfo] { months.flatMap { days(inYear: $0.0, month: $0.1) } }

    /// 주말(금·토) 입실일 — 날짜순.
    var weekendDays: [DayInfo] { allDays.filter(\.isWeekendCheckin).sorted { $0.date < $1.date } }

    /// 오늘 이후 다가오는 주말.
    var upcomingWeekends: [DayInfo] { weekendDays.filter { $0.date >= today } }

    /// 가까운 금요일 / 토요일.
    var nearestFriday: DayInfo? { upcomingWeekends.first(where: \.isFriday) }
    var nearestSaturday: DayInfo? { upcomingWeekends.first(where: \.isSaturday) }

    /// 해당 월의 예약 가능(총 잔여>0) 주말 수.
    func availableWeekendCount(year: Int, month: Int) -> Int {
        days(inYear: year, month: month).filter { $0.isWeekendCheckin && $0.total > 0 }.count
    }

    /// 잔여 최다 날짜.
    var maxAvailabilityDay: DayInfo? { allDays.max { $0.total < $1.total } }

    /// 선택된 날짜 정보.
    var selectedDay: DayInfo? {
        guard let key = selectedKey else { return nil }
        return allDays.first { $0.key == key }
    }

    /// 필터 적용된 주말 목록.
    var filteredWeekends: [DayInfo] {
        weekendDays.filter { d in
            (filterWeekday == .all
             || (filterWeekday == .fri && d.isFriday)
             || (filterWeekday == .sat && d.isSaturday))
            && (!onlyAvailable || d.total > 0)
        }
    }

    /// (month, site) 예약 URL.
    func url(month: Int, site: String) -> URL? { siteURL["\(month)-\(site)"] }

    /// (month, site) 총모집수(cap). 인스펙터의 remain/cap 진행바용.
    func capacity(month: Int, site: String) -> Int {
        for svc in calendar.services where svc.month == month && svc.site == site {
            if let c = svc.days.map(\.cap).max() { return c }
        }
        return 0
    }

    /// 특정 월/일의 사이트별 잔여(정렬된 표시 순서).
    func sitesForDay(_ d: DayInfo) -> [(site: String, remain: Int, cap: Int)] {
        ["프리","A","B","C","D","바비큐","캠파"].compactMap { s in
            guard let r = d.sites[s] else { return nil }
            return (s, r, capacity(month: d.month, site: s))
        }
    }
}
