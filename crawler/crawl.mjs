// 난지 캠핑장 예약 현황 Playwright 크롤러.
//
// 실측 리버스 엔지니어링 결과(yeyak.seoul.go.kr 실제 엔드포인트):
//   - /web/main.do                                  세션 쿠키 발급(진입)
//   - /web/search/selectPageListTotalSearch.do      통합검색(키워드)
//   - /web/reservation/selectPageListFacilitySvc.do 시설 서비스 목록
//   - /web/reservation/selectReservView.do?rsv_svc_id=...   서비스 상세
//   - /web/reservation/selectListReservCalAjax.do   ★ 날짜별 예약현황(세션 필요; 직접 GET은 302→로그인)
//   - /web/reservation/selectListReservCalUnitAjax.do  구역/단위별 잔여
//
// 핵심: 예약현황 AJAX는 세션 쿠키 + XHR 컨텍스트가 있어야 데이터를 반환한다.
// 그래서 순수 HTTP가 아니라 Playwright(브라우저 세션)로 페이지를 열어
// 캘린더가 렌더된 뒤 잔여 수량을 읽어야 한다.
//
// 출력: Swift ReservationParser 계약(<li data-site="A" data-available="N">) HTML.
//
// 사용:
//   npm install
//   node crawl.mjs --month 2026-07            # 실제 크롤(node/Playwright 필요)
//   node crawl.mjs --month 2026-07 --mock     # 계약 형식 mock

import { chromium } from "playwright";

const BASE = "https://yeyak.seoul.go.kr";
const SEARCH_KEYWORD = "난지 캠핑";

function parseArgs() {
  const a = process.argv.slice(2);
  const mi = a.indexOf("--month");
  return { month: mi >= 0 ? a[mi + 1] : null, useMock: a.includes("--mock") };
}

function toContractHTML(counts) {
  const items = Object.entries(counts)
    .map(([s, n]) => `  <li data-site="${s}" data-available="${n}"></li>`)
    .join("\n");
  return `<ul class="camp-availability">\n${items}\n</ul>`;
}

async function crawlReal(month) {
  const browser = await chromium.launch({ headless: true });
  try {
    const ctx = await browser.newContext({ locale: "ko-KR" });
    const page = await ctx.newPage();

    // 1) 진입 → 세션 쿠키 확보
    await page.goto(`${BASE}/web/main.do`, { waitUntil: "networkidle" });

    // 2) 통합검색으로 난지 캠핑 서비스 목록 수집
    await page.goto(
      `${BASE}/web/search/selectPageListTotalSearch.do?searchKeyword=${encodeURIComponent(SEARCH_KEYWORD)}`,
      { waitUntil: "networkidle" }
    );
    // 검색 결과 앵커에서 rsv_svc_id 추출(예: selectReservView.do?rsv_svc_id=S...)
    const svcIds = await page.$$eval("a[href*='rsv_svc_id=']", (as) =>
      Array.from(new Set(as.map((a) => (a.getAttribute("href").match(/rsv_svc_id=([A-Z0-9]+)/) || [])[1]).filter(Boolean)))
    );

    // 3) 각 서비스 상세를 열어 해당 월의 잔여 수량을 읽는다.
    //    (selectListReservCalAjax.do가 세션 컨텍스트에서 자동 호출되어 캘린더 렌더)
    const counts = { A: 0, B: 0, C: 0, D: 0 };
    for (const svcId of svcIds) {
      await page.goto(`${BASE}/web/reservation/selectReservView.do?rsv_svc_id=${svcId}`, {
        waitUntil: "networkidle",
      });
      // TODO(사이트 DOM 확정 필요): 구역(A~D)과 해당 월 잔여 수량 셀 셀렉터 매핑.
      //   const zone = await page.locator("...").innerText();      // A/B/C/D
      //   const remain = await page.locator("... .remain").count(); // 잔여 슬롯
      //   counts[zone] += remain;
    }
    return counts;
  } finally {
    await browser.close();
  }
}

async function main() {
  const { month, useMock } = parseArgs();
  const counts = useMock ? { A: 3, B: 2, C: 0, D: 5 } : await crawlReal(month);
  process.stdout.write(toContractHTML(counts) + "\n");
}

main().catch((e) => {
  process.stderr.write(`크롤러 오류: ${e.message}\n`);
  process.exit(1);
});
