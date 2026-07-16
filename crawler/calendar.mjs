// 난지캠핑장 날짜별 사이트별 잔여 좌석 수집기 (Playwright, 로그인 불필요).
//
// 실측: 상세 페이지가 로드되면 사이트의 JS가 selectListReservCalAjax.do를 호출하고,
// 그 응답에 날짜별 예약가능수(RESVE_POSBL_CNT), 신청수(REG_TOTAL_CNT), 총모집수(RCRIT_NMPR_CNT)가 들어온다.
// 브라우저로 상세 페이지를 열고 이 AJAX 응답을 가로채면 로그인 없이 잔여를 얻는다.
//
// anti-bot 예의: 실제 브라우저 + 요청 간 딜레이 + 순차 처리 + 차단 감지 백오프.
// 비상업 개인 모니터링 용도.

import { chromium } from "playwright";
import { writeFileSync } from "node:fs";

const BASE = "https://yeyak.seoul.go.kr";
const LIST = `${BASE}/web/search/selectPageListDetailSearchImg.do?code=T500&dCode=T502`;
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36";
const DELAY = 4000; // 서비스 간 4초

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ locale: "ko-KR", userAgent: UA, viewport: { width: 1280, height: 900 } });
  const page = await ctx.newPage();

  // 워밍업(정상 사용자 흐름)
  await page.goto(`${BASE}/web/main.do`, { waitUntil: "domcontentloaded" });
  await sleep(1500);

  // 목록에서 난지캠핑장 서비스 추출(7·8월 등 모두)
  await page.goto(LIST, { waitUntil: "networkidle" });
  const html = await page.content();
  if (html.includes("비정상 접근")) { console.error("차단됨(목록). 잠시 후 재시도 필요."); process.exit(2); }
  const services = [];
  for (const tag of html.match(/<a\b[^>]*fnDetailPage[^>]*>/g) || []) {
    const id = (tag.match(/fnDetailPage\(['"]([A-Za-z0-9]+)['"]/) || [])[1];
    const title = (tag.match(/title=["']([^"']*)["']/) || [])[1] || "";
    if (id && title.includes("난지캠핑장")) services.push({ id, title });
  }
  console.error(`난지캠핑장 서비스 ${services.length}건`);

  const result = [];
  for (const s of services) {
    let cal = null;
    const onResp = async (r) => {
      if (/selectListReservCalAjax/i.test(r.url())) {
        try { cal = await r.json(); } catch {}
      }
    };
    page.on("response", onResp);
    await page.goto(`${BASE}/web/reservation/selectReservView.do?rsv_svc_id=${s.id}`, { waitUntil: "networkidle" });
    // 달력 AJAX가 늦게 올 수 있어 잠깐 대기
    for (let i = 0; i < 10 && !cal; i++) await sleep(400);
    page.off("response", onResp);

    const days = [];
    if (cal && cal.resultListDays) {
      const tm = cal.resultListTm || {};
      for (const d of cal.resultListDays) {
        const t = tm[d.YMD] || {};
        const cap = Number(t.RCRIT_NMPR_CNT ?? 0);
        const reg = Number(t.REG_TOTAL_CNT ?? 0);
        const posbl = t.RESVE_POSBL_CNT != null ? Number(t.RESVE_POSBL_CNT) : (cap - reg);
        days.push({ ymd: d.YMD, code: d.SVC_RESVE_CODE, remain: posbl, reg, cap });
      }
    }
    result.push({ id: s.id, title: s.title, days });
    console.error(`  ${s.title.slice(0, 30)} → ${days.length}일 (가능일 ${days.filter(d => d.remain > 0).length})`);
    await sleep(DELAY);
  }

  await browser.close();
  const payload = JSON.stringify({ generatedAt: new Date().toISOString(), services: result });
  writeFileSync("/tmp/nanji_calendar.json", payload);
  // 메뉴바 앱(loadFresh)도 읽을 수 있게 저장소 경로에도 저장.
  try { writeFileSync(new URL("./nanji_calendar.json", import.meta.url).pathname, payload); } catch {}
  process.stdout.write("saved /tmp/nanji_calendar.json (+crawler/nanji_calendar.json)\n");
}

main().catch((e) => { console.error("오류:", e.message); process.exit(1); });
