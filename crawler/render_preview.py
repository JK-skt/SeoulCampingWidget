#!/usr/bin/env python3
# 라이브 크롤 데이터(/tmp/live.json)로 macOS 위젯/메뉴바 UI 미리보기 HTML 생성.
import json, datetime, html, sys

data = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/live.json"))
services = data["services"]

# 이번달/다음달 계산
now = datetime.date(2026, 7, 16)
cur = now.month
nxt = 1 if cur == 12 else cur + 1

def zone_counts(month):
    c = {"A": 0, "B": 0, "C": 0, "D": 0}
    for s in services:
        if not s.get("open"):
            continue
        if f"{month}월" not in s["title"]:
            continue
        z = s.get("zone")
        if z in c:
            c[z] += 1
    return c

cur_c, nxt_c = zone_counts(cur), zone_counts(nxt)

def zone_row(counts):
    cells = ""
    for z in "ABCD":
        n = counts[z]
        color = "#34c759" if n > 0 else "#8e8e93"
        cells += f'<div class="z"><span class="zl">{z}</span><span class="zn" style="color:{color}">{n}</span></div>'
    return cells

def badge(status):
    ok = "접수중" in status
    return f'<span class="badge {"ok" if ok else "no"}">{html.escape(status)}</span>'

svc_rows = "".join(
    f'<div class="svc">{badge(s["status"])}<span class="svct">{html.escape(s["title"].replace("26년 한강공원 난지캠핑장","").strip())}</span></div>'
    for s in services
)

menubar = "🏕 " + " ".join(f'{z}{cur_c[z] if False else nxt_c[z]}' for z in "ABCD")  # 메뉴바는 가장 임박(다음달) 요약

HTML = f"""<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8">
<title>서울 캠핑 위젯 · 라이브 미리보기</title>
<style>
  * {{ box-sizing: border-box; font-family: -apple-system, "SF Pro", "Apple SD Gothic Neo", sans-serif; }}
  body {{ margin:0; min-height:100vh; background: linear-gradient(135deg,#1c1c1e,#2c2c2e 60%,#3a3a3c);
         display:flex; flex-direction:column; align-items:center; gap:26px; padding:34px; color:#f2f2f7; }}
  h1 {{ font-size:19px; font-weight:600; opacity:.85; margin:0; }}
  .sub {{ font-size:12px; opacity:.5; margin-top:-16px; }}
  /* 메뉴바 */
  .menubar {{ width:520px; height:26px; background:rgba(255,255,255,.08); backdrop-filter:blur(20px);
             border-radius:7px; display:flex; align-items:center; justify-content:flex-end; padding:0 12px;
             font-size:13px; font-variant-numeric:tabular-nums; letter-spacing:.5px; border:1px solid rgba(255,255,255,.06); }}
  .row {{ display:flex; gap:22px; align-items:flex-start; flex-wrap:wrap; justify-content:center; }}
  /* 위젯 카드 */
  .widget {{ width:200px; background:rgba(44,44,46,.9); border-radius:20px; padding:16px;
            box-shadow:0 12px 40px rgba(0,0,0,.5); border:1px solid rgba(255,255,255,.07); }}
  .widget.med {{ width:330px; }}
  .wt {{ font-size:14px; font-weight:700; margin-bottom:10px; }}
  .ml {{ font-size:11px; font-weight:600; opacity:.6; margin:8px 0 4px; }}
  .zrow {{ display:flex; gap:8px; }}
  .z {{ flex:1; background:rgba(255,255,255,.06); border-radius:9px; padding:7px 0; text-align:center; }}
  .zl {{ display:block; font-size:11px; opacity:.6; }}
  .zn {{ display:block; font-size:20px; font-weight:700; font-variant-numeric:tabular-nums; }}
  /* 상세 패널 */
  .panel {{ width:330px; background:rgba(44,44,46,.9); border-radius:16px; padding:16px;
           border:1px solid rgba(255,255,255,.07); box-shadow:0 12px 40px rgba(0,0,0,.5); }}
  .svc {{ display:flex; align-items:center; gap:8px; padding:7px 0; border-bottom:1px solid rgba(255,255,255,.06); font-size:12.5px; }}
  .svc:last-child {{ border-bottom:0; }}
  .svct {{ opacity:.9; }}
  .badge {{ font-size:10px; font-weight:700; padding:2px 7px; border-radius:20px; white-space:nowrap; }}
  .badge.ok {{ background:rgba(52,199,89,.2); color:#34c759; }}
  .badge.no {{ background:rgba(142,142,147,.2); color:#8e8e93; }}
  .foot {{ font-size:11px; opacity:.4; }}
  a {{ color:#0a84ff; text-decoration:none; }}
</style></head><body>
  <h1>서울 캠핑 위젯 — 난지캠핑장 <span style="color:#34c759">● LIVE</span></h1>
  <div class="sub">yeyak.seoul.go.kr 실시간 · 생성 {now.isoformat()}</div>

  <div class="menubar">{menubar}</div>

  <div class="row">
    <!-- Small 위젯 -->
    <div class="widget">
      <div class="wt">난지 캠핑장</div>
      <div class="ml">이번달 ({cur}월)</div>
      <div class="zrow">{zone_row(cur_c)}</div>
      <div class="ml">다음달 ({nxt}월)</div>
      <div class="zrow">{zone_row(nxt_c)}</div>
    </div>

    <!-- 상세 패널(메뉴바 드롭다운 느낌) -->
    <div class="panel">
      <div class="wt">난지캠핑장 · 예약 현황 ({len(services)}건)</div>
      {svc_rows}
      <div style="margin-top:10px" class="foot">
        일반캠핑존 A/B/D형 · 프리/바비큐/캠프파이어존 &nbsp;|&nbsp;
        <a href="https://yeyak.seoul.go.kr">예약 페이지 열기</a>
      </div>
    </div>
  </div>

  <div class="foot">※ 7월은 접수마감/미노출(0), 8월 오픈 · 일자별 잔여는 로그인 세션 필요</div>
</body></html>"""

out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/seoul_camping_preview.html"
open(out, "w").write(HTML)
print(out)
