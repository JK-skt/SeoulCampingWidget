// yeyak 로그인 세션을 auth.json(storageState)으로 저장하는 헬퍼.
//
// 이 스크립트는 화면(headed 브라우저)이 필요하므로 **사용자 로컬 PC**에서 실행한다.
// (원격/headless 환경에서는 로그인 상호작용이 불가)
//
// 사용:
//   node login.mjs
//   → 브라우저가 열리면 yeyak에 로그인 → 터미널에서 Enter → auth.json 저장
//
// 이후 crawl.mjs가 auth.json을 자동으로 사용해 일자별 예약 가능일까지 크롤한다.

import { chromium } from "playwright";

const BASE = "https://yeyak.seoul.go.kr";
const browser = await chromium.launch({ headless: false });
const ctx = await browser.newContext({ locale: "ko-KR" });
const page = await ctx.newPage();

await page.goto(`${BASE}/web/loginForm.do`, { waitUntil: "domcontentloaded" });
console.log("\n▶ 브라우저에서 yeyak에 로그인하세요.");
console.log("  로그인 완료 후 이 터미널에서 [Enter]를 누르면 세션을 저장합니다.\n");

process.stdin.resume();
await new Promise((resolve) => process.stdin.once("data", resolve));

await ctx.storageState({ path: "auth.json" });
console.log("✅ auth.json 저장 완료. 이제 `node crawl.mjs`가 일자별 가용까지 조회합니다.");
await browser.close();
process.exit(0);
