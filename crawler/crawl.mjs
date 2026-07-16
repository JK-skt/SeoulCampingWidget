// 난지캠핑장 예약 현황 Playwright 크롤러 (동작 버전 + 로그인 세션 확장).
//
// 흐름: [auth.json 있으면 로그인 세션] 진입 → 캠핑장 목록(T500/T502)
//       → 난지캠핑장 서비스(제목/상태/구역) 추출
//       → (로그인 시) 각 서비스 예약폼(insertFormReserve.do)의 달력에서
//          예약 가능일(td.able a[data-ymd]) 파싱
//       → Swift ReservationParser 계약 HTML 출력.
//
// 실측 근거:
//   - 서비스 상태(접수중/마감)는 로그인 없이 조회 가능.
//   - 달력 셀: <td class="able"><a data-ymd="YYYYMMDD"> = 예약 가능일.
//     예약폼은 로그인을 요구하므로 auth.json(storageState)이 있어야 달력이 렌더된다.
//
// 사용:
//   node login.mjs          # (로컬) 로그인 후 auth.json 저장 — 1회
//   node crawl.mjs          # 난지캠핑장 크롤 → 계약 HTML
//   node crawl.mjs --json   # 상세 JSON(서비스별 예약가능일 포함)
//   node crawl.mjs --mock   # 브라우저 없이 mock

import { chromium } from "playwright";
import { existsSync } from "node:fs";

const BASE = "https://yeyak.seoul.go.kr";
const LIST = `${BASE}/web/search/selectPageListDetailSearchImg.do?code=T500&dCode=T502`;
const AUTH = "auth.json";

function parseArgs() {
  const a = process.argv.slice(2);
  return { json: a.includes("--json"), mock: a.includes("--mock") };
}

function zoneOf(title) {
  const m = title.match(/일반캠핑존\s*([A-D])형/) || title.match(/([A-D])구역/);
  return m ? m[1] : null;
}

function toContractHTML(counts) {
  const li = ["A", "B", "C", "D"]
    .map((s) => `  <li data-site="${s}" data-available="${counts[s] || 0}"></li>`)
    .join("\n");
  return `<ul class="camp-availability">\n${li}\n</ul>`;
}

/** 예약폼 달력에서 예약 가능일(YYYYMMDD) 목록 파싱. 로그인 세션 필요. */
async function availableDates(page, svcId) {
  await page.goto(`${BASE}/web/reservation/insertFormReserve.do?rsv_svc_id=${svcId}`, {
    waitUntil: "networkidle",
  });
  await page.waitForTimeout(1500);
  const html = await page.content();
  // <td class="... able ...">...<a ... data-ymd="YYYYMMDD">
  const dates = [];
  const re = /<td[^>]*class="[^"]*\bable\b[^"]*"[^>]*>[\s\S]{0,120}?data-ymd="(\d{8})"/g;
  let m;
  while ((m = re.exec(html))) dates.push(m[1]);
  return [...new Set(dates)];
}

async function crawlReal() {
  const authed = existsSync(AUTH);
  const browser = await chromium.launch({ headless: true });
  try {
    const ctx = await browser.newContext({
      locale: "ko-KR",
      ...(authed ? { storageState: AUTH } : {}),
    });
    const page = await ctx.newPage();
    await page.goto(`${BASE}/web/main.do`, { waitUntil: "domcontentloaded" });
    await page.goto(LIST, { waitUntil: "networkidle" });

    const html = await page.content();
    const services = [];
    for (const tag of html.match(/<a\b[^>]*fnDetailPage[^>]*>/g) || []) {
      const id = (tag.match(/fnDetailPage\(['"]([A-Za-z0-9]+)['"]/) || [])[1];
      const title = (tag.match(/title=["']([^"']*)["']/) || [])[1] || "";
      if (!id || !title.includes("난지캠핑장")) continue;
      const idx = html.indexOf(tag);
      const status = (html.slice(idx, idx + 600).match(/bd_label\s+status\d+"[^>]*>([^<]+)</) || [])[1]?.trim() || "?";
      services.push({ id, title, status, zone: zoneOf(title), open: /접수중/.test(status) });
    }

    // 로그인 세션이면 서비스별 예약 가능일 수집
    if (authed) {
      for (const s of services) {
        if (!s.open) continue;
        try { s.availableDates = await availableDates(page, s.id); }
        catch { s.availableDates = []; }
      }
    }

    // 구역별 집계: 로그인 시 예약가능일 수, 아니면 접수중 여부(1/0)
    const counts = {};
    for (const s of services) {
      if (!s.open || !s.zone) continue;
      counts[s.zone] = (counts[s.zone] || 0) + (authed ? (s.availableDates?.length || 0) : 1);
    }
    return { services, counts, authed };
  } finally {
    await browser.close();
  }
}

async function main() {
  const { json, mock } = parseArgs();
  let counts, services, authed;
  if (mock) {
    counts = { A: 1, B: 1, C: 0, D: 1 }; services = []; authed = false;
  } else {
    ({ counts, services, authed } = await crawlReal());
  }
  if (json) {
    process.stdout.write(JSON.stringify({ authed, counts, services }, null, 2) + "\n");
  } else {
    if (!authed) process.stderr.write("정보: auth.json 없음 → 서비스 상태(접수중/마감)만. 일자별은 `node login.mjs` 후 가능.\n");
    process.stdout.write(toContractHTML(counts) + "\n");
  }
}

main().catch((e) => {
  process.stderr.write(`크롤러 오류: ${e.message}\n`);
  process.exit(1);
});
