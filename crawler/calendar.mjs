// 난지캠핑장 날짜별 사이트별 잔여 좌석 수집기 (Playwright).
//
// 근본 구조(실측 리버스 엔지니어링):
//   - 상세페이지(selectReservView.do)의 달력은 inline JS 함수 `fnDraw()`("첫로딩")가
//     `$('#aform').serialize()`를 selectListReservCalAjax.do 로 POST 하여 채운다.
//   - 이 AJAX는 WAF(WebMonitor)가 보호한다: 순수 curl/재구성 POST는
//     `/management/ipRedirect.do?threatGb=DNP`(비정상 접근) 로 302 차단된다.
//   - **실제 브라우저 안에서 `fnDraw()`를 호출**하면 브라우저의 세션/헤더/JS 챌린지로
//     WAF를 통과해 정상 JSON을 받는다. → 그 응답을 page.on('response')로 가로챈다.
//
// 응답 필드: resultListDays[{YMD, SVC_RESVE_CODE}], resultListTm[YMD]{RESVE_POSBL_CNT,
//   REG_TOTAL_CNT(신청수), RCRIT_NMPR_CNT(총모집수)}.  잔여 = RESVE_POSBL_CNT.
//
// 예의: 실제 브라우저 + 서비스 간 딜레이 + 순차 + WAF 차단 감지 시 즉시 중단/백오프.
// 비상업 개인 모니터링 용도. (IP가 이미 플래그되면 잠시 후 재시도)

import { chromium } from "playwright";
import { writeFileSync } from "node:fs";

const BASE = "https://yeyak.seoul.go.kr";
const LIST = `${BASE}/web/search/selectPageListDetailSearchImg.do?code=T500&dCode=T502`;
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";
const DELAY = 5000;               // 서비스 간 5초 (예의)
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function isBlocked(urlOrHtml) {
  return /ipRedirect\.do|비정상 접근|threatGb=/.test(urlOrHtml);
}

async function collectListing(page) {
  await page.goto(LIST, { waitUntil: "networkidle" });
  if (isBlocked(page.url())) throw new Error("WAF-BLOCKED-LIST");
  const html = await page.content();
  if (isBlocked(html)) throw new Error("WAF-BLOCKED-LIST");
  const out = [];
  for (const tag of html.match(/<a\b[^>]*fnDetailPage[^>]*>/g) || []) {
    const id = (tag.match(/fnDetailPage\(['"]([A-Za-z0-9]+)['"]/) || [])[1];
    const title = (tag.match(/title=["']([^"']*)["']/) || [])[1] || "";
    if (id && title.includes("난지캠핑장")) out.push({ id, title });
  }
  return out;
}

/** 상세페이지에서 fnDraw()를 호출해 달력 AJAX 응답을 가로챈다. */
async function fetchCalendar(page, svcId) {
  let cal = null, blocked = false;
  const onResp = async (r) => {
    const u = r.url();
    if (/selectListReservCalAjax/i.test(u)) {
      if (r.status() >= 300 && r.status() < 400 && isBlocked(r.headers().location || "")) blocked = true;
      try { cal = await r.json(); } catch {}
    }
    if (isBlocked(u)) blocked = true;
  };
  page.on("response", onResp);
  try {
    const resp = await page.goto(`${BASE}/web/reservation/selectReservView.do?rsv_svc_id=${svcId}`,
      { waitUntil: "domcontentloaded" });
    if (isBlocked(page.url()) || (resp && isBlocked(resp.url()))) { blocked = true; return { blocked }; }
    await sleep(800);
    // 브라우저 컨텍스트에서 첫로딩 함수 호출(WAF 통과 경로).
    await page.evaluate(() => { try { if (typeof fnDraw === "function") fnDraw(); } catch (e) {} });
    for (let i = 0; i < 15 && !cal && !blocked; i++) await sleep(400);
  } finally {
    page.off("response", onResp);
  }
  return { cal, blocked };
}

function parseDays(cal) {
  const tm = cal.resultListTm || {};
  const days = [];
  for (const d of cal.resultListDays || []) {
    const t = tm[d.YMD] || {};
    const cap = Number(t.RCRIT_NMPR_CNT ?? 0);
    const reg = Number(t.REG_TOTAL_CNT ?? 0);
    const posbl = t.RESVE_POSBL_CNT != null ? Number(t.RESVE_POSBL_CNT) : (cap - reg);
    days.push({ ymd: d.YMD, code: d.SVC_RESVE_CODE, remain: Math.max(0, posbl), reg, cap });
  }
  return days;
}

async function main() {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({
    locale: "ko-KR", userAgent: UA, viewport: { width: 1366, height: 900 },
    extraHTTPHeaders: { "Accept-Language": "ko-KR,ko;q=0.9" },
  });
  const page = await ctx.newPage();

  // 워밍업(정상 사용자 흐름)
  await page.goto(`${BASE}/web/main.do`, { waitUntil: "domcontentloaded" });
  await sleep(1500);

  let services;
  try { services = await collectListing(page); }
  catch (e) {
    console.error(`목록 수집 실패: ${e.message}. WAF 차단 상태 — 잠시 후 재시도하세요.`);
    await browser.close(); process.exit(2);
  }
  console.error(`난지캠핑장 서비스 ${services.length}건`);

  const result = [];
  let blockedCount = 0;
  for (const s of services) {
    const { cal, blocked } = await fetchCalendar(page, s.id);
    if (blocked) {
      blockedCount++;
      console.error(`  [WAF 차단] ${s.title.slice(0, 26)} — 중단 백오프`);
      if (blockedCount >= 2) break;         // 연속 차단이면 즉시 중단(사이트 보호)
    }
    const days = cal ? parseDays(cal) : [];
    result.push({ id: s.id, title: s.title, days });
    console.error(`  ${s.title.slice(0, 28)} → ${days.length}일 (가능 ${days.filter(d => d.remain > 0).length})`);
    await sleep(DELAY);
  }

  await browser.close();

  const ok = result.filter(r => r.days.length > 0).length;
  if (ok === 0) { console.error("수집된 달력 데이터 없음(WAF 차단 추정). 잠시 후 재시도."); process.exit(3); }

  const payload = JSON.stringify({ generatedAt: new Date().toISOString(), services: result });
  writeFileSync("/tmp/nanji_calendar.json", payload);
  try { writeFileSync(new URL("./nanji_calendar.json", import.meta.url).pathname, payload); } catch {}
  console.error(`✅ ${ok}개 서비스 실측 저장 → /tmp/nanji_calendar.json (+crawler/)`);
  process.stdout.write("saved\n");
}

main().catch((e) => { console.error("오류:", e.message); process.exit(1); });
