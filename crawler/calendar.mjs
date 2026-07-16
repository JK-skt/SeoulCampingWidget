// 난지캠핑장 날짜별 사이트별 잔여 수집기 (Playwright, 사람 속도).
//
// 핵심: yeyak WAF는 '빠른 반복 요청'을 봇으로 차단한다(ipRedirect.do?threatGb=DNP).
// → 실제 브라우저로 **사람처럼 천천히**(요청 간 15~30초 랜덤) 한 페이지씩 방문하고,
//   상세페이지에서 fnDraw()를 호출해 달력 AJAX 응답을 가로챈다.
// → 차단(ipRedirect/비정상 접근) 감지 시 **즉시 중단**하여 사이트에 부담을 주지 않는다.
//
// 이미 IP가 차단된 상태면 첫 요청에서 감지하고 바로 종료한다(그 후 수십 분 대기 필요).
//
// 사용: node calendar.mjs            (전 서비스, 매우 느림 — 5~8분)
//       node calendar.mjs --check    (차단 여부만 가볍게 1회 확인)

import { chromium } from "playwright";
import { writeFileSync } from "node:fs";

const BASE = "https://yeyak.seoul.go.kr";
const LIST = `${BASE}/web/search/selectPageListDetailSearchImg.do?code=T500&dCode=T502`;
const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// 사람 속도: 요청 간 15~30초 랜덤.
const humanDelay = () => sleep(15000 + Math.floor(Math.random() * 15000));
const isBlocked = (s) => /ipRedirect\.do|비정상 접근|threatGb=/.test(s || "");

async function gentleCheck(page) {
  const r = await page.goto(`${BASE}/web/main.do`, { waitUntil: "domcontentloaded" });
  if (isBlocked(page.url()) || isBlocked(r?.url())) return false;
  const html = await page.content();
  return !isBlocked(html);
}

async function collectListing(page) {
  await page.goto(LIST, { waitUntil: "networkidle" });
  if (isBlocked(page.url())) return null;
  const html = await page.content();
  if (isBlocked(html)) return null;
  const out = [];
  for (const tag of html.match(/<a\b[^>]*fnDetailPage[^>]*>/g) || []) {
    const id = (tag.match(/fnDetailPage\(['"]([A-Za-z0-9]+)['"]/) || [])[1];
    const title = (tag.match(/title=["']([^"']*)["']/) || [])[1] || "";
    if (id && title.includes("난지캠핑장")) out.push({ id, title });
  }
  return out;
}

async function fetchCalendar(page, svcId) {
  let cal = null, blocked = false;
  const onResp = async (r) => {
    const u = r.url();
    if (isBlocked(u)) blocked = true;
    if (/selectListReservCalAjax/i.test(u)) { try { cal = await r.json(); } catch {} }
  };
  page.on("response", onResp);
  try {
    const resp = await page.goto(`${BASE}/web/reservation/selectReservView.do?rsv_svc_id=${svcId}`,
      { waitUntil: "networkidle" });
    if (isBlocked(page.url()) || isBlocked(resp?.url())) return { blocked: true };
    await sleep(2500 + Math.random() * 2000);           // 사람이 화면 읽는 시간
    await page.evaluate(() => { try { if (typeof fnDraw === "function") fnDraw(); } catch (e) {} });
    for (let i = 0; i < 20 && !cal && !blocked; i++) await sleep(400);
  } finally { page.off("response", onResp); }
  return { cal, blocked };
}

function parseDays(cal) {
  const tm = cal.resultListTm || {};
  return (cal.resultListDays || []).map((d) => {
    const t = tm[d.YMD] || {};
    const cap = Number(t.RCRIT_NMPR_CNT ?? 0), reg = Number(t.REG_TOTAL_CNT ?? 0);
    const posbl = t.RESVE_POSBL_CNT != null ? Number(t.RESVE_POSBL_CNT) : cap - reg;
    return { ymd: d.YMD, code: d.SVC_RESVE_CODE, remain: Math.max(0, posbl), reg, cap };
  });
}

async function main() {
  const checkOnly = process.argv.includes("--check");
  const browser = await chromium.launch({ headless: !process.argv.includes("--headed") });
  const ctx = await browser.newContext({
    locale: "ko-KR", userAgent: UA, viewport: { width: 1366, height: 900 },
    extraHTTPHeaders: { "Accept-Language": "ko-KR,ko;q=0.9" },
  });
  const page = await ctx.newPage();

  console.error("① 진입(main.do)…");
  const ok = await gentleCheck(page);
  if (!ok) { console.error("✗ WAF 차단 상태 — 지금은 접근 불가. 탭 닫고 수십 분 뒤(또는 IP 변경) 재시도."); await browser.close(); process.exit(2); }
  console.error("  통과 ✓");
  if (checkOnly) { console.error("차단 아님 — 지금 `node calendar.mjs`(느린 수집) 실행 가능."); await browser.close(); process.exit(0); }

  await sleep(4000 + Math.random() * 3000);
  console.error("② 목록…");
  const services = await collectListing(page);
  if (!services) { console.error("✗ 목록에서 차단 감지 — 중단."); await browser.close(); process.exit(2); }
  console.error(`  난지캠핑장 ${services.length}건. 사람 속도로 수집(요청 간 15~30초)…`);

  const result = [];
  for (const s of services) {
    await humanDelay();                                  // ★ 느린 페이싱
    const { cal, blocked } = await fetchCalendar(page, s.id);
    if (blocked) { console.error(`  ✗ [차단] ${s.title.slice(0, 22)} — 즉시 중단`); break; }
    const days = cal ? parseDays(cal) : [];
    result.push({ id: s.id, title: s.title, days });
    console.error(`  ✓ ${s.title.slice(0, 24)} → ${days.length}일 (가능 ${days.filter(d => d.remain > 0).length})`);
  }

  await browser.close();
  const good = result.filter(r => r.days.length > 0).length;
  if (good === 0) { console.error("수집 0 — 잠시 후 재시도."); process.exit(3); }
  const payload = JSON.stringify({ generatedAt: new Date().toISOString(), source: "slow-crawl", services: result });
  writeFileSync("/tmp/nanji_calendar.json", payload);
  try { writeFileSync(new URL("./nanji_calendar.json", import.meta.url).pathname, payload); } catch {}
  console.error(`✅ ${good}개 서비스 저장 → /tmp/nanji_calendar.json (+crawler/)`);
  process.stdout.write("saved\n");
}

main().catch((e) => { console.error("오류:", e.message); process.exit(1); });
