#!/usr/bin/env python3
# 난지캠핑장 이번달/다음달 2개월 달력 렌더러.
# 각 날짜에 사이트별 가용을 표시한다. (정확한 '남은 자리수'는 yeyak 로그인 세션 필요 →
# 로그인 시 calendar AJAX의 RESVE_POSBL_CNT로 대체. 미로그인 시 접수중 사이트의 가용 여부 표시.)
import json, sys, calendar, datetime

data = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/live.json"))
services = data["services"]
today = datetime.date(2026, 7, 16)

# 사이트 정의(표시 순서)
SITES = [("프리", "프리캠핑"), ("A", "일반캠핑존 A형"), ("B", "일반캠핑존 B형"),
         ("C", "일반캠핑존 C형"), ("D", "일반캠핑존 D형"), ("바비큐", "바비큐"), ("캠파", "캠프파이어")]

def open_sites_for(month):
    """해당 월에 접수중인 사이트 라벨 집합."""
    res = set()
    for s in services:
        if "접수중" not in s["status"]:
            continue
        if f"{month}월" not in s["title"]:
            continue
        for label, key in SITES:
            if key in s["title"]:
                res.add(label)
    return res

def month_cal(year, month, title):
    opened = open_sites_for(month)
    is_open = len(opened) > 0
    cal = calendar.Calendar(firstweekday=6)  # 일요일 시작
    weeks = cal.monthdayscalendar(year, month)
    wd = ["일", "월", "화", "수", "목", "금", "토"]
    head = "".join(f'<th class="{"sat" if i==6 else "sun" if i==0 else ""}">{d}</th>' for i, d in enumerate(wd))
    rows = ""
    for week in weeks:
        cells = ""
        for i, day in enumerate(week):
            if day == 0:
                cells += '<td class="empty"></td>'; continue
            date = datetime.date(year, month, day)
            is_fri, is_sat = (date.weekday() == 4), (date.weekday() == 5)
            cls = "sat" if i == 6 else "sun" if i == 0 else ""
            past = date < today
            night = ""  # 캠핑 입실일 표시
            body = ""
            if (is_fri or is_sat) and not past:
                night = "fri" if is_fri else "sat"
                if is_open:
                    chips = "".join(
                        f'<span class="chip {"ok" if lbl in opened else "no"}">{lbl}</span>'
                        for lbl, _ in SITES if lbl in opened or lbl in ("A","B","C","D")
                    )
                    tag = "금-토박" if is_fri else "토-일박"
                    body = f'<div class="tag {night}">{tag}</div><div class="chips">{chips}</div>'
                else:
                    body = '<div class="tag closed">마감</div>'
            rows_cls = f"{cls} {night} {'past' if past else ''}".strip()
            cells += f'<td class="{rows_cls}"><span class="dnum">{day}</span>{body}</td>'
        rows += f"<tr>{cells}</tr>"
    badge = f'<span class="mon-open">예약 오픈 · {len(opened)}개 사이트</span>' if is_open else '<span class="mon-closed">미개방/마감</span>'
    return f'''<div class="cal">
      <div class="cal-h">{title} <b>{year}.{month:02d}</b> {badge}</div>
      <table><thead><tr>{head}</tr></thead><tbody>{rows}</tbody></table>
    </div>'''

cur = month_cal(2026, 7, "이번달")
nxt = month_cal(2026, 8, "다음달")

HTML = f'''<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>난지캠핑장 · 이번달/다음달 달력</title>
<style>
  :root {{ color-scheme: dark; }}
  * {{ box-sizing:border-box; font-family:-apple-system,"Apple SD Gothic Neo",sans-serif; }}
  body {{ margin:0; background:linear-gradient(135deg,#1c1c1e,#23233a 55%,#0f5f49); color:#f2f2f7; padding:26px; }}
  h1 {{ font-size:19px; margin:0 0 2px; }} .live {{ color:#34c759; font-size:12px; }}
  .sub {{ font-size:12px; opacity:.55; margin-bottom:14px; }}
  .banner {{ background:rgba(255,209,102,.12); border:1px solid rgba(255,209,102,.3); color:#ffd166;
             font-size:12px; padding:8px 12px; border-radius:10px; margin-bottom:16px; }}
  .cals {{ display:flex; gap:20px; flex-wrap:wrap; }}
  .cal {{ background:rgba(40,40,46,.9); border:1px solid rgba(255,255,255,.08); border-radius:16px; padding:14px; flex:1; min-width:340px; }}
  .cal-h {{ font-size:14px; font-weight:700; margin-bottom:8px; }}
  .cal-h b {{ opacity:.7; font-weight:600; }}
  .mon-open {{ font-size:11px; background:rgba(52,199,89,.2); color:#34c759; padding:2px 8px; border-radius:20px; margin-left:6px; }}
  .mon-closed {{ font-size:11px; background:rgba(142,142,147,.2); color:#8e8e93; padding:2px 8px; border-radius:20px; margin-left:6px; }}
  table {{ width:100%; border-collapse:collapse; table-layout:fixed; }}
  th {{ font-size:11px; opacity:.55; padding:4px 0; font-weight:600; }}
  th.sun,td.sun .dnum {{ color:#ff6b6b; }} th.sat,td.sat .dnum {{ color:#4aa8ff; }}
  td {{ height:64px; vertical-align:top; border:1px solid rgba(255,255,255,.05); padding:3px; }}
  td.empty {{ background:transparent; border:0; }}
  td.past {{ opacity:.3; }}
  td.fri {{ background:rgba(74,168,255,.10); }} td.sat {{ background:rgba(52,199,89,.10); }}
  .dnum {{ font-size:12px; font-weight:700; }}
  .tag {{ font-size:9px; font-weight:700; margin:2px 0 1px; }}
  .tag.fri {{ color:#4aa8ff; }} .tag.sat {{ color:#34c759; }} .tag.closed {{ color:#8e8e93; }}
  .chips {{ display:flex; flex-wrap:wrap; gap:2px; }}
  .chip {{ font-size:8.5px; padding:1px 4px; border-radius:5px; }}
  .chip.ok {{ background:rgba(52,199,89,.25); color:#7ee29a; }}
  .chip.no {{ background:rgba(142,142,147,.18); color:#8e8e93; }}
  .legend {{ margin-top:14px; font-size:12px; opacity:.7; display:flex; gap:16px; flex-wrap:wrap; }}
  .sw {{ display:inline-block; width:12px; height:12px; border-radius:3px; vertical-align:-2px; margin-right:4px; }}
</style></head><body>
  <h1>난지캠핑장 예약 달력 <span class="live">● LIVE</span></h1>
  <div class="sub">yeyak.seoul.go.kr · 생성 {data.get("generatedAt","")}</div>
  <div class="banner">ℹ️ 정확한 <b>날짜별 사이트별 남은 자리수</b>는 yeyak 로그인 세션이 필요합니다(예약 달력 API가 로그인 요구).
     현재는 <b>접수중 사이트</b>를 주말 입실일(금/토)에 표시합니다. 로그인 세션 주입 시 실제 잔여수로 대체됩니다.</div>
  <div class="cals">{cur}{nxt}</div>
  <div class="legend">
    <span><span class="sw" style="background:rgba(74,168,255,.5)"></span>금요일 입실(금-토박)</span>
    <span><span class="sw" style="background:rgba(52,199,89,.5)"></span>토요일 입실(토-일박)</span>
    <span><span class="chip ok">A</span> 접수중 사이트 &nbsp; <span class="chip no">C</span> 미개방</span>
  </div>
</body></html>'''

out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/calendar.html"
open(out, "w").write(HTML)
print(out)
