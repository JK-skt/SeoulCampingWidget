#!/usr/bin/env python3
# 난지캠핑장 이번달/다음달 2개월 달력 — 날짜별 사이트별 잔여 좌석 렌더러.
# 입력: crawler/calendar.mjs 출력({services:[{title, days:[{ymd, remain, cap, reg, code}]}]})
import json, sys, calendar, datetime

data = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/nanji_calendar.json"))
today = datetime.date(2026, 7, 16)

def site_label(title):
    for z in ["A", "B", "C", "D"]:
        if f"일반캠핑존 {z}형" in title: return z
    if "프리캠핑" in title: return "프리"
    if "바비큐" in title: return "바비큐"
    if "캠프파이어" in title: return "캠파"
    return "기타"

SITE_ORDER = ["프리", "A", "B", "C", "D", "바비큐", "캠파"]

# (year,month) -> ymd -> {site: remain}, 그리고 (year,month,site) -> 예약 URL
grid = {}
url_map = {}
BASE = "https://yeyak.seoul.go.kr/web/reservation/selectReservView.do?rsv_svc_id="
for svc in data["services"]:
    site = site_label(svc["title"])
    sid = svc.get("id", "")
    for d in svc.get("days", []):
        y, m, dd = int(d["ymd"][:4]), int(d["ymd"][4:6]), int(d["ymd"][6:8])
        grid.setdefault((y, m), {}).setdefault(dd, {})[site] = d
        url_map[(y, m, site)] = (BASE + sid) if sid else "https://yeyak.seoul.go.kr"

def cell_body(rec, y, m):
    if not rec: return ""
    chips = ""
    for s in SITE_ORDER:
        if s not in rec: continue
        r = rec[s]["remain"]
        cls = "full" if r <= 0 else ("low" if r <= 3 else "ok")
        url = url_map.get((y, m, s), "https://yeyak.seoul.go.kr")
        chips += f'<a class="chip {cls}" href="{url}" target="_blank" title="{s}형 예약 페이지">{s}<b>{max(0,r)}</b></a>'
    return f'<div class="chips">{chips}</div>'

def month_html(y, m, label):
    cal = calendar.Calendar(firstweekday=6)
    weeks = cal.monthdayscalendar(y, m)
    wd = ["일","월","화","수","목","금","토"]
    head = "".join(f'<th class="{"sat" if i==6 else "sun" if i==0 else ""}">{d}</th>' for i,d in enumerate(wd))
    gm = grid.get((y, m), {})
    rows = ""
    for week in weeks:
        cells = ""
        for i, day in enumerate(week):
            if day == 0: cells += '<td class="empty"></td>'; continue
            date = datetime.date(y, m, day)
            cls = "sat" if i==6 else "sun" if i==0 else ""
            past = date < today
            wknd = date.weekday() in (4,5)   # 금·토 입실
            rec = gm.get(day)
            total = sum(max(0, v["remain"]) for v in rec.values()) if rec else None
            tot = f'<span class="tot">{total}</span>' if total is not None else ""
            cells += f'<td class="{cls} {"past" if past else ""} {"wknd" if wknd else ""}"><span class="dnum">{day}</span>{tot}{cell_body(rec, y, m)}</td>'
        rows += f"<tr>{cells}</tr>"
    return f'<div class="cal"><div class="cal-h">{label} <b>{y}.{m:02d}</b></div><table><thead><tr>{head}</tr></thead><tbody>{rows}</tbody></table></div>'

cur = month_html(2026, 7, "이번달")
nxt = month_html(2026, 8, "다음달")
gen = data.get("generatedAt","")

HTML = f'''<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>난지캠핑장 · 날짜별 사이트별 잔여</title>
<style>
 :root{{color-scheme:dark}} *{{box-sizing:border-box;font-family:-apple-system,"Apple SD Gothic Neo",sans-serif}}
 body{{margin:0;background:linear-gradient(135deg,#1c1c1e,#23233a 55%,#0f5f49);color:#f2f2f7;padding:24px}}
 h1{{font-size:19px;margin:0 0 2px}} .live{{color:#34c759;font-size:12px}} .sub{{font-size:12px;opacity:.55;margin-bottom:14px}}
 .cals{{display:flex;gap:18px;flex-wrap:wrap}}
 .cal{{background:rgba(40,40,46,.9);border:1px solid rgba(255,255,255,.08);border-radius:16px;padding:12px;flex:1;min-width:430px}}
 .cal-h{{font-size:14px;font-weight:700;margin-bottom:8px}} .cal-h b{{opacity:.7;font-weight:600}}
 table{{width:100%;border-collapse:collapse;table-layout:fixed}}
 th{{font-size:11px;opacity:.55;padding:3px 0}} th.sun{{color:#ff6b6b}} th.sat{{color:#4aa8ff}}
 td{{height:74px;vertical-align:top;border:1px solid rgba(255,255,255,.05);padding:3px;position:relative}}
 td.empty{{border:0;background:transparent}} td.past{{opacity:.28}} td.wknd{{background:rgba(74,168,255,.07)}}
 td.sun .dnum{{color:#ff6b6b}} td.sat .dnum{{color:#4aa8ff}}
 .dnum{{font-size:11px;font-weight:700}} .tot{{position:absolute;top:2px;right:4px;font-size:12px;font-weight:800;color:#34c759}}
 .chips{{display:flex;flex-wrap:wrap;gap:2px;margin-top:2px}}
 .chip{{font-size:8.5px;padding:0 3px;border-radius:4px;line-height:1.5;background:rgba(255,255,255,.06);text-decoration:none;cursor:pointer}}
 .chip:hover{{background:rgba(255,255,255,.16)}}
 .chip b{{margin-left:1px}} .chip.ok{{color:#7ee29a}} .chip.low{{color:#ffd166}} .chip.full{{color:#8e8e93}}
 .legend{{margin-top:12px;font-size:12px;opacity:.7;display:flex;gap:18px;flex-wrap:wrap}}
 .k{{padding:1px 6px;border-radius:5px}} .k.ok{{color:#7ee29a;background:rgba(52,199,89,.15)}} .k.low{{color:#ffd166;background:rgba(255,209,102,.15)}} .k.full{{color:#8e8e93;background:rgba(142,142,147,.15)}}
</style></head><body>
 <h1>난지캠핑장 · 날짜별 사이트별 잔여 <span class="live">● LIVE</span></h1>
 <div class="sub">yeyak.seoul.go.kr 예약 달력(로그인 불필요) · 우측 상단 숫자=그날 총 잔여 · 생성 {gen}</div>
 <div class="cals">{cur}{nxt}</div>
 <div class="legend">
   <span><span class="k ok">C13</span> 여유(4+)</span>
   <span><span class="k low">A3</span> 임박(1~3)</span>
   <span><span class="k full">D0</span> 마감</span>
   <span>사이트: 프리 · 일반 A/B/C/D · 바비큐 · 캠파</span>
 </div>
</body></html>'''
out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/seats.html"
open(out,"w").write(HTML); print(out)
