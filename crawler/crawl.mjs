// 난지 캠핑장 예약 현황 Playwright 크롤러 (스텁).
//
// 서울 공공예약 사이트의 실제 DOM 구조가 확정되지 않았으므로,
// 현재는 Swift 파서(`ReservationParser`)가 기대하는 계약(contract) 형식의
// HTML을 생성해 출력한다:
//
//   <li data-site="A" data-available="3"></li>
//
// 실제 연동 시 아래 TODO 부분을 사이트 구조에 맞게 채우면 된다.
//
// 사용법:
//   npm install
//   node crawl.mjs --month 2026-07 > out.html
//   (또는 Swift 앱의 CrawlerDataSource.htmlProvider가 이 스크립트를 서브프로세스로 호출)

import { chromium } from "playwright";

const RESERVATION_URL = "https://yeyak.seoul.go.kr";

function parseArgs() {
  const args = process.argv.slice(2);
  const monthIdx = args.indexOf("--month");
  const month = monthIdx >= 0 ? args[monthIdx + 1] : null;
  const useMock = args.includes("--mock") || true; // 실제 셀렉터 확정 전까지 기본 mock
  return { month, useMock };
}

/** 계약 형식의 HTML을 생성한다. */
function toContractHTML(counts) {
  const items = Object.entries(counts)
    .map(([site, n]) => `  <li data-site="${site}" data-available="${n}"></li>`)
    .join("\n");
  return `<ul class="camp-availability">\n${items}\n</ul>`;
}

async function crawlReal(month) {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage();
    await page.goto(RESERVATION_URL, { waitUntil: "networkidle" });

    // TODO: 실제 사이트 흐름 구현
    //   1) 난지 캠핑장 검색/이동
    //   2) 대상 월(month) 선택
    //   3) 각 사이트(A~D)의 잔여 수량 DOM 추출
    // 예시(가상 셀렉터):
    //   const counts = {};
    //   for (const site of ["A", "B", "C", "D"]) {
    //     const text = await page.locator(`[data-zone="${site}"] .remain`).innerText();
    //     counts[site] = parseInt(text.replace(/[^0-9]/g, ""), 10) || 0;
    //   }
    //   return counts;

    throw new Error("실제 셀렉터 미구현");
  } finally {
    await browser.close();
  }
}

async function main() {
  const { month, useMock } = parseArgs();
  let counts;
  if (useMock) {
    // 결정론적 mock 값.
    counts = { A: 3, B: 2, C: 0, D: 5 };
  } else {
    counts = await crawlReal(month);
  }
  process.stdout.write(toContractHTML(counts) + "\n");
}

main().catch((err) => {
  process.stderr.write(`크롤러 오류: ${err.message}\n`);
  process.exit(1);
});
