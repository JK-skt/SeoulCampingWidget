// 난지캠핑장 예약 현황 Playwright 크롤러 (동작 버전).
//
// 흐름: 진입(세션) → 캠핑장 카테고리 목록(T500/T502) → 난지캠핑장 서비스 추출
//       → 제목에서 구역(일반캠핑존 A/B/C/D형)·상태(접수중/마감) 파싱
//       → Swift ReservationParser 계약 HTML 출력(<li data-site data-available>).
//
// 참고(실측): 서비스 단위 상태(접수중/마감)는 로그인 없이 조회 가능.
//   일자별 '잔여 좌석 수'는 예약 신청 폼(insertFormReserve.do)이 로그인을 요구하므로
//   계정 세션(쿠키)이 있어야 한다. --login-cookie 옵션으로 확장 가능(하단 TODO).
//
// 사용:
//   node crawl.mjs                 # 난지캠핑장 라이브 크롤 → 계약 HTML
//   node crawl.mjs --json          # 상세 JSON
//   node crawl.mjs --mock          # 브라우저 없이 mock

import { chromium } from "playwright";

const BASE = "https://yeyak.seoul.go.kr";
const LIST = `${BASE}/web/search/selectPageListDetailSearchImg.do?code=T500&dCode=T502`;

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

async function crawlReal() {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await (await browser.newContext({ locale: "ko-KR" })).newPage();
    await page.goto(`${BASE}/web/main.do`, { waitUntil: "domcontentloaded" });
    await page.goto(LIST, { waitUntil: "networkidle" });

    const html = await page.content();
    const services = [];
    for (const tag of html.match(/<a\b[^>]*fnDetailPage[^>]*>/g) || []) {
      const id = (tag.match(/fnDetailPage\(['"]([A-Za-z0-9]+)['"]/) || [])[1];
      const title = (tag.match(/title=["']([^"']*)["']/) || [])[1] || "";
      if (!id || !title.includes("난지캠핑장")) continue;
      // 상태 라벨: 같은 li 블록에서 status
      const idx = html.indexOf(tag);
      const seg = html.slice(idx, idx + 600);
      const status = (seg.match(/bd_label\s+status\d+"[^>]*>([^<]+)</) || [])[1]?.trim() || "?";
      services.push({ id, title, status, zone: zoneOf(title), open: /접수중/.test(status) });
    }

    // 일반캠핑존 구역별 접수중 수 집계
    const counts = {};
    for (const s of services) if (s.open && s.zone) counts[s.zone] = (counts[s.zone] || 0) + 1;
    return { services, counts };
  } finally {
    await browser.close();
  }
}

async function main() {
  const { json, mock } = parseArgs();
  let counts, services;
  if (mock) {
    counts = { A: 1, B: 1, C: 0, D: 1 };
    services = [];
  } else {
    ({ counts, services } = await crawlReal());
  }
  if (json) {
    process.stdout.write(JSON.stringify({ counts, services }, null, 2) + "\n");
  } else {
    process.stdout.write(toContractHTML(counts) + "\n");
  }
}

// TODO(일자별 잔여): 로그인 세션이 필요.
//   1) storageState(쿠키)로 로그인 상태 주입: newContext({ storageState: 'auth.json' })
//   2) insertFormReserve.do 진입 → reservCalendar가 렌더한 날짜별 cnt 파싱
//   (계정 자격증명 필요 — 사용자 제공 시 연결)

main().catch((e) => {
  process.stderr.write(`크롤러 오류: ${e.message}\n`);
  process.exit(1);
});
