/* 난지캠핑장 날짜별 사이트별 잔여 수집기 — 브라우저 콘솔용.
 *
 * 왜 필요한가: yeyak의 예약 달력 AJAX(selectListReservCalAjax.do)는 WAF(WebMonitor)가
 * 보호하여 외부 자동화(curl/서버 크롤러)는 `비정상 접근`으로 차단된다. 하지만
 * **이미 WAF를 통과한 실제 브라우저 세션**에서 같은-출처 fetch로 호출하면 정상 동작한다.
 *
 * 사용법:
 *   1) 브라우저에서 https://yeyak.seoul.go.kr 접속(아무 페이지나).
 *   2) 개발자도구(F12) → Console 탭에 이 파일 전체를 붙여넣고 Enter.
 *   3) 수집이 끝나면 nanji_calendar.json 파일이 자동 다운로드된다.
 *   4) 그 파일을 ~/SeoulCampingWidget/crawler/nanji_calendar.json 로 저장하면
 *      메뉴바 앱/웹 위젯이 [갱신] 시 실측 잔여로 자동 반영한다.
 *
 * 개인·비상업 모니터링 용도. 요청 간 딜레이로 사이트에 부담을 주지 않는다.
 */
(async () => {
  const BASE = "https://yeyak.seoul.go.kr";
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const log = (...a) => console.log("[난지수집]", ...a);

  async function getText(url, opts) {
    const res = await fetch(url, { credentials: "include", ...opts });
    return await res.text();
  }

  // 1) 캠핑장 목록(페이지네이션)에서 난지캠핑장 서비스 수집
  log("목록 수집 중…");
  const services = [];
  const seen = new Set();
  for (let pg = 1; pg <= 15; pg++) {
    const html = await getText(`${BASE}/web/search/selectPageListDetailSearchImg.do?code=T500&dCode=T502&currentPage=${pg}`);
    if (/비정상 접근|ipRedirect/.test(html)) { log("⚠️ WAF 차단 감지 — 페이지 새로고침 후 재시도하세요."); return; }
    const tags = html.match(/<a\b[^>]*fnDetailPage[^>]*>/g) || [];
    let added = 0;
    for (const t of tags) {
      const id = (t.match(/fnDetailPage\(['"]([A-Za-z0-9]+)['"]/) || [])[1];
      const title = (t.match(/title=["']([^"']*)["']/) || [])[1] || "";
      if (id && title.includes("난지캠핑장") && !seen.has(id)) { seen.add(id); services.push({ id, title }); added++; }
    }
    log(`  page ${pg}: 난지 ${added}건 (누적 ${services.length})`);
    if (tags.length === 0) break;
    await sleep(600);
  }
  log(`총 ${services.length}개 서비스`);

  // 2) 각 서비스 상세 → #aform 직렬화 → 달력 AJAX(같은-출처, WAF 통과)
  const result = [];
  for (const s of services) {
    try {
      const det = await getText(`${BASE}/web/reservation/selectReservView.do?rsv_svc_id=${s.id}`);
      const block = (det.match(/<form[^>]*id="aform"[\s\S]*?<\/form>/) || [])[0] || "";
      const params = new URLSearchParams();
      for (const inp of block.match(/<input\b[^>]*>/g) || []) {
        const n = (inp.match(/name="([^"]*)"/) || [])[1];
        const v = (inp.match(/value="([^"]*)"/) || [])[1] || "";
        if (n) params.set(n, v);
      }
      const res = await fetch(`${BASE}/web/reservation/selectListReservCalAjax.do`, {
        method: "POST", credentials: "include",
        headers: { "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8", "X-Requested-With": "XMLHttpRequest" },
        body: params.toString(),
      });
      const cal = await res.json();
      const tm = cal.resultListTm || {};
      const days = (cal.resultListDays || []).map((d) => {
        const t = tm[d.YMD] || {};
        const cap = Number(t.RCRIT_NMPR_CNT ?? 0), reg = Number(t.REG_TOTAL_CNT ?? 0);
        const posbl = t.RESVE_POSBL_CNT != null ? Number(t.RESVE_POSBL_CNT) : cap - reg;
        return { ymd: d.YMD, code: d.SVC_RESVE_CODE, remain: Math.max(0, posbl), reg, cap };
      });
      result.push({ id: s.id, title: s.title, days });
      log(`  ${s.title.slice(0, 26)} → ${days.length}일 (가능 ${days.filter((d) => d.remain > 0).length})`);
    } catch (e) {
      log(`  ${s.title.slice(0, 26)} 실패: ${e.message}`);
      result.push({ id: s.id, title: s.title, days: [] });
    }
    await sleep(700);
  }

  // 3) JSON 다운로드
  const payload = JSON.stringify({ generatedAt: new Date().toISOString(), source: "browser", services: result }, null, 0);
  const blob = new Blob([payload], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "nanji_calendar.json";
  document.body.appendChild(a); a.click(); a.remove();
  const ok = result.filter((r) => r.days.length > 0).length;
  log(`✅ 완료: ${ok}/${result.length}개 서비스 수집 → nanji_calendar.json 다운로드됨`);
  log("이 파일을 ~/SeoulCampingWidget/crawler/nanji_calendar.json 로 저장하고 앱에서 [갱신]하세요.");
})();
