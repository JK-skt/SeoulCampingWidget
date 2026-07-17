/* 난지캠핑장 — 현재 보고 있는 상세페이지의 달력을 그대로 읽어 누적·다운로드.
 *
 * fetch/네트워크를 안 쓴다. 화면에 이미 렌더된 달력(신청수/총모집수)을 DOM에서 읽으므로
 * WAF·CORS·붙여넣기 제약과 무관하게 항상 동작한다.
 *
 * 사용법:
 *   1) yeyak에서 난지캠핑장 "상세페이지"(달력이 보이는 화면)를 연다.
 *   2) F12 → Console 에 이 스크립트를 붙여넣고 Enter (붙여넣기 막히면 'allow pasting' 먼저).
 *   3) 그 서비스가 누적 저장되고, 지금까지 모은 전체가 nanji_calendar.json 로 다운로드된다.
 *   4) 다른 사이트(프리/A/B/C/D/바비큐/캠파, 7·8월)로 이동해 2~3을 반복한다.
 *      → 마지막에 받은 파일이 전체를 담고 있다.
 *   5) 그 파일을 ~/SeoulCampingWidget/crawler/nanji_calendar.json 로 저장 → 앱에서 [갱신].
 */
(() => {
  const id = (location.href.match(/rsv_svc_id=([A-Za-z0-9]+)/) || [])[1];
  if (!id) { console.log("[난지] 상세페이지(rsv_svc_id=...)에서 실행하세요."); return; }
  // 서비스 제목: "난지캠핑장"을 포함한 제목 요소를 찾는다(사이드바 등 오탐 방지).
  const title = [...document.querySelectorAll("h1,h2,h3,h4,.tit,.view_tit,.cont_tit,.tit_view")]
                  .map((e) => (e.textContent || "").replace(/\s+/g, " ").trim())
                  .find((t) => t.includes("난지캠핑장"))
                || (document.title || "").trim() || id;

  // 달력 셀: <div id="div_cal_YYYYMMDD"> ... <span class="num">신청수/총모집수</span>
  const days = [];
  document.querySelectorAll('[id^="div_cal_"]').forEach((el) => {
    const ymd = el.id.replace("div_cal_", "");
    const num = (el.querySelector(".num") || el).textContent.trim();
    const m = num.match(/(\d+)\s*\/\s*(\d+)/);
    if (m) {
      const reg = +m[1], cap = +m[2];
      days.push({ ymd, reg, cap, remain: Math.max(0, cap - reg) });
    }
  });

  // 폴백: div_cal_ 없으면 td.able의 data-ymd(가능일만)라도 수집
  if (days.length === 0) {
    document.querySelectorAll("td.able a[data-ymd], td .able[data-ymd]").forEach((a) => {
      days.push({ ymd: a.getAttribute("data-ymd"), reg: 0, cap: 0, remain: 1 });
    });
  }

  const store = JSON.parse(localStorage.getItem("nanji_cal") || '{"services":[]}');
  store.services = store.services.filter((s) => s.id !== id);
  store.services.push({ id, title: (title || "").replace(/\s+/g, " ").trim(), days });
  store.generatedAt = new Date().toISOString();
  store.source = "browser-dom";
  localStorage.setItem("nanji_cal", JSON.stringify(store));

  console.log(`[난지] "${title.slice(0,30)}" → ${days.length}일 저장 · 누적 ${store.services.length}개 서비스`);

  // 지금까지 모은 전체를 다운로드
  const blob = new Blob([JSON.stringify(store)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "nanji_calendar.json";
  document.body.appendChild(a); a.click(); a.remove();
  console.log("→ nanji_calendar.json 다운로드됨 (다른 사이트에서 반복하면 계속 누적)");
})();
